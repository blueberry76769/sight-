import Foundation

struct TutorResult: Decodable {
    let found: Bool
    let question: String?
    let answer: String?
}

enum TutorError: Error {
    case badKey
    case http(Int, String)
    case decode
}

/// Sends a screen frame to Claude and asks for a question + spoken answer.
final class TutorEngine {

    private let session: URLSession

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.waitsForConnectivity = true
        session = URLSession(configuration: cfg)
    }

    private let prompt = """
    Look at this screenshot. If there is a visible question, math problem, quiz item, \
    or exercise, respond with ONLY this JSON and nothing else:
    {"found":true,"question":"the question text","answer":"a spoken answer in 1-3 plain \
    sentences, no markdown, no bullets, natural to hear aloud"}

    If there is no clear question visible, respond with ONLY:
    {"found":false}
    """

    func solve(imageData: Data, apiKey: String) async throws -> TutorResult {
        guard !apiKey.isEmpty else { throw TutorError.badKey }

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 600,
            "messages": [[
                "role": "user",
                "content": [
                    [
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": imageData.base64EncodedString()
                        ]
                    ],
                    ["type": "text", "text": prompt]
                ]
            ]]
        ]

        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard (200..<300).contains(code) else {
            let msg = String(data: data, encoding: .utf8) ?? "unknown"
            throw TutorError.http(code, msg)
        }

        // Pull the text block out of Claude's content array
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = root["content"] as? [[String: Any]]
        else { throw TutorError.decode }

        var raw = ""
        for block in content where (block["type"] as? String) == "text" {
            raw = (block["text"] as? String) ?? ""
            break
        }

        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8),
              let result = try? JSONDecoder().decode(TutorResult.self, from: jsonData)
        else { return TutorResult(found: false, question: nil, answer: nil) }

        return result
    }
}
