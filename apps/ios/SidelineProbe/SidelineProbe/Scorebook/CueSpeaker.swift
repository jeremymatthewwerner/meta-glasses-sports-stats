import AVFoundation

/// Speaks player cues. Audio goes wherever the phone's output is routed:
/// the glasses' open-ear speakers when they're connected over Bluetooth
/// (A2DP), otherwise the phone. Playback-only, so it doesn't claim the
/// glasses as a Bluetooth mic (which ends Display sessions, dat-ios #342).
@MainActor
final class CueSpeaker: NSObject {
    private let synth = AVSpeechSynthesizer()
    var rate: Float = 0.52
    /// The last thing said, for the screen.
    private(set) var lastSpoken: String?
    /// Owns the audio session for the current utterance (so we can release it).
    private var ownsSession = false

    override init() {
        super.init()
        synth.delegate = self
    }

    var isSpeaking: Bool { synth.isSpeaking }

    /// `urgent` cuts off whatever is being said (countdown beats a callout).
    func say(_ text: String, urgent: Bool = false) {
        prepareSession()
        if urgent, synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        let u = AVSpeechUtterance(string: text)
        u.rate = rate
        u.voice = AVSpeechSynthesisVoice(language: "en-US")
        u.prefersAssistiveTechnologySettings = false
        synth.speak(u)
        lastSpoken = text
    }

    func stop() { synth.stopSpeaking(at: .immediate) }

    private func prepareSession() {
        let session = AVAudioSession.sharedInstance()
        // Always switch to playback: speech capture leaves the category at
        // play-and-record, which would send cues to the phone's earpiece
        // instead of the glasses. Cues are muted while listening, and
        // capture sets its own category each time it starts.
        do {
            try session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            try session.setActive(true)
            ownsSession = true
        } catch {
            ownsSession = false
        }
    }

    private func finished() {
        guard ownsSession, !synth.isSpeaking else { return }
        ownsSession = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

extension CueSpeaker: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finished() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finished() }
    }
}
