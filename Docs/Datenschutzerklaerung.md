# Datenschutzerklärung – VoiceType

**Stand:** Mai 2026
**Anwendung:** VoiceType für macOS
**Verantwortlicher:** [Name / Firma des App-Entwicklers] · [E-Mail] · [Adresse]

---

## 1. Überblick und Grundsätze

VoiceType ist eine macOS-Anwendung, die Spracheingaben über das Mikrofon des Geräts aufnimmt und in Text umwandelt. Der erkannte Text wird direkt in die aktive Anwendung des Nutzers eingefügt.

Wir verarbeiten **so wenig Daten wie möglich** und löschen temporäre Dateien automatisch. Ohne ausdrückliche Einwilligung des Nutzers wird die App nicht gestartet und es werden keinerlei Daten erhoben.

---

## 2. Verantwortlicher im Sinne der DSGVO

```
[Vollständiger Name oder Firmenname]
[Straße, Hausnummer]
[PLZ, Ort]
[Land]
E-Mail: [datenschutz@beispiel.de]
```

---

## 3. Welche Daten werden verarbeitet?

### 3.1 Audioaufnahmen (temporär, lokal)

- **Was:** Kurze Audioschnipsel, die während einer Sprachaufnahme entstehen.
- **Wo:** Ausschließlich im temporären Systemverzeichnis des Geräts (`/tmp` bzw. `NSTemporaryDirectory()`). Nicht in iCloud, nicht in App-Dokumenten, nicht auf externen Servern (außer für die Transkription, siehe 3.2).
- **Wie lange:** Die Datei wird **unmittelbar nach Abschluss der Transkription** automatisch gelöscht — unabhängig davon, ob die Transkription erfolgreich war. Beim Beenden der App werden alle verbleibenden temporären Dateien bereinigt.
- **Rechtsgrundlage:** Einwilligung des Nutzers (Art. 6 Abs. 1 lit. a DSGVO).

### 3.2 Übertragung an externe Transkriptions-API

Sofern VoiceType eine externe API für die Spracherkennung nutzt, werden Audiodaten verschlüsselt (TLS) an den entsprechenden Dienst übertragen:

| Anbieter | Zweck | Datenschutzerklärung |
|---|---|---|
| [z. B. OpenAI, Inc.] | Sprachtranskription via Whisper API | [https://openai.com/privacy] |

Die Übertragung erfolgt **nur nach ausdrücklicher Einwilligung**. Ohne Einwilligung findet keine Übertragung statt. Wenn ausschließlich Apple's On-Device Speech Recognition genutzt wird, verlassen keinerlei Audiodaten das Gerät.

### 3.3 Transkriptionsergebnisse (Zwischenablage)

- Der erkannte Text wird in die Zwischenablage (Clipboard) des Betriebssystems geschrieben, um ihn in die aktive App einzufügen.
- Der zuvor in der Zwischenablage befindliche Inhalt wird unmittelbar nach dem Einfügevorgang automatisch wiederhergestellt.
- VoiceType liest den Clipboard-Inhalt ausschließlich zum Zweck der Wiederherstellung aus — keine Analyse, keine Speicherung, keine Weitergabe.

### 3.4 Einwilligungsstatus

- **Was:** Ein einzelner boolescher Wert (ja/nein), ob der Nutzer der Datenschutzerklärung zugestimmt hat.
- **Wo:** Lokal in den App-Einstellungen des Betriebssystems (macOS UserDefaults / `~/Library/Preferences`).
- **Keine Weitergabe** an Dritte.

### 3.5 Was wir NICHT erheben

- Keine Nutzungsstatistiken oder Analytics
- Keine Absturz-Berichte (Crash Reports) an externe Dienste
- Keine Gerätekennungen, IP-Adressen oder Standortdaten
- Kein dauerhaftes Speichern von Transkripten oder Audiodateien

---

## 4. Zwecke der Datenverarbeitung

| Datenart | Zweck | Rechtsgrundlage |
|---|---|---|
| Audioaufnahme | Spracherkennung / Transkription | Einwilligung (Art. 6 I a DSGVO) |
| API-Übertragung | Transkription durch Drittanbieter | Einwilligung (Art. 6 I a DSGVO) |
| Clipboard (temporär) | Einsetzen des Transkripts in aktive App | Berechtigtes Interesse (Art. 6 I f DSGVO) |
| Einwilligungsstatus | Nachweis der erteilten Einwilligung | Rechtliche Verpflichtung (Art. 6 I c DSGVO) |

---

## 5. Einwilligung und Widerruf

### 5.1 Einwilligung beim ersten Start

Beim ersten Start der App wird ein Einwilligungsdialog angezeigt. Der Nutzer muss aktiv zustimmen, bevor:
- das Mikrofon aktiviert wird,
- Audiodaten verarbeitet oder übertragen werden,
- die App in den Vollbetrieb übergeht.

Eine Ablehnung beendet die App. Die Nutzung ohne Einwilligung ist nicht möglich.

### 5.2 Widerruf der Einwilligung

Die Einwilligung kann jederzeit widerrufen werden durch:
- **Deinstallation der App** (löscht alle lokalen App-Daten einschließlich des Einwilligungsstatus)
- **Zurücksetzen der App-Einstellungen** über die macOS-Systemeinstellungen → Datenschutz & Sicherheit → Mikrofon
- **Schreiben an:** [datenschutz@beispiel.de]

Nach dem Widerruf werden keine weiteren Daten erhoben. Bereits bei Drittanbietern verarbeitete Daten unterliegen deren jeweiliger Datenschutzerklärung.

---

## 6. Datensicherheit

- Audiodateien werden ausschließlich im geschützten temporären Systemverzeichnis abgelegt, auf das andere Apps keinen Zugriff haben.
- Übertragungen an externe APIs erfolgen ausschließlich via HTTPS/TLS.
- Die App speichert keine Schlüssel oder Zugangsdaten im Klartext.
- Mikrofonzugriff erfolgt ausschließlich während einer aktiven Aufnahme.

---

## 7. Rechte der betroffenen Personen (DSGVO Art. 15–22)

Als Nutzer haben Sie folgende Rechte:

- **Auskunft** (Art. 15): Welche Daten von Ihnen verarbeitet werden.
- **Berichtigung** (Art. 16): Korrektur unrichtiger Daten.
- **Löschung** (Art. 17): Da VoiceType keine personenbezogenen Daten dauerhaft speichert, ist eine separate Löschanfrage in der Regel nicht erforderlich. Alle Audiodaten werden automatisch gelöscht.
- **Einschränkung** (Art. 18): Einschränkung der Verarbeitung auf Anfrage.
- **Widerspruch** (Art. 21): Widerspruch gegen die Verarbeitung auf Basis berechtigter Interessen.
- **Beschwerde** (Art. 77): Beschwerde bei der zuständigen Datenschutzaufsichtsbehörde (in Deutschland: der Datenschutzbeauftragte Ihres Bundeslandes oder der BfDI).

Anfragen richten Sie bitte an: **[datenschutz@beispiel.de]**

---

## 8. Datenweitergabe und Drittländer

Audiodaten können bei Nutzung externer APIs in Länder außerhalb der EU/EWR (z. B. USA) übertragen werden. In diesem Fall stützen wir uns auf:
- **Standardvertragsklauseln (SCC)** der EU-Kommission, oder
- die jeweiligen Datenschutzzertifizierungen des Anbieters (z. B. EU-U.S. Data Privacy Framework).

Details entnehmen Sie bitte der Datenschutzerklärung des jeweiligen Anbieters (siehe Abschnitt 3.2).

---

## 9. Kinder

VoiceType richtet sich nicht an Personen unter 16 Jahren. Wir erheben wissentlich keine Daten von Kindern.

---

## 10. Änderungen dieser Datenschutzerklärung

Wesentliche Änderungen werden dem Nutzer beim nächsten App-Start mitgeteilt und erfordern ggf. eine erneute Einwilligung. Das Datum der letzten Aktualisierung ist oben vermerkt.

---

## 11. Kontakt

Bei Fragen zum Datenschutz wenden Sie sich bitte an:

**[Name des Verantwortlichen]**
E-Mail: [datenschutz@beispiel.de]
Telefon: [optional]

---

*Diese Datenschutzerklärung wurde für VoiceType (macOS) erstellt und entspricht den Anforderungen der EU-Datenschutz-Grundverordnung (DSGVO) sowie dem deutschen Bundesdatenschutzgesetz (BDSG).*
