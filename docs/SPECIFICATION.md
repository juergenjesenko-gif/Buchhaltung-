# Spezifikation – Buchhaltung

**Dokumentversion:** 1.38 · **App-Version:** 0.3.4 · **Stand:** 2026-10-14
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

**Gültigkeitsbeginn eines Satzes:** Ein `VatRate` kann ein `validFrom` tragen.
Vorher wird er weder in Auswahllisten angeboten noch aus der Belegerkennung
vorbelegt (`TaxProfile.vatRatesOn`, Stichtag Leistungs- bzw. Belegdatum); ein
bereits gespeicherter Satz bleibt anzeigbar. Österreich 4,9 % für
Grundnahrungsmittel nach § 10 Abs 1a UStG 1994 iVm Anlage 3 gilt für
Leistungen ab 1.7.2026 (`spec.at.vat_49_valid_from`, Prüfpunkt P-S28).

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
Das PDF einer gestellten Rechnung nimmt **alle** Absenderangaben (Name,
Anschrift, Steuernummer, UID, Firmenbuch, Bank, Fußzeile, Logo) aus
`seller_snapshot` (`InvoiceSeller`, `InvoiceLogo`); Entwürfe nutzen das
aktuelle Profil. Rückfall für alte Rechnungen: fehlt der Snapshot oder ist er
unlesbar, gilt das aktuelle Profil; fehlt ein einzelnes Feld (Snapshot aus
einer älteren Schemaversion), gilt für dieses Feld der aktuelle Wert – außer
beim Logo, das dann fehlt. Die Steuerbehandlung steht in
`invoices.is_small_business`.

### GR-9 · Fremdwährung: Kurs als Ganzzahl, Umsatzsteuer und Bank getrennt

Nur Eingangsbelege (Ausgaben) dürfen in fremder Währung sein; Ausgangsrechnungen
bleiben Euro (Lastenheft L-13.3). Der Kurs wird als **Einheiten der fremden
Währung je 1 Euro × 10^6** gespeichert (`spec.fx_rate_scale`), so wie EZB und
BMF notieren – er wird nie invertiert. Beträge in fremder Währung stehen in
Hundertsteln der Einheit, auch bei Währungen ohne Nachkommastellen.
Umrechnung: `euroCent = round_half_up(original × 10^6 / kurs)`, ausschließlich
Ganzzahlen (`CurrencyConverter`). Der Euro-Betrag ist das Brutto des Belegs; GR-2
gilt danach unverändert, die Steuer ist Restgröße.

Zwei Euro-Werte bleiben getrennt: `gross_cents` (zum Umsatzsteuer-Kurs, Basis
für Vorsteuer und UVA, § 20 Abs 6 UStG AT, § 16 Abs 6 UStG DE –
`TaxProfile.fxRateLegalRef`) und `bank_gross_cents` (tatsächlich abgebucht,
überschreibt nur in der Einnahmen-Ausgaben-Rechnung, L-2.26). Die Differenz
wirkt als Kursdifferenz auf das Ergebnis, nie auf die Vorsteuer.

---

## 4. Datenmodell

**Speicher:** SQLite auf dem Gerät, Datei `buchhaltung.db` im
Anwendungsdokumentenverzeichnis. Aktuelle Schemaversion: **10**
(`spec.schema_version`). Bilder liegen als Dateien daneben: Belegseiten in
`belege/`, Firmenlogos in `logo/`.

### 4.1 Tabellen

| Tabelle | Zweck | Besonderheit |
|---|---|---|
| `company_profile` | Firmenstammdaten | Genau eine Zeile, erzwungen durch `CHECK (id = 1)` |
| `categories` | Buchhaltungskategorien | 16 Startkategorien, `is_system = 1` schützt vor Löschen |
| `customers` | Rechnungsempfänger | Löschen blockiert, solange Rechnungen bestehen |
| `receipts` | Belege | Index auf `date` und `direction`. Werden nie gelöscht, nur storniert (`cancelled_at`) |
| `receipt_pages` | Seiten (Fotos) eines Belegs: `receipt_id`, `position` ab 1, `image_path`, `created_at` | Schema 8. Nach dem Speichern nur Anhängen; bestehende Einzelfotos wurden bei der Migration zur Seite 1 |
| `receipt_comments` | Kommentare zu Belegen: `receipt_id`, `text`, `created_at` (Systemzeit) | Schema 8. Nur Einfügen; ein Trigger verhindert `UPDATE`. Löschen bietet die App nicht an (die Wiederherstellung leert alle Tabellen) |
| `invoices` | Ausgangsrechnungen | `UNIQUE INDEX` auf `number` |
| `invoice_items` | Rechnungspositionen | `ON DELETE CASCADE` |
| `audit_log` | Änderungsprotokoll | Nur Einfügen, kein Löschen durch die App |
| `consents` | Bestätigte Texte: Art, Fassung, Zeitpunkt | Nur Einfügen (Schema 7) |
| `vat_id_checks` | Protokoll der UID-Abfragen: UID, Ergebnis, Zeitpunkt, Name/Anschrift laut VIES, Abfragenummer, Fehlercode | Nur Einfügen (Schema 5) |
| `ecb_rates` | Abgerufene EZB-Referenzkurse: `date`, `currency`, `rate_micros` (Einheiten je 1 € × 10^6), `fetched_at` | Schema 10. Schlüssel (`date`, `currency`); nur durch „Kurs abrufen“ befüllt |
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
| `logo_path` | TEXT | Relativer Pfad des Firmenlogos in `logo/`, `NULL` = kein Logo (Schema 8, FA-1.12) |
| `last_backup_at` | TEXT | Zeitpunkt der letzten Datensicherung bzw. der wiederhergestellten Sicherung; nur vom Sicherungsdienst geschrieben (Schema 4) |

**`receipts`** — zusätzlich seit Schema 3: `cancelled_at` (TEXT, Zeitpunkt der Stornierung, `NULL` = gültig). Seit Schema 9: `document_number` (TEXT, Rechnungsnummer des Ausstellers), `issuer_vat_id` (TEXT, UID des Ausstellers), `currency` (TEXT, ISO 4217, Standard `EUR`), `original_gross_cents` (INTEGER, Betrag laut Beleg in fremder Währung, sonst `NULL`). `net_cents`, `vat_cents`, `gross_cents` sind immer Euro (FA-2.21). Seit Schema 10 (FA-2.24): `fx_rate_micros` (INTEGER, Kurs je 1 € × 10^6), `fx_rate_date` (TEXT, `YYYY-MM` beim Monatskurs, sonst `YYYY-MM-DD`), `fx_rate_source` (TEXT: `bmf_monthly`, `ecb_monthly_avg`, `ecb_daily`, `manual`, `bank`), `bank_gross_cents` (INTEGER, tatsächlich abgebuchter Euro-Betrag, `NULL` = wie `gross_cents`)

**`company_profile`** — seit Schema 9: `receipt_scan_enabled` (INTEGER, Standard 1, FA-2.23). Seit Schema 10: `fx_daily_rate_approved` (INTEGER, Standard 0, Tageskurs vom Finanzamt genehmigt, FA-2.25)


| Feld | Typ | Bedeutung |
|---|---|---|
| `date` | TEXT | Belegdatum, `YYYY-MM-DD` |
| `direction` | TEXT | `income` oder `expense` |
| `description` | TEXT | Pflicht in der Eingabemaske |
| `net_cents`, `vat_cents`, `gross_cents` | INTEGER | Beträge in Cent, es gilt GR-2 |
| `vat_permille` | INTEGER | Angewandter Steuersatz, siehe GR-3 |
| `payment_method` | TEXT | `cash`, `bank`, `card`, `other` |
| `image_path` | TEXT | **Relativer** Pfad, siehe NFA-4. Seit Schema 8 Spiegel der ersten Seite aus `receipt_pages` |

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
| FA-1.10 | **Bestätigungen vor der ersten Nutzung** (L-17.1 bis L-17.4): „Keine Steuerberatung“ und „Nutzungsbedingungen/Datenschutz“, je eigenes, nicht vorausgewähltes Häkchen; erst danach Ersteinrichtung bzw. Wiederherstellung. Gespeichert in `consents` mit Art, Textfassung und Zeitpunkt; eine neue Fassung in `LegalText` wird erneut abgefragt. **Keine Einwilligung für Werbung**, da keine Daten dafür erhoben werden |
| FA-1.12 | **Firmenlogo** (Lastenheft L-1.7, L-1.9): Auswahl aus der Fotobibliothek in den Stammdaten, verkleinert auf höchstens 800 px Kantenlänge bei 90 % Qualität (`spec.logo_max_edge_px`, `spec.logo_quality_percent`), abgelegt als **neue** Datei in `logo/`; Entfernen möglich. Logodateien werden nie überschrieben oder gelöscht. Das Logo steht im PDF oben rechts **zusätzlich** zu Name und Anschrift, nie an ihrer Stelle. Es wird mit dem `seller_snapshot` bei der Rechnungslegung eingefroren: gestellte Rechnungen zeigen das damalige Logo (Rechnungen vor Schema 8 keines), Entwürfe das aktuelle (`InvoiceLogo`). Der `seller_snapshot` eines Entwurfs wird bei jedem Speichern erneuert, ab dem Ausstellen nicht mehr. Ein unlesbares Bild verhindert das PDF nicht |
| FA-1.11 | Kennwort- und Code-Felder haben ein Auge-Symbol zum Anzeigen (`PasswordField`) |

**Pflichtangaben für Rechnungsfähigkeit** (`CompanyProfile.missingInvoiceFields`):
Firmenname, Straße, PLZ, Ort; in Deutschland Steuernummer **oder** USt-IdNr.;
bei gesetzter Registernummer das Registergericht. Betragsabhängige Angaben
prüft `InvoiceRequirements` (FA-1.4).

### 5.2 Belege

| ID | Anforderung |
|---|---|
| FA-2.1 | Beleg per Kamera aufnehmen oder aus der Fotobibliothek wählen; **mehrere Seiten je Beleg** (FA-2.13) |
| FA-2.2 | Jede Seite wird bei der Aufnahme auf maximal 2000 × 2000 px bei 85 % Qualität reduziert und danach nie mehr verändert. Eine Bildverbesserung gibt es nicht; käme sie, dann nur als Kopie |
| FA-2.3 | Betrag wird **brutto** eingegeben; Netto und Umsatzsteuer werden live angezeigt |
| FA-2.4 | Betrag 0 und negative Beträge werden abgelehnt; die Richtung steuert das Vorzeichen |
| FA-2.5 | Die Beschreibung ist Pflichtfeld |
| FA-2.6 | Belegdatum wählbar, maximal bis heute, rückwärts über die Aufbewahrungsfrist |
| FA-2.7 | Kategorien sind richtungsabhängig; ein Wechsel der Richtung setzt die Kategorie neu |
| FA-2.8 | Ist Kleinunternehmer aktiv und ein Satz > 0 gewählt, warnt die App |
| FA-2.9 | Liste gruppiert nach Monat, Suche über Beschreibung, Partner und Notiz |
| FA-2.10 | Filter Alle/Einnahmen/Ausgaben, Jahresauswahl über die Aufbewahrungsfrist |
| FA-2.11 | Bearbeiten möglich. **Belege werden nicht gelöscht, sondern storniert** (nach Rückfrage): sie bleiben samt Foto gespeichert, erscheinen in keiner Liste und zählen in keiner Auswertung, keinem Export und nicht zur Umsatzgrenze (Aufbewahrungspflicht § 132 BAO, § 147 AO; GoBD) |
| FA-2.12 | Anlegen, Ändern und Stornieren werden im `audit_log` protokolliert, mit Seitenzahl |
| FA-2.13 | **Mehrseitige Belege** (L-2.15): weitere Seiten fotografieren oder wählen; vor dem ersten Speichern Reihenfolge ändern (nach vorne/hinten) und einzelne Seiten löschen (Datei wird entfernt). Wird die Erfassung ohne Speichern verlassen, löscht die App die neu aufgenommenen Dateien. Nach dem Speichern sind Seiten fest: nur Anhängen, kein Löschen oder Umsortieren – erzwungen in `ReceiptRepository.save` |
| FA-2.14 | **Vollständigkeitsbestätigung** (L-2.16): sind neue Seiten hinzugekommen, verlangt das Speichern das Häkchen „Alle Seiten inkl. beschriebener Rückseiten erfasst“ |
| FA-2.15 | Belegansicht zeigt alle Seiten als Leiste mit Seitennummer; Antippen öffnet die Seite vergrößert (Zoom) |
| FA-2.16 | **Kommentare** (L-2.17): beim Erfassen ein Kommentarfeld, das beim Speichern zum ersten Kommentar wird; bei gespeicherten, auch stornierten Belegen „Kommentar anhängen“. Zeitstempel ist die Systemzeit. Kein Bearbeiten, kein Löschen; Korrektur nur als neuer Kommentar. Jeder Kommentar erzeugt einen `audit_log`-Eintrag `comment`. Der Beleg selbst bleibt unverändert |
| FA-2.17 | **Diktat** (L-2.18) nur über die Diktierfunktion der Systemtastatur; die App enthält keine Spracherkennung und überträgt nichts. Hinweis im Formular: je nach Gerät kann die Tastatur Sprache an Google oder Apple senden |
| FA-2.19 | **Belege automatisch auslesen** (Lastenheft L-2.20): nach dem Hinzufügen einer Seite erkennt die App den Text **aller Seiten** auf dem Gerät (Android: Google ML Kit Text Recognition Latin, gebündeltes Modell; iOS: Apple Vision `VNRecognizeTextRequest`) über den Channel `buchhaltung/receipt_text` und die Schnittstelle `ReceiptTextRecognizer`. Der Parser `lib/services/receipt_scan/` ermittelt Belegdatum, Bruttobetrag, Umsatzsteuer je Satz (Sätze aus allen `TaxProfile`s, eigenes Land zuerst), Netto, Händler, Aussteller-UID (Prüfung mit `VatIdFormat`, eigene UID übergangen), Rechnungsnummer und Währung, je mit Konfidenz 0–100. Beträge ganzzahlig in Cent; je Satz gilt `net + vat == gross`. Nur bei neuen Belegen wird automatisch vorbelegt, Felder unter Konfidenz 40 bleiben leer. Vorbelegte Felder tragen „erkannt – bitte prüfen“; gebucht wird erst beim Speichern. Das Originalbild bleibt unverändert. „Erneut auslesen“ startet die Erkennung von Hand |
| FA-2.28 | **Auslesen echter Belege** (Stufe 1, Korpus `test/fixtures/belege/`): Zeilen werden über die Lage zu Bildzeilen zusammengeführt, auch bei schräg gehaltenem Beleg (Abweichung bis ¾ Zeilenhöhe, nicht bei untereinander stehenden Zeilen gleicher Einrückung). Schlüsselwörter für den Bruttobetrag zusätzlich „Beløb“, „I alt“; ein Betrag ohne Nachkommastellen allein in der Zeile nach dem Schlüsselwort zählt (Konfidenz 60). „685, 88“ wird als 685,88 gelesen. Datum auch TT-MM-JJJJ. Rechnungsnummer auch „Rechnung 37549“. Dänische CVR-Nummer wird als UID `DK…` gelesen. Enthaltene Steuer ohne Prozentangabe („HERAF MOMS 137,18“) ergibt den Satz aus Brutto und Steuer, wenn er einem EU-Satz entspricht. Währung „$“ allein bzw. „kr“ allein ist mehrdeutig (Konfidenz 30): kein Betrag im Euro-Feld, Hinweis zur Währung |
| FA-2.29 | **Ausländische Umsatzsteuer** bei Ausgaben: erkannter Satz, den das eigene Land nicht kennt, oder Aussteller-UID aus einem anderen Staat → Steuersatz 0 % vorbelegt mit Hinweis „nicht als Vorsteuer abziehbar“ und dem länderspezifischen Text `TaxProfile.foreignVatHint` (AT: EU-Vorsteuer-Erstattung über FinanzOnline; DE: Vorsteuer-Vergütung beim BZSt; Frist 30.09. des Folgejahres, Mindestbetrag 50 €/400 €, nicht für Kleinunternehmer) (§ 12 Abs. 1 Z 1 UStG 1994, § 15 Abs. 1 Nr. 1 UStG; Prüfpunkte P-S27, P-S30). Seit 0.3.4 gilt als ausländisch: Aussteller-UID aus einem anderen Staat oder ein Satz, den nur ein anderes Länderprofil kennt. Bei Kleinunternehmern belegt die App den erkannten Satz unverändert vor und zeigt den bestehenden Hinweis, dass die Vorsteuer nicht abziehbar ist; sie setzt nicht selbst 0 % |
| FA-2.30 | **Mehrsprachige Erkennung** (0.3.4): Schlüsselwörter für Brutto, Netto, Steuer, Datum, „nicht Belegdatum“ und Rechnungsnummer stehen als Tabellen in `receipt_keywords.dart` für DE, EN, SL, HR, IT, HU, CS, SK, PL, FR, ES, NL, DK, SE, NO (z. B. Skupaj, Ukupno, Totale, Összesen, Celkem, Razem, Totaal, I alt, Summa, Totalt; DDV, PDV, IVA, ÁFA, DPH, PTU, VAT, BTW, MOMS, MVA, TVA, MwSt, USt). Kurze Einträge nur als ganzes Wort. Satz auch nach dem Prozentzeichen („DDV % 22,0“) und mit Dezimalstelle („4,90 %“); die Satzangabe zählt nicht als Betrag. Ein Satz außerhalb der Profile und EU-Sätze gilt nur mit Rechenprobe (Netto + Steuer = Brutto bzw. Steuer zum Brutto). Steuerzeilen mit Rechenprobe gehen einem unsicheren Gesamtbetrag vor (Summe der Zeilen = Brutto), z. B. wenn „Summe“ verdeckt ist. Steuertabelle mit Kopfzeile mit „%“ und Satz ohne Prozentzeichen in der Zeile darunter („22,0  1,62  9,00“, Basis eine Zeile tiefer): Spalten über die Rechenprobe zugeordnet, weil die Kopfwörter oft entstellt sind. Ein Satz eines anderen EU-Staats gilt auch ohne lesbare Aussteller-UID als ausländisch. Datum auch mit gemischtem Trenner „05.09,2026“ und JJJJ.MM.TT.; entstellte Jahreszahl neben einem Datums-Schlüsselwort („03.10.2ULG“) ergibt das Datum im Jahr des Stichtags bzw. im Vorjahr mit Konfidenz 60. Logo-Rauschen bei bekannten Ketten („SPARO“ → SPAR), Rechtsform beendet den Händlernamen |
| FA-2.31 | **Beschreibung und Kategorie vorschlagen** (0.3.4, `ReceiptClassifier`): Branche aus bekannter Kette oder Schlüsselwörtern (Maut/Vignette, Parken, Tankstelle, Taxi, Hotel, Fahrkarte, Supermarkt, Drogerie, Büro, Elektronik, Post, Telefon, Fachliteratur). Beschreibung „Händler – Branche“, bei Handel mit bis zu drei Artikeln, höchstens 60 Zeichen; nur in ein leeres Feld. Kategorie nur aus den Startkategorien und nur, wenn eine Kategorie mit diesem Namen existiert: Maut/Parken/Treibstoff → Kfz-Kosten, Taxi/Hotel/Fahrkarte → Reisekosten, Supermarkt/Drogerie → Sonstige Ausgaben. Beide Felder „erkannt – bitte prüfen“. Neue Belege starten mit „Sonstige Ausgaben“ bzw. „Sonstige Einnahmen“ statt der alphabetisch ersten Kategorie (vorher „Bankspesen“) |
| FA-2.32 | **Beleg ohne Steuerausweis** (z. B. nur Kartenbeleg): kein Satz erkannt, Betrag erkannt, Ausgabe → 0 % („ohne Vorsteuer“) mit Hinweis aus `TaxProfile.noVatShownHint` (AT § 11 Abs 6 UStG, DE § 33 UStDV); die App erfindet keinen Satz (P-S29). Erkannter Satz, den die App nicht kennt: nicht vorbelegen, Hinweis „in der App noch nicht hinterlegt“. Satz vor seinem Gültigkeitsbeginn: nicht vorbelegen, Hinweis „gilt aber erst ab …“ |
| FA-2.20 | Formularfelder **Rechnungsnummer** und **UID des Ausstellers** (Schema 9). Mehrere Steuersätze erkannt: Hinweis mit Brutto je Satz, vorbelegt wird der Satz mit dem größten Anteil; ein Satz, den das eigene Land nicht kennt, wird nicht vorbelegt |
| FA-2.21 | **Fremdwährung** (L-2.21): nur bei Ausgaben. Erkannte Währung ≠ EUR füllt das Euro-Feld nicht, sondern schaltet das Formular auf Fremdwährung (FA-2.24) mit Betrag laut Beleg. Einnahmen bleiben immer Euro |
| FA-2.24 | **Fremdwährung umrechnen** (L-2.24): Schalter „Beleg in fremder Währung“ bei Ausgaben; Felder Währung (ISO 4217), Betrag laut Beleg, Kurs (Einheiten je 1 €, höchstens 6 Nachkommastellen), Kursquelle, Kursdatum; das Euro-Brutto wird nach GR-9 berechnet und angezeigt, Netto/Steuer nach GR-2 |
| FA-2.25 | **Kurs abrufen** (L-2.25, L-19.29): nur auf Knopfdruck lädt `EcbClient` `eurofxref-hist-90d.xml` (Beleg bis 80 Tage alt) bzw. `eurofxref-hist.xml` direkt bei der EZB, speichert alle Kurse in `ecb_rates` und nutzt danach den Speicher. Standard ist das **Mittel aller EZB-Tageskurse des Belegmonats** (half-up auf 10^-6), gekennzeichnet „EZB-Monatsmittel – Näherung an BMF-Kurs“; im laufenden Monat als vorläufig markiert. Den **Tageskurs** (letzter Kurs am oder vor dem Belegdatum) nutzt die App nur, wenn in den Einstellungen „Tageskurs vom Finanzamt genehmigt“ eingeschaltet ist. Manueller Kurs (Quelle `manual`, `bmf_monthly`, `bank`) jederzeit; ein von Hand geänderter EZB-Kurs wird zu `manual`. Hinweis „EZB-Referenzkurs, ohne Gewähr“ |
| FA-2.26 | **Bankbetrag** (L-2.26): optionales Feld „Tatsächlich abgebucht (EUR)“ (`bank_gross_cents`). `PeriodTotals.expenseFxDifference` = Σ(Bank − umgerechnet); `profit` zieht sie ab, `expensePaidGross` zeigt Ausgaben laut Bank. Vorsteuer, UVA und Umsatz bleiben beim Umsatzsteuer-Kurs |
| FA-2.27 | **Protokoll** (L-2.26): jedes Speichern eines Fremdwährungsbelegs schreibt `audit_log`-Eintrag `fx` mit Währung, Originalbetrag, Kurs, Quelle, Kursdatum, umgerechnetem Betrag und ggf. Bankbetrag mit Differenz |
| FA-2.22 | **Protokoll** (L-2.22): beim Speichern eines ausgelesenen Belegs ein `audit_log`-Eintrag `scan` mit Engine und Version, je Feld erkannter Wert mit Konfidenz, bestätigter Wert und Kennzeichen `GEÄNDERT`, sowie SHA-256 jedes Originalbilds. Keine Bilddaten, kein Volltext |
| FA-2.23 | **Abschaltbar** (L-2.23): Einstellungen → „Belege auslesen“, Standard an (`company_profile.receipt_scan_enabled`) |
| FA-2.18 | **Stornierte Belege lesbar**: Filter „Storniert“ in der Belegliste; die Ansicht ist schreibgeschützt (Hinweisbanner, kein Speichern), Kommentare bleiben anhängbar |

### 5.3 Kassabuch und Auswertung

| ID | Anforderung |
|---|---|
| FA-3.1 | Zeiträume: dieser Monat, letzter Monat, dieses Quartal, dieses Jahr, letztes Jahr |
| FA-3.2 | Anzeige von Einnahmen netto, Ausgaben netto und Ergebnis; das Ergebnis enthält Kursdifferenzen laut Bank (FA-2.26) |
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
| FA-7.6 | Pfade im Archiv außerhalb von `belege/` und `logo/` werden verworfen. Gesichert werden alle Belegseiten und alle Logodateien; Seiten und Kommentare stecken in der Datenbank. Sicherungen ohne `logo/` (vor Schema 8) bleiben lesbar und werden auf Schema 8 migriert; beim Wiederherstellen werden beide Ordner ersetzt |
| FA-7.7 | Erinnerung auf der Übersicht, wenn noch nie oder seit **30 Tagen** nicht gesichert wurde (`spec.backup_reminder_days`) |
| FA-7.8 | Wiederherstellung auch direkt aus der Ersteinrichtung auf einem neuen Gerät; sie wird im `audit_log` vermerkt |
| FA-7.9 | **Automatische Sicherung** (Opt-in nach Erklärseite): Ordner einmal wählen (iOS `UIDocumentPicker` + Security-Scoped Bookmark, `ios/Runner/BackupFolderChannel.swift`; Android Storage Access Framework mit dauerhafter Berechtigung, `BackupFolderChannel.kt`); Kanal `buchhaltung/backup_folder`; derselbe Kanal liefert mit `pickFile` die Datei für die Wiederherstellung (kein `file_picker`) |
| FA-7.10 | Schlüssel: 256 Bit zufällig, gespeichert über `flutter_secure_storage` (iOS `first_unlock_this_device`, nicht synchronisiert); Anzeige einmal als **Wiederherstellungscode** (Base32, 52 Zeichen in Vierergruppen), Bestätigung „aufbewahrt" Pflicht. Ausschalten löscht den Schlüssel |
| FA-7.11 | Sicherungsformat 2 (`JBBK`, Version 2, Modus 1, Nonce, Chiffrat, Tag) für Schlüssel-Sicherungen; Format 1 (Kennwort) bleibt lesbar. Wiederherstellen akzeptiert Kennwort **oder** Wiederherstellungscode |
| FA-7.12 | Fällig, wenn eingeschaltet, Ordner gewählt und seit der letzten automatischen Sicherung eine Änderung im `audit_log` steht, frühestens nach **24 Stunden** (`spec.auto_backup_min_interval_hours`); ausgelöst beim Start und bei Rückkehr in die App |
| FA-7.13 | Nach dem Schreiben: zurücklesen, SHA-256 vergleichen, entschlüsseln, entpacken. Erst dann `auto_backup_last_at` und Protokoll `auto_backup` mit Prüfsumme; sonst `auto_backup_last_error` und Banner auf der Übersicht |
| FA-7.14 | Rotation im Ordner nur für eigene Dateien `Auto-Sicherung_JJJJ-MM-TT_HHMMSS.jbbackup`: die letzten **7**, je Monat die jüngste der letzten **12** Monate, **je Kalenderjahr die jüngste dauerhaft** (`spec.auto_backup_keep_daily`, `spec.auto_backup_keep_monthly`) |
| FA-7.15 | „Sicherung prüfen" entschlüsselt die jüngste automatische Sicherung, ohne etwas zu ersetzen; Protokoll `verify` |

### 5.5b App-Sperre

Entscheidung der Auftraggeberin vom 2026-10-12 (Lastenheft L-22.30).
Fachlogik: `lib/services/app_lock/app_lock_service.dart`, Plattform:
`lib/services/app_lock/platform_app_lock.dart`.

| ID | Anforderung |
|---|---|
| FA-1.13 | **Optional**, Einstellungen → App-Sperre. Aus ist der Standard. Einschalten erst nach der Bestätigung, dass eine vergessene PIN nicht zurückgesetzt werden kann |
| FA-1.14 | **PIN als Pflicht-Rückfall**, **6 bis 8 Ziffern** (`spec.app_lock_pin_*`); abgelehnt werden gleiche Ziffern (`000000`) und einfache Folgen (`123456`, `876543`). Begründung: 4 Ziffern (10.000 Kombinationen) sind mit Mustern zu leicht; 6 Ziffern entsprechen NIST SP 800-63B 5.1.1 und den Vorgaben von iOS/Android. Gespeichert wird nur ein Argon2id-Hash (Parameter wie FA-7.2, Salz 16 Byte, Format `v1:Speicher:Durchläufe:Parallelität:Salz:Hash`) in `flutter_secure_storage` (iOS `first_unlock_this_device`, nicht synchronisiert), **nie in SQLite** und damit nie in einer Sicherung. Vergleich in konstanter Zeit |
| FA-1.15 | Gesperrt beim Start und bei Rückkehr nach einer einstellbaren Zeit im Hintergrund: sofort, 1 (Standard, `spec.app_lock_default_timeout_seconds`), 5 oder 15 Minuten. Die Zeit läuft ab `AppLifecycleState.hidden`; reine Inaktivität (System-Dialog, Biometrie) zählt nicht. Eine zurückgestellte Uhr sperrt sofort. Die Sperre liegt über der Navigation (`AppLockGate` im `MaterialApp.builder`), danach geht es an derselben Stelle weiter |
| FA-1.16 | **Biometrie** (Fingerabdruck, Face ID) optional über `local_auth`, nur wenn das Gerät sie anbietet; Prüfung durch das System, die App erhält nur das Ergebnis. Android: `MainActivity` erbt von `FlutterFragmentActivity`, Starttheme `Theme.AppCompat`; iOS: `NSFaceIDUsageDescription` |
| FA-1.17 | Im App-Umschalter wird der Inhalt verdeckt, solange die Sperre eingeschaltet ist: Flutter-Abdeckung ab `inactive` (beide Plattformen), zusätzlich Android 13+ `setRecentsScreenshotEnabled(false)` über Kanal `buchhaltung/app_lock`. **Kein `FLAG_SECURE`**, damit Bildschirmfotos (z. B. für den Support) möglich bleiben. Wirksamkeit: P-D17 |
| FA-1.18 | Fehlversuche: **5** ohne Wartezeit, dann **30 s**, je weiterem Fehlversuch verdoppelt bis **1 Stunde** (`spec.app_lock_free_attempts`, `spec.app_lock_backoff_*`). Zähler und Wartezeit liegen im sicheren Speicher und überstehen einen Neustart; richtige PIN oder Biometrie setzt sie zurück. Keine Datenlöschung nach Fehlversuchen. **Vergessene PIN:** kein Zurücksetzen durch den Anbieter; Weg ist App-Daten löschen bzw. neu installieren und aus der Sicherung wiederherstellen. Erklärt beim Einrichten und auf dem Sperrbildschirm; ohne vorhandene Sicherung (von Hand oder automatisch) erscheint beim Einrichten eine Warnung mit Weg zur Datensicherung. Ausschalten und PIN ändern nur mit der aktuellen PIN |

### 5.5c App-Symbol auf dem Startbildschirm

Bei einer Installation per APK legt Android kein Symbol auf den Startbildschirm.
Eine App darf es nicht stumm ablegen; zulässig ist nur
`ShortcutManager.requestPinShortcut` (Android 8+) mit Systemdialog.
Fachlogik: `lib/services/launcher/home_shortcut_service.dart`, Plattform:
`lib/services/launcher/platform_home_shortcut.dart`, `LauncherChannel.kt`.

| ID | Anforderung |
|---|---|
| FA-1.19 | **Einmaliges Angebot** beim ersten Erreichen der Hauptnavigation (nach Onboarding) auf Android, wenn `ShortcutManagerCompat.isRequestPinShortcutSupported` zutrifft: Dialog „App-Symbol auf den Startbildschirm legen?“, bei „Hinzufügen“ der Systemdialog. Kanal `buchhaltung/launcher` (`isSupported`, `requestPin`); Verknüpfung ID `home`, Beschriftung App-Name, Symbol `@mipmap/ic_launcher`, Intent MAIN/LAUNCHER auf `MainActivity`. Der Merker „gefragt“ liegt gerätegebunden in `flutter_secure_storage` (nicht in SQLite, keine Migration), gesetzt unabhängig von der Antwort. Dauerhaft: Einstellungen → „Symbol auf Startbildschirm legen“, nur sichtbar, wenn unterstützt. iOS und andere Plattformen: nicht unterstützt, nichts angezeigt. Gerätetest: P-D24 |

### 5.6 Export

| ID | Anforderung |
|---|---|
| FA-6.1 | Zeitraum wählbar: Jahr, Quartal oder Monat |
| FA-6.2 | Vorschau mit Belegzahl und Summen **vor** dem Teilen |
| FA-6.3 | Bei leerem Zeitraum ist der Export gesperrt und ein Hinweis sichtbar |
| FA-6.4 | DATEV wird nur bei Land DE angeboten, BMD nur bei Land AT |
| FA-6.5 | Dateiname enthält Firma und Zeitraum |
| FA-6.6 | CSV mit Semikolon, CRLF und UTF-8-BOM |
| FA-6.7 | Belegliste mit Seitenzahl und allen Kommentaren samt Zeitpunkt; DATEV und BMD hängen den jüngsten Kommentar gekürzt an den Buchungstext an (`Beschreibung / K: …`, höchstens 60 Zeichen) |

### 5.7 Tablet und Querformat

Umsetzung von DESIGN_SPEC Abschnitt 5. Schwellen nur in
`lib/core/window_size.dart` (`WindowSizeClass`), Bausteine in
`lib/widgets/adaptive.dart`.

| ID | Anforderung |
|---|---|
| FA-9.1 | Breitenklassen nach Material 3 aus der **Fensterbreite** (auch im geteilten Bildschirm): compact < 600 dp, medium 600–839 dp, expanded ≥ 840 dp (`spec.window_medium_min_dp`, `spec.window_expanded_min_dp`). Kein Widget vergleicht selbst mit Pixelzahlen |
| FA-9.2 | Hauptnavigation: compact `NavigationBar` unten; medium `NavigationRail` links mit Beschriftung unter dem Symbol; expanded ausgeklappte `NavigationRail`. Ziele und Reihenfolge unverändert (Abschnitt 7) |
| FA-9.3 | **Liste-Detail** ab expanded für Belege, Rechnungen und Kunden: Liste links (2/5), Bearbeitung rechts (3/5) in einem eigenen Navigator; Speichern schließt den Detailbereich und aktualisiert die Liste. Auf compact und medium wie bisher eigene Seite. Medium quer (z. B. Telefon quer) bleibt einspaltig, weil zwei Spalten unter 840 dp das Formular zu schmal machen |
| FA-9.4 | Formulare und Lesebereiche (Beleg, Rechnung, Kunde, Stammdaten, Bestätigungen, Einstellungen, App-Sperre, Datensicherung, Export) höchstens 640 dp breit, zentriert (`spec.max_content_width_dp`, DESIGN_SPEC D-5). Sperrbildschirm höchstens 360 dp, zentriert und scrollbar; Dialoge nach Material 3 höchstens 560 dp |
| FA-9.5 | Hoch- und Querformat ohne Sperre: Android ohne `screenOrientation`, iOS iPhone hoch und quer, iPad alle vier Ausrichtungen. **Kein `UIRequiresFullScreen`**: die App unterstützt Split View und Slide Over auf dem iPad; Apple verlangt dafür alle vier iPad-Ausrichtungen. Gerätetest: P-D19, P-D20 |

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
| Bestätigungen | `features/onboarding/consent_screen.dart` | Hinweis „keine Steuerberatung“, Nutzungsbedingungen und Datenschutz bestätigen |
| Onboarding / Stammdaten | `features/onboarding/company_setup_screen.dart` | Firmenprofil anlegen und bearbeiten, Firmenlogo |
| Hauptnavigation | `features/home/home_shell.dart` | Vier Bereiche: Tab-Leiste (compact) oder Navigationsleiste links (medium, expanded), FA-9.2; einmaliges Angebot „App-Symbol auf den Startbildschirm“ (FA-1.19) |
| Übersicht | `features/dashboard/dashboard_screen.dart` | Kassabuch, Umsatzsteuer, Grenzwertampel, Verlauf |
| Belegliste | `features/receipts/receipt_list_screen.dart` | Suchen, filtern, öffnen; Filter „Storniert“ |
| Beleg bearbeiten | `features/receipts/receipt_edit_screen.dart` | Erfassen, Seiten, automatisches Auslesen mit „Erneut auslesen“, Betrag, Fremdwährung mit „Kurs abrufen“ und Bankbetrag (FA-2.24 bis FA-2.26), Kategorie, Rechnungsnummer, Aussteller-UID, Kommentare; stornierte Belege nur lesen |
| Rechnungsliste | `features/invoices/invoice_list_screen.dart` | Status, PDF teilen, Aktionen |
| Rechnung bearbeiten | `features/invoices/invoice_edit_screen.dart` | Kunde, Positionen, Ausstellen |
| Kunde bearbeiten | `features/invoices/customer_edit_screen.dart` | Kundenstammdaten |
| Datensicherung | `features/backup/backup_screen.dart` | Sicherung erstellen und teilen, wiederherstellen mit Vorschau |
| Export | `features/export/export_screen.dart` | Zeitraum, Vorschau, Format |
| Einstellungen | `features/settings/settings_screen.dart` | Stammdaten, App-Sperre, Symbol auf Startbildschirm (FA-1.19, nur Android), Belege auslesen, Fremdwährung (Tageskurs-Genehmigung), Kategorien, Rechtsrahmen, Hinweise |
| App-Sperre einrichten | `features/app_lock/app_lock_settings_screen.dart` | PIN, Biometrie, Sperrzeit, Hinweis „PIN vergessen“, Warnung ohne Sicherung |
| Sperrbildschirm | `features/app_lock/lock_screen.dart` | PIN oder Biometrie, Wartezeit nach Fehlversuchen; Abdeckung im App-Umschalter |

**Navigation:** Vier Ziele – Übersicht, Belege, Rechnungen, Export – in der
Tab-Leiste (Telefon) bzw. in der Navigationsleiste links (Tablet, Querformat,
FA-9.2). Einstellungen erreicht man über das Zahnrad in der Übersicht.

**Liste-Detail (expanded, FA-9.3):** Belegliste mit „Beleg bearbeiten“,
Rechnungsliste mit „Rechnung bearbeiten“ und Kundenliste mit „Kunde
bearbeiten“ stehen nebeneinander; ohne Auswahl zeigt der rechte Bereich einen
Hinweis.

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
Zahlungsart, Netto, USt-Satz, USt-Betrag, Brutto, Währung, Originalbetrag, Kurs (je EUR, 6 Nachkommastellen), Kursquelle,
Kursdatum, Bankbetrag EUR, Beleg vorhanden, Notiz, Seiten, Kommentare (je
`TT.MM.JJJJ, hh:mm: Text`, getrennt durch ` | `).
Danach Summenzeilen für Einnahmen, Ausgaben, ggf. „Kursdifferenzen laut Bank“
(FA-2.26) und Ergebnis.

### 8.3 DATEV-Buchungsstapel (`datev`, nur DE)

EXTF-Format, Formatversion 700, Kategorie 21. Zeile 1 Metadaten, Zeile 2
Spaltenüberschriften, ab Zeile 3 die Buchungen.

- Gebucht wird immer **brutto**, ohne Vorzeichen
- Das Vorzeichen steckt im Soll/Haben-Kennzeichen: Einnahme `H`, Ausgabe `S`
- Belegdatum als `TTMM`; das Jahr steht im Header
- Buchungstext maximal 60 Zeichen, Semikola werden durch Komma ersetzt
- Berater- und Mandantennummer stehen als `0` – die Kanzlei ordnet den Stapel beim Import zu
- **Fremdwährung:** gebucht wird der umgerechnete Euro-Betrag mit `WKZ Umsatz` = `EUR`; die Felder `Kurs`, `Basis-Umsatz` und `WKZ Basis-Umsatz` bleiben leer, weil Kursrichtung und Pflichtkombination im EXTF-Format nicht gesichert geprüft sind (P-D23). Originalbetrag und Kurs stehen in der Belegliste (8.2). BMD (8.4) ebenso nur Euro

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

**Belegerkennung (FA-2.19):** Bild und erkannter Text bleiben auf dem Gerät.
Unter Android sendet die eingebundene Google-ML-Kit-Bibliothek jedoch
Nutzungs- und Diagnosedaten (keine Bilder, keine Texte) an Google; ein
offizielles Abschalten gibt es nicht. Offengelegt in `PRIVACY.md`,
Lastenheft 5.19 und `STORE_LISTING.md`; Prüfung P-R19, P-D21. Apple Vision
(iOS) überträgt nichts.

**EZB-Kursabruf (FA-2.25):** nur auf Tippen „Kurs abrufen“ ruft die App eine
feste Datei der Europäischen Zentralbank ab (`eurofxref-hist-90d.xml` bzw.
`eurofxref-hist.xml`). Übertragen werden nur IP-Adresse und technische
Verbindungsdaten, keine Belegdaten, keine Währung, kein Betrag. Offengelegt in
`PRIVACY.md`, Lastenheft 5.19 und `STORE_LISTING.md`; Prüfung P-R18.

### 10.2 Berechtigungen

| Berechtigung | Plattformschlüssel | Zweck |
|---|---|---|
| Kamera | `NSCameraUsageDescription` | Belege abfotografieren |
| Fotobibliothek lesen | `NSPhotoLibraryUsageDescription` | Vorhandene Belegfotos hinzufügen |
| Fotobibliothek schreiben | `NSPhotoLibraryAddUsageDescription` | Rechnung in der Fotobibliothek ablegen |
| Face ID | `NSFaceIDUsageDescription` | App-Sperre entsperren (FA-1.16); Auswertung durch das System |
| Biometrie (Android) | `USE_BIOMETRIC` (über `local_auth`) | App-Sperre entsperren (FA-1.16); Auswertung durch das System |

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
| **Steuerwerte fest im Code** | Kennwerte außer Steuersätzen (seit 0.3.4 `validFrom`, GR-3) haben kein Gültig-ab-Datum und ändern sich nur per App-Update; eine kurzfristige Gesetzesänderung erreicht die Nutzerin erst nach Store-Freigabe | Rechtsstand-Überwachung, Lastenheft L-20 und L-13.5, Stufe B |
| **Belegerkennung nicht auf Gerät erprobt** | Android-Teil im CI-Emulator mit R8 an einem synthetischen Kassenbon geprüft, Swift-Teil nur kompiliert; Korpus mit sechs echten Belegen (`test/fixtures/belege/`); Quote auf dem Gerät noch zu bestätigen (P-D22). Mehrsprachige Schlüsselwörter sind teils nur an synthetischen Texten geprüft. Lernen je Händler (Korrekturen merken) fehlt noch. Ein Beleg mit mehreren Steuersätzen wird mit einem Satz gebucht | vor Release |
| **Fremdwährung nur bei Ausgaben** | Eingangsbelege werden umgerechnet (FA-2.24 bis FA-2.27); Ausgangsrechnungen nur in Euro. Den BMF-Monatskurs lädt die App nicht, er wird von Hand übernommen; das EZB-Monatsmittel ist nur eine Näherung (P-S23, P-S24). DATEV/BMD exportieren nur Euro (P-D23). Ein Land mit anderer Währung setzt Mehrwährungsfähigkeit voraus | Backlog G7 |
| **Mengen mit zwei Dezimalstellen** | Die Mengeneingabe verarbeitet zwei Nachkommastellen, obwohl das Datenmodell drei erlaubt | – |
| **Offene Detailseite beim Wechsel der Breitenklasse** | Wird ein Tablet von quer (expanded) auf hoch (medium) gedreht oder das Fenster verkleinert, während rechts ein Beleg, eine Rechnung oder ein Kunde in Bearbeitung ist, schließt sich der Detailbereich; ungespeicherte Eingaben gehen verloren. Gespeichertes bleibt unberührt | später |
| **Android-APK-Build nicht lokal verifiziert** | Im Entwicklungscontainer ist `dl.google.com` per Netzwerk-Policy gesperrt, das Android SDK ließ sich nicht installieren. Analyse, Format und Tests laufen lokal; die Plattform-Builds verifiziert die CI | – |

---

## 12. Maschinenlesbare Kenndaten

> **Diese Werte prüft `test/specification_sync_test.dart` gegen den Code.**
> Wird ein Wert im Code geändert, ohne ihn hier anzupassen, schlägt der Test fehl.
> Das ist der Mechanismus, der dieses Dokument aktuell hält.

```properties
spec.schema_version = 10
spec.fx_rate_scale = 1000000
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
spec.logo_max_edge_px = 800
spec.logo_quality_percent = 90
spec.trend_months = 6
spec.dashboard_recent_receipts = 5
spec.app_lock_pin_min_digits = 6
spec.app_lock_pin_max_digits = 8
spec.app_lock_default_timeout_seconds = 60
spec.app_lock_free_attempts = 5
spec.app_lock_backoff_initial_seconds = 30
spec.app_lock_backoff_max_seconds = 3600
spec.window_medium_min_dp = 600
spec.window_expanded_min_dp = 840
spec.max_content_width_dp = 640

# Österreich – § 6 Abs 1 Z 27 UStG, § 11 Abs 6 UStG, § 132 BAO
spec.at.vat_permille = 200,130,100,49,0
spec.at.vat_49_valid_from = 2026-07-01
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
spec.at.fx_rate_legal_ref = § 20 Abs 6 UStG
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
spec.de.fx_rate_legal_ref = § 16 Abs 6 UStG
spec.de.small_business_legal_ref = § 19 UStG
```

Umrechnung: Beträge in Cent. `5500000` Cent = 55.000,00 €.

---

## 13. Änderungshistorie

| Version | Datum | App-Version | Änderung |
|---|---|---|---|
| 1.38 | 2026-10-14 | 0.3.4 | Korpus vollständig (6 Belege, OCR des DARS-Belegs aus dem Emulator); Steuertabelle ohne Prozentzeichen, EU-Satz ohne UID als ausländisch, entstellte Jahreszahl (FA-2.30, FA-2.29). |
| 1.37 | 2026-10-14 | 0.3.4 | Mehrsprachige Belegerkennung (FA-2.30) mit Schlüsselwort-Tabellen in 15 Sprachen, Satz nach „%“, Dezimalsätze, Steuerzeilen vor unsicherem Brutto; Beschreibungs- und Kategorievorschlag (FA-2.31); Beleg ohne Steuerausweis (FA-2.32); ausländische USt mit Länderhinweis aus dem TaxProfile (FA-2.29). Österreich 4,9 % (§ 10 Abs 1a UStG 1994) mit Gültigkeitsbeginn 1.7.2026 (GR-3, `spec.at.vat_permille`, neu `spec.at.vat_49_valid_from`). Neue Prüfpunkte P-S28 bis P-S30. Kein Schemawechsel. |
| 1.36 | 2026-10-13 | 0.3.3 | Belegerkennung an echten Belegen (FA-2.28, FA-2.29): Korpus mit ML-Kit-Rohdaten aus dem CI-Emulator, Korpustest `test/receipt_corpus_test.dart`, Zeilenzuordnung bei Schräglage, ausländische USt mit 0 % vorbelegt, mehrdeutige Währung nicht als Euro. Neuer Prüfpunkt P-S27. Kein Schemawechsel. |
| 1.35 | 2026-10-13 | 0.3.2 | Prüfpunkte P-R22, P-R23 (Kontotyp bei Google und Apple für ein e.U.); Formularvorlage `docs/STORE_ANMELDUNG.md`. Keine Codeänderung. |
| 1.34 | 2026-10-13 | 0.3.2 | Belegerkennung Android abgesichert: ML Kit wird ausdrücklich initialisiert (`MlKitContext.initializeIfNeeded`, falls der MlKitInitProvider fehlt), Datei-/Formatprüfung mit eigener Meldung, Fehlercode enthält Exception-Klasse und erste Stackzeilen. Neuer CI-Job `android-ocr-emulator` prüft die Erkennung eines synthetischen Kassenbons im Emulator im Release-Build mit R8 (`integration_test/receipt_ocr_release.dart`, `tool/ci/ocr_emulator_test.sh`). Kein Schemawechsel. |
| 1.33 | 2026-10-12 | 0.3.2 | App-Version 0.3.2: R8-Regeln für ML Kit, Fehlercode in der Meldung der Belegerkennung. |
| 1.32 | 2026-10-12 | 0.3.1 | App-Version 0.3.1: Fehlerbehebung Belegerkennung Android. |
| 1.31 | 2026-10-12 | 0.3.0 | P-L7 teilweise und P-R10 festgelegt (Telefon, Gewerbe bestätigt). Keine Codeänderung. |
| 1.30 | 2026-10-12 | 0.3.0 | App-Version 0.3.0 (Testbuild): Belegerkennung, Fremdwährung bei Eingangsbelegen, App-Symbol auf dem Startbildschirm. Schema 10. |
| 1.29 | 2026-10-12 | 0.2.0 | App-Symbol auf dem Startbildschirm (Abschnitt 5.5c, FA-1.19): einmaliges Angebot und Eintrag in den Einstellungen über `ShortcutManager.requestPinShortcut` (Android 8+), Kanal `buchhaltung/launcher`, Merker im sicheren Speicher. Kein Schemawechsel. Prüfpunkt P-D24. |
| 1.28 | 2026-10-12 | 0.2.0 | Fremdwährung bei Eingangsbelegen umgerechnet (FA-2.24 bis FA-2.27, GR-9, Lastenheft L-2.24 bis L-2.26, L-13.3, L-19.29): Kurs als Einheiten je 1 € × 10^6 (`spec.fx_rate_scale`), Umrechnung half-up in Ganzzahlen, „Kurs abrufen“ bei der EZB mit lokalem Speicher `ecb_rates`, EZB-Monatsmittel als Näherung, Tageskurs nur mit Genehmigung im Profil, Bankbetrag getrennt für die EÜR, Protokoll `fx`, Belegliste mit Währungsspalten; DATEV/BMD nur Euro. Schema 10. Neue Kennwerte `spec.fx_rate_scale`, `spec.*.fx_rate_legal_ref`, Datenfluss EZB in 10.1, Grenze in Abschnitt 11 angepasst, Prüfpunkt P-D23. |
| 1.27 | 2026-10-12 | 0.2.0 | Prüfpunkte P-S23 bis P-S26, P-R18 bis P-R20, P-L18, P-D21 (Fremdwährung, ML-Kit-Telemetrie, Haftung bei Fehlerkennung). Keine Codeänderung. |
| 1.26 | 2026-10-12 | 0.2.0 | Belege automatisch auslesen (FA-2.19 bis FA-2.23, Lastenheft L-2.20 bis L-2.23): Texterkennung auf dem Gerät (ML Kit gebündelt, Apple Vision) über eigenen Platform-Channel, Parser in `lib/services/receipt_scan/`, Vorbelegung mit „erkannt – bitte prüfen“, Fremdwährung nur erkannt, Protokoll erkannt/bestätigt mit SHA-256. Schema 9. ML-Kit-Telemetrie in 10.1 offengelegt. Neue Grenze in Abschnitt 11, Prüfpunkt P-D22. |
| 1.25 | 2026-10-12 | 0.2.0 | App-Version 0.2.0 (Testbuild). Versionsschema: 0.x bis zum Store-Start, zweite Stelle für Funktionen, dritte für Fehlerbehebungen; Buildnummer fortlaufend aus der CI. |
| 1.24 | 2026-10-12 | 0.1.0 | Tablet und Querformat (Abschnitt 5.7, FA-9.1 bis FA-9.5): Breitenklassen nach Material 3, NavigationRail ab medium, Liste-Detail ab expanded für Belege, Rechnungen und Kunden, Formularbreite 640 dp, iPad ohne `UIRequiresFullScreen`. Neue Kennwerte `spec.window_*`, `spec.max_content_width_dp`, neue Grenze in Abschnitt 11, Prüfpunkte P-D19, P-D20. |
| 1.23 | 2026-10-12 | 0.1.0 | App-Sperre (Abschnitt 5.5b, FA-1.13 bis FA-1.18, Lastenheft L-22.30): PIN 6–8 Ziffern als Argon2id-Hash im sicheren Speicher, Biometrie über `local_auth`, Sperrzeit, steigende Wartezeit, Abdeckung im App-Umschalter. Neue Kennwerte `spec.app_lock_*`, zwei neue Bildschirme, Prüfpunkte P-D17, P-D18. |
| 1.22 | 2026-10-12 | 0.1.0 | Prüfpunkte P-S19 bis P-S22, P-R15 bis P-R17, P-D14 bis P-D16 (Store-Erlös, Wiederherstellungscode, Promocodes). Keine Codeänderung. |
| 1.21 | 2026-10-12 | 0.1.0 | GR-8 vollständig: das PDF gestellter Rechnungen nimmt alle Absenderangaben aus `seller_snapshot` (`InvoiceSeller`), mit Rückfall je fehlendem Feld; abgebrochene Belegerfassung löscht nie gespeicherte Seiten (FA-2.13). |
| 1.20 | 2026-10-12 | 0.1.0 | Schema 8: mehrseitige Belege (`receipt_pages`, FA-2.13 bis FA-2.15), Kommentare nur anhängbar (`receipt_comments`, FA-2.16), Diktat über die Systemtastatur (FA-2.17), stornierte Belege lesbar (FA-2.18), Firmenlogo im PDF, eingefroren bei Rechnungslegung (`logo_path`, FA-1.12). Sicherung mit `logo/` (FA-7.6), Export mit Seiten und Kommentaren (FA-6.7, 8.2). Neue Kennwerte `spec.logo_*`, Prüfpunkte P-D11 bis P-D13. |
| 1.19 | 2026-10-12 | 0.1.0 | P-B1 bestanden (Pixel 10, Google Drive); neue Prüfpunkte P-B6 bis P-B12 zu iCloud-Standard, Datensicherheitsformularen und Wiederherstellung. Keine Codeänderung. |
| 1.18 | 2026-10-12 | 0.1.0 | Entwürfe der Rechtstexte in `docs/legal/` (Impressum, Datenschutzerklärung, Nutzungsbedingungen); Prüfpunkte P-L4 bis P-L17, P-S15 bis P-S18 (Belegkommentare, mehrseitige Belege, Diktat, Vertragsarchiv). Keine Codeänderung. |
| 1.17 | 2026-10-12 | 0.1.0 | Prüfpunkte zu Store-Reife, Lizenz und Bezahlung: P-R10 bis P-R14, P-S11 bis P-S14, P-D9, P-D10. Keine Codeänderung. |
| 1.16 | 2026-10-12 | 0.1.0 | Rückmeldungen aus dem ersten Gerätetest: Bestätigungen vor der ersten Nutzung (FA-1.10, Schema 7, Tabelle `consents`), Kennwortfelder mit Auge-Symbol (FA-1.11), Anzeigename des Sicherungsordners unter Android statt Dokument-ID. Prüfpunkt P-L1. |

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
| P-B1 | Android: bietet die Google-Drive-App bei der Ordnerwahl (Storage Access Framework) Ordner an? Test auf Pixel und Samsung mit aktueller Drive-App. Wenn nein: Entscheidung über Anbindung der Drive-Schnittstelle | Drive bot lange keine Ordner an; unsicher | vor Release | **bestanden 2026-10-12** (Auftraggeberin, Pixel 10: Sicherung und automatische Sicherung nach Google Drive). Wiederherstellung aus Drive siehe P-B12 |
| P-B2 | iOS: Bookmark auf einen iCloud-Drive-Ordner nach Neustart, Update und offline; Upload durch das System | — | vor Release | offen |
| P-B3 | Laufzeit einer großen Sicherung (viele Fotos) beim Öffnen der App; Verhalten bei Wechsel in den Hintergrund | — | vor Release | offen |
| P-B4 | Steuerberatung: verschlüsselte Sicherungskopie in einer US-Cloud neben den Originaldaten am Gerät ist kein „Führen der Bücher im Ausland“ (§ 146 Abs 2a/2b AO, § 131 BAO); Fristen nach BEG IV (8/10 Jahre) | beide Instanzen: nach h. M. unkritisch, kippt wenn die Cloud-Kopie die einzige wird | Release | offen |
| P-B5 | Store-Angaben zur automatischen Sicherung (gehört zu P-U4) | keine Erhebung durch den Anbieter | erster Upload | offen |
| P-B6 | Anwältin: iCloud-Sicherung standardmäßig an mit Hinweis, ohne Einwilligung zulässig; Hinweis auf Kundendaten und Drittland USA bei Apple | — | vor Release | offen |
| P-B7 | Gerätetest iPhone: iCloud an, aus, voll, abgemeldet; Wiederherstellung auf Zweitgerät mit Code | nur real prüfbar | vor Release | offen |
| P-B8 | Anwältin: Formular Datensicherheit in der Play Console bei Ordnerwahl bzw. Drive-Schnittstelle | — | erster Upload | offen |
| P-B9 | Apple-Review: „Data Not Collected“ trotz iCloud-Sicherung akzeptiert | — | erster Upload | offen |
| P-B10 | Gerätetest: Ordnerwahl mit Google Drive auf Samsung und Xiaomi, automatische Sicherung im Hintergrund; danach Entscheidung über Drive-Schnittstelle | — | vor Release | offen |
| P-B11 | Google: OAuth-Verifizierung für `drive.file`, nur wenn der Ersatzweg gebaut wird | — | bei Bedarf | offen |
| P-B12 | Gerätetest: Wiederherstellung aus einer Sicherung in Google Drive auf einem zweiten oder frisch installierten Gerät | Zurückholen ist der eigentliche Prüfstein | vor Release | offen |
| P-M1 | Steuerberatung AT bestätigt Nummernkreise je Gerät/Person mit Präfix (UStR Rz 1565); DE nach UStAE 14.5 Abs 10 | Prüfinstanzen: zulässig, wenn Präfix fest und dokumentiert | Stufe C | offen |
| P-M2 | Steuerberatung: Ordnungsmäßigkeit, wenn Buchhaltungsdaten im (privaten) Cloud-Konto liegen; § 131 Abs 1 BAO bei Ablage außerhalb Österreichs; Umgang mit doppeltem Storno | — | Stufe C | offen |
| P-M3 | Arbeitsrecht AT: § 96/96a ArbVG bei Erfasser-Kennung mit Zeitstempel; DE § 87 BetrVG | Erfasser-Vermerk ohne Auswertung berührt Menschenwürde in der Regel nicht | Stufe C | offen |
| P-M4 | Verhalten von iCloud-Freigabeordnern, Google Drive, OneDrive, Nextcloud bei Synchronisierung (Verzögerung, ausgelagerte Dateien, Konfliktkopien, Umbenennen) auf echten Geräten, auch gemischt iOS/Android | hohes Risiko | Stufe C | offen |
| P-M5 | Externes Sicherheitsreview der Schlüsselverteilung (X25519, Ed25519, AES-GCM, Schlüsselwechsel) vor Release | — | Release Stufe C | offen |
| P-M6 | Anwältin: Mustertext Art. 13 für Beschäftigte, Haftung und Formulierung „kein harter Zugriffsschutz“ | — | Stufe C | offen |
| P-L1 | Anwältin erstellt bzw. prüft Nutzungsbedingungen (Lizenzvertrag) und Datenschutzerklärung; Kurztexte in `lib/domain/legal_texts.dart` sind Entwürfe | — | Release | offen |
| P-L2 | Anwältin: AGB-Klausel zum Datenzugang nach Vertragsende, Haftung bei Wegfall des Anbieters, Data Act vor jedem Backend | Exklusivsperre unzulässig bzw. riskant | Release | offen |
| P-L3 | Steuerberatung: Format des Archivexports für den Datenzugriff Z3 und Verfahrensdokumentation | — | Stufe B | offen |
| P-L4 | Anwältin: gestufte Haftungsklausel (Nutzungsbedingungen Ziffer 9) nach § 6 KSchG, § 879 Abs 3 ABGB, §§ 307–309 BGB; Transparenz bei AT/DE und B2B/B2C in einem Text | Unwirksame Klausel entfällt ganz, Abmahnrisiko | Release | offen |
| P-L5 | Anwältin: Gewährleistung und Updatepflicht nach VGG bzw. § 327f BGB, obwohl der Store verkauft – wer ist „Unternehmer“ der digitalen Leistung? | — | Release | offen |
| P-L6 | Anwältin: Apple-Mindestklauseln der EULA (Ziffern 2.3, 8.3, 10) gegen das aktuelle Developer Agreement | Ablehnung im Review | Release | offen |
| P-L7 | Auftraggeberin: Firmenbucheintrag ja/nein, Gewerbewortlaut, Gewerbebehörde, Kammer; Daten aus Firmen-ABC in `docs/legal/` eintragen | Pflichtangaben § 5 ECG, DSA | Release | teilweise erledigt 2026-10-12: Firmenbuch, Gewerbebehörde, Telefon eingetragen; Gewerbe deckt Software laut Inhaberin; offen: Fachgruppe der Kammer |
| P-L8 | Auftraggeberin: Teilnahme an Verbraucherschlichtung (Internet Ombudsstelle) | Infopflicht § 19 AStG, § 36 VSBG | Release | offen |
| P-L9 | Anwältin: Hosting der Produktseite und E-Mail-Anbieter, Drittlandübermittlung, AVV | Pflichtangaben Datenschutzerklärung | Release | offen |
| P-L10 | Anwältin: genügt der Verweis auf das Widerrufsrecht des Stores, oder braucht es eine eigene Widerrufsbelehrung (L-17.10)? | — | Release | offen |
| P-L11 | Anwältin: Änderungsklausel (Ziffer 11) mit Zustimmung in der App wirksam? | BGH XI ZR 26/20, OGH streng | Release | offen |
| P-S15 | Steuerberatung: Kommentarkonzept (nur anhängbar, im Export) und Muster-Verfahrensdokumentation für mehrseitig fotografierte Belege (GoBD Rz. 136 ff., § 132 Abs 2 BAO) | — | Release | offen |
| P-S16 | Steuerberatung: Aufbewahrungsfrist je Vertragstyp AT/DE (BEG IV) für das Vertragsarchiv | — | Stufe C | offen |
| P-S17 | Steuerberatung bzw. Kammer: Katalog der KI-Hinweistexte zu Verträgen auf Vorbehaltsaufgaben (StBerG, WTBG) | — | Stufe C | offen |
| P-S18 | Steuerberatung: Leasing-Sonderzahlung und Zurechnung bei Einnahmen-Ausgaben-Rechnung AT/DE | — | Stufe C | offen |
| P-S19 | Steuerberatung: Zusammenfassende Meldung und UID-Pflicht bei Store-Auszahlungen als Kleinunternehmerin AT | — | erste Auszahlung | offen |
| P-S20 | Steuerberatung: kein Reverse Charge auf die Store-Provision (fiktiver Leistender), Bemessungsgrundlage Auszahlung; Abrechnungsbelege Google/Apple | — | erste Auszahlung | offen |
| P-S21 | Steuerberatung: Store-Umsätze zählen nicht zur 55.000-€-Grenze (§ 6 Abs 1 Z 27 UStG)? | — | erste Auszahlung | offen |
| P-S22 | Steuerberatung: Affiliate-Provisionen (Reverse Charge, Gutschrift), Einkommensteuer- und SVS-Schätzung mit echten Zahlen | Preispolitik der Auftraggeberin | vor Preisfestlegung | offen |
| P-S23 | Steuerberatung AT: BMF-Durchschnittskurs nach § 20 Abs 6 UStG, Stichtag bei Soll- und Istbesteuerung, Steuerbetrag in Euro auf Fremdwährungsrechnungen | Umgesetzt: Monatskurs des Belegmonats; BMF-Kurs nur manuell (Quelle `bmf_monthly`), Standard EZB-Monatsmittel als Näherung (FA-2.25) | vor Fremdwährung | offen |
| P-S24 | Steuerberatung DE: Abschn. 14.5 Abs. 22 UStAE; darf das EZB-Monatsmittel den BMF-Kurs ersetzen? | Umgesetzt als gekennzeichnete Näherung „EZB-Monatsmittel – Näherung an BMF-Kurs“; manueller BMF-Kurs jederzeit | vor Fremdwährung | offen |
| P-S25 | Steuerberatung: Kurs für die Kleinunternehmergrenze bei Fremdwährungsumsätzen | Betrifft nur Einnahmen; diese bleiben Euro (L-13.3), daher derzeit ohne Wirkung | vor Fremdwährung | offen |
| P-S26 | Steuerberatung: Unterschied Umsatzsteuer-Kurs zu Bankbetrag in E1a bzw. Anlage EÜR | Umgesetzt: Bankbetrag überschreibt nur das EÜR-Ergebnis als Kursdifferenz (FA-2.26), Vorsteuer bleibt beim USt-Kurs | vor Fremdwährung | offen |
| P-S27 | Steuerberatung: Ausländische Umsatzsteuer auf Belegen (z. B. dänische MOMS 25 %, deutsche USt 19 % bei Nutzerin in AT) ist im Inland nicht als Vorsteuer abziehbar; App belegt 0 % vor und verweist auf das Vorsteuer-Vergütungsverfahren. Bestätigen: Buchung brutto ohne Vorsteuer korrekt, Hinweistext ausreichend | Umgesetzt (FA-2.29), Befund der Prüfinstanz Steuerberater noch zu bestätigen | vor Release | offen |
| P-S28 | Steuerberatung AT: 4,9 % nach § 10 Abs 1a UStG 1994 iVm Anlage 3 (laut RIS BGBl. I Nr. 37/2026), Leistungen ab 1.7.2026, unbefristet. Wortlaut, Anlage 3 und BGBl.-Nr. im RIS abgleichen; Abgrenzung Grundnahrungsmittel (KN-Positionen, Fett-/Zuckergrenze) | Umgesetzt: Satz im TaxProfile Österreich mit `validFrom` 2026-07-01 (GR-3); Befund der Prüfinstanz Steuerberater 2026-10-14 | vor Release | offen |
| P-S29 | Steuerberatung: Kartenbeleg ohne Steuerausweis – Betriebsausgabe ja, Vorsteuer nein (§ 11 Abs 6, § 12 Abs 1 Z 1 UStG 1994; DE § 33 UStDV, § 15 UStG). Hinweistext bestätigen | Umgesetzt (FA-2.32): 0 % vorbelegt, Hinweis `noVatShownHint` | vor Release | offen |
| P-S30 | Steuerberatung: Hinweistext ausländische USt je Land (AT FinanzOnline, DE BZSt; Frist 30.09. Folgejahr; Mindestbeträge 50 €/400 €; nicht für Kleinunternehmer) | Umgesetzt (FA-2.29, `foreignVatHint`) | vor Release | offen |
| P-L12 | Anwältin: Diktat über die Systemtastatur – Anbieterin nicht verantwortlich, Hinweistext genügt | — | Release | offen |
| P-L13 | Gerätetest, nur bei eigener Spracherkennung: Erkennung im Flugmodus | — | später | offen |
| P-L14 | Anwältin: Rollen beim Vertragsarchiv mit KI (Anbieterin als Auftragsverarbeiterin), Muster-AVV, Rechtsgrundlage Beschäftigtendaten | — | Stufe C | offen |
| P-L15 | Anwältin bzw. Datenschutzberatung: DSFA und TIA; DPF-Zertifikat, Zero Data Retention und Speicherdauer bei Anthropic verifizieren | — | Stufe C | offen |
| P-L16 | Anwältin: KI-Ausgabetexte zu Verträgen auf RDG, RAO und UWG | — | Stufe C | offen |
| P-L17 | Anwältin: Art. 50 AI Act (Kennzeichnung) und aktuelle Fristen | — | Stufe C | offen |
| P-L18 | Anwältin: Lizenzpflichten ML Kit (Google APIs / ML Kit Terms), Lizenznennung in der App | — | Release | offen |
| P-R10 | Öffentliche Händleradresse und Telefon (DSA-„Trader"-Angaben) festlegen, identisch mit dem Impressum | Postfach reicht nicht; Geschäftsadresse ratsam | erster Upload | festgelegt 2026-10-12 (Arnoldstein, +43 660 3124252); anwaltliche Bestätigung offen |
| P-R11 | Nutzungsbedingungen als eigene EULA (Apple) bzw. verlinkt (Google): Gewährleistung und Regress, Rolle der Stores, Herabstufung/Nur-Lese-Modus, Volljährigkeit | — | Release | offen |
| P-R12 | Wortlaut der Abo- und Testseite (§§ 312j, 312k BGB, PAngV, Apple 3.1.2); greift § 312k bei Store-Abos? | h. M.: nein, Sprung in die Store-Verwaltung genügt | Release | offen |
| P-R13 | Finaler Store-Text und Screenshots auf UWG und „keine Steuerberatung" | — | vor jeder Einreichung | offen |
| P-R14 | App Privacy Labels und Data Safety zu Käufen ohne Dritt-SDK | Käufe nur über die Stores, nicht „erhoben" | erster Upload | offen |
| P-R15 | Anwältin: Haftung und Hinweispflicht bei Datenverlust durch verlorenen Wiederherstellungscode (AT/DE, B2B/B2C) | — | Release | offen |
| P-R16 | Anwältin: Affiliate- bzw. Influencer-Vertrag, Werbekennzeichnung (§ 6 ECG, UWG), Mithaftung | — | vor erster Aktion | offen |
| P-R17 | Anwältin: Preisangaben bei Gratisphase und Jahresrabatt (PAngV, PrAG, Omnibus-RL) | — | Release | offen |
| P-R18 | Anwältin: EZB-Nutzungsbedingungen; datenschutzrechtliche Einordnung des Kursabrufs (IP-Adresse) | Abruf nur auf Knopfdruck, nur IP-Adresse, offengelegt in PRIVACY, 5.19, STORE_LISTING; Hinweis „EZB-Referenzkurs, ohne Gewähr“ | vor Fremdwährung | offen |
| P-R19 | Anwältin: ML-Kit-Telemetrie laut aktueller Google-Doku, Opt-out, Angaben in Play Data Safety und Apple Privacy Label | Entscheidung ML Kit 2026-10-12 | Release | offen |
| P-R20 | Anwältin: Haftungsbegrenzung bei Fehlerkennung in den Nutzungsbedingungen (KSchG, BGB) | — | Release | offen |
| P-R22 | Google Play: wird ein eingetragenes Einzelunternehmen (e.U.) als Organisationskonto angenommen? Welche Nachweise (D-U-N-S, Firmenbuchauszug)? | Organisationskonto erspart den 14-Tage-Test mit 12 Testerinnen | vor Kontoanlage | offen |
| P-R23 | Apple: Anmeldung als Einzelperson (Einzelunternehmen ist laut Apple keine Organisation); Verkäufername im Store = persönlicher Name; Migration bei späterer GmbH | Apple Account Help D-U-N-S | vor Kontoanlage | offen |
| P-S11 | USt-Kette der Store-Abos: Leistung an Apple/Google in Irland, Reverse Charge, UID, ZM, UVA; gelten die Store-Abrechnungen als Gutschrift (§ 11 Abs 7 UStG AT)? | Kette sicher, Rechnungsstellung offen | erster Verkauf | offen |
| P-S12 | Vorsteuerabzug für Unternehmerinnen aus Store-Quittungen | unklar; kein Versprechen in App oder Werbung | erster Verkauf | offen |
| P-S13 | Verbuchung der Store-Auszahlungen (netto als Erlös empfohlen, Zufluss/Abgrenzung, Fremdwährung), W-8BEN(-E) | — | erster Verkauf | offen |
| P-S14 | Zählen Store-Umsätze (Leistungsort Irland) zur Kleinunternehmergrenze des Anbieters? Zusammen mit O-26 | voraussichtlich nein | erster Verkauf | offen |
| P-D9 | Export Compliance iOS: `ITSAppUsesNonExemptEncryption` steht auf `false`, die App verschlüsselt aber selbst (AES-256, Argon2id); Einstufung als Standardverfahren, Frankreich-Erklärung | voraussichtlich ausgenommen, Wert und Fragebogen klären | erster iOS-Upload | offen |
| P-D10 | In den Konsolen bestätigen: Pflichttest für Organisationskonten entfällt, targetSdk-Stichtag 2026, Entwicklerverifizierung für Sideloading | aus Fachwissen | erster Upload | offen |
| P-D11 | Gerätetest Mehrseiten-Kamera (Android und iOS): mehrere Seiten nacheinander aufnehmen, Reihenfolge ändern, Seite löschen, Speichern mit Bestätigung; Speicherbedarf bei 10 Seiten; Wiederherstellung auf zweitem Gerät zeigt alle Seiten | Logik in Tests geprüft, Kamera nicht | Release | offen |
| P-D12 | Gerätetest Diktat über die Systemtastatur (Gboard, Samsung-Tastatur, iOS) im Kommentarfeld, auch offline; stimmt der Hinweistext zum tatsächlichen Verhalten (gehört zu P-L12) | — | Release | offen |
| P-D13 | Rechnungs-PDF mit Logo (PNG mit Transparenz, JPEG, HEIC aus iOS) am Bildschirm und gedruckt; DATEV-Import eines Stapels mit gekürztem Kommentar im Buchungstext | Logo-PDF im Test erzeugbar; DATEV-Import nicht geprüft | Release | offen |
| P-D14 | Offer Codes (App Store Connect) und Promo Codes (Play Console) anlegen; Einlösung als Neu- und Bestandskundin, Limits, Ablauf | — | vor erster Aktion | offen |
| P-D15 | Eingelöste Codes und Ende der Gratisphase werden ohne Server erkannt (StoreKit 2, Billing Library) | — | Release | offen |
| P-D16 | Codeblatt als PDF, Druck und Autofill auf iOS und Android ansehen | — | Release | offen |
| P-D17 | App-Sperre auf echten Geräten: Fingerabdruck (Android), Face ID und Touch ID (iOS), Rückfall auf PIN, Sperre nach Zeit im Hintergrund; Vorschau im App-Umschalter verdeckt (iOS-Abdeckung, Android 13+ `setRecentsScreenshotEnabled`, Android < 13 nur Flutter-Abdeckung) | Flutter-Abdeckung kann auf Android < 13 zu spät gezeichnet werden; dann FLAG_SECURE erwägen | Release | offen |
| P-D18 | Android-Build nach Umstellung auf `FlutterFragmentActivity` und `Theme.AppCompat`: Start, Sicherungsordner-Wahl (`onActivityResult`) und Startbildschirm hell/dunkel, auch unter Android 8 | im Container nicht baubar; CI prüft den Build, nicht das Verhalten | Release | offen |
| P-D19 | Android-Tablet (z. B. 10–11 Zoll) hoch und quer, Telefon quer, Split-Screen/Mehrfenster: Navigation (Leiste/Rail), Liste-Detail, Formularbreite, Tastatur verdeckt kein aktives Feld, Sperrbildschirm und Dialoge, Drehen während der Bearbeitung | Widget-Tests mit 390×844, 844×390, 768×1024 und 1194×834 dp grün; echtes Gerät fehlt | Release | offen |
| P-D23 | DATEV-Import eines Buchungsstapels mit Fremdwährungsbeleg in einer echten DATEV-Kanzlei: genügt Euro ohne WKZ/Kurs, oder sind `WKZ Umsatz`, `Kurs` (Richtung!) und `Basis-Umsatz` zu befüllen? Ebenso BMD. Dazu „Kurs abrufen“ auf echtem Gerät inkl. Fehlerfall ohne Netz | Export nur Euro, Originalwerte in der Belegliste; EZB-Parser mit Beispieldatei geprüft | vor Fremdwährung | offen |
| P-D22 | Belegerkennung an mindestens 30 echten Belegen (Supermarkt, Tankstelle, Hotel, Online-Rechnung, Kleinbetrag, Fremdwährung, zerknittert/schräg): Quote je Feld (Datum, Brutto, Satz, Händler, UID, Rechnungsnummer); Gerätetest Android und iOS, auch im Flugmodus (Erkennung muss offline laufen) | Parser mit Testtexten geprüft; Android-Engine im CI-Emulator (Release mit R8) an synthetischem Bon geprüft, ersetzt nicht den Gerätetest; iOS nur kompiliert | vor Release | offen |
| P-D21 | Gerätetest mit Netzwerkmitschnitt: Erkennung läuft offline; welche Endpunkte ruft ML Kit auf (Firelog)? | gehört zu P-R19 | Release | offen |
| P-D20 | iPad hoch und quer (alle vier Ausrichtungen), Split View und Slide Over (1/3, 1/2, 2/3), Stage Manager; App Review akzeptiert Multitasking ohne `UIRequiresFullScreen` | Info.plist enthält alle vier iPad-Ausrichtungen, kein `UIRequiresFullScreen`; nur auf macOS/Gerät prüfbar | Release | offen |
| P-D24 | App-Symbol auf dem Startbildschirm auf echtem Pixel (per APK installiert): Angebot erscheint einmal nach dem Onboarding, Systemdialog „Zum Startbildschirm hinzufügen“, Symbol erscheint, Tippen startet die App; Eintrag in den Einstellungen; Verhalten unter Android 8 und mit einem Fremd-Launcher | Dart-Logik getestet, Kotlin nur kompiliert (CI) | Release | offen |
| P-D8 | Zusatzsicherung unter Windows (`tool/sicherung/sicherung.ps1`): Erstlauf, Aufgabenplanung, Wiederherstellung | Linux-Variante getestet, Windows-Skript nie ausgeführt | sofort | offen |
