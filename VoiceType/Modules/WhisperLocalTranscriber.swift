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

    /// Datei wird immer als Mono-Float32 angelegt.
    /// Stereo-Mikrofone würden sonst non-interleaved Kanäle produzieren,
    /// die WhisperKit als zwei sequenzielle Mono-Chunks liest → doppelter Text.
    func startSession(format: AVAudioFormat) throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voicetype-local-\(UUID().uuidString).caf")
        self.fileURL = url

        // Mono-Format erzwingen: gleiche Sample-Rate und Bit-Tiefe wie Mikrofon,
        // aber immer 1 Kanal, non-interleaved.
        var monoSettings = format.settings
        monoSettings[AVNumberOfChannelsKey] = 1

        do {
            self.audioFile = try AVAudioFile(
                forWriting: url,
                settings: monoSettings,
                commonFormat: format.commonFormat,
                interleaved: false
            )
        } catch {
            self.fileURL = nil
            throw NSError(domain: "VoiceType", code: 8, userInfo: [
                NSLocalizedDescriptionKey:
                    "AVAudioFile(forWriting:) fehlgeschlagen: \(error.localizedDescription)"
            ])
        }
    }

    /// Stereo-Buffer werden zu Mono gemischt (Durchschnitt aller Kanäle),
    /// Mono-Buffer werden direkt geschrieben.
    func process(buffer: AVAudioPCMBuffer) {
        guard let audioFile else { return }
        if buffer.format.channelCount > 1,
           let mono = Self.mixToMono(buffer) {
            try? audioFile.write(from: mono)
        } else {
            try? audioFile.write(from: buffer)
        }
    }

    /// Mischt einen Float32-PCM-Buffer mit beliebig vielen Kanälen zu Mono.
    private static func mixToMono(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard buffer.format.commonFormat == .pcmFormatFloat32,
              let monoFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: buffer.format.sampleRate,
                channels: 1,
                interleaved: false),
              let mono = AVAudioPCMBuffer(
                pcmFormat: monoFormat,
                frameCapacity: buffer.frameCapacity),
              let monoPtr = mono.floatChannelData?[0]
        else { return nil }

        mono.frameLength = buffer.frameLength
        let frameCount = Int(buffer.frameLength)
        let nChannels   = Int(buffer.format.channelCount)
        let scale       = Float(1) / Float(nChannels)

        // Alle Samples auf 0 initialisieren
        for i in 0..<frameCount { monoPtr[i] = 0 }

        // Kanäle aufaddieren und skalieren
        for ch in 0..<nChannels {
            guard let src = buffer.floatChannelData?[ch] else { continue }
            for i in 0..<frameCount {
                monoPtr[i] += src[i] * scale
            }
        }
        return mono
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

        let lang: String = {
            let hint = Settings.shared.languageHint ?? ""
            return hint.isEmpty ? "de" : hint
        }()

        var options = DecodingOptions()
        options.task = .transcribe
        options.language = lang
        options.withoutTimestamps = true
        options.temperatureFallbackCount = 0
        // Special Tokens (wie [BLANK_AUDIO], * Musik *) bereits im Tokenizer
        // herausfiltern — bevor sie in first.text landen. Das ist der korrekte
        // Fix; String-Cleanup danach ist nur noch Fallback.
        options.skipSpecialTokens = true
        // Stille-Segmente am Anfang unterdrücken
        options.suppressBlank = true
        options.compressionRatioThreshold = nil
        options.logProbThreshold = nil
        options.firstTokenLogProbThreshold = nil

        // Aufnahmen kürzer als 1 Sekunde sind Fn-Key-Bounces — kein Text erwünscht
        if let dur = Self.audioDuration(url: url), dur < 1.0 {
            return ""
        }

        let transcribeURL = Self.trimLeadingSilence(from: url)
        defer {
            if transcribeURL != url {
                try? FileManager.default.removeItem(at: transcribeURL)
            }
        }

        let results = try await pipe.transcribe(
            audioPath: transcribeURL.path, decodeOptions: options)
        guard let first = results.first else { return "" }

        return Self.removeMarkers(first.text)
    }

    /// Liest die aufgenommene Datei, sucht den ersten Frame mit Sprach-Energie
    /// und schreibt eine neue Datei ab diesem Punkt (minus 80 ms Puffer).
    /// Gibt die Original-URL zurück wenn keine Stille gefunden wird.
    private static func trimLeadingSilence(from url: URL) -> URL {
        guard let inFile = try? AVAudioFile(forReading: url) else { return url }

        let fmt       = inFile.processingFormat
        let totalFrames = AVAudioFrameCount(inFile.length)
        guard totalFrames > 0,
              let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: totalFrames),
              (try? inFile.read(into: buf)) != nil,
              let samples = buf.floatChannelData?[0]
        else { return url }

        let sr         = fmt.sampleRate
        let winFrames  = Int(sr * 0.04)          // 40 ms Fenster
        let threshold: Float = 0.01              // RMS-Schwelle für Sprache
        let frameCount = Int(buf.frameLength)
        var speechStart = 0
        var found = false

        var i = 0
        while i + winFrames <= frameCount {
            var sum: Float = 0
            for j in i ..< i + winFrames { sum += samples[j] * samples[j] }
            if sqrt(sum / Float(winFrames)) > threshold {
                speechStart = max(0, i - Int(sr * 0.08)) // 80 ms vor Beginn
                found = true
                break
            }
            i += winFrames / 2
        }

        guard found, speechStart > 0 else { return url }

        let trimmedURL = url.deletingPathExtension()
                            .appendingPathExtension("t.caf")
        let trimFrames = AVAudioFrameCount(frameCount - speechStart)

        guard let outFile = try? AVAudioFile(
                  forWriting: trimmedURL,
                  settings: fmt.settings,
                  commonFormat: fmt.commonFormat,
                  interleaved: fmt.isInterleaved),
              let outBuf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: trimFrames),
              let dst = outBuf.floatChannelData?[0]
        else { return url }

        outBuf.frameLength = trimFrames
        for j in 0 ..< Int(trimFrames) { dst[j] = samples[speechStart + j] }
        try? outFile.write(from: outBuf)
        return trimmedURL
    }

    private static func audioDuration(url: URL) -> Double? {
        guard let f = try? AVAudioFile(forReading: url) else { return nil }
        return Double(f.length) / f.processingFormat.sampleRate
    }

    /// Entfernt WhisperKit-Halluzinations-Marker wie „* Musik *" und „[BLANK_AUDIO]"
    /// aus dem Transkriptions-Text. Arbeitet auf Unicode-Scalar-Ebene, um
    /// nicht-standardkonforme Asterisk-Varianten zuverlässig zu erfassen.
    private static func removeMarkers(_ s: String) -> String {
        enum State { case normal, inStar, inBracket }
        var state: State = .normal
        var out = ""
        for sc in s.unicodeScalars {
            let v = sc.value
            // Alle gängigen Asterisk-Unicode-Varianten
            let isAsterisk     = v == 42 || v == 0x2217 || v == 0xFF0A || v == 0xFE61 || v == 0x2731
            let isOpenBracket  = v == 91  || v == 0xFF3B
            let isCloseBracket = v == 93  || v == 0xFF3D
            switch state {
            case .normal:
                if isAsterisk        { state = .inStar    }
                else if isOpenBracket { state = .inBracket }
                else                 { out.unicodeScalars.append(sc) }
            case .inStar:
                if isAsterisk { state = .normal }
            case .inBracket:
                if isCloseBracket { state = .normal }
            }
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
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

    func cancelSession() {
        audioFile = nil
        if let url = fileURL {
            try? FileManager.default.removeItem(at: url)
            fileURL = nil
        }
    }

    func unload() {
        pipe = nil
        modelState = .idle
    }
}
