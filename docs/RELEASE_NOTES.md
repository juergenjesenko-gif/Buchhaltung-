# Release Notes

Jede ausgelieferte App-Version hat hier einen Eintrag — auch interne Testbuilds.
Der Eintrag entsteht **im selben Commit**, der die Version in `pubspec.yaml`
erhöht. `test/release_notes_test.dart` schlägt fehl, wenn zur Version in
`pubspec.yaml` kein Eintrag existiert.

## Aufbau eines Eintrags

Jeder Eintrag beantwortet die Frage: *Aus welchem Stand wurde dieser Build
gebaut, und was war darin geprüft?*

| Feld | Inhalt |
|---|---|
| Version | `version` aus `pubspec.yaml`, inklusive Buildnummer |
| Datum | Tag des Builds |
| Art | Testbuild (CI-APK) · interner Test (TestFlight / interner Track) · Store-Release |
| Commit | Kurz-Hash des gebauten Commits; nach dem Build als Git-Tag `v<Version>` gesetzt |
| Branch | aus dem gebaut wurde |
| Dokumentstände | Version von Lastenheft, Spezifikation und Benutzerhandbuch zum Build |
| Datenbankschema | `AppDatabase.schemaVersion` |
| Prüfung | Ergebnis von `flutter analyze`, Anzahl Tests, CI-Lauf |
| Neu / Geändert / Behoben | jeweils mit Anforderungs-ID (L-…, FA-…, O-…, P-…) und Commit |
| Steuerliche Kennwerte | geänderte `spec.*`-Werte aus Spezifikation Abschnitt 12 |
| Offene reale Prüfpunkte | IDs aus Spezifikation Abschnitt 14, die zum Build noch *offen* waren |
| Bekannte Grenzen | Verweis auf Spezifikation Abschnitt 11 |

---

## Unveröffentlicht

Änderungen seit 0.1.0+1, die noch in keinem Build stecken. Wandern beim
nächsten Versionssprung in den neuen Eintrag.

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Behoben | Grenzwertüberwachung: Vorjahresumsatz neuer Nutzer war null, Ampel fälschlich grün; Eröffnungswerte und Status „Angaben fehlen" | O-19, FA-1.8, FA-1.9, FA-4.9–4.12 | 2918bfd |
| Behoben | Österreich: Vorjahresgrenze 55.000 € ohne Toleranz | O-1, FA-4.6 | 8fb5547 |
| Behoben | Rechnungsnummer wird in derselben Transaktion wie das Speichern vergeben, keine Lücken | FA-5.5 | 077ca5d |
| Behoben | Schreibschutz gestellter Rechnungen auch in der Datenschicht | FA-5.5a, CLAUDE.md Regel 7 | 077ca5d |
| Geändert | DE-Rechnungshinweis „Steuerbefreiung nach § 19 UStG (Kleinunternehmer)" | P-S8 | 077ca5d |
| Geändert | Umsatzsteuer ganzzahlig gerundet, ohne `double` | CLAUDE.md Regel 1 | 077ca5d |
| Datenbank | Schema 1 → 2: Tabelle `opening_turnover`, Spalte `company_profile.tracking_start` | Spezifikation 4 | 2918bfd |
| Kennwert | `spec.at.previous_year_limit_cents`: none → 5500000 | Spezifikation 12 | 8fb5547 |

---

## 0.1.0+1 — 2026-08-17

| Feld | Wert |
|---|---|
| Art | Testbuild (CI-APK, `test-apk`-Artefakt); kein Store-Release |
| Commit | 39282ec (Code-Stand aus 83c1b28) |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Spezifikation 1.0; Benutzerhandbuch Erstfassung; Lastenheft existierte noch nicht |
| Datenbankschema | 1 |
| Prüfung | `flutter analyze` ohne Befund, 109 Tests grün, CI grün |

**Neu**

- Firmenprofil AT/DE mit Kleinunternehmerregelung und Rechnungsnummernkreis
- Belege mit Foto, Herausrechnen der Umsatzsteuer, Kategorien
- Kassabuch (Einnahmen-Ausgaben-Rechnung) je Monat, Quartal, Jahr
- Kleinunternehmer-Ampel mit Länderregeln
- Rechnungen mit Positionen, Pflichtangabenprüfung, PDF, Status
- Export: CSV, DATEV-Buchungsstapel, BMD, Umsatzsteuer-Zusammenfassung

**Nachträglich festgestellte Fehler dieses Builds**

- O-19: Vorjahresumsatz neuer Nutzer null → grüne Ampel trotz Überschreitung
- O-1: Österreich prüfte den Vorjahresumsatz nicht
- Lücken im Rechnungsnummernkreis bei Abbruch nach der Nummernvergabe möglich

Alle drei sind unter *Unveröffentlicht* behoben. Wer diesen Testbuild mit echten
Daten nutzt, muss die Kleinunternehmer-Ampel selbst nachprüfen.

**Tag:** `v0.1.0+1` nicht gesetzt (Build vor Einführung dieser Regel); maßgeblich ist Commit 39282ec.
