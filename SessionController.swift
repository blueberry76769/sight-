import Foundation
import UIKit

struct AnswerEntry: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
    let time: Date
}

@MainActor
final class SessionController: ObservableObject {

    @Published var running = false
    @Published var broadcasting = false
    @Published var status = "Not running"
    @Published var currentQuestion = ""
    @Published var currentAnswer = ""
    @Published var log: [AnswerEntry] = []
    @Published var errorText = ""
    @Published var scanCount = 0

    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: "sight_api_key") }
    }
    @Published var interval: Double {
        didSet { UserDefaults.standard.set(interval, forKey: "sight_interval") }
    }

    private let engine = TutorEngine()
    let speaker = Speaker()

    private var task: Task<Void, Never>?
    private var lastAnswer = ""
    private var lastFrameHash = 0
    private var lastFrameDate: Date?

    init() {
        apiKey = UserDefaults.standard.string(forKey: "sight_api_key") ?? ""
        let saved = UserDefaults.standard.double(forKey: "sight_interval")
        interval = saved > 0 ? saved : 6
    }

    func start() {
        guard !apiKey.isEmpty else {
            errorText = "Paste your Anthropic API key first."
            return
        }
        guard !running else { return }

        running = true
        errorText = ""
        status = "Waiting for broadcast…"
        FrameBridge.clear()

        task = Task { await loop() }
    }

    func stop() {
        running = false
        task?.cancel()
        task = nil
        speaker.stop()
        status = "Stopped"
    }

    private func loop() async {
        while running && !Task.isCancelled {
            broadcasting = FrameBridge.isBroadcasting()

            if !broadcasting {
                status = "Start the broadcast to begin"
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                continue
            }

            if speaker.isSpeaking {
                try? await Task.sleep(nanoseconds: 400_000_000)
                continue
            }

            await scanOnce()

            let ns = UInt64(max(interval, 3) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: ns)
        }
    }

    private func scanOnce() async {
        guard let frame = FrameBridge.readFrame() else {
            status = "Waiting for the first frame…"
            return
        }

        // Skip if the frame hasn't been refreshed since last time
        if let last = lastFrameDate, frame.modified <= last {
            status = "Screen unchanged — watching…"
            return
        }
        lastFrameDate = frame.modified

        // Cheap change check so we don't re-send a near-identical screen
        let hash = frame.image.prefix(4096).hashValue
        if hash == lastFrameHash {
            status = "Screen unchanged — watching…"
            return
        }
        lastFrameHash = hash

        status = "Reading the screen…"
        scanCount += 1

        do {
            let result = try await engine.solve(imageData: frame.image, apiKey: apiKey)

            guard result.found, let answer = result.answer, !answer.isEmpty else {
                status = "Watching for questions…"
                return
            }

            guard answer.trimmingCharacters(in: .whitespaces)
                    != lastAnswer.trimmingCharacters(in: .whitespaces) else {
                status = "Same question — watching…"
                return
            }

            lastAnswer = answer
            currentQuestion = result.question ?? "Question"
            currentAnswer = answer
            log.insert(AnswerEntry(question: currentQuestion,
                                   answer: answer,
                                   time: Date()), at: 0)
            if log.count > 20 { log.removeLast() }

            status = "Speaking…"
            speaker.speak(answer)

        } catch TutorError.http(let code, _) {
            errorText = code == 401
                ? "API key rejected. Check the key and try again."
                : "Request failed (HTTP \(code)). Retrying."
            status = "Watching for questions…"
        } catch {
            errorText = "Network problem. Retrying on next scan."
            status = "Watching for questions…"
        }
    }

    func replayLast() {
        guard !currentAnswer.isEmpty else { return }
        speaker.speak(currentAnswer)
    }
}
