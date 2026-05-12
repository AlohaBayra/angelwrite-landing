import AVFoundation

final class AudioCapture {
    private let engine = AVAudioEngine()
    private var bufferHandler: ((AVAudioPCMBuffer) -> Void)?

    /// Das native Eingabe-Format des Mikrofons. Auch ohne laufende Engine
    /// abfragbar — wird vom Audio-System anhand des aktuellen Geräts bestimmt.
    var inputFormat: AVAudioFormat {
        engine.inputNode.outputFormat(forBus: 0)
    }

    func start(onBuffer: @escaping (AVAudioPCMBuffer) -> Void) throws {
        self.bufferHandler = onBuffer

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw NSError(domain: "VoiceType", code: 100, userInfo: [
                NSLocalizedDescriptionKey:
                    "Mikrofon liefert kein gültiges Format (sampleRate=\(format.sampleRate), channels=\(format.channelCount)). Mikrofon-Berechtigung prüfen."
            ])
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.bufferHandler?(buffer)
        }

        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        bufferHandler = nil
    }
}
