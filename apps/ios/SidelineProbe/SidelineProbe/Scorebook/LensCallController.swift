import Foundation

/// "Call play" from the lens, hands-free: the wearer picks Call play with the
/// Neural Band, says the play, and stops talking. Prefers the glasses' own
/// recognizer (no phone audio at all, so it works with the phone in a pocket);
/// falls back to the phone mic if the glasses can't listen.
///
/// The call ends on the first of: a final transcript from the recognizer,
/// `silenceAfter` with no new words, `maxDuration`, or Done / Cancel on the lens.
@MainActor
final class LensCallController {
    enum Source: Equatable { case glasses, phone }

    static let silenceAfter: Duration = .milliseconds(1600)
    static let maxDuration: Duration = .seconds(12)

    private(set) var source: Source?
    var isListening: Bool { source != nil }

    private let hud: GlassesHUD
    private let phone: SpeechTranscriber
    private let onResult: (_ text: String, _ startedAt: Date) -> Void
    private var heard = ""
    /// When Call play was pressed: the anchor for the play's video clip.
    private var startedAt = Date()
    private var silenceTimer: Task<Void, Never>?
    private var capTimer: Task<Void, Never>?

    init(hud: GlassesHUD, phone: SpeechTranscriber, onResult: @escaping (_ text: String, _ startedAt: Date) -> Void) {
        self.hud = hud
        self.phone = phone
        self.onResult = onResult
    }

    func start() async {
        guard source == nil else { return }
        heard = ""
        startedAt = Date()
        if await hud.startGlassesSpeech(handler: { [weak self] text, isFinal in self?.receive(text, isFinal: isFinal) }) {
            source = .glasses
        } else {
            // Phone fallback. Never Bluetooth while the lens is up (dat-ios #342).
            if phone.isListening { phone.stop() }
            phone.allowBluetoothInput = false
            phone.onPartial = { [weak self] text in self?.receive(text, isFinal: false) }
            source = .phone
            // The lens call ends from our own timers; ignore the transcriber's
            // own final delivery so a play is never submitted twice.
            await phone.start { _ in }
            if let error = phone.error {
                source = nil
                phone.onPartial = nil
                hud.setVoice(.note("Mic didn't start: \(error)"))
                return
            }
        }
        showListening()
        capTimer = Task { [weak self] in
            try? await Task.sleep(for: Self.maxDuration)
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }

    /// Done on the lens: use what was heard so far.
    func finish() {
        guard let source else { return }
        stopListening(source)
        let text = heard.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            hud.setVoice(.note("Didn't hear a play. Pick Call play and try again."))
        } else {
            hud.setVoice(.idle)
            onResult(text, startedAt)
        }
    }

    /// Cancel on the lens: discard.
    func cancel() {
        guard let source else { return }
        stopListening(source)
        hud.setVoice(.idle)
    }

    private func receive(_ text: String, isFinal: Bool) {
        guard source != nil else { return }   // late transcript after the call ended
        heard = text
        showListening()
        if isFinal {
            finish()
        } else if !text.isEmpty {
            silenceTimer?.cancel()
            silenceTimer = Task { [weak self] in
                try? await Task.sleep(for: Self.silenceAfter)
                guard !Task.isCancelled else { return }
                self?.finish()
            }
        }
    }

    private func showListening() {
        hud.setVoice(.listening(heard: heard, source: source == .glasses ? "glasses mic" : "phone mic"))
    }

    private func stopListening(_ source: Source) {
        self.source = nil
        silenceTimer?.cancel()
        capTimer?.cancel()
        silenceTimer = nil
        capTimer = nil
        switch source {
        case .glasses:
            hud.stopGlassesSpeech()
        case .phone:
            phone.onPartial = nil
            phone.stop()
        }
    }
}
