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
| Behoben | Österreich: Kleinunternehmergrenze auf Bruttobasis, ausgewiesene Umsatzsteuer zählt mit | FA-4.1, P-S1 (a) | 7ad6b69 |
| Geändert | Österreich: harte Grenze 55.000 € zur Sicherheit, Toleranz nur noch als Warnung mit Verweis an die Steuerberatung; Status „in Toleranz“ entfällt | FA-4.4, P-S1 (b) | c30dc9d |
| Neu | UID-Prüfung: Formatprüfung offline, VIES auf Tippen, wöchentlich nach Opt-in, Protokoll, Ergebnis an der Rechnung eingefroren | L-1.3, L-1.4, FA-1.4a–d | 30ef78e |
| Neu | Firmenbuch-/Handelsregisternummer und Gericht, auf jeder Rechnung | FA-1.4e | 30ef78e |
| Geändert | Steuernummer und UID im Profil optional; Rechnungspflichten je Land (DE Steuernummer oder USt-IdNr., AT UID beider Seiten ab 10.000 €) | FA-1.4 | 30ef78e |
| Datenbank | Schema 4 → 5: Register- und Prüffelder, Tabelle `vat_id_checks` | Spezifikation 4 | 30ef78e |
| Berechtigung | Android `INTERNET` | VIES | 30ef78e |
| Neu | Verschlüsselte Datensicherung samt Fotos, Ablage über den Teilen-Dialog, Wiederherstellung mit Vorschau, Erinnerung nach 30 Tagen | L-7.1, L-7.3, L-7.4, FA-7.1–7.8 | 21682c9 |
| Datenbank | Schema 3 → 4: `company_profile.last_backup_at` | Spezifikation 4 | 21682c9 |
| Abhängigkeit | Neu: `cryptography`, `archive`, `file_picker` | Datensicherung | 21682c9 |
| Behoben | Belege werden storniert statt gelöscht; bleiben samt Foto erhalten | FA-2.11, P-S10 | d05d639 |
| Neu | Gründungsjahr im Firmenprofil; DE-Grenze 25.000 € im Gründungsjahr, keine Vorjahresprüfung | FA-4.13, P-S2 | d05d639 |
| Datenbank | Schema 2 → 3: `receipts.cancelled_at`, `company_profile.founding_year` | Spezifikation 4 | d05d639 |
| Kennwert | `spec.*.founding_year_limit_cents`: neu (DE 2500000, AT none) | Spezifikation 12 | d05d639 |
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
