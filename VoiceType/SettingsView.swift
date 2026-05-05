import SwiftUI
import KeyboardShortcuts
import AVFoundation

struct SettingsView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var openAIKey: String = Settings.shared.openAIAPIKey ?? ""
    @State private var anthropicKey: String = Settings.shared.anthropicAPIKey ?? ""
    @State private var useFallback: Bool = Settings.shared.useFallbackShortcuts
    @State private var languageHint: String = Settings.shared.languageHint ?? "de"
    @State private var permissionTrigger = 0  // forcing re-render

    var body: some View {
        TabView {
            generalTab.tabItem { Label("Allgemein", systemImage: "gear") }
            keysTab.tabItem { Label("API-Keys", systemImage: "key.fill") }
            shortcutsTab.tabItem { Label("Shortcuts", systemImage: "command") }
            permissionsTab.tabItem { Label("Berechtigungen", systemImage: "lock.shield") }
        }
        .frame(width: 540, height: 460)
        .padding(20)
    }

    // MARK: Tabs

    private var generalTab: some View {
        Form {
            Section("Status") {
                LabeledContent("Aktuell", value: coordinator.statusDescription)
                if let err = coordinator.lastError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
            }
            Section("Sprache") {
                Picker("Whisper-Sprachhinweis", selection: $languageHint) {
                    Text("Auto").tag("")
                    Text("Deutsch").tag("de")
                    Text("Englisch").tag("en")
                }
                .onChange(of: languageHint) { new in Settings.shared.languageHint = new }
            }
            Section("Über") {
                Text("VoiceType nutzt OpenAI Whisper für Transkription und Anthropic Claude für Modi „Nett“ und „Wut→Nett“. Audio wird zur Verarbeitung an OpenAI übertragen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var keysTab: some View {
        Form {
            Section("OpenAI (Whisper)") {
                SecureField("sk-…", text: $openAIKey)
                Text("Wird benötigt für alle drei Modi. Key liegt sicher im Keychain.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Anthropic (Claude)") {
                SecureField("sk-ant-…", text: $anthropicKey)
                Text("Nur für Modi „Nett“ und „Wut→Nett“ benötigt.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                HStack {
                    Spacer()
                    Button("Speichern") { saveAPIKeys() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!apiKeysDirty)
                }
            }
        }
        .formStyle(.grouped)
        .onDisappear { saveAPIKeys() }
    }

    private var shortcutsTab: some View {
        Form {
            Section("Shortcut-Modus") {
                Toggle("Klassische Shortcuts statt Fn-Modifier verwenden", isOn: $useFallback)
                Text(useFallback
                     ? "Nutze ⌘⌥R / ⌘⌥N / ⌘⌥W (Toggle: drücken zum Starten, drücken zum Stoppen)."
                     : "Push-to-Talk: Halte Fn+⇧ (Raw), Fn+⌃ (Nett), oder Fn+⌥ (Wut→Nett). Aufnahme stoppt beim Loslassen.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("Übernehmen") { applyShortcutMode() }
                        .disabled(useFallback == Settings.shared.useFallbackShortcuts)
                }
            }

            if useFallback {
                Section("Fallback-Shortcuts") {
                    KeyboardShortcuts.Recorder("Raw:", name: .fallbackRaw)
                    KeyboardShortcuts.Recorder("Nett:", name: .fallbackNice)
                    KeyboardShortcuts.Recorder("Wut→Nett:", name: .fallbackCalm)
                }
            } else {
                Section("Fn-Modifier (fest)") {
                    LabeledContent("Raw", value: "Fn + Shift")
                    LabeledContent("Nett", value: "Fn + Control")
                    LabeledContent("Wut→Nett", value: "Fn + Option")
                }
            }
        }
        .formStyle(.grouped)
    }

    private var permissionsTab: some View {
        Form {
            Section("Status der Berechtigungen") {
                permissionRow("Mikrofon", granted: micGranted, action: openMicSettings)
                permissionRow("Bedienungshilfen", granted: a11yGranted, action: openAccessibilitySettings)
                if !useFallback {
                    permissionRow("Eingabeüberwachung", granted: a11yGranted, action: openInputMonitoringSettings)
                }
            }
            Section {
                Button("Status aktualisieren") { permissionTrigger += 1 }
            }
            Section {
                Text("Bei Problemen: VoiceType vollständig beenden, in den Systemeinstellungen aus der Liste entfernen und wieder hinzufügen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .id(permissionTrigger)
    }

    // MARK: Persistenz

    /// Schreibt die State-Werte explizit in den Keychain. Wird durch den
    /// Speichern-Button und onDisappear getriggert — NICHT pro Tastendruck,
    /// sonst entstehen SwiftUI-Update-Loops (Keychain-Writes sind synchron).
    private func saveAPIKeys() {
        if (Settings.shared.openAIAPIKey ?? "") != openAIKey {
            Settings.shared.openAIAPIKey = openAIKey
        }
        if (Settings.shared.anthropicAPIKey ?? "") != anthropicKey {
            Settings.shared.anthropicAPIKey = anthropicKey
        }
    }

    private var apiKeysDirty: Bool {
        (Settings.shared.openAIAPIKey ?? "") != openAIKey
            || (Settings.shared.anthropicAPIKey ?? "") != anthropicKey
    }

    private func applyShortcutMode() {
        Settings.shared.useFallbackShortcuts = useFallback
        (NSApp.delegate as? AppDelegate)?.reloadShortcuts()
    }

    // MARK: Helpers

    @ViewBuilder
    private func permissionRow(_ title: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(granted ? .green : .red)
            Text(title)
            Spacer()
            if !granted {
                Button("Öffnen", action: action)
            }
        }
    }

    private var micGranted: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    private var a11yGranted: Bool {
        TextInserter.checkAccessibilityPermission(prompt: false)
    }

    private func openMicSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    private func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
}
