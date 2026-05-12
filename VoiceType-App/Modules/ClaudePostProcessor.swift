import Foundation

final class ClaudePostProcessor {
    /// Endpoint wird zur Laufzeit aus Settings.shared.serverURL gebaut.
    /// Trailing-Slashes der Basis-URL werden geschluckt.
    private var endpoint: URL {
        let base = Settings.shared.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: base + "/process") ?? URL(string: "https://invalid.local/process")!
    }

    func process(text: String, mode: ProcessingMode) async throws -> String {
        guard mode != .raw else { return text }
        guard let licenseKey = Settings.shared.licenseKey, !licenseKey.isEmpty else {
            throw NSError(domain: "VoiceType", code: 10,
                          userInfo: [NSLocalizedDescriptionKey: "Lizenzkey fehlt"])
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(licenseKey, forHTTPHeaderField: "x-license-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "text": text,
            "systemPrompt": mode.systemPrompt
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
                          userInfo: [NSLocalizedDescriptionKey: "Server (process): \(msg)"])
        }

        struct Response: Decodable { let text: String }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
