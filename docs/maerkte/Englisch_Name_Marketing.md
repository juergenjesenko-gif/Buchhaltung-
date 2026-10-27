# JeNi auf Englisch – Name, Website, Social Media (Stand 2026-10-26)

Rollen: Marken-/Marketingstrategie und Prüfinstanz Rechtsanwalt (Marke UK/EU/US,
KI-Kennzeichnung). Keine echte Rechtsberatung. Prüfpunkte für die reale Welt
gehören nach `docs/SPECIFICATION.md` Abschnitt 14 (Vorschläge unten mit „→ 14“).
Zielmärkte: UK zuerst, dann IE, dann US.

Wichtige Vorbedingung (fachlich, nicht Marketing): Die App kann heute AT/DE-Steuer.
UK braucht ein eigenes `TaxProfile` (VAT 20 %, VAT-Schwelle, Self Assessment,
**Making Tax Digital for Income Tax ab April 2026 für Einkünfte > 50.000 £**,
ab 2027 > 30.000 £). Kein englisches Marketing mit UK-Funktionsversprechen, bevor
das gebaut und vom Steuerberater geprüft ist. Bis dahin: englische Inhalte nur
als Markenaufbau/Warteliste („coming to the UK“).

## 1. Name der englischen Variante

„bucht“ trägt auf Englisch nichts. Google hat „JeNi bucht“ in der
Play-Policy-Mail bereits selbst zu „JeNi books“ übersetzt – das ist der
natürliche Name, den Nutzer ohnehin hören.

| Option | Pro | Contra |
|---|---|---|
| **JeNi books** | 1:1-Übersetzung von „bucht“ (to book = buchen), „books“ = Buchhaltung („keep the books“), Doppelsinn Verb/Nomen wie im Deutschen; Google übersetzt schon so | „Books“ auch Bücher/E-Books → Store-Suche verwechselt evtl. mit Lese-Apps; Namensnähe zu QuickBooks, FreshBooks, Zoho Books (kein Konflikt durch „JeNi“, aber generisch) |
| JeNi Receipts | Trifft Kernfunktion und Suchbegriff „receipts“ | Klingt nach reinem Scanner, schmal; Wortspiel geht verloren |
| JeNi Bookkeeping | Klar, SEO-stark | Lang, sperrig, kein Charme |
| JeNi Tax | Suchbegriff „tax“ | Verspricht Steuerberatung → Konflikt mit Werbe-Negativliste („ersetzt den Steuerberater“) |
| JeNi (allein) | Kürzeste Marke, sprachneutral | Schwach unterscheidungskräftig, viele „Jeni/Jenny“-Marken, null Funktionshinweis |
| JeNi books (klein, analog „JeNi bucht“) | Konsistent zur DE-Schreibweise | Wie JeNi books; im Englischen wirkt Kleinschreibung als Satz („JeNi books.“) – kann gewollt sein |

**Aussprache:** „JeNi“ wird im UK als „Jenny“ gelesen – passt, freundlich.

**Store-Suchbegriffe:** Name kurz halten, Suchbegriffe in Untertitel/Kurzbeschreibung:
„JeNi books – Receipts & MTD“ (App Store Name ≤ 30 Zeichen) bzw. Untertitel
„Receipts, invoices, self assessment“. Keywords: receipts, bookkeeping,
sole trader, self employed, MTD, self assessment, invoice, expenses.
Achtung: „MTD“ nur nutzen, wenn die App wirklich HMRC-anerkannte MTD-Software
ist (HMRC-Liste) – sonst irreführend (CAP Code 3.1) → 14.

**Kurze Markenrecherche (Websuche, geringe Sicherheit):** Suche nach
„JeNi books“/„Jeni Books“ fand keinen exakt gleichen Eintrag; nächste Treffer
USPTO: „JENNI B.“ (Serial 98268166, Buchverlag, Kl. 41) und „JB JENNI B.“
(98794963), „CLEVER JENNY BOOKS“ (97636837) – andere Klassen (41 statt 9/36/42),
wohl kein Konflikt. UKIPO/EUIPO wurden nicht direkt abgefragt.
Quellen: https://trademark.justia.com/982/68/jenni-98268166.html,
https://trademark.justia.com/976/36/clever-jenny-97636837.html.
Sicherheit: niedrig. → 14: Identitäts- und Ähnlichkeitsrecherche „JENI“/„JENI BOOKS“
in UKIPO, EUIPO (TMview), USPTO, Klassen 9, 35, 36, 42, durch Anwalt.
Empfehlung Anwalt: eine **Wort-/Bildmarke „JeNi“** (EU + UK, später US) schützt
beide Sprachlinien; „bucht“/„books“ sind beschreibend und tragen wenig.

**Domains** (Verfügbarkeit hier nicht prüfbar – selbst beim Registrar prüfen):
jenibooks.com, jenibooks.co.uk, jenibooks.app, getjenibooks.com. Minimalweg:
**jenibucht.com/en/** als Hauptadresse, jenibooks.com nur kaufen und per 301
auf /en/ umleiten (eine Seite, eine Pflege, Domain-Authority gebündelt).

**Empfehlung:** **„JeNi books“**, Schreibweise analog „JeNi bucht“.

**Eine App oder zwei?** Eine App, lokalisiert. Play Console und App Store
Connect erlauben je Sprache/Locale eigenen Titel, Untertitel, Beschreibung,
Screenshots: de-DE/de-AT „JeNi bucht“, en-GB (später en-IE, en-US) „JeNi books“.
Ein Code, eine Bewertungshistorie, ein Abo-System; Länderlogik bleibt im
`TaxProfile`. Paketname bleibt. Preise je Land im Store.

## 2. Website mit Englisch, minimaler Aufwand

1. `tool/site/produktseite.html` bleibt Vorlage; Texte in zwei Inhaltsdateien
   auslagern (`inhalt_de.json`, `inhalt_en.json`, gleiche Schlüssel).
2. `build_site.py` baut je Sprache: `/index.html` (de) und `/en/index.html`;
   Rechtsseiten EN: Privacy, Terms, Imprint (UK verlangt kein Impressum, aber
   Kontaktangaben nach Consumer Contracts/ECR – Inhalt durch Anwalt → 14).
3. In jeden `<head>`: `<link rel="alternate" hreflang="de" …>`,
   `hreflang="en" …/en/`, `hreflang="x-default"` → de-Seite; `<html lang>` setzen;
   sitemap.xml um /en/ erweitern.
4. Sprachumschalter „DE | EN“ oben rechts als einfacher Link (keine automatische
   Umleitung per IP – Google rät ab).
5. Bilder und Videos gemeinsam in `docs/site/img`, `docs/site/video` – nicht kopieren.
6. Reels mit eingebrannten deutschen Untertiteln:
   - **ab jetzt** Videos **ohne** eingebrannten Text rendern, Untertitel als
     WebVTT (`video_de.vtt`, `video_en.vtt`, `<track kind="subtitles" srclang>`);
     Text dann im JSON übersetzbar, barrierefrei, durchsuchbar.
   - Bestandsvideos: für die EN-Seite nur 1–2 Videos neu rendern (ohne Text)
     oder vorläufig Standbild + englischer Text. Kein Doppel-Untertitel.
   - Ausnahme: KI-Hinweis „AI-generated · Ad for JeNi books“ bleibt eingebrannt
     (Kennzeichnung darf nicht abschaltbar sein) – sprachneutral lösbar mit
     Icon „AI“ + kurzem Text je Sprache im Rendering-Schritt.

Aufwand: einmalig ca. 1 Entwicklertag (Claude Code), danach je Textänderung
nur den EN-Eintrag mitpflegen (Claude übersetzt im selben Commit).

## 3. Instagram & TikTok

| | Ein zweisprachiges Konto | Getrennte Konten (@jeni.books) |
|---|---|---|
| Algorithmus | Gemischte Sprache verwässert Zielgruppensignal; DE-Follower sehen EN-Posts und umgekehrt → schlechtere Interaktionsrate | Saubere Zielgruppe je Konto, Empfehlungen (Reels/For You) passen |
| Aufwand | Ein Konto pflegen | Zweites Konto, aber gleiche Videos |
| Recht | Impressum/Kennzeichnung je Post zweisprachig nötig | Je Konto eine Sprache, klarer |
| Marke | – | Name sichern, bevor jemand anders ihn nimmt |

Instagram bietet KI-Übersetzung/Lip-Sync für Reels („Meta AI translations“) und
mehrsprachige Captions; TikTok automatische Untertitel/Übersetzung. Das hilft,
ersetzt aber nicht die Kennzeichnungs-Zeile in der Zielsprache.

**Empfehlung:** Handles **@jeni.books** auf Instagram und TikTok **jetzt sichern**
(kostet nichts), aber erst aktiv bespielen, wenn UK-Funktion + Warteliste stehen.
Dann getrennte Konten, gleiche Rohvideos.

**Produktionsablauf „einmal drehen, zweimal posten“:**
1. Szene/Bild der KI-Figur ohne eingebrannten Text erzeugen (sprachneutral,
   keine deutschen Schilder/Belege im Bild; Musterbeleg neutral oder je Land).
2. Skript DE schreiben, Claude-Projekt erstellt EN-Fassung (britisches
   Englisch, „sole trader“, „receipts“, „VAT“, nie „Steuerberatung“-Ersatz).
3. KI-Stimme in beiden Sprachen (gleiche Stimme, z. B. Voice-Clone/Dubbing).
4. Untertitel als bearbeitbare Textebene/Caption-Funktion der Plattform.
5. Zwei Exporte, je mit Kennzeichnungs-Overlay in der Sprache.

**Checkliste je EN-Post:**
- [ ] Overlay erste Sekunden + dauerhaft: „AI-generated · Ad for JeNi books“
- [ ] Caption Zeile 1: „Ad · AI character – JeNi is not a real person, scene is fictional.“
- [ ] Meta „AI info“ / TikTok „AI-generated content“-Schalter an; C2PA-Metadaten nicht entfernen
- [ ] Bei Bezahlwerbung: Instagram „Paid partnership“/TikTok „Promotional content“
- [ ] Werbe-Negativliste auf Englisch: kein „HMRC-approved“ (außer wirklich gelistet), „replaces your accountant“, „tax advice“, „100 % accurate“, „free“ ohne Folgepreis
- [ ] Musik aus lizenzfreier Plattformbibliothek (Business-Konto)
- [ ] Erste KI-Antwort in DMs/Kommentaren: „This is an AI reply from JeNi books. Not tax advice – for your situation ask an accountant.“

**KI-Kennzeichnung (Rechtsanwalt):**
- **EU AI Act Art. 50 Abs. 4** gilt seit 2.8.2026: Deepfakes (realistisch
  wirkende KI-Person) sind sichtbar zu kennzeichnen; reicht auch für UK/US-Firmen,
  deren Inhalte EU-Publikum erreichen. Plattform-Label allein genügt nicht,
  sichtbarer Hinweis nötig; Code of Practice empfiehlt „AI“-Icon. Bußgeld bis
  15 Mio. €/3 %. Quellen: https://www.lewissilkin.com/insights/2026/07/31/the-new-ai-labelling-rules-for-deployers-in-the-advertising-supply-chain,
  https://www.srd-rechtsanwaelte.de/en/blog/deepfake-labelling-under-the-ai-act-what-the-new-eu-guidance-clarifies. Sicherheit: mittel (Sekundärquellen).
- **UK:** kein AI-Act; **ASA/CAP** prinzipienbasiert: Kennzeichnen, wenn
  Publikum sonst irregeführt würde – bei KI-Influencerin, die „ihr Business“
  zeigt, ist das der Fall. Plus Werbekennzeichnung „#ad“ (CAP 2.1, CMA-Influencer-
  Leitfaden), DMCC Act 2024 (CMA darf direkt Bußgelder verhängen). Quelle:
  https://connectontech.bakermckenzie.com/ai-generated-marketing-content-new-eu-ai-act-disclosure-rules-and-the-uk-position. Sicherheit: mittel.
  → 14: ASA-Originaltext prüfen und EN-Kennzeichnung durch UK-Anwalt bestätigen.
- **Meta/TikTok:** eigene Pflicht-Labels für realistische KI-Inhalte; bisherige
  DE-Praxis (P-R71/P-R72) einfach auf Englisch spiegeln – deckt EU und UK ab.

## 4. Schritt-für-Schritt-Plan

| Woche | Schritt | Auftraggeber/Woche |
|---|---|---|
| 1 | Handles @jeni.books (IG, TikTok) + Domain jenibooks.com/.co.uk sichern | 30 min |
| 1 | Anwalt: Markenrecherche „JeNi“ UK/EU beauftragen (→ 14) | 15 min |
| 2 | Claude Code: Website /en/ mit hreflang, Warteliste „Coming to the UK“ | 15 min Freigabe |
| 2–3 | Neue Videos ohne eingebrannten Text, WebVTT DE/EN | 0 (Workflow) |
| parallel | Entwicklung UK-`TaxProfile`, Steuerberater-Prüfung, en-GB-Store-Listing | Entscheidungen |
| ab UK-Start | Getrennter EN-Kanal, 2–3 Posts/Woche aus den DE-Rohvideos | ca. 1–1,5 h |

Ziel < 2 h/Woche: erreichbar, weil Bild/Video einmal entsteht; EN-Mehraufwand
nur Skript-Übersetzung (Claude), zweiter Voice-Export, Upload, Checkliste
(~20–30 min je Post).

## Übergabe an den Marketing-Chat (Claude-Projekt „JeNi bucht“)

- Markenname EN: **JeNi books** (Vorschlag, Freigabe Auftraggeber offen).
  Handle **@jeni.books** – erst sichern, aktiv erst ab UK-Funktion.
- Ab sofort Videos **ohne eingebrannten Text** produzieren; Untertitel als
  Plattform-Caption oder WebVTT. Szenen sprachneutral (keine DE-Schilder).
- Je Video: Skript DE + EN (britisches Englisch), gleiche KI-Stimme in beiden
  Sprachen, Overlay je Sprache „KI-generiert · Werbung für die App JeNi bucht“ /
  „AI-generated · Ad for JeNi books“.
- EN-Caption Zeile 1: „Ad · AI character – JeNi is not a real person, scene is fictional.“
- EN-Bio-Entwurf: „AI influencer for JeNi books 🤖 / Running my business from my
  phone. / Snap a receipt – done. 📱 / For UK sole traders 👇“ + „Contact & privacy: link in bio“.
- Englische Negativliste: kein „tax advice“, „replaces your accountant“,
  „HMRC-approved/MTD-compatible“ (bis bestätigt), „100 % accurate“, „free“ ohne Folgepreis.
- Keine UK-Funktionsversprechen, bevor die App UK kann.
