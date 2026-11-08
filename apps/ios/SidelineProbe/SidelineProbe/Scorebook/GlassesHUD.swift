// No SwiftUI import here on purpose: MWDATDisplay's Text/Button/Image
// would clash with SwiftUI's (see the DAT 0.5 changelog note).
import Foundation
import MWDATCamera
import MWDATCore
import MWDATDisplay
import MWDATSpeech
import Observation
import SidelineCore

/// Heads-up scorebook on Meta Ray-Ban Display: score, situation, the last
/// play, Call play / Confirm / Undo / Redo buttons (selectable with the
/// Neural Band), and the glasses' own speech recognizer for calling plays
/// hands-free with the phone in a pocket.
///
/// Owns one DeviceSession ("game mode") with Display + Speech + Camera:
/// the lens, hands-free play calls and the game video all share it, because
/// DAT allows one session per device. Glasses without a display (Gen 3,
/// Oakley) still get recording and the glasses mic.
@MainActor
@Observable
final class GlassesHUD {
    enum Status: Equatable {
        case off
        case connecting
        case on(glasses: String)
        case failed(String)
    }

    /// What the lens shows about voice input, on top of the game.
    enum Voice: Equatable {
        case idle
        /// Listening for a play call; `heard` is the transcript so far.
        case listening(heard: String, source: String)
        /// A short note (e.g. "Didn't catch a play"), shown until the next change.
        case note(String)
    }

    /// The glasses' on-device speech recognizer (MWDATSpeech, experimental in DAT 1.0).
    enum GlassesMic: Equatable {
        case unknown
        case ready
        case unavailable(String)
    }

    private(set) var status: Status = .off
    private(set) var sentCount = 0
    private(set) var voice: Voice = .idle
    private(set) var glassesMic: GlassesMic = .unknown
    private(set) var hasDisplay = true

    /// Live numbers for the recording in progress (refreshed ~1 Hz).
    struct Recording: Equatable {
        var file: String
        var seconds: TimeInterval
        var frames: Int
        var fps: Double
        var error: String?
    }
    private(set) var recording: Recording?
    /// Called when a recording ends (stopped, or the session went away).
    var onRecordingFinished: ((_ file: String, _ frames: Int, _ error: String?) -> Void)?
    private var camera: Camera?
    private var writer: HEVCFileWriter?
    private var frameTap: FrameTap?
    private var recordingTimer: Timer?

    /// Called on the main actor when the wearer picks a button on the lens.
    var onConfirm: ((UUID) -> Void)?
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?
    var onCallPlay: (() -> Void)?
    var onDoneListening: (() -> Void)?
    var onCancelListening: (() -> Void)?

    private var session: DeviceSession?
    private var display: Display?
    private var speech: Speech?
    private var speechHandler: ((String, Bool) -> Void)?
    private var tokens = ListenerTokenBag()
    private var game: FootballHUD?
    private var shown: Lens?
    private var queued: Lens?
    private var sending = false
    private var lastSessionError: DeviceSessionError?

    /// Everything that determines what's on the lens; equal → no resend.
    private struct Lens: Equatable {
        var game: FootballHUD
        var voice: Voice
        var recording: Bool
    }

    var isOn: Bool { if case .on = status { true } else { false } }
    var isActive: Bool { session != nil }

    var statusText: String {
        switch status {
        case .off: "Off"
        case .connecting: "Connecting…"
        case .on(let name): "On \(name)" + (hasDisplay ? "" : " (no display)")
        case .failed(let why): "Failed: \(why)"
        }
    }

    var glassesMicText: String {
        switch glassesMic {
        case .unknown: "glasses mic: checking…"
        case .ready: "glasses mic: ready"
        case .unavailable(let why): "glasses mic: \(why) (using phone mic)"
        }
    }

    // MARK: Connect / disconnect

    /// Opens a session on the given glasses (which must have a display).
    func connect(deviceID: DeviceIdentifier?, initial hud: FootballHUD) async {
        guard session == nil else { return }
        guard let deviceID else {
            status = .failed("No Meta Ray-Ban Display linked. Pair it in Meta AI (or a mock Display on the probe tab).")
            return
        }
        status = .connecting
        tokens = ListenerTokenBag()
        shown = nil
        voice = .idle
        glassesMic = .unknown
        do {
            let wearables = Wearables.shared
            let session = try wearables.createSession(deviceSelector: SpecificDeviceSelector(device: deviceID))
            self.session = session

            let states = session.stateStream()
            lastSessionError = nil
            session.errorPublisher.listen { [weak self] error in
                Task { @MainActor in self?.lastSessionError = error }
            }.store(in: tokens)

            try session.start()
            for await state in states {
                if state == .started { break }
                if state == .stopped {
                    try? await Task.sleep(for: .milliseconds(500))
                    throw HUDError.sessionEnded(lastSessionError.map { "\($0)" })
                }
            }

            // From here on, a stopped session means the HUD is gone.
            session.statePublisher.listen { [weak self] state in
                Task { @MainActor in
                    if state == .stopped { self?.ended("session ended") }
                }
            }.store(in: tokens)

            hasDisplay = wearables.deviceForIdentifier(deviceID)?.supportsDisplay() ?? true
            if hasDisplay {
                let display = try session.addDisplay()
                self.display = display
                let displayStates = AsyncStream<DisplayState> { cont in
                    display.statePublisher.listen { cont.yield($0) }.store(in: self.tokens)
                }
                display.start()
                if display.state != .started {
                    for await s in displayStates {
                        if s == .started { break }
                        if s == .stopped { throw HUDError.displayStopped }
                    }
                }
            }
            status = .on(glasses: session.device?.nameOrId() ?? "glasses")
            show(hud)
            await attachSpeech(to: session)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            teardown()
            status = .failed(message)
        }
    }

    func disconnect() {
        let display = self.display
        teardown()
        Task { try? await display?.clearDisplay() }
        status = .off
    }

    private func ended(_ why: String) {
        guard session != nil else { return }
        teardown()
        status = .failed(why)
    }

    private func teardown() {
        endRecording()
        speech?.stop()
        display?.stop()
        session?.stop()
        speech = nil
        speechHandler = nil
        display = nil
        session = nil
        voice = .idle
        let old = tokens
        Task { await old.cancelAll() }
    }

    // MARK: Glasses speech

    /// Adds the speech capability to the session, stopped. It's started only
    /// while the wearer is calling a play. Requires the Meta AI microphone
    /// permission (request it on the probe tab; asking from here would switch
    /// apps mid-session).
    private func attachSpeech(to session: DeviceSession) async {
        do {
            let permission = try await Wearables.shared.checkPermissionStatus(.microphone)
            guard permission == .granted else {
                glassesMic = .unavailable("not allowed in Meta AI")
                return
            }
        } catch {
            glassesMic = .unavailable("permission check failed")
            return
        }
        let added: Speech?
        do {
            added = try session.addSpeech()
        } catch {
            glassesMic = .unavailable("couldn't attach (\(error))")
            return
        }
        guard let speech = added else {
            glassesMic = .unavailable("not supported on these glasses")
            return
        }
        self.speech = speech
        speech.transcriptionPublisher.listen { [weak self] result in
            Task { @MainActor in self?.speechHandler?(result.text, result.isFinal) }
        }.store(in: tokens)
        speech.errorPublisher.listen { [weak self] error in
            Task { @MainActor in
                if error == .unavailable { self?.glassesMic = .unavailable("unavailable") }
            }
        }.store(in: tokens)
        glassesMic = .ready
    }

    /// Starts the glasses' recognizer; `handler(text, isFinal)` gets every
    /// transcript until `stopGlassesSpeech()`. Returns false if it doesn't
    /// come up within `timeout`, so the caller can fall back to the phone mic.
    func startGlassesSpeech(timeout: Duration = .seconds(3),
                            handler: @escaping (String, Bool) -> Void) async -> Bool {
        guard glassesMic == .ready, let speech else { return false }
        speechHandler = handler
        if speech.state != .started { speech.start() }
        let deadline = ContinuousClock.now + timeout
        while speech.state != .started {
            if ContinuousClock.now > deadline {
                speech.stop()
                speechHandler = nil
                return false
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return true
    }

    func stopGlassesSpeech() {
        speechHandler = nil
        speech?.stop()
    }

    // MARK: Recording (game video)

    var isRecording: Bool { writer != nil }
    var recordingFile: String? { recording?.file }

    /// Starts the glasses camera (HEVC 504x896 @ 15 fps, the T1 config) and
    /// writes it to `url` in passthrough. HEVC keeps streaming with the phone
    /// locked; raw would pause.
    func startRecording(to url: URL) throws {
        guard let session, writer == nil else { return }
        let config = StreamConfiguration(videoCodec: .hvc1, resolution: .medium, frameRate: 15)
        guard let camera = try session.addCamera(config: config) else { throw HUDError.cameraUnavailable }
        let writer = HEVCFileWriter(url: url)
        let tap = FrameTap()
        camera.stream.videoFramePublisher.listen { frame in
            writer.append(frame)
            _ = tap.frame(bytes: 0, previewEvery: 0)
        }.store(in: tokens)
        camera.stream.errorPublisher.listen { [weak self] error in
            Task { @MainActor in self?.recording?.error = "\(error)" }
        }.store(in: tokens)
        camera.stream.start()
        self.camera = camera
        self.writer = writer
        frameTap = tap
        recording = Recording(file: url.lastPathComponent, seconds: 0, frames: 0, fps: 0)
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshRecording() }
        }
        RunLoop.main.add(timer, forMode: .common)
        recordingTimer = timer
        if let game { send(Lens(game: game, voice: voice, recording: true)) }
    }

    func stopRecording() {
        endRecording()
        if let game { send(Lens(game: game, voice: voice, recording: false)) }
    }

    /// Seconds into the current recording for wall-clock `date`.
    func videoTime(at date: Date) -> TimeInterval? { writer?.videoTime(at: date) }

    private func refreshRecording() {
        guard let writer, var r = recording else { return }
        let p = writer.progress
        r.seconds = p.seconds
        r.frames = p.frames
        r.fps = frameTap?.snapshot().fps ?? 0
        recording = r
    }

    private func endRecording() {
        guard let writer, let file = recording?.file else { return }
        refreshRecording()
        let frames = recording?.frames ?? 0
        recordingTimer?.invalidate()
        recordingTimer = nil
        camera?.stop()
        camera = nil
        self.writer = nil
        frameTap = nil
        recording = nil
        let done = onRecordingFinished
        writer.finish { error in
            Task { @MainActor in done?(file, frames, error) }
        }
    }

    // MARK: Rendering

    func setVoice(_ v: Voice) {
        voice = v
        if let game { send(Lens(game: game, voice: v, recording: isRecording)) }
    }

    /// Sends the HUD if it changed.
    func show(_ hud: FootballHUD) {
        game = hud
        send(Lens(game: hud, voice: voice, recording: isRecording))
    }

    /// Sends are serialized; if one is in flight, only the newest pending
    /// state is sent afterwards.
    private func send(_ lens: Lens) {
        guard isOn, display != nil, lens != shown else { return }
        if sending { queued = lens; return }
        sending = true
        Task {
            var next: Lens? = lens
            while let current = next, let display {
                do {
                    try await display.send(render(current))
                    shown = current
                    sentCount += 1
                } catch {
                    ended("send failed: \((error as? LocalizedError)?.errorDescription ?? "\(error)")")
                }
                next = queued
                queued = nil
            }
            sending = false
        }
    }

    private func action(_ pick: @escaping @MainActor (GlassesHUD) -> Void) -> @Sendable () -> Void {
        { [weak self] in Task { @MainActor in if let self { pick(self) } } }
    }

    private func render(_ lens: Lens) -> FlexBox {
        let hud = lens.game
        let playID = hud.lastPlayID
        let confirm = action { hud in if let playID { hud.onConfirm?(playID) } }
        let undo = action { $0.onUndo?() }
        let redo = action { $0.onRedo?() }
        let call = action { $0.onCallPlay?() }
        let done = action { $0.onDoneListening?() }
        let cancel = action { $0.onCancelListening?() }

        return FlexBox(direction: .column, spacing: 6, alignment: .start, crossAlignment: .stretch,
                       padding: EdgeInsets(all: 12)) {
            Text(hud.scoreLine, style: .heading)
            Text(hud.situationLine, style: .body, color: .secondary)

            if case .listening(let heard, let source) = lens.voice {
                FlexBox(direction: .column, spacing: 2, padding: EdgeInsets(all: 8)) {
                    Text(heard.isEmpty ? "Listening… say the play" : heard, style: .body)
                    Text("Listening (\(source))", style: .meta, color: .secondary)
                }
                .background(.card)
                ButtonGroup(alignment: .start) {
                    Button(label: "Done", style: .primary, iconName: .checkmark, onClick: done)
                        .actionRole(.primary)
                    Button(label: "Cancel", style: .secondary, iconName: .x, onClick: cancel)
                }
            } else {
                if let play = hud.lastPlay {
                    FlexBox(direction: .column, spacing: 2, padding: EdgeInsets(all: 8)) {
                        Text(play, style: .body)
                        Text(hud.lastPlayNeedsConfirm ? "Proposed" : "Confirmed", style: .meta, color: .secondary)
                    }
                    .background(.card)
                }
                ButtonGroup(alignment: .start) {
                    if hud.lastPlayNeedsConfirm {
                        Button(label: "Confirm", style: .primary, iconName: .checkmark, onClick: confirm)
                            .actionRole(.primary)
                        Button(label: "Call play", style: .secondary, iconName: .speechBubble, onClick: call)
                    } else {
                        Button(label: "Call play", style: .primary, iconName: .speechBubble, onClick: call)
                            .actionRole(.primary)
                    }
                    if hud.lastPlay != nil {
                        Button(label: "Undo", style: .secondary, onClick: undo)
                    }
                    if hud.redoPlay != nil {
                        Button(label: "Redo", style: .outline, onClick: redo)
                    }
                }
                if case .note(let note) = lens.voice {
                    Text(note, style: .meta, color: .secondary)
                }
                if let redoPlay = hud.redoPlay {
                    Text("Redo: \(redoPlay)", style: .meta, color: .secondary)
                }
                if hud.pendingCount > 1 {
                    Text("\(hud.pendingCount) plays to confirm", style: .meta, color: .secondary)
                }
                if lens.recording {
                    Text("● REC", style: .meta, color: .secondary)
                }
            }
        }
    }

    enum HUDError: LocalizedError {
        case sessionEnded(String?)
        case displayStopped
        case cameraUnavailable
        var errorDescription: String? {
            switch self {
            case .cameraUnavailable: "The glasses camera couldn't be added to the session"
            case .sessionEnded(let why): "The glasses ended the session" + (why.map { " (\($0))" } ?? "")
            case .displayStopped: "The display stopped before it started"
            }
        }
    }
}
