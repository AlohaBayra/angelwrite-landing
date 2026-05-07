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

    @State private var nicePrompt: String = ProcessingMode.getCurrentPrompt(for: .nice)
    @State private var calmPrompt: String = ProcessingMode.getCurrentPrompt(for: .calm)
    @State private var showDefaultNice: Bool = false
    @State private var showDefaultCalm: Bool = false
    @FocusState private var niceFocused: Bool
    @FocusState private var calmFocused: Bool

    @State private var transcriptionEngine: TranscriptionEngine = Settings.shared.transcriptionEngine
    @State private var whisperModelSize: String = Settings.shared.whisperModelSize

    var body: some View {
        TabView {
            generalTab.tabItem { Label("Allgemein", systemImage: "gear") }
            keysTab.tabItem { Label("API-Keys", systemImage: "key.fill") }
            transcriptionTab.tabItem { Label("Transkription", systemImage: "waveform") }
            shortcutsTab.tabItem { Label("Shortcuts", systemImage: "command") }
            promptsTab.tabItem { Label("Prompts", systemImage: "text.bubble") }
            permissionsTab.tabItem { Label("Berechtigungen", systemImage: "lock.shield") }
        }
        .frame(width: 600, height: 680)
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
                LabeledContent("Version", value: appVersionString)
                Text(Settings.shared.transcriptionEngine == .local
                    ? "VoiceType nutzt ein lokales Whisper-Modell für Transkription \u{2013} Audio verlässt deinen Mac nicht. Anthropic Claude wird für Modi \u{201E}Nett\u{201C} und \u{201E}Wut\u{2192}Nett\u{201C} genutzt."
                    : "VoiceType nutzt OpenAI Whisper für Transkription und Anthropic Claude für Modi \u{201E}Nett\u{201C} und \u{201E}Wut\u{2192}Nett\u{201C}. Audio wird zur Verarbeitung an OpenAI übertragen.")
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

    private var transcriptionTab: some View {
        Form {
            Section("Engine") {
                Picker("Transkription", selection: $transcriptionEngine) {
                    Text("\u{2601}\u{FE0F}  Cloud (OpenAI Whisper)").tag(TranscriptionEngine.cloud)
                    Text("\u{1F5A5}  Lokal (auf diesem Mac)").tag(TranscriptionEngine.local)
                }
                .pickerStyle(.segmented)
                .onChange(of: transcriptionEngine) { engine in
                    Settings.shared.transcriptionEngine = engine
                    coordinator.warmUpLocalIfNeeded()
                }
            }

            if transcriptionEngine == .cloud {
                Section("OpenAI API-Key") {
                    Text("Den OpenAI API-Key trägst du im Tab \u{201E}API-Keys\u{201C} ein.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Audio wird zur Verarbeitung an OpenAI übertragen.")
                        .font(.caption).foregroundStyle(.orange)
                }
            }

            if transcriptionEngine == .local {
                Section("Modell") {
                    Picker("Größe", selection: $whisperModelSize) {
                        Text("Winzig \u{2013} 75 MB (schnell, weniger genau)").tag("tiny")
                        Text("Klein \u{2013} 142 MB (empfohlen)").tag("base")
                        Text("Mittel \u{2013} 466 MB (langsamer, genauer)").tag("small")
                    }
                    .onChange(of: whisperModelSize) { size in
                        Settings.shared.whisperModelSize = size
                        coordinator.localTranscriber.unload()
                    }
                }

                Section("Modell-Status") {
                    let state = coordinator.localTranscriber.modelState
                    HStack {
                        switch state {
                        case .idle:
                            Image(systemName: "arrow.down.circle").foregroundStyle(.secondary)
                            Text("Nicht geladen").foregroundStyle(.secondary)
                        case .loading:
                            ProgressView().scaleEffect(0.7)
                            Text("Wird geladen \u{2026}").foregroundStyle(.secondary)
                        case .ready:
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text("Bereit \u{2013} kein API-Key erforderlich").foregroundStyle(.green)
                        case .error(let msg):
                            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
                            Text(msg).foregroundStyle(.red).font(.caption)
                        }
                        Spacer()
                    }
                    if case .idle = state {
                        Button("Modell jetzt laden") {
                            Task { await coordinator.localTranscriber.prepare() }
                        }
                    }
                    if case .error = state {
                        Button("Erneut versuchen") {
                            coordinator.localTranscriber.unload()
                            Task { await coordinator.localTranscriber.prepare() }
                        }
                    }
                }

                Section {
                    Text("Audio bleibt vollständig auf deinem Mac. Kein OpenAI-Key benötigt für den Raw-Modus. Für Modi \u{201E}Nett\u{201C} und \u{201E}Wut\u{2192}Nett\u{201C} ist weiterhin der Anthropic-Key erforderlich.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
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

    private var promptsTab: some View {
        Form {
            Section {
                Text("Diese Anweisungen sagen Claude, wie er deinen Text formen soll. Sei konkret, was bleiben soll und was sich ändern soll. Bei Problemen kannst du jederzeit auf den Original-Prompt zurücksetzen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            promptSection(
                title: "Modus \u{201E}Nett\u{201C}",
                subtitle: "Whisper → Claude poliert (Grammatik, Füllwörter, Tonalität)",
                text: $nicePrompt,
                isFocused: $niceFocused,
                isCustom: niceIsCustom,
                onReset: {
                    ProcessingMode.resetToDefault(for: .nice)
                    nicePrompt = ProcessingMode.defaultNicePrompt
                },
                onShowDefault: { showDefaultNice = true }
            )
            .onChange(of: niceFocused) { focused in
                if !focused { saveNicePrompt() }
            }

            promptSection(
                title: "Modus \u{201E}Wut→Nett\u{201C}",
                subtitle: "Whisper → Claude entschärft (aggressiv → professionell)",
                text: $calmPrompt,
                isFocused: $calmFocused,
                isCustom: calmIsCustom,
                onReset: {
                    ProcessingMode.resetToDefault(for: .calm)
                    calmPrompt = ProcessingMode.defaultCalmPrompt
                },
                onShowDefault: { showDefaultCalm = true }
            )
            .onChange(of: calmFocused) { focused in
                if !focused { saveCalmPrompt() }
            }
        }
        .formStyle(.grouped)
        .onDisappear {
            saveNicePrompt()
            saveCalmPrompt()
        }
        .sheet(isPresented: $showDefaultNice) {
            defaultPromptSheet(
                title: "Original-Prompt: Nett",
                text: ProcessingMode.defaultNicePrompt,
                isPresented: $showDefaultNice
            )
        }
        .sheet(isPresented: $showDefaultCalm) {
            defaultPromptSheet(
                title: "Original-Prompt: Wut→Nett",
                text: ProcessingMode.defaultCalmPrompt,
                isPresented: $showDefaultCalm
            )
        }
    }

    @ViewBuilder
    private func promptSection(
        title: String,
        subtitle: String,
        text: Binding<String>,
        isFocused: FocusState<Bool>.Binding,
        isCustom: Bool,
        onReset: @escaping () -> Void,
        onShowDefault: @escaping () -> Void
    ) -> some View {
        Section {
            HStack(spacing: 6) {
                Text(title).font(.headline)
                if isCustom {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.blue)
                    Text("Eigener Prompt aktiv")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                Spacer()
            }
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: text)
                .focused(isFocused)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 180, maxHeight: 220)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color(NSColor.textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            HStack {
                Button("Auf Default zurücksetzen", action: onReset)
                    .controlSize(.small)
                    .disabled(!isCustom)
                Button("Default anzeigen", action: onShowDefault)
                    .controlSize(.small)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func defaultPromptSheet(title: String, text: String, isPresented: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            ScrollView {
                Text(text)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
            .background(Color(NSColor.textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            HStack {
                Button("Kopieren") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                Spacer()
                Button("Schließen") { isPresented.wrappedValue = false }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 600, height: 500)
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

    /// True wenn der Editor-Inhalt vom Default abweicht. Trimmt Whitespace,
    /// damit „nur Leerzeichen" nicht als Custom gewertet wird.
    private var niceIsCustom: Bool {
        let trimmed = nicePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && nicePrompt != ProcessingMode.defaultNicePrompt
    }

    private var calmIsCustom: Bool {
        let trimmed = calmPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && calmPrompt != ProcessingMode.defaultCalmPrompt
    }

    /// Wird beim Verlieren des Fokus und beim Tab-/Window-Verlassen aufgerufen.
    /// Schreibt nur, wenn sich der zu speichernde Wert vom aktuell persistierten
    /// unterscheidet — sonst Update-Loop-Risiko bei häufigen Tab-Wechseln.
    private func saveNicePrompt() {
        let target = normalizedTarget(editor: nicePrompt, default: ProcessingMode.defaultNicePrompt)
        if target != Settings.shared.customNicePrompt {
            if target.isEmpty {
                ProcessingMode.resetToDefault(for: .nice)
            } else {
                ProcessingMode.setCustomPrompt(target, for: .nice)
            }
        }
    }

    private func saveCalmPrompt() {
        let target = normalizedTarget(editor: calmPrompt, default: ProcessingMode.defaultCalmPrompt)
        if target != Settings.shared.customCalmPrompt {
            if target.isEmpty {
                ProcessingMode.resetToDefault(for: .calm)
            } else {
                ProcessingMode.setCustomPrompt(target, for: .calm)
            }
        }
    }

    /// Editor-Inhalt → Speicherwert. Leer (auch nur Whitespace) und „identisch
    /// zum Default" bedeuten beide: keinen Custom hinterlegen.
    private func normalizedTarget(editor: String, default defaultText: String) -> String {
        let trimmed = editor.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || editor == defaultText {
            return ""
        }
        return editor
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

    /// Liest CFBundleShortVersionString und CFBundleVersion aus dem geladenen
    /// App-Bundle. Format: "VoiceType 0.2.0 (Build 2)".
    private var appVersionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "VoiceType \(version) (Build \(build))"
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
