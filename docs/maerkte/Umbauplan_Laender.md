# Umbauplan: weiteres Land als reine Konfiguration (UK, IE, US)

Prüfinstanz Softwareentwickler, 2026-10-27. Grundlage für Lastenheft 5.34
(L-34.1 bis L-34.6). Code-Stellen Stand Commit b109b1f.

## Befund

1. **Euro fest verdrahtet:** `lib/core/formatting.dart` (`de_AT`, Symbol €),
   `lib/domain/money.dart` (Parser, `toString` EUR), Exporte (Spalten „je EUR“),
   E-Rechnung (Währung EUR, Sprache de), Datenbank `currency DEFAULT 'EUR'`,
   Kurstabelle mit Basis EUR, PDFs, Belegscan.
2. **Kalenderjahr als Steuerjahr:** `fiscal_year.dart` nur Monatsanfang,
   `Period.year`, Umsatzgrenze, Fristen, Abgaben, AfA zum 31.12. UK braucht 6.4.–5.4.
3. **TaxProfile DACH-lastig:** Pflichtfelder für USt, Kleinunternehmer, UVA,
   Firmenbuch, Reverse Charge, Sozialversicherung. USA hat keine USt.
4. **Deutsche Fachtexte ohne BuildContext** in `country.dart`, PDFs, Exporten,
   Jahresbericht, Angebotstexten, Demo.
5. **Datum/Zahl fest `de_AT`**, Datumsauswahl erzwingt `Locale('de')`.

## Arbeitspakete

| AP | Inhalt | Aufwand | Risiko |
|---|---|---|---|
| AP1 | `Fmt` nach Locale und Währung, Datumsauswahl entkoppeln, Parser 1,234.56 / 1.234,56 | 2 PT | Parser, Golden-Tests |
| AP2 | Migration v33 `base_currency`, `CurrencyCode`, Währung in E-Rechnung, Export, PDF, Kursen; Basiswährung nach erster Buchung gesperrt | 3 PT | Fremdwährung, Sicherung |
| AP3 | `YearSpec` (Monat + Tag), `taxYear`/`vatYear` im Profil, alle Zeiträume umstellen | 3 PT | Fristen, Grenze, AfA |
| AP4 | `TaxProfile` in optionale Teile (`VatRegime?`, EU-Regeln, Register, Sozialversicherung), Null-Weichen | 5 PT | stille Fehler AT/DE |
| AP5 | Fachtexte aus Domain/Services in ARB, Dokumentsprache als eigener Parameter | 4 PT | Umfang |
| AP6 | Profile IE, UK, US mit Quellen (`docs/maerkte/Steuerwerte_UK_IE_US.md`) | je 3–5 PT | Steuerwerte |

Daneben läuft die Übersetzung der Bildschirme (FA-1.20).

## Absicherung

- Vor AP3/AP4 Schnappschuss-Tests der AT/DE-Ergebnisse (Fristen, Grenze, UVA,
  PDF, CSV, XRechnung/ebInterface) als Regressionsnetz.
- Migrationstest v32 → v33 mit Bestandsdaten.
- `YearSpec` 6.4.–5.4. mit Schaltjahr und Jahreswechsel.
- US-Profil ohne USt läuft durch Rechnung, Export, Bericht, Fristen.
- Formate GBP/USD/EUR in je zwei Locales.
- Architekturtest: `lib/domain` und `lib/services` importieren kein Flutter-UI.
