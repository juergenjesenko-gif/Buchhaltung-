# Märkte und Expansion

Stand: 2026-10-27. Entscheidungsgrundlagen (Recherche der Prüfinstanzen, Sicherheit je Aussage dort vermerkt) liegen in `docs/maerkte/`. Prüfpunkte für die reale Welt stehen ausschließlich in `docs/SPECIFICATION.md` Abschnitt 14 (P-UK-…, P-FR-…).

## Entscheidungen des Auftraggebers

| Datum | Entscheidung |
|---|---|
| 2026-10-26 | **UK ist der nächste Markt**, Start vor dem 6. April 2027 (Making Tax Digital ab 30.000 £). Englische Fassung dient später Irland und USA. |
| 2026-10-26 | Englischer Produktname **„JeNi Books“**; eine App, Store-Name je Land (de: „JeNi bucht“, en: „JeNi Books“). |
| 2026-10-26 | Domain **jenibooks.com** gesichert (später 301 auf jenibucht.com/en/). |
| 2026-10-27 | Instagram **@jeni.books.app** gesichert (TikTok gleicher Name anstreben). |

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
- Website `/en/` aus zweiter Textdatei, Reels künftig ohne eingebrannte Untertitel (WebVTT je Sprache).

## Frankreich – Kernpunkte

Details: `docs/maerkte/Frankreich_Markteintritt.md`.

- Produktname (Vorschlag, nicht entschieden): **„JeNi compta“**.
- Plattform (Plateforme Agréée): **Favorit Super PDP** – 0,01 € je Rechnung über API, 2 € KYC/KYB je Kundin, Mindestumsatz 10 €/Jahr, Abrechnung nur an uns; AGB: Server in der EU, Auftragsverarbeitung (Anhang A), monatlich kündbar, kostenlose Reversibilität, Gerichtsstand Paris (gelesen 2026-10-26, Antwort Support #9374993). Angebote Iopole und B2Brouter angefragt.
- Kosten im Abo einrechnen, keine eigene Gebühr (Marktüblich: Indy, Tiime, Abby, Qonto gratis).

## AT/DE-Erweiterung aus UK-Arbeit

- **AT:** Direktübermittlung UVA an FinanzOnline (Webservice) ohne eigenen Server, ca. 2–3 Wochen – nach UK.
- **DE:** ELSTER braucht ERiC (keine Mobilbibliothek bekannt) – zurückgestellt bis geklärt.
