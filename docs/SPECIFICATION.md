# Spezifikation – Buchhaltung

**Dokumentversion:** 1.15 · **App-Version:** 0.1.0 · **Stand:** 2026-10-10
**Status:** Sprint 1 umgesetzt und verifiziert

> Das **Zielbild** des Produkts steht im [`LASTENHEFT.md`](LASTENHEFT.md); dieses
> Dokument beschreibt, was die App **heute tatsächlich tut**.
>
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
14. [Prüfung in der realen Welt](#14-prüfung-in-der-realen-welt)

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
Anwendungsdokumentenverzeichnis. Aktuelle Schemaversion: **2**.

### 4.1 Tabellen

| Tabelle | Zweck | Besonderheit |
|---|---|---|
| `company_profile` | Firmenstammdaten | Genau eine Zeile, erzwungen durch `CHECK (id = 1)` |
| `categories` | Buchhaltungskategorien | 16 Startkategorien, `is_system = 1` schützt vor Löschen |
| `customers` | Rechnungsempfänger | Löschen blockiert, solange Rechnungen bestehen |
| `receipts` | Belege | Index auf `date` und `direction`. Werden nie gelöscht, nur storniert (`cancelled_at`) |
| `invoices` | Ausgangsrechnungen | `UNIQUE INDEX` auf `number` |
| `invoice_items` | Rechnungspositionen | `ON DELETE CASCADE` |
| `audit_log` | Änderungsprotokoll | Nur Einfügen, kein Löschen durch die App |
| `vat_id_checks` | Protokoll der UID-Abfragen: UID, Ergebnis, Zeitpunkt, Name/Anschrift laut VIES, Abfragenummer, Fehlercode | Nur Einfügen (Schema 5) |
| `opening_turnover` | Umsatz je Jahr vor Beginn der Erfassung (Eröffnungswert) | Ein Eintrag je Jahr; fehlend ≠ 0 € (seit Schema 2) |

### 4.2 Datenwörterbuch – zentrale Felder

**`company_profile`**

| Feld | Typ | Bedeutung |
|---|---|---|
| `company_name` | TEXT | Firmenname. Pflicht; ohne ihn startet das Onboarding |
| `country_code` | TEXT | `AT` oder `DE`. Bestimmt Steuersätze und Rechtsverweise |
| `legal_form` | TEXT | `soleTrader`, `freelancer`, `gbr`, `gmbh` |
| `tax_number` | TEXT | Steuernummer beim Finanzamt |
| `vat_id` | TEXT | UID (AT) bzw. USt-IdNr. (DE). Optional, Pflicht nur je Rechnung (FA-1.4) |
| `is_small_business` | INTEGER | 1 = Kleinunternehmerregelung wird genutzt |
| `invoice_number_pattern` | TEXT | Muster, Standard `RE-{YYYY}-{NNNN}` |
| `next_invoice_sequence` | INTEGER | Nächste laufende Nummer. Wird nur erhöht, nie zurückgesetzt |
| `tracking_start` | TEXT | Tag, ab dem die App die Buchhaltung führt. Neue Profile: Tag des Onboardings; bei Migration auf Schema 2: ältester Beleg, sonst Tag der Migration |
| `founding_year` | INTEGER | Gründungsjahr, `NULL` wenn nicht angegeben (Schema 3) |
| `register_number`, `register_court` | TEXT | Firmenbuch-/Handelsregisternummer und Gericht (Schema 5) |
| `vat_check_enabled` | INTEGER | 1 = wöchentliche UID-Prüfung eingeschaltet (Opt-in, Standard 0; Schema 5) |
| `vat_check_last_run` | TEXT | Zeitpunkt der letzten Prüfrunde (Schema 5) |
| `auto_backup_enabled`, `auto_backup_target`, `auto_backup_target_label`, `auto_backup_last_at`, `auto_backup_last_error` | INTEGER/TEXT | Automatische Sicherung: eingeschaltet, Ordnerzugriff (SAF-URI bzw. Bookmark), Anzeigename, letzte geprüfte Sicherung, letzter Fehler (Schema 6). Nicht Teil des Stammdatenformulars |
| `last_backup_at` | TEXT | Zeitpunkt der letzten Datensicherung bzw. der wiederhergestellten Sicherung; nur vom Sicherungsdienst geschrieben (Schema 4) |

**`receipts`** — zusätzlich seit Schema 3: `cancelled_at` (TEXT, Zeitpunkt der Stornierung, `NULL` = gültig)


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
| FA-1.4 | Steuernummer und UID sind im Profil **optional** (Steuernummer kann noch beantragt sein). Für Rechnungen gilt: DE Steuernummer **oder** USt-IdNr. auf jeder Rechnung (`spec.de.invoice_requires_tax_id`); AT ab 10.000 € brutto mit Steuerausweis UID des Ausstellers **und** des Empfängers (`spec.at.large_invoice_vat_id_limit_cents`, `InvoiceRequirements`) |
| FA-1.4a | UID-Felder (Profil und Kunde) werden **offline** auf Format und Prüfziffer geprüft (AT: ATU + 8 Ziffern; DE: DE + 9 Ziffern, ISO 7064 MOD 11,10; übrige EU-Länder: Länderkennung und Muster) |
| FA-1.4b | **UID-Prüfung über VIES** direkt vom Gerät an die REST-Schnittstelle der EU-Kommission, auf Tippen „Jetzt prüfen“; die eigene UID wird als Anfragende mitgesendet, damit VIES eine Abfragenummer als Nachweis liefert. Ergebnis dreiwertig: gültig / ungültig / nicht prüfbar – ein Ausfall ist nie „ungültig“ |
| FA-1.4c | **Wöchentliche Prüfung nur nach Opt-in** (`vat_check_enabled`, Schalter in den Stammdaten): eigene UID und UIDs von Kunden mit Rechnung in den letzten 12 Monaten, seriell mit 1 s Pause; ausgelöst beim Start und bei Rückkehr in die App, wenn die letzte Runde ≥ 7 Tage zurückliegt (`spec.vat_check_interval_days`). Eine echte Hintergrundausführung gibt es nicht |
| FA-1.4d | Jede VIES-Abfrage wird in `vat_id_checks` protokolliert (nur Einfügen). Bei eingeschalteter Prüfung wird die Kunden-UID vor dem Ausstellen geprüft und das Ergebnis im `customer_snapshot` der Rechnung eingefroren; ein negatives Ergebnis warnt, blockiert aber nie |
| FA-1.4e | Firmenbuch-/Handelsregisternummer optional; ist sie gesetzt, ist das Gericht Pflicht. Beide erscheinen in der Fußzeile jeder Rechnung (§ 14 UGB, § 37a HGB) |
| FA-1.5 | Das Rechnungsnummernmuster muss eine laufende Nummer enthalten, sonst wird das Formular abgelehnt |
| FA-1.6 | Ein Bearbeiten der Stammdaten setzt `next_invoice_sequence` nie zurück |
| FA-1.7 | Die App benennt fehlende Pflichtangaben für Rechnungen und verlinkt in die Stammdaten |
| FA-1.8 | Bei aktiver Kleinunternehmerregelung fragt das Profil den **Umsatz des Vorjahres** und den **Umsatz des laufenden Jahres vor Beginn der Erfassung** ab, soweit die App diese Zeiträume nicht selbst kennt. Pflichtfelder; leer ist nicht 0 |
| FA-1.9 | Beim Wechsel zur Regelbesteuerung bleiben erfasste Eröffnungswerte erhalten |

**Pflichtangaben für Rechnungsfähigkeit** (`CompanyProfile.missingInvoiceFields`):
Firmenname, Straße, PLZ, Ort; in Deutschland Steuernummer **oder** USt-IdNr.;
bei gesetzter Registernummer das Registergericht. Betragsabhängige Angaben
prüft `InvoiceRequirements` (FA-1.4).

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
| FA-2.11 | Bearbeiten möglich. **Belege werden nicht gelöscht, sondern storniert** (nach Rückfrage): sie bleiben samt Foto gespeichert, erscheinen in keiner Liste und zählen in keiner Auswertung, keinem Export und nicht zur Umsatzgrenze (Aufbewahrungspflicht § 132 BAO, § 147 AO; GoBD) |
| FA-2.12 | Anlegen, Ändern und Stornieren werden im `audit_log` protokolliert |

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
| FA-4.1 | Maßgeblich sind die Einnahmen des Kalenderjahres: in Österreich **brutto** (ausgewiesene Umsatzsteuer zählt mit, z. B. bei versehentlichem Ausweis oder Auslandslieferungen; ohne Ausweis ist brutto gleich netto), in Deutschland netto (`spec.*.turnover_basis`). Alle Einnahmen zählen, auch Hilfsgeschäfte (siehe P-S1) |
| FA-4.2 | Bei Regelbesteuerung wird nicht bewertet (Status *nicht anwendbar*) |
| FA-4.3 | Warnung ab 80 % Ausnutzung der Grenze |
| FA-4.4 | Österreich: über der Grenze, aber innerhalb der 10-%-Toleranz → Status *überschritten* (**harte Grenze zur Sicherheit**, Entscheidung des Auftraggebers 2026-10-10). Die Meldung weist auf die mögliche Toleranz hin und verlangt, die Steuerberatung zu fragen |
| FA-4.5 | Österreich: über der Toleranz → Status *überschritten*, sofortiger Wegfall |
| FA-4.6 | Vorjahresumsatz über der Vorjahresgrenze → *überschritten* für das ganze laufende Jahr. Deutschland 25.000 €, Österreich 55.000 €; die österreichische Toleranz gilt nicht für das Vorjahr |
| FA-4.7 | Deutschland: keine Toleranz; die Meldung erwähnt keine |
| FA-4.8 | Jeder Status trägt eine Erklärung der Rechtsfolge im Klartext |
| FA-4.9 | Der Jahresumsatz setzt sich aus erfassten Einnahmen und dem Eröffnungswert des Jahres zusammen. Ein Jahr ist **vollständig**, wenn die Erfassung spätestens am 1. Jänner begann oder ein Eröffnungswert vorliegt; bei voll erfasstem Jahr wird ein Eröffnungswert ignoriert |
| FA-4.10 | Ist der Vorjahresumsatz unbekannt und kennt das Land eine Vorjahresgrenze, lautet der Status *Angaben fehlen* — nie *ok* |
| FA-4.11 | Ist das laufende Jahr unvollständig, lautet der Status *Angaben fehlen* — außer die Grenze ist bereits überschritten, dann *überschritten* |
| FA-4.12 | Der Status *Angaben fehlen* führt in der Übersicht direkt zur Ergänzung in den Stammdaten |
| FA-4.13 | **Gründungsjahr:** Ist das laufende Jahr das Gründungsjahr, gibt es keine Vorjahresprüfung und keinen Vorjahres-Eröffnungswert; Deutschland prüft gegen 25.000 € statt 100.000 € (`spec.de.founding_year_limit_cents`, § 19 Abs 1 UStG) | 

> **Erledigt in Dokumentversion 1.4: Vorjahresgrenze Österreich (O-1).** Auch
> in Österreich darf der Vorjahresumsatz 55.000 € nicht überschritten haben
> (§ 6 Abs 1 Z 27 UStG). Bis dahin prüfte die App nur das laufende Jahr.

> **Behoben in Dokumentversion 1.3: Vorjahresumsatz neuer Nutzer (O-19).**
> Bis dahin wurde der Vorjahresumsatz ausschließlich aus erfassten Belegen
> ermittelt und war für Neueinsteiger null — die Ampel stand fälschlich auf
> Grün. Seither gelten FA-4.9 bis FA-4.12.

Grenzwerte siehe Abschnitt 12.

### 5.5 Rechnungen

| ID | Anforderung |
|---|---|
| FA-5.1 | Kundenstamm mit Name, Anschrift, Land, UID, E-Mail |
| FA-5.2 | Kunde löschen ist blockiert, solange Rechnungen darauf verweisen |
| FA-5.3 | Positionen mit Bezeichnung, Menge, Einheit, Einzelpreis netto, Steuersatz |
| FA-5.4 | Die Rechnungsnummer wird **erst beim Ausstellen** vergeben, nicht beim Entwurf |
| FA-5.5 | Die Nummer wird beim Ausstellen **in derselben Transaktion** gezogen, in der die Rechnung gespeichert wird; ein Abbruch hinterlässt keine Lücke, zwei gleichzeitige Ausstellungen erhalten verschiedene Nummern |
| FA-5.5a | Der Schreibschutz gestellter Rechnungen gilt auch in der Datenschicht: `InvoiceRepository.save` lehnt das Überschreiben einer gestellten Rechnung ab |
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

### 5.5a Datensicherung

| ID | Anforderung |
|---|---|
| FA-7.1 | Vollsicherung aller Tabellen (konsistenter Schnappschuss per `VACUUM INTO`) und aller Belegfotos in **eine Datei** `Sicherung_JJJJ-MM-TT_HHMM.jbbackup` |
| FA-7.2 | Verschlüsselung AES-256-GCM, Schlüssel per Argon2id aus einem Kennwort der Nutzerin (19 MiB, 2 Durchläufe, Parallelität 1); Kennwort mindestens 10 Zeichen, zweimal einzugeben. Dateiformat siehe `lib/services/backup/backup_crypto.dart` |
| FA-7.3 | Ablage über den Teilen-Dialog: die Nutzerin wählt iCloud Drive, Google Drive, Dateien oder ein anderes Ziel. Kein Server des Anbieters, keine automatische Übertragung |
| FA-7.4 | Wiederherstellen: Datei wählen, Kennwort eingeben, **Vorschau** (Unternehmen, Datum, Anzahl Belege, Rechnungen, Kunden, Fotos), ausdrückliche Bestätigung; dann werden alle Daten und Fotos ersetzt, in einer Transaktion |
| FA-7.5 | Falsches Kennwort und veränderte Dateien werden erkannt (Authentifizierungs-Tag) und nicht eingelesen; fremde Dateien und Sicherungen einer neueren App-Version werden abgelehnt; ältere Sicherungen werden auf das aktuelle Schema migriert |
| FA-7.6 | Pfade im Archiv außerhalb von `belege/` werden verworfen |
| FA-7.7 | Erinnerung auf der Übersicht, wenn noch nie oder seit **30 Tagen** nicht gesichert wurde (`spec.backup_reminder_days`) |
| FA-7.8 | Wiederherstellung auch direkt aus der Ersteinrichtung auf einem neuen Gerät; sie wird im `audit_log` vermerkt |
| FA-7.9 | **Automatische Sicherung** (Opt-in nach Erklärseite): Ordner einmal wählen (iOS `UIDocumentPicker` + Security-Scoped Bookmark, `ios/Runner/BackupFolderChannel.swift`; Android Storage Access Framework mit dauerhafter Berechtigung, `BackupFolderChannel.kt`); Kanal `buchhaltung/backup_folder`; derselbe Kanal liefert mit `pickFile` die Datei für die Wiederherstellung (kein `file_picker`) |
| FA-7.10 | Schlüssel: 256 Bit zufällig, gespeichert über `flutter_secure_storage` (iOS `first_unlock_this_device`, nicht synchronisiert); Anzeige einmal als **Wiederherstellungscode** (Base32, 52 Zeichen in Vierergruppen), Bestätigung „aufbewahrt" Pflicht. Ausschalten löscht den Schlüssel |
| FA-7.11 | Sicherungsformat 2 (`JBBK`, Version 2, Modus 1, Nonce, Chiffrat, Tag) für Schlüssel-Sicherungen; Format 1 (Kennwort) bleibt lesbar. Wiederherstellen akzeptiert Kennwort **oder** Wiederherstellungscode |
| FA-7.12 | Fällig, wenn eingeschaltet, Ordner gewählt und seit der letzten automatischen Sicherung eine Änderung im `audit_log` steht, frühestens nach **24 Stunden** (`spec.auto_backup_min_interval_hours`); ausgelöst beim Start und bei Rückkehr in die App |
| FA-7.13 | Nach dem Schreiben: zurücklesen, SHA-256 vergleichen, entschlüsseln, entpacken. Erst dann `auto_backup_last_at` und Protokoll `auto_backup` mit Prüfsumme; sonst `auto_backup_last_error` und Banner auf der Übersicht |
| FA-7.14 | Rotation im Ordner nur für eigene Dateien `Auto-Sicherung_JJJJ-MM-TT_HHMMSS.jbbackup`: die letzten **7**, je Monat die jüngste der letzten **12** Monate, **je Kalenderjahr die jüngste dauerhaft** (`spec.auto_backup_keep_daily`, `spec.auto_backup_keep_monthly`) |
| FA-7.15 | „Sicherung prüfen" entschlüsselt die jüngste automatische Sicherung, ohne etwas zu ersetzen; Protokoll `verify` |

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

Kleinunternehmer, Umsatz unvollständig ─► angaben fehlen (außer überschritten)

Kleinunternehmer:
  Umsatz < 80 % der Grenze ────────────► ok
  Umsatz ≥ 80 % ≤ Grenze ──────────────► nähert sich
  Umsatz > Grenze (AT: Hinweis Toleranz)──┐
                                          ├─► überschritten
  Vorjahr > Vorjahresgrenze         ──┘
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
| Datensicherung | `features/backup/backup_screen.dart` | Sicherung erstellen und teilen, wiederherstellen mit Vorschau |
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
| **Automatische Sicherung nicht auf Gerät erprobt** | Ordnerwahl und Schreiben laufen über eigenen Kotlin- bzw. Swift-Code, der hier nur kompiliert (CI), nicht auf einem Gerät getestet ist. Ob die Google-Drive-App unter Android Ordner zur Auswahl anbietet, ist offen (P-B1) | vor Release |
| **Keine revisionssichere Archivierung** | Das `audit_log` schafft Nachvollziehbarkeit im Alltag, ist aber keine manipulationssichere Protokollierung im Sinne einer Verfahrensdokumentation. Die App ist die Vorerfassung; die revisionssichere Aufbewahrung findet in der Kanzlei statt | – |
| **Keine Registrierkasse** | Wer die RKSV-Grenzen (15.000 € Umsatz und 7.500 € Barumsätze) überschreitet, braucht zusätzlich eine registrierkassenpflichtige Lösung | Nicht geplant |
| **Keine E-Rechnung** | Ein PDF ist keine E-Rechnung nach EN 16931. In Deutschland gilt die Empfangspflicht seit 1.1.2025, die Versandpflicht kommt gestaffelt bis 2028 | Backlog G1 |
| **Keine Storno-/Gutschriftsrechnung** | Eine gestellte Rechnung ist gesperrt; es gibt derzeit keinen Korrekturweg innerhalb der App | Backlog F4, Sprint 2 |
| **Steuerwerte fest im Code** | Kennwerte haben kein Gültig-ab-Datum und ändern sich nur per App-Update; eine kurzfristige Gesetzesänderung erreicht die Nutzerin erst nach Store-Freigabe | Rechtsstand-Überwachung, Lastenheft L-20 und L-13.5, Stufe B |
| **Nur eine Währung** | Nur Euro. Ein Land mit anderer Währung setzt Mehrwährungsfähigkeit voraus | Backlog G7 |
| **Mengen mit zwei Dezimalstellen** | Die Mengeneingabe verarbeitet zwei Nachkommastellen, obwohl das Datenmodell drei erlaubt | – |
| **Android-APK-Build nicht lokal verifiziert** | Im Entwicklungscontainer ist `dl.google.com` per Netzwerk-Policy gesperrt, das Android SDK ließ sich nicht installieren. Analyse, Format und Tests laufen lokal; die Plattform-Builds verifiziert die CI | – |

---

## 12. Maschinenlesbare Kenndaten

> **Diese Werte prüft `test/specification_sync_test.dart` gegen den Code.**
> Wird ein Wert im Code geändert, ohne ihn hier anzupassen, schlägt der Test fehl.
> Das ist der Mechanismus, der dieses Dokument aktuell hält.

```properties
spec.schema_version = 6
spec.vat_check_interval_days = 7
spec.backup_reminder_days = 30
spec.auto_backup_min_interval_hours = 24
spec.auto_backup_keep_daily = 7
spec.auto_backup_keep_monthly = 12
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
spec.at.previous_year_limit_cents = 5500000
spec.at.small_amount_invoice_limit_cents = 40000
spec.at.retention_years = 7
spec.at.turnover_basis = brutto
spec.at.founding_year_limit_cents = none
spec.at.invoice_requires_tax_id = nein
spec.at.large_invoice_vat_id_limit_cents = 1000000
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
spec.de.turnover_basis = netto
spec.de.founding_year_limit_cents = 2500000
spec.de.invoice_requires_tax_id = ja
spec.de.large_invoice_vat_id_limit_cents = none
spec.de.vat_id_label = USt-IdNr.
spec.de.invoice_legal_ref = § 14 UStG
spec.de.small_business_legal_ref = § 19 UStG
```

Umrechnung: Beträge in Cent. `5500000` Cent = 55.000,00 €.

---

## 13. Änderungshistorie

| Version | Datum | App-Version | Änderung |
|---|---|---|---|
| 1.15 | 2026-10-10 | 0.1.0 | Prüfpunkte P-M1 bis P-M6 für den Mehrgeräte- und Mehrpersonenbetrieb ohne Server (Lastenheft L-19.12 ff.). Keine Codeänderung. |
| 1.14 | 2026-10-10 | 0.1.0 | Automatische Sicherung (FA-7.9 bis FA-7.15): Ordnerwahl je Plattform, Geräteschlüssel mit Wiederherstellungscode, Sicherungsformat 2, Fälligkeit, Probe nach dem Schreiben, Rotation 7/12/je Jahr, „Sicherung prüfen". Schema 6, neue Kennwerte, Prüfpunkte P-B1 bis P-B5, Grenze aktualisiert. |
| 1.13 | 2026-10-10 | 0.1.0 | Stammdaten und UID-Prüfung (FA-1.4 bis FA-1.4e): Steuernummer und UID optional, Rechnungspflichten je Land, Firmenbuch-/Registerangaben, Formatprüfung offline, VIES-Prüfung mit Protokoll, wöchentliche Prüfung nach Opt-in, Prüfergebnis an der Rechnung eingefroren. Schema 5, neue Kennwerte, Prüfpunkte P-U1 bis P-U4. |
| 1.12 | 2026-10-10 | 0.1.0 | Datensicherung (Abschnitt 5.5a, FA-7.1 bis FA-7.8): verschlüsselte Vollsicherung samt Fotos, Ablage über den Teilen-Dialog, Wiederherstellung mit Vorschau, Erinnerung nach 30 Tagen. Schema 4 (`last_backup_at`), neuer Bildschirm, Kennwert `spec.backup_reminder_days`. Bekannte Grenze „Kein Backup" ersetzt durch „Sicherung nur von Hand". |
| 1.11 | 2026-10-10 | 0.1.0 | Schema 3: Belegstorno statt Löschen (`receipts.cancelled_at`, FA-2.11, FA-2.12) und Gründungsjahr (`company_profile.founding_year`, FA-4.13, `spec.*.founding_year_limit_cents`). P-S2 und P-S10 aktualisiert. |
| 1.10 | 2026-10-10 | 0.1.0 | Prüfpunkte P-K1 bis P-K8 zur KI-Anbindung an Anthropic (Lastenheft L-21). Keine Codeänderung. |
| 1.9 | 2026-10-10 | 0.1.0 | Österreich: harte Grenze zur Sicherheit, Status *in Toleranz* entfällt; über 55.000 € *überschritten* mit Hinweis auf mögliche Toleranz und Steuerberatung (FA-4.4, FA-4.7). |
| 1.8 | 2026-10-10 | 0.1.0 | Österreich: Kleinunternehmergrenze auf Bruttobasis, ausgewiesene Umsatzsteuer zählt mit (FA-4.1, `spec.*.turnover_basis`); P-S1 (a) bestätigt. |
| 1.7 | 2026-10-10 | 0.1.0 | Rechtsstand-Überwachung (Lastenheft L-20) als geplante Funktion: bekannte Grenze „Steuerwerte fest im Code", Validierungspunkte P-V1 bis P-V9. P-S1 um den Widerspruch der Prüfinstanzen (brutto/netto, Toleranzregel) ergänzt. Keine Codeänderung. |
| 1.6 | 2026-10-10 | 0.1.0 | Prüfpunkt P-D8 für die Zusatzsicherung unter Windows. Keine Verhaltensänderung der App. |
| 1.5 | 2026-10-10 | 0.1.0 | Befunde der Prüfinstanzen: Nummernvergabe in derselben Transaktion wie das Speichern (FA-5.5), Schreibschutz gestellter Rechnungen in der Datenschicht (FA-5.5a), DE-Rechnungshinweis „Steuerbefreiung nach § 19 UStG", Umsatzsteuerberechnung ohne `double`. Neuer Abschnitt 14 „Prüfung in der realen Welt" als einzige Sammelstelle für reale Prüfpunkte. |
| 1.4 | 2026-10-10 | 0.1.0 | O-1 erledigt: Vorjahresgrenze Österreich 55.000 € ohne Toleranz (`spec.at.previous_year_limit_cents`). FA-4.6 gilt für beide Länder, Warnhinweis in 5.4 entfernt. |
| 1.3 | 2026-10-09 | 0.1.0 | O-19 behoben: Eröffnungswerte für den Umsatz (Tabelle `opening_turnover`, Spalte `tracking_start`, Schema 2), neuer Status *Angaben fehlen* der Grenzwertüberwachung. FA-1.8, FA-1.9, FA-4.9 bis FA-4.12 neu. |
| 1.2 | 2026-10-09 | 0.1.0 | Zweiter bekannter Fehler dokumentiert: der Vorjahresumsatz wird ausschließlich aus erfassten Belegen ermittelt und ist für neue Nutzer null. In Abschnitt 5.4 und in den bekannten Grenzen vermerkt. Keine Code- oder Kennwertänderung. |
| 1.1 | 2026-10-09 | 0.1.0 | Offener Prüfpunkt zur österreichischen Vorjahresgrenze in Abschnitt 5.4 vermerkt. Verweis auf das neue Lastenheft ergänzt. Keine Code- oder Kennwertänderung. |
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

---

## 14. Prüfung in der realen Welt

**Einzige Stelle** für alles, was eine echte Fachperson, ein Amt oder ein echtes
Gerät bestätigen muss (Oberstes Gesetz in [`CLAUDE.md`](../CLAUDE.md)). Andere
Dokumente verweisen nur auf die ID. Die Vorbefunde stammen von den drei
Prüfinstanzen (Rechtsanwalt, Steuerberater, Softwareentwickler) vom 2026-10-10.
Diese konnten amtliche Quellen nicht abrufen; die Befunde stützen sich auf
Fachwissen und Sekundärquellen. **Ein Vorbefund ist keine Bestätigung.**

Status: *offen* · *bestätigt* (mit Datum und Prüfer) · *widerlegt* (mit Folge)

### Rechtsanwältin / Rechtsanwalt

| ID | Prüfpunkt | Vorbefund der Prüfinstanz | Benötigt vor | Status |
|---|---|---|---|---|
| P-R1 | Impressum und Offenlegung für Produktseite und App | § 5 ECG und § 25 Abs 5 MedienG (AT, „kleine Website"); § 5 DDG greift über das Herkunftslandprinzip nur mittelbar; Verbraucherschlichtungshinweis prüfen; ODR-Link entfallen seit 07/2025 | Produktseite | offen |
| P-R2 | Rabatt- und Streichpreiswerbung für Store-Abos | 30-Tage-Regel (§ 11 PAngV, § 9a PrAG) für Dienstleistungen streitig; Irreführungsverbot gilt immer; ohne vorher verlangten Listenpreis nur „Einführungspreis bis …" | erste Werbung | offen |
| P-R3 | BFSG (DE) / BaFG (AT) | voraussichtlich nicht anwendbar (B2B, Kleinstunternehmen); Unternehmensgröße bestätigen | vor Stufe B | offen |
| P-R4 | Tragweite der Bestätigung „keine Steuerberatung" und Haftungsbegrenzung in den AGB | begrenzt wirksam; Vorsatz, grobe Fahrlässigkeit, Personenschäden nicht ausschließbar | Release | offen |
| P-R5 | Abgrenzung zur Hilfeleistung in Steuersachen (StBerG, WTBG) bei UVA-Übermittlung und ESt-Vorbereitung | zulässig als Werkzeug, Übermittlung nur im Namen und mit Zugang der Nutzerin; keine Einzelfallempfehlung | Stufe B | offen |
| P-R6 | DSGVO: Datenschutzerklärung, Verzeichnis, TOM, Datenpannenprozess; ab Stufe C AVV und Unterauftragsverarbeiter | Rollen laut Lastenheft L-19 im Kern richtig, um Anbieter- und Store-Daten ergänzt | Release / Stufe C | offen |
| P-R7 | Markenrecherche „Jenny Bar" / „Jenni bucht" (TMview, Klassen 9, 35, 36, 42) | eine Websuche ohne Kollision — **keine** Recherche; „Jenni bucht" teilweise beschreibend | Store-Eintrag | offen |
| P-R8 | Rechtsform, Haftung, Versicherung des Anbieters | Einzelunternehmen haftet persönlich | Release | offen |
| P-R9 | AI Act Art. 50 (Kennzeichnung KI-Inhalte) und Urheberrecht im Marketing-Modul; Produkthaftungsrichtlinie (EU) 2024/2853 | Pflichten wahrscheinlich | Stufe C | offen |

### Steuerberaterin / Steuerberater

| ID | Prüfpunkt | Vorbefund der Prüfinstanz | Benötigt vor | Status |
|---|---|---|---|---|
| P-S1 | AT Kleinunternehmer: (a) brutto oder netto? (b) Gilt die Toleranz **unbeschränkt oder nur einmal in 5 Jahren?** (c) Welche Umsätze zählen nicht (Hilfsgeschäfte, bestimmte steuerfreie Umsätze)? | (a) **bestätigt vom Auftraggeber am 2026-10-10: brutto** — ohne Steuerausweis gleich netto, ausgewiesene Umsatzsteuer zählt mit; umgesetzt (FA-4.1). (b) **entschieden vom Auftraggeber am 2026-10-10:** App rechnet mit der harten Grenze, Toleranz nur als Warnung mit Verweis an die Steuerberatung (FA-4.4); damit für die App ohne Bedeutung. (c) App zählt alle Einnahmen | **sofort** (c) | teilweise bestätigt |
| P-S2 | DE Gründungsjahr: Grenze 25.000 € statt 100.000 € im laufenden Jahr | seit Spezifikation 1.11 im Code (FA-4.13, Schema 3) | Release | offen |
| P-S3 | DE Zuordnung des Umsatzes nach Zahlungseingang statt Belegdatum | Abweichung möglich über den Jahreswechsel | Stufe B | offen |
| P-S4 | AT ermäßigter Satz 4,9 % für Grundnahrungsmittel ab 1.7.2026 | angekündigt, Beschluss unbekannt; nicht im Code | sofort | offen |
| P-S5 | DE Aufbewahrung: 8 Jahre Belege, 10 Jahre Bücher; AT 7 Jahre, 22 Jahre Grundstücke | Code führt nur eine Frist je Land; Löschung findet nicht statt | vor Löschfunktion | offen |
| P-S6 | AT E-Rechnung B2B | keine nationale Pflicht bekannt | Stufe B | offen |
| P-S7 | UVA-Schwellen und Befreiungen AT/DE, DE-Neugründerregel ab 2027 | AT-Befreiungsgrenze ab 2025 unsicher | Stufe B | offen |
| P-S8 | Rechnungshinweis DE Kleinunternehmer | „Steuerbefreiung nach § 19 UStG (Kleinunternehmer)" empfohlen; seit Spezifikation 1.5 im Code | Release | offen |
| P-S9 | AT Rechnung über 10.000 € brutto braucht UID des Empfängers | Prüfung im Formular fehlt | Release | offen |
| P-S10 | GoBD/BAO: Unveränderbarkeit, Verfahrensdokumentation, RKSV-Abgrenzung bei Bareinnahmen | Belege werden seit Spezifikation 1.11 storniert statt gelöscht (FA-2.11); Unveränderbarkeit des `audit_log` und Verfahrensdokumentation offen | Release | offen |

### Rechtsstand-Überwachung (Validierung, Lastenheft L-20)

| ID | Prüfpunkt | Vorbefund der Prüfinstanz | Benötigt vor | Status |
|---|---|---|---|---|
| P-V1 | Rückspieltest des Agenten gegen historische Änderungen (DE 16/5 % 2020, AT 5 % 2020/21, KU-Reformen 2025): alle erkannt, kein Vorschlag ohne gültiges Zitat | — | erstes Paket | offen |
| P-V2 | Vollständiger Probelauf mit der echten Steuerberaterin vom Vorschlag bis zur Anwendung auf einem Testgerät | — | erstes Paket | offen |
| P-V3 | Schlüsselzeremonie: Signaturschlüssel offline erzeugen, Reserveschlüssel, Notfall-Rotation einmal üben | — | erstes Paket | offen |
| P-V4 | Fehlertests auf echten Geräten: manipuliertes, unsigniertes, älteres, abgelaufenes, unplausibles Paket; Flugmodus über einen Stichtag | — | Release Stufe B | offen |
| P-V5 | Vertrag mit der Steuerberaterin (Freigabe für den Anbieter, Haftung, Versicherung, Vertretung) und Angebot zu den laufenden Kosten (O-27) | — | Stufe B | offen |
| P-V6 | AGB-Klausel zu Aktualisierungen und Haftungsbegrenzung; keine Werbung mit „immer aktuell" | Haftung für Rechenfehler nicht über den Steuerhinweis ausschließbar | Stufe B | offen |
| P-V7 | Datenschutz des Paketabrufs: EU-Hosting, Protokollkonfiguration des CDN, Datenschutzerklärung, Store-Angaben | IP-Adresse ist personenbezogen; Anbieter ist Verantwortlicher | Stufe B | offen |
| P-V8 | Nutzungsbedingungen und Text-und-Data-Mining-Vorbehalte aller beobachteten Quellen; RIS-OGD mit CC-BY-Nennung | amtliche Texte gemeinfrei, Datenbanken teils geschützt | Stufe B | offen |
| P-V9 | Feed-Adressen der amtlichen Quellen technisch prüfen (RIS, recht.bund.de, BMF, Findok, DIP) | — | Stufe B | offen |

### KI-Anbindung an Anthropic (Lastenheft L-21)

| ID | Prüfpunkt | Vorbefund der Prüfinstanz | Benötigt vor | Status |
|---|---|---|---|---|
| P-K1 | Ist Anthropic, PBC unter dem EU-US Data Privacy Framework zertifiziert? (dataprivacyframework.gov) Prüfdatum festhalten | unbekannt; sonst Standardvertragsklauseln aus dem DPA plus Transfer-Folgenabschätzung | Umschaltung | offen |
| P-K2 | Aktuelle Fassungen von Commercial Terms, DPA und Zero-Data-Retention-Bedingungen: Aufbewahrungsdauer, kein Training mit API-Daten, Unterauftragsverarbeiter | nach Kenntnisstand ca. 30 Tage Aufbewahrung, kein Training; zu verifizieren | Umschaltung | offen |
| P-K3 | Anwältin gibt Auftragsverarbeitungskette, Transfer-Folgenabschätzung und Datenschutzerklärung für Marketing-Modul und Rechtsstand-Agent frei | DSGVO verlangt keine EU-Verarbeitung bei abgesichertem Transfer | Umschaltung | offen |
| P-K4 | Steuerberatung bestätigt: flüchtige KI-Verarbeitung ohne Speicherung ist kein „Führen der Bücher" im Ausland (§ 146 Abs 2 AO, § 131 BAO) | beide Prüfinstanzen: kein Verlagerungsantrag nötig, solange Ablage auf dem Gerät | vor KI-Belegerkennung | offen |
| P-K5 | Datenschutz-Folgenabschätzung (Schwellwertprüfung) und Verfahrensdokumentation für eine KI-Belegerkennung | hohes Risiko; Erkennung auf dem Gerät bevorzugt | vor KI-Belegerkennung | offen |
| P-K6 | Preise, Websuche-Gebühren, Nutzungsstufen, Rate Limits und SLA-Lage auf docs.claude.com / anthropic.com verifizieren; Kostenannahmen mit Messdaten aus dem Probebetrieb ersetzen | Annahmen: Agent 30–60 USD/Monat, Marketing 250–350 USD je 1.000 Pro-Nutzerinnen | Umschaltung | offen |
| P-K7 | Funktioniert Workload Identity Federation mit dem gewählten Hosting (GitHub Actions, Backend)? | — | Umschaltung | offen |
| P-K8 | Ausfalltest: Backend bei gesperrter KI-Anbindung (Warteschlange, Ausweichmodell, Meldung in der App); Buchhaltung im Flugmodus voll nutzbar | — | Launch Marketing-Modul | offen |

### Softwareentwicklung (echte Geräte und Stores)

| ID | Prüfpunkt | Vorbefund der Prüfinstanz | Benötigt vor | Status |
|---|---|---|---|---|
| P-D1 | Update einer echten v1-Installation auf Schema 2 und folgende | Upgrade-Test mit ffi vorhanden; echtes Gerät fehlt | Release | offen |
| P-D2 | PDF mit Umlauten, CSV in Excel/Numbers | nicht verifiziert | Release | offen |
| P-D3 | Datensicherung und Wiederherstellung über iCloud Drive / Google Drive | noch nicht gebaut | Release | offen |
| P-D4 | Abo-Testkäufe in Sandbox beider Stores (Test, Basis/Pro, Angebote, Jahresabo, Offline-Lizenz) | noch nicht gebaut | Stufe B | offen |
| P-D5 | iOS Privacy Manifest, Data-Safety- und Privacy-Label-Angaben inkl. aller SDKs | Manifest fehlt | erster Upload | offen |
| P-D6 | Android targetSdk-Vorgabe 2026, Signing, Bundle-ID `at.jesenko.buchhaltung` endgültig | Bundle-ID personenbezogen, nach Release unveränderlich | erster Upload | offen |
| P-D7 | Kamera, Fotoablage, Spracheingabe auf echten Geräten | — | Release | offen |
| P-U1 | VIES-Schnittstelle live auf echten Android- und iOS-Geräten: gültige, ungültige Nummer, Ausfall eines Mitgliedstaats; Abfragenummer kommt zurück | Endpunkt und Antwortformat aus Fachwissen, nicht live getestet | Release | offen |
| P-U2 | Nachweiswert von VIES mit Abfragenummer gegenüber FinanzOnline Stufe 2 (AT) und qualifizierter Bestätigungsabfrage § 18e UStG (DE) | VIES schwächer, aber als Hilfsnachweis anerkannt | Release | offen |
| P-U3 | Steuernummer auf österreichischen Rechnungen nicht nötig; DE Steuernummer oder USt-IdNr. genügt | beide Prüfinstanzen | Release | offen |
| P-U4 | Datenschutzerklärung und Store-Formulare (Google Data Safety, Apple Label) zur VIES-Abfrage durch Fachperson | Nutzerin Verantwortliche, Kommission Empfängerin, Anbieter unbeteiligt | erster Upload | offen |
| P-B1 | Android: bietet die Google-Drive-App bei der Ordnerwahl (Storage Access Framework) Ordner an? Test auf Pixel und Samsung mit aktueller Drive-App. Wenn nein: Entscheidung über Anbindung der Drive-Schnittstelle | Drive bot lange keine Ordner an; unsicher | vor Release | offen |
| P-B2 | iOS: Bookmark auf einen iCloud-Drive-Ordner nach Neustart, Update und offline; Upload durch das System | — | vor Release | offen |
| P-B3 | Laufzeit einer großen Sicherung (viele Fotos) beim Öffnen der App; Verhalten bei Wechsel in den Hintergrund | — | vor Release | offen |
| P-B4 | Steuerberatung: verschlüsselte Sicherungskopie in einer US-Cloud neben den Originaldaten am Gerät ist kein „Führen der Bücher im Ausland“ (§ 146 Abs 2a/2b AO, § 131 BAO); Fristen nach BEG IV (8/10 Jahre) | beide Instanzen: nach h. M. unkritisch, kippt wenn die Cloud-Kopie die einzige wird | Release | offen |
| P-B5 | Store-Angaben zur automatischen Sicherung (gehört zu P-U4) | keine Erhebung durch den Anbieter | erster Upload | offen |
| P-M1 | Steuerberatung AT bestätigt Nummernkreise je Gerät/Person mit Präfix (UStR Rz 1565); DE nach UStAE 14.5 Abs 10 | Prüfinstanzen: zulässig, wenn Präfix fest und dokumentiert | Stufe C | offen |
| P-M2 | Steuerberatung: Ordnungsmäßigkeit, wenn Buchhaltungsdaten im (privaten) Cloud-Konto liegen; § 131 Abs 1 BAO bei Ablage außerhalb Österreichs; Umgang mit doppeltem Storno | — | Stufe C | offen |
| P-M3 | Arbeitsrecht AT: § 96/96a ArbVG bei Erfasser-Kennung mit Zeitstempel; DE § 87 BetrVG | Erfasser-Vermerk ohne Auswertung berührt Menschenwürde in der Regel nicht | Stufe C | offen |
| P-M4 | Verhalten von iCloud-Freigabeordnern, Google Drive, OneDrive, Nextcloud bei Synchronisierung (Verzögerung, ausgelagerte Dateien, Konfliktkopien, Umbenennen) auf echten Geräten, auch gemischt iOS/Android | hohes Risiko | Stufe C | offen |
| P-M5 | Externes Sicherheitsreview der Schlüsselverteilung (X25519, Ed25519, AES-GCM, Schlüsselwechsel) vor Release | — | Release Stufe C | offen |
| P-M6 | Anwältin: Mustertext Art. 13 für Beschäftigte, Haftung und Formulierung „kein harter Zugriffsschutz“ | — | Stufe C | offen |
| P-D8 | Zusatzsicherung unter Windows (`tool/sicherung/sicherung.ps1`): Erstlauf, Aufgabenplanung, Wiederherstellung | Linux-Variante getestet, Windows-Skript nie ausgeführt | sofort | offen |
