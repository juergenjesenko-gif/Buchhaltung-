# Buchhaltung

Mobile Buchhaltung für Einzelunternehmen und Kleinunternehmer in **Österreich** und
**Deutschland**. Belege fotografieren, Einnahmen und Ausgaben führen, Rechnungen
schreiben, Daten an die Steuerberatung übergeben.

Flutter-App für Android und iOS. Offline-first: alle Daten liegen auf dem Gerät.

## Was die App kann (Stand Sprint 1)

| Bereich | Umfang |
|---|---|
| **Firmenprofil** | Land (AT/DE), Rechtsform, Anschrift, Steuernummer/UID, Kleinunternehmerregelung, Bankverbindung, Rechnungsnummernkreis |
| **Belege** | Foto aufnehmen oder auswählen, Bruttobetrag eingeben, USt wird herausgerechnet, Kategorie und Zahlungsart, Suche und Monatsgruppierung |
| **Kassabuch** | Einnahmen-Ausgaben-Rechnung je Monat/Quartal/Jahr, Umsatzsteuer je Satz, Zahllast oder Guthaben, 6-Monats-Verlauf |
| **Kleinunternehmer-Monitor** | Ampel zur Umsatzgrenze mit den unterschiedlichen Regeln für AT und DE |
| **Rechnungen** | Kundenstamm, Positionen mit Teilmengen, fortlaufende Nummer, Pflichtangaben-Prüfung, PDF zum Teilen, Status (Entwurf/Gestellt/Bezahlt/Storniert) |
| **Export** | Belegliste als CSV, DATEV-Buchungsstapel (DE), BMD-Buchungssätze (AT), Umsatzsteuer-Zusammenfassung |

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
│   ├── invoice_pdf.dart
│   ├── receipt_image_store.dart
│   ├── share_service.dart
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
flutter test             # 109 Tests
flutter run              # auf angeschlossenem Gerät oder Emulator
```

## Testen

Die CI baut bei jedem Push ein installierbares Release-APK. Herunterladen unter
**Actions → letzter Lauf → Artifacts → `test-apk`**, darin
`app-arm64-v8a-release.apk` – dafür braucht es auf dem eigenen Rechner nichts.

Schritt für Schritt, inklusive lokalem Setup und einem Testlauf, der jede
Funktion abdeckt: [`docs/TESTEN.md`](docs/TESTEN.md)

## Release

Buildnummer und Signing sind in `docs/RELEASE_PLAYBOOK.md` beschrieben. Kurz:

```bash
flutter build appbundle --release   # Google Play
flutter build ipa --release         # App Store
```

## Dokumentation

Die beiden zentralen Dokumente werden mit jeder Codeänderung mitgeführt:

- [`docs/SPECIFICATION.md`](docs/SPECIFICATION.md) – **Spezifikation.** Was die App
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

- [`docs/BACKLOG.md`](docs/BACKLOG.md) – Product Backlog mit Akzeptanzkriterien
- [`docs/SPRINT_PLAN.md`](docs/SPRINT_PLAN.md) – Sprintschnitt und Definition of Done
- [`docs/COMPLIANCE_AT_DE.md`](docs/COMPLIANCE_AT_DE.md) – steuerliche Anforderungen und
  wo die App bewusst an ihre Grenze kommt
- [`docs/RELEASE_PLAYBOOK.md`](docs/RELEASE_PLAYBOOK.md) – Weg in App Store und Google Play
- [`docs/PRIVACY.md`](docs/PRIVACY.md) – Datenschutzerklärung (Vorlage)
- [`docs/STORE_LISTING.md`](docs/STORE_LISTING.md) – Texte für die Store-Einträge

## Rechtlicher Hinweis

Die App unterstützt bei der Belegerfassung und beim Rechnungschreiben. Sie ist
**keine Steuerberatung** und **keine Registrierkasse** im Sinne der
österreichischen Registrierkassensicherheitsverordnung. Die im Code hinterlegten
Steuersätze und Grenzwerte sind nach bestem Wissen recherchiert (Stand 2025/2026),
können sich aber ändern – siehe `docs/COMPLIANCE_AT_DE.md`.
