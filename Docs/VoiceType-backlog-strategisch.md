# VoiceType – Strategischer Backlog & Wettbewerbsvergleich

**Stand:** v0.2.0 · Mai 2026  
**Basis:** Wispr-Flow-Nutzerbeschwerden + VoiceType-Codebase-Analyse

---

## Was VoiceType bereits besser macht als Wispr Flow

Bevor wir den Backlog aufbauen: VoiceType hat durch seinen nativen Swift-Ansatz mehrere der größten Wispr-Flow-Schmerzpunkte **von Haus aus gelöst** — ohne dass dafür ein einziges Feature gebaut werden muss.

| Wispr-Flow-Problem (Nutzerbeschwerden) | VoiceType-Status |
|----------------------------------------|-----------------|
| 800 MB RAM im Idle (Electron) | ✅ Native macOS — Bruchteil davon |
| 8–10 Sek. Startzeit | ✅ Menüleiste startet sofort |
| Friert Ziel-App ein | ✅ Kein Electron-Konflikt |
| Screenshots werden in Cloud gesendet | ✅ Kein Screenshot-Tracking |
| Kein Datenschutz-Overblick | ✅ Nur Audio für Diktate, transparent |
| iOS-Popup-Friction | ✅ Nicht relevant (Mac-only, Push-to-Talk) |
| Kontext-Detection ohne Zustimmung | ✅ Expliziter Modus-Wahl durch User (R/N/W) |

**Das ist die eigentliche Positionierung von VoiceType:** Nicht weniger Features — sondern weniger Overhead, mehr Kontrolle, more intentional.

---

## Backlog — nach Wert sortiert

---

### EPIC 1 – Offline-Modus (Whisper.cpp lokal)
**Wert: Kritisch | Aufwand: Hoch | bereits in CLAUDE.md vorgesehen**

#### Problem
VoiceType schickt Audio zu OpenAI (Whisper API). Das ist bewusster Trade-off, steht transparent in den Settings — trotzdem ist es ein Ausschlusskriterium für:
- Anwälte, Ärzte, Berater (Vertraulichkeitspflicht)
- Nutzer ohne stabiles Internet (Zug, Flugzeug, ländlich)
- Alle die für sensible Diktate keine Cloud wollen

Wispr Flow baut das explizit **nicht** — cloud-only ist deren erklärte Strategie. Das ist VoiceTypes größtes strategisches Fenster.

#### Was gebaut wird
Whisper.cpp-Integration als lokale Engine. Zwei Modi in Settings wählbar:
- **Cloud** (Standard): OpenAI Whisper API, beste Qualität, ~1–3s Latenz
- **Lokal**: Whisper.cpp auf dem Mac, kein Internet nötig, Daten verlassen nie das Gerät

Modell-Download (small/medium/large) einmalig aus dem Settings-Tab. Fortschrittsanzeige beim ersten Download.

#### Warum #1
Kein direkter Konkurrent in dieser Qualitätsklasse bietet das. Für Compliance-Berufe ist es kein Feature — es ist das Kaufargument.

---

### EPIC 2 – Diktat-Verlauf
**Wert: Hoch | Aufwand: Mittel | bereits in CLAUDE.md vorgesehen**

#### Problem
Jede Aufnahme ist nach dem Einfügen weg. Wenn Cmd+V sich in die falsche App einfügt, wenn der Text zu lang war und abgeschnitten wurde, wenn man 10 Minuten später merkt dass man das Diktat nochmal braucht — es gibt keinen Rückweg.

#### Was gebaut wird
Lokale Datenbank (Core Data oder SQLite) speichert jede Aufnahme mit:
- Zeitstempel
- Roh-Transkript (Whisper-Output)
- Finaler Text (nach Claude-Processing)
- Genutzter Modus (R/N/W)
- Dauer der Aufnahme

Settings-Tab "Verlauf" zeigt die letzten N Einträge (konfigurierbar). Klick auf Eintrag kopiert in Zwischenablage. Suche über Volltext. Automatische Löschung nach konfigurierbaren Tagen (Default: 30).

#### Warum #2
Datenverlust ist das Horror-Szenario. Der Verlauf gibt Sicherheit und macht VoiceType zur ernsthaften Arbeits-App statt zum Experiment.

---

### EPIC 3 – Kontext-Modi (App-Detection)
**Wert: Hoch | Aufwand: Mittel | bereits in CLAUDE.md vorgesehen**

#### Problem
Derzeit wählt der Nutzer den Modus manuell per Tastenkombination (Fn+Shift/Control/Option). Das ist gut — aber es gibt Kontexte die immer gleich sind: In Slack will Marcus immer "Nett", im Terminal immer "Raw", in Mail oft "Wut→Nett".

#### Was gebaut wird
Optionales App-Mapping: In Settings kann pro App festgelegt werden, welcher Modus als Standard vorbelegt ist wenn diese App im Fokus ist. Push-to-Talk-Verhalten bleibt — der Modifier wählt weiter den Modus. Aber der "Nett"-Modifier landet bei aktivem Slack automatisch mit dem Slack-optimierten Prompt statt dem generischen.

Alternativ/zusätzlich: Pro App kann ein eigener System-Prompt hinterlegt werden (z. B. "Slack: immer casual, keine Formalitäten").

#### Warum #3
Wispr Flow bewirbt genau das als Premium-Feature ("Personalized Style by app"). VoiceType kann das tiefer integrieren — weil der Nutzer aktiv entscheidet statt dass die App heimlich trackt.

---

### EPIC 4 – Latenz-Feedback & Fehlerklärheit
**Wert: Mittel-Hoch | Aufwand: Niedrig**

#### Problem
Im Zustand `.processing` sieht der Nutzer "Verarbeite…" in der Menüleiste — aber kein Feedback wie lange es noch dauert, ob etwas schiefläuft, oder warum ein Fehler aufgetreten ist. Fehler-Strings wie "The operation couldn't be completed" sind nicht hilfreich.

#### Was gebaut wird
- Animiertes Icon während Processing (Pulsing-Punkt oder Spinner)
- Klartextfehler statt Raw-Error-Messages: "OpenAI nicht erreichbar — Internetverbindung prüfen" statt Roher NSError
- Timeout nach konfigurierbarer Zeit (Default 15s) mit klarem Hinweis
- Notification bei Fertigstellung (optional, für lange Diktate)

#### Warum #4
Kleiner Aufwand, riesiger UX-Gewinn. Vertrauen in das Tool entsteht durch vorhersehbares, erklärendes Verhalten — nicht durch Stille.

---

### EPIC 5 – Vierter Modus: "Prompt" (freies System-Prompt per Shortcut)
**Wert: Mittel | Aufwand: Niedrig**

#### Problem
Die drei Modi (Raw, Nett, Wut→Nett) sind fest. Für LinkedIn-Posts, Zusammenfassungen oder andere spezifische Anforderungen gibt es keinen Weg ohne Settings-Eingriff. Jedes Mal den Prompt in Settings umzuschreiben ist zu viel Friction.

#### Was gebaut wird
Ein optionaler vierter Slot (Fn+Cmd als Shortcut) mit frei konfigurierbarem System-Prompt. Name und Prompt vollständig in Settings definierbar. Marcus könnte das z. B. als "LinkedIn" konfigurieren mit dem LinkedIn-Post-Prompt. Andere Nutzer als "Zusammenfassung", "Code-Kommentar", etc.

Alternativ: Bis zu 3 zusätzliche Custom-Slots (Fn+1, Fn+2, Fn+3) mit jeweils eigenem Namen und Prompt.

#### Warum #5
Der bestehende Settings-Tab "Prompts" zeigt, dass Editierbarkeit bereits gewünscht ist. Der nächste Schritt ist Schnellzugriff ohne Settings zu öffnen.

---

### EPIC 6 – Onboarding & Permission-Flow
**Wert: Mittel | Aufwand: Niedrig**

#### Problem
Beim ersten Start muss der Nutzer selbst herausfinden, dass er Input Monitoring, Bedienungshilfen und Mikrofon-Berechtigung braucht. Der Settings-Tab "Berechtigungen" existiert — aber beim ersten Fehler (kein Ton, kein Einfügen) ist die Verbindung unklar.

#### Was gebaut wird
Einmaliger Setup-Wizard beim Erst-Start: 3 Schritte, jeder mit "Berechtigung erteilen"-Button der direkt zu System-Einstellungen springt. Grünes Häkchen wenn Permission erteilt. Erst nach allen drei Haken ist der "Fertig"-Button aktiv. Nach Setup: kurzes 10-Sekunden-Demo-Diktat im Tutorial-Modus.

#### Warum #6
Die häufigsten Supportfragen bei Diktier-Tools sind Berechtigungs-Probleme. Ein guter Onboarding-Flow reduziert Frustration beim ersten Eindruck — der entscheidendste Moment für Retention.

---

## VoiceType vs. Wispr Flow — direkte Gegenüberstellung

| Dimension | VoiceType v0.2 | Wispr Flow (aktuell) |
|-----------|----------------|----------------------|
| **Plattform** | macOS native (Swift) | Electron (Mac + Windows) |
| **Performance** | ✅ Minimal-Footprint | ❌ 800 MB RAM idle |
| **Datenschutz** | ✅ Kein Screenshot-Tracking | ❌ Screenshots zur Kontext-Erfassung |
| **Interaktion** | Push-to-Talk (bewusst) | Immer-aktiv (kontinuierlich) |
| **Modus-Wahl** | Explizit durch User | KI-automatisch |
| **Offline** | 🔜 Roadmap (Whisper.cpp) | ❌ Cloud-only, kein Plan |
| **Verlauf** | 🔜 Roadmap | ✅ Vorhanden |
| **App-Kontext** | 🔜 Roadmap | ✅ Vorhanden (mit Tracking) |
| **Mobile** | ❌ Mac-only | ✅ iOS + Android |
| **Preis** | Selbst gehostet (API-Costs) | $16–19/Monat |
| **Team-Features** | ❌ | ✅ Vorhanden |

---

## Strategische Schlussfolgerung

VoiceType hat eine klare Identität die Wispr Flow strukturell nicht kopieren kann: **intentional, privat, nativ.**

Wispr Flow optimiert auf Enterprise-Wachstum, Team-Features und mobile Expansion. Das zwingt sie zu Kompromissen (Electron für Windows-Parität, Cloud-only für Skalierung, Screenshot-Tracking für Kontext).

VoiceType kann genau die Zielgruppe bedienen, die Wispr Flow verliert: Power-User, Solopreneure, Freelancer in Compliance-Berufen, und alle die wollen dass ihr Tool tut was sie sagen — nicht was die KI für richtig hält.

**Die eine Frage die alles entscheidet:** Will VoiceType ein Tool für Marcus bleiben, oder soll es für andere veröffentlicht werden? Wenn Letzteres — dann ist EPIC 6 (Onboarding) die erste Investition, und Offline (EPIC 1) das Alleinstellungsmerkmal.

---

*Erstellt auf Basis von: VoiceType v0.2.0 Codebase, CLAUDE.md, Wispr-Flow-Nutzerbeschwerden (Reddit, Medium, G2), Wispr-Flow-Changelog Mai 2026*
