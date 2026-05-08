import Foundation
import AVFoundation

final class WhisperAPITranscriber {
    private var audioFile: AVAudioFile?
    private var fileURL: URL?
    private let endpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!

    /// Legt die Aufnahme-Datei in EXAKT dem übergebenen Mikrofon-Format an.
    /// Damit ist `audioFile.write(from: buffer)` ein direkter Schreibvorgang
    /// ohne interne Format-Konvertierung — kein -10877 mehr möglich, weil
    /// die AudioUnit nichts umrechnen muss.
    func startSession(format: AVAudioFormat) throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voicetype-\(UUID().uuidString).wav")
        self.fileURL = url

        do {
            self.audioFile = try AVAudioFile(
                forWriting: url,
                settings: format.settings,
                commonFormat: format.commonFormat,
                interleaved: format.isInterleaved
            )
        } catch {
            self.fileURL = nil
            throw NSError(domain: "VoiceType", code: 8, userInfo: [
                NSLocalizedDescriptionKey:
                    "AVAudioFile(forWriting:) fehlgeschlagen für Format \(format): \(error.localizedDescription)"
            ])
        }
    }

    func process(buffer: AVAudioPCMBuffer) {
        try? audioFile?.write(from: buffer)
    }

    func finishSession() async throws -> String {
        audioFile = nil // schließt File-Handle

        guard let url = fileURL else {
            throw NSError(domain: "VoiceType", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Keine Audio-Datei (startSession nicht aufgerufen?)"
            ])
        }
        defer { try? FileManager.default.removeItem(at: url) }

        guard let apiKey = Settings.shared.openAIAPIKey, !apiKey.isEmpty else {
            throw NSError(domain: "VoiceType", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "OpenAI API-Key fehlt"
            ])
        }

        // Whisper akzeptiert WAV in verschiedenen Sample-Rates und Bit-Tiefen
        // und resampled serverseitig. Bei Push-to-Talk-Aufnahmen unter wenigen
        // Sekunden bleibt die Datei deutlich unter dem Whisper-Limit von 25 MB
        // (z. B. 48 kHz Float32 stereo ≈ 384 KB/s → ~5 MB für 13 s).
        let audioData = try Data(contentsOf: url)
        return try await sendToWhisper(audioData: audioData, apiKey: apiKey)
    }

    private func sendToWhisper(audioData: Data, apiKey: String) async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        var body = Data()

        // file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // model
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)

        // language hint (optional, Whisper auto-detected sonst)
        if let lang = Settings.shared.languageHint, !lang.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
            body.append(lang.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "VoiceType", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Keine HTTP-Antwort"])
        }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw NSError(domain: "VoiceType", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Whisper API: \(msg)"])
        }

        struct Response: Decodable { let text: String }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.text
    }
}

extension WhisperAPITranscriber: Transcriber {
    func cancelSession() {
        audioFile = nil
        if let url = fileURL {
            try? FileManager.default.removeItem(at: url)
            fileURL = nil
        }
    }
}
