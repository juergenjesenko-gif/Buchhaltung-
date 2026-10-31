# Märkte und Expansion

Stand: 2026-10-27. Entscheidungsgrundlagen (Recherche der Prüfinstanzen, Sicherheit je Aussage dort vermerkt) liegen in `docs/maerkte/`. Prüfpunkte für die reale Welt stehen ausschließlich in `docs/SPECIFICATION.md` Abschnitt 14 (P-UK-…, P-FR-…).

## Entscheidungen des Auftraggebers

| Datum | Entscheidung |
|---|---|
| 2026-10-26 | **UK ist der nächste Markt**, Start vor dem 6. April 2027 (Making Tax Digital ab 30.000 £). Englische Fassung dient später Irland und USA. |
| 2026-10-26 | Englischer Produktname **„JeNi books“**; eine App, Store-Name je Land (de: „JeNi bucht“, en: „JeNi books“). |
| 2026-10-26 | Domain **jenibooks.com** gesichert (später 301 auf jenibucht.com/en/). |
| 2026-10-27 | Instagram **@jeni.books.app** gesichert (TikTok gleicher Name anstreben). |
| 2026-10-27 | **Frankreich:** App und Website auf **Französisch**, Produktname dort ebenfalls **„JeNi books“** (kein „JeNi compta“, keine eigene FR-Domain). |
| 2026-10-27 | **UK, Irland, USA starten gemeinsam** an einem Tag; vorbereitet wird ein Land nach dem anderen: **Irland, dann UK, dann USA** (kleinster Umbau zuerst, `docs/maerkte/Umbauplan_Laender.md`). |
| 2026-10-31 | **Erklärvideo** (Langfassung, ca. 100 s) wird **prominent auf jenibucht.com** platziert, gleich unter dem Kopfbereich; Aufnahmen automatisiert (Variante B), Schnitt durch Marketing. |
| 2026-10-27 | **Social Media nur Deutsch und Englisch** (@jeni.bucht, @jeni.books.app); keine dritte Sprache – zu viel Pflegeaufwand. |
| 2026-10-27 | **Eine Master-Domain jenibucht.com** mit Sprachversionen `/en/` und `/fr/`; **jenibooks.com leitet nur weiter** (301 auf `/en/`, später sprachabhängig `/fr/`). |

## Rangfolge (Stand 2026-10-26)

1. AT/DE vertiefen
2. **UK** – vor 6. 4. 2027
3. **Frankreich** – vor 1. 9. 2027 (Plattform-Pflicht für E-Rechnungen)
4. Italien – technisch machbar, wirtschaftlich schwach (SdI, Konkurrenz 2–8 €/Monat)
5. Spanien – VeriFactu und keine Kleinunternehmerbefreiung, hohes Risiko
6. USA – nur als Belegbuch, nicht aktiv verfolgen

## UK – Kernpunkte

Details: `docs/maerkte/UK_Anforderungen.md`, `docs/maerkte/Englisch_Name_Marketing.md`.

- HMRC MTD for Income Tax: Schnittstellen, Pflicht-Header zur Betrugsprävention, Zulassung (längster Vorlauf).
- **Offene Entscheidung des Auftraggebers:** kleiner Anmeldedienst (OAuth-Tokentausch, sieht keine Buchhaltungsdaten) – erster Serverdienst der App; derselbe Baustein dient Frankreich (Super PDP, OAuth „authorization code“).
- Mehrsprachigkeit der App, TaxProfile UK (Steuerjahr 6.4.–5.4., SA103-Zuordnung).
- Website `/en/` steht seit 2026-10-27 als Gerüst (`tool/site/produktseite_en.html` → `docs/site/en/index.html`): englische Texte ohne UK-Funktions-, MTD- oder Preisversprechen, Medien als Platzhalter, Warteliste per mailto, Rechtstexte vorerst deutsch verlinkt.
- Website `/en/` aus zweiter Textdatei, Reels künftig ohne eingebrannte Untertitel (WebVTT je Sprache).

## Frankreich – Kernpunkte

Details: `docs/maerkte/Frankreich_Markteintritt.md`.

- Produktname **„JeNi books“** (Entscheidung 2026-10-27); App, Store-Texte und Website französisch (Loi Toubon), Social Media bleibt DE/EN.
- Plattform (Plateforme Agréée): **Favorit Super PDP** – 0,01 € je Rechnung über API, 2 € KYC/KYB je Kundin, Mindestumsatz 10 €/Jahr, Abrechnung nur an uns; AGB: Server in der EU, Auftragsverarbeitung (Anhang A), monatlich kündbar, kostenlose Reversibilität, Gerichtsstand Paris (gelesen 2026-10-26, Antwort Support #9374993). Angebote Iopole und B2Brouter angefragt.
- Kosten im Abo einrechnen, keine eigene Gebühr (Marktüblich: Indy, Tiime, Abby, Qonto gratis).

## AT/DE-Erweiterung aus UK-Arbeit

- **AT:** Direktübermittlung UVA an FinanzOnline (Webservice) ohne eigenen Server, ca. 2–3 Wochen – nach UK.
- **DE:** ELSTER braucht ERiC (keine Mobilbibliothek bekannt) – zurückgestellt bis geklärt.

## Englischsprachiger Start: UK, Irland, USA gleichzeitig (Entscheidung 2026-10-27)

Ein englischer Build, drei Ländereinstellungen. Ziel: Start in allen drei Ländern vor dem 6. April 2027.

| | UK | Irland | USA |
|---|---|---|---|
| Sprache/Format | en-GB, £, 27/10/2026 | en-GB/en-IE, €, 27/10/2026 | en-US, $, 10/27/2026 |
| Steuerprofil | TaxProfile UK (Steuerjahr 6.4.–5.4., SA103-Kategorien, VAT 90.000 £) | TaxProfile IE (Kalenderjahr, VAT-Grenzen €42.500/€85.000, Kategorien Form 11) | TaxProfile US (Kalenderjahr, Kategorien Schedule C, keine USt) |
| Behördenanbindung | **HMRC MTD** direkt (Quartalsmeldung) | keine (ROS ohne offene Schnittstelle) → Export | keine → Export für Steuerberater/Schedule C |
| Rechnungen | VAT-Rechnung für Registrierte | VAT-Rechnung, EN 16931 wiederverwendbar | einfache Invoice, Sales Tax nur als Feld |
| Besonders | Anmeldedienst (OAuth) nötig | – | Meilen-Erfassung erwartet (später) |
| Store | UK | IE | US |

Reihenfolge der Arbeit: Mehrsprachigkeit und Länderwahl (gemeinsam) → TaxProfile IE und US (einfach, ohne Behörde) → UK mit HMRC (längster Vorlauf) → gemeinsamer Start. Fällt die HMRC-Zulassung zu spät, starten IE und US trotzdem, UK folgt.

Prüfpunkte: P-UK-01 bis P-UK-05; für IE und US neue Prüfpunkte vor Entwicklungsbeginn (Steuerwerte, Rechtstexte, US-Bundesstaaten-Datenschutz).

## Frankreich – Angebot B2Brouter (Antwort 2026-10-27)

| | Super PDP | B2Brouter |
|---|---|---|
| Modell | OAuth je Kundin (Kundin verbindet sich selbst) | „graue Marke“, wir sind Direktkunde, Kundinnen per API angelegt |
| Preis | 0,01 €/Rechnung, 2 € KYC je Kundin, min. 10 €/Jahr | 99 €/Monat fix + Stufe (z. B. 100 aktive Kundinnen = 198 €/Monat, 500 Transaktionen) |
| Kosten je Kundin (100 Kundinnen, 30 Rechn./Mon.) | ca. 0,30 € + 2 € einmalig | ca. 2,97 € (297 €/100) |
| Vertrag | monatlich kündbar | 1 Jahr, 30 Tage Frist (laut Antwort derzeit keine Austrittsgebühr) |
| Hosting | EU | Deutschland und Frankreich |
| Datenschutz-Unterlagen | AGB mit Anhang A (öffentlich) | nur nach NDA |
| Technik | App spricht mit Plattform im Namen der Kundin | API-Schlüssel ist unserer → Aufrufe müssen über **unseren Server** laufen, Rechnungsdaten aller Kundinnen gehen durch ihn |

**Entscheidung des Auftraggebers 2026-10-27: Super PDP.** B2Brouter als Ausweichlösung. Anforderungen: LASTENHEFT 5.35; Umsetzung nach der englischen Fassung.
