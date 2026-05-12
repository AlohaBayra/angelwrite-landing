# Claude Code Prompt – VoiceType: Drei App-Änderungen + Datenschutzerklärung

> **Verwendung:** Diesen Prompt vollständig in Claude Code (Terminal: `claude`) einfügen.
> Claude Code liest zuerst die Codebase, setzt dann alle drei Änderungen um und generiert abschließend die Datenschutzerklärung.

---

## Kontext

Du arbeitest an **VoiceType**, einer macOS-Anwendung, die Sprache per Mikrofon aufnimmt, in Text transkribiert und das Ergebnis in die Zwischenablage (Clipboard) legt. Die App ist in Swift/SwiftUI geschrieben und verwendet AVFoundation für die Audioaufnahme sowie eine externe Transkriptions-API (OpenAI Whisper).

---

## Phase 0 – Codebase verstehen (IMMER zuerst ausführen)

Bevor du irgendetwas änderst, verschaffe dir einen vollständigen Überblick:

```
1. Lies die gesamte Verzeichnisstruktur (find . -type f -name "*.swift" | sort)
2. Identifiziere die Hauptklassen/-dateien für:
   a) App-Einstiegspunkt (AppDelegate, @main)
   b) Audioaufnahme / AVAudioRecorder / AVCaptureSession
   c) Clipboard-Zugriff (NSPasteboard)
   d) Transkriptions-Logik (API-Calls, URLSession)
   e) Bestehende UserDefaults / Settings
3. Notiere dir die exakten Dateinamen und Zeilen, die du ändern wirst.
4. Prüfe, ob bereits ein Einwilligungs- oder Onboarding-Flow existiert.
```

Schreibe am Anfang deiner Antwort eine kurze **Codebase-Übersicht** (max. 10 Zeilen), bevor du mit den Änderungen beginnst.

---

## Änderung 1 – DSGVO-Einwilligungs-Dialog (Consent Flow)

### Ziel
Beim **allerersten App-Start** muss der Nutzer aktiv zustimmen, bevor die App auf das Mikrofon zugreift oder Daten an externe APIs sendet. Ohne Zustimmung startet die App nicht.

### Anforderungen

**1a. UserDefaults-Flag anlegen**
```swift
// Key: "hasUserConsented" (Bool, Default: false)
// Wird beim Consent-Dialog auf true gesetzt.
```

**1b. ConsentView / ConsentWindow erstellen**

Erstelle eine neue Datei `ConsentView.swift` mit folgendem Inhalt:

- **Titel:** „Datenschutz & Einwilligung"
- **Text (auf Deutsch):** Erkläre klar und verständlich:
  - Welche Daten erfasst werden (Audioaufnahmen, Transkriptionsergebnisse)
  - Dass Audiodaten zur Transkription an einen externen Dienst gesendet werden
  - Dass temporäre Audiodateien nach der Transkription automatisch gelöscht werden
  - Verweis auf die vollständige Datenschutzerklärung
- **Zwei Buttons:**
  - „Zustimmen & Fortfahren" → setzt `hasUserConsented = true`, schließt den Dialog
  - „Ablehnen & Beenden" → beendet die App (`NSApplication.shared.terminate(nil)`)
- Das Fenster ist **modal**, nicht schließbar (kein rotes X).

**1c. App-Einstiegspunkt anpassen**

```swift
let hasConsented = UserDefaults.standard.bool(forKey: "hasUserConsented")
if !hasConsented {
    // ConsentView als modales Fenster anzeigen
    // Hauptfenster erst NACH Einwilligung öffnen
}
```

**1d. Info.plist**

Stelle sicher, dass folgende Keys gesetzt sind:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>VoiceType benötigt Zugriff auf dein Mikrofon, um Spracheingaben aufzunehmen und in Text umzuwandeln.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>VoiceType verwendet Spracherkennung, um deine Aufnahmen zu transkribieren.</string>
```

---

## Änderung 2 – Clipboard-Fix (Alten Inhalt sichern & wiederherstellen)

### Problem
Die App überschreibt beim Einfügen des Transkriptionsergebnisses den bisherigen Clipboard-Inhalt des Nutzers unwiederbringlich.

### Implementierung

```swift
func pasteTranscriptionWithClipboardRestore(text: String) {
    let pasteboard = NSPasteboard.general

    // 1. Bestehenden Inhalt sichern
    let savedChangeCount = pasteboard.changeCount
    let savedItems = pasteboard.pasteboardItems?.compactMap { item -> NSPasteboardItem? in
        let newItem = NSPasteboardItem()
        for type in item.types {
            if let data = item.data(forType: type) {
                newItem.setData(data, forType: type)
            }
        }
        return newItem
    }

    // 2. Transkription in Clipboard schreiben
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)

    // 3. Cmd+V simulieren
    simulatePaste()

    // 4. Nach kurzer Verzögerung alten Inhalt wiederherstellen
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        if pasteboard.changeCount == savedChangeCount + 1,
           let items = savedItems, !items.isEmpty {
            pasteboard.clearContents()
            pasteboard.writeObjects(items)
        }
    }
}

func simulatePaste() {
    let source = CGEventSource(stateID: .hidSystemState)
    let vKeyCode: CGKeyCode = 0x09
    let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
    cmdDown?.flags = .maskCommand
    let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
    cmdUp?.flags = .maskCommand
    cmdDown?.post(tap: .cgAnnotatedSessionEventTap)
    cmdUp?.post(tap: .cgAnnotatedSessionEventTap)
}
```

Ersetze alle bestehenden direkten `NSPasteboard.general.setString(...)` Aufrufe nach der Transkription mit `pasteTranscriptionWithClipboardRestore(text:)`.

---

## Änderung 3 – Automatische Löschroutine für Audiodateien

### Implementierung

**Aufnahme immer im temporären Verzeichnis ablegen:**
```swift
let tempDir = FileManager.default.temporaryDirectory
let audioFileName = "voicetype_recording_\(UUID().uuidString).m4a"
let audioFileURL = tempDir.appendingPathComponent(audioFileName)
```

**Löschfunktion:**
```swift
func deleteTemporaryAudioFile(at url: URL) {
    guard FileManager.default.fileExists(atPath: url.path) else { return }
    do {
        try FileManager.default.removeItem(at: url)
    } catch {
        print("[VoiceType] Fehler beim Löschen: \(error.localizedDescription)")
    }
}
```

**Aufruf nach Transkription (Erfolg UND Fehler):**
```swift
func onTranscriptionCompleted(text: String, audioFileURL: URL) {
    pasteTranscriptionWithClipboardRestore(text: text)
    deleteTemporaryAudioFile(at: audioFileURL)
}

func onTranscriptionFailed(error: Error, audioFileURL: URL) {
    deleteTemporaryAudioFile(at: audioFileURL)
}
```

**Aufräumen beim App-Beenden:**
```swift
func cleanupAllTemporaryAudioFiles() {
    let tempDir = FileManager.default.temporaryDirectory
    guard let files = try? FileManager.default.contentsOfDirectory(
        at: tempDir, includingPropertiesForKeys: nil
    ) else { return }
    files.filter {
        $0.lastPathComponent.hasPrefix("voicetype_recording_") && $0.pathExtension == "m4a"
    }.forEach { try? FileManager.default.removeItem(at: $0) }
}
```

---

## Phase 4 – Tests & Verifikation

```
1. Build: xcodebuild build (muss ohne Fehler durchlaufen)
2. Consent-Flow: UserDefaults löschen → App neu starten → Dialog erscheint?
3. Clipboard-Fix: Text in Clipboard → VoiceType nutzen → ursprünglicher Text wieder da?
4. Löschroutine: Nach Transkription keine Audiodatei mehr im Temp-Verzeichnis?
```

---

## Zusammenfassung der Datei-Änderungen

| Datei | Aktion |
|---|---|
| `ConsentView.swift` | NEU erstellen |
| `AppDelegate.swift` / `@main` | Consent-Check beim Start ergänzen |
| `Info.plist` | Mikrofon- & Speech-Usage-Description prüfen/ergänzen |
| `[Recorder/TranscriptionController].swift` | Clipboard-Fix + Löschroutine integrieren |

---

*Prompt erstellt für VoiceType (macOS) · Stand: Mai 2026*
