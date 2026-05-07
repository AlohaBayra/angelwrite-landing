import Foundation
import Combine
import AVFoundation
import AppKit

enum AppState: Equatable {
    case idle
    case recording(mode: ProcessingMode)
    case processing
    case done
    case error(String)

    static func == (lhs: AppState, rhs: AppState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.processing, .processing), (.done, .done):
            return true
        case (.recording(let a), .recording(let b)):
            return a == b
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

final class AppCoordinator: ObservableObject {
    @Published private(set) var state: AppState = .idle
    @Published var lastError: String?

    var onStateChange: ((AppState) -> Void)?

    private let audioCapture = AudioCapture()
    private let cloudTranscriber = WhisperAPITranscriber()
    let localTranscriber = WhisperLocalTranscriber()   // internal: SettingsView braucht Zugriff
    private let postProcessor = ClaudePostProcessor()
    private let inserter = TextInserter()

    private var activeTranscriber: any Transcriber {
        Settings.shared.transcriptionEngine == .local ? localTranscriber : cloudTranscriber
    }

    private var currentMode: ProcessingMode = .raw

    var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }

    var statusDescription: String {
        switch state {
        case .idle: return "Bereit"
        case .recording(let m): return "Aufnahme (\(m.displayName))"
        case .processing: return "Verarbeite…"
        case .done: return "Fertig"
        case .error(let m): return "Fehler: \(m)"
        }
    }

    // MARK: Public API

    func checkPermissionsOnStartup() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        _ = TextInserter.checkAccessibilityPermission(prompt: false)
        warmUpLocalIfNeeded()
    }

    /// Wärmt das lokale Modell im Hintergrund vor, wenn local engine gewählt ist.
    func warmUpLocalIfNeeded() {
        guard Settings.shared.transcriptionEngine == .local else { return }
        Task { await localTranscriber.prepare() }
    }

    /// Toggle-Modus für Fallback-Shortcuts
    func toggle(mode: ProcessingMode) {
        if isRecording {
            stopRecording()
        } else {
            startRecording(mode: mode)
        }
    }

    /// Push-to-Talk: Start beim Drücken des Modifiers
    func startRecording(mode: ProcessingMode) {
        guard case .idle = state else { return }

        guard TextInserter.checkAccessibilityPermission(prompt: true) else {
            setState(.error("Bedienungshilfen-Berechtigung fehlt"))
            return
        }
        if Settings.shared.transcriptionEngine == .cloud {
            guard Settings.shared.openAIAPIKey?.isEmpty == false else {
                setState(.error("OpenAI API-Key fehlt"))
                return
            }
        }
        if mode != .raw, Settings.shared.anthropicAPIKey?.isEmpty == true {
            setState(.error("Anthropic API-Key fehlt"))
            return
        }

        currentMode = mode

        do {
            // Mikrofon-Format VOR allem anderen ermitteln, an Whisper durchreichen,
            // dann Aufnahme starten — Tap und AVAudioFile MÜSSEN identisches
            // Format haben, sonst gibt's -10877.
            let micFormat = audioCapture.inputFormat
            try activeTranscriber.startSession(format: micFormat)
            try audioCapture.start { [weak self] buffer in
                self?.activeTranscriber.process(buffer: buffer)
            }
            setState(.recording(mode: mode))
            playSound("Tink")
        } catch {
            setState(.error("Aufnahme fehlgeschlagen: \(error.localizedDescription)"))
        }
    }

    /// Push-to-Talk: Stop beim Loslassen des Modifiers
    func stopRecording() {
        guard isRecording else { return }
        audioCapture.stop()
        setState(.processing)
        playSound("Pop")

        Task {
            do {
                let rawText = try await activeTranscriber.finishSession()
                guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    await MainActor.run { self.setState(.error("Keine Sprache erkannt")) }
                    return
                }

                let finalText: String
                if currentMode == .raw {
                    finalText = rawText
                } else {
                    finalText = try await postProcessor.process(text: rawText, mode: currentMode)
                }

                await MainActor.run {
                    self.inserter.insert(text: finalText)
                    self.setState(.done)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        self.setState(.idle)
                    }
                }
            } catch {
                await MainActor.run {
                    self.setState(.error(error.localizedDescription))
                }
            }
        }
    }

    // MARK: State Helpers

    private func setState(_ newState: AppState) {
        state = newState
        if case .error(let msg) = newState {
            lastError = msg
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                if case .error = self?.state {
                    self?.setState(.idle)
                }
            }
        }
        onStateChange?(newState)
    }

    private func playSound(_ name: String) {
        NSSound(named: name)?.play()
    }
}
