# UMZUG — /test → Startseite (index.html)

> Stand 2026-07-29 (inkl. Runde 3: Tab-2-Animation, Antwortentwurf-Story, Live-Demo-Zwei-Wege,
> App-Band, Trust-Badge zurück). /test ist die freigabepflichtige Vorlage; die Startseite wurde
> nicht angefasst. Umzug erst nach Freigabe Marcus UND nachdem die Voraussetzungen unten erfüllt sind.

## Voraussetzungen VOR dem Umzug

1. **Build 34 mit `rewrite_enabled` default `true`** ist released und auf Railway live —
   sonst bewirbt die Startseite ein Feature, das für Bestandslizenzen noch abgeschaltet ist.
   (Server: `licenses.rewrite_enabled` DEFAULT false; die Seite behauptet „Pro & Advanced".)
2. ✅ ERLEDIGT (2026-07-29): /test lädt `promo.js` jetzt selbst (root-absolut, `?v=2` wie die
   Startseite) und trägt alle Hooks inkl. `.js-lokal-price`/`.js-promo-note` in Trial-Kasten
   und Vergleichstabelle. Beim Umzug ist hier nichts mehr zu entscheiden — Include und Hooks
   1:1 mitnehmen; `promo.js` selbst bleibt die einzige Stelle, an der Aktionen geschaltet werden.
3. Datenpfad-Formulierung für markierten Text liefern (siehe „Bewusst offen" unten) —
   ohne sie bleibt der OFFEN-Kommentar bestehen.
4. Entscheidung Download-CTA: alle drei „Kostenlos laden/testen"-CTAs zeigen auf `#kaufen`
   statt auf einen Download — Ziel-URL klären, bevor die Startseite die neuen Hero-CTAs erbt.

## Was übernommen wird (Reihenfolge)

| # | Block | Quelle in test/index.html | Hinweise |
|---|-------|---------------------------|----------|
| 1 | CSS-Block `/* /test-Umbau: Hero-Tabs, Rewrite-Kleid, Kontrast */` (vor `</head>`) | `<style>`-Block am Head-Ende | komplett kopieren; enthält auch `.stats .stat-source`-Kontrastfix |
| 2 | Ankündigungsleiste (dezent, hell) über der Nav | erster `<a href="#rewrite" …>` vor `<!-- NAV -->` | ersetzt ggf. die Akzent-Variante |
| 3 | Nav-Eintrag „Umformulieren" (`#rewrite`) | `.nav-links` | zweite Position, nach „Modi" |
| 4 | Hero: H1 + Lead + Tab-Umschalter + Tab-2-Panel + `vt-note`-Zeile + Pause-Button | HERO-Sektion | H1: „Du sagst, wie es klingen soll. / AngelWrite schreibt es." |
| 5 | Banner-JS komplett (rAF-Typewriter, IntersectionObserver, reduced-motion, Pause/Play, Tab-Logik) | Script-Block ab `var SPOKEN` bis Ende `initBanner()`-Listener | ersetzt ALTEN Block `INTERVAL/TICK/TW` vollständig; Startseite hat sonst zwei konkurrierende Implementierungen |
| 6 | „So funktioniert es": Ziffern 01/02/03 → Verben Halten/Sprechen/Loslassen | HIW-Sektion | nur die `hiw-num`-Inhalte |
| 7 | Rewrite-Sektion (`section.rw-section#rewrite`, eigenes Kleid, Verben, Vorher/Nachher mit Herkunftslabel, 4 Anwendungsfälle mit fremdem Ursprung, CTA) | zwischen HIW und LIVE PREVIEW | inkl. OFFEN-Kommentar, bis Formulierung steht |
| 8 | Preiskarten: Rewrite-Bullets „(Pro & Advanced)" in Pro und Advanced; FAQ-Rewrite-Eintrag | PRICING + FAQ | erst nach Voraussetzung 1! |
| 9 | Übrige /test-Deltas aus dem Käuferurteil-Umbau (Beweiszeile unter Hero, gekürzte Zahlenleiste, Rollen-Kacheln, Ersparnisrechner, Datenschutz-Riegel, F1-Zeile, FAQ-Erweiterungen, KI-Footer) | jeweilige Sektionen | waren schon vor diesem Auftrag in /test; im selben Umzug mitnehmen |
| 10 | Tab-2-Animation („Überarbeiten": Cursor-Selektion → Welle+Befehl → Ergebnis, ein rAF-Loop; Pause/Play wirkt auf beide Tabs) | Hero-Panel `#vt-panel-2` + JS (`T2_*`, `t2*`-Funktionen, `vtSync`) | gehört untrennbar zu Block 4/5 |
| 11 | Story „Antwortentwurf vom Sekretariat" (Herkunftslabel + Entwurfszeile) in Hero-Tab 2 UND `.rw-ba` | Hero + Rewrite-Sektion | ersetzt die frühere Mandanten-Mail-Darstellung — NICHT zurückdrehen |
| 12 | Live-Demo-Zwei-Wege (Diktieren/Überarbeiten, `dw-*`-Tabs, 4 Befehls-Buttons + Ergebnisse) | DEMO-Sektion + JS-Handler (`data-idx` vs. `data-rwidx`) | Sub-Headline der Sektion mitnehmen |
| 13 | „Überall gleich"-Band (App-Namen-Chips, ohne Logos, ohne Laufband) | schmale Sektion vor „So funktioniert es" | Chips nur seiten-erwähnte Apps + macOS-Standard |
| 14 | Trust-Row: Badge „🔒 Lokal oder Cloud: du wählst" wieder an Position 1; Eyebrow „Seit v1.2 dabei" statt „Neu · v1.2.0" | Hero + LIVE-PREVIEW-Sektion | Kleinigkeiten, aber Teil der Story |

Beim Umzug NICHT übernehmen: `noindex,nofollow`-Meta, `[TEST]`-Titelpräfix, der Kommentar
„promo.js wird hier bewusst NICHT geladen" (Startseite behält ihren promo.js-Include, s. o.).

## Bewusst offen geblieben

- **Datenpfad markierter Text (Rewrite):** Auf der Seite ist nur der Diktat-Datenpfad belegt
  (Audio lokal vs. Cloud, Nutzerwahl). Wo der markierte TEXT verarbeitet wird, ist nicht
  belegt → sichtbarer Hinweis bewusst weggelassen, stattdessen `<!-- OFFEN: … -->` in der
  Rewrite-Sektion. Formulierung liefert Marcus.
- **Download-CTA-Ziel** (s. Voraussetzung 4).
- **Fair-Use-Einheit:** Seite nennt „250 Anfragen/Woche", Server misst Tokens (125.000/Woche).
- **`#presse`** hat keinen internen Link mehr (Hero-„Bekannt aus"-Zeile wurde durch die
  Beweiszeile ersetzt); Sektion existiert weiter.
- **Vorschlag, nicht beschlossen:** 30-Tage-Geld-zurück-Badge am Kaufpunkt.
