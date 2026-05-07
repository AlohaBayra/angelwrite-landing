import Foundation
import Combine
import AVFoundation
import WhisperKit

final class WhisperLocalTranscriber: ObservableObject, Transcriber {
    enum ModelState {
        case idle
        case loading
        case ready
        case error(String)
    }

    @Published var modelState: ModelState = .idle

    private var pipe: WhisperKit? = nil
    private var audioFile: AVAudioFile?
    private var fileURL: URL?

    /// Identisch zu WhisperAPITranscriber — Datei wird im Mikrofon-Format
    /// angelegt, kein Resampling beim Schreiben.
    func startSession(format: AVAudioFormat) throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voicetype-local-\(UUID().uuidString).wav")
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

        if pipe == nil {
            await prepare()
        }

        if case .error = modelState {
            throw NSError(domain: "VoiceType", code: 9, userInfo: [
                NSLocalizedDescriptionKey:
                    "Lokales Modell nicht bereit – bitte erst in den Einstellungen laden"
            ])
        }
        guard let pipe else {
            throw NSError(domain: "VoiceType", code: 9, userInfo: [
                NSLocalizedDescriptionKey:
                    "Lokales Modell nicht bereit – bitte erst in den Einstellungen laden"
            ])
        }

        let results = try await pipe.transcribe(audioPath: url.path)
        if results.isEmpty { return "" }
        return results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    @MainActor
    func prepare() async {
        guard pipe == nil else { return }
        modelState = .loading
        do {
            pipe = try await WhisperKit(model: Settings.shared.whisperModelSize, verbose: false)
            modelState = .ready
        } catch {
            modelState = .error(error.localizedDescription)
        }
    }

    func unload() {
        pipe = nil
        modelState = .idle
    }
}
