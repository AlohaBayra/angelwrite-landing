# VoiceType – Lokale Whisper-Integration (WhisperKit)
## Claude Code Prompts – in dieser Reihenfolge ausführen

---

## Schritt 0 – Vor dem ersten Prompt (manuell in Xcode)

Öffne das Projekt in Xcode, dann:
**File → Add Package Dependencies → URL eingeben:**
```
https://github.com/argmaxinc/WhisperKit
```
Version: **Up to Next Major** ab `0.9.0`
Target: `VoiceType`

Danach erst mit den Prompts starten.

---

## Prompt 1 – Transcriber-Protokoll + lokaler Transcriber

```
Lies VoiceType/Modules/WhisperAPITranscriber.swift.

Erstelle zwei neue Dateien:

--- VoiceType/Modules/Transcriber.swift ---
Ein protocol `Transcriber: AnyObject` mit drei Methoden, die exakt der
bestehenden WhisperAPITranscriber-Schnittstelle entsprechen:
  - func startSession(format: AVAudioFormat) throws
  - func process(buffer: AVAudioPCMBuffer)
  - func finishSession() async throws -> String

Füge außerdem am unteren Ende der Datei WhisperAPITranscriber.swift die
Conformance-Zeile hinzu:
  extension WhisperAPITranscriber: Transcriber {}

--- VoiceType/Modules/WhisperLocalTranscriber.swift ---
Eine final class WhisperLocalTranscriber: ObservableObject, Transcriber.

Sie soll:
1. Eine ModelState-Enum mit Fällen idle, loading, ready, error(String) definieren
   und als @Published var modelState: ModelState = .idle veröffentlichen.

2. Intern einen WhisperKit?-Wert halten (private var pipe: WhisperKit? = nil).

3. Dieselbe Audiofile-Logik wie WhisperAPITranscriber verwenden:
   - startSession: Temp-WAV anlegen (Name "voicetype-local-UUID.wav")
   - process: in AVAudioFile schreiben
   Diese beiden Methoden sind identisch mit WhisperAPITranscriber.

4. finishSession() async throws -> String:
   - audioFile = nil (schließt File-Handle)
   - Guard auf fileURL
   - defer: tempFile löschen
   - Falls pipe == nil: await prepare() aufrufen
   - Falls modelState == .error oder pipe immer noch nil: Fehler werfen
     ("Lokales Modell nicht bereit – bitte erst in den Einstellungen laden")
   - let results = try await pipe!.transcribe(audioPath: url.path)
   - return results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespaces)
   - Falls results leer: return ""

5. @MainActor func prepare() async:
   - Guard: pipe == nil, sonst return
   - modelState = .loading
   - do { pipe = try await WhisperKit(model: Settings.shared.whisperModelSize, verbose: false)
          modelState = .ready }
   - catch { modelState = .error(error.localizedDescription) }

6. func unload():
   - pipe = nil
   - modelState = .idle

Import: Foundation, AVFoundation, WhisperKit
```

---

## Prompt 2 – Settings erweitern

```
Lies VoiceType/Modules/Settings.swift vollständig.

Füge folgendes hinzu:

1. Direkt nach den bestehenden Imports, vor `final class Settings`:
   enum TranscriptionEngine: String {
       case cloud = "cloud"
       case local  = "local"
   }

2. In der Settings-Klasse zwei neue Keys (analog zu den bestehenden):
   private let transcriptionEngineKey = "transcriptionEngine"
   private let whisperModelSizeKey    = "whisperModelSize"

3. Zwei neue computed properties:

   var transcriptionEngine: TranscriptionEngine {
       get {
           let raw = UserDefaults.standard.string(forKey: transcriptionEngineKey) ?? "cloud"
           return TranscriptionEngine(rawValue: raw) ?? .cloud
       }
       set { UserDefaults.standard.set(newValue.rawValue, forKey: transcriptionEngineKey) }
   }

   var whisperModelSize: String {
       get { UserDefaults.standard.string(forKey: whisperModelSizeKey) ?? "base" }
       set { UserDefaults.standard.set(newValue, forKey: whisperModelSizeKey) }
   }

Keine anderen Änderungen.
```

---

## Prompt 3 – AppCoordinator umbauen

```
Lies VoiceType/Modules/AppCoordinator.swift vollständig.

Ändere folgendes:

1. Ersetze:
     private let whisper = WhisperAPITranscriber()
   durch:
     private let cloudTranscriber = WhisperAPITranscriber()
     let localTranscriber = WhisperLocalTranscriber()   // internal: SettingsView braucht Zugriff

   private var activeTranscriber: any Transcriber {
       Settings.shared.transcriptionEngine == .local ? localTranscriber : cloudTranscriber
   }

2. In startRecording(mode:):
   - Ersetze JEDEN Aufruf von `whisper.` durch `activeTranscriber.`
   - Die API-Key-Validierung für OpenAI (guard auf openAIAPIKey) soll nur noch
     prüfen wenn Settings.shared.transcriptionEngine == .cloud. Ist engine == .local,
     keinen OpenAI-Key-Check durchführen.
   - Beispiel:
     if Settings.shared.transcriptionEngine == .cloud {
         guard Settings.shared.openAIAPIKey?.isEmpty == false else {
             setState(.error("OpenAI API-Key fehlt")); return
         }
     }

3. In stopRecording():
   - Ersetze `whisper.finishSession()` durch `activeTranscriber.finishSession()`

4. Neue public Methode ergänzen (nach checkPermissionsOnStartup):
   /// Wärmt das lokale Modell im Hintergrund vor, wenn local engine gewählt ist.
   func warmUpLocalIfNeeded() {
       guard Settings.shared.transcriptionEngine == .local else { return }
       Task { await localTranscriber.prepare() }
   }

5. In checkPermissionsOnStartup() am Ende ergänzen:
   warmUpLocalIfNeeded()

Keine anderen Änderungen an der State-Machine oder den Sounds.
```

---

## Prompt 4 – SettingsView: neuer Transkription-Tab

```
Lies VoiceType/SettingsView.swift vollständig.

Ergänze einen neuen Tab "Transkription" zwischen dem "API-Keys"-Tab und dem
"Shortcuts"-Tab. Füge außerdem einen neuen State-Wert hinzu.

1. Neue State-Variablen (bei den anderen @State-Deklarationen oben):
   @State private var transcriptionEngine: TranscriptionEngine = Settings.shared.transcriptionEngine
   @State private var whisperModelSize: String = Settings.shared.whisperModelSize

2. Im body: TabView nach `.tabItem { Label("API-Keys", ...) }` einfügen:
   transcriptionTab.tabItem { Label("Transkription", systemImage: "waveform") }

3. Den neuen Tab als private var transcriptionTab: some View implementieren:

   Form {
       Section("Engine") {
           Picker("Transkription", selection: $transcriptionEngine) {
               Text("☁️  Cloud (OpenAI Whisper)").tag(TranscriptionEngine.cloud)
               Text("🖥  Lokal (auf diesem Mac)").tag(TranscriptionEngine.local)
           }
           .pickerStyle(.segmented)
           .onChange(of: transcriptionEngine) { engine in
               Settings.shared.transcriptionEngine = engine
               coordinator.warmUpLocalIfNeeded()
           }
       }

       if transcriptionEngine == .cloud {
           Section("OpenAI API-Key") {
               Text("Den OpenAI API-Key trägst du im Tab „API-Keys" ein.")
                   .font(.caption).foregroundStyle(.secondary)
               Text("Audio wird zur Verarbeitung an OpenAI übertragen.")
                   .font(.caption).foregroundStyle(.orange)
           }
       }

       if transcriptionEngine == .local {
           Section("Modell") {
               Picker("Größe", selection: $whisperModelSize) {
                   Text("Winzig – 75 MB (schnell, weniger genau)").tag("tiny")
                   Text("Klein – 142 MB (empfohlen)").tag("base")
                   Text("Mittel – 466 MB (langsamer, genauer)").tag("small")
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
                       Text("Wird geladen …").foregroundStyle(.secondary)
                   case .ready:
                       Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                       Text("Bereit – kein API-Key erforderlich").foregroundStyle(.green)
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
               Text("Audio bleibt vollständig auf deinem Mac. Kein OpenAI-Key benötigt für den Raw-Modus. Für Modi „Nett" und „Wut→Nett" ist weiterhin der Anthropic-Key erforderlich.")
                   .font(.caption).foregroundStyle(.secondary)
           }
       }
   }
   .formStyle(.grouped)

4. Im generalTab: Ersetze den bestehenden Über-Text durch einen dynamischen:
   Text(Settings.shared.transcriptionEngine == .local
       ? "VoiceType nutzt ein lokales Whisper-Modell für Transkription – Audio verlässt deinen Mac nicht. Anthropic Claude wird für Modi „Nett" und „Wut→Nett" genutzt."
       : "VoiceType nutzt OpenAI Whisper für Transkription und Anthropic Claude für Modi „Nett" und „Wut→Nett". Audio wird zur Verarbeitung an OpenAI übertragen.")
       .font(.caption)
       .foregroundStyle(.secondary)

5. Passe die frame-Höhe des TabView von 620 auf 680 an.

Keine anderen Änderungen.
```

---

## Prompt 5 – CLAUDE.md aktualisieren

```
Lies CLAUDE.md vollständig.

Aktualisiere folgende Abschnitte:

1. Im Abschnitt "Dependency" ergänze WhisperKit:
   - `WhisperKit` (https://github.com/argmaxinc/WhisperKit), `.upToNextMajor(from: "0.9.0")`.
     Für lokale Transkription auf Apple Silicon (Core ML). Nur auf macOS verfügbar.

2. Im Abschnitt "Wichtige Design-Entscheidungen" ergänze einen neuen Block:

   ### Lokale Transkription (WhisperKit)
   Wenn Settings.shared.transcriptionEngine == .local, übernimmt WhisperLocalTranscriber
   die Transkription komplett auf dem Gerät. WhisperKit nutzt Core ML und ist auf
   Apple Silicon (M1+) erheblich schneller als auf Intel. Das lokale Modell wird lazy
   geladen – beim ersten Aufnahme-Versuch oder per "Modell jetzt laden"-Button in den
   Settings. Die Instanz bleibt im Speicher, solange die App läuft (kein Reload nötig).
   Modell-Dateien liegen im HuggingFace-Cache (~/.cache/huggingface/) und überleben
   App-Neustarts. Beim Wechsel der Modellgröße wird die Instanz via unload() verworfen.

3. Im Abschnitt "Erweiterungen (nicht für V1)" die Zeile
   "- Whisper.cpp lokal als Offline-Engine"
   ersetzen durch:
   "- ✅ Lokale Transkription via WhisperKit (ab v0.3.0)"

4. Im Abschnitt "Bekannte Stolpersteine" ergänze:
   - **Lokales Modell lädt nicht** → Internetzugang beim ersten Download erforderlich
     (einmalig ~75–466 MB je nach Größe). Danach offline nutzbar.
   - **Transkriptions-Qualität lokal schlechter** → Modell "base" oder "small" wählen
     statt "tiny". Small ist auf Apple Silicon M1+ in Echtzeit nutzbar.
   - **WhisperKit-Build-Fehler** → Paket noch nicht in Xcode hinzugefügt.
     File → Add Package Dependencies → https://github.com/argmaxinc/WhisperKit

Version in CHANGELOG.md als [0.3.0] ergänzen mit den Änderungen:
- Lokale Transkription via WhisperKit (kein OpenAI-Key im Raw-Modus)
- Modellgrößen: tiny / base / small, wählbar in Settings
- Neuer Settings-Tab "Transkription"
- Automatisches Vorwärmen beim App-Start wenn lokale Engine aktiv
```

---

## Prompt 6 – Build testen

```
Führe folgenden Build-Befehl aus und berichte das Ergebnis:

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project VoiceType.xcodeproj \
           -scheme VoiceType \
           -configuration Debug \
           build \
           2>&1 | tail -50

Bei Fehlern: zeige mir die vollständige Fehlermeldung und behebe sie.
Häufige Ursachen:
- `WhisperKit` nicht als SPM-Dependency in Xcode eingetragen → kann nicht behoben
  werden ohne Xcode-UI, melde das klar.
- API-Drift in WhisperKit (z.B. transcribe() gibt anderen Typ zurück) →
  anpassen, Originaldokumentation beachten.
- @MainActor-Isolation bei WhisperLocalTranscriber → ggf. nonisolated oder
  Task { @MainActor in ... } ergänzen.
```

---

## Reihenfolge-Zusammenfassung

1. ✋ Xcode: WhisperKit-Package hinzufügen (manuell, einmalig)
2. 🤖 Prompt 1: Protokoll + WhisperLocalTranscriber
3. 🤖 Prompt 2: Settings erweitern
4. 🤖 Prompt 3: AppCoordinator umbauen
5. 🤖 Prompt 4: SettingsView – neuer Tab
6. 🤖 Prompt 5: CLAUDE.md + Changelog
7. 🤖 Prompt 6: Build-Test
