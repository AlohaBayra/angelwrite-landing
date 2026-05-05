# CLAUDE.md — Briefing für Claude Code

Lies diese Datei vollständig, bevor du Code änderst.

## Projekt

**VoiceType** ist eine macOS-Menüleisten-App für Push-to-Talk-Diktat mit drei Modi:

1. **Raw** (Fn+Shift halten) — Whisper-Transkription wörtlich einfügen
2. **Nett** (Fn+Control halten) — Whisper → Claude poliert (Grammatik, Füllwörter, Tonalität) → einfügen
3. **Wut→Nett** (Fn+Option halten) — Whisper → Claude entschärft komplett (aggressiv → professionell) → einfügen

Push-to-Talk: Aufnahme läuft solange die Kombo gehalten wird. Beim Loslassen wird verarbeitet und an Cursor-Position eingefügt.

## Nutzer-Kontext

Marcus Eichler, Founder ValueLift (Coaching/Leadership). Brauchst du nicht für Code-Entscheidungen, hilft aber beim Verstehen der Modi:
- Modus „Nett" wird viel für LinkedIn-Drafts und E-Mails genutzt
- Modus „Wut→Nett" wird für E-Mails an Kunden/Kollegen nach Frustration genutzt
- Sprache primär Deutsch, gelegentlich Englisch
- Keine Funktion darf Marcus' Stimme/Persönlichkeit überschreiben — Claude soll nur „lesbar machen", nicht umschreiben

## Projekttyp & Struktur

Das Projekt ist ein **vollwertiges macOS-App-Xcode-Projekt** (kein Swift Package mehr — die alte Package-Variante liegt unter `../VoiceType_alt/` als Read-only-Backup).

```
VoiceType/                              ← Repo-Root
├── VoiceType.xcodeproj                 ← Xcode-Projekt
├── VoiceType/                          ← Source-Folder (FileSystem-Synchronized Group)
│   ├── VoiceTypeApp.swift              App-Entry, AppDelegate, NSStatusItem, Shortcut-Setup
│   ├── SettingsView.swift              SwiftUI Settings (Tabs: Allgemein, Keys, Shortcuts, Permissions)
│   ├── Info.plist                      Bundle-Metadata, Permission-Strings, LSUIElement
│   ├── VoiceType.entitlements          App-Sandbox=NO, audio-input=YES
│   ├── Assets.xcassets/                AppIcon, AccentColor
│   └── Modules/
│       ├── AppCoordinator.swift        State-Machine, orchestriert Audio→Whisper→Claude→Insert
│       ├── ProcessingMode.swift        Enum mit System-Prompts für Claude
│       ├── AudioCapture.swift          AVAudioEngine Mikrofon-Tap
│       ├── WhisperAPITranscriber.swift WAV-File-Buffer + Multipart-Upload zu OpenAI
│       ├── ClaudePostProcessor.swift   Claude-Messages-API für Modi Nett/Wut→Nett
│       ├── ModifierShortcutWatcher.swift CGEventTap für Fn+Modifier-Erkennung
│       ├── TextInserter.swift          Pasteboard-Save → Cmd+V → Pasteboard-Restore
│       └── Settings.swift              UserDefaults + Keychain für API-Keys
├── CLAUDE.md
├── README.md
└── .gitignore
```

### Folge daraus für Code-Änderungen

- Neue Swift-Dateien einfach unter `VoiceType/` (oder `VoiceType/Modules/`) ablegen — Xcode 26 nutzt `PBXFileSystemSynchronizedRootGroup`, sie werden automatisch ins Target übernommen, kein pbxproj-Editing nötig.
- `Info.plist` und `VoiceType.entitlements` sind via `PBXFileSystemSynchronizedBuildFileExceptionSet` aus dem Resources-Phase ausgenommen — nicht versehentlich umbenennen oder verschieben.
- Build via `xcodebuild -project VoiceType.xcodeproj -scheme VoiceType -configuration Debug build` (Xcode-CLI muss aktiv sein, ggf. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` voranstellen falls `xcode-select -p` auf CLT zeigt).

### Dependency

- `KeyboardShortcuts` (https://github.com/sindresorhus/KeyboardShortcuts), exakt **1.10.0** gepinnt. Höhere Versionen verlangen den `#Preview`-Macro-Plugin und brechen außerhalb voller Xcode-Umgebungen.

## Wichtige Design-Entscheidungen

### Push-to-Talk via Modifier-only Shortcuts
Standard-Modus: Fn+Shift / Fn+Control / Fn+Option als gehaltene Kombinationen. Implementiert via `CGEventTap` auf `.flagsChanged` in `ModifierShortcutWatcher.swift`. Braucht **Input Monitoring** + **Bedienungshilfen** Permission.

### Fallback-Modus
Wenn der User in Settings „Fallback verwenden" aktiviert, werden stattdessen klassische Toggle-Shortcuts (⌘⌥R/N/W) via `KeyboardShortcuts`-Library aktiv. Wechsel ohne Neustart möglich, `AppDelegate.reloadShortcuts()` reinitialisiert.

### Whisper API statt Apple Speech
Bessere Qualität bei Fachbegriffen, Eigennamen und gemischten Sprachen. Trade-off: Audio geht zu OpenAI (im Settings-Tab transparent kommuniziert). Latenz typisch 1–3s pro Aufnahme.

### Audio-Format
16 kHz mono WAV — Whisper-optimal, ~32 KB/s. Dateien landen in `FileManager.default.temporaryDirectory` und werden nach Upload gelöscht.

### Pasteboard-basiertes Einfügen
Funktioniert universell (native, Web, Electron, Terminal). Klarer Trade-off: Zwischenablage wird kurz „belegt", aber sofort restored.

### API-Keys im Keychain
Niemals UserDefaults oder Plain-Files. Account-Namen: `openai`, `anthropic`. Service: `de.valuelift.voicetype`. Bundle-ID identisch zum alten Projekt, damit existierende Keychain-Einträge weitergenutzt werden.

### State-Machine
`AppState` in `AppCoordinator`: `.idle | .recording(mode) | .processing | .done | .error`. Nur ein State zur Zeit, keine parallelen Aufnahmen. Status-Icon spiegelt State direkt in Menüleiste.

### App-Sandbox
Aus (`com.apple.security.app-sandbox = false`). Grund: CGEventTap und globales Cmd-V-Simulieren funktionieren in Sandbox stark eingeschränkt oder gar nicht. Nicht ohne Rücksprache wieder einschalten.

## Nicht ändern ohne Rücksprache

- **Push-to-Talk-Verhalten** (drücken & halten, nicht toggle) — bewusster UX-Entscheid
- **Pasteboard-Restore-Delay** (0.4s) — kürzer = manche Apps verpassen den Paste, länger = User wartet
- **Whisper-Sample-Rate 16 kHz** — höher bringt nichts, Whisper resampled intern
- **System-Prompts in `ProcessingMode.swift`** — diese sind sorgfältig formuliert, nicht beiläufig kürzen
- **App-Sandbox-Status** (off) — sonst bricht CGEventTap

## Erste Aufgabe

1. Prüfe ob das Projekt baut:
   `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project VoiceType.xcodeproj -scheme VoiceType -configuration Debug build`
2. Falls Build-Fehler: behebe sie (häufig: Swift-6-Member-Visibility — ggf. fehlt explizites `import Combine` o.ä., oder API-Drift in KeyboardShortcuts).
3. Falls grün: in Xcode öffnen, in Signing das Apple-ID-Team setzen, ⌘R für Erst-Run.
4. Berichte Status.

## Bekannte Stolpersteine

- **CGEventTap funktioniert nicht** → Input Monitoring Permission fehlt. App muss in `System Settings → Privacy & Security → Input Monitoring` eingetragen sein.
- **Shortcut feuert nie** → Apps wie Karabiner-Elements können Modifier umschreiben. Im Zweifel kurz deaktivieren.
- **Whisper-Aufrufe schlagen fehl mit 401** → API-Key falsch oder leer. Settings → API-Keys prüfen.
- **Cmd+V wird simuliert, aber nichts wird eingefügt** → Bedienungshilfen-Permission fehlt, oder die Ziel-App hat fokus verloren während Processing.
- **Nach Permission-Erteilung passiert nichts** → manche Permission-Änderungen brauchen App-Neustart. Beim ersten Setup ist Beenden-und-Neustart oft die schnellste Lösung.
- **„Cannot find type X in scope" beim Editieren in Xcode** → Xcode-Index ist hinter dem Filesystem hinterher, weil Sync-Group neu indexiert. `Product → Clean Build Folder` und kurz warten.

## Erweiterungen (nicht für V1)

- Whisper.cpp lokal als Offline-Engine
- Diktat-Verlauf mit Suche
- Custom Modi mit eigenen System-Prompts
- Auto-Detection welche App fokussiert ist und kontextuelles Mode-Switching
