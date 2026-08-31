import AVFoundation

/// Speaks answers aloud. Configured to keep working while the app is
/// backgrounded, which is essential — the user will be in another app
/// looking at the question while Sight talks.
final class Speaker: NSObject, ObservableObject {

    private let synth = AVSpeechSynthesizer()
    @Published private(set) var isSpeaking = false

    override init() {
        super.init()
        synth.delegate = self
        configureSession()
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // .playback keeps audio alive in the background and ignores
            // the ring/silent switch, which is what we want for a tutor.
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: [])
        } catch {
            print("Audio session error: \(error)")
        }
    }

    func speak(_ text: String) {
        guard !text.isEmpty else { return }

        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }

        try? AVAudioSession.sharedInstance().setActive(true, options: [])

        let utter = AVSpeechUtterance(string: text)
        utter.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        utter.pitchMultiplier = 1.0
        utter.volume = 1.0

        // Prefer a natural-sounding voice when the device has one installed
        if let premium = AVSpeechSynthesisVoice.speechVoices().first(where: {
            $0.language.hasPrefix("en") && $0.quality == .premium
        }) {
            utter.voice = premium
        } else if let enhanced = AVSpeechSynthesisVoice.speechVoices().first(where: {
            $0.language.hasPrefix("en") && $0.quality == .enhanced
        }) {
            utter.voice = enhanced
        } else {
            utter.voice = AVSpeechSynthesisVoice(language: "en-US")
        }

        isSpeaking = true
        synth.speak(utter)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
}

extension Speaker: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }
}
