import AVFoundation
import Foundation
import Observation
import Speech

/// Tap-to-talk speech recognition for play calls. Prefers on-device
/// recognition. The audio session allows Bluetooth HFP inputs, so AirPods
/// (or Meta glasses acting as a headset) can be the microphone.
@MainActor
@Observable
final class SpeechTranscriber {
    private(set) var isListening = false
    private(set) var partial = ""
    private(set) var authorized: Bool?
    private(set) var error: String?
    private(set) var onDevice = false

    private(set) var isStarting = false
    /// Let AirPods / glasses act as the mic. Off while the Display HUD is up.
    var allowBluetoothInput = true
    /// Every partial transcript while listening (used by lens Call play).
    var onPartial: ((String) -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audio = AudioCapture()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var onFinal: ((String) -> Void)?

    /// Football vocabulary hints for the recognizer.
    static let vocabulary = [
        "touchdown", "incomplete", "interception", "intercepted", "field goal", "extra point", "PAT",
        "two point conversion", "sack", "sacked", "fumble", "recovered", "punt", "kickoff", "touchback",
        "tackle by", "no gain", "loss of", "holding", "false start", "offside", "pass interference",
        "first and ten", "second and", "third and", "fourth and", "goal", "scratch that", "returned by",
    ]

    func requestAuthorization() async -> Bool {
        let speech = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
        let mic = await AVAudioApplication.requestRecordPermission()
        authorized = speech && mic
        return speech && mic
    }

    /// Starts listening. `onFinal` receives the transcript after `stop()`.
    func start(onFinal: @escaping (String) -> Void) async {
        guard !isStarting, !isListening else { return }
        error = nil
        if authorized != true, await !requestAuthorization() {
            error = "Microphone or speech recognition permission denied (Settings → Sideline Probe)."
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            error = "Speech recognition is unavailable right now."
            return
        }
        teardown()
        self.onFinal = onFinal

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.contextualStrings = Self.vocabulary
        onDevice = recognizer.supportsOnDeviceRecognition
        if onDevice { req.requiresOnDeviceRecognition = true }
        request = req

        // Audio session activation can block (Core Audio round-trips), so it
        // runs on the capture queue, never on the main thread.
        isStarting = true
        let started = await audio.start(timeout: 6, allowBluetooth: allowBluetoothInput) { buffer in req.append(buffer) }
        isStarting = false
        if let failure = started {
            error = failure
            teardown()
            return
        }
        partial = ""
        isListening = true

        task = recognizer.recognitionTask(with: req) { [weak self] result, err in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failed = err != nil
            Task { @MainActor in
                guard let self else { return }
                if let text {
                    self.partial = text
                    self.onPartial?(text)
                }
                if isFinal || failed { self.deliverFinal() }
            }
        }
    }

    /// Stops capturing audio; the final transcript arrives via `onFinal`.
    func stop() {
        guard isListening else { return }
        audio.stop()
        request?.endAudio()
        isListening = false
        // Safety net: if the recognizer never reports a final result, deliver what we have.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.deliverFinal()
        }
    }

    private func deliverFinal() {
        guard let callback = onFinal else { return }
        onFinal = nil
        let text = partial.trimmingCharacters(in: .whitespacesAndNewlines)
        teardown()
        partial = ""
        if !text.isEmpty { callback(text) }
    }

    private func teardown() {
        audio.stop()
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        isListening = false
    }
}

/// Owns the audio session and engine on a private serial queue.
/// AVAudioSession activation and AVAudioEngine start can block for a long
/// time (or indefinitely in a misconfigured simulator), so none of it runs
/// on the main thread.
final class AudioCapture: @unchecked Sendable {
    private let queue = DispatchQueue(label: "sideline.audio-capture")
    private let engine = AVAudioEngine()

    /// Returns nil on success, or a user-facing error message.
    func start(timeout: TimeInterval, allowBluetooth: Bool, onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void) async -> String? {
        await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            let once = Once(cont)
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                once.resume("The microphone didn't start. In the Simulator, allow microphone access for Simulator in macOS Settings, or type the play.")
            }
            queue.async { [engine] in
                do {
                    let session = AVAudioSession.sharedInstance()
                    var options: AVAudioSession.CategoryOptions = [.duckOthers, .defaultToSpeaker]
                    if allowBluetooth { options.insert(.allowBluetooth) }
                    try session.setCategory(.playAndRecord, mode: .measurement, options: options)
                    try session.setActive(true, options: .notifyOthersOnDeactivation)
                    let input = engine.inputNode
                    let format = input.outputFormat(forBus: 0)
                    // No usable input (e.g. a simulator without a mic) makes installTap abort.
                    guard format.sampleRate > 0, format.channelCount > 0 else {
                        once.resume("No microphone input available. Type the play instead.")
                        return
                    }
                    input.removeTap(onBus: 0)
                    input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in onBuffer(buffer) }
                    engine.prepare()
                    try engine.start()
                    once.resume(nil)
                } catch {
                    once.resume(error.localizedDescription)
                }
            }
        }
    }

    func stop() {
        queue.async { [engine] in
            if engine.isRunning { engine.stop() }
            engine.inputNode.removeTap(onBus: 0)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    /// Resumes a continuation at most once (start vs. timeout race).
    private final class Once: @unchecked Sendable {
        private var cont: CheckedContinuation<String?, Never>?
        private let lock = NSLock()
        init(_ cont: CheckedContinuation<String?, Never>) { self.cont = cont }
        func resume(_ value: String?) {
            lock.lock()
            let c = cont
            cont = nil
            lock.unlock()
            c?.resume(returning: value)
        }
    }
}
