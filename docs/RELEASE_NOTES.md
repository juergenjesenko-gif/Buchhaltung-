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
| Commit | Kurz-Hash des Commits, der die Version setzt (Testbuilds ohne Git-Tag) |
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

Änderungen seit 0.37.0+50, die noch in keinem Build stecken. Wandern beim
nächsten Versionssprung in den neuen Eintrag.

| Art | Änderung | Bezug | Commit |
|---|---|---|---|

---

## 0.37.0+50 — 2026-10-20

| Feld | Wert |
|---|---|
| Art | Interner Test (TestFlight, Google Play interner Track) über `release.yml` und Test-APK aus `ci.yml`; **Lizenzprüfung aus**, alle Funktionen frei |
| Commit | `830b4ee` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.89, Spezifikation 1.98, REGELPFLEGE 2026-10-20, Benutzerhandbuch für 0.37.0, DESIGN_SPEC 1.7 |
| Datenbankschema | 31 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün; Android/iOS-Build nur in der CI |
| Steuerliche Kennwerte | unverändert |
| Offene reale Prüfpunkte | P-D19, P-D58 |
| Bekannte Grenzen | unverändert (Spezifikation 11) |

**Änderungen seit 0.36.0+49**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Geändert | Beleg- und Rechnungsliste: Kopf (Suche, Filter, Angebote/Artikel) scrollt mit der Liste | FA-9.6 | `830b4ee` |

---

## 0.36.0+49 — 2026-10-20

| Feld | Wert |
|---|---|
| Art | Interner Test (TestFlight, Google Play interner Track) über `release.yml`; Buildnummer = Laufnummer der CI; **Lizenzprüfung aus**, alle Funktionen frei |
| Commit | `ca570fb` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.89, Spezifikation 1.97, REGELPFLEGE 2026-10-20, Benutzerhandbuch für 0.36.0, DESIGN_SPEC 1.7 |
| Datenbankschema | 31 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu: Telefon quer 915 × 412 ohne Liste-Detail); Android/iOS-Build nur in der CI |
| Steuerliche Kennwerte | unverändert; neu `spec.window_compact_max_height_dp` = 480 |
| Offene reale Prüfpunkte | P-D19 (Querformat am Gerät), P-D58 |
| Bekannte Grenzen | unverändert (Spezifikation 11) |

**Änderungen seit 0.35.0+48**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Behoben | Telefon quer: keine drei schmalen Spalten mehr, schmale Navigationsleiste und Inhalt über die volle Breite | FA-9.1 | `ca570fb` |
| Behoben | Vertrag ablegen: „Scannen“ und „Galerie“ gleich breit und bündig mit „Text erkennen“ | FA-19 | `ca570fb` |

---

## 0.35.0+48 — 2026-10-20

| Feld | Wert |
|---|---|
| Art | Interner Test (TestFlight, Google Play interner Track) über `release.yml`; Buildnummer = Laufnummer der CI; **Lizenzprüfung aus** (ohne Eingabe `abo`), alle Funktionen frei |
| Commit | `511dd71` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.89, Spezifikation 1.96, REGELPFLEGE 2026-10-20, Benutzerhandbuch für 0.35.0, DESIGN_SPEC 1.7 |
| Datenbankschema | 31 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün; Android/iOS-Build nur in der CI |
| Steuerliche Kennwerte | unverändert |
| Offene reale Prüfpunkte | neu P-D58 |
| Bekannte Grenzen | unverändert (Spezifikation 11) |

**Änderungen seit 0.34.0+47**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | Versionsanzeige mit Buildnummer am Ende der Einstellungen und in Support-Mails | FA-11.8 | `511dd71` |
| Geändert | Sicherung von Hand mit 8-stelligem Zahlencode statt Kennwort | FA-7.2 | `4233656` |
| Geändert | Automatische Sicherung: Abtippen von zwei Blöcken entfällt | FA-7.10 | `4233656` |
| Geändert | Release-Builds ohne Lizenzprüfung, außer mit Eingabe `abo` (Tester sehen Pro) | FA-13.10 | `4233656` |
| Behoben | Tastatur schließt bei Tippen neben ein Eingabefeld (iOS-Ziffernblock ohne Fertig-Taste) | SPEC 7 | `5fefe06` |
| Geändert | Ersteinrichtung: Umsatz des laufenden Jahres optional (leer = 0, Hinweis zum Nachbuchen) | FA-1.8 | `03ff86e` |
| Geändert | Willkommensseite: Titel über dem Logo, mehr Abstand vor den Funktionszeilen | FA-1.13 | `03ff86e` |
| Behoben | Release-Workflow iOS: Archiv unsigniert, Signierung beim Export | RELEASE_PLAYBOOK | `44b7a30` |
| Behoben | Release-Workflow iOS: Archiv mit Verteilungsidentität (kein registriertes Gerät nötig) | RELEASE_PLAYBOOK | `8b2db6e` |
| Behoben | Release-Workflow iOS: Konfiguration mit --no-codesign, Signierung allein über xcodebuild und App-Store-Connect-Schlüssel | RELEASE_PLAYBOOK | `fb644a7` |

---

## 0.34.0+47 — 2026-10-20

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.34.0-build-<Nr>.apk`, fester Testschlüssel); **Lizenzprüfung aus** (ohne `LICENSING=true`), alle Funktionen frei |
| Commit | `48ee0d0` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.89, Spezifikation 1.95, REGELPFLEGE 2026-10-20, Benutzerhandbuch für 0.34.0, DESIGN_SPEC 1.7 |
| Datenbankschema | 31 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `booking_rules_test.dart`: Anteil aus km/m², Rundung exakt, Vorsteuer AT/DE/KU, 10-%-Grenze, Geltungsbereich, Gültigkeit, Ausnahme, Verlauf unveränderlich, Bericht/CSV/PDF; `rules_freshness_test.dart`: Ablauf, Hinweistext, Schätzungsvermerk, Einstellungszeile). Android/iOS-Build nur in der CI |
| Steuerliche Kennwerte | neu `spec.at.mixed_use`, `spec.de.mixed_use` (10 % Mindestnutzung für Vorsteuer), `spec.*.rules_as_of` 2026-01-01, `spec.*.rules_valid_until` 2026-12-31 |
| Offene reale Prüfpunkte | neu P-S88, P-S89, P-S90, P-R65, P-R66, P-X29, P-X30, P-D57 |
| Bekannte Grenzen | neu „Buchungsregeln nur als Kostenaufteilung“ (Spezifikation 11) |

**Änderungen seit 0.33.0+46**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Geändert | Einstellungen: „Symbol auf Startbildschirm legen“ an das Ende der Stammdaten-Liste | FA-1.19 | `5c487ef` |
| Geändert | Rechnungs-, Storno- und Mahnungs-PDF in Markenfarbe Marineblau #0B3A67 statt #1B4965 | DESIGN_SPEC 9 | `b5ebe1f` |
| Neu | Buchungsregeln (Privatanteil / betrieblicher Anteil, Fahrtenbuch/Fläche, Gültigkeit, Begründung, Anhänge, Verlauf), Schema 31 | FA-20.1, FA-20.2 | `091e639` |
| Neu | Wirkung auf Gewinn und Vorsteuer, Karte „Regel: … betrieblich“ an der Buchung mit Ausnahme | FA-20.3, FA-20.4 | `091e639` |
| Neu | Abschnitt „Buchungsregeln und Angaben für die Steuerberatung“ in Saldenliste, Jahresabschluss, Paket (`Buchungsregeln.csv`, Anhänge) | FA-20.5 | `091e639` |
| Neu | Hilfeartikel „Privat-PKW teilweise betrieblich“ und „Büro in der eigenen Wohnung“ mit „Regel anlegen“; Demo-Musterregeln | FA-20.6, FA-20.7 | `091e639` |
| Doku | KI-Chat als Stufe C (L-21.13), Tarif Pro (O-47) | FA-20.8 | `091e639` |
| Neu | Regelstand je Land in den Einstellungen; Hinweis „Für <Jahr> gibt es neue Steuerwerte – bitte App aktualisieren.“ mit Store-Link; „Werte von <Jahr> – Schätzung unsicher“ bei Abgaben und Kennzahlen | FA-21.1–FA-21.3 | `48ee0d0` |
| Doku | `docs/REGELPFLEGE.md`: Checkliste aller Steuerwerte mit Quelle, Termin, Codestelle, `spec.*` | FA-21.1 | `48ee0d0` |

---

## 0.33.0+46 — 2026-10-19

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.33.0-build-<Nr>.apk`, fester Testschlüssel); **Lizenzprüfung aus** (ohne `LICENSING=true`), alle Funktionen frei |
| Commit | `8578354` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.88, Spezifikation 1.93, Benutzerhandbuch für 0.33.0, DESIGN_SPEC 1.7 |
| Datenbankschema | 30 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `brand_assets_test.dart`: Logo hell/dunkel 1x/2x/3x, Android-Symbole klassisch/adaptiv/monochrom, iOS 1024 ohne Alpha; `welcome_page_test.dart`: Logo 280 dp auf 360 × 740 ohne Scrollen, Dunkelmodus helles Logo). Android/iOS-Build nur in der CI |
| Steuerliche Kennwerte | unverändert |
| Offene reale Prüfpunkte | wie 0.32.0+45 (P-R63 um Werbetext ohne „statt“-Preis ergänzt) |
| Bekannte Grenzen | Spezifikation Abschnitt 11 unverändert; App-Symbol ist eine Vektor-Rekonstruktion bis zur Lieferung der Originale (DESIGN_SPEC 10a) |

**Änderungen seit 0.32.0+45**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Geändert | E-Rechnung ausstellen ab Basis (`Feature.eInvoiceIssue`), Zustellen über Teilen-Blatt, Senden mit einem Tipp bleibt Pro | FA-13.2, O-44 | `69ae0d8` |
| Geändert | Apple: 14 Tage gratis auf allen vier Produkten, Preis fürs erste Jahr nur per Angebotscode `JENIBUCHTSTART`; Abo-Text „14 Tage gratis, danach Grundpreis“ auf iOS getestet | FA-13.16, O-45 | `69ae0d8` |
| Neu | Pro-Code `JENIBUCHT20PRO` (20 % aufs Pro-Jahresabo), auf Android gleiches Angebots-Tag | FA-13.16, O-46 | `69ae0d8` |
| Neu | Endgültiges Hauptlogo auf der Willkommensseite, im Dunkelmodus mit hellen Linien | FA-1.13, DESIGN_SPEC 10a | `8578354` |
| Neu | App-Symbol (Android klassisch, adaptiv, Android-13-Monochrom; iOS-Satz), Startbildschirm Hellblau mit Symbol | DESIGN_SPEC 10a | `8578354` |
| Geändert | Farbschema Marineblau `#0B3A67`, Hellblau `#EAF2FF` als Container | DESIGN_SPEC 2 | `8578354` |
| Doku | Instagram-Texte zum 20-%-Code ohne „statt“-Preis (Pro und Basis) | O-46, P-R63 | `8578354` |

---

## 0.32.0+45 — 2026-10-19

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.32.0-build-<Nr>.apk`, fester Testschlüssel); **Lizenzprüfung aus** (ohne `LICENSING=true`), alle Funktionen frei – auch E-Rechnung ausstellen |
| Commit | `7ed206f` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.86, Spezifikation 1.91, Benutzerhandbuch für 0.32.0, DESIGN_SPEC 1.6 |
| Datenbankschema | 30 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `e_invoice_writer_test.dart`: CII für ZUGFeRD und XRechnung sowie ebInterface 6.1 je Fall XSD-gültig über `xmllint` mit Factur-X-1.09-EN-16931- und ebInterface-6.1-Schema, Rundreise über `EInvoiceParser` mit gleichen Summen je Satz – Kleinunternehmer DE, Regelbesteuerung 19/7 % mit Positions- und Gesamtrabatt, Versand, Skonto, Storno als 381 (Regel und KU), AT 20/10 % –, ZUGFeRD-PDF mit eingebetteter `factur-x.xml`, Pflichtangaben je Format, Migration 29 → 30; `pdf_viewer_test.dart`: Hinweiszeile und „XML senden“; `one_hand_test.dart`: Kundin E-Rechnung 56 dp; `welcome_page_test.dart`: „Rechnungen & E-Rechnungen schreiben“ einzeilig). Intern zusätzlich Mustang 2.26 (veraPDF PDF/A-3b, EN-16931- und XRechnung-3.0-Schematron): alle Muster gültig. Android/iOS-Build nur in der CI |
| Steuerliche Kennwerte | `spec.schema_version` 30, neu `spec.einvoice_guideline_en16931`, `spec.einvoice_guideline_xrechnung`, `spec.einvoice_zugferd_file`, `spec.einvoice_ebinterface_namespace`; aus FA-13.16 `spec.license_promo_code_discount`, `spec.license_promo_discount_percent` |
| Offene reale Prüfpunkte | wie 0.31.0+44, neu P-S86, P-S87, P-R62, P-R63, P-R64, P-D55, P-D56, P-X28; Entscheidung O-44 (Tarif E-Rechnung) offen |
| Bekannte Grenzen | Spezifikation Abschnitt 11, neu „E-Rechnung: Grenzen beim Ausstellen“ statt „E-Rechnung nur im Empfang“ |

**Änderungen seit 0.31.0+44**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | Abo-Seite zeigt Test, Einführungspreis des ersten Jahres und Grundpreis aus den Preisphasen des Stores; neue Preise (Lastenheft 5.10); zweiter Instagram-Code `JENIBUCHT20` (20 % aufs Jahresabo im ersten Jahr) | FA-13.16, O-45, O-46, P-R62, P-R63, P-D55 | c5a3ef3 |
| Neu | E-Rechnung erstellen: jede Rechnung und Stornorechnung als ZUGFeRD-PDF (PDF/A-3b mit `factur-x.xml`, EN 16931); für Behörden XRechnung 3.0 (CII) bzw. ebInterface 6.1 mit „XML senden“; Prüfung der Pflichtangaben mit Hinweis | FA-5.49, L-4.1, L-4.2 | `7ed206f` |
| Neu | Kundin: Abschnitt „E-Rechnung“ mit Format, Leitweg-ID/Auftragsreferenz bzw. Käuferreferenz, Lieferantennummer (Schema 30) | FA-5.49, 4.1 | `7ed206f` |
| Geändert | Tarif `eInvoiceIssue` Pro (Lastenheft 5.10), Vorschlag Basis an den Auftraggeber | FA-13.2, O-44 | `7ed206f` |
| Geändert | Willkommensseite „Rechnungen & E-Rechnungen schreiben“; Store-Texte mit Abschnitt „E-Rechnungen schreiben“ (Store-Texte schon in `c5a3ef3` enthalten) | FA-1.13, P-R64 | `7ed206f` |
| Doku | Datenfluss Rechnungsversand (Lastenheft 5.19, PRIVACY, STORE_LISTING); Prüfmappe Steuerberater neu erzeugt | L-19.5 | `7ed206f` |

---

## 0.31.0+44 — 2026-10-19

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.31.0-build-<Nr>.apk`, fester Testschlüssel); **Lizenzprüfung aus** (ohne `LICENSING=true`), alle Funktionen frei |
| Commit | `b400a36` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.84, Spezifikation 1.89, Benutzerhandbuch für 0.31.0, DESIGN_SPEC 1.6 |
| Datenbankschema | 29 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `scroll_auto_hide_test.dart`: Ausblenden beim Scrollen, nach 5 s zurück, oben sofort, nicht während eines Tipps, mit Bedienungshilfe immer sichtbar; `pdf_viewer_test.dart`: dunkles Thema mit weißem Papier ohne Filter; `welcome_page_test.dart`: Textbreite jeder Funktionszeile auf 360 und 412 dp; `small_business_monitor_test.dart`: DE 25.000-€-Anzeige und Folgejahreswarnung, AT Grenzenhinweis mit Toleranz; `demo_test.dart`: deutsche Musterfirma, Ampel an 25.000 €, Listen gefüllt, Landeswahl; `setup_wizard_test.dart`: Mithelfer-Option in Schritt 2); Android/iOS-Build nur in der CI |
| Steuerliche Kennwerte | keine Änderung; neu `spec.demo_de_company`, `spec.demo_de_receipt_count`, `spec.capture_bar_show_after_s` |
| Offene reale Prüfpunkte | wie 0.30.0+43, neu P-X27, P-S85, P-R61 |
| Bekannte Grenzen | Spezifikation Abschnitt 11 |

**Änderungen seit 0.30.0+43**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Geändert | Willkommensseite: Punkt statt Gedankenstrich, Titel größer, mehr Abstand, Funktionszeilen einzeilig, „Sicherung wiederherstellen“; Mithelfer-Koppeln als Nebenoption in Schritt 2 | FA-1.13, FA-17.2, FA-17.13, L-29.1 | `b400a36` |
| Behoben | PDF-Betrachter im dunklen Modus: Seite auf weißem Papier in Originalfarben | FA-5.48 | `b400a36` |
| Neu | Aufnahmeleiste der Übersicht weicht beim Scrollen aus, nach 5 s zurück | FA-12.1 | `b400a36` |
| Geändert | Kleinunternehmergrenze je Land: DE misst an 25.000 € mit Warnung fürs Folgejahr, Grenzenhinweis DE/AT | FA-4.14, P-S85 | `b400a36` |
| Neu | Demo mit Landeswahl (Deutschland zuerst) und deutscher Musterfirma „Muster Handel“ (§ 19 UStG) | FA-13.14 | `b400a36` |

---

## 0.30.0+43 — 2026-10-19

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.30.0-build-<Nr>.apk`, fester Testschlüssel); **Lizenzprüfung aus** (ohne `LICENSING=true`), alle Funktionen frei |
| Commit | `f12ac05` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.83, Spezifikation 1.88, Benutzerhandbuch für 0.30.0, DESIGN_SPEC 1.5 |
| Datenbankschema | 29 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `pdf_viewer_test.dart`: Seiten wischen, „Seite x von n“, Leiste 56 dp in der Daumenzone, Drucken frei, Demo: Drucken zeigt Demo-Blatt; neu `welcome_page_test.dart`: Willkommensseite ohne Scrollen auf 360 × 740 und 412 × 915 dp, kein „E-Rechnung schreiben“; angepasst `licensing_test.dart` (`levyReserve` nur Pro, Demo frei), `setup_wizard_test.dart` (echte Schrift)); Android/iOS-Build nur in der CI |
| Steuerliche Kennwerte | keine Änderung |
| Offene reale Prüfpunkte | wie 0.29.0+42, neu P-X26, P-D54, P-R60 |
| Bekannte Grenzen | Spezifikation Abschnitt 11; „Demo ohne PDF-Vorschau“ erledigt |

**Änderungen seit 0.29.0+42**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | PDF-Betrachter (Paket `printing`): jedes erzeugte PDF und PDF-Anhänge eines Belegs zuerst ansehen; wischen, zoomen, Seitenanzeige; Schließen, Drucken (frei), Senden (Pro wie bisher); Demo gesperrt mit Hinweis | FA-5.48, FA-13.11, FA-13.14 | `f12ac05` |
| Geändert | „PDF senden“ heißt „Ansehen“ bzw. „PDF ansehen“ (Rechnungsliste, Rechnungsformular, Storno-Hinweis, Angebot, Mahnung, Berichte); Angebot gilt erst nach „Senden“ als gesendet | FA-5.46, FA-5.48 | `f12ac05` |
| Geändert | „Abgaben & Rücklagen“ nur Pro; ohne Pro Hinweiszeile „(Pro)“ zur Abo-Seite auf der Übersicht und in „Für das Finanzamt“ | O-43, FA-13.2, FA-19.1 | `f12ac05` |
| Geändert | Willkommensseite: Unterzeile und vier Funktionszeilen; Store-Kurzbeschreibung angepasst | FA-1.13, P-R60 | `f12ac05` |
| Doku | RZL-Export zurückgestellt (L-33.4, P-D52); Lastenheft 14a; interne Prüfung 2026-10-19 PDF-Betrachter | Spezifikation 14 | `f12ac05` |

---

## 0.29.0+42 — 2026-10-19

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.29.0-build-<Nr>.apk`, fester Testschlüssel); **Lizenzprüfung aus** (ohne `LICENSING=true`), alle Funktionen frei |
| Commit | `1c8007f` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.82, Spezifikation 1.87, Benutzerhandbuch für 0.29.0, DESIGN_SPEC 1.5 |
| Datenbankschema | 29 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `levy_estimator_test.dart`: Tarif AT 2025/2026 mit Beispiel usp.gv.at, § 32a DE 2025/2026 je Zone und an den Grenzen, SVS Mindest-/Höchstbeitragsgrundlage und KU-Ausnahme, Gewinnfreibetrag, GewSt mit Freibetrag und § 35-Anrechnung, Soli-Freigrenze/Milderung, Kirchensteuer je Land, Termine AT/DE, E/A-Behandlung SVS vs. ESt, Migration 28 → 29; neu `levies_screen_test.dart`: Hinweis Schätzung, Speichern ≥ 56 dp, Schalter ≥ 48 dp; angepasst `tax_office_test.dart`, `specification_sync_test.dart`); Prüfmappen neu erzeugt; Android/iOS-Build nur in der CI |
| Steuerliche Kennwerte | `spec.schema_version` 29, `spec.seed_category_count` 21, `spec.seed_category_expense_count` 18, `spec.demo_receipt_count` 28, neu `spec.*.income_tax_2025`, `spec.*.income_tax_2026`, `spec.*.profit_allowance`, `spec.*.social_insurance`, `spec.*.social_insurance_business_expense`, `spec.*.surcharges`, `spec.*.trade_tax` |
| Offene reale Prüfpunkte | wie 0.28.0+41, neu P-S78 bis P-S84, P-R59, P-D50 bis P-D53, P-X25 |
| Bekannte Grenzen | Spezifikation Abschnitt 11, neu „Abgaben nur geschätzt“ |

**Änderungen seit 0.28.0+41**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | „Abgaben & Rücklagen“: Karte „Rücklage für Steuern & SV“ auf der Übersicht, Bildschirm mit Jahresschätzung, bezahlt/offen, nächsten Zahlungen und Angaben; Einstieg aus „Für das Finanzamt“ | FA-19.1, FA-19.2, FA-19.3, FA-19.5, FA-19.6, L-31 | `1c8007f` |
| Neu | Abgabenkategorien „Sozialversicherung“, „Einkommensteuer-Vorauszahlung“, „Gewerbesteuer“ (Schema 29); private bzw. nicht abziehbare Abgaben werden dem Gewinn hinzugerechnet | FA-19.4, P-S80 | `1c8007f` |
| Neu | Paket „Für Kapitalgesellschaft / doppelte Buchführung“: Saldenliste, Belegliste, DATEV, BMD und Belegkopien als ZIP | FA-15.12, L-33, P-D50 bis P-D53 | `1c8007f` |
| Neu | Demo: SVS-Quartalsbeiträge, ESt-Vorauszahlung, Rücklagenkarte | FA-13.14 | `1c8007f` |
| Doku | Lastenheft 5.31 bis 5.33, 14a, O-43; Spezifikation 5.15, interne Prüfung 2026-10-19 Abgaben; Prüfmappen | Spezifikation 14 | `1c8007f` |

---

## 0.28.0+41 — 2026-10-19

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.28.0-build-<Nr>.apk`, fester Testschlüssel); **Lizenzprüfung aus** (ohne `LICENSING=true`), alle Funktionen frei. Ersteinrichtung im Testbuild mit vier Schritten (Abo-Schritt entfällt); vorhandene Installationen sehen sie nicht |
| Commit | `cb6bbb7` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.81, Spezifikation 1.86, Benutzerhandbuch für 0.28.0, DESIGN_SPEC 1.5 |
| Datenbankschema | 28 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `setup_wizard_test.dart`: Willkommensseite und Knöpfe 56/48 dp in der Daumenzone, Schritt 1 mit einem Häkchen, Pflichtfeld Schritt 2, „Später hinzufügen“ ≥ 48 dp mit ≥ 12 dp Abstand, Fortsetzen nach dem Schließen, Entwurf, Zurück, „?“-Blatt, EU-KU-Feld im Registrierungsformular, Mithelfer nur ohne Daten; neu `eu_sme_id_test.dart`: Format AT/DE, Rechnungsregel, Einfrieren, Migration 27 → 28; angepasst `demo_test.dart` (neu: Demo aus den Einstellungen zeigt Belege, Rechnungen, Verträge; Ampel 20–35 %), `manual_expense_dashboard_test.dart`, `specification_sync_test.dart`); Android/iOS-Build nur in der CI |
| Steuerliche Kennwerte | `spec.schema_version` 28, neu `spec.setup_steps`, `spec.eu_sme_id_suffix` |
| Offene reale Prüfpunkte | wie 0.27.0+40, neu P-R58, P-S76, P-S77, P-X24, P-D49 |
| Bekannte Grenzen | Spezifikation Abschnitt 11, neu „EU-KU-Nummer nur offline geprüft“ |

**Änderungen seit 0.27.0+40**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | Geführte Ersteinrichtung: Willkommensseite (Logo als eine austauschbare Datei, „Los geht's“, „Erst ansehen (Demo)“, „Ich habe schon Daten – Sicherung wiederherstellen“, „Ich helfe mit – Gerät koppeln“), Schritte Bestätigungen – Dein Unternehmen – Zusatzdaten – Extras – Abo, Fortschritt, Zurück, „Später hinzufügen“, Fortsetzen nach dem Schließen | FA-1.13, FA-1.1 | `7c6b9c8` |
| Geändert | Bestätigungen: Häkchen „Keine Steuerberatung“ plus „Akzeptieren und weiter“ mit Links auf Nutzungsbedingungen und Datenschutzerklärung (zwei Tipps statt drei) | FA-1.10, L-17.2, P-R58 | `7c6b9c8` |
| Geändert | Startauswahl des Store-Builds ersetzt durch Willkommensseite und Schritt 5 „Abo wählen“ | FA-13.15 | `7c6b9c8` |
| Neu | EU-KU-Nummer (EX) im Registrierungsformular beim EU-Kleinunternehmer-Verfahren, Formatprüfung, im Profil getrennt von der UID (Schema 28), auf Kleinunternehmer-Rechnungen an Kunden im anderen Land | FA-18.10, P-S76, P-S77 | `7c6b9c8` |
| Geändert | Belegformular: „Beschreibung“ heißt „Produkt oder Leistung“ (Hinweis, Fehlermeldung, Suche); Exportspalte unverändert | FA-2.5, 8.2 | `7c6b9c8` |
| Neu | Mithelfer: „?“-Erklärung neben „Gerät koppeln“/„Gerät hinzufügen“; Einstellungen → „Als Mithelfer-Gerät koppeln“ (nur ohne Belege, mit Bestätigung) | FA-17.13 | `7c6b9c8` |
| Doku | Spezifikation 1.86, Handbuch, DESIGN_SPEC 1.5, Lastenheft 1.81 (14a), interne Prüfung 2026-10-19 | Spezifikation 14 | `7c6b9c8` |
| Behoben | Demo: Belege- und Rechnungsliste zeigten nach „Einstellungen → Demo ansehen“ keine Musterdaten (Listen im Stapel der Startseite luden nicht neu) | FA-13.14 | `cb6bbb7` |
| Geändert | Demo-Firma Kleinunternehmerin AT mit Ampel ≈ 27 % und DE-Registrierung; Musterverträge Leasing und Dienstvertrag Teilzeitkraft | FA-13.14, P-S75 | `cb6bbb7` |
| Neu | Vertragsarchiv über „Belege | Verträge“ und Einstellungen → Verträge; Dienstvertrag mit Datenschutzhinweis (L-23.8) | FA-16.9 | `cb6bbb7` |

---

## 0.27.0+40 — 2026-10-19

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.27.0-build-<Nr>.apk`, fester Testschlüssel); **Lizenzprüfung aus** (ohne `LICENSING=true`), alle Funktionen frei. Die Demo ist im Testbuild über **Einstellungen → Demo ansehen** erreichbar; Startauswahl und Testzeit-Logik wirken erst im Store-Build |
| Commit | `67a7601` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.80, Spezifikation 1.85, Benutzerhandbuch für 0.27.0, DESIGN_SPEC 1.4 |
| Datenbankschema | 27 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `demo_test.dart`: Musterdaten, keine echten Marken, Schreibschutz, echte Datenbank unberührt, Wasserzeichen auf jeder PDF-Seite, Teilen gesperrt, Startauswahl/Band/Blatt ≥ 48 dp in der Daumenzone, Demo endet mit Abo; erweitert `licensing_test.dart`: Anspruchsmatrix, Android-Testfenster inkl. Neuinstallation, iOS-Einführungsangebot mit Fake, Abo-Seite; `specification_sync_test.dart`: `spec.demo_*`); Prüfmappen neu erzeugt; Android/iOS-Build nur in der CI |
| Steuerliche Kennwerte | neu `spec.demo_company`, `spec.demo_receipt_count`, `spec.demo_watermark` |
| Offene reale Prüfpunkte | wie 0.26.0+39, neu P-R55, P-R56, P-R57, P-S75, P-D46, P-D47, P-D48, P-X23; P-D30 jetzt mit Test auf allen vier Produkten |
| Bekannte Grenzen | Spezifikation Abschnitt 11, neu „Testzeit auf Android nur genähert“, „Demo ohne PDF-Vorschau in der App“ |

**Änderungen seit 0.26.0+39**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Geändert | Test 14 Tage auf allen vier Produkten; Basis in der Testzeit des ersten Abos mit allen Pro-Funktionen, danach Basis (iOS StoreKit-2-Einführungsangebot, Android Zeitfenster ab Kaufzeitpunkt) – ersetzt „Store-Test nur auf Pro“ | O-42, L-10.3, L-22.3, FA-13.4 | `67a7601` |
| Geändert | Abo-Seite: „14 Tage kostenlos testen – mit allen Pro-Funktionen. Danach gilt dein gewähltes Abo (‹Preis›). Jederzeit vorher im Store kündbar.“ auf beiden Karten, bei Basis „Nach dem Test gilt der Umfang von Basis.“; Pflichttext neu | FA-13.5, P-R57 | `67a7601` |
| Neu | Hinweis 3 Tage vorher „Noch X Tage Pro inklusive – danach Basis. Jetzt auf Pro wechseln?“ | FA-13.8, L-10.3 | `67a7601` |
| Neu | Demo ohne Abo: eigene schreibgeschützte Muster-Datenbank „Muster Handel e.U.“ mit 25 Belegen samt synthetischer Belegbilder, Rechnungen, Mahnung, Storno, Angeboten, Anlage, Verträgen; Speichern/Senden/Export/Sicherung gesperrt mit Hinweisblatt; „MUSTER – DEMO“ auf jeder PDF-Seite; Band oben; Einstellungen → Demo ansehen | O-42, L-10.6, FA-13.14 | `67a7601` |
| Neu | Startauswahl im Store-Build ohne Abo: „Abo wählen – 14 Tage kostenlos“ / „Erst ansehen (Demo)“ | FA-13.15 | `67a7601` |
| Behoben | Onboarding: Rechtsform-Auswahl lief auf 360 dp über den Rand | P-X23 | `67a7601` |
| Doku | STORE_ANMELDUNG Formular 4 (Einführungsangebot auf allen vier Produkten, Apple-Gruppenregel), STORE_LISTING, Lastenheft 14a/O-42, interne Prüfung 2026-10-19, Prüfmappen | O-42, Spezifikation 14 | `67a7601` |

---

## 0.26.0+39 — 2026-10-19

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.26.0-build-<Nr>.apk`, fester Testschlüssel); **Lizenzprüfung aus** (ohne `LICENSING=true`), alle Funktionen frei. **Neue Kennung `at.jenibarb.jenibucht`: wird neben der alten App installiert und startet leer.** Testerinnen: in der alten App Sicherung erstellen (Datei nach Google Drive/iCloud Drive/Dateien), in der neuen App wiederherstellen, danach alte App löschen (Benutzerhandbuch, Kopf) |
| Commit | `b7cf875` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.79, Spezifikation 1.84, Benutzerhandbuch für 0.26.0, DESIGN_SPEC 1.4 |
| Datenbankschema | 27 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (angepasst `helper_package_platform_test.dart`, `document_scanner_test.dart`); Android/iOS-Build und Emulator-OCR-Test mit neuem Paketnamen nur in der CI |
| Steuerliche Kennwerte | unverändert |
| Offene reale Prüfpunkte | wie 0.25.0+38; P-B13 jetzt für `iCloud.at.jenibarb.jenibucht`, P-D6 |
| Bekannte Grenzen | Spezifikation Abschnitt 11 |

**Änderungen seit 0.25.0+38**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Geändert | Bundle-ID/applicationId `at.jenibarb.jenibucht` (Android, iOS inkl. RunnerTests, iCloud-Container, Dateityp `.jenibeleg` mit alter Kennung als Alias, Hintergrundaufgabe `mailsync`, Play-Upload, CI-Emulatortest) | O-33, P-D6, P-B13 | `b7cf875` |
| Neu | „Für das Finanzamt“ warnt bei jeder weiteren Registrierung, dass das Verbringen ins Lager fehlt (DE Kz 89/61, AT Kz 070/072/065) – Entscheidung 2026-10-18, Verbringen nicht in der App | FA-18.4, P-S68, O-40 | `b7cf875` |
| Behoben | OSS-Erklärung und EU-KU-Meldung wurden auf den nächsten Werktag verschoben; EU-Recht kennt keine Verschiebung, Termin jetzt genau | FA-18.6, P-S72 | `b7cf875` |
| Doku | Interne Prüfung P-S68 bis P-S74 und P-R5, Prüfmappen neu; Länderanalyse (`docs/LAENDERANALYSE.md`, `docs/Laenderanalyse.pdf`), Lastenheft O-41 | Spezifikation 14, O-41 | `b7cf875` |

---

## 0.25.0+38 — 2026-10-18

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.25.0-build-<Nr>.apk`, fester Testschlüssel); **Lizenzprüfung aus** (ohne `LICENSING=true`), alle Funktionen frei |
| Commit | `659b3b4` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.77, Spezifikation 1.82, Benutzerhandbuch für 0.25.0, DESIGN_SPEC 1.4 |
| Datenbankschema | 27 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `tax_registration_test.dart`: Termine je Land und Zeitraum inkl. Wochenende, Kennzahlen je Registrierung, Importzuordnung, Migration 26 → 27, Bedienmaße; erweitert `specification_sync_test.dart`); Prüfmappen neu erzeugt; Android/iOS-Build nur in der CI |
| Steuerliche Kennwerte | `spec.schema_version` 27; `spec.at.deadline_rules`/`spec.de.deadline_rules` um OSS-Erklärung und EU-KU-Meldung; neu `spec.*.registration_deadline_rules`, `spec.*.foreign_tax_offices` |
| Offene reale Prüfpunkte | wie 0.24.0+37, neu P-S68 bis P-S74, P-X22, P-D45 |
| Bekannte Grenzen | Spezifikation Abschnitt 11, neu „Mehrere Steuerländer: erste Stufe“ |

**Änderungen seit 0.24.0+37**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | Steuerliche Registrierungen in mehreren Ländern: Stammdaten „Weitere Länder“ mit „Land hinzufügen“ (AT/DE, weitere „bald“), UID-Prüfung je Land, Finanzamt-Vorschlag, Besteuerungsform, Zeitraum, Dauerfristverlängerung, Beginn/Ende; Steuerland-Chips im Belegformular ab zwei Registrierungen; Amazon-Import ordnet FBA-Verkäufe aus dem Lager dem Steuerland zu; „Für das Finanzamt“ je Land, E1a/EÜR über alle Länder; Termine je Registrierung mit Länderkürzel, OSS-Schalter und EU-KU-Meldung; Schema 27 | FA-18.1 bis FA-18.9, GR-16, L-30.1 bis L-30.7, P-S68 bis P-S74, P-X22, P-D45 | `659b3b4` |
| Geändert | Kleinunternehmergrenze der Heimat zählt nur Belege ohne weiteres Steuerland | FA-18.7, P-S70 | `659b3b4` |
| Behoben | Prüfmappen-Generatoren: P-S65, P-S66, P-S67 und P-R44 bis P-R48 waren keinem Thema zugeordnet (Abbruch) | Spezifikation 14 | `659b3b4` |

---

## 0.24.0+37 — 2026-10-17

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.24.0-build-<Nr>.apk`, fester Testschlüssel); **Lizenzprüfung aus** (ohne `LICENSING=true`), alle Funktionen frei |
| Commit | `4775b1f` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.76, Spezifikation 1.81, Benutzerhandbuch für 0.24.0, DESIGN_SPEC 1.4 |
| Datenbankschema | 26 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `helper_mail_test.dart` mit Ersatz-Mailserver, `helper_mail_ui_test.dart`; erweitert `specification_sync_test.dart`); Android/iOS-Build nur in der CI (neue Pakete `workmanager` 0.10.10, `flutter_local_notifications` 22.3.2, Android-Desugaring, iOS `BGTaskSchedulerPermittedIdentifiers`) |
| Steuerliche Kennwerte | `spec.schema_version` 26, neu `spec.helper_mail_poll_minutes` 60, `spec.helper_mail_send_hours` 24, `spec.helper_mail_retention_days` 90 |
| Offene reale Prüfpunkte | wie 0.23.2+36, neu P-D44, P-R47, P-R48, P-S67, P-X21 |
| Bekannte Grenzen | Spezifikation Abschnitt 11, neu „Mailweg ohne OAuth“ |

**Änderungen seit 0.23.2+36**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | Belegsammler per E-Mail als Standardweg: Hauptgerät empfängt an der Geschäfts-E-Mail (Häkchen „Andere E-Mail-Adresse …“), liest das Postfach nur lesend per IMAP stündlich und beim Öffnen; Mithelfer sendet einmal am Tag und beim Öffnen aus dem eigenen Postfach per SMTP ein verschlüsseltes Sammelpaket (v2, v1 lesbar); Gmail-/iCloud-App-Passwort mit Anleitung und Link; Autoconfig; Erinnerung „Belege senden“ mit Mailfenster ohne Postfach; Aufbewahrung 90 Tage; „Exportieren“ als Notweg; Schema 26 | FA-17.9 bis FA-17.12, L-29.10, P-D44, P-R47, P-S67, P-X21 | `4775b1f` |

---

## 0.23.2+36 — 2026-10-17

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.23.2-build-<Nr>.apk`, fester Testschlüssel); **Lizenzprüfung aus** (ohne `LICENSING=true`), alle Funktionen frei |
| Commit | `25c8170` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.75, Spezifikation 1.80, Benutzerhandbuch für 0.23.2, DESIGN_SPEC 1.4 |
| Datenbankschema | 25 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `receipt_omv_test.dart`, erweitert `document_scanner_test.dart`, Korpus um `omv_kaiserwald_20260519.jpg`); Android/iOS-Build nur in der CI |
| Steuerliche Kennwerte | unverändert |
| Offene reale Prüfpunkte | wie 0.23.1+35, neu P-D43 |
| Bekannte Grenzen | Spezifikation Abschnitt 11, unverändert |

**Änderungen seit 0.23.1+35**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Behoben | OMV-Beleg 8,96 € mit 20 %/0 % statt 7,96 € zu 20 %: Rangfolge QR > Steuertabelle (mehrere Zeilen, 0 %) > Gesamtbetrag; Zahlungszeilen nie Gesamtbetrag; gedruckte Netto/Steuer; Codes auf jeder Seite und auf dem Scan-Original; „OMV Tankstelle“; Tankstelle ohne Treibstoff nicht Kfz-Kosten | FA-2.62, P-D43 | `25c8170` |

---

## 0.23.1+35 — 2026-10-17

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.23.1-build-<Nr>.apk`, fester Testschlüssel); **Lizenzprüfung aus** (ohne `LICENSING=true`), alle Funktionen frei |
| Commit | `f3f22be` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.75, Spezifikation 1.79, Benutzerhandbuch für 0.23.1, DESIGN_SPEC 1.4 |
| Datenbankschema | 25 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `material_category_test.dart`, `helper_package_platform_test.dart` mit Prüfmuster `test/fixtures/belegpaket/pruefmuster_v1.jenibeleg`; geändert `receipt_description_test.dart`); Android/iOS-Build nur in der CI |
| Steuerliche Kennwerte | `spec.schema_version` 25, `spec.seed_category_count` 18, `spec.seed_category_expense_count` 15 |
| Offene reale Prüfpunkte | wie 0.23.0+34, neu P-S66, P-D42 erweitert (gemischt in beide Richtungen) |
| Bekannte Grenzen | Spezifikation Abschnitt 11, unverändert |

**Änderungen seit 0.23.0+34**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | Startkategorie „Material und Werkzeug“ (SKR03 4985, BMD EKR 5300), Schema 25 für bestehende Datenbanken; Baumarkt-Belege schlagen sie vor; Mithelfer ohne eigenes Abo/Gerätegrenze bestätigt | FA-2.31, L-29.7, P-S66 | `329f27b` |
| Neu | Belegsammler gemischt Android/iPhone: Paketformat mit Prüfmuster, iOS „Öffnen in JeNi bucht“ (eigener Dateityp), Android „Öffnen mit“ (MIME/Endung), iPad-Anker im Teilen-Blatt, Ordnerhinweis | FA-17.4, 8.9, P-D42 | `f3f22be` |

---

## 0.23.0+34 — 2026-10-17

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.23.0-build-<Nr>.apk`, fester Testschlüssel); **Lizenzprüfung aus** (ohne `LICENSING=true`), alle Funktionen frei |
| Commit | `e2591a7` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.74, Spezifikation 1.78, Benutzerhandbuch für 0.23.0, DESIGN_SPEC 1.4 |
| Datenbankschema | 24 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `helper_devices_test.dart`; erweitert `licensing_test.dart`); Android/iOS-Build nur in der CI |
| Steuerliche Kennwerte | unverändert (`spec.schema_version` 24) |
| Offene reale Prüfpunkte | wie 0.22.3+33, neu P-D42, P-R46, P-S65, P-X20 |
| Bekannte Grenzen | Spezifikation Abschnitt 11, neu „Mithelfer-Geräte ohne Synchronisierung“ |

**Änderungen seit 0.22.3+33**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | Mithelfer-Geräte / Belegsammler: Koppeln per QR (Pro auf dem Hauptgerät), Mithelfer-Modus nur zum Erfassen, Belegpaket `.jenibeleg` Ende-zu-Ende verschlüsselt (AES-256-GCM), Wege Messenger/Mail und gemeinsamer Ordner, Eingang mit Übernehmen/Ablehnen, Dublettenschutz, Trennen; Schema 24 | FA-17.1 bis FA-17.8, L-29.1 bis L-29.9, P-D42, P-R46, P-S65, P-X20 | `e2591a7` |

---

## 0.22.3+33 — 2026-10-17

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.22.3-build-<Nr>.apk`, fester Testschlüssel); **Lizenzprüfung aus** (ohne `LICENSING=true`), alle Funktionen frei |
| Commit | `f4c4721` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.73, Spezifikation 1.77, Benutzerhandbuch für 0.22.3, DESIGN_SPEC 1.4 |
| Datenbankschema | 23 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `receipt_description_test.dart`; Korpus-Sollwert SPAR „Baguette“ statt „Lebensmittel“); Android/iOS-Build nur in der CI |
| Steuerliche Kennwerte | unverändert |
| Offene reale Prüfpunkte | wie 0.22.2+32 (P-D22 Belegerkennung auf dem Gerät) |
| Bekannte Grenzen | Spezifikation Abschnitt 11, unverändert |

**Änderungen seit 0.22.2+32**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Behoben | BAUHAUS-Bon: Artikelzeile „SET 3L Lasurpinsel-S“ wurde Lieferant; jetzt Zeile mit Rechtsform bzw. bekannte Kette („BAUHAUS Depot GmbH“), Artikelzeilen nie Lieferant, Kettenliste AT/DE erweitert, OCR-Varianten | FA-2.31, L-2.20 | `f4c4721` |
| Geändert | Beschreibung = was gekauft wurde („Lasurpinsel u. a.“), sonst Branche („Maut“, „Baumarkt-Einkauf“), sonst leer; nie der Händlername | FA-2.31 | `f4c4721` |

---

## 0.22.2+32 — 2026-10-16

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.22.2-build-<Nr>.apk`, fester Testschlüssel); **Lizenzprüfung aus** (ohne `LICENSING=true`), alle Funktionen frei |
| Commit | `7c2ea6f` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.73, Spezifikation 1.76, Benutzerhandbuch für 0.22.2, DESIGN_SPEC 1.4 |
| Datenbankschema | 23 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `feedback_test.dart`); Android/iOS-Build nur in der CI |
| Steuerliche Kennwerte | unverändert |
| Offene reale Prüfpunkte | wie 0.22.1+31, neu P-R45 |
| Bekannte Grenzen | Spezifikation Abschnitt 11, unverändert |

**Änderungen seit 0.22.1+31**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | Einstellungen → „Wunsch oder Idee senden“: Art als Chips, Titel optional, Beschreibung mit Diktat, technische Angaben abschaltbar; „Per E-Mail senden“ öffnet die Mail-App an office@jenibarb.com, ohne Mail-App Text in die Zwischenablage. Die App überträgt nichts selbst | FA-11.6, L-26.7, P-R45 | `7c2ea6f` |

---

## 0.22.1+31 — 2026-10-16

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.22.1-build-<Nr>.apk`, fester Testschlüssel); **Lizenzprüfung aus** (ohne `LICENSING=true`), alle Funktionen frei |
| Commit | `34d333f` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.71, Spezifikation 1.75, Benutzerhandbuch für 0.22.1, DESIGN_SPEC 1.4 |
| Datenbankschema | 23 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `scan_to_form_test.dart`; erweitert `document_scanner_test.dart`, `one_hand_test.dart`); Android/iOS-Build nur in der CI |
| Steuerliche Kennwerte | unverändert |
| Offene reale Prüfpunkte | wie 0.22.0+30, neu P-X19, P-D41 |
| Bekannte Grenzen | Spezifikation Abschnitt 11, unverändert |

**Änderungen seit 0.22.0+30**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Behoben | Nach dem Scan blieb das Belegformular leer (keine Seite, keine Vorbelegung): Android-Request-Code 4711 war doppelt vergeben (Scanner und Sicherungsordner), der Sicherungsordner verschluckte das Scan-Ergebnis; jetzt eindeutige Codes in `RequestCodes.kt` mit Test | FA-2.51, P-D41 | `34d333f` |
| Geändert | Kein stiller Weg beim Scannen: verlorenes Ergebnis, nicht lesbare oder nicht speicherbare Seiten und Auslesefehler erscheinen als Meldung; scheitert die Nachbearbeitung, wird das Original übernommen; nicht darstellbare Seite zeigt Platzhalter | FA-2.51 | `34d333f` |
| Neu | „Foto“ (Galerie) und „Datei“ (PDF, E-Rechnung, Bild) als kleinere runde Knöpfe neben „Beleg“ auf Übersicht und Belegliste; öffnen direkt einen neuen Beleg und lesen aus | FA-12.1, DESIGN_SPEC 5a Regel 13, P-X19 | `34d333f` |

---

## 0.22.0+30 — 2026-10-16

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.22.0-build-<Nr>.apk`, fester Testschlüssel); **Lizenzprüfung aus** (ohne `LICENSING=true`), alle Funktionen frei |
| Commit | `d647f8e` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.71, Spezifikation 1.74, Benutzerhandbuch für 0.22.0, DESIGN_SPEC 1.3 |
| Datenbankschema | 23 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `spoken_amount_test.dart`, `dictation_test.dart`; erweitert `one_hand_test.dart`, `receipt_save_bar_test.dart`); Android/iOS-Build nur in der CI |
| Steuerliche Kennwerte | unverändert |
| Offene reale Prüfpunkte | wie 0.21.1+29, neu P-X17, P-X18, P-D39, P-D40, P-R44 |
| Bekannte Grenzen | Spezifikation Abschnitt 11, unverändert; Diktat nur mit Erkennung auf dem Gerät (Android ab 12) |

**Änderungen seit 0.21.1+29**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Geändert | Runder Aufnahmeknopf „Beleg“ (76 dp, Kamera) unten in der Mitte auf Übersicht, Belegliste (öffnet jetzt direkt den Scanner) und im Belegformular über „Beleg speichern“; Galerie als kleinere Nebenaktion | FA-12.1, DESIGN_SPEC 5a Regel 13, P-X17 | `4422d81` |
| Neu | Diktat auf dem Gerät: Mikrofon in Beschreibung, Anlass, Teilnehmer, Notiz, Kommentar (Beleg, Vertrag) und Betragsfeldern; Beträge wie „zwölf Euro fünfzig“ als Vorschlag in Cent; ohne On-Device-Erkennung kein Knopf, kein Netz; Berechtigung Mikrofon (Android), Mikrofon und Spracherkennung (iOS) | FA-2.61, LH 5.19, 14a, P-D40, P-X18, P-R44 | `d647f8e` |

---

## 0.21.1+29 — 2026-10-16

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.21.1-build-<Nr>.apk`, fester Testschlüssel); **Lizenzprüfung aus** (ohne `LICENSING=true`), alle Funktionen frei |
| Commit | `b925046` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.70, Spezifikation 1.72, Benutzerhandbuch für 0.21.1, DESIGN_SPEC 1.2 |
| Datenbankschema | 23 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `scan_enhancer_test.dart`, erweitert `document_scanner_test.dart`); Android/iOS-Build nur in der CI |
| Steuerliche Kennwerte | unverändert |
| Offene reale Prüfpunkte | wie 0.21.0+28, P-S63 ergänzt (Graustufen) |
| Bekannte Grenzen | Spezifikation Abschnitt 11, unverändert |

**Änderungen seit 0.21.0+28**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Behoben | Dokumentenscanner nach dem ersten Scan bis zum Neustart gesperrt (offene Kanal-Antwort nie abgeschlossen, Folgeaufrufe still als „abgebrochen“ gelesen): Antwort genau einmal, am Prozess, Abbruch nach Rückkehr ohne Ergebnis, Dart-Sperre im `finally`; iOS gleich | FA-2.51 | `b925046` |
| Behoben | Nach dem Scan keine Vorbelegung: Scan-Seiten laufen über denselben Weg wie Kamerafotos in Erkennung und Vorbelegung, Einstellung frisch geladen; mehrere Seiten in derselben Millisekunde überschrieben einander im Belegspeicher | FA-2.51, FA-2.19 | `b925046` |
| Neu | Nachbearbeitung gescannter Seiten (Tonwertkorrektur, Papier aufhellen, Nachschärfen, farblose Belege grau, max. 2400 px, JPEG 85) im Hintergrund; gespeichert nur das Ergebnis | FA-2.51, P-S63 | `b925046` |

---

## 0.21.0+28 — 2026-10-16

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.21.0-build-<Nr>.apk`, fester Testschlüssel); **Lizenzprüfung aus** (ohne `LICENSING=true`), alle Funktionen frei |
| Commit | `c335808` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.70, Spezifikation 1.71, Benutzerhandbuch für 0.21.0, DESIGN_SPEC 1.2 |
| Datenbankschema | 23 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `entertainment_deduction_test.dart`); Android/iOS-Build nur in der CI |
| Steuerliche Kennwerte | neu `spec.at.entertainment` (500, Vorsteuer voll), `spec.de.entertainment` (700, Vorsteuer voll, Anlass/Teilnehmer); `spec.schema_version` 23; `spec.seed_category_count` 17, `spec.seed_category_expense_count` 14 |
| Offene reale Prüfpunkte | wie 0.20.0+27, P-S46 neu gefasst (offen), neu P-X16 |
| Bekannte Grenzen | Spezifikation Abschnitt 11 (Bewirtung ohne Kürzung ersetzt durch „Bewirtung nur mit Regelsatz“) |

**Änderungen seit 0.20.0+27**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | Bewirtung mit Abzugsbeschränkung: Kategorie „Bewirtung“, AT 50 %, DE 70 %, Vorsteuer voll, Kleinunternehmer brutto × Anteil; nicht abziehbarer Teil in Übersicht, Kennzahlen, Saldenliste, Jahresabschluss, CSV und DATEV (Umbuchung 4654); DE Anlass/Teilnehmer; Belegerkennung schlägt Bewirtung für Restaurants vor; Schema 23 | FA-2.60, LH 14a, P-S46 | `c335808` |
| Geändert | Lastenheft O-36: ELSTER-Softwarehersteller am 2026-10-16 beantragt, Antwort ausstehend | O-36 | `c335808` |
| Geändert | Anlagen anlegen, ändern, ausscheiden nur Pro; bestehende Anlagen, Verzeichnis und AfA in jedem Abo; GWG-Hinweis am Beleg ohne Pro; Vertragsarchiv Basis, Auslesen Pro (Entscheidungen Auftraggeberin) | FA-13.2, FA-15.1, LH 14a | `c57a543` |
| Behoben | Verzugszinsen DE: Basiszinssatz 1,52 % ab 1.7.2026 ergänzt (Bundesbank); interne Prüfung der Steuer- und Rechtspunkte, neuer Status „intern geprüft“, Prüfmappen nur mit offenen Punkten | P-S44, SPEC 14 | `596413c` |

---

## 0.20.0+27 — 2026-10-16

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.20.0-build-<Nr>.apk`, fester Testschlüssel); **Lizenzprüfung aus** (ohne `LICENSING=true`), alle Funktionen frei |
| Commit | `e4934a3` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.68, Spezifikation 1.68, Benutzerhandbuch für 0.20.0, DESIGN_SPEC 1.2 |
| Datenbankschema | 22 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `document_scanner_test.dart`); Android/iOS-Build nur in der CI (Abhängigkeit `play-services-mlkit-document-scanner` 16.0.0, VisionKit) |
| Steuerliche Kennwerte | neu `spec.scanner_page_limit` 20 |
| Offene reale Prüfpunkte | wie 0.19.0+26, neu P-S63, P-R42, P-D37, P-D38, P-X15 |
| Bekannte Grenzen | Spezifikation Abschnitt 11 (neu: Scanner nicht auf Gerät erprobt) |

**Änderungen seit 0.19.0+26**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | Dokumentenscanner des Systems für Belege und Verträge (Android ML Kit Document Scanner, iOS VisionKit), mehrere Seiten, nur verarbeitetes Bild gespeichert, ohne Scanner automatisch Kamera | FA-2.51, Lastenheft 14a | `e4934a3` |

---

## 0.19.0+26 — 2026-10-16

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.19.0-build-<Nr>.apk`, fester Testschlüssel); **Lizenzprüfung aus** (ohne `LICENSING=true`), alle Funktionen frei |
| Commit | `9963035` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.67, Spezifikation 1.67, Benutzerhandbuch für 0.19.0, DESIGN_SPEC 1.2 |
| Datenbankschema | 22 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `contract_test.dart`), CI-Lauf zum Commit |
| Steuerliche Kennwerte | neu `spec.contract_match_tolerance_days` 20; `spec.schema_version` 22 |
| Offene reale Prüfpunkte | wie 0.18.0+25, neu P-R41, P-S62, P-X14, P-D36 |
| Bekannte Grenzen | Spezifikation Abschnitt 11 (neu: Vertragsarchiv ohne KI) |

**Änderungen seit 0.18.0+25**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | Vertragsarchiv: Verträge mit Seiten (Foto, Galerie, Teilen inkl. PDF), Fristen in der Termin-Box, Abgleich Rate/Buchung, Buchungsvorschlag, Aufbewahrung mit Löschwarnung, `vertraege.csv` (Schema 22) | L-23.1 bis L-23.4, L-23.11, FA-16.1, FA-16.2, FA-16.4 bis FA-16.8 | `9963035` |
| Neu | Kurzübersicht aus lokal erkanntem Vertragstext mit Fundstelle Seite/Zeile (Pro, Vorschlag 14a) | L-23.6, FA-16.3, FA-13.2 | `9963035` |

---

## 0.18.0+25 — 2026-10-16

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.18.0-build-<Nr>.apk`, fester Testschlüssel); **Lizenzprüfung aus** (ohne `LICENSING=true`), alle Funktionen frei |
| Commit | `d65aaaf` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.66, Spezifikation 1.66, Benutzerhandbuch für 0.18.0, DESIGN_SPEC 1.2 |
| Datenbankschema | 21 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `fixed_asset_test.dart` mit Summenprobe über 600 Fälle), CI-Lauf zum Commit |
| Steuerliche Kennwerte | neu `spec.at.depreciation`, `spec.de.depreciation`; `spec.schema_version` 21 |
| Offene reale Prüfpunkte | wie 0.17.0+24, neu P-S59, P-S60, P-S61, P-X13 |
| Bekannte Grenzen | Spezifikation Abschnitt 11 (neu: Anlagen vereinfacht) |

**Änderungen seit 0.17.0+24**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | Ausgabe als Investition erfassen: Nutzungsdauer-Vorschlag je Land mit Fundstelle, eigene Dauer mit Begründung, GWG, Sammelposten (DE), AfA-Plan; Gewinn mit AfA statt Anschaffung (Schema 21) | GR-15, FA-15.1 bis FA-15.5, FA-15.7 | `d65aaaf` |
| Neu | Ausscheiden bzw. vollständig abschreiben mit Pflichtkommentar, Verkaufserlös als Einnahme | FA-15.6 | `d65aaaf` |
| Neu | Anlagenverzeichnis (jedes Abo), Saldenliste und vorläufiger Jahresabschluss als PDF/ZIP (Pro, Vorschlag 14a) | FA-15.8 bis FA-15.11, FA-13.2 | `d65aaaf` |

---

## 0.17.0+24 — 2026-10-16

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.17.0-build-<Nr>.apk`, fester Testschlüssel); **Lizenzprüfung aus** (ohne `LICENSING=true`), alle Funktionen frei |
| Commit | `699d9e1` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.65, Spezifikation 1.65, Benutzerhandbuch für 0.17.0, DESIGN_SPEC 1.2 |
| Datenbankschema | 20 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `tax_office_test.dart`), U30-XML gegen BMF-XSD 07_2026 mit `xmllint` gültig, CI-Lauf zum Commit |
| Steuerliche Kennwerte | neu `spec.at.vat_return_kz`, `spec.de.vat_return_kz`, `spec.at.annual_return_kz`, `spec.de.annual_return_kz`, `spec.u30_schema_version` 07_2026 |
| Offene reale Prüfpunkte | wie 0.16.0+23, neu P-S57, P-S58, P-D35, P-X12; P-R5 präzisiert |
| Bekannte Grenzen | Spezifikation Abschnitt 11 (neu: keine direkte Übermittlung ans Finanzamt, keine ZM) |

**Änderungen seit 0.16.0+23**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | iOS-Datenschutz-Manifest `PrivacyInfo.xcprivacy` (kein Tracking, Dateizeitstempel C617.1, Kaufverlauf und Finanzinfos wie App Privacy Label); `CFBundleLocalizations` de | L-19.5, P-B15 | `1e85096` |
| Neu | Release-Workflow: signierte AAB und IPA als ungezippte Artefakte, Play-Upload (Entwurf) und TestFlight nur mit vorhandenen Secrets, sonst unsigniertes iOS-Archiv | FA-13.10, P-B16 | `1e85096` |
| Neu | Skript `tool/release/bundle_id_wechsel.sh` für die Store-Kennung `at.jenibarb.jenibucht` (vorbereitet, nicht ausgeführt) | O-33 | `1e85096` |
| Geändert | STORE_LISTING: Kategorien, Screenshot-Größen, Demodaten, Altersfreigabe-Fragebogen, Formularantworten Datensicherheit/App-Datenschutz | P-D34 | `1e85096` |
| Neu | Prüfmappen Steuerberater und Rechtsanwalt als PDF (`docs/pruefmappen/`), aus SPECIFICATION 14 erzeugt, mit Beispielrechnungen und Rechtstexten im Anhang; keine Verhaltensänderung | P-S…, P-R…, P-L… | `52414ec` |
| Neu | „Für das Finanzamt“: Kennzahlen UVA (U30) bzw. UStVA und Jahreszahlen E1a/Anlage EÜR, Kopieren mit einem Tipp; Kleinunternehmer ohne UVA-Hinweis außer Reverse Charge | L-6.1, L-6.3, FA-14.1 bis FA-14.3, FA-14.5 bis FA-14.8 | `699d9e1` |
| Neu | U30-Datei nach BMF-Datenstrom 07_2026 teilen und in FinanzOnline hochladen (Pro, nur AT) | L-6.5, FA-14.4, 8.7 | `699d9e1` |

---

## 0.16.0+23 — 2026-10-16

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.16.0-build-<Nr>.apk`, fester Testschlüssel); **Lizenzprüfung aus** (ohne `LICENSING=true`), alle Funktionen frei |
| Commit | `d994893` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.64, Spezifikation 1.62, Benutzerhandbuch für 0.16.0, DESIGN_SPEC 1.2 |
| Datenbankschema | 20 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `supplier_learning_test.dart`, erweitert `auto_backup_test.dart`), CI-Lauf zum Commit |
| Steuerliche Kennwerte | `spec.schema_version` 20 |
| Offene reale Prüfpunkte | wie 0.15.0+22, neu P-B13, P-B14, P-X11, P-D33 |
| Bekannte Grenzen | Spezifikation Abschnitt 11 |

**Änderungen seit 0.15.0+22**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | Abo-Seite: „Promo-Code einlösen“ (iOS Einlöseblatt, Android Google Play); Code JENIBUCHT2M für 2 Monate Pro gratis, Erinnerung zum Ende | FA-13.13 | `067a8f8` |
| Neu | Lernen je Lieferant: Name, Kategorie, Steuersatz, Währung, Zahlungsart „wie beim letzten Mal“ (Schema 20) | L-2.28, FA-2.50 | `d994893` |
| Neu | iOS: automatische Sicherung in den iCloud-Drive-Container „JeNi bucht“; Liste „Wiederherstellen“ auf beiden Plattformen | L-7.17, L-7.18, L-7.20, FA-7.16 | `d994893` |

---

## 0.15.0+22 — 2026-10-16

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.15.0-build-<Nr>.apk`, fester Testschlüssel); **Lizenzprüfung aus** (ohne `LICENSING=true`), alle Funktionen frei |
| Commit | `b168605` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.62, Spezifikation 1.60, Benutzerhandbuch für 0.15.0, DESIGN_SPEC 1.2 |
| Datenbankschema | 19 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `offer_article_test.dart`), CI-Lauf zum Commit |
| Steuerliche Kennwerte | neu `spec.offer_number_pattern` AN-{YYYY}-{NNNN}, `spec.offer_validity_days` 30; `spec.schema_version` 19 |
| Offene reale Prüfpunkte | wie 0.14.0+21, neu P-U8, P-R39 |
| Bekannte Grenzen | Spezifikation Abschnitt 11 |

**Änderungen seit 0.14.0+21**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | Angebote: eigener Nummernkreis, Gültigkeit, Status, PDF „Angebot“ in Sie-Form, mit einem Tipp zur Rechnung; bucht nichts | L-3.13 bis L-3.17, FA-5.40 bis FA-5.43, FA-5.46 | `b168605` |
| Neu | Artikel ohne Lager; „Aus Artikeln und Vorschlägen“ in Rechnung und Angebot, auch aus früheren Positionen | L-11.1, L-11.2, L-11.5, L-11.9, FA-5.44, FA-5.45 | `b168605` |
| Geändert | Pro-Umfang: Import (Plattformen, E-Rechnung auslesen), PDF senden (Rechnung, Storno), Mahnung senden, Logo, Kurs abrufen nur Pro, Finanzamt-Übermittlung vorab Pro; ohne Pro PDF speichern/drucken über den Systemdialog | O-34, FA-13.2, FA-13.11 | `f3ae91c` |
| Geändert | Abo-Seite: „14 Tage kostenlos, danach ‹Preis› pro ‹Zeitraum›, jederzeit vorher kündbar“ | O-35, FA-13.5 | `eb79a9e` |
| Geändert | Logo im Onboarding ohne Abo-Seite wählbar; gedruckt nur mit Pro oder Test, mit Basis nicht auf neuen Rechnungen; gestellte behalten ihr Logo | FA-13.12, L-1.7 | `35173cd` |

---

## 0.14.0+21 — 2026-10-15

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.14.0-build-<Nr>.apk`, fester Testschlüssel); **Lizenzprüfung aus** (ohne `LICENSING=true`), alle Funktionen frei |
| Commit | `aa747a6` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.58, Spezifikation 1.56, Benutzerhandbuch für 0.14.0, DESIGN_SPEC 1.2 |
| Datenbankschema | 18 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `licensing_test.dart`), CI-Lauf zum Commit |
| Steuerliche Kennwerte | neu `spec.license_trial_days` 14, `spec.license_trial_reminder_days` 3, `spec.license_offline_grace_days` 45, `spec.license_offline_warn_days` 31, `spec.license_product_ids` |
| Offene reale Prüfpunkte | wie 0.13.2+20, neu P-R37, P-R38, P-X10, P-D30, P-D31; P-D4 präzisiert |
| Bekannte Grenzen | Spezifikation Abschnitt 11, neu „Abo nicht mit echten Stores erprobt“ |

**Änderungen seit 0.13.2+20**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | Lizenzmanager mit einem Anspruch (keiner / nur lesen / Basis / Pro), Store-Schnittstelle austauschbar, Store-Ersatz für Tests | L-22.1, FA-13.1 | `aa747a6` |
| Neu | Tarifschnitt: Belegerkennung nur Pro, neue Belege/Rechnungen ab Basis; Ansehen, Ändern, Export, Sicherung immer | L-10.4, L-22.6, FA-13.2, FA-13.9 | `aa747a6` |
| Neu | Paket `in_app_purchase`: eine Abogruppe `basis_monat`, `basis_jahr`, `pro_monat`, `pro_jahr`, Wechsel ohne Doppelabo, Test 14 Tage über die Stores | L-22.2, L-22.3, FA-13.3, FA-13.4 | `aa747a6` |
| Neu | Abo-Seite (Einstellungen → Abo): Store-Preise, Pflichttext Verlängerung/Kündigung/Test, Kauf wiederherstellen, Abo verwalten, Nutzungsbedingungen, Datenschutz | L-22.7, L-22.8, FA-13.5 | `aa747a6` |
| Neu | Stand im Schlüsselbund, offline 45 Tage gültig, Hinweis ab Tag 31, Testende-Erinnerung, Herabstufung mit Hinweis auf der Übersicht | L-10.5, L-22.5, FA-13.6 bis FA-13.8 | `aa747a6` |
| Geändert | Store-Text: Test geht ohne Kündigung in das Abo über (statt „endet von selbst“); In-App-Käufe und Datensicherheit „Kaufverlauf“; Datenschutzerklärung Abschnitt 6 | P-R37, L-19.5 | `aa747a6` |
| Neu | STORE_ANMELDUNG Formular 4: Abos in Play Console und App Store Connect anlegen | P-D30 | `aa747a6` |

---

## 0.13.2+20 — 2026-10-15

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.13.2-build-<Nr>.apk`, fester Testschlüssel); Fehlerbehebung Gerätetest 0.13.1 (Google-Beleg) |
| Commit | `01903ba` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.57, Spezifikation 1.55, Benutzerhandbuch für 0.13.2, DESIGN_SPEC 1.2 |
| Datenbankschema | 18 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `receipt_google_test.dart`, `receipt_apple_test.dart`), CI-Lauf zum Commit |
| Steuerliche Kennwerte | unverändert |
| Offene reale Prüfpunkte | wie 0.13.1+19 |
| Bekannte Grenzen | Spezifikation Abschnitt 11, unverändert |

**Änderungen seit 0.13.1+19**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Behoben | „$“-Beleg mit US-Merkmalen (Google-Gebühr $25.00): USD als Vorschlag, Fremdwährung mit Betrag vorbelegt statt Hinweis „Währung unklar“ | FA-2.28, FA-2.21 | `01903ba` |
| Neu | Bekannte Anbieter (Google, Apple, Amazon, Microsoft, Meta, Adobe …) als Lieferant | FA-2.28 | `01903ba` |
| Behoben | Steuersatz aus Steuerbetrag ohne Prozent („inkl. MwSt. € 16,50“, „USt“, „VAT“, „Tax“): Apple-Beleg 99,00 → 20 % statt 0 % | FA-2.28 | `01903ba` |
| Behoben | Hinweis „kein Vorsteuerabzug“ bei Beleg ohne Steuerausweis nicht mehr für Kleinunternehmer | FA-2.28 | `01903ba` |

---

## 0.13.1+19 — 2026-10-15

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.13.1-build-<Nr>.apk`, fester Testschlüssel); Fehlerbehebung Gerätetest 0.13.0 |
| Commit | `7d6a184` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.57, Spezifikation 1.54, Benutzerhandbuch für 0.13.1, DESIGN_SPEC 1.2 |
| Datenbankschema | 18 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `amount_round_trip_test.dart`, Zurück-Test in `invoice_form_ux_test.dart`), CI-Lauf zum Commit |
| Steuerliche Kennwerte | unverändert |
| Offene reale Prüfpunkte | wie 0.13.0+18, neu P-X9, P-D29 |
| Bekannte Grenzen | Spezifikation Abschnitt 11, unverändert |

**Änderungen seit 0.13.0+18**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Behoben | Bearbeitete Rechnung und Korrekturentwurf zeigten Positionen mit 0 €: `Money.tryParse` entfernt jetzt jedes Leerraumzeichen (geschütztes Leerzeichen U+00A0/U+202F als Tausendertrenner aus `Fmt.amount`); gilt für alle vorbelegten Betrags-, Mengen- und Rabattfelder | GR-1, FA-5.32 | `7d6a184` |
| Geändert | Leiste „Beenden“ / „PDF senden“; Zurück speichert den Entwurf oder fragt einmal | FA-5.20, FA-5.34, P-X9 | `7d6a184` |
| Behoben | Gmail: PDF-Anhang „Download fehlgeschlagen“ – Android teilt über eigenen FileProvider aus `files/geteilt`, Aufräumen nach 30 Tagen | FA-5.35, P-D29 | `7d6a184` |
| Behoben | Einstellungen „Daten und Sicherung“: veralteter Satz „keine automatische Sicherung“ ersetzt | L-7.2 | `7d6a184` |

---

## 0.13.0+18 — 2026-10-15

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.13.0-build-<Nr>.apk`, fester Testschlüssel); Stornorechnung, Rechtliches, Wiederherstellungscode |
| Commit | `5f3d21a` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.57, Spezifikation 1.53, Benutzerhandbuch für 0.13.0, DESIGN_SPEC 1.2 |
| Datenbankschema | 18 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `invoice_cancellation_test.dart`, `legal_documents_test.dart`, `recovery_code_test.dart`), Emulator-Job `android-ocr-emulator`, CI-Lauf zum Commit |
| Steuerliche Kennwerte | `spec.schema_version` 17 → 18; sonst unverändert |
| Offene reale Prüfpunkte | wie 0.12.0+17, neu P-S56, P-L20, P-X8, P-D28 |
| Bekannte Grenzen | Spezifikation Abschnitt 11, neu „Storno nur vollständig“ |

**Änderungen seit 0.12.0+17**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | Stornorechnung mit eigener Nummer aus dem gemeinsamen Nummernkreis, Bezug auf Nummer und Datum, Grund, negative Beträge je Satz identisch zum Original, PDF in Sie-Form; Original unverändert, „storniert durch …“; Rückzahlung als negative Einnahme bei bezahltem Original, sonst keine Buchung; Mahnungen mitstorniert. Ersetzt die reine Statusänderung | L-3.7, L-3.18, GR-14, FA-5.11, FA-5.31, FA-5.33, P-S56 | `5f3d21a` |
| Neu | „Korrigieren“: Storno und Entwurfskopie in einem Tipp | L-3.7, FA-5.32 | `5f3d21a` |
| Neu | Einstellungen → Rechtliches: Impressum, Datenschutz, Nutzungsbedingungen aus `docs/legal/` als Assets, offline; keine Steuerberatung, Support, Open-Source-Lizenzen mit Work Sans OFL; Entwurfsvermerk bis P-L1 | L-22.18, FA-11.4, FA-11.5, P-L20 | `5f3d21a` |
| Geändert | Wiederherstellungscode nur als Druckblatt (PDF mit QR-Code) über Teilen/Drucken, Bestätigung durch zwei zufällige Blöcke | L-22.21, L-22.22, FA-7.10, P-D28 | `5f3d21a` |
| Geändert | Datenbankschema 18 (Stornobezug an `invoices`) | GR-14 | `5f3d21a` |

---

## 0.12.0+17 — 2026-10-15

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK `JeNi-bucht-0.12.0-build-<Nr>.apk`, fester Testschlüssel); Produktname und Entscheidungen der Auftraggeberin |
| Commit | `f7788aa` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.55, Spezifikation 1.52, Benutzerhandbuch für 0.12.0, DESIGN_SPEC 1.2 |
| Datenbankschema | 17 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `contact_format_test.dart`), Emulator-Job `android-ocr-emulator`, CI-Lauf zum Commit |
| Steuerliche Kennwerte | unverändert |
| Offene reale Prüfpunkte | wie 0.11.0+16 ohne P-R7 (erledigt) |

**Änderungen seit 0.11.0+16**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Geändert | App-Name „JeNi bucht“ auf Startbildschirm (Android-Label, iOS CFBundleDisplayName/CFBundleName, damit auch die Verknüpfung), App-Titel, Sperrbildschirm, Support-Betreff „Frage zu JeNi bucht (Version …)“, Exportvermerk, Betreff der Sicherung; Bundle-ID unverändert | O-2, O-25, O-33, FA-11.3 | `f7788aa` |
| Geändert | CI-Artefakt heißt `JeNi-bucht-<Version>-build-<Nr>.apk` | – | `f7788aa` |
| Neu | Formatprüfung für E-Mail (Profil, Kunde) und Telefon (Profil), ohne Verifizierung | O-30, FA-1.4f | `f7788aa` |
| Geändert | Store-Text: „14 Tage kostenlos testen“ mit Folgepreis | O-4, P-R13 | `f7788aa` |

---

## 0.11.0+16 — 2026-10-14

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK, fester Testschlüssel); Stufe B1 Plattformexporte |
| Commit | `b131704` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.53, Spezifikation 1.50, Benutzerhandbuch für 0.11.0, DESIGN_SPEC 1.2 |
| Datenbankschema | 17 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `platform_import_test.dart`: zehn synthetische Exporte in fünf Sprachen, Datensparsamkeit über alle Tabellen, Knopf ≥ 56 dp), Emulator-Job `android-ocr-emulator`, CI-Lauf zum Commit |
| Steuerliche Kennwerte | neu `spec.oss_threshold_cents = 1000000`, `spec.at.reverse_charge_kz = -,057,066`, `spec.de.reverse_charge_kz = 46,47,67` |
| Offene reale Prüfpunkte | wie 0.10.0+15, dazu P-S51 bis P-S55, P-R36, P-U7 |

**Änderungen seit 0.10.0+15**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | Plattformexporte über Teilen/„Öffnen mit“: Amazon Transaktionsbericht (DE/EN/FR/IT/ES) und Abrechnung V2, PayPal, Shopify, Stripe; Format automatisch erkannt | L-28.1, FA-2.43 | `b131704` |
| Neu | Eine Zusammenfassung je Monat, ein Knopf „Übernehmen“ unten (56 dp) | L-28.2, FA-2.44, P-U7 | `b131704` |
| Neu | Bruttoprinzip: Umsatz, Gebühren, Werbung getrennt, Auszahlung nicht gebucht; Reverse Charge für Amazon/Stripe/Shopify, PayPal steuerfrei | L-28.3, L-28.4, FA-2.46, P-S51, P-S52, P-S54 | `b131704` |
| Neu | Reverse Charge in Übersicht und UVA-Export mit Kennzahlen je Land (AT Kz 057/066, DE Kz 46/47/67), auch für Kleinunternehmer | L-28.4, FA-3.3, FA-3.4 | `b131704` |
| Neu | Dubletten still übersprungen (Schema 17 `platform_import_rows`), OSS- und FBA-Warnung | L-28.5, FA-2.45, FA-2.47, P-S53 | `b131704` |
| Neu | Käuferdaten werden nie übernommen (Test über alle Tabellen) | L-28.6, FA-2.49, P-R36 | `b131704` |
| Neu | Hinweis „Gebührenrechnung als Beleg ablegen“ mit direktem Link, Anleitung je Plattform im Handbuch | L-28.7, FA-2.48 | `b131704` |

---

## 0.10.0+15 — 2026-10-14

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK, fester Testschlüssel); Stufe A3 Link-QR |
| Commit | `d96481e` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.52, Spezifikation 1.49, Benutzerhandbuch für 0.10.0, DESIGN_SPEC 1.2 |
| Datenbankschema | 16 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `link_invoice_test.dart` inkl. Touchflächen ≥ 48 dp), Emulator-Job `android-ocr-emulator`, CI-Lauf zum Commit |
| Steuerliche Kennwerte | keine Änderung |
| Offene reale Prüfpunkte | wie 0.9.0+14, dazu P-R35, P-U6 |

**Änderungen seit 0.9.0+14**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | Link-QR: Hinweisstreifen mit Domain groß, Laden nur nach Tipp, nur https/PDF/XML ≤ 20 MB, andere Domain nur nach erneuter Anzeige, sonst „Im Browser öffnen“ | L-27.7, FA-2.42, P-U6 | `d96481e` |
| Neu | Datenfluss „Rechnung über Link-QR“ dreifach dokumentiert (Lastenheft 5.19, PRIVACY, STORE_LISTING) | L-19.5, P-R35 | `d96481e` |

---

## 0.9.0+14 — 2026-10-14

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK, fester Testschlüssel); Stufe A2 PDF- und E-Rechnungen |
| Commit | `fabed21` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.51, Spezifikation 1.48, Benutzerhandbuch für 0.9.0, DESIGN_SPEC 1.2 |
| Datenbankschema | 16 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `e_invoice_test.dart` mit KoSIT-Testsuite 01.01a UBL/CII, ebInterface 6.1, ZUGFeRD-PDF), Emulator-Job `android-ocr-emulator` mit PDF-Seitenbild, CI-Lauf zum Commit |
| Steuerliche Kennwerte | `spec.schema_version` 15 → 16 |
| Offene reale Prüfpunkte | wie 0.8.0+13 |

**Änderungen seit 0.8.0+13**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | PDF-Rechnungen: eingebettetes XML, Seitenbilder (PdfRenderer/PDFKit), Texterkennung als Rückfall, iOS-Textebene | L-27.5, FA-2.39 | `fabed21` |
| Neu | E-Rechnung CII (ZUGFeRD/Factur-X/XRechnung), UBL (XRechnung), ebInterface strukturiert | L-27.6, FA-2.40 | `fabed21` |
| Neu | Originaldatei unverändert mit SHA-256, in Sicherung und Belegliste; Schema 16 `receipt_documents` | L-27.8, FA-2.41 | `fabed21` |
| Neu | Teilen-Ziel für PDF/XML, iOS „Öffnen in“ | L-27.4, FA-2.38 | `fabed21` |
| Neu | Abhängigkeit `xml` 7.1 (MIT) | FA-2.40 | `fabed21` |

---

## 0.8.0+13 — 2026-10-14

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK, fester Testschlüssel); Stufe A1 Kassen-QR, Zahlungs-QR, Teilen-Ziel |
| Commit | `6dfda7d` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.50, Spezifikation 1.47, Benutzerhandbuch für 0.8.0, DESIGN_SPEC 1.2 |
| Datenbankschema | 15 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `receipt_codes_test.dart`), Emulator-Job `android-ocr-emulator` mit synthetischem RKSV- und EPC-QR, CI-Lauf zum Commit |
| Steuerliche Kennwerte | `spec.schema_version` 14 → 15 |
| Offene reale Prüfpunkte | wie 0.7.0+12, dazu P-S49, P-S50, P-U5 |

**Änderungen seit 0.7.0+12**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | QR-/Barcodes auf demselben Foto (ML Kit Barcode Scanning gebündelt, iOS Vision) | L-27.1, FA-2.35 | `6dfda7d` |
| Neu | Kassen-QR RKSV/TSE mit Vorrang bei Betrag, Datum, Sätzen; „Besonders“ nicht geraten; Lernspeicher Kasse → Händler (Schema 15); Vermerk „vom Kassen-QR“ | L-27.2, FA-2.36, P-S49, P-S50 | `6dfda7d` |
| Neu | Zahlungs-QR EPC069-12: Empfänger, Betrag, IBAN, Referenz | L-27.3, FA-2.37 | `6dfda7d` |
| Neu | Teilen-Ziel Android für Bilder | L-27.4, FA-2.38, P-U5 | `6dfda7d` |

---

## 0.7.0+12 — 2026-10-14

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK, fester Testschlüssel); Steuersätze aufteilen, Mahnfrist, Einhandbedienung links/rechts |
| Commit | `acc37c4` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.48, Spezifikation 1.46, Benutzerhandbuch für 0.7.0, DESIGN_SPEC 1.2 |
| Datenbankschema | 14 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `receipt_vat_split_test.dart`, `manual_expense_dashboard_test.dart`, `dunning_followup_test.dart`, `pdf_fonts_test.dart`), Emulator-Job `android-ocr-emulator`, CI-Lauf zum Commit |
| Steuerliche Kennwerte | `spec.schema_version` 13 → 14 |
| Offene reale Prüfpunkte | wie 0.6.0+11, dazu P-S46 bis P-S48, P-L19, P-X7 |

**Änderungen seit 0.6.0+11**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Behoben | Gerätetest 0.6.0: Ausgabe in der Übersicht – Kleinunternehmer zählen Ausgaben brutto (keine Vorsteuer), Balken-Mindesthöhe 6 dp, nur der jüngste Ladevorgang zeigt Summen | FA-3.2, FA-3.5, FA-3.7, P-S47 | `acc37c4` |
| Behoben | € und Gedankenstrich in allen PDFs: eingebettete Schrift Work Sans (OFL) statt Helvetica | FA-5.30, P-L19 | `acc37c4` |
| Geändert | Termin-Box ans Ende der Übersicht | FA-3.7 | `acc37c4` |
| Neu | Beleg mit mehreren Steuersätzen aufteilen, Rest automatisch, Auswertungen/UVA/Exporte je Satz (DATEV eine Buchung je Satz), Belegerkennung belegt Aufteilung vor; Schema 14 `receipt_vat_lines` | L-2.27, FA-2.33, FA-2.34, P-S46, P-S48 | `acc37c4` |
| Neu | Mahnwesen: neue Frist je Schreiben, „überfällig“ erst nach deren Ablauf; Mahnsymbol mit Stufe und Frist, Tipp zeigt Verlauf | L-3.31, FA-5.26, FA-5.27 | `acc37c4` |
| Geändert | Kundendokumente (Rechnung, Mahnung, Begleittext) in Sie-Form | FA-5.28 | `acc37c4` |
| Neu | Hinweis „Leistungsdatum liegt nach dem Rechnungsdatum – stimmt das?“ | FA-5.29 | `acc37c4` |
| Geändert | Einhandbedienung links und rechts: zentrierte Knöpfe „Beleg erfassen“, „Neue Rechnung“, „Neuer Kunde“; Rechnungskarte mit Aktionsleiste inkl. „PDF senden“ | FA-12.7, P-X7 | `acc37c4` |

---

## 0.6.0+11 — 2026-10-14

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK, fester Testschlüssel); Einhandbedienung |
| Commit | `04fb0f3` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.47, Spezifikation 1.45, Benutzerhandbuch für 0.6.0, DESIGN_SPEC 1.2 |
| Datenbankschema | 13 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `one_hand_test.dart`), Emulator-Job `android-ocr-emulator`, CI-Lauf zum Commit |
| Steuerliche Kennwerte | keine Änderung |
| Offene reale Prüfpunkte | wie 0.5.0+10, dazu P-X1 bis P-X6 |

**Änderungen seit 0.5.0+10**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Geändert | Übersicht: ein zentrierter Knopf „Beleg fotografieren“ statt zweier Knöpfe rechts; öffnet direkt die Kamera, Einnahme/Ausgabe im Formular | FA-12.1, DESIGN_SPEC 5a | `04fb0f3` |
| Geändert | Beleg stornieren und Kunde löschen aus der AppBar an das Formularende (rot umrandet, Bestätigung in Fehlerfarbe); ebenso Fehlerfarbe bei „Sicherung ausschalten“ und „Wiederherstellen“ | FA-12.2, P-X2 | `04fb0f3` |
| Geändert | Belegseiten: Pfeile 48 dp, Löschen über Antippen der Seite; Chip-Reihen umbrechend, Jahr als Chip; Datum „Heute/Gestern“; `PrimaryActionBar` in Kunden- und Stammdatenformular. Test `one_hand_test.dart` | FA-12.3 bis FA-12.6, P-X1, P-X3 bis P-X6 | `04fb0f3` |

---

## 0.5.0+10 — 2026-10-14

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK, fester Testschlüssel); Mahnwesen |
| Commit | `f67355c` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.47, Spezifikation 1.44, Benutzerhandbuch für 0.5.0 |
| Datenbankschema | 13 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `dunning_test.dart`, `invoice_list_ux_test.dart`), Emulator-Job `android-ocr-emulator`, CI-Lauf zum Commit |
| Steuerliche Kennwerte | `spec.schema_version` = 13; neu `spec.dunning_default_fee_cents` = 1000, `spec.dunning_period_days` = 14, `spec.*.dunning_consumer_rate_bp` (AT 400), `spec.*.dunning_consumer_surcharge_bp` (DE 500), `spec.*.dunning_business_surcharge_bp` (AT 920, DE 900), `spec.*.dunning_flat_fee_cents` = 4000, `spec.*.dunning_base_rates`, `spec.*.dunning_consumer_notice`, `spec.*.dunning_interest_legal_ref` |
| Offene reale Prüfpunkte | P-D21, P-D22, P-D25, P-D26, P-S27 bis P-S35, P-S40 bis P-S45, P-R24 bis P-R26, P-R30 bis P-R34 |

**Änderungen seit 0.4.0+9**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | Zahlungserinnerung und Mahnungen beliebig oft (Stufe 1 Erinnerung, dann 1., 2. … Mahnung) als Bottom-Sheet mit Vorschau, PDF mit Tabelle und neuer Frist, Teilen; unveränderlich mit SHA-256, Storno mit Begründung. Schema 13 (`dunning_notices`). Test `dunning_test.dart`, `invoice_list_ux_test.dart` | L-3.10, L-3.29, FA-5.21, P-R33 | `f67355c` |
| Neu | Mahnkosten 10 € ab 1. Mahnung (änderbar) mit Hinweis bei Privatkunden; optionale Verzugszinsen act/365 je Halbjahr aus Basiszinssatz; Pauschale 40 € nur B2B | L-3.27, GR-13, FA-5.22, FA-5.23, P-R32, P-R34, P-S44 | `f67355c` |
| Neu | Kundenmerkmal „Unternehmen“ (folgt der UID); DE-Rechnungen an Privatkunden mit Hinweis § 286 Abs 3 BGB | L-3.28, FA-5.24 | `f67355c` |
| Neu | „Bezahlt“ fragt „Mahnkosten und Zinsen mitbezahlt?“ und bucht sie als nicht umsatzsteuerbare Einnahme | L-3.30, FA-5.25, P-S45 | `f67355c` |
| Geändert | Rechnungsliste: Hinweis „überfällig – mahnen?“, Tonal-Knöpfe „Erinnern/Mahnen“ und „Bezahlt“ in eigener Zeile (≥ 48 dp) | FA-5.13, FA-5.20 | `f67355c` |

---

## 0.4.0+9 — 2026-10-14

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK, fester Testschlüssel); Rabatt, Versand, Skonto, AGB-Verweis |
| Commit | `8fe9f07` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.46, Spezifikation 1.43, Benutzerhandbuch für 0.4.0 |
| Datenbankschema | 12 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (neu `invoice_totals_test.dart`, `invoice_form_ux_test.dart`), Emulator-Job `android-ocr-emulator`, CI-Lauf zum Commit |
| Steuerliche Kennwerte | `spec.schema_version` = 12; neu `spec.primary_action_height_dp` = 56, `spec.min_touch_target_dp` = 48 |
| Offene reale Prüfpunkte | P-D21, P-D22, P-D25, P-D26, P-S27 bis P-S35, P-S40 bis P-S43, P-R24 bis P-R26, P-R30, P-R31 |

**Änderungen seit 0.3.5+8**

| Art | Änderung | Bezug | Commit |
|---|---|---|---|
| Neu | Rabatt je Position und auf die Rechnung (Prozent oder Betrag), Gesamtrabatt anteilig je Steuersatz mit Restcent nach größtem Rest; Versandkosten wie Hauptleistung (anteilig bei Mischsätzen) oder fester Satz; Rechnen in `InvoiceTotals`. Schema 12. Test `invoice_totals_test.dart` | L-3.21, L-3.22, GR-12, FA-5.15, FA-5.16, P-S40, P-S41 | `8fe9f07` |
| Neu | Skonto (Tage + Prozent, Vorschlag aus dem Profil), auf dem PDF mit festem Datum und Betrag; „Bezahlt“ fragt „Mit Skonto bezahlt?“ und mindert die Einnahme je Satz; Rechnung bleibt unverändert | L-3.23, L-3.24, FA-5.17, FA-5.18, P-S42, P-S43 | `8fe9f07` |
| Neu | AGB-Adresse im Profil, Verweis „soweit sie vereinbart wurden“ auf dem PDF, eingefroren mit der Rechnung; einmaliger Hinweis zur Einbeziehung | L-3.25, L-3.26, FA-5.19, P-R30 | `8fe9f07` |
| Geändert | Bedienung nach UX-Prüfinstanz: `PrimaryActionBar` (56 dp, über der Tastatur) im Rechnungsformular, nach dem Ausstellen „PDF senden“; „Position hinzufügen“ volle Breite, Entfernen 48 dp; Rabatt/Versand/Skonto eingeklappt; Tonal-Knopf „Bezahlt“ mit Bottom-Sheet; Stornieren/Löschen in Fehlerfarbe mit Bestätigung. Test `invoice_form_ux_test.dart` | FA-5.20 | `8fe9f07` |

---

## 0.3.5+8 — 2026-10-14

| Feld | Wert |
|---|---|
| Art | Testbuild (ungezippte arm64-APK, fester Testschlüssel); Wirtschaftsjahr, Termin-Box, bezahlte Rechnung als Einnahme, Hilfe offline |
| Commit | `dd4adfa` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.45, Spezifikation 1.42, Benutzerhandbuch für 0.3.5 |
| Datenbankschema | 11 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün, Emulator-Job `android-ocr-emulator`, CI-Lauf zum Commit |
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
| Commit | `fd5bf27` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.42, Spezifikation 1.38, Benutzerhandbuch für 0.3.4 |
| Datenbankschema | 10 |
| Prüfung | `flutter analyze` ohne Befund, alle Tests grün (Korpus 6 Belege), Emulator-Job `android-ocr-emulator`, CI-Lauf zum Commit |
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
| Commit | `22b7f8b` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.42, Spezifikation 1.36, Benutzerhandbuch für 0.3.3 |
| Datenbankschema | 10 |
| Prüfung | `flutter analyze` ohne Befund, 268 Tests grün, Emulator-Job `android-ocr-emulator` grün, CI-Lauf zum Commit |
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
| Commit | `034a877` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.42, Spezifikation 1.33, Benutzerhandbuch für 0.3.2 |
| Datenbankschema | 10 |
| Prüfung | `flutter analyze` ohne Befund, 250 Tests grün, CI-Lauf zum Commit |
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
| Commit | `9f2c95a` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.42, Spezifikation 1.32, Benutzerhandbuch für 0.3.1 |
| Datenbankschema | 10 |
| Prüfung | `flutter analyze` ohne Befund, 250 Tests grün, CI-Lauf zum Commit |
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
| Commit | `d8f527e` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.42, Spezifikation 1.30, Benutzerhandbuch für 0.3.0 |
| Datenbankschema | 10 |
| Prüfung | `flutter analyze` ohne Befund, 250 Tests grün, CI-Lauf zum Commit |
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
| Commit | `db32452` |
| Branch | `claude/agile-accounting-app-mobile-wa5j3h` |
| Dokumentstände | Lastenheft 1.39, Spezifikation 1.25, Benutzerhandbuch für 0.2.0 |
| Datenbankschema | 8 |
| Prüfung | `flutter analyze` ohne Befund, 220 Tests grün, CI-Lauf zum Commit |
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
