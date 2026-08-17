# Spezifikation – Buchhaltung

**Dokumentversion:** 1.0 · **App-Version:** 0.1.0 · **Stand:** 2026-08-17
**Status:** Sprint 1 umgesetzt und verifiziert

> Dieses Dokument ist die verbindliche Beschreibung dessen, was die App tut. Es
> wird **mit jeder Änderung am Code mitgeführt** – nicht im Nachhinein. Die
> Regeln dafür stehen in [`CLAUDE.md`](../CLAUDE.md), und
> `test/specification_sync_test.dart` prüft die Kennzahlen aus Abschnitt 12
> automatisch gegen den Code. Läuft die Spezifikation dem Code weg, wird der
> Test rot.

## Inhalt

1. [Produkt und Abgrenzung](#1-produkt-und-abgrenzung)
2. [Rollen und Zielgruppe](#2-rollen-und-zielgruppe)
3. [Fachliche Grundregeln](#3-fachliche-grundregeln)
4. [Datenmodell](#4-datenmodell)
5. [Funktionale Anforderungen](#5-funktionale-anforderungen)
6. [Zustandsmodelle](#6-zustandsmodelle)
7. [Bildschirme](#7-bildschirme)
8. [Exportformate](#8-exportformate)
9. [Nichtfunktionale Anforderungen](#9-nichtfunktionale-anforderungen)
10. [Datenschutz und Berechtigungen](#10-datenschutz-und-berechtigungen)
11. [Bekannte Grenzen](#11-bekannte-grenzen)
12. [Maschinenlesbare Kenndaten](#12-maschinenlesbare-kenndaten)
13. [Änderungshistorie](#13-änderungshistorie)

---

## 1. Produkt und Abgrenzung

Mobile Buchhaltung für Einzelunternehmen und Kleinunternehmer in Österreich und
Deutschland. Flutter-App für Android und iOS.

**Im Umfang:** Firmenstammdaten, Belegerfassung mit Foto, Einnahmen-Ausgaben-
Rechnung, Umsatzsteuerermittlung, Kleinunternehmer-Grenzwertüberwachung,
Ausgangsrechnungen mit PDF, Export an die Steuerberatung.

**Nicht im Umfang – bewusste Abgrenzung:**

| Nicht enthalten | Begründung |
|---|---|
| Registrierkasse nach RKSV (AT) | Signaturerstellungseinheit, DEP, Belegprüfung und Jahresbelegmeldung sind ein eigenes, zertifizierungspflichtiges Produkt |
| Lohnverrechnung | Eigene Domäne, eigene Haftung |
| Doppelte Buchführung, Bilanz | Zielgruppe sind Einnahmen-Ausgaben-Rechner |
| Übermittlung von Steuererklärungen | Die App liefert Bemessungsgrundlagen; die Erklärung verantwortet der Unternehmer |
| Revisionssichere Archivierung | Siehe Abschnitt 11 |
| E-Rechnung (XRechnung, ZUGFeRD, ebInterface) | Geplant, siehe Backlog G1 |

---

## 2. Rollen und Zielgruppe

Es gibt **eine** Rolle: den Unternehmer, der die App auf seinem eigenen Gerät
nutzt. Kein Mehrbenutzerbetrieb, keine Rechteverwaltung, kein Login.

**Primäre Nutzer:** Einzelunternehmer und Kleinunternehmer in Österreich und
Deutschland, mit oder ohne Umsatzsteuerpflicht, die ihre Buchhaltung selbst
vorerfassen und an eine Kanzlei übergeben.

---

## 3. Fachliche Grundregeln

Diese Regeln gelten überall in der App und sind nicht verhandelbar.

### GR-1 · Geld ist ganzzahlig

Alle Beträge werden als **ganzzahlige Cent** in `Money` geführt
(`lib/domain/money.dart`). Es existiert kein `double`-Betrag in der Codebasis,
auch nicht zur Anzeige.

*Begründung:* `0.1 + 0.2 != 0.3` in Fließkomma. Ein falsch gerundeter Cent macht
eine Umsatzsteuervoranmeldung unplausibel.

### GR-2 · Netto plus Umsatzsteuer ergibt exakt Brutto

Für jede Umsatzsteuerberechnung gilt ohne Ausnahme `net + vat == gross`. Bei
Eingabe eines Bruttobetrags wird der Nettobetrag herausgerechnet und die Steuer
als **Differenz** gebildet; bei Eingabe eines Nettobetrags umgekehrt. Der vom
Nutzer eingegebene Wert bleibt dadurch immer exakt erhalten.

Formeln (`lib/services/vat_calculator.dart`):

```
aus netto:  vat   = round(net × permille / 1000)
            gross = net + vat
aus brutto: net   = round(gross × 1000 / (1000 + permille))
            vat   = gross − net
```

*Verifiziert* für alle Steuersätze über 2.000 Beträge je Satz in
`test/vat_calculator_test.dart`.

### GR-3 · Steuersätze in Promille

Steuersätze werden als Promille-Ganzzahl geführt (20 % = `200`). Das erlaubt
Sätze mit einer Dezimalstelle ohne Fließkomma.

### GR-4 · Mengen in Tausendsteln

Rechnungsmengen werden als Tausendstel geführt (1,5 Stück = `1500`). Teilmengen
bleiben dadurch exakt: 0,25 Std × 99,99 € = 25,00 €.

### GR-5 · Umsatzsteuer wird je Position gerundet

Der auf einer Rechnung ausgewiesene Steuerbetrag ist die **Summe der
Positionssteuern**, nicht eine separat gerundete Gesamtrechnung. So stimmt der
ausgewiesene Betrag mit der Summe der Zeilen überein.

### GR-6 · Länderunterschiede an einer Stelle

Alles Landesspezifische steht in `TaxProfile` in `lib/domain/country.dart`. Eine
Länderabfrage in einem Widget verletzt diese Regel.

### GR-7 · Migrationen sind unveränderlich

Eine ausgelieferte Datenbankmigration wird nie geändert, nur eine neue ergänzt.
Sonst haben aktualisierte Installationen ein anderes Schema als neue.

### GR-8 · Gestellte Rechnungen sind unveränderlich

Ab dem Status *Gestellt* ist eine Rechnung schreibgeschützt. Aussteller- und
Empfängerdaten werden zum Zeitpunkt der Rechnungslegung als JSON eingefroren.

---

## 4. Datenmodell

**Speicher:** SQLite auf dem Gerät, Datei `buchhaltung.db` im
Anwendungsdokumentenverzeichnis. Aktuelle Schemaversion: **1**.

### 4.1 Tabellen

| Tabelle | Zweck | Besonderheit |
|---|---|---|
| `company_profile` | Firmenstammdaten | Genau eine Zeile, erzwungen durch `CHECK (id = 1)` |
| `categories` | Buchhaltungskategorien | 16 Startkategorien, `is_system = 1` schützt vor Löschen |
| `customers` | Rechnungsempfänger | Löschen blockiert, solange Rechnungen bestehen |
| `receipts` | Belege | Index auf `date` und `direction` |
| `invoices` | Ausgangsrechnungen | `UNIQUE INDEX` auf `number` |
| `invoice_items` | Rechnungspositionen | `ON DELETE CASCADE` |
| `audit_log` | Änderungsprotokoll | Nur Einfügen, kein Löschen durch die App |

### 4.2 Datenwörterbuch – zentrale Felder

**`company_profile`**

| Feld | Typ | Bedeutung |
|---|---|---|
| `company_name` | TEXT | Firmenname. Pflicht; ohne ihn startet das Onboarding |
| `country_code` | TEXT | `AT` oder `DE`. Bestimmt Steuersätze und Rechtsverweise |
| `legal_form` | TEXT | `soleTrader`, `freelancer`, `gbr`, `gmbh` |
| `tax_number` | TEXT | Steuernummer beim Finanzamt |
| `vat_id` | TEXT | UID (AT) bzw. USt-IdNr. (DE). Pflicht bei Regelbesteuerung |
| `is_small_business` | INTEGER | 1 = Kleinunternehmerregelung wird genutzt |
| `invoice_number_pattern` | TEXT | Muster, Standard `RE-{YYYY}-{NNNN}` |
| `next_invoice_sequence` | INTEGER | Nächste laufende Nummer. Wird nur erhöht, nie zurückgesetzt |

**`receipts`**

| Feld | Typ | Bedeutung |
|---|---|---|
| `date` | TEXT | Belegdatum, `YYYY-MM-DD` |
| `direction` | TEXT | `income` oder `expense` |
| `description` | TEXT | Pflicht in der Eingabemaske |
| `net_cents`, `vat_cents`, `gross_cents` | INTEGER | Beträge in Cent, es gilt GR-2 |
| `vat_permille` | INTEGER | Angewandter Steuersatz, siehe GR-3 |
| `payment_method` | TEXT | `cash`, `bank`, `card`, `other` |
| `image_path` | TEXT | **Relativer** Pfad, siehe NFA-4 |

**`invoices`**

| Feld | Typ | Bedeutung |
|---|---|---|
| `number` | TEXT | Fortlaufende Nummer, eindeutig |
| `issue_date` | TEXT | Ausstellungsdatum |
| `delivery_date` | TEXT | Liefer-/Leistungsdatum. Pflicht vor dem Ausstellen |
| `status` | TEXT | `draft`, `issued`, `paid`, `cancelled` |
| `is_small_business` | INTEGER | Momentaufnahme bei Rechnungslegung, siehe GR-8 |
| `seller_snapshot`, `customer_snapshot` | TEXT | Eingefrorene Stammdaten als JSON |

**`invoice_items`**

| Feld | Typ | Bedeutung |
|---|---|---|
| `position` | INTEGER | Lückenlos ab 1, beim Speichern neu vergeben |
| `quantity_milli` | INTEGER | Menge × 1000, siehe GR-4 |
| `unit_price_cents` | INTEGER | Einzelpreis **netto** |

### 4.3 Startkategorien

16 Kategorien, drei für Einnahmen und dreizehn für Ausgaben, mit SKR03-Konten.
Vollständige Liste: `AppDatabase.seedCategories` in `lib/data/app_database.dart`.
Eigene Kategorien sind ergänzbar und löschbar; die vorgegebenen nicht.

---

## 5. Funktionale Anforderungen

### 5.1 Firmenprofil

| ID | Anforderung |
|---|---|
| FA-1.1 | Beim ersten Start zeigt die App das Onboarding, bis Firmenname und Land erfasst sind |
| FA-1.2 | Land ist Österreich oder Deutschland; die Auswahl bestimmt Steuersätze, Feldbezeichnungen und Rechtsverweise |
| FA-1.3 | Die Kleinunternehmerregelung ist ein Schalter; die App erklärt beide Folgen im Klartext |
| FA-1.4 | Bei Regelbesteuerung ist eine UID/USt-IdNr. Pflicht (Formularvalidierung) |
| FA-1.5 | Das Rechnungsnummernmuster muss eine laufende Nummer enthalten, sonst wird das Formular abgelehnt |
| FA-1.6 | Ein Bearbeiten der Stammdaten setzt `next_invoice_sequence` nie zurück |
| FA-1.7 | Die App benennt fehlende Pflichtangaben für Rechnungen und verlinkt in die Stammdaten |

**Pflichtangaben für Rechnungsfähigkeit** (`CompanyProfile.missingInvoiceFields`):
Firmenname, Straße, PLZ, Ort, Steuernummer **oder** UID; bei Regelbesteuerung
zusätzlich zwingend die UID.

### 5.2 Belege

| ID | Anforderung |
|---|---|
| FA-2.1 | Beleg per Kamera aufnehmen oder aus der Fotobibliothek wählen |
| FA-2.2 | Foto auf maximal 2000 × 2000 px bei 85 % Qualität reduziert |
| FA-2.3 | Betrag wird **brutto** eingegeben; Netto und Umsatzsteuer werden live angezeigt |
| FA-2.4 | Betrag 0 und negative Beträge werden abgelehnt; die Richtung steuert das Vorzeichen |
| FA-2.5 | Die Beschreibung ist Pflichtfeld |
| FA-2.6 | Belegdatum wählbar, maximal bis heute, rückwärts über die Aufbewahrungsfrist |
| FA-2.7 | Kategorien sind richtungsabhängig; ein Wechsel der Richtung setzt die Kategorie neu |
| FA-2.8 | Ist Kleinunternehmer aktiv und ein Satz > 0 gewählt, warnt die App |
| FA-2.9 | Liste gruppiert nach Monat, Suche über Beschreibung, Partner und Notiz |
| FA-2.10 | Filter Alle/Einnahmen/Ausgaben, Jahresauswahl über die Aufbewahrungsfrist |
| FA-2.11 | Bearbeiten und Löschen möglich; Löschen nur nach Rückfrage |
| FA-2.12 | Anlegen, Ändern und Löschen werden im `audit_log` protokolliert |

### 5.3 Kassabuch und Auswertung

| ID | Anforderung |
|---|---|
| FA-3.1 | Zeiträume: dieser Monat, letzter Monat, dieses Quartal, dieses Jahr, letztes Jahr |
| FA-3.2 | Anzeige von Einnahmen netto, Ausgaben netto und Ergebnis |
| FA-3.3 | Bei Regelbesteuerung: Umsatz je Steuersatz, Umsatzsteuer, Vorsteuer, Zahllast oder Guthaben |
| FA-3.4 | Bei Kleinunternehmern entfällt die Umsatzsteuerauswertung mit Erklärung |
| FA-3.5 | Balkenverlauf über die letzten sechs Monate, Einnahmen und Ausgaben getrennt |
| FA-3.6 | Die letzten fünf Belege sind als Schnellzugriff sichtbar |

### 5.4 Kleinunternehmer-Grenzwertüberwachung

| ID | Anforderung |
|---|---|
| FA-4.1 | Maßgeblich ist der Netto-Umsatz der Einnahmen des Kalenderjahres |
| FA-4.2 | Bei Regelbesteuerung wird nicht bewertet (Status *nicht anwendbar*) |
| FA-4.3 | Warnung ab 80 % Ausnutzung der Grenze |
| FA-4.4 | Österreich: über der Grenze, aber innerhalb der 10-%-Toleranz → Status *in Toleranz*, Befreiung gilt bis Jahresende |
| FA-4.5 | Österreich: über der Toleranz → Status *überschritten*, sofortiger Wegfall |
| FA-4.6 | Deutschland: Vorjahresumsatz über der Vorjahresgrenze → *überschritten* für das ganze laufende Jahr |
| FA-4.7 | Deutschland: keine Toleranz; der Status *in Toleranz* darf dort nie auftreten |
| FA-4.8 | Jeder Status trägt eine Erklärung der Rechtsfolge im Klartext |

Grenzwerte siehe Abschnitt 12.

### 5.5 Rechnungen

| ID | Anforderung |
|---|---|
| FA-5.1 | Kundenstamm mit Name, Anschrift, Land, UID, E-Mail |
| FA-5.2 | Kunde löschen ist blockiert, solange Rechnungen darauf verweisen |
| FA-5.3 | Positionen mit Bezeichnung, Menge, Einheit, Einzelpreis netto, Steuersatz |
| FA-5.4 | Die Rechnungsnummer wird **erst beim Ausstellen** vergeben, nicht beim Entwurf |
| FA-5.5 | Die Nummernvergabe läuft in einer Transaktion; zwei gleichzeitige Ausstellungen erhalten verschiedene Nummern |
| FA-5.6 | Vor dem Ausstellen prüft die App: Kunde, vollständige Kundenanschrift, mindestens eine Position, Bezeichnung je Position, Liefer-/Leistungsdatum, Stammdaten-Pflichtangaben |
| FA-5.7 | Fehlt etwas, ist der Knopf *Rechnung ausstellen* gesperrt und die Liste des Fehlenden sichtbar |
| FA-5.8 | Bei Kleinunternehmern entfällt die Steuerspalte vollständig und der gesetzliche Hinweistext erscheint |
| FA-5.9 | PDF im A4-Format mit allen Pflichtangaben, mehrseitig lauffähig |
| FA-5.10 | Teilen über den Systemdialog |
| FA-5.11 | Nur Entwürfe sind löschbar; gestellte Rechnungen werden storniert |
| FA-5.12 | Statuswechsel nach *bezahlt* setzt `paid_at` |
| FA-5.13 | Eine gestellte Rechnung mit überschrittener Fälligkeit wird als überfällig gekennzeichnet |
| FA-5.14 | Die Übersicht zeigt die Summe der gestellten, nicht bezahlten Rechnungen |

**Pflichtangaben im PDF** (§ 11 UStG AT, § 14 UStG DE): Name und Anschrift von
Aussteller und Empfänger, Steuernummer bzw. UID des Ausstellers,
Ausstellungsdatum, fortlaufende Nummer, Menge und Bezeichnung der Leistung,
Liefer-/Leistungsdatum, Entgelt je Steuersatz, Steuersatz und Steuerbetrag oder
– bei Befreiung – der Grund der Befreiung.

### 5.6 Export

| ID | Anforderung |
|---|---|
| FA-6.1 | Zeitraum wählbar: Jahr, Quartal oder Monat |
| FA-6.2 | Vorschau mit Belegzahl und Summen **vor** dem Teilen |
| FA-6.3 | Bei leerem Zeitraum ist der Export gesperrt und ein Hinweis sichtbar |
| FA-6.4 | DATEV wird nur bei Land DE angeboten, BMD nur bei Land AT |
| FA-6.5 | Dateiname enthält Firma und Zeitraum |
| FA-6.6 | CSV mit Semikolon, CRLF und UTF-8-BOM |

---

## 6. Zustandsmodelle

### 6.1 Rechnung

```
          ┌──────────────────────────────────┐
          │            Entwurf               │  änderbar, löschbar
          │            (draft)               │  Nummer noch nicht vergeben
          └───────────────┬──────────────────┘
                          │ ausstellen → Nummer wird gezogen,
                          │ Stammdaten werden eingefroren
                          ▼
          ┌──────────────────────────────────┐
          │           Gestellt               │  schreibgeschützt
          │           (issued)               │  überfällig, wenn Fälligkeit vorbei
          └────────┬────────────────┬────────┘
                   │                │
        bezahlt    │                │  stornieren
                   ▼                ▼
          ┌────────────────┐  ┌──────────────┐
          │  Bezahlt       │  │  Storniert   │
          │  (paid)        │  │  (cancelled) │
          └────────────────┘  └──────────────┘
```

Alle Zustände außer *Entwurf* sind schreibgeschützt (`InvoiceStatus.isLocked`).

### 6.2 Kleinunternehmerstatus

```
Regelbesteuerung ──────────────────────► nicht anwendbar

Kleinunternehmer:
  Umsatz < 80 % der Grenze ────────────► ok
  Umsatz ≥ 80 % ≤ Grenze ──────────────► nähert sich
  Grenze < Umsatz ≤ Toleranz (nur AT) ─► in Toleranz
  Umsatz > Toleranz (AT)             ──┐
  Umsatz > Grenze (DE, ohne Toleranz)──┼─► überschritten
  Vorjahr > Vorjahresgrenze (DE)     ──┘
```

---

## 7. Bildschirme

| Bildschirm | Datei | Zweck |
|---|---|---|
| Onboarding / Stammdaten | `features/onboarding/company_setup_screen.dart` | Firmenprofil anlegen und bearbeiten |
| Hauptnavigation | `features/home/home_shell.dart` | Vier Bereiche als Tab-Leiste |
| Übersicht | `features/dashboard/dashboard_screen.dart` | Kassabuch, Umsatzsteuer, Grenzwertampel, Verlauf |
| Belegliste | `features/receipts/receipt_list_screen.dart` | Suchen, filtern, öffnen |
| Beleg bearbeiten | `features/receipts/receipt_edit_screen.dart` | Erfassen, Foto, Betrag, Kategorie |
| Rechnungsliste | `features/invoices/invoice_list_screen.dart` | Status, PDF teilen, Aktionen |
| Rechnung bearbeiten | `features/invoices/invoice_edit_screen.dart` | Kunde, Positionen, Ausstellen |
| Kunde bearbeiten | `features/invoices/customer_edit_screen.dart` | Kundenstammdaten |
| Export | `features/export/export_screen.dart` | Zeitraum, Vorschau, Format |
| Einstellungen | `features/settings/settings_screen.dart` | Stammdaten, Kategorien, Rechtsrahmen, Hinweise |

**Navigation:** Vier Ziele in der Tab-Leiste – Übersicht, Belege, Rechnungen,
Export. Einstellungen erreicht man über das Zahnrad in der Übersicht.

---

## 8. Exportformate

### 8.1 Allgemein

Alle Exporte sind CSV mit Semikolon als Trennzeichen, CRLF als Zeilenende und
UTF-8 mit BOM. *Begründung:* Excel im deutschsprachigen Raum erwartet Semikolon;
ein Komma würde bei „1.234,56" die Spalten zerreißen. Das BOM sorgt dafür, dass
Excel Umlaute nicht zerlegt.

Beträge im Export: Dezimalkomma, zwei Stellen, **kein** Tausendertrenner – ein
Punkt würde beim Import als Dezimalpunkt gelesen und den Betrag um Faktor 1000
verfälschen.

### 8.2 Belegliste (`plainCsv`)

Spalten: Datum, Art, Beschreibung, Geschäftspartner, Kategorie, Konto,
Zahlungsart, Netto, USt-Satz, USt-Betrag, Brutto, Beleg vorhanden, Notiz.
Danach Summenzeilen für Einnahmen, Ausgaben und Ergebnis.

### 8.3 DATEV-Buchungsstapel (`datev`, nur DE)

EXTF-Format, Formatversion 700, Kategorie 21. Zeile 1 Metadaten, Zeile 2
Spaltenüberschriften, ab Zeile 3 die Buchungen.

- Gebucht wird immer **brutto**, ohne Vorzeichen
- Das Vorzeichen steckt im Soll/Haben-Kennzeichen: Einnahme `H`, Ausgabe `S`
- Belegdatum als `TTMM`; das Jahr steht im Header
- Buchungstext maximal 60 Zeichen, Semikola werden durch Komma ersetzt
- Berater- und Mandantennummer stehen als `0` – die Kanzlei ordnet den Stapel beim Import zu

### 8.4 BMD-Buchungssätze (`bmd`, nur AT)

Spalten: Satzart, Konto, Gegenkonto, Belegdatum, Belegnummer, Buchungstext,
Betrag, Steuercode, Steuersatz, Steuerbetrag, Buchsymbol.

Steuercodes: Einnahme 20 % → `1`, 13 % → `3`, 10 % → `2`; Ausgabe 20 % → `11`,
13 % → `13`, 10 % → `12`; 0 % → `0`.
Buchsymbol: `KA` bei Barzahlung, sonst `BK`.

### 8.5 Umsatzsteuer-Zusammenfassung (`vatReturn`)

Stammdaten, Zeitraum, steuerpflichtige Umsätze je Satz mit Bemessungsgrundlage
und Steuer, Vorsteuer je Satz, Zahllast oder Guthaben, Ergebnis netto. Bei
Kleinunternehmern zusätzlich der Befreiungsvermerk.

### 8.6 Kontenzuordnung

Grundlage ist SKR03. Für Österreich wird auf den Einheitskontenrahmen gemappt.
Gegenkonto nach Zahlungsart: Bar → `1000` (Kasse), Bank und Karte → `1200`,
Sonstiges → `1360`.

Beide Zuordnungen sind **Vorschläge**. Die Kontonummer je Kategorie ist in den
Einstellungen überschreibbar.

---

## 9. Nichtfunktionale Anforderungen

| ID | Anforderung |
|---|---|
| NFA-1 | Offline-first: die App baut von sich aus keine Netzwerkverbindung auf |
| NFA-2 | Kein Nutzerkonto, keine Registrierung, sofort nach dem Onboarding nutzbar |
| NFA-3 | Keine Analyse-, Crash-Reporting- oder Werbe-Bibliotheken |
| NFA-4 | Belegfotos werden mit **relativem** Pfad referenziert, weil sich der iOS-Anwendungscontainer bei jedem App-Update ändert |
| NFA-5 | Androids automatisches Backup und die Gerät-zu-Gerät-Übertragung sind deaktiviert |
| NFA-6 | Fachlogik in `lib/domain` und `lib/services` importiert kein `material.dart` und ist ohne UI testbar |
| NFA-7 | `flutter analyze` ohne Befund, `dart format` ohne Änderung, alle Tests grün – siehe Definition of Done |
| NFA-8 | Sprache der Oberfläche ist Deutsch; Zahlen- und Datumsformat richten sich nach dem Firmensitz (`de_AT` / `de_DE`) |
| NFA-9 | Zustandsverwaltung über einen einzigen `ChangeNotifier`; kein State-Management-Paket als Abhängigkeit |

---

## 10. Datenschutz und Berechtigungen

### 10.1 Datenflüsse

Daten verlassen das Gerät **ausschließlich** durch eine vom Nutzer ausgelöste
Aktion:

1. Rechnung als PDF teilen
2. Export für die Steuerberatung teilen

In beiden Fällen wählt der Nutzer das Ziel im Systemdialog. Die App kennt das
Ziel nicht und protokolliert es nicht.

### 10.2 Berechtigungen

| Berechtigung | Plattformschlüssel | Zweck |
|---|---|---|
| Kamera | `NSCameraUsageDescription` | Belege abfotografieren |
| Fotobibliothek lesen | `NSPhotoLibraryUsageDescription` | Vorhandene Belegfotos hinzufügen |
| Fotobibliothek schreiben | `NSPhotoLibraryAddUsageDescription` | Rechnung in der Fotobibliothek ablegen |

Android benötigt für `image_picker` keine Manifest-Berechtigung, weil die
Aufnahme über die System-Kamera-App per Intent läuft.

Details: [`docs/PRIVACY.md`](PRIVACY.md).

---

## 11. Bekannte Grenzen

Offen benannt, weil eine Spezifikation, die ihre Lücken verschweigt, wertlos ist.

| Grenze | Auswirkung | Geplant |
|---|---|---|
| **Kein Backup** | Geräteverlust bedeutet Datenverlust bei laufender Aufbewahrungspflicht | Backlog F1, Sprint 2, **vor** dem öffentlichen Release |
| **Keine revisionssichere Archivierung** | Das `audit_log` schafft Nachvollziehbarkeit im Alltag, ist aber keine manipulationssichere Protokollierung im Sinne einer Verfahrensdokumentation. Die App ist die Vorerfassung; die revisionssichere Aufbewahrung findet in der Kanzlei statt | – |
| **Keine Registrierkasse** | Wer die RKSV-Grenzen (15.000 € Umsatz und 7.500 € Barumsätze) überschreitet, braucht zusätzlich eine registrierkassenpflichtige Lösung | Nicht geplant |
| **Keine E-Rechnung** | Ein PDF ist keine E-Rechnung nach EN 16931. In Deutschland gilt die Empfangspflicht seit 1.1.2025, die Versandpflicht kommt gestaffelt bis 2028 | Backlog G1 |
| **Keine Storno-/Gutschriftsrechnung** | Eine gestellte Rechnung ist gesperrt; es gibt derzeit keinen Korrekturweg innerhalb der App | Backlog F4, Sprint 2 |
| **Nur eine Währung** | Nur Euro. Ein Land mit anderer Währung setzt Mehrwährungsfähigkeit voraus | Backlog G7 |
| **Mengen mit zwei Dezimalstellen** | Die Mengeneingabe verarbeitet zwei Nachkommastellen, obwohl das Datenmodell drei erlaubt | – |
| **Android-APK-Build nicht lokal verifiziert** | Im Entwicklungscontainer ist `dl.google.com` per Netzwerk-Policy gesperrt, das Android SDK ließ sich nicht installieren. Analyse, Format und Tests laufen lokal; die Plattform-Builds verifiziert die CI | – |

---

## 12. Maschinenlesbare Kenndaten

> **Diese Werte prüft `test/specification_sync_test.dart` gegen den Code.**
> Wird ein Wert im Code geändert, ohne ihn hier anzupassen, schlägt der Test fehl.
> Das ist der Mechanismus, der dieses Dokument aktuell hält.

```properties
spec.schema_version = 1
spec.seed_category_count = 16
spec.seed_category_income_count = 3
spec.seed_category_expense_count = 13
spec.warn_threshold_percent = 80
spec.default_invoice_pattern = RE-{YYYY}-{NNNN}
spec.default_payment_term_days = 14
spec.receipt_image_max_edge_px = 2000
spec.receipt_image_quality_percent = 85
spec.trend_months = 6
spec.dashboard_recent_receipts = 5

# Österreich – § 6 Abs 1 Z 27 UStG, § 11 Abs 6 UStG, § 132 BAO
spec.at.vat_permille = 200,130,100,0
spec.at.default_vat_permille = 200
spec.at.turnover_limit_cents = 5500000
spec.at.tolerance_limit_cents = 6050000
spec.at.previous_year_limit_cents = none
spec.at.small_amount_invoice_limit_cents = 40000
spec.at.retention_years = 7
spec.at.vat_id_label = UID-Nummer
spec.at.invoice_legal_ref = § 11 UStG
spec.at.small_business_legal_ref = § 6 Abs 1 Z 27 UStG

# Deutschland – § 19 UStG, § 33 UStDV, § 147 AO
spec.de.vat_permille = 190,70,0
spec.de.default_vat_permille = 190
spec.de.turnover_limit_cents = 10000000
spec.de.tolerance_limit_cents = none
spec.de.previous_year_limit_cents = 2500000
spec.de.small_amount_invoice_limit_cents = 25000
spec.de.retention_years = 8
spec.de.vat_id_label = USt-IdNr.
spec.de.invoice_legal_ref = § 14 UStG
spec.de.small_business_legal_ref = § 19 UStG
```

Umrechnung: Beträge in Cent. `5500000` Cent = 55.000,00 €.

---

## 13. Änderungshistorie

| Version | Datum | App-Version | Änderung |
|---|---|---|---|
| 1.0 | 2026-08-17 | 0.1.0 | Erstfassung nach Sprint 1. Beschreibt Firmenprofil, Belege, Kassabuch, Grenzwertüberwachung, Rechnungen mit PDF und die vier Exportformate. |

### Pflege dieses Dokuments

Bei jeder Änderung am Code:

1. Betroffene Abschnitte anpassen – Anforderungen, Datenmodell, Grenzen
2. Abschnitt 12 anpassen, wenn sich ein Kennwert ändert
3. `flutter test` laufen lassen; `specification_sync_test.dart` deckt Abweichungen auf
4. Zeile in der Änderungshistorie ergänzen, Dokumentversion erhöhen
5. Bei Änderungen, die der Nutzer sieht: auch
   [`BENUTZERHANDBUCH.md`](BENUTZERHANDBUCH.md) anpassen

Verbindliche Regeln dazu: [`CLAUDE.md`](../CLAUDE.md).
