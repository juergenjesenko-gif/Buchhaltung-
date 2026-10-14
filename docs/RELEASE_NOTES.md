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

Änderungen seit 0.11.0+16, die noch in keinem Build stecken. Wandern beim
nächsten Versionssprung in den neuen Eintrag.

| Art | Änderung | Bezug | Commit |
|---|---|---|---|

---

## 0.11.0+16 — 2026-10-14

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK, fester Testschlüssel); Stufe B1 Plattformexporte |
| Commit | siehe Git-Tag `v0.11.0` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.53, Spezifikation 1.50, Benutzerhandbuch für 0.11.0, DESIGN_SPEC 1.2 |
| Datenbankschema | 17 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `platform_import_test.dart`: zehn synthetische Exporte in fünf Sprachen, Datensparsamkeit über alle Tabellen, Knopf ≥ 56 dp), Emulator-Job `android-ocr-emulator`, CI siehe Lauf zum Tag |
| Steuerliche Kennwerte | neu `spec.oss_threshold_cents = 1000000`, `spec.at.reverse_charge_kz = -,057,066`, `spec.de.reverse_charge_kz = 46,47,67` |
| Offene reale Prüfpunkte | wie 0.10.0+15, dazu P-S51 bis P-S55, P-R36, P-U7 |

**Änderungen seit 0.10.0+15**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | Plattformexporte über Teilen/„Öffnen mit“: Amazon Transaktionsbericht (DE/EN/FR/IT/ES) und Abrechnung V2, PayPal, Shopify, Stripe; Format automatisch erkannt | L-28.1, FA-2.43 | siehe Tag |
| Neu | Eine Zusammenfassung je Monat, ein Knopf „Übernehmen“ unten (56 dp) | L-28.2, FA-2.44, P-U7 | siehe Tag |
| Neu | Bruttoprinzip: Umsatz, Gebühren, Werbung getrennt, Auszahlung nicht gebucht; Reverse Charge für Amazon/Stripe/Shopify, PayPal steuerfrei | L-28.3, L-28.4, FA-2.46, P-S51, P-S52, P-S54 | siehe Tag |
| Neu | Reverse Charge in Übersicht und UVA-Export mit Kennzahlen je Land (AT Kz 057/066, DE Kz 46/47/67), auch für Kleinunternehmer | L-28.4, FA-3.3, FA-3.4 | siehe Tag |
| Neu | Dubletten still übersprungen (Schema 17 `platform_import_rows`), OSS- und FBA-Warnung | L-28.5, FA-2.45, FA-2.47, P-S53 | siehe Tag |
| Neu | Käuferdaten werden nie übernommen (Test über alle Tabellen) | L-28.6, FA-2.49, P-R36 | siehe Tag |
| Neu | Hinweis „Gebührenrechnung als Beleg ablegen“ mit direktem Link, Anleitung je Plattform im Handbuch | L-28.7, FA-2.48 | siehe Tag |

---

## 0.10.0+15 — 2026-10-14

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK, fester Testschlüssel); Stufe A3 Link-QR |
| Commit | siehe Git-Tag `v0.10.0` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.52, Spezifikation 1.49, Benutzerhandbuch für 0.10.0, DESIGN_SPEC 1.2 |
| Datenbankschema | 16 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `link_invoice_test.dart` inkl. Touchflächen ≥ 48 dp), Emulator-Job `android-ocr-emulator`, CI siehe Lauf zum Tag |
| Steuerliche Kennwerte | keine Änderung |
| Offene reale Prüfpunkte | wie 0.9.0+14, dazu P-R35, P-U6 |

**Änderungen seit 0.9.0+14**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | Link-QR: Hinweisstreifen mit Domain groß, Laden nur nach Tipp, nur https/PDF/XML ≤ 20 MB, andere Domain nur nach erneuter Anzeige, sonst „Im Browser öffnen“ | L-27.7, FA-2.42, P-U6 | siehe Tag |
| Neu | Datenfluss „Rechnung über Link-QR“ dreifach dokumentiert (Lastenheft 5.19, PRIVACY, STORE_LISTING) | L-19.5, P-R35 | siehe Tag |

---

## 0.9.0+14 — 2026-10-14

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK, fester Testschlüssel); Stufe A2 PDF- und E-Rechnungen |
| Commit | siehe Git-Tag `v0.9.0` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.51, Spezifikation 1.48, Benutzerhandbuch für 0.9.0, DESIGN_SPEC 1.2 |
| Datenbankschema | 16 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `e_invoice_test.dart` mit KoSIT-Testsuite 01.01a UBL/CII, ebInterface 6.1, ZUGFeRD-PDF), Emulator-Job `android-ocr-emulator` mit PDF-Seitenbild, CI siehe Lauf zum Tag |
| Steuerliche Kennwerte | `spec.schema_version` 15 → 16 |
| Offene reale Prüfpunkte | wie 0.8.0+13 |

**Änderungen seit 0.8.0+13**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | PDF-Rechnungen: eingebettetes XML, Seitenbilder (PdfRenderer/PDFKit), Texterkennung als Rückfall, iOS-Textebene | L-27.5, FA-2.39 | siehe Tag |
| Neu | E-Rechnung CII (ZUGFeRD/Factur-X/XRechnung), UBL (XRechnung), ebInterface strukturiert | L-27.6, FA-2.40 | siehe Tag |
| Neu | Originaldatei unverändert mit SHA-256, in Sicherung und Belegliste; Schema 16 `receipt_documents` | L-27.8, FA-2.41 | siehe Tag |
| Neu | Teilen-Ziel für PDF/XML, iOS „Öffnen in“ | L-27.4, FA-2.38 | siehe Tag |
| Neu | Abhängigkeit `xml` 7.1 (MIT) | FA-2.40 | siehe Tag |

---

## 0.8.0+13 — 2026-10-14

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK, fester Testschlüssel); Stufe A1 Kassen-QR, Zahlungs-QR, Teilen-Ziel |
| Commit | siehe Git-Tag `v0.8.0` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.50, Spezifikation 1.47, Benutzerhandbuch für 0.8.0, DESIGN_SPEC 1.2 |
| Datenbankschema | 15 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `receipt_codes_test.dart`), Emulator-Job `android-ocr-emulator` mit synthetischem RKSV- und EPC-QR, CI siehe Lauf zum Tag |
| Steuerliche Kennwerte | `spec.schema_version` 14 → 15 |
| Offene reale Prüfpunkte | wie 0.7.0+12, dazu P-S49, P-S50, P-U5 |

**Änderungen seit 0.7.0+12**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | QR-/Barcodes auf demselben Foto (ML Kit Barcode Scanning gebündelt, iOS Vision) | L-27.1, FA-2.35 | siehe Tag |
| Neu | Kassen-QR RKSV/TSE mit Vorrang bei Betrag, Datum, Sätzen; „Besonders“ nicht geraten; Lernspeicher Kasse → Händler (Schema 15); Vermerk „vom Kassen-QR“ | L-27.2, FA-2.36, P-S49, P-S50 | siehe Tag |
| Neu | Zahlungs-QR EPC069-12: Empfänger, Betrag, IBAN, Referenz | L-27.3, FA-2.37 | siehe Tag |
| Neu | Teilen-Ziel Android für Bilder | L-27.4, FA-2.38, P-U5 | siehe Tag |

---

## 0.7.0+12 — 2026-10-14

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK, fester Testschlüssel); Steuersätze aufteilen, Mahnfrist, Einhandbedienung links/rechts |
| Commit | siehe Git-Tag `v0.7.0` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.48, Spezifikation 1.46, Benutzerhandbuch für 0.7.0, DESIGN_SPEC 1.2 |
| Datenbankschema | 14 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `receipt_vat_split_test.dart`, `manual_expense_dashboard_test.dart`, `dunning_followup_test.dart`, `pdf_fonts_test.dart`), Emulator-Job `android-ocr-emulator`, CI siehe Lauf zum Tag |
| Steuerliche Kennwerte | `spec.schema_version` 13 → 14 |
| Offene reale Prüfpunkte | wie 0.6.0+11, dazu P-S46 bis P-S48, P-L19, P-X7 |

**Änderungen seit 0.6.0+11**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Behoben | Gerätetest 0.6.0: Ausgabe in der Übersicht – Kleinunternehmer zählen Ausgaben brutto (keine Vorsteuer), Balken-Mindesthöhe 6 dp, nur der jüngste Ladevorgang zeigt Summen | FA-3.2, FA-3.5, FA-3.7, P-S47 | siehe Tag |
| Behoben | € und Gedankenstrich in allen PDFs: eingebettete Schrift Work Sans (OFL) statt Helvetica | FA-5.30, P-L19 | siehe Tag |
| Geändert | Termin-Box ans Ende der Übersicht | FA-3.7 | siehe Tag |
| Neu | Beleg mit mehreren Steuersätzen aufteilen, Rest automatisch, Auswertungen/UVA/Exporte je Satz (DATEV eine Buchung je Satz), Belegerkennung belegt Aufteilung vor; Schema 14 `receipt_vat_lines` | L-2.27, FA-2.33, FA-2.34, P-S46, P-S48 | siehe Tag |
| Neu | Mahnwesen: neue Frist je Schreiben, „überfällig“ erst nach deren Ablauf; Mahnsymbol mit Stufe und Frist, Tipp zeigt Verlauf | L-3.31, FA-5.26, FA-5.27 | siehe Tag |
| Geändert | Kundendokumente (Rechnung, Mahnung, Begleittext) in Sie-Form | FA-5.28 | siehe Tag |
| Neu | Hinweis „Leistungsdatum liegt nach dem Rechnungsdatum – stimmt das?“ | FA-5.29 | siehe Tag |
| Geändert | Einhandbedienung links und rechts: zentrierte Knöpfe „Beleg erfassen“, „Neue Rechnung“, „Neuer Kunde“; Rechnungskarte mit Aktionsleiste inkl. „PDF senden“ | FA-12.7, P-X7 | siehe Tag |

---

## 0.6.0+11 — 2026-10-14

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK, fester Testschlüssel); Einhandbedienung |
| Commit | siehe Git-Tag `v0.6.0` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.47, Spezifikation 1.45, Benutzerhandbuch für 0.6.0, DESIGN_SPEC 1.2 |
| Datenbankschema | 13 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `one_hand_test.dart`), Emulator-Job `android-ocr-emulator`, CI siehe Lauf zum Tag |
| Steuerliche Kennwerte | keine Änderung |
| Offene reale Prüfpunkte | wie 0.5.0+10, dazu P-X1 bis P-X6 |

**Änderungen seit 0.5.0+10**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Geändert | Übersicht: ein zentrierter Knopf „Beleg fotografieren“ statt zweier Knöpfe rechts; öffnet direkt die Kamera, Einnahme/Ausgabe im Formular | FA-12.1, DESIGN_SPEC 5a | siehe Tag |
| Geändert | Beleg stornieren und Kunde löschen aus der AppBar an das Formularende (rot umrandet, Bestätigung in Fehlerfarbe); ebenso Fehlerfarbe bei „Sicherung ausschalten“ und „Wiederherstellen“ | FA-12.2, P-X2 | siehe Tag |
| Geändert | Belegseiten: Pfeile 48 dp, Löschen über Antippen der Seite; Chip-Reihen umbrechend, Jahr als Chip; Datum „Heute/Gestern“; `PrimaryActionBar` in Kunden- und Stammdatenformular. Test `one_hand_test.dart` | FA-12.3 bis FA-12.6, P-X1, P-X3 bis P-X6 | siehe Tag |

---

## 0.5.0+10 — 2026-10-14

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK, fester Testschlüssel); Mahnwesen |
| Commit | siehe Git-Tag `v0.5.0` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.47, Spezifikation 1.44, Benutzerhandbuch für 0.5.0 |
| Datenbankschema | 13 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `dunning_test.dart`, `invoice_list_ux_test.dart`), Emulator-Job `android-ocr-emulator`, CI siehe Lauf zum Tag |
| Steuerliche Kennwerte | `spec.schema_version` = 13; neu `spec.dunning_default_fee_cents` = 1000, `spec.dunning_period_days` = 14, `spec.*.dunning_consumer_rate_bp` (AT 400), `spec.*.dunning_consumer_surcharge_bp` (DE 500), `spec.*.dunning_business_surcharge_bp` (AT 920, DE 900), `spec.*.dunning_flat_fee_cents` = 4000, `spec.*.dunning_base_rates`, `spec.*.dunning_consumer_notice`, `spec.*.dunning_interest_legal_ref` |
| Offene reale Prüfpunkte | P-D21, P-D22, P-D25, P-D26, P-S27 bis P-S35, P-S40 bis P-S45, P-R24 bis P-R26, P-R30 bis P-R34 |

**Änderungen seit 0.4.0+9**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | Zahlungserinnerung und Mahnungen beliebig oft (Stufe 1 Erinnerung, dann 1., 2. … Mahnung) als Bottom-Sheet mit Vorschau, PDF mit Tabelle und neuer Frist, Teilen; unveränderlich mit SHA-256, Storno mit Begründung. Schema 13 (`dunning_notices`). Test `dunning_test.dart`, `invoice_list_ux_test.dart` | L-3.10, L-3.29, FA-5.21, P-R33 | siehe Tag |
| Neu | Mahnkosten 10 € ab 1. Mahnung (änderbar) mit Hinweis bei Privatkunden; optionale Verzugszinsen act/365 je Halbjahr aus Basiszinssatz; Pauschale 40 € nur B2B | L-3.27, GR-13, FA-5.22, FA-5.23, P-R32, P-R34, P-S44 | siehe Tag |
| Neu | Kundenmerkmal „Unternehmen“ (folgt der UID); DE-Rechnungen an Privatkunden mit Hinweis § 286 Abs 3 BGB | L-3.28, FA-5.24 | siehe Tag |
| Neu | „Bezahlt“ fragt „Mahnkosten und Zinsen mitbezahlt?“ und bucht sie als nicht umsatzsteuerbare Einnahme | L-3.30, FA-5.25, P-S45 | siehe Tag |
| Geändert | Rechnungsliste: Hinweis „überfällig – mahnen?“, Tonal-Knöpfe „Erinnern/Mahnen“ und „Bezahlt“ in eigener Zeile (≥ 48 dp) | FA-5.13, FA-5.20 | siehe Tag |

---

## 0.4.0+9 — 2026-10-14

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK, fester Testschlüssel); Rabatt, Versand, Skonto, AGB-Verweis |
| Commit | siehe Git-Tag `v0.4.0` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.46, Spezifikation 1.43, Benutzerhandbuch für 0.4.0 |
| Datenbankschema | 12 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `invoice_totals_test.dart`, `invoice_form_ux_test.dart`), Emulator-Job `android-ocr-emulator`, CI siehe Lauf zum Tag |
| Steuerliche Kennwerte | `spec.schema_version` = 12; neu `spec.primary_action_height_dp` = 56, `spec.min_touch_target_dp` = 48 |
| Offene reale Prüfpunkte | P-D21, P-D22, P-D25, P-D26, P-S27 bis P-S35, P-S40 bis P-S43, P-R24 bis P-R26, P-R30, P-R31 |

**Änderungen seit 0.3.5+8**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | Rabatt je Position und auf die Rechnung (Prozent oder Betrag), Gesamtrabatt anteilig je Steuersatz mit Restcent nach größtem Rest; Versandkosten wie Hauptleistung (anteilig bei Mischsätzen) oder fester Satz; Rechnen in `InvoiceTotals`. Schema 12. Test `invoice_totals_test.dart` | L-3.21, L-3.22, GR-12, FA-5.15, FA-5.16, P-S40, P-S41 | siehe Tag |
| Neu | Skonto (Tage + Prozent, Vorschlag aus dem Profil), auf dem PDF mit festem Datum und Betrag; „Bezahlt“ fragt „Mit Skonto bezahlt?“ und mindert die Einnahme je Satz; Rechnung bleibt unverändert | L-3.23, L-3.24, FA-5.17, FA-5.18, P-S42, P-S43 | siehe Tag |
| Neu | AGB-Adresse im Profil, Verweis „soweit sie vereinbart wurden“ auf dem PDF, eingefroren mit der Rechnung; einmaliger Hinweis zur Einbeziehung | L-3.25, L-3.26, FA-5.19, P-R30 | siehe Tag |
| Geändert | Bedienung nach UX-Prüfinstanz: `PrimaryActionBar` (56 dp, über der Tastatur) im Rechnungsformular, nach dem Ausstellen „PDF senden“; „Position hinzufügen“ volle Breite, Entfernen 48 dp; Rabatt/Versand/Skonto eingeklappt; Tonal-Knopf „Bezahlt“ mit Bottom-Sheet; Stornieren/Löschen in Fehlerfarbe mit Bestätigung. Test `invoice_form_ux_test.dart` | FA-5.20 | siehe Tag |

---

## 0.3.5+8 — 2026-10-14

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK, fester Testschlüssel); Wirtschaftsjahr, Termin-Box, bezahlte Rechnung als Einnahme, Hilfe offline |
| Commit | siehe Git-Tag `v0.3.5` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.45, Spezifikation 1.42, Benutzerhandbuch für 0.3.5 |
| Datenbankschema | 11 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün, Emulator-Job `android-ocr-emulator`, CI siehe Lauf zum Tag |
| Steuerliche Kennwerte | neu `spec.*.deadline_rules`, `spec.*.monthly_vat_return_threshold_cents` (AT 10000000, DE 900000), `spec.*.vat_interval_basis`, `spec.*.fiscal_year_legal_ref`, `spec.*.deadline_shift_legal_ref`, `spec.*.asks_federal_state`, `spec.deadline_box_count` = 4 |
| Offene reale Prüfpunkte | P-D21, P-D22, P-D25, P-D26, P-S27 bis P-S35, P-R24 bis P-R26 |

**Änderungen seit 0.3.4+7**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Geändert | Belegformular: Vollständigkeitsbestätigung und Speichern zu einem Knopf zusammengelegt („Vollständig – Beleg speichern (n Seiten)“, unten fixiert, über der Tastatur, Telefon volle Breite, Tablet rechts); Häkchen entfällt; bei einer Seite Knopf „Rückseite?“; Protokoll „Vollständigkeit bestätigt“. Test `receipt_save_bar_test.dart` | FA-2.14, P-S31 | fbbc404 |
| Behoben | Bezahlte Ausgangsrechnung erschien nicht in Übersicht, Grenze und Verlauf (Gerätetest 0.3.4): „Bezahlt“ fragt den Zahlungseingang (vorbelegt heute) und bucht die Einnahme je Steuersatz an diesem Tag; alte bezahlte Rechnungen werden beim Start nachgebucht; keine Doppelbuchung (eindeutiger Index). Schema 11. Test `invoice_payment_test.dart` | L-25.9, FA-5.12, GR-11, P-S35 | 0a5bb7c |
| Behoben | Übersicht: schwebende Knöpfe verdeckten den rechten Rand der Karten; 160 dp Abstand unten | Spezifikation 7 | 0a5bb7c |
| Neu | Wirtschaftsjahr: „Erster Monat Wirtschaftsjahr“ in den Stammdaten mit einmaliger Bestätigung; Übersicht „Dieses WJ“, Export „Wirtschaftsjahr“, DATEV „WJ-Beginn“; Umsatzsteuer und Kleinunternehmergrenze bleiben Kalenderjahr (Regressionstest) | L-24, GR-10, FA-10.1, FA-10.2, P-S32 | 0a5bb7c |
| Neu | Termin-Box „Nächste Termine“ auf der Übersicht (nur Anzeige): UVA/UStVA, ZM, ESt-Vorauszahlung, Erklärung, SVS (ca.), Feiertage AT/DE mit Verschiebung auf den nächsten Werktag, Bundesland (DE), Rhythmus-Vorschlag aus dem Vorjahr. Test `deadline_calculator_test.dart` | L-25, FA-10.3 bis FA-10.8, P-S33, P-S34, P-R24, P-D25 | 0a5bb7c |
| Neu | Hilfe Stufe 1 offline: Fragezeichen oben rechts, Suche im Benutzerhandbuch (BM25, Umlaute, Synonyme), Abschnitt lesen, Beleg-Themen zuerst aus dem Belegformular; ohne Treffer E-Mail an den Support mit Betreff und App-Version, ohne Anhang. Handbuch als Asset, Test `help_test.dart` | L-26, FA-11.1 bis FA-11.3, P-D26 | dd4adfa |

---

## 0.3.4+7 — 2026-10-14

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK, fester Testschlüssel); mehrsprachige Belegerkennung |
| Commit | siehe Git-Tag `v0.3.4` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.42, Spezifikation 1.38, Benutzerhandbuch für 0.3.4 |
| Datenbankschema | 10 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (Korpus 6 Belege), Emulator-Job `android-ocr-emulator`, CI siehe Lauf zum Tag |
| Steuerliche Kennwerte | `spec.at.vat_permille` = 200,130,100,49,0; neu `spec.at.vat_49_valid_from` = 2026-07-01 |
| Offene reale Prüfpunkte | P-D21, P-D22, P-S27 bis P-S30 |

**Änderungen seit 0.3.3+6**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Behoben | Übersicht lädt nach Speichern oder Stornieren eines Belegs in einem anderen Reiter und nach Wiederherstellung neu (`AppState.bookingsRevision`); vorher blieben „Dieser Monat“ und „Letzte Belege“ auf dem Stand des App-Starts. Test `dashboard_refresh_test.dart` | Gerätetest 0.3.3 | 7971df3 |
| Neu | Belegerkennung mehrsprachig: Schlüsselwort-Tabellen in 15 Sprachen (`receipt_keywords.dart`), Satz nach „%“ („DDV % 22,0“), Dezimalsätze (4,90 %), Steuerzeilen mit Rechenprobe vor unsicherem Brutto, Datum „05.09,2026“ und JJJJ.MM.TT. | FA-2.30 | dieser |
| Neu | Beschreibung und Kategorie werden aus Händler/Branche vorgeschlagen; Logo-Rauschen „SPARO“ → SPAR; neue Belege starten mit „Sonstige Ausgaben“ statt „Bankspesen“ (Gerätetest 0.3.3) | FA-2.31 | dieser |
| Neu | Österreich 4,9 % (Grundnahrungsmittel, § 10 Abs 1a UStG 1994) ab 1.7.2026; Steuersätze mit Gültigkeitsbeginn, Auswahllisten datumsabhängig | GR-3, P-S28 | dieser |
| Geändert | Beleg ohne Steuerausweis: 0 % mit Hinweis statt Standardsatz; unbekannter Satz: Hinweis „noch nicht hinterlegt“; ausländische USt: Länderhinweis aus dem TaxProfile | FA-2.32, FA-2.29, P-S29, P-S30 | dieser |
| Neu | Korpus: ML-Kit-Ergebnis des DARS-Belegs (Slowenien) aus dem Emulatorlauf 38515679584; Steuertabelle „DDV % / Osnova / Znesek / Skupaj“ ohne Prozentzeichen, EU-Satz ohne lesbare UID als ausländisch (0 %), entstellte Jahreszahl „2ULG“ | FA-2.28, FA-2.30 | dieser |
| Behoben | Belegdatum wurde bei „05.09,2026“/„10.09,2026“ (Komma statt Punkt) nicht erkannt (Gerätetest SPAR, Villach) | FA-2.30 | dieser |

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
