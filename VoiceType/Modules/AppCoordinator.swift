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

    // Leitet objectWillChange von localTranscriber weiter, damit SwiftUI-Views
    // die coordinator als @EnvironmentObject beobachten auch auf modelState-
    // Änderungen im localTranscriber re-rendern.
    private var cancellables = Set<AnyCancellable>()

    init() {
        localTranscriber.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

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
        Settings.shared.recordFirstLaunchIfNeeded()
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        _ = TextInserter.checkAccessibilityPermission(prompt: false)
        // Modell-Warmup erst nach 3 Sekunden — gibt der App Zeit vollständig
        // zu starten bevor Core ML Speicher allokiert. Verhindert Konflikte
        // mit dem LLDB-Debugger beim Entwickeln.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.warmUpLocalIfNeeded()
        }
        Task { await validateLicenseOnStartup() }
    }

    /// Validiert den Lizenzkey beim App-Start gegen den Server.
    ///
    /// Drei Fälle:
    ///   - Server antwortet 2xx → licenseValidated = true, lastValidatedAt aktualisieren
    ///   - Server antwortet 4xx → licenseValidated = false, Fehler anzeigen (Key gesperrt)
    ///   - Netzwerkfehler (offline) → licenseValidated unverändert, kein Fehler
    ///     (vorherige Validierung gilt weiter → Offline-Nutzung möglich)
    func validateLicenseOnStartup() async {
        guard let key = Settings.shared.licenseKey, !key.isEmpty else { return }
        let base = Settings.shared.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: base + "/validate") else {
            await MainActor.run { self.setState(.error("Server-URL ungültig")) }
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(key, forHTTPHeaderField: "x-license-key")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }

            if (200..<300).contains(http.statusCode) {
                // Erfolg: Validierung bestätigt
                Settings.shared.licenseValidated = true
                Settings.shared.lastValidatedAt = Date()
            } else {
                // Server hat Key explizit abgelehnt → sofort sperren
                Settings.shared.licenseValidated = false
                let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
                    ?? "HTTP \(http.statusCode)"
                await MainActor.run { self.setState(.error("Lizenz gesperrt: \(msg)")) }
            }
        } catch {
            // Netzwerkfehler: kein setState, kein Zurücksetzen von licenseValidated.
            // Nutzer mit zuletzt gültigem Key können offline weiterarbeiten.
        }
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

        // Lizenz-/Grace-Logik:
        // - licenseValidated = true (Key wurde mind. einmal vom Server bestätigt):
        //     → alles erlaubt, auch offline (Netzwerkfehler setzt Flag nicht zurück)
        // - licenseValidated = false (kein Key oder Key gesperrt):
        //     → nur lokale Engine + Raw-Modus innerhalb der 14-tägigen Grace Period
        if !Settings.shared.licenseValidated {
            let isLocalRaw = (Settings.shared.transcriptionEngine == .local && mode == .raw)
            if !isLocalRaw {
                setState(.error("Lizenzkey erforderlich für Cloud-Transkription oder Modi „Nett“/„Wut→Nett“"))
                return
            }
            if !Settings.shared.isInGracePeriod {
                setState(.error("Probezeitraum abgelaufen — bitte Lizenzkey eintragen"))
                return
            }
        }

        currentMode = mode

        // Clipboard bereinigen damit keine Altlasten aus früheren Läufen eingefügt werden
        TextInserter.clearClipboard()

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

    /// Bricht eine laufende Aufnahme ab ohne Transkription (z.B. bei zu kurzem Tastendruck).
    func cancelRecording() {
        guard isRecording else { return }
        audioCapture.stop()
        activeTranscriber.cancelSession()
        setState(.idle)
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
                    let ns = error as NSError
                    if ns.code == 429 {
                        self.setState(.error("Monatliches Limit erreicht – bitte nächsten Monat oder Lizenz upgraden"))
                    } else {
                        self.setState(.error(error.localizedDescription))
                    }
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
