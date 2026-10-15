# JeNi bucht

Mobile Buchhaltung für Einzelunternehmen und Kleinunternehmer in **Österreich** und
**Deutschland**. Belege fotografieren, Einnahmen und Ausgaben führen, Rechnungen
schreiben, Daten an die Steuerberatung übergeben.

Flutter-App für Android und iOS. Offline-first: alle Daten liegen auf dem Gerät.

## Stand der App

**Aktuelle Version: 0.12.0 (Testbuild vom 2026-10-15).** Noch nicht im Store.
Was in welcher Version kam: [`docs/RELEASE_NOTES.md`](docs/RELEASE_NOTES.md);
Zuordnung zu den Anforderungen: Lastenheft Abschnitt 10a.

| Bereich | Was die App heute kann |
|---|---|
| **Einrichten** | Firmenprofil AT/DE, Kleinunternehmerregelung, Logo, Wirtschaftsjahr, Eröffnungswerte, Bestätigungen vor der ersten Nutzung |
| **Belege** | Foto mit mehreren Seiten, automatisches Auslesen (Betrag, Datum, Steuersatz, Händler, Rechnungsnummer), Kassen-QR (AT/DE) und Zahlungs-QR, mehrere Steuersätze je Beleg, Fremdwährung mit EZB-Kurs, Kommentare, Storno statt Löschen |
| **Übernehmen** | Bilder, PDF- und E-Rechnungen (XRechnung, ZUGFeRD, ebInterface) per Teilen bzw. „Öffnen in“, Rechnung über Link-QR, Monatsberichte von Amazon, PayPal, Shopify und Stripe |
| **Zahlen** | Einnahmen-Ausgaben-Rechnung, Umsatzsteuer je Satz inkl. Reverse Charge, Kleinunternehmer-Ampel, Termin-Box mit den nächsten Steuerterminen |
| **Rechnungen** | Kunden, Positionen, Rabatt, Versand, Skonto, AGB-Verweis, Pflichtangaben-Prüfung, PDF senden, „Bezahlt“ bucht die Einnahme, Zahlungserinnerung und Mahnungen mit Mahnkosten und Zinsen |
| **Export** | Belegliste CSV, DATEV (DE), BMD (AT), Umsatzsteuer-Zusammenfassung |
| **Sicherheit** | Verschlüsselte Sicherung (manuell oder automatisch in einen eigenen Ordner), App-Sperre mit PIN oder Fingerabdruck/Face ID |
| **Bedienung** | Einhändig mit dem Daumen, Tablet- und Querformat, Hilfe mit Suche im Handbuch und Support-Mail |

**Offen bis zum Store-Start** (Einzelheiten: [`docs/STORE_READINESS.md`](docs/STORE_READINESS.md)):

1. **Entscheidungen der Auftraggeberin:** Produktname nach Markenrecherche (O-2, O-25), Verifizierung von E-Mail/Telefon (O-30), Haftpflicht (O-26)
2. **Konten:** D-U-N-S-Nummer, Google-Play-Organisationskonto, Apple Developer Program
3. **Funktionen aus Stufe A:** Storno- bzw. Korrekturrechnung, Angebote, Artikelverwaltung, Menü „Rechtliches“, Lizenz und Abo
4. **Technik:** eigenes App-Symbol, Privacy Manifest (iOS), Store-Upload im Release-Workflow, Formulare (Data Safety, Privacy Labels)
5. **Prüfung in der realen Welt:** Rechtstexte, Steuerberatung (Probeexporte), Gerätetests – alle Punkte in [`docs/SPECIFICATION.md`](docs/SPECIFICATION.md) Abschnitt 14

## Architektur

```
lib/
├── domain/          Fachliche Typen ohne Framework-Abhängigkeit
│   ├── money.dart          Geldbeträge als ganzzahlige Cent
│   ├── country.dart        AT/DE: Steuersätze, Grenzen, Rechtsverweise
│   ├── company_profile.dart
│   ├── customer.dart
│   ├── receipt.dart
│   └── invoice.dart
├── services/        Fachlogik, testbar ohne UI
│   ├── vat_calculator.dart        Umsatzsteuer auf ganzen Cent
│   ├── invoice_numbering.dart     Fortlaufende Rechnungsnummern
│   ├── small_business_monitor.dart Umsatzgrenzen AT/DE
│   ├── invoice_pdf.dart, dunning_*.dart  Rechnung, Mahnwesen
│   ├── receipt_scan/              Belegerkennung, QR-Codes, E-Rechnung
│   ├── platform_import/           Amazon, PayPal, Shopify, Stripe
│   ├── backup/, app_lock/, help/  Sicherung, App-Sperre, Hilfe
│   └── export/                    CSV, DATEV, BMD
├── data/            SQLite-Schema und Repositories
├── features/        Ein Ordner je Bildschirm
├── core/            Formatierung, Zeiträume
├── widgets/         Gemeinsame UI-Bausteine
├── app_state.dart   Zustand als ChangeNotifier
└── theme.dart
```

Zwei Entscheidungen, die den Rest erklären:

**Geld ist `int`, nie `double`.** `Money` speichert Cent als ganze Zahl. Ein
gerundeter Cent zu viel macht eine Umsatzsteuervoranmeldung unplausibel, und
`0.1 + 0.2 != 0.3` ist in einer Buchhaltung kein akademisches Problem.

**Länderunterschiede stecken nur in `country.dart`.** Steuersätze,
Umsatzgrenzen, Kleinbetragsgrenzen, Aufbewahrungsfristen und Gesetzeszitate für
AT und DE sind dort als `TaxProfile` gebündelt. Ein drittes Land wäre dadurch
überwiegend Konfiguration.

Zustandsverwaltung ist ein einzelner `ChangeNotifier` (`AppState`) über
`InheritedNotifier` – kein Riverpod, kein Bloc. Der Zustand dieser App ist klein,
und jede Abhängigkeit weniger ist eine, die vor einem Store-Release nicht
aktualisiert werden muss.

## Entwickeln

Voraussetzung: Flutter 3.47 oder neuer.

```bash
flutter pub get
flutter analyze          # muss ohne Befund durchlaufen
flutter test             # über 400 Tests
flutter run              # auf angeschlossenem Gerät oder Emulator
```

## Testen

Die CI baut bei jedem Push ein installierbares Release-APK. Herunterladen unter
**Actions → letzter Lauf → Artifacts → `JeNi-bucht-<Version>-build-<Nummer>.apk`**
(direkt die APK, nicht gezippt) – dafür braucht es auf dem eigenen Rechner nichts.
Aus der Claude-App: im Fenster ⋮ → „In Chrome öffnen“, sonst wird die Datei
nicht gespeichert.

Schritt für Schritt, inklusive lokalem Setup und einem Testlauf, der jede
Funktion abdeckt: [`docs/TESTEN.md`](docs/TESTEN.md)

## Release

Buildnummer und Signing sind in `docs/RELEASE_PLAYBOOK.md` beschrieben. Kurz:

```bash
flutter build appbundle --release   # Google Play
flutter build ipa --release         # App Store
```

## Dokumentation

Die zentralen Dokumente werden mit jeder Codeänderung mitgeführt:

- [`docs/LASTENHEFT.md`](docs/LASTENHEFT.md) – **Lastenheft.** Das Zielbild des
  Produkts: Geschäftsziele, Zielgruppe, numerierte Anforderungen mit Priorität
  und Ausbaustufe, Abgrenzung, Risiken und offene Punkte.
- [`docs/SPECIFICATION.md`](docs/SPECIFICATION.md) – **Spezifikation (Pflichtenheft).** Was die App
  tut, mit numerierten Anforderungen, Datenmodell, Zustandsmodellen,
  Exportformaten und offen benannten Grenzen.
- [`docs/BENUTZERHANDBUCH.md`](docs/BENUTZERHANDBUCH.md) – **Benutzerhandbuch.**
  Dieselbe App aus Nutzersicht, mit Schritt-für-Schritt-Anleitungen und
  Fehlermeldungen.

Dass beide aktuell bleiben, ist nicht Disziplin, sondern erzwungen:

- `test/specification_sync_test.dart` liest die Kennzahlen aus Abschnitt 12 der
  Spezifikation und vergleicht sie mit dem Code. Weicht ein Steuersatz, eine
  Umsatzgrenze oder die Schemaversion ab, ist der Test rot. Ein dokumentierter
  Wert, den keine Prüfung erfasst, ist ebenfalls rot.
- Die CI verlangt bei jedem Pull Request, der `lib/` anfasst, eine Änderung an
  `docs/SPECIFICATION.md` (Ausnahme: `[skip-spec]` in der Commit-Nachricht).
- Die Zuordnung „welche Änderung betrifft welchen Abschnitt" steht in
  [`CLAUDE.md`](CLAUDE.md).

Weiteres:

- [`docs/DESIGN_SPEC.md`](docs/DESIGN_SPEC.md) – Designspezifikation für Designvarianten (feste Regeln, Spielraum, KI-Briefing)
- [`docs/WETTBEWERB.md`](docs/WETTBEWERB.md) – Wettbewerbsanalyse mit Preisbändern und Preisvorschlag
- [`docs/BACKLOG.md`](docs/BACKLOG.md) – Product Backlog mit Akzeptanzkriterien
- [`docs/SPRINT_PLAN.md`](docs/SPRINT_PLAN.md) – Sprintschnitt und Definition of Done
- [`docs/COMPLIANCE_AT_DE.md`](docs/COMPLIANCE_AT_DE.md) – steuerliche Anforderungen und
  wo die App bewusst an ihre Grenze kommt
- [`docs/RELEASE_PLAYBOOK.md`](docs/RELEASE_PLAYBOOK.md) – Weg in App Store und Google Play
- [`docs/STORE_READINESS.md` (Formulare: `docs/STORE_ANMELDUNG.md`, iPhone-Test: `docs/IPHONE_TEST.md`)](docs/STORE_READINESS.md) – Checkliste bis zur Einreichung
- [`docs/RELEASE_NOTES.md`](docs/RELEASE_NOTES.md) – Release Notes mit Nachverfolgbarkeit je Version
- [`docs/SICHERUNG.md`](docs/SICHERUNG.md) – Zusatzsicherung auf die lokale SSD
- [`docs/PRIVACY.md`](docs/PRIVACY.md) – Datenschutzerklärung (Vorlage)
- [`docs/STORE_LISTING.md`](docs/STORE_LISTING.md) – Texte für die Store-Einträge

## Rechtlicher Hinweis

Die App unterstützt bei der Belegerfassung und beim Rechnungschreiben. Sie ist
**keine Steuerberatung** und **keine Registrierkasse** im Sinne der
österreichischen Registrierkassensicherheitsverordnung. Die im Code hinterlegten
Steuersätze und Grenzwerte sind nach bestem Wissen recherchiert (Stand 2025/2026),
können sich aber ändern – siehe `docs/COMPLIANCE_AT_DE.md`.
