import Foundation
import AVFoundation

final class WhisperAPITranscriber {
    private var audioFile: AVAudioFile?
    private var fileURL: URL?

    /// Endpoint wird zur Laufzeit aus Settings.shared.serverURL gebaut, damit
    /// User die Server-URL in den Settings ändern können ohne Neustart.
    /// Trailing-Slashes der Basis-URL werden geschluckt.
    private var endpoint: URL {
        let base = Settings.shared.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: base + "/transcribe") ?? URL(string: "https://invalid.local/transcribe")!
    }

    /// Legt die Aufnahme-Datei mit fixen 16 kHz Mono PCM-Settings an — dem
    /// von OpenAI Whisper bevorzugten Format. AVAudioFile resampelt die
    /// Mic-Buffer (typisch 48 kHz Float32 stereo) intern beim Schreiben, das
    /// Resultat ist eine direkt Whisper-kompatible WAV ohne Server-Konvertierung.
    /// Das `format`-Argument wird ignoriert (Protokoll-Kontrakt mit dem
    /// lokalen Transcriber).
    func startSession(format: AVAudioFormat) throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voicetype-\(UUID().uuidString).wav")
        self.fileURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        do {
            self.audioFile = try AVAudioFile(forWriting: url, settings: settings)
        } catch {
            self.fileURL = nil
            throw NSError(domain: "VoiceType", code: 8, userInfo: [
                NSLocalizedDescriptionKey:
                    "AVAudioFile(forWriting:) fehlgeschlagen: \(error.localizedDescription)"
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

        guard let licenseKey = Settings.shared.licenseKey, !licenseKey.isEmpty else {
            throw NSError(domain: "VoiceType", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Lizenzkey fehlt"
            ])
        }

        let audioData = try Data(contentsOf: url)
        return try await sendToServer(audioData: audioData, licenseKey: licenseKey)
    }

    private func sendToServer(audioData: Data, licenseKey: String) async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(licenseKey, forHTTPHeaderField: "x-license-key")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        var body = Data()

        // file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // durationSeconds — vorerst hartkodiert "0", Server kann das lesen ohne
        // dass wir die Aufnahmedauer hier durchschleifen müssen.
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"durationSeconds\"\r\n\r\n".data(using: .utf8)!)
        body.append("0".data(using: .utf8)!)
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
                          userInfo: [NSLocalizedDescriptionKey: "Server (transcribe): \(msg)"])
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
