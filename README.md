# VoiceType

macOS-Menüleisten-App für Push-to-Talk-Diktat mit drei Modi:

| Halten | Modus | Was passiert |
|--------|-------|--------------|
| **Fn + ⇧** | **Raw** | Whisper-Transkription wörtlich einfügen |
| **Fn + ⌃** | **Nett** | Whisper → Claude poliert (Grammatik, Füllwörter) → einfügen |
| **Fn + ⌥** | **Wut→Nett** | Whisper → Claude entschärft (aggressiv → professionell) → einfügen |

Push-to-Talk: Aufnahme läuft solange du die Kombination hältst. Beim Loslassen wird der Text verarbeitet und an deiner Cursor-Position eingefügt.

Falls Fn-Shortcuts auf deinem Mac Probleme machen: in den Einstellungen kannst du auf klassische Shortcuts (⌘⌥R / ⌘⌥N / ⌘⌥W als Toggle) umschalten.

## Voraussetzungen

- macOS 13 Ventura oder neuer
- Xcode 15 oder neuer
- OpenAI API-Key (für Whisper) — https://platform.openai.com/api-keys
- Anthropic API-Key (für Claude, optional aber Modi „Nett" und „Wut→Nett" brauchen ihn) — https://console.anthropic.com/

## Build & Run

### Aus Xcode (empfohlen für Erst-Inbetriebnahme)

```bash
open VoiceType.xcodeproj
```

In Xcode:

1. Projekt-Navigator → blauer `VoiceType`-Eintrag → TARGETS `VoiceType` → Tab **Signing & Capabilities** → bei **Team** dein Apple-ID-Team auswählen.
2. **Product → Run** (⌘R).

Beim ersten Start fragt macOS nach Berechtigungen — siehe „Erst-Setup nach dem Start" unten.

### Aus der Kommandozeile

```bash
xcodebuild -project VoiceType.xcodeproj -scheme VoiceType -configuration Debug build
```

Falls `xcode-select -p` auf die Command Line Tools zeigt statt auf Xcode.app:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project VoiceType.xcodeproj -scheme VoiceType -configuration Debug build
```

Das fertige App-Bundle liegt unter `~/Library/Developer/Xcode/DerivedData/VoiceType-*/Build/Products/Debug/VoiceType.app`.

## Empfohlener Entwicklungs-Workflow: Claude Code

Für Iteration, Debugging und Erweiterungen ist **Claude Code** das richtige Werkzeug.

### Setup (einmalig, ca. 5 Minuten)

```bash
# Node.js (falls nicht vorhanden)
brew install node

# Claude Code installieren
npm install -g @anthropic-ai/claude-code

# Ins Projekt wechseln und starten
cd path/to/VoiceType
claude
```

### Erste Session

```
Lies CLAUDE.md vollständig. Dann prüfe via xcodebuild, ob das Projekt baut.
Wenn nicht, behebe die Build-Fehler. Berichte Status mit Übersicht der gefundenen Probleme.
```

### Häufige Folge-Aufgaben

- *„Aufnahme stoppt nicht zuverlässig beim Loslassen — debugge `ModifierShortcutWatcher.swift` mit zusätzlichen Log-Statements und teste das Verhalten."*
- *„Füge dem Settings-Fenster einen Test-Button pro Modus hinzu, der eine 3-Sekunden-Aufnahme macht und das Ergebnis im UI anzeigt statt einzufügen."*
- *„Optimiere die Whisper-Antwortzeit: prüfe ob wir die Audio-Datei kleiner machen können ohne Qualitätsverlust."*

## Erst-Setup nach dem Start

Beim ersten Start fragt macOS nach Berechtigungen:

1. **Mikrofon** — automatischer Dialog beim ersten Aufnahmeversuch → erlauben
2. **Bedienungshilfen** — manuell unter *Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen* → VoiceType aktivieren
3. **Eingabeüberwachung** (nur bei Fn-Modus) — *Systemeinstellungen → Datenschutz & Sicherheit → Eingabeüberwachung* → VoiceType aktivieren

Settings öffnen über das Menüleisten-Icon → *Einstellungen…* (oder ⌘,):

- **API-Keys** Tab: OpenAI- und Anthropic-Key eintragen (werden im macOS Keychain abgelegt)
- **Shortcuts** Tab: Fn-Modus oder Fallback-Modus wählen
- **Berechtigungen** Tab: Status der vier Permissions auf einen Blick

## Distribution

Da es jetzt ein vollwertiges App-Projekt ist, funktioniert in Xcode:

- **Product → Archive** → Distribute App → Developer ID (für Verteilung außerhalb des App Stores)
- oder Direct Distribution / Notarization über die übliche Xcode-UI

## Kosten-Überschlag

Für persönliche Nutzung typischerweise unter 5 €/Monat:

- **Whisper API**: $0.006 pro Audio-Minute
- **Claude API** (Modi Nett/Wut→Nett): ~$0.003 pro Aufnahme bei kurzen Texten

## Lizenz

MIT
