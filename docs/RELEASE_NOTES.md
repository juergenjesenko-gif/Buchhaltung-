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

Änderungen seit 0.3.3+6, die noch in keinem Build stecken. Wandern beim
nächsten Versionssprung in den neuen Eintrag.

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Behoben | Übersicht lädt nach Speichern oder Stornieren eines Belegs in einem anderen Reiter und nach Wiederherstellung neu (`AppState.bookingsRevision`); vorher blieben „Dieser Monat“ und „Letzte Belege“ auf dem Stand des App-Starts. Test `dashboard_refresh_test.dart` | Gerätetest 0.3.3 | dieser Commit |

---

## 0.3.3+6 — 2026-10-13

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK, fester Testschlüssel); Belegerkennung an echten Belegen |
| Commit | siehe Git-Tag `v0.3.3` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.42, Spezifikation 1.36, Benutzerhandbuch für 0.3.3 |
| Datenbankschema | 10 |
| Prüfung | `flutter analyze` ohne Befund, 268 Tests grün, Emulator-Job `android-ocr-emulator` grün, CI siehe Lauf zum Tag |
| Offene reale Prüfpunkte | P-D21, P-D22 (Belegerkennung auf dem Pixel), P-S27 |

**Änderungen seit 0.3.2+5**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Behoben | Belegerkennung: Kopfzeilen wie „DUPLIKAT“ oder „Zweitschrift“ werden nicht mehr als Händler erkannt; Test mit dem echten Mautticket aus dem Gerätetest | FA-2.19 | 45b7ecb |
| Behoben | Android-Belegerkennung: ML Kit ausdrücklich initialisiert, Datei/Format geprüft, Fehlercode mit Exception-Klasse und Stackzeile | FA-2.19, P-D22 | 88d65ad, b5a031a |
| Neu | CI-Job `android-ocr-emulator`: echte Erkennung eines synthetischen Kassenbons im Emulator, Release-Build mit R8 | P-D22 | 88d65ad, b5a031a |
| Neu | CI-Job `android-ocr-emulator` liest alle Korpusfotos aus `test/fixtures/belege/` und legt das rohe ML-Kit-Ergebnis ab (Artefakt `ocr-belege`, Job-Log) | FA-2.28 | 7b58ed9 bis 084d3b7 |
| Behoben | Belegerkennung: Bruttobetrag und Steuersatz wurden nicht vorbelegt, wenn der Betrag rechts nicht exakt auf Höhe der Bezeichnung lag (schräg gehaltener Beleg, Gerätetest Build 85 Mautbeleg) | FA-2.28 | dieser |
| Neu | Belegerkennung: „Beløb“, „TOTAL … kr“, „HERAF MOMS“, TT-MM-JJJJ, CVR-Nummer, „Rechnung 37549“, Betrag ohne Nachkommastellen nach „Total“; Korpustest mit Trefferquote | FA-2.28 | dieser |
| Geändert | Ausländische Umsatzsteuer wird erkannt, aber 0 % mit Hinweis „nicht als Vorsteuer abziehbar“ vorbelegt; mehrdeutige Währung („$“, „kr“) füllt das Euro-Feld nicht | FA-2.29, P-S27 | dieser |

---

## 0.3.2+5 — 2026-10-12

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK, fester Testschlüssel); Fehlerbehebung zu 0.3.1 |
| Commit | siehe Git-Tag `v0.3.2` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.42, Spezifikation 1.33, Benutzerhandbuch für 0.3.2 |
| Datenbankschema | 10 |
| Prüfung | `flutter analyze` ohne Befund, 250 Tests grün, CI siehe Lauf zum Tag |
| Offene reale Prüfpunkte | P-D21, P-D22 (Belegerkennung auf dem Pixel) |

**Änderungen seit 0.3.1+4**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Geändert | Testbuild nur noch arm64, ungezippt als `Buchhaltung-<Version>-build-<Nummer>.apk` (upload-artifact v7, `archive: false`); weiter mit `--split-per-abi`, damit der versionCode 2000 + Buildnummer bleibt (Build 73 ohne Split ließ sich nicht als Update installieren) | Wunsch Auftraggeberin 2026-10-12 | 9109e7b, dieser |
| Behoben | Android: Belegerkennung brach im Release-Build weiter ab (Build 74); R8-Keep-Regeln für ML Kit ergänzt; Fehlermeldung zeigt einen kurzen Fehlercode ohne Belegdaten | FA-2.19, Gerätetest Pixel 10 | dieser |

---

## 0.3.1+4 — 2026-10-12

| Feld | Wert |
|---|---|
| Art | Testbuild (CI-APK, Artefakt `test-apk-build-<Nummer>`, fester Testschlüssel); Fehlerbehebung zu 0.3.0 |
| Commit | siehe Git-Tag `v0.3.1` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.42, Spezifikation 1.32, Benutzerhandbuch für 0.3.1 |
| Datenbankschema | 10 |
| Prüfung | `flutter analyze` ohne Befund, 250 Tests grün, CI siehe Lauf zum Tag |
| Offene reale Prüfpunkte | wie 0.3.0, insbesondere P-D21, P-D22 (Belegerkennung auf dem Pixel erneut prüfen) |

**Änderungen seit 0.3.0+3**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Behoben | Android: Belegerkennung brach im Release-Build mit NullPointerException ab (`InputImage.fromFilePath`); Bild wird jetzt selbst dekodiert, verkleinert und mit EXIF-Drehung übergeben; verständliche Fehlermeldung statt technischem Text | FA-2.19, Gerätetest Pixel 10 2026-10-12 | dfd14d8 |

---

## 0.3.0+3 — 2026-10-12

| Feld | Wert |
|---|---|
| Art | Testbuild (CI-APK, Artefakt `test-apk-build-<Nummer>`, signiert mit festem Testschlüssel); kein Store-Release. Die Buildnummer der APK ist die CI-Laufnummer |
| Commit | siehe Git-Tag `v0.3.0` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.42, Spezifikation 1.30, Benutzerhandbuch für 0.3.0 |
| Datenbankschema | 10 |
| Prüfung | `flutter analyze` ohne Befund, 250 Tests grün, CI siehe Lauf zum Tag |
| Offene reale Prüfpunkte | alle mit Status „offen“ in Spezifikation Abschnitt 14, für diesen Build vor allem P-D21 bis P-D24 (ML-Kit-Netzverkehr, Belegerkennung an echten Belegen, Fremdwährung im DATEV-Import, App-Symbol auf dem Startbildschirm) sowie P-R19, P-S23 bis P-S26 |
| Bekannte Grenzen | Spezifikation Abschnitt 11 |

**Änderungen seit 0.2.0+2**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | Belege automatisch auslesen: Texterkennung auf dem Gerät (Android ML Kit gebündelt, iOS Apple Vision), Vorbelegung von Datum, Brutto, Steuersatz, Lieferant, Rechnungsnummer, Aussteller-UID mit „erkannt – bitte prüfen“, „Erneut auslesen“, abschaltbar; Fremdwährung bei Ausgaben nur erkannt; Protokoll erkannt/bestätigt mit SHA-256. Schema 9 | L-2.20–L-2.23, FA-2.19–FA-2.23, P-D22, P-R19, P-D21 | 87f6577 |
| Neu | Fremdwährung bei Ausgaben umrechnen: Kurs als Ganzzahl (je 1 € × 10^6), „Kurs abrufen“ bei der EZB nur auf Knopfdruck mit lokalem Speicher, EZB-Monatsmittel als Näherung an den BMF-Kurs, Tageskurs nur mit Genehmigung in den Einstellungen, Bankbetrag getrennt für das Ergebnis, Protokoll `fx`, Belegliste mit Währungsspalten; DATEV/BMD nur Euro. Schema 10 | L-2.24–L-2.26, L-13.3, L-19.29, FA-2.24–FA-2.27, P-S23–P-S26, P-R18, P-D23 | 5b9faed |
| Neu | App-Symbol auf dem Startbildschirm: einmaliges Angebot nach dem Onboarding und Eintrag in den Einstellungen, Systemdialog über `requestPinShortcut` (Android 8+); auf iOS ausgeblendet | FA-1.19, P-D24 | 57da3b0 |

---

## 0.2.0+2 — 2026-10-12

| Feld | Wert |
|---|---|
| Art | Testbuild (CI-APK, Artefakt `test-apk-build-<Nummer>`, signiert mit festem Testschlüssel); kein Store-Release. Die Buildnummer der APK ist die CI-Laufnummer |
| Commit | siehe Git-Tag `v0.2.0` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.39, Spezifikation 1.25, Benutzerhandbuch für 0.2.0 |
| Datenbankschema | 8 |
| Prüfung | `flutter analyze` ohne Befund, 220 Tests grün, CI siehe Lauf zum Tag |
| Offene reale Prüfpunkte | alle mit Status „offen“ in Spezifikation Abschnitt 14, für diesen Build vor allem P-D11 bis P-D13, P-D17 bis P-D20, P-B12 |
| Bekannte Grenzen | Spezifikation Abschnitt 11 |

**Änderungen seit 0.1.0+1**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Geändert | Testbuilds tragen eine fortlaufende Buildnummer (CI-Laufnummer) als versionCode und im Artefaktnamen `test-apk-build-<Nummer>` | Wunsch Auftraggeberin 2026-10-12 | 3e9bf5b |
| Neu | Tablet und Querformat: Breitenklassen nach Material 3, Navigationsleiste links ab 600 dp, Liste-Detail ab 840 dp für Belege, Rechnungen und Kunden, Formulare höchstens 640 dp; iPad mit Split View (kein `UIRequiresFullScreen`) | FA-9.1–9.5, DESIGN_SPEC D-5, P-D19, P-D20 | 55ad7cc |
| Neu | App-Sperre: PIN 6–8 Ziffern (Argon2id-Hash im sicheren Speicher), optional Fingerabdruck/Face ID, Sperre beim Start und nach einstellbarer Zeit, steigende Wartezeit, Abdeckung im App-Umschalter, Hinweis „PIN vergessen“ mit Warnung ohne Sicherung | L-22.30, FA-1.13–1.18 | f14c031 |
| Abhängigkeit | Neu: `local_auth`, `androidx.appcompat`; Android `MainActivity` erbt von `FlutterFragmentActivity`, Starttheme `Theme.AppCompat`; iOS `NSFaceIDUsageDescription` | FA-1.16, P-D18 | f14c031 |
| Behoben | PDF gestellter Rechnungen nahm Absenderangaben aus dem aktuellen Profil statt aus dem eingefrorenen Snapshot | GR-8, CLAUDE.md Regel 7 | 340458f |
| Behoben | Abgebrochene Belegerfassung hinterließ verwaiste Fotos | FA-2.13 | 340458f |
| Neu | Mehrseitige Belege mit Vollständigkeitsbestätigung, Seiten nach dem Speichern nur anhängbar; Schema 8 (`receipt_pages`), Migration der Einzelfotos | L-2.15, L-2.16, FA-2.13–2.15 | a9da2ce |
| Neu | Kommentare zu Belegen, nur anhängbar, mit Zeitstempel und Protokoll, auch bei stornierten Belegen; Diktat über die Systemtastatur mit Hinweis; Filter „Storniert" | L-2.17, L-2.18, FA-2.16–2.18 | a9da2ce |
| Neu | Firmenlogo im Rechnungs-PDF, eingefroren bei Rechnungslegung, in der Sicherung (`logo/`) | L-1.7, L-1.9, FA-1.12, FA-7.6 | a9da2ce |
| Geändert | Export: Belegliste mit Seiten und Kommentaren, DATEV/BMD-Buchungstext mit gekürztem Kommentar | FA-6.7 | a9da2ce |
| Dokumentation | Entwürfe Impressum, Datenschutzerklärung, Nutzungsbedingungen (`docs/legal/`), noch nicht in der App | P-L1, P-L4–L11 | 86d4d92 |
| Behoben | Grenzwertüberwachung: Vorjahresumsatz neuer Nutzer war null, Ampel fälschlich grün; Eröffnungswerte und Status „Angaben fehlen" | O-19, FA-1.8, FA-1.9, FA-4.9–4.12 | 2918bfd |
| Behoben | Österreich: Vorjahresgrenze 55.000 € ohne Toleranz | O-1, FA-4.6 | 8fb5547 |
| Behoben | Rechnungsnummer wird in derselben Transaktion wie das Speichern vergeben, keine Lücken | FA-5.5 | 077ca5d |
| Behoben | Schreibschutz gestellter Rechnungen auch in der Datenschicht | FA-5.5a, CLAUDE.md Regel 7 | 077ca5d |
| Geändert | DE-Rechnungshinweis „Steuerbefreiung nach § 19 UStG (Kleinunternehmer)" | P-S8 | 077ca5d |
| Geändert | Umsatzsteuer ganzzahlig gerundet, ohne `double` | CLAUDE.md Regel 1 | 077ca5d |
| Behoben | Österreich: Kleinunternehmergrenze auf Bruttobasis, ausgewiesene Umsatzsteuer zählt mit | FA-4.1, P-S1 (a) | 7ad6b69 |
| Geändert | Österreich: harte Grenze 55.000 € zur Sicherheit, Toleranz nur noch als Warnung mit Verweis an die Steuerberatung; Status „in Toleranz“ entfällt | FA-4.4, P-S1 (b) | c30dc9d |
| Neu | Bestätigungen vor der ersten Nutzung (keine Steuerberatung, Nutzungsbedingungen/Datenschutz) mit Fassung und Zeitpunkt | L-17.1–17.4, FA-1.10 | 80b59dc |
| Neu | Auge-Symbol in Kennwort- und Code-Feldern | FA-1.11 | 80b59dc |
| Behoben | Android: Sicherungsordner zeigte technische Dokument-ID statt Namen | Gerätetest 12.10. | 80b59dc |
| Datenbank | Schema 6 → 7: Tabelle `consents` | Spezifikation 4 | 80b59dc |
| Neu | Automatische Sicherung in einen gewählten Ordner (iCloud Drive, Google Drive …), Wiederherstellungscode, Probe nach jedem Schreiben, Aufbewahrung 7/12/je Jahr dauerhaft, „Sicherung prüfen“ | L-7.2, L-7.6–7.10, FA-7.9–7.15 | 1cae349 |
| Datenbank | Schema 5 → 6: Spalten der automatischen Sicherung | Spezifikation 4 | 1cae349 |
| Abhängigkeit | Entfernt: `file_picker` (brach den Android-Build unter AGP 9; Dateiauswahl jetzt über `BackupFolderChannel`) | CI | bb924b8 |
| Abhängigkeit | Neu: `flutter_secure_storage`; eigener Plattformcode `BackupFolderChannel` (Kotlin, Swift) | FA-7.9 | 1cae349 |
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
