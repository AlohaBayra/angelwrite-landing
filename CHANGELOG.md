# Changelog

Alle relevanten Änderungen an VoiceType werden hier dokumentiert.

## [0.3.0] - 2026-05-07

### Hinzugefügt
- Lokale Transkription via WhisperKit (kein OpenAI-Key im Raw-Modus)
- Modellgrößen: tiny / base / small, wählbar in Settings
- Neuer Settings-Tab "Transkription"
- Automatisches Vorwärmen beim App-Start wenn lokale Engine aktiv

## [0.2.0] - 2026-05-05

### Hinzugefügt
- Editierbare System-Prompts für Modi "Nett" und "Wut→Nett"
- Neuer Settings-Tab "Prompts" mit TextEditor pro Modus
- "Auf Default zurücksetzen"-Funktion pro Prompt
- Persistente Speicherung der Custom-Prompts in UserDefaults

## [0.1.0] - 2026-05-05

### Hinzugefügt
- Erste lauffähige Version
- Push-to-Talk via Fn+Shift / Fn+Control / Fn+Option
- Drei Modi: Raw, Nett, Wut→Nett
- Whisper API Integration für Transkription
- Claude API Integration für Post-Processing
- Keychain-basierte API-Key-Speicherung
- Settings-UI mit Tabs für API-Keys, Shortcuts, Berechtigungen
- Menüleisten-only-App (LSUIElement)
