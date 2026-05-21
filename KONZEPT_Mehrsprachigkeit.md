# Konzept: Mehrsprachigkeit DE/EN — AngelWrite Landing Page

Erstellt: 2026-05-21

---

## 1. Wie andere das lösen — Marktüberblick

Es gibt drei etablierte Ansätze. Alle drei werden aktiv eingesetzt:

**A) Subdirectory `/en/`** (Beispiele: Linear.app, Notion, Vercel)
Alle englischen Seiten liegen unter `www.angelwrite.app/en/index.html`. Die deutsche Version bleibt auf `/`. Klare URL-Struktur, vollständig SEO-wirksam, einfach zu verlinken.

**B) JavaScript-Inline-Switching** (Beispiele: kleinere SaaS-Tools, Indie-Apps)
Alle Texte werden in einem JS-Objekt gepflegt. Per Klick auf `DE | EN` tauscht JavaScript alle `data-i18n`-Attribute aus. Vorteil: eine Datei. Nachteil: Inhalte sind ohne JavaScript nicht crawlbar.

**C) Subdomain `en.angelwrite.app`** (Beispiele: ältere Enterprise-Seiten)
Aufwändiger, teilt Domain-Authority — für AngelWrite nicht empfehlenswert.

**Empfehlung der Branche 2025:** Subdirectory `/en/` ist der Goldstandard für kleine bis mittelgroße Seiten. Teilt Domain-Authority, sauber für Google, einfach zu deployen auf Cloudflare Pages.

---

## 2. Empfohlene Architektur für AngelWrite

### Struktur nach Umsetzung

```
Docs/landing-page/
├── index.html              ← Deutsch (unverändert, Hauptseite)
├── en/
│   └── index.html          ← Englisch (neue Seite)
├── danke.html              ← Deutsch (Kauf-Bestätigung)
├── en/
│   └── danke.html          ← Englisch
├── bestaetigung.html       ← Deutsch (Waitlist DOI)
├── en/
│   └── thank-you.html      ← Englisch (oder: confirmation.html)
├── willkommen.html         ← Deutsch
├── en/
│   └── welcome.html        ← Englisch
├── 404.html                ← Bleibt zweisprachig (inline DE/EN)
├── agb.html                ← Nur Deutsch (gesetzliche Pflicht)
├── datenschutz.html        ← Nur Deutsch (gesetzliche Pflicht)
├── impressum.html          ← Nur Deutsch (gesetzliche Pflicht)
└── sitemap.xml             ← Beide Sprachen eintragen
```

### Welche Seiten werden übersetzt?

| Seite | Übersetzt? | Begründung |
|---|---|---|
| `index.html` | ✅ Ja | Hauptseite, umsatzrelevant |
| `danke.html` | ✅ Ja | Käufer sehen diese Seite |
| `bestaetigung.html` | ✅ Ja | Waitlist-Nutzer sehen diese Seite |
| `willkommen.html` | ✅ Ja | Onboarding-Seite für neue Nutzer |
| `404.html` | ✅ Ja (inline) | Einfach, beide Sprachen in einer Datei |
| `agb.html` | ❌ Nein | Deutsches Recht, Pflicht auf Deutsch |
| `datenschutz.html` | ❌ Nein | DSGVO, Pflicht auf Deutsch |
| `impressum.html` | ❌ Nein | Deutsches Recht, nur Deutsch nötig |

---

## 3. Sprach-Switcher — Design & Verhalten

### Platzierung
Oben rechts in der Navbar: `🌐 DE | EN` als kleiner, dezenter Toggle.
Auf Mobile: gleiche Position, kompakter.

### Verhalten
- Klick auf `EN` → Redirect zu `angelwrite.app/en/`
- Klick auf `DE` → Redirect zu `angelwrite.app/`
- Aktive Sprache wird visuell hervorgehoben (fetter, andere Farbe)
- Keine automatische Browser-Erkennung/Weiterleitung (UX-Best-Practice: Nutzer wählen selbst)
- Optional: Sprachpräferenz in `localStorage` merken

### Code-Snippet (Navbar-Ergänzung)
```html
<div class="lang-switch">
  <a href="/" class="lang-link active" lang="de">DE</a>
  <span style="color:#d1d5db">|</span>
  <a href="/en/" class="lang-link" lang="en">EN</a>
</div>

<!-- Auf der EN-Seite umgekehrt: DE = /, EN = active -->
```

---

## 4. SEO — hreflang-Tags

In jeder deutschen Seite im `<head>`:
```html
<link rel="alternate" hreflang="de" href="https://www.angelwrite.app/" />
<link rel="alternate" hreflang="en" href="https://www.angelwrite.app/en/" />
<link rel="alternate" hreflang="x-default" href="https://www.angelwrite.app/" />
```

In jeder englischen Seite im `<head>`:
```html
<link rel="alternate" hreflang="de" href="https://www.angelwrite.app/" />
<link rel="alternate" hreflang="en" href="https://www.angelwrite.app/en/" />
<link rel="alternate" hreflang="x-default" href="https://www.angelwrite.app/" />
```

`x-default` zeigt immer auf Deutsch — das ist die Hauptsprache.

---

## 5. Inhalte — Was ändert sich auf Englisch?

### index.html — Anpassungen über reine Übersetzung hinaus

Einige Texte müssen nicht nur übersetzt, sondern für den englischen Markt angepasst werden:

| Bereich | Deutsch | Englisch (Anpassung) |
|---|---|---|
| Hero | "Du sprichst. AngelWrite schreibt." | "You speak. AngelWrite writes." |
| Modus "Englisch" | "Sprich Deutsch — AngelWrite schreibt Englisch" | Aus Käufer-Sicht irrelevant → umbenennen zu "French / Spanish / etc." oder weglassen |
| Testimonials | Aktuell auf Deutsch | Englische Testimonials einfügen (oder übersetzen) |
| Pricing | €19 Basic / €49 Advanced | Preise gleich bleiben (€), aber Texte auf Englisch |
| FAQ | Deutsch | Englisch übersetzen |
| Footer | AGB, Datenschutz, Impressum | "Terms", "Privacy Policy", "Legal Notice" → verlinken auf DE-Seiten mit Hinweis |

### Modus "Englisch" auf der EN-Seite
Auf der deutschen Seite ist der Translate-Modus ein USP: "Sprich Deutsch, schreibe Englisch."
Für englische Nutzer dreht sich das um: Sie würden eher "Speak English, write French/Spanish" erwarten.
**Empfehlung:** Den Modus auf der EN-Seite umbenennen in "Translate" und breiter beschreiben.

---

## 6. Umsetzungsplan (Phasen)

### Phase 1 — Vorbereitung (1 Session)
- [ ] Ordner `en/` anlegen
- [ ] Sprach-Switcher CSS + HTML-Snippet fertigstellen
- [ ] hreflang-Template erstellen
- [ ] Englische Übersetzung von `index.html` anfertigen (alle Texte)

### Phase 2 — Hauptseite EN (1–2 Sessions)
- [ ] `en/index.html` erstellen (vollständige Übersetzung + Anpassungen)
- [ ] Sprach-Switcher in `index.html` (DE) einbauen
- [ ] hreflang-Tags in beide Versionen eintragen
- [ ] `sitemap.xml` um EN-URLs erweitern

### Phase 3 — Subseiten EN (1 Session)
- [ ] `en/danke.html` (post-purchase thank-you)
- [ ] `en/confirmation.html` (waitlist DOI)
- [ ] `en/welcome.html` (onboarding)
- [ ] `404.html` zweisprachig machen (inline DE/EN)

### Phase 4 — Feinschliff (1 Session)
- [ ] Footer auf allen DE-Seiten: Sprach-Switcher ergänzen
- [ ] Cloudflare Analytics prüfen: `/en/` wird separat getrackt
- [ ] Stripe Payment Link: Kann so bleiben (Preis in €, Sprache egal)
- [ ] robots.txt + sitemap.xml finalisieren

---

## 7. Aufwand-Schätzung

| Aufgabe | Geschätzter Aufwand |
|---|---|
| `en/index.html` übersetzen + anpassen | ~45 Min (1 Claude-Session) |
| Sprach-Switcher in alle Seiten einbauen | ~15 Min |
| hreflang + sitemap | ~10 Min |
| Subseiten (4 Seiten) | ~20 Min |
| Gesamt | **~90 Min** |

---

## 8. Was wir NICHT tun (und warum)

**Kein Auto-Redirect per IP/Browser-Sprache:** Nutzer bestimmen ihre Sprache selbst — das ist UX-Best-Practice und von Google empfohlen. IP-basierte Weiterleitung kann SEO schädigen.

**Kein Translation-Service (Weglot, DeepL API):** Für 7 Seiten ist manuell + KI-gestützt schneller, billiger und qualitativ besser als ein automatischer Service.

**Keine React/Framework-Migration:** Die statische HTML-Struktur bleibt — kein Build-Prozess, kein npm, keine Abhängigkeiten.

---

*Quellen: simplelocalize.io, weglot.com, linguise.com, digidop.com, sennalabs.com*
