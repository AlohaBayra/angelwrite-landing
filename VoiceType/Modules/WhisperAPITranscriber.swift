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

    /// Legt die Aufnahme-Datei in EXAKT dem übergebenen Mikrofon-Format an
    /// (CAF-Container). Damit ist `audioFile.write(from: buffer)` ein direkter
    /// Schreibvorgang ohne interne Format-Konvertierung — kein -10877 mehr,
    /// weil die AudioUnit nichts umrechnen muss. Konvertierung auf das
    /// Whisper-kompatible 16 kHz Mono WAV passiert anschließend in
    /// finishSession() via AVAudioConverter.
    func startSession(format: AVAudioFormat) throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voicetype-\(UUID().uuidString).caf")
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

        guard let cafURL = fileURL else {
            throw NSError(domain: "VoiceType", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Keine Audio-Datei (startSession nicht aufgerufen?)"
            ])
        }
        defer { try? FileManager.default.removeItem(at: cafURL) }

        guard let licenseKey = Settings.shared.licenseKey, !licenseKey.isEmpty else {
            throw NSError(domain: "VoiceType", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Lizenzkey fehlt"
            ])
        }

        let wavURL = try convertToWav(from: cafURL)
        defer { try? FileManager.default.removeItem(at: wavURL) }

        let audioData = try Data(contentsOf: wavURL)
        return try await sendToServer(audioData: audioData, licenseKey: licenseKey)
    }

    /// Liest die native CAF-Aufnahme und schreibt sie als 16 kHz Mono Int16
    /// WAV — Whispers bevorzugtes Format. AVAudioConverter macht Resampling,
    /// Down-Mix auf Mono und Bit-Tiefen-Konvertierung in einem Schritt; bei
    /// Fehler wird die Teil-WAV aufgeräumt, bevor der Fehler propagiert.
    private func convertToWav(from cafURL: URL) throws -> URL {
        let wavURL = cafURL.deletingPathExtension().appendingPathExtension("wav")

        do {
            let inputFile = try AVAudioFile(forReading: cafURL)
            let inputFormat = inputFile.processingFormat

            let outputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]

            let outputFile = try AVAudioFile(forWriting: wavURL, settings: outputSettings)
            let outputFormat = outputFile.processingFormat

            guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
                throw NSError(domain: "VoiceType", code: 9, userInfo: [
                    NSLocalizedDescriptionKey: "AVAudioConverter konnte nicht erstellt werden"
                ])
            }

            let inputCapacity: AVAudioFrameCount = 4096
            guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: inputCapacity) else {
                throw NSError(domain: "VoiceType", code: 10, userInfo: [
                    NSLocalizedDescriptionKey: "Input-Buffer-Allokation fehlgeschlagen"
                ])
            }

            let ratio = outputFormat.sampleRate / inputFormat.sampleRate
            let outputCapacity = AVAudioFrameCount(Double(inputCapacity) * ratio) + 1024
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputCapacity) else {
                throw NSError(domain: "VoiceType", code: 11, userInfo: [
                    NSLocalizedDescriptionKey: "Output-Buffer-Allokation fehlgeschlagen"
                ])
            }

            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                do {
                    try inputFile.read(into: inputBuffer)
                } catch {
                    outStatus.pointee = .endOfStream
                    return nil
                }
                if inputBuffer.frameLength == 0 {
                    outStatus.pointee = .endOfStream
                    return nil
                }
                outStatus.pointee = .haveData
                return inputBuffer
            }

            while true {
                var convError: NSError?
                let status = converter.convert(to: outputBuffer, error: &convError, withInputFrom: inputBlock)
                if status == .error {
                    throw convError ?? NSError(domain: "VoiceType", code: 12, userInfo: [
                        NSLocalizedDescriptionKey: "AVAudioConverter-Fehler"
                    ])
                }
                if outputBuffer.frameLength > 0 {
                    try outputFile.write(from: outputBuffer)
                }
                if status == .endOfStream {
                    break
                }
            }

            return wavURL
        } catch {
            try? FileManager.default.removeItem(at: wavURL)
            throw error
        }
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
