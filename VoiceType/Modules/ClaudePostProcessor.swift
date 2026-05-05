import Foundation

final class ClaudePostProcessor {
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-sonnet-4-5"
    private let apiVersion = "2023-06-01"

    func process(text: String, mode: ProcessingMode) async throws -> String {
        guard mode != .raw else { return text }
        guard let apiKey = Settings.shared.anthropicAPIKey, !apiKey.isEmpty else {
            throw NSError(domain: "VoiceType", code: 10,
                          userInfo: [NSLocalizedDescriptionKey: "Anthropic API-Key fehlt"])
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "system": mode.systemPrompt,
            "messages": [
                ["role": "user", "content": text]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "VoiceType", code: 11,
                          userInfo: [NSLocalizedDescriptionKey: "Keine HTTP-Antwort"])
        }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw NSError(domain: "VoiceType", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Claude API: \(msg)"])
        }

        // Response: { "content": [ { "type": "text", "text": "..." } ], ... }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentArray = json["content"] as? [[String: Any]],
              let firstText = contentArray.first(where: { ($0["type"] as? String) == "text" }),
              let resultText = firstText["text"] as? String else {
            throw NSError(domain: "VoiceType", code: 12,
                          userInfo: [NSLocalizedDescriptionKey: "Unerwartete Claude-Antwort"])
        }

        return resultText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
