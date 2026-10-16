# Spezifikation – Buchhaltung

**Dokumentversion:** 1.64 · **App-Version:** 0.16.0 · **Stand:** 2026-10-16
**Status:** Testbuild 0.16.0 (Schema 20); Store-Start offen, siehe Abschnitt 11 und 14

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

Korrigiert wird nie durch Ändern, sondern durch eine Stornorechnung (GR-14).
Am Original ändern sich dabei nur `status` und `cancelled_by_invoice_id`.

### GR-14 · Stornorechnung und Rechnungskorrektur

Lastenheft L-3.7, L-3.18; `InvoiceRepository.cancelWithInvoice`.

1. **Eigener Beleg, eigene Nummer:** Die Stornorechnung zieht die nächste
   Nummer aus **demselben** Nummernkreis wie Rechnungen, in derselben
   Transaktion (FA-5.5) – lückenlos, einmalig (§ 11 Abs 1 Z 3 lit c UStG AT,
   § 14 Abs 4 Nr. 4 UStG DE; getrennte Kreise wären zulässig, ein Kreis ist
   der einfachere und prüfsichere Weg, P-S56).
2. **Bezug:** Nummer und Datum der Originalrechnung werden eingefroren
   (`cancels_number`, `cancels_issue_date`) und stehen im Kopf und im Text
   (§ 31 Abs 5 UStDV, Abschn. 14.11 UStAE; UStR Rz 1535 ff. zur
   Rechnungsberichtigung AT). Dazu Grund und Datum des Stornos. Aussteller-
   und Empfängerdaten übernimmt sie aus den Snapshots des Originals.
3. **Beträge:** dieselben Positionen, Rabatte und Versandkosten wie das
   Original; alle Summen sind die **negierten** Summen des Originals
   (`InvoiceTotals.negated`), je Steuersatz ohne neue Rundung. Original plus
   Storno ergeben je Satz exakt 0; GR-2 und GR-5 gelten unverändert.
4. **Nicht „Gutschrift“:** Titel „Stornorechnung“, weil „Gutschrift“ die
   Abrechnung durch den Leistungsempfänger bezeichnet (§ 14 Abs 2 UStG DE,
   § 11 Abs 7 UStG AT).
5. **Buchung (Ist-Prinzip, GR-11):** War das Original *bezahlt*, wird am Tag
   des Stornos (= Rückzahlung, änderbar) je Satz eine negative Einnahme in
   Höhe des damals gebuchten Betrags (nach Skonto) gebucht, Bezug
   `receipts.invoice_id` = Stornorechnung. War es *offen*, wird nichts
   gebucht – es wurde nichts eingenommen. Eine falsch ausgewiesene Steuer
   (§ 14c UStG DE, § 11 Abs 12 UStG AT) gilt mit der Stornorechnung als
   berichtigt, sobald sie dem Empfänger zugeht (P-S56).
6. **Mahnungen:** nicht stornierte Mahnschreiben zur Rechnung werden mit dem
   Grund „Rechnung storniert durch <Nummer>“ storniert. Bereits gebuchte
   Mahnkosten bleiben.
7. Je Originalrechnung höchstens eine Stornorechnung (eindeutiger Index);
   eine Stornorechnung selbst ist nicht stornierbar.

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

### GR-10 · Wirtschaftsjahr nur für die Gewinnermittlung

Das Wirtschaftsjahr (`FiscalYear`, `lib/domain/fiscal_year.dart`) beginnt am
Ersten des Monats „Erster Monat Wirtschaftsjahr“ (Standard Jänner/Januar) und
wird nach dem Kalenderjahr bezeichnet, in dem es endet (AT § 2 Abs 5 EStG,
DE § 4a Abs 2 Nr 2 EStG; `spec.*.fiscal_year_legal_ref`). Es gilt für
Kassabuch-Jahr, Einnahmen-Ausgaben-Auswertung, Jahresexport, Exportdateinamen
und den DATEV-Header „WJ-Beginn“. **Umsatzsteuer, Voranmeldung und
Kleinunternehmergrenze bleiben immer beim Kalenderjahr**; ein Regressionstest
(`test/invoice_payment_test.dart`) sichert das.

### GR-11 · Einnahmen nach Zahlungseingang

Die Einnahmen-Ausgaben-Rechnung folgt dem Zuflussprinzip (AT § 19 EStG,
DE § 11 EStG): Eine Ausgangsrechnung wird Einnahme am Tag des
Zahlungseingangs, eine offene Rechnung zählt nicht. Beim Markieren „bezahlt“
entsteht je Steuersatz ein Einnahmebeleg mit `invoice_id`; ein eindeutiger
Index verhindert Doppelbuchungen. Prüfpunkt P-S35.

### GR-12 · Rabatt, Versand und Skonto je Steuersatz

Rechnungssummen rechnet ausschließlich `InvoiceTotals`
(`lib/services/invoice_totals.dart`):

1. Positionsbetrag = Menge × Einzelpreis (ganzzahlig, half-up), abzüglich
   Positionsrabatt (Promille des Positionsbetrags oder Betrag, höchstens der
   Positionsbetrag) = Entgelt der Position.
2. Gesamtrabatt (Promille der Entgeltsumme oder Betrag) wird **anteilig nach
   Entgelt je Steuersatz** auf je eine Rabattzeile je Satz verteilt.
   Restcent nach dem größten Rest, bei Gleichstand an den höheren Satz.
3. Versandkosten folgen der Hauptleistung: ein Satz → dieser; mehrere Sätze →
   anteilig nach Entgelt nach Rabatt, eine Teilzeile je Satz; wahlweise ein
   fester Satz (`shipping_vat_permille`).
4. Umsatzsteuer je Position und je Zusatzzeile gerundet (GR-5); je Satz und
   insgesamt gilt `net + vat == gross` (GR-2).
5. Skonto = Brutto × Satz, half-up. Wird mit Skonto gezahlt, verteilt die App
   den Abzug nach **Brutto je Satz** (größter Rest) und zerlegt jeden Anteil mit
   `VatCalculator.fromGross` in Entgelt und Steuer; die Einnahme je Satz
   mindert sich um diesen Anteil. Weil die App Einnahmen erst bei Zahlung bucht
   (GR-11), ist die geminderte Einnahme im Zahlungsmonat zugleich die
   Steuerberichtigung (§ 16 UStG AT, § 17 UStG DE); eine eigene
   Korrekturbuchung für Soll-Versteuerung gibt es nicht (P-S35, P-S42).
   Die Rechnung bleibt unverändert (GR-8), vermerkt wird nur
   `skonto_taken_cents`.

Beispiel AT: 100,00 € zu 20 % und 50,00 € zu 10 %, 10 % Gesamtrabatt →
90,00 + 18,00 und 45,00 + 4,50, brutto 157,50 €.

### GR-13 · Mahnwesen: Nebenforderungen sind nicht umsatzsteuerbar

Zahlungserinnerung (Stufe 1) und Mahnungen (Stufe 2 = „1. Mahnung“ usw.)
sind unveränderliche Momentaufnahmen (`dunning_notices`, Trigger). Mahnkosten,
Verzugszinsen und Pauschale sind Schadenersatz bzw. Zinsen, kein Entgelt: sie
stehen getrennt mit „nicht umsatzsteuerbar“ und werden erst bei Zahlung als
Einnahme mit 0 % gebucht (Kategorie „Sonstige Einnahmen“). Anrechnung einer
Zahlung: Kosten → Zinsen → Hauptforderung (§ 1416 ABGB, § 367 BGB,
`DunningCalculator.allocatePayment`).

Zinsen: Basispunkte (1/100 %), weil der Basiszinssatz zwei Nachkommastellen
hat. Zeitraum Tag nach Fälligkeit bis Mahndatum einschließlich, act/365, je
Halbjahr ein Abschnitt mit dem Basiszinssatz am ersten Tag des Halbjahrs;
je Abschnitt `Betrag × Satz × Tage / 3.650.000`, half-up. Gesetzliche Sätze
im `TaxProfile.dunning`: AT Verbraucher 4 % (§ 1000 ABGB), AT Unternehmen
Basiszins + 9,2 Pp (§ 456 UGB), DE Verbraucher + 5 Pp, Unternehmen + 9 Pp
(§ 288 BGB); Pauschale 40 € nur B2B (§ 458 UGB, § 288 Abs 5 BGB). Der Satz ist
ein änderbarer Vorschlag.

## 4. Datenmodell

**Speicher:** SQLite auf dem Gerät, Datei `buchhaltung.db` im
Anwendungsdokumentenverzeichnis. Aktuelle Schemaversion: **19**
(`spec.schema_version`). Bilder liegen als Dateien daneben: Belegseiten in
`belege/`, Firmenlogos in `logo/`.

### 4.1 Tabellen

| Tabelle | Zweck | Besonderheit |
|---|---|---|
| `company_profile` | Firmenstammdaten | Genau eine Zeile, erzwungen durch `CHECK (id = 1)` |
| `categories` | Buchhaltungskategorien | 16 Startkategorien, `is_system = 1` schützt vor Löschen |
| `customers` | Rechnungsempfänger | Löschen blockiert, solange Rechnungen bestehen. Seit Schema 13 `is_business` (1 = Unternehmen; bei der Migration 1, wo eine UID eingetragen ist) |
| `dunning_notices` | Zahlungserinnerungen und Mahnungen: `invoice_id`, `level`, `issued_on`, `new_due_date`, `principal_cents`, `fee_cents`, `fees_total_cents`, `interest_cents`, `interest_rate_bp`, `flat_fee_cents`, `total_cents`, `text`, `pdf_sha256`, `cancelled_at`, `cancel_reason`, `created_at` | Schema 13. Unveränderlich (Trigger); einzig erlaubt: einmaliges Storno mit Begründung |
| `receipts` | Belege | Index auf `date` und `direction`. Werden nie gelöscht, nur storniert (`cancelled_at`). Seit Schema 11 `invoice_id` (Einnahme aus bezahlter Rechnung, eindeutig je Rechnung und Steuersatz); seit Schema 17 `reverse_charge` (0/1, Steuerschuld des Leistungsempfängers, FA-2.46) |
| `receipt_vat_lines` | Steuersatzzeilen eines Belegs: `receipt_id`, `position` ab 1, `vat_permille`, `net_cents`, `vat_cents`, `gross_cents` | Schema 14. Je Zeile `net + vat == gross`, Summe der Zeilen = `receipts.gross_cents` (erzwungen in `ReceiptRepository.writeVatLines`). Bei der Migration wurde jeder bestehende Beleg zu genau einer Zeile; Einnahmen aus bezahlten Rechnungen und Mahnkosten schreiben ihre Zeile mit. Kopf des Belegs: Summen, `vat_permille` = Satz der größten Zeile. Auswertungen lesen nur Zeilen (ein Beleg ohne Zeile zählt mit seinem Kopf) |
| `cash_register_merchants` | Lernspeicher Kasse → Händler (FA-2.36): `register_key` (`AT:<Kassen-ID>`, `DE:<Seriennummer>`), `merchant`, `updated_at` | Schema 15. Ersetzt beim Speichern eines Belegs mit Kassen-QR |
| `supplier_memory` | Lernspeicher je Lieferant (FA-2.50): `supplier_key` (`<Richtung>|UID:<UID>` bzw. `<Richtung>|NAME:<normalisierter Name>`), `counterparty`, `category_id`, `vat_permille`, `currency`, `payment_method`, `updated_at` | Schema 20. Ersetzt bei jedem Speichern eines Belegs; nur auf dem Gerät, in der Sicherung enthalten |
| `receipt_documents` | Originaldateien (FA-2.41): `receipt_id`, `file_path` (relativ, `belege/…`), `file_name`, `mime`, `sha256`, `size_bytes`, `source`, `created_at` | Schema 16. Nur Einfügen; Trigger verhindern `UPDATE` und `DELETE` |
| `platform_import_rows` | Übernommene Zeilen aus Plattformexporten (FA-2.45): `platform`, `external_id`, `format`, `month` (`YYYY-MM`), `receipt_id` (Sammelbeleg oder leer bei Auszahlung/Sonstigem), `imported_at` | Schema 17. Primärschlüssel (`platform`, `external_id`): Dubletten werden mit `INSERT OR IGNORE` still übersprungen. Keine Käuferdaten |
| `receipt_pages` | Seiten (Fotos) eines Belegs: `receipt_id`, `position` ab 1, `image_path`, `created_at` | Schema 8. Nach dem Speichern nur Anhängen; bestehende Einzelfotos wurden bei der Migration zur Seite 1 |
| `receipt_comments` | Kommentare zu Belegen: `receipt_id`, `text`, `created_at` (Systemzeit) | Schema 8. Nur Einfügen; ein Trigger verhindert `UPDATE`. Löschen bietet die App nicht an (die Wiederherstellung leert alle Tabellen) |
| `invoices` | Ausgangsrechnungen | `UNIQUE INDEX` auf `number`. Seit Schema 12 Gesamtrabatt, Versand, Skonto (GR-12). Seit Schema 18 Stornorechnung (GR-14): `cancels_invoice_id` (eindeutig, wenn gesetzt), `cancels_number`, `cancels_issue_date`, `cancel_reason`; am Original `cancelled_by_invoice_id`; Status `cancellation` |
| `invoice_items` | Rechnungspositionen | `ON DELETE CASCADE`. Seit Schema 12 Positionsrabatt |
| `articles` | Artikelstamm (FA-5.44): `number` (Artikelnummer, freiwillig), `name`, `description`, `unit`, `unit_price_cents` (netto), `vat_permille`, `created_at` | Schema 19. `UNIQUE INDEX` auf `number`, wenn gesetzt (L-11.2). Löschen jederzeit: Positionen sind Kopien (L-11.11) |
| `offers` | Angebote (FA-5.40): `number`, `year`, `sequence`, `issue_date`, `valid_until`, `customer_id`, `status` (`draft`, `sent`, `accepted`, `rejected`), `is_small_business`, `notes`, `invoice_id` (Rechnungsentwurf nach Umwandlung), `created_at` | Schema 19. `UNIQUE` auf `number` und (`year`, `sequence`). „Abgelaufen“ wird nicht gespeichert, sondern aus `valid_until` abgeleitet. Kein Bezug zu `receipts` (L-3.14) |
| `offer_items` | Angebotspositionen, Spalten wie `invoice_items` | Schema 19. `ON DELETE CASCADE` |
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
| `fiscal_year_start_month` | INTEGER | Erster Monat Wirtschaftsjahr, 1–12 (GR-10) |
| `fiscal_year_confirmed` | INTEGER | Abweichendes Wirtschaftsjahr bestätigt (Schema 11, FA-10.2) |
| `federal_state` | TEXT | Bundesland-Kürzel, nur DE, leer = bundesweite Feiertage (Schema 11) |
| `vat_return_interval` | TEXT | `auto`, `monthly`, `quarterly` (Schema 11, FA-10.6) |
| `vat_permanent_extension`, `files_ecsl`, `has_tax_advisor`, `svs_insured` | INTEGER | Dauerfristverlängerung (DE), ZM, Steuerberatung, SVS (AT); Schema 11 |
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
| `seller_snapshot`, `customer_snapshot` | TEXT | Eingefrorene Stammdaten als JSON; `terms_url` wird nie aus dem aktuellen Profil ergänzt |
| `discount_permille`, `discount_cents` | INTEGER | Gesamtrabatt in Promille oder Cent (Schema 12) |
| `shipping_cents`, `shipping_vat_permille` | INTEGER | Versandkosten netto; Satz `NULL` = wie Hauptleistung (Schema 12) |
| `skonto_days`, `skonto_permille` | INTEGER | Skontofrist ab Rechnungsdatum und Satz (Schema 12) |
| `skonto_taken_cents` | INTEGER | Bei Zahlung abgezogenes Skonto, 0 = ohne (Schema 12) |

**`invoice_items`**

| Feld | Typ | Bedeutung |
|---|---|---|
| `position` | INTEGER | Lückenlos ab 1, beim Speichern neu vergeben |
| `quantity_milli` | INTEGER | Menge × 1000, siehe GR-4 |
| `unit_price_cents` | INTEGER | Einzelpreis **netto** |
| `discount_permille`, `discount_cents` | INTEGER | Positionsrabatt in Promille oder Cent (Schema 12) |

**`company_profile`** — seit Schema 13: `dunning_fee_cents` (Standard 1000), `dunning_interest`, `dunning_flat_fee` (INTEGER 0/1), `dunning_period_days` (Standard 14). **`receipts`** — seit Schema 13: `dunning_invoice_id` (Einnahme aus Mahnkosten und Zinsen, eindeutig je Rechnung).

**`company_profile`** — seit Schema 12: `default_skonto_days`, `default_skonto_permille` (INTEGER, Vorschlag für neue Rechnungen, 0 = ohne), `terms_url` (TEXT, Adresse der AGB), `terms_hint_shown` (INTEGER, einmaliger Hinweis gezeigt)

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
| FA-1.4f | **E-Mail und Telefon** (Profil; E-Mail auch beim Kunden) werden nur auf Form geprüft (`ContactFormat`, 0.12.0, Lastenheft O-30), ohne Verifizierung; leer ist erlaubt. E-Mail: Lokalteil, `@`, Domain mit Punkt und Endung ≥ 2 Zeichen, ohne Leerzeichen. Telefon: Ziffern, führendes `+`, Leerzeichen, `/ ( ) -`; 6 bis 20 Ziffern |
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
| FA-2.14 | **Vollständigkeitsbestätigung** (L-2.16): sind neue Seiten hinzugekommen, ist Speichern zugleich die Bestätigung. Der unten fixierte Primärknopf heißt dann „Vollständig – Beleg speichern (n Seiten)“ mit Häkchen-Symbol, darüber steht „Mit Speichern bestätigst du, dass alle Seiten inkl. beschriebener Rückseiten erfasst sind.“ Kein eigenes Kontrollkästchen, kein Dialog. Bei genau einer Seite links daneben der sekundäre Knopf „Rückseite?“ (Kamera, weitere Seite). Der `audit_log`-Eintrag `create`/`update` trägt „n Seite(n), Vollständigkeit bestätigt“. Ohne neue Seiten bleibt „Beleg speichern“ bzw. „Änderungen speichern“. Steuerliche Wirksamkeit: Prüfpunkt P-S31 |
| FA-2.15 | Belegansicht zeigt alle Seiten als Leiste mit Seitennummer; Antippen öffnet die Seite vergrößert (Zoom) |
| FA-2.16 | **Kommentare** (L-2.17): beim Erfassen ein Kommentarfeld, das beim Speichern zum ersten Kommentar wird; bei gespeicherten, auch stornierten Belegen „Kommentar anhängen“. Zeitstempel ist die Systemzeit. Kein Bearbeiten, kein Löschen; Korrektur nur als neuer Kommentar. Jeder Kommentar erzeugt einen `audit_log`-Eintrag `comment`. Der Beleg selbst bleibt unverändert |
| FA-2.17 | **Diktat** (L-2.18) nur über die Diktierfunktion der Systemtastatur; die App enthält keine Spracherkennung und überträgt nichts. Hinweis im Formular: je nach Gerät kann die Tastatur Sprache an Google oder Apple senden |
| FA-2.19 | **Belege automatisch auslesen** (Lastenheft L-2.20): nach dem Hinzufügen einer Seite erkennt die App den Text **aller Seiten** auf dem Gerät (Android: Google ML Kit Text Recognition Latin, gebündeltes Modell; iOS: Apple Vision `VNRecognizeTextRequest`) über den Channel `buchhaltung/receipt_text` und die Schnittstelle `ReceiptTextRecognizer`. Der Parser `lib/services/receipt_scan/` ermittelt Belegdatum, Bruttobetrag, Umsatzsteuer je Satz (Sätze aus allen `TaxProfile`s, eigenes Land zuerst), Netto, Händler, Aussteller-UID (Prüfung mit `VatIdFormat`, eigene UID übergangen), Rechnungsnummer und Währung, je mit Konfidenz 0–100. Beträge ganzzahlig in Cent; je Satz gilt `net + vat == gross`. Nur bei neuen Belegen wird automatisch vorbelegt, Felder unter Konfidenz 40 bleiben leer. Vorbelegte Felder tragen „erkannt – bitte prüfen“; gebucht wird erst beim Speichern. Das Originalbild bleibt unverändert. „Erneut auslesen“ startet die Erkennung von Hand |
| FA-2.28 | **Auslesen echter Belege** (Stufe 1, Korpus `test/fixtures/belege/`): Zeilen werden über die Lage zu Bildzeilen zusammengeführt, auch bei schräg gehaltenem Beleg (Abweichung bis ¾ Zeilenhöhe, nicht bei untereinander stehenden Zeilen gleicher Einrückung). Schlüsselwörter für den Bruttobetrag zusätzlich „Beløb“, „I alt“; ein Betrag ohne Nachkommastellen allein in der Zeile nach dem Schlüsselwort zählt (Konfidenz 60). „685, 88“ wird als 685,88 gelesen. Datum auch TT-MM-JJJJ. Rechnungsnummer auch „Rechnung 37549“. Dänische CVR-Nummer wird als UID `DK…` gelesen. Enthaltene Steuer ohne Prozentangabe („HERAF MOMS 137,18“) ergibt den Satz aus Brutto und Steuer, wenn er einem EU-Satz entspricht. Währung „$“ allein bzw. „kr“ allein ist mehrdeutig (Konfidenz 30): kein Betrag im Euro-Feld, Hinweis zur Währung. Ausnahme (0.13.2, Gerätetest Google-Beleg): „$“ direkt vor einem Betrag mit zwei Nachkommastellen **und** ein US-Merkmal (englisches Monatsdatum „October 15, 2026“, US-Zeitzone PST/PDT/EST…, Zeile beginnt mit „Tax“/„Total“/„Subtotal“) ergibt USD mit Konfidenz 60: Fremdwährung wird vorbelegt (FA-2.21) mit Hinweis „Vorschlag: Währung USD – bitte prüfen“. Lieferant: bekannte Ketten zuerst, dann Kopfzeile mit Rechtsform; sonst ein bekannter Anbieter digitaler Dienste (Google, Apple, Amazon, Microsoft, Meta, Adobe, PayPal, Stripe, Dropbox, Zoom, Spotify, Netflix) als eigenes Wort irgendwo im Text. Steuerzeile mit Betrag ohne Prozent („inkl. MwSt. € 16,50“, „MwSt.“, „USt“, „enthaltene Steuer“, „VAT“, „Tax“ am Zeilenanfang): Satz aus Brutto und Steuer, wenn er einem EU-Satz entspricht (16,50 von 99,00 → 20 %). Beleg ohne Steuerausweis: nur bei Vorsteuerabzug 0 % mit Hinweis „kein Vorsteuerabzug“; für Kleinunternehmer (`AppState.inputVatDeductible` falsch) weder Hinweis noch erzwungener Satz, das Formular behält seinen Vorgabesatz |
| FA-2.29 | **Ausländische Umsatzsteuer** bei Ausgaben: erkannter Satz, den das eigene Land nicht kennt, oder Aussteller-UID aus einem anderen Staat → Steuersatz 0 % vorbelegt mit Hinweis „nicht als Vorsteuer abziehbar“ und dem länderspezifischen Text `TaxProfile.foreignVatHint` (AT: EU-Vorsteuer-Erstattung über FinanzOnline; DE: Vorsteuer-Vergütung beim BZSt; Frist 30.09. des Folgejahres, Mindestbetrag 50 €/400 €, nicht für Kleinunternehmer) (§ 12 Abs. 1 Z 1 UStG 1994, § 15 Abs. 1 Nr. 1 UStG; Prüfpunkte P-S27, P-S30). Seit 0.3.4 gilt als ausländisch: Aussteller-UID aus einem anderen Staat oder ein Satz, den nur ein anderes Länderprofil kennt. Bei Kleinunternehmern belegt die App den erkannten Satz unverändert vor und zeigt den bestehenden Hinweis, dass die Vorsteuer nicht abziehbar ist; sie setzt nicht selbst 0 % |
| FA-2.30 | **Mehrsprachige Erkennung** (0.3.4): Schlüsselwörter für Brutto, Netto, Steuer, Datum, „nicht Belegdatum“ und Rechnungsnummer stehen als Tabellen in `receipt_keywords.dart` für DE, EN, SL, HR, IT, HU, CS, SK, PL, FR, ES, NL, DK, SE, NO (z. B. Skupaj, Ukupno, Totale, Összesen, Celkem, Razem, Totaal, I alt, Summa, Totalt; DDV, PDV, IVA, ÁFA, DPH, PTU, VAT, BTW, MOMS, MVA, TVA, MwSt, USt). Kurze Einträge nur als ganzes Wort. Satz auch nach dem Prozentzeichen („DDV % 22,0“) und mit Dezimalstelle („4,90 %“); die Satzangabe zählt nicht als Betrag. Ein Satz außerhalb der Profile und EU-Sätze gilt nur mit Rechenprobe (Netto + Steuer = Brutto bzw. Steuer zum Brutto). Steuerzeilen mit Rechenprobe gehen einem unsicheren Gesamtbetrag vor (Summe der Zeilen = Brutto), z. B. wenn „Summe“ verdeckt ist. Steuertabelle mit Kopfzeile mit „%“ und Satz ohne Prozentzeichen in der Zeile darunter („22,0  1,62  9,00“, Basis eine Zeile tiefer): Spalten über die Rechenprobe zugeordnet, weil die Kopfwörter oft entstellt sind. Ein Satz eines anderen EU-Staats gilt auch ohne lesbare Aussteller-UID als ausländisch. Datum auch mit gemischtem Trenner „05.09,2026“ und JJJJ.MM.TT.; entstellte Jahreszahl neben einem Datums-Schlüsselwort („03.10.2ULG“) ergibt das Datum im Jahr des Stichtags bzw. im Vorjahr mit Konfidenz 60. Logo-Rauschen bei bekannten Ketten („SPARO“ → SPAR), Rechtsform beendet den Händlernamen |
| FA-2.31 | **Beschreibung und Kategorie vorschlagen** (0.3.4, `ReceiptClassifier`): Branche aus bekannter Kette oder Schlüsselwörtern (Maut/Vignette, Parken, Tankstelle, Taxi, Hotel, Fahrkarte, Supermarkt, Drogerie, Büro, Elektronik, Post, Telefon, Fachliteratur). Beschreibung „Händler – Branche“, bei Handel mit bis zu drei Artikeln, höchstens 60 Zeichen; nur in ein leeres Feld. Kategorie nur aus den Startkategorien und nur, wenn eine Kategorie mit diesem Namen existiert: Maut/Parken/Treibstoff → Kfz-Kosten, Taxi/Hotel/Fahrkarte → Reisekosten, Supermarkt/Drogerie → Sonstige Ausgaben. Beide Felder „erkannt – bitte prüfen“. Neue Belege starten mit „Sonstige Ausgaben“ bzw. „Sonstige Einnahmen“ statt der alphabetisch ersten Kategorie (vorher „Bankspesen“) |
| FA-2.32 | **Beleg ohne Steuerausweis** (z. B. nur Kartenbeleg): kein Satz erkannt, Betrag erkannt, Ausgabe → 0 % („ohne Vorsteuer“) mit Hinweis aus `TaxProfile.noVatShownHint` (AT § 11 Abs 6 UStG, DE § 33 UStDV); die App erfindet keinen Satz (P-S29). Erkannter Satz, den die App nicht kennt: nicht vorbelegen, Hinweis „in der App noch nicht hinterlegt“. Satz vor seinem Gültigkeitsbeginn: nicht vorbelegen, Hinweis „gilt aber erst ab …“ |
| FA-2.20 | Formularfelder **Rechnungsnummer** und **UID des Ausstellers** (Schema 9). Mehrere Steuersätze erkannt: seit 0.7.0 Aufteilung vorbelegt (FA-2.34) |
| FA-2.21 | **Fremdwährung** (L-2.21): nur bei Ausgaben. Erkannte Währung ≠ EUR füllt das Euro-Feld nicht, sondern schaltet das Formular auf Fremdwährung (FA-2.24) mit Betrag laut Beleg. Einnahmen bleiben immer Euro |
| FA-2.24 | **Fremdwährung umrechnen** (L-2.24): Schalter „Beleg in fremder Währung“ bei Ausgaben; Felder Währung (ISO 4217), Betrag laut Beleg, Kurs (Einheiten je 1 €, höchstens 6 Nachkommastellen), Kursquelle, Kursdatum; das Euro-Brutto wird nach GR-9 berechnet und angezeigt, Netto/Steuer nach GR-2 |
| FA-2.25 | **Kurs abrufen** (L-2.25, L-19.29): nur auf Knopfdruck lädt `EcbClient` `eurofxref-hist-90d.xml` (Beleg bis 80 Tage alt) bzw. `eurofxref-hist.xml` direkt bei der EZB, speichert alle Kurse in `ecb_rates` und nutzt danach den Speicher. Standard ist das **Mittel aller EZB-Tageskurse des Belegmonats** (half-up auf 10^-6), gekennzeichnet „EZB-Monatsmittel – Näherung an BMF-Kurs“; im laufenden Monat als vorläufig markiert. Den **Tageskurs** (letzter Kurs am oder vor dem Belegdatum) nutzt die App nur, wenn in den Einstellungen „Tageskurs vom Finanzamt genehmigt“ eingeschaltet ist. Manueller Kurs (Quelle `manual`, `bmf_monthly`, `bank`) jederzeit; ein von Hand geänderter EZB-Kurs wird zu `manual`. Hinweis „EZB-Referenzkurs, ohne Gewähr“ |
| FA-2.26 | **Bankbetrag** (L-2.26): optionales Feld „Tatsächlich abgebucht (EUR)“ (`bank_gross_cents`). `PeriodTotals.expenseFxDifference` = Σ(Bank − umgerechnet); `profit` zieht sie ab, `expensePaidGross` zeigt Ausgaben laut Bank. Vorsteuer, UVA und Umsatz bleiben beim Umsatzsteuer-Kurs |
| FA-2.27 | **Protokoll** (L-2.26): jedes Speichern eines Fremdwährungsbelegs schreibt `audit_log`-Eintrag `fx` mit Währung, Originalbetrag, Kurs, Quelle, Kursdatum, umgerechnetem Betrag und ggf. Bankbetrag mit Differenz |
| FA-2.22 | **Protokoll** (L-2.22): beim Speichern eines ausgelesenen Belegs ein `audit_log`-Eintrag `scan` mit Engine und Version, je Feld erkannter Wert mit Konfidenz, bestätigter Wert und Kennzeichen `GEÄNDERT`, sowie SHA-256 jedes Originalbilds. Keine Bilddaten, kein Volltext |
| FA-2.23 | **Abschaltbar** (L-2.23): Einstellungen → „Belege auslesen“, Standard an (`company_profile.receipt_scan_enabled`) |
| FA-2.33 | **Beleg mit mehreren Steuersätzen aufteilen** (L-2.27, 0.7.0), z. B. Bewirtung Speisen 10 %/Getränke 20 %, Supermarkt 4,9/10/20 %: im Formular „Weiteren Steuersatz hinzufügen“ (volle Breite, 48 dp). Je Teil Satz und **Bruttobetrag**; Netto und Steuer je Teil nach GR-2 (Steuer als Restgröße). Der erste Teil startet mit dem ganzen Betrag, der letzte Teil übernimmt automatisch den Rest (Belegbetrag − übrige Teile), bis er von Hand geändert wird. Speichern nur, wenn die Summe der Teile den Belegbetrag exakt ergibt; sonst Meldung mit Differenz. Teile mit gleichem Satz werden zusammengefasst, Teile mit 0 € entfallen; bleibt ein Teil, ist der Beleg wieder einfach. Bei Fremdwährung sind die Teile Euro-Beträge des umgerechneten Betrags. Belegliste zeigt die Sätze („10 % + 20 %“). Ausländische Steuer und 0 %-Regeln gelten je Teil (FA-2.29). Die Abzugsbeschränkung für Bewirtung (Ertragsteuer, Vorsteuer) setzt die App **nicht** um (P-S46) |
| FA-2.34 | **Belegerkennung mit mehreren Sätzen** (0.7.0): erkennt der Parser mehrere Sätze, belegt die App die Aufteilung (FA-2.33) mit Brutto je Satz vor statt nur eines Hinweises. Je Zeile: eigener, am Belegdatum gültiger Satz → dieser Satz; ausländischer Satz bzw. ausländische Aussteller-UID bei Ausgaben → 0 %; unbekannter Satz oder Fremdwährung → keine Aufteilung, nur Hinweis |
| FA-2.35 | **Codes auf dem Foto** (Lastenheft L-27.1, 0.8.0): dieselbe Erkennung liest QR, Data Matrix und Aztec auf denselben Bildern (Android `com.google.mlkit:barcode-scanning` 17.3.0 gebündelt, iOS `VNDetectBarcodesRequest`) und liefert die Rohinhalte im Feld `codes` des Channels `buchhaltung/receipt_text`. Ein Fehler beim Code-Lesen bricht die Texterkennung nicht ab. Zerlegung in `lib/services/receipt_scan/receipt_codes.dart` (reines Dart): **RKSV** `_R1-AT<n>_` mit 13 Feldern (Detailspezifikation Abschnitt 7, A-SIT-Mustercode `MachineCodeValue`), Beträge brutto mit Komma und Tausenderpunkt, Felder Normal 20 %, Ermäßigt-1 10 %, Ermäßigt-2 13 %, Null 0 %, Besonders (19 % **oder** 4,9 %, P-S49); **TSE** `V0;…;Kassenbeleg-V1;Beleg^B1_…_B5^…` mit IDs 19 %, 7 %, 10,7 %, 5,5 %, 0 % (DSFinV-K Anhang I, P-S50); **EPC069-12** `BCD` Version 001/002 mit IBAN-Prüfziffer; **Link** nur `https` ohne Benutzerangabe. Ein Code, der nicht exakt dem Format folgt, wird verworfen |
| FA-2.36 | **Kassen-QR zuerst** (L-27.2, `ReceiptCodePrefill`): Betrag (Summe der Felder), Datum und Sätze aus dem Code ersetzen die Texterkennung; mehrere Sätze als Aufteilung (FA-2.33). „Besonders“: Satz aus dem Text, wenn dort genau 4,9 % oder 19 % steht; vor dem 01.07.2026 19 %; sonst keine Aufteilung und Hinweis „Steuersatz (4,9 % oder 19 %) bitte wählen“. Code eines anderen Landes als das Profil (z. B. RKSV bei DE-Profil): Betrag und Datum, bei Ausgaben 0 % (FA-2.29). Storno/Nullbeleg: nur Datum. Händler: gelernter Name zur Kasse (Schema 15 `cash_register_merchants`, Schlüssel `AT:<Kassen-ID>` bzw. `DE:<Seriennummer>`, gespeichert beim Speichern des Belegs mit dem bestätigten Partner), sonst aus dem Text. Belegnummer des Codes, wenn der Text keine Rechnungsnummer ergab. Felder aus dem Code tragen statt „erkannt – bitte prüfen“ den Vermerk „vom Kassen-QR“; das Foto bleibt der Beleg |
| FA-2.37 | **Zahlungs-QR** (L-27.3): Empfänger → Partner, Betrag → Brutto, IBAN, BIC und Referenz → Notiz (nur wenn leer); Vermerk „vom Zahlungs-QR“. Gezahlt wird nicht aus der App |
| FA-2.38 | **Teilen-Ziel** (L-27.4): Android `ACTION_SEND`/`ACTION_SEND_MULTIPLE` mit `image/*`, seit 0.9.0 auch `application/pdf`, `application/xml`, `text/xml`; `ShareInChannel.kt` kopiert sofort in den App-Cache (höchstens 20 MB je Datei), Channel `buchhaltung/share_in`. iOS (0.9.0): „Öffnen in …“/„Kopieren nach“ über `CFBundleDocumentTypes` (PDF, XML, Bilder, Rang `Alternate`) und `FlutterSceneLifeCycleDelegate` – keine Share Extension, damit `project.pbxproj` und App Group unverändert bleiben (P-U5). Die Startseite öffnet „Ausgabe erfassen“: Bilder als Seiten mit Erkennung, PDF/XML nach FA-2.39 |
| FA-2.39 | **PDF-Rechnungen** (L-27.5, 0.9.0): `DocumentImporter` liest die Datei (höchstens 20 MB). Eingebettete XML-Dateien (`/Type /EmbeddedFile`, ungefiltert oder `FlateDecode`) liest `PdfEmbeddedFiles` in reinem Dart. Seitenbilder (höchstens 5 Seiten, lange Kante 2000 px) liefert der Channel `buchhaltung/pdf`: Android `PdfRenderer`, iOS PDFKit. Android hat vor API 35 keine Textebene: die Seitenbilder laufen durch die Texterkennung (FA-2.19) samt Codes (FA-2.35). iOS liefert zusätzlich die Textebene (`PDFPage.string`); ab drei Zeilen ersetzt sie die Texterkennung. Paketwahl: keine PDF-Bibliothek – pdfrx (PDFium, mehrere MB je Architektur) und syncfusion_flutter_pdf (kommerzielle Lizenz) verworfen; XML über `package:xml` 7.1 (MIT, reines Dart) |
| FA-2.40 | **E-Rechnung strukturiert** (L-27.6, `EInvoiceParser`, unabhängig vom Namensraum-Präfix): CII (`CrossIndustryInvoice`: ZUGFeRD 2.x, Factur-X, XRechnung-CII; EN 16931 / CEN/TS 16931-3-3), UBL 2.1 (`Invoice`, `CreditNote`: XRechnung-UBL; CEN/TS 16931-3-2), ebInterface 4.x–6.x (`Tax/VAT/VATItem` bzw. `Tax/TaxItem`). Übernommen: Nummer, Datum, Lieferant, UID, Währung, Brutto (GrandTotal/TaxInclusive/TotalGross), je Satz Bemessung und Steuer, IBAN (Prüfziffer). Beträge ohne Gleitkomma auf Cent (kaufmännisch), Sätze mit höchstens einer Promillestelle. DOCTYPE/ENTITY wird abgelehnt. Vorschlag (`ReceiptCodePrefill.fromEInvoice`): Aufteilung je Satz (Brutto = Bemessung + Steuer) nur, wenn die Summe exakt dem Rechnungsbetrag entspricht; Aussteller-UID eines anderen Staats bzw. unbekannter Satz bei Ausgaben → 0 % (FA-2.29); Fremdwährung → FA-2.21; Gutschrift → Hinweis; Beschreibung „Lieferant – Rechnung Nr“; IBAN in die Notiz; Vermerk „aus der E-Rechnung“. XML ohne bekanntes Format wird nicht übernommen |
| FA-2.41 | **Originaldatei aufbewahren** (L-27.8, Schema 16 `receipt_documents`): PDF bzw. XML unverändert im Belegordner (`belege/`, damit in jeder Sicherung, 5.5a), SHA-256 beim Übernehmen, Eintrag erst beim Speichern des Belegs, `audit_log` `document` mit Name, Typ, Größe, Prüfsumme, Quelle. Trigger verbieten Ändern und Löschen. Im Formular je Datei „Original aufbewahrt · SHA-256 …“. Belegliste (8.2) Spalte „Originaldatei“. Ohne Speichern werden die Kopien gelöscht |
| FA-2.42 | **Link-QR** (L-27.7, 0.10.0): steht auf dem Foto ein QR-Code mit `https`-Adresse (ohne Benutzerangabe), zeigt das Belegformular über der Speicherleiste den Streifen `LinkInvoiceStrip`: „QR-Code: Rechnung laden von“ und darunter die **Domain groß** (titleLarge, fett), Knöpfe „Im Browser öffnen“ und „Laden“ (je ≥ 48 dp, 12 dp Abstand) und „Hinweis schließen“ (48 dp). Geladen wird **nur nach Tipp** auf „Laden“ (`LinkInvoiceFetcher`, `dart:io` `HttpClient`, keine Cookies, kein Login, kein WebView): `followRedirects = false`; Weiterleitungen auf derselben Domain bis 5, eine **andere Domain** wird nicht angefragt, sondern im Streifen erneut angezeigt („Weiterleitung – Rechnung jetzt von“) und erst nach erneutem Tipp geladen. Übernommen wird nur ein Inhalt mit PDF-Signatur `%PDF` oder XML (`<?xml`, kein HTML), höchstens 20 MB (Content-Length und beim Lesen), Zeitlimit 30 s. Danach wie eine geteilte Datei (FA-2.39 bis FA-2.41, Quelle „Link ‹Domain›“). HTML, Login oder Fehlerstatus → Meldung „Bitte „Im Browser öffnen““; der Knopf öffnet die Adresse im Systembrowser (Channel `buchhaltung/launcher` `openUrl`, nur `https`) |
| FA-2.43 | **Plattformexporte erkennen** (L-28.1, 0.11.0, `PlatformImportParser`): geteilte bzw. mit „Öffnen mit“ geöffnete Datei mit Endung `.csv`, `.tsv` oder `.txt` (Android `SEND`/`VIEW` mit `text/csv`, `text/comma-separated-values`, `text/tab-separated-values`, `text/plain`, `application/vnd.ms-excel`; iOS „Öffnen in“ für CSV/TSV/Text). Trennzeichen `,` `;` Tab automatisch, UTF-8 mit/ohne BOM, sonst Latin-1; Kopfzeile in den ersten 20 Zeilen (Amazon-Erklärzeilen). Erkannt nach Spaltennamen (normalisiert, ohne Akzente): **Amazon Transaktionsbericht** (Datumsbereich) DE/EN/FR/IT/ES, **Amazon Abrechnung Flatfile V2** (Tab), **PayPal Aktivitäten** (DE/EN/FR/IT/ES), **Shopify** Auszahlungs-Transaktionen und Bestellungen, **Stripe** Saldo-Transaktionen (itemized und klassisch). Beträge ganzzahlig in Cent (`1.234,56`, `1,234.56`, Klammer = negativ), Datum ISO, `TT.MM.JJJJ`, Schrägstrich (Monat zuerst nur, wenn eine Zeile es beweist) oder mit Monatsnamen in fünf Sprachen. Nur EUR: andere Währungen und Amazon-Marktplätze außerhalb des Euroraums (UK, US, PL, SE, TR, CZ) werden gezählt und nicht übernommen. Unbekannte Datei → Meldung „Format nicht erkannt“ |
| FA-2.44 | **Eine Zusammenfassung je Monat** (L-28.2, `PlatformImportScreen`): je Monat „März 2026: 42 Verkäufe 1.230,00 €, Gebühren 210,00 € (Reverse Charge), Werbung …, Auszahlung 1.020,00 €“, darunter dieselben Werte als Zeilen, Hinweise, bei Amazon die Karte „Gebührenrechnung als Beleg ablegen“ (FA-2.48). Unten **ein** Knopf „Übernehmen“ (`PrimaryActionBar`, 56 dp, Telefon volle Breite); Erklärzeile mit Zahl der Buchungen und „Auszahlungen … werden nicht gebucht“. Keine Rückfrage je Zeile |
| FA-2.45 | **Dubletten** (L-28.5, Schema 17): jede Zeile hat eine Kennung je Plattform – PayPal/Stripe Transaktions-ID, Shopify Bestellnummer (`order:#1001`, gleich in Auszahlungs- und Bestellexport), Amazon Abrechnungsnummer + FNV-1a-Prüfsumme der buchungsrelevanten Spalten (ohne Käuferspalten), gleiche Zeilen in einer Datei werden durchgezählt. Schon übernommene Kennungen werden still übersprungen („n Zeilen waren schon übernommen“). Wurde für einen Monat schon ein anderer Amazon-Berichtstyp übernommen, warnt die Zusammenfassung vor doppelten Umsätzen |
| FA-2.46 | **Buchung nach Bruttoprinzip** (L-28.3, Befund Steuerberater, P-S51): je Plattform und Monat ein Sammelbeleg **Einnahme** „‹Plattform› ‹Monat›: n Verkäufe“ (Verkäufe inkl. Versand, Geschenkverpackung, Aktionsrabatte, abzüglich Erstattungen; Kategorie Umsatzerlöse). Umsatzsteuer: Kleinunternehmer 0; sonst Steuer laut Bericht, wenn vorhanden, sonst aus dem Normalsatz herausgerechnet (Annahme Inlandsumsatz, P-S51). Je Monat ein Beleg **Gebühren** (Verkaufs-, Versand-, Abo-, Transaktionsgebühren; Kategorie „Beiträge & Gebühren“ bei Amazon, sonst „Bankspesen“) und ein Beleg **Werbung** („Werbung & Marketing“), jeweils mit Leistendem als Geschäftspartner, ohne ausgewiesene Steuer. **Auszahlungen** sind Geldtransfer und werden nicht gebucht; sonstige Zeilen (Anpassungen, Einbehalte) ebenfalls nicht, mit Hinweis. Mehr Erstattungen als Verkäufe bzw. Gebührengutschriften im Saldo → Hinweis, keine Buchung. Leistende (`FeeSupplier`): Amazon EU S.à r.l. (LU) und Stripe Technology Europe Ltd. bzw. Shopify International Ltd. (IE) → **Reverse Charge** (`receipts.reverse_charge = 1`); PayPal (Europe) S.à r.l. et Cie, S.C.A. (LU) → steuerfreier Finanzumsatz ohne Reverse Charge (P-S54) |
| FA-2.47 | **Warnungen** (L-28.4, L-28.5): **OSS**, wenn Verkäufe und Erstattungen eines Kalenderjahres in andere EU-Länder als das eigene (Bestimmungsland = Amazon-Marktplatz bzw. Shopify-Lieferland; PayPal und Stripe ohne Land) 10.000 € übersteigen (`ossThreshold`, Art 59c MwStSystRL, AT Art 3 Abs 5 UStG 1994, DE § 3c Abs 4 UStG; P-S53); **Versand durch Amazon** (FBA/AFN) → Hinweis auf Lager in anderen Ländern (Pan-EU), nur Warnung; vom Marktplatz einbehaltene Steuer; Reverse Charge für Kleinunternehmer („schuldest du die Umsatzsteuer darauf, ohne Vorsteuerabzug, UID nötig“) |
| FA-2.48 | **Gebührenrechnung als eigener Beleg** (L-28.7): bei Amazon zeigt die Zusammenfassung „Gebührenrechnung als Beleg ablegen“ mit Knopf „Gebührenrechnungen öffnen“ (48 dp, Systembrowser, `https://sellercentral.amazon.de/tax/seller-fee-invoices`); die PDF wird über Teilen als Beleg übernommen (FA-2.39) |
| FA-2.49 | **Datensparsamkeit** (L-28.6, P-R36): gelesen werden nur benannte Spalten (Datum, Typ, Bestell-/Transaktionsnummer, SKU, Beträge, Währung, Marktplatz bzw. Lieferland, Versandart). Name, Adresse, Ort, PLZ, Region, E-Mail, Telefon der Käufer werden nie angesprochen und weder gespeichert noch protokolliert; die geteilte Datei bleibt nur im Cache. Geprüft in `platform_import_test.dart` über alle Tabellen der Datenbank |
| FA-2.50 | **Lernen je Lieferant** (L-2.28, 0.16.0, `SupplierLearning`, Schema 20 `supplier_memory`): beim Speichern jedes Belegs merkt sich die App bestätigten Partnernamen, Kategorie, Steuersatz (Hauptsatz), Währung und Zahlungsart je Richtung unter der Aussteller-UID, dem normalisierten bestätigten Namen und der normalisierten erkannten Schreibweise (Zuordnung OCR-Variante → gewählter Name). Normalisierung: klein, ä/ö/ü → a/o/u, ß → ss, nur Buchstaben und Ziffern, Rechtsformen (GmbH, KG, e.U., AG …) entfernt, 0 → o. Beim Auslesen (FA-2.19, nach Kassen-QR FA-2.36) wird zuerst über die UID, dann über den Namen nachgeschlagen. Vorrang: Name, Kategorie und Zahlungsart immer gelernt; Steuersatz erkannt vor gelernt (gelernt nur ohne erkannten Satz); Fremdwährung gelernt nur bei Ausgaben, wenn die Erkennung keine sichere Währung fand (Konfidenz < 60). Felder Partner, Kategorie und Zahlungsart tragen dann „wie beim letzten Mal“; Steuersatz und Währung ohne eigenen Vermerk. Gelernte Kategorie nur, wenn sie noch existiert. Teil der Belegerkennung (Pro, 5.10 Lastenheft); nichts verlässt das Gerät |
| FA-2.18 | **Stornierte Belege lesbar**: Filter „Storniert“ in der Belegliste; die Ansicht ist schreibgeschützt (Hinweisbanner, kein Speichern), Kommentare bleiben anhängbar |

### 5.3 Kassabuch und Auswertung

| ID | Anforderung |
|---|---|
| FA-3.1 | Zeiträume: dieser Monat, letzter Monat, dieses Quartal, dieses Jahr, letztes Jahr. „Jahr“ ist das Wirtschaftsjahr (GR-10); bei abweichendem Wirtschaftsjahr heißen die Chips „Dieses WJ (2027)“ und „Letztes WJ (2026)“ |
| FA-3.2 | Anzeige von Einnahmen netto, Ausgaben netto und Ergebnis; das Ergebnis enthält Kursdifferenzen laut Bank (FA-2.26). Ausgewertet wird je Steuersatzzeile (`receipt_vat_lines`). **Kleinunternehmer** haben keinen Vorsteuerabzug: Ausgaben zählen **brutto** („Ausgaben (brutto)“), Vorsteuer 0, auch in Export und UVA-Zusammenfassung (AT § 12 iVm § 6 Abs 1 Z 27 UStG 1994; DE § 19 Abs 1 UStG, § 9b Abs 1 EStG; P-S47). Maßgeblich ist die aktuelle Einstellung, nicht die des Belegjahres |
| FA-3.3 | Bei Regelbesteuerung: Umsatz je Steuersatz, Umsatzsteuer, Vorsteuer, Zahllast oder Guthaben. **Reverse Charge** (0.11.0, FA-2.46): Belege mit `reverse_charge` zählen netto als Ausgabe; die Steuer rechnet die Auswertung je Beleg zum Normalsatz des Landes (`TaxProfile.standardVatPermille`) und zeigt sie mit Kennzahlen aus `TaxProfile.reverseCharge`: AT Kz 057 Steuer, Kz 066 Vorsteuer (§ 19 Abs 1 zweiter Satz iVm § 3a Abs 6 UStG 1994); DE Kz 46 Bemessungsgrundlage, Kz 47 Steuer, Kz 67 Vorsteuer (§ 13b Abs 1 und 5 UStG); P-S52. Zahllast = Umsatzsteuer − Vorsteuer + RC-Steuer − RC-Vorsteuer |
| FA-3.4 | Bei Kleinunternehmern entfällt die Umsatzsteuerauswertung mit Erklärung – außer bei Reverse Charge: dann Karte mit RC-Kennzahlen, Vorsteuer 0 und Zahllast (Steuerschuld ohne Vorsteuerabzug, P-S52) |
| FA-3.5 | Balkenverlauf über die letzten sechs Monate, Einnahmen und Ausgaben getrennt; ein Betrag > 0 ist mindestens 6 dp hoch, damit eine kleine Ausgabe neben einer großen Einnahme sichtbar bleibt |
| FA-3.7 | Reihenfolge der Übersicht: Hinweise, Kleinunternehmergrenze, Zeitraum, Einnahmen/Ausgaben, Umsatzsteuer, Verlauf, Letzte Belege, **Termin-Box am Ende** (0.7.0). Nur der jüngste Ladevorgang zeigt sein Ergebnis an (kein Überschreiben neuer Summen durch einen älteren Lauf) |
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
| FA-5.2 | Kunde löschen ist blockiert, solange Rechnungen oder Angebote darauf verweisen |
| FA-5.3 | Positionen mit Bezeichnung, Menge, Einheit, Einzelpreis netto, Steuersatz |
| FA-5.4 | Die Rechnungsnummer wird **erst beim Ausstellen** vergeben, nicht beim Entwurf |
| FA-5.5 | Die Nummer wird beim Ausstellen **in derselben Transaktion** gezogen, in der die Rechnung gespeichert wird; ein Abbruch hinterlässt keine Lücke, zwei gleichzeitige Ausstellungen erhalten verschiedene Nummern |
| FA-5.5a | Der Schreibschutz gestellter Rechnungen gilt auch in der Datenschicht: `InvoiceRepository.save` lehnt das Überschreiben einer gestellten Rechnung ab |
| FA-5.6 | Vor dem Ausstellen prüft die App: Kunde, vollständige Kundenanschrift, mindestens eine Position, Bezeichnung je Position, Liefer-/Leistungsdatum, Stammdaten-Pflichtangaben |
| FA-5.7 | Fehlt etwas, ist der Knopf *Rechnung ausstellen* gesperrt und die Liste des Fehlenden sichtbar |
| FA-5.8 | Bei Kleinunternehmern entfällt die Steuerspalte vollständig und der gesetzliche Hinweistext erscheint |
| FA-5.9 | PDF im A4-Format mit allen Pflichtangaben, mehrseitig lauffähig |
| FA-5.10 | Teilen über den Systemdialog |
| FA-5.11 | Nur Entwürfe sind löschbar; gestellte und bezahlte Rechnungen werden durch eine **Stornorechnung** storniert (GR-14, FA-5.31). Die frühere reine Statusänderung entfällt; vor 0.13.0 so stornierte Rechnungen bleiben ohne Stornobeleg „Storniert“ |
| FA-5.31 | **Stornieren** (Menü ⋮ der Rechnungskarte, Fehlerfarbe nach Trennlinie): Bottom-Sheet mit Betrag, Grund als Vorschlag mit einem Tipp („Fehler in der Rechnung“, „Auftrag storniert“, „Rechnung doppelt gestellt“, vorbelegt der erste, frei änderbar, Pflicht), Datum (vorbelegt heute; bei bezahlter Rechnung „Storno und Rückzahlung am“) und Hinweis, was gebucht wird; Knopf „Stornorechnung erstellen“ 56 dp volle Breite unten. Danach Hinweis mit „PDF senden“. Karte des Originals: „storniert durch <Nummer>“, der Stornorechnung: Status „Storno“, „Storno zu <Nummer>“, Betrag negativ |
| FA-5.32 | **Korrigieren** (Menü ⋮): wie FA-5.31, Knopf „Stornieren und neu schreiben“; danach öffnet sich ein neuer Entwurf als Kopie (Kunde, Positionen, Rabatt, Versand, Skonto, Hinweise; Rechnungsdatum heute, Zahlungsziel mit gleichem Abstand; `InvoiceCancellation.correctionDraft`). Nummer und Snapshots entstehen beim Ausstellen neu |
| FA-5.33 | **PDF der Stornorechnung** (Sie-Form, `InvoiceTexts`): Titel „Stornorechnung <Nummer>“, Kopf „Storno zu“ und „vom“, Mengen und Beträge negativ, Steuer je Satz negativ, Bezugssatz „Diese Stornorechnung hebt die Rechnung … vom … vollständig auf …“, Grund, bei bezahltem Original „Den bereits bezahlten Betrag von … erstatten wir Ihnen.“, sonst „Bitte überweisen Sie den Betrag der Rechnung nicht mehr …“. Dateiname `Stornorechnung_<Nummer>.pdf` |
| FA-5.34 | **Beenden und Zurück** (0.13.1, Gerätetest 0.13.0): Leiste im bearbeitbaren Formular „Beenden“ / „Rechnung ausstellen“, nach dem Ausstellen bzw. bei gestellter Rechnung „Beenden“ / „PDF senden“ (beide 56 dp, gleiche Leiste, Primärknopf rechts im Daumenbereich). Nach dem Teilen-Blatt bleibt die Rechnung offen; „Beenden“ führt zur Liste. „Beenden“, Zurück-Pfeil und System-Zurück speichern Änderungen als Entwurf (Vergleich mit dem Stand beim Öffnen; ein nie gespeicherter Entwurf, z. B. Korrekturentwurf, gilt als geändert). Fehlt für das Speichern noch etwas (z. B. Kunde), fragt ein Dialog einmal: „Weiter bearbeiten“ (Primär) oder „Verwerfen“. Nichts wird still verworfen. Prüfpunkt P-X9 |
| FA-5.35 | **Teilen auf Android** (0.13.1): PDF und CSV über den eigenen Kanal `buchhaltung/share_out` (`ShareOutChannel.kt`, `GeteiltFileProvider`, Authority `<applicationId>.geteilt`, Pfad `files/geteilt/`), `ACTION_SEND` mit `EXTRA_STREAM`, `EXTRA_SUBJECT`, `EXTRA_TEXT`, `ClipData`, `FLAG_GRANT_READ_URI_PERMISSION`, `Intent.createChooser`. Dateien bleiben liegen und werden nach 30 Tagen beim nächsten Teilen gelöscht. Grund: share_plus 10 kopiert nach `cache/share_plus` und leert diesen Ordner bei jedem Teilen; Gmail lädt Anhänge später hoch, beim Empfänger kam „Download fehlgeschlagen“. iOS bleibt bei share_plus. Prüfpunkt P-D29 |
| FA-5.12 | *Bezahlt* fragt den Zahlungseingang (vorbelegt heute, änderbar), setzt `paid_at` und bucht die Einnahme je Steuersatz an diesem Tag (GR-11). Vor Schema 11 bezahlte Rechnungen bucht die App beim Start einmal nach (`paid_at`, sonst Rechnungsdatum). Hinweis im Dialog: nicht zusätzlich als Einnahmebeleg erfassen |
| FA-5.13 | Eine gestellte Rechnung mit überschrittener Fälligkeit wird als überfällig gekennzeichnet; die Rechnungsliste zeigt oben „n Rechnungen überfällig – mahnen?“ und auf der Karte den Tonal-Knopf „Erinnern“ bzw. „Mahnen“ (L-3.10) |
| FA-5.14 | Die Übersicht zeigt die Summe der gestellten, nicht bezahlten Rechnungen |
| FA-5.15 | Rabatt je Position und auf die Rechnung, Prozent oder Betrag, eingeklappt („Rabatt hinzufügen“, Bottom-Sheet mit „% / €“); Gesamtrabatt anteilig je Satz (GR-12, L-3.21) |
| FA-5.16 | Versandkosten (eingeklappt) mit Satz „wie Hauptleistung (automatisch)“ oder festem Satz (GR-12, L-3.22) |
| FA-5.17 | Skonto als Schalter mit Prozent und Tagen, vorbelegt aus dem Profil; PDF: „Zahlbar bis <Fälligkeit> ohne Abzug. Bei Zahlung bis <Datum> <p> % Skonto (= <Betrag>).“ (L-3.23) |
| FA-5.18 | „Bezahlt“ als Bottom-Sheet mit Zahlungsdatum und, bei Skonto, Schalter „Mit Skonto bezahlt?“ (vorbelegt Ja innerhalb der Frist); Einnahme je Satz um anteiliges Skonto gemindert (GR-12, L-3.24) |
| FA-5.19 | AGB-Adresse im Profil; Verweis „Es gelten unsere Verkaufsbedingungen, abrufbar unter <URL>, soweit sie vereinbart wurden.“ auf dem PDF; eingefroren in `seller_snapshot`; einmaliger Hinweis beim ersten Eintragen (L-3.25, L-3.26) |
| FA-5.21 | Mahnen beliebig oft: Stufe 1 „Zahlungserinnerung“, danach „1. Mahnung“, „2. Mahnung“ …; Bottom-Sheet mit Vorschau (Frist +`dunning_period_days`, Mahnkosten, Zinsen, Pauschale, Gesamt, Text), ein Tipp „… erstellen und senden“ erzeugt das PDF, speichert die Momentaufnahme mit SHA-256 und öffnet den Teilen-Dialog; Storno mit Pflicht-Begründung (L-3.10, L-3.29) |
| FA-5.22 | Mahnkosten 10,00 € je Mahnung ab der 1. Mahnung, Zahlungserinnerung kostenlos, änderbar; bei Privatkunden mit Kosten > 0 Hinweis „Bei Privatkunden sind nur angemessene, tatsächlich entstandene Mahnkosten zulässig – 10 € können zu hoch sein.“ (L-3.27, P-R32) |
| FA-5.23 | Verzugszinsen optional mit gesetzlichem Vorschlag (GR-13), Pauschale 40 € nur bei Unternehmen; Standardwerte in den Stammdaten (L-3.27) |
| FA-5.24 | Kundenmerkmal „Unternehmen“ (Schalter, folgt der UID bis zur ersten eigenen Wahl); DE: Rechnungen an Privatkunden tragen den Hinweis nach § 286 Abs 3 BGB aus `TaxProfile.dunning.consumerDefaultNotice` (L-3.28) |
| FA-5.25 | „Bezahlt“ fragt bei vorhandener Mahnung „Mahnkosten und Zinsen mitbezahlt?“; Ja bucht die Kosten des letzten nicht stornierten Schreibens als nicht umsatzsteuerbare Einnahme (GR-13, L-3.30) |
| FA-5.26 | **Neue Zahlungsfrist** (0.7.0): jedes Schreiben setzt eine neue Frist (im Sheet vorbelegt +`dunning_period_days`, änderbar), die im Text steht und in `dunning_notices.new_due_date` an der Rechnung gespeichert ist; die Rechnung selbst bleibt unverändert (GR-8). „Überfällig“, Banner „mahnen?“ und „Erinnern/Mahnen“ erscheinen erst ab dem Tag nach der maßgeblichen Frist (letztes nicht storniertes Schreiben, sonst Fälligkeit; `DunningService.needsReminder`) |
| FA-5.27 | **Mahnsymbol** in der Rechnungsliste: Badge mit Stufe „Erinnert“, „1. Mahnung“, „2. Mahnung“ … und neuer Frist, ≥ 48 dp; Tipp zeigt den Mahnverlauf (Rechnung, jedes Schreiben mit Datum, Betrag, Frist, Storno) als Bottom-Sheet |
| FA-5.28 | **Anrede in Kundendokumenten** (0.7.0): Rechnung, Mahnschreiben und Begleittext beim Senden in Sie-Form („Bitte überweisen Sie …“, „Falls Sie bereits bezahlt haben …“), Texte zentral in `InvoiceTexts`; die App-Oberfläche duzt weiter. Umschaltbarkeit offen (Entscheidung der Auftraggeberin) |
| FA-5.29 | Hinweis im Rechnungsformular, wenn das Leistungsdatum nach dem Rechnungsdatum liegt: „Leistungsdatum liegt nach dem Rechnungsdatum – stimmt das?“ – kein Blocker |
| FA-5.30 | **PDF-Schrift** (0.7.0): alle PDFs (Rechnung, Mahnung) betten Work Sans (SIL OFL 1.1, `assets/fonts/`, Lizenz `OFL.txt`) ein; €, „–“, „“ und Umlaute sind echte Glyphen (vorher Helvetica ohne €, Gerätetest 0.6.0). Lizenzprüfung P-L19 |
| FA-5.20 | Bedienung (UX-Prüfinstanz): Primärleiste `PrimaryActionBar` 56 dp unten über der Tastatur mit „Beenden“ / „Rechnung ausstellen“, nach dem Ausstellen „Beenden“ / „PDF senden“ (FA-5.34); „Position hinzufügen“ volle Breite; Zielflächen ≥ 48 dp; Rechnungskarte mit Tonal-Knopf „Bezahlt“; Stornieren/Löschen im Menü nach Trennlinie in Fehlerfarbe mit Bestätigung (Nummer, Betrag) |

**Angebote und Artikel** (0.15.0; Lastenheft L-3.13 bis L-3.17, L-11.1,
L-11.2, L-11.5, L-11.6, L-11.9, L-11.11; Tarif: beides Basis, PDF senden Pro
wie bei Rechnungen, Lastenheft 5.10):

| ID | Anforderung |
|---|---|
| FA-5.40 | **Angebot** (`domain/offer.dart`, `OfferRepository`): Kunde, Angebotsdatum, „Gültig bis“ (vorbelegt +`spec.offer_validity_days`), Positionen wie Rechnungspositionen samt Positionsrabatt, Anmerkungen. Nummer `spec.offer_number_pattern` aus eigenem Kreis je Kalenderjahr, gezogen beim ersten Speichern in derselben Transaktion; unabhängig von `next_invoice_sequence`. Neues Angebot speichern braucht `Feature.newBookings` (ab Basis) |
| FA-5.41 | **Status:** Entwurf → Gesendet (automatisch nach „PDF senden“) → Angenommen (nur durch Umwandeln) oder Abgelehnt („Kundin hat abgelehnt“, rückgängig mit „Wieder öffnen“). Offene Angebote (Entwurf, Gesendet) gelten nach „Gültig bis“ als **Abgelaufen** (`Offer.statusOn`, nicht gespeichert). Angenommene Angebote sind schreibgeschützt, auch in der Datenschicht; nur nicht angenommene sind löschbar |
| FA-5.42 | **Keine steuerliche Wirkung** (L-3.14): Angebote erzeugen keine Belege, zählen nicht im Kassabuch, nicht in der UVA und nicht in der Grenzwertüberwachung; Export und Auswertungen lesen sie nicht |
| FA-5.43 | **In Rechnung umwandeln** mit einem Tipp („Zur Rechnung machen“, L-3.15): `OfferRepository.convertToInvoice` legt in einer Transaktion einen Rechnungsentwurf an (Kunde, Positionen, Anmerkungen kopiert; Datum und Leistungsdatum heute, Fälligkeit nach Zahlungsziel des Profils; Kleinunternehmerstatus aktuell) und setzt das Angebot auf Angenommen mit Verweis `invoice_id`. Der Entwurf öffnet sich sofort und bleibt bis zum Ausstellen änderbar. Ein zweiter Tipp („Rechnung öffnen“) öffnet denselben Entwurf |
| FA-5.46 | **Angebots-PDF** (`InvoicePdf.offer`, L-3.17, L-3.31): Titel „Angebot <Nummer>“, nie „Rechnung“; Kopf „Angebot für“, „Angebotsnummer“, „Angebotsdatum“, „Gültig bis“; statt Zahlungsangaben „Dieses Angebot ist gültig bis <Datum>. Wir freuen uns auf Ihren Auftrag.“ (Sie-Form) und AGB-Verweis; Kleinunternehmerhinweis wie bei Rechnungen. Logo nach FA-13.12. „PDF senden“ mit Tarifschnitt `pdfSending` (FA-13.11) |
| FA-5.44 | **Artikel** (`domain/article.dart`, `ArticleRepository`): Bezeichnung, Einzelpreis netto, Einheit, Steuersatz (bei Kleinunternehmern ausgeblendet), freiwillig Artikelnummer (eindeutig, L-11.2) und kurze Beschreibung. Liste mit Suche nach Bezeichnung oder Nummer ab sechs Artikeln (L-11.9). Kein Lagerstand (L-11.3 ist Stufe B) |
| FA-5.45 | **Position übernehmen** (L-11.5, L-11.6): Knopf „Aus Artikeln und Vorschlägen“ in Rechnung und Angebot öffnet ein Bottom-Sheet; oben die Artikel, darunter früher verwendete Positionen aus Rechnungen (ohne Stornorechnungen) und Angeboten, je Bezeichnung die zuletzt verwendete, ohne Dubletten zu Artikeln. Ein Tipp übernimmt Bezeichnung (mit Beschreibung), Einheit, Preis, Steuersatz, Menge 1 und ersetzt eine leere letzte Position; alles bleibt änderbar. Freie Positionen bleiben jederzeit möglich. Suchfeld unten im Sheet ab sechs Vorschlägen |
| FA-5.47 | **Erreichbarkeit** (UX-Prüfinstanz): Rechnungsliste oben zwei gleich breite Knöpfe „Angebote“ und „Artikel“ (48 dp); Angebotsformular unten `PrimaryActionBar` mit „PDF senden“ und „Speichern“ bzw. „Zur Rechnung machen“; Listenzeilen ≥ 56 dp; Zurück speichert ein gespeichertes Angebot still, ein neues mit Eingaben fragt einmal (wie FA-5.34). Geräteprüfung P-U8 |

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
| FA-7.10 | Schlüssel: 256 Bit zufällig, gespeichert über `flutter_secure_storage` (iOS `first_unlock_this_device`, nicht synchronisiert); **Wiederherstellungscode** (Base32, 52 Zeichen in 13 Vierergruppen) nur als lokal erzeugtes **Druckblatt** (PDF mit Blöcken, QR-Code und Aufbewahrungshinweis, `RecoveryCodeSheet`) über Teilen/Drucken; die App zeigt den Code nicht an und behält keine Kopie (L-22.21). Danach Bestätigung durch Abtippen von **zwei zufälligen, verschiedenen Blöcken** vom Druckblatt (`RecoveryCodeChallenge`, Verwechsler 0/1/8 egal); erst dann „Code ist aufbewahrt“ (L-22.22). Bildschirm `recovery_code_setup_screen.dart`, Knopf unten in der `PrimaryActionBar`. Ausschalten löscht den Schlüssel |
| FA-7.11 | Sicherungsformat 2 (`JBBK`, Version 2, Modus 1, Nonce, Chiffrat, Tag) für Schlüssel-Sicherungen; Format 1 (Kennwort) bleibt lesbar. Wiederherstellen akzeptiert Kennwort **oder** Wiederherstellungscode |
| FA-7.12 | Fällig, wenn eingeschaltet, Ordner gewählt und seit der letzten automatischen Sicherung eine Änderung im `audit_log` steht, frühestens nach **24 Stunden** (`spec.auto_backup_min_interval_hours`); ausgelöst beim Start und bei Rückkehr in die App |
| FA-7.13 | Nach dem Schreiben: zurücklesen, SHA-256 vergleichen, entschlüsseln, entpacken. Erst dann `auto_backup_last_at` und Protokoll `auto_backup` mit Prüfsumme; sonst `auto_backup_last_error` und Banner auf der Übersicht |
| FA-7.14 | Rotation im Ordner nur für eigene Dateien `Auto-Sicherung_JJJJ-MM-TT_HHMMSS.jbbackup`: die letzten **7**, je Monat die jüngste der letzten **12** Monate, **je Kalenderjahr die jüngste dauerhaft** (`spec.auto_backup_keep_daily`, `spec.auto_backup_keep_monthly`) |
| FA-7.15 | „Sicherung prüfen" entschlüsselt die jüngste automatische Sicherung, ohne etwas zu ersetzen; Protokoll `verify` |
| FA-7.16 | **iCloud-Sicherung unter iOS** (L-7.17, L-7.18, L-7.20, 0.16.0): ist iCloud angemeldet und für die App erlaubt (`icloudAvailable` im Channel `buchhaltung/backup_folder`), richtet „Einrichten“ die automatische Sicherung ohne Ordnerwahl im App-eigenen iCloud-Drive-Container ein (iCloud Documents, kein CloudKit; Unterordner `Documents`, in der Dateien-App als „JeNi bucht“ sichtbar, `NSUbiquitousContainers`). Gespeichert wird statt eines Bookmarks die Kennung `icloud`; Anzeige „iCloud Drive › JeNi bucht“. Container-ID `iCloud.<Bundle-ID>` nur in `ios/Runner/Runner.entitlements` und `Info.plist`, abgeleitet aus `PRODUCT_BUNDLE_IDENTIFIER` (O-33); der Swift-Code nimmt den ersten Container der Entitlements. Nicht geladene Dateien (`.Name.icloud`) erscheinen unter ihrem Namen; Lesen über `NSFileCoordinator` lädt sie. Ohne iCloud: Ordnerwahl wie FA-7.9 (L-7.18); mit iCloud und anderem Ordner zusätzlich „In iCloud sichern“, „Ordner ändern“ öffnet immer die Ordnerwahl. Verschlüsselung, Probe, Rotation unverändert (FA-7.10 bis FA-7.14). **Wiederherstellen aus der Liste** (beide Plattformen): „Wiederherstellen“ zeigt die automatischen Sicherungen im Ordner, neueste zuerst; ein Tipp öffnet sie mit dem Schlüssel dieses Geräts, sonst mit Kennwort oder Wiederherstellungscode, dann Vorschau und Bestätigung wie FA-7.4 |

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
| FA-6.1 | Zeitraum wählbar: Jahr, Quartal oder Monat. „Ganzes Jahr“ ist das Wirtschaftsjahr (bei abweichendem WJ „Wirtschaftsjahr“, Auswahl „WJ 2027“); Quartale und Monate bleiben Kalenderzeiträume der Umsatzsteuer |
| FA-6.2 | Vorschau mit Belegzahl und Summen **vor** dem Teilen |
| FA-6.3 | Bei leerem Zeitraum ist der Export gesperrt und ein Hinweis sichtbar |
| FA-6.4 | DATEV wird nur bei Land DE angeboten, BMD nur bei Land AT |
| FA-6.5 | Dateiname enthält Firma und Zeitraum |
| FA-6.6 | CSV mit Semikolon, CRLF und UTF-8-BOM |
| FA-6.7 | Belegliste mit Seitenzahl und allen Kommentaren samt Zeitpunkt; DATEV und BMD hängen den jüngsten Kommentar gekürzt an den Buchungstext an (`Beschreibung / K: …`, höchstens 60 Zeichen) |

### 5.6a Wirtschaftsjahr und Steuertermine

Lastenheft L-24 und L-25. Termine in `lib/services/deadline_calculator.dart`,
Regeln je Land in `TaxProfile.deadlineRules` (`spec.*.deadline_rules`),
Feiertage in `lib/domain/holidays.dart`.

| ID | Anforderung |
|---|---|
| FA-10.1 | Stammdaten, Abschnitt „Wirtschaftsjahr und Termine“ (nicht im Onboarding): „Erster Monat Wirtschaftsjahr“, Standard Jänner/Januar |
| FA-10.2 | Monat ≠ Jänner nur nach einmaliger Bestätigung mit dem Text aus `TaxProfile.fiscalYearConfirmation` (AT: Firmenbuch, bilanzierend, Zustimmung FA; DE: Handelsregister, Einvernehmen FA); danach dauerhafter Hinweis unter der Auswahl. Prüfpunkt P-S32 |
| FA-10.3 | Termin-Box „Nächste Termine“ auf der Übersicht: die nächsten **4** Termine (`spec.deadline_box_count`) mit Bezeichnung, Datum und „in n Tagen“; Tipp zeigt die Rechtsgrundlage. Nur Anzeige, keine Benachrichtigung |
| FA-10.4 | Darunter: „Berechnete Termine zur Orientierung, ohne Gewähr. Maßgeblich sind Bescheid, Finanzamt bzw. deine Steuerberatung.“ (P-R24) |
| FA-10.5 | Fällt ein Termin auf Samstag, Sonntag oder Feiertag, gilt der nächste Werktag (`spec.*.deadline_shift_legal_ref`). AT: bundeseinheitliche Feiertage plus Karfreitag und 24.12. (§ 108 Abs 3 BAO), kein Bundesland. DE: bundesweite Feiertage plus Landesfeiertage des gewählten Bundeslands (`spec.*.asks_federal_state`). Ostern nach der Gaußschen Formel |
| FA-10.6 | Voranmeldung nur bei Regelbesteuerung. Rhythmus „Vorschlag“ aus dem Vorjahr: AT Vorjahresumsatz über 100.000 €, DE Vorjahressteuer über 9.000 € → monatlich, sonst vierteljährlich (`spec.*.monthly_vat_return_threshold_cents`, `spec.*.vat_interval_basis`; P-S33); immer Kalenderjahr |
| FA-10.7 | AT: UVA 15. des zweitfolgenden Monats, ZM Ende des Folgemonats, ESt-Vorauszahlung 15.2./15.5./15.8./15.11., Erklärung 30.06. Folgejahr (FinanzOnline), SVS Ende Feb./Mai/Aug./Nov. als „ca.“ ohne Verschiebung (P-S34). DE: UStVA 10. nach Zeitraum (+1 Monat Dauerfristverlängerung), ZM 25. nach Zeitraum, ESt-Vorauszahlung 10.3./10.6./10.9./10.12., Erklärung 31.07. Folgejahr. ZM-Zeitraum folgt dem Voranmeldungsrhythmus (Vereinfachung, P-S33) |
| FA-10.8 | Mit Steuerberatung keine Erklärungsfrist, sondern „Steuererklärungen JJJJ: Frist laut Kanzlei“ |

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

### 5.7a Einhandbedienung

Maßstab: `docs/DESIGN_SPEC.md` Abschnitt 5a (Prüfregel 1–12, symmetrisch für
beide Hände, keine Händigkeits-Einstellung).

| ID | Anforderung |
|---|---|
| FA-12.1 | Übersicht: ein zentrierter, verlängerter Knopf „Beleg fotografieren“ (`centerFloat`, 56 dp), öffnet das Belegformular mit Kamera; Einnahme/Ausgabe im Formular |
| FA-12.2 | Zerstörende Aktionen nicht in der AppBar: Beleg stornieren und Kunde löschen als rot umrandeter Bereich am Formularende (`DangerZone`, ≥ 24 dp Abstand zur Speicherleiste); Bestätigung mit Verb-Knopf in Fehlerfarbe (`confirmDestructive`), ebenso „Automatische Sicherung ausschalten“ und „Wiederherstellen“ |
| FA-12.3 | Belegseiten: Pfeile 48 dp mit 8 dp Abstand; Löschen einer neuen Seite über Antippen → Bottom-Sheet „Seite löschen“ mit Bestätigung |
| FA-12.4 | Chip-Reihen (Übersicht Zeitraum, Belegliste Filter) umbrechen (`Wrap`); das Jahr der Belegliste ist der erste Chip (Auswahl im Bottom-Sheet) statt AppBar-Menü |
| FA-12.5 | Belegdatum mit Schnellchips „Heute“ / „Gestern“ |
| FA-12.6 | Kunden- und Stammdatenformular speichern über `PrimaryActionBar` |
| FA-12.7 | **Links und rechts gleich** (Entscheidung der Auftraggeberin 2026-10-14, 0.7.0): Belegliste „Beleg erfassen“, Rechnungsliste „Neue Rechnung“ und Kundenliste „Neuer Kunde“ als zentrierter, verlängerter Knopf (`centerFloat`, 56 dp) statt Plus rechts unten. Rechnungskarte: Aktionsleiste über die volle Breite mit „Erinnern/Mahnen“, „Bezahlt“ und „PDF senden“ (dritter Knopf in eigener Zeile); Stornieren/Löschen bleiben im Menü. Einstellungsseiten dürfen rechtslastig bleiben |

### 5.8 Hilfe

Lastenheft L-26. Stufe 1: offline, ohne Server, ohne neues Paket. Suche in
`lib/services/help/help_index.dart`, Bildschirm `lib/features/help/help_screen.dart`,
Support-Mail `lib/services/help/support_mail.dart`. **Stufe 2** (Antworten
durch ein KI-Modell auf einem Server) ist nicht gebaut und wartet auf die
Server-Entscheidung; Prüfpunkte P-R25, P-R26.

| ID | Anforderung |
|---|---|
| FA-11.1 | **Hilfe-Symbol** (Fragezeichen, Tooltip „Hilfe“) in der AppBar rechts auf Übersicht, Belege, Rechnungen, Export, Einstellungen, Beleg- und Rechnungsformular. Nicht als FAB: unten rechts liegen bereits die Erfassungsknöpfe (Übersicht zwei, Listen ein Plus) in der Daumenzone, die der Hauptaktion vorbehalten ist (DESIGN_SPEC „Hauptaktion in Daumenreichweite“); Hilfe ist eine seltene Nebenaktion und darf oben liegen, wo auch das Zahnrad sitzt |
| FA-11.2 | **Suche** im Benutzerhandbuch: `docs/BENUTZERHANDBUCH.md` ist selbst als Asset eingebunden (pubspec.yaml) – keine Kopie, kein zweiter Text. Zerlegung in `##`/`###`-Abschnitte; in „Häufige Fragen“ und „Wenn etwas nicht geht“ ist jede fett gesetzte Frage bzw. Meldung ein eigener Treffer; „Inhalt“ entfällt. Rangfolge BM25 (k1 1,2, b 0,75), Überschrift dreifach gewichtet, Normalisierung Kleinschreibung, ä/ö/ü/ß, Füllwörter, einfache Endungs-Stammbildung, Präfixtreffer für zusammengesetzte Wörter, Synonyme mit Gewicht 0,6 (z. B. „löschen“ → „stornieren“, „Backup“ → „Sicherung“, „MwSt“ → „Umsatzsteuer“). Treffer zeigen Überschrift, Kapitel und Auszug; Tipp öffnet den Abschnitt mit eigenem Markdown-Darsteller (Absätze, Listen, fett, kursiv, Code, Tabellenzeilen), Text auswählbar. **Kontext:** vom Beleg-Bildschirm geöffnet zeigt die leere Suche die Beleg-Kapitel, Treffer aus Beleg-Kapiteln wiegen 1,3-fach; analog Rechnungen. Test `test/help_test.dart` prüft, dass jede Handbuchüberschrift und jede FAQ-Frage im Index steht |
| FA-11.4 | **Rechtliches** (Einstellungen → Rechtliches, `features/settings/legal_screen.dart`, Lastenheft L-22.18, Store-Pflicht): Impressum, Datenschutzerklärung, Nutzungsbedingungen, Hinweis „Keine Steuerberatung“ (`LegalText.disclaimer`), Support (Mail-App wie FA-11.3), Open-Source-Lizenzen (`showLicensePage`, ergänzt um Work Sans OFL über `LicenseRegistry`). Je Zeile eine `ListTile` ≥ 56 dp |
| FA-11.5 | Die Rechtstexte sind **eine Quelle**: `docs/legal/IMPRESSUM.md`, `DATENSCHUTZ.md`, `NUTZUNGSBEDINGUNGEN.md` sind selbst Assets (`LegalDocument`), offline mit dem Markdown-Darsteller der Hilfe lesbar. Der Entwurfsblock der Datei wird ausgeblendet; solange `LegalDocument.reviewed` `false` ist (P-L1 offen), steht darüber der Vermerk „Entwurf – noch nicht anwaltlich geprüft“. Im Store-Build entfällt er (P-L20). `test/legal_documents_test.dart` prüft Asset-Einbindung, Vollständigkeit und dass `reviewed` zum Entwurfsvermerk der Dateien passt |
| FA-11.3 | **Ohne Treffer:** Hinweis und Knopf „E-Mail an den Support“; mit Treffern zusätzlich „Nicht dabei? Support fragen“. Öffnet die Mail-App (`mailto:office@jenibarb.com`, Android `ACTION_SENDTO`, iOS `UIApplication.open`, Kanal `buchhaltung/launcher` Methoden `openMail`, `appVersion`) mit Betreff „Frage zu JeNi bucht (Version x.y.z): <Suchtext>“. Kein Text, kein Anhang, keine Daten automatisch; gesendet wird nur, was die Nutzerin selbst abschickt. Ohne Mail-App: Dialog mit Adresse und „Adresse kopieren“ |

### 5.9 Lizenz und Abo

Lastenheft 5.10 und 5.22. Bezahlung **nur** über die Stores (Google Play
Billing, StoreKit 2) mit dem Paket `in_app_purchase`; kein Server, kein
Nutzerkonto, kein Drittanbieter-SDK. Code in `lib/services/licensing/`
(reines Dart bis auf den Adapter), Oberfläche in `lib/features/licensing/`.

| ID | Anforderung |
|---|---|
| FA-13.1 | **Ein Anspruch** (L-22.1): `Entitlement` = `none` (nie ein Abo), `readOnly` (Abo beendet), `basis`, `pro`. Einzige Entscheidung über Funktionen ist `Entitlement.allows(Feature)` in `license_policy.dart`; Bildschirme fragen nur `AppState.allows` bzw. `ensureFeature` (`features/licensing/feature_gate.dart`), nie den Store und nie den Tarif |
| FA-13.2 | **Tarifschnitt** (Lastenheft 5.10, O-4; Pro-Umfang entschieden 2026-10-15, O-34): `Feature.newBookings` (neuen Beleg speichern, neue Rechnung speichern, Rechnung ausstellen) ab Basis. **Nur Pro:** `receiptRecognition` (Belegerkennung FA-2.19 ff.), `dataImport` (Plattformimport Amazon/PayPal/Shopify/Stripe FA-5.x L-28 und Auslesen von E-Rechnungen ZUGFeRD/XRechnung/ebInterface in den Beleg; die Datei selbst wird in jedem Abo angehängt), `pdfSending` (Rechnung und Stornorechnung mit einem Tipp senden, FA-13.11), `dunningSending` (Zahlungserinnerung/Mahnung senden; erstellen und protokollieren ab Basis), `invoiceLogo` (Logo **drucken** auf neuen Rechnungen und Angeboten; wählen, ändern, entfernen immer, FA-13.12), `exchangeRateFetch` („Kurs abrufen“ bei der EZB; Kurs eintippen immer), `taxOfficeSubmission` (UVA/FinanzOnline/ELSTER, noch nicht gebaut, Tarif vorab festgelegt). **Immer frei, auch ohne Abo:** ansehen, Belege und Entwürfe ändern, PDF speichern oder drucken über den Systemdialog, Export, Sicherung, Wiederherstellung, Rechtliches, Hilfe (L-10.4, L-7.15, L-22.6). Knöpfe gesperrter Funktionen tragen „(Pro)“ und führen zur Abo-Seite (`proLabel`, `ensureFeature`) |
| FA-13.3 | **Produkte** (L-22.2): eine Abogruppe mit `basis_monat`, `basis_jahr`, `pro_monat`, `pro_jahr` (Kenndaten `spec.license_product_ids`). Wechsel innerhalb der Gruppe ersetzt das Abo: Android über `ChangeSubscriptionParam` (anteilige Zeitgutschrift), iOS über die Abogruppe (Upgrade sofort, Downgrade zum Periodenende) |
| FA-13.4 | **Test** (L-10.3, L-22.3): 14 Tage Pro als Einführungsangebot der Stores (Kenndaten `spec.license_trial_days`); der Store entscheidet über die Berechtigung. Android: bietet Play ein Angebot mit kostenloser erster Preisphase, wird dieses gekauft. Der Test geht nach Ablauf in das Abo über, wenn die Nutzerin nicht kündigt. Erster Pro-Kauf ohne früheres Abo merkt sich den Beginn; **3 Tage vor Ende** zeigt die Übersicht „Dein kostenloser Test endet am …“ (`spec.license_trial_reminder_days`) . **Entschieden 2026-10-15 (O-35):** Test bleibt Store-Test nur auf Pro; in den 14 Tagen kostenlos kündbar oder auf Basis wechselbar. Das **Widerrufsrecht** für digitale Inhalte (§ 356 Abs 5 BGB, § 18 Abs 1 Z 11 FAGG) regelt der Store unabhängig vom Test (Befund Prüfinstanz Rechtsanwalt; Bestätigung P-L10) |
| FA-13.5 | **Abo-Seite** (`features/licensing/subscription_screen.dart`, L-22.7, L-22.8; Einstellungen → Abo, Übersicht-Hinweis, gesperrte Funktion): Stand, Umschalter Monatlich/Jährlich (56 dp), Karten Pro und Basis mit **Preis aus dem Store** inkl. USt je Zeitraum (nie im Code), bei Pro ohne früheres Abo „14 Tage kostenlos, danach ‹Preis› pro ‹Zeitraum›, jederzeit vorher kündbar“ (Wortlaut entschieden 2026-10-15, O-35), Knopf 56 dp volle Breite. Darunter Pflichttext: automatische Verlängerung um denselben Zeitraum, Kündigung spätestens 24 Stunden vor Ablauf in den Store-Einstellungen, Übergang des Tests, Widerruf und Erstattung über den Store, Daten bleiben immer lesbar. Zeilen „Kauf wiederherstellen“, „Abo verwalten oder kündigen“ (Sprung `https://play.google.com/store/account/subscriptions` bzw. `https://apps.apple.com/account/subscriptions`, ohne Browser Anleitung als Meldung), Nutzungsbedingungen, Datenschutzerklärung (offline, FA-11.5) |
| FA-13.6 | **Store-Abfrage** (L-22.5): beim Start im Hintergrund und bei „Kauf wiederherstellen“. Gilt als verlässlich nur, wenn der Store verfügbar ist **und** die Produktliste geladen wurde; dann `restorePurchases` und Sammeln der gemeldeten Käufe (bis 6 s plus 1 s). Unverlässlich (offline, Fehler) → Stand bleibt, Meldung „Store nicht erreichbar. Dein Abo gilt weiter.“ Offene Käufe werden abgeschlossen (`completePurchase`) |
| FA-13.7 | **Offline und Kulanz** (L-10.5, L-22.5): der zuletzt bestätigte Stand (Stufe, Zeitpunkt, je ein Abo, Testbeginn) liegt im Schlüsselbund bzw. Keystore (`flutter_secure_storage`, nur dieses Gerät, nie in der Sicherung) und gilt **45 Tage** ab der letzten Bestätigung (`spec.license_offline_grace_days`: längster Monat 31 + 14 Tage Kulanz). Ab Tag 31 (`spec.license_offline_warn_days`) bittet die Übersicht, die App einmal mit Internet zu öffnen |
| FA-13.8 | **Herabstufen statt sperren** (L-22.6): Pro endet → Basis, wenn Basis aktiv; sonst Nur lesen. Die Übersicht zeigt nach einer Herabstufung einmal „Dein Abo ‹Stufe› ist beendet …“ (bis zum Tippen); höchstens ein Abo-Hinweis zur Zeit (`features/licensing/license_notice.dart`), Reihenfolge Herabstufung, Testende, Bestätigung fehlt, Nur lesen, kein Abo |
| FA-13.9 | **Gesperrte Funktion:** `ensureFeature` öffnet die Abo-Seite mit Begründung und prüft danach erneut; das Formular bleibt mit allen Eingaben offen. Beim Beleg ersetzt bei fehlendem Pro der Knopf „Automatisch auslesen (Pro)“ das stille Auslesen |
| FA-13.10 | **Testbuild-Schalter:** Lizenzprüfung nur mit `--dart-define=LICENSING=true` (`LicensePolicy.enabled`); ohne ihn voller Umfang, kein Store-Zugriff, Abo-Seite zeigt „Testversion“. Store-Builds setzen den Schalter (`.github/workflows/release.yml`, P-D30) |
| FA-13.13 | **Promo-Code** (Entscheidung Auftraggeberin 2026-10-16): Code `spec.license_promo_code` für 2 Monate Pro gratis (`spec.license_promo_free_months`) für neue Abonnentinnen, beworben auf Instagram. Nur Store-Mechanik, kein eigener Server: Apple **Angebotscode** (benutzerdefinierter Code auf `pro_monat`/`pro_jahr`, „Kostenlos“, 2 Monate, Neukunden) und Google Play **Promo-Code** auf einem Angebot des Pro-Abos (kostenlose Phase 2 Monate). Wie der Test: danach kostenpflichtig, vorher kostenlos kündbar oder Wechsel auf Basis im Store. Abo-Seite: Zeile „Promo-Code einlösen“ (≥ 48 dp). iOS öffnet direkt Apples Einlöseblatt (`presentCodeRedemptionSheet`, Paket `in_app_purchase_storekit`), Android ein Bottom-Sheet mit leerem Codefeld und „Einlösen“ (56 dp), dann `https://play.google.com/redeem?code=<Code>` (`StoreBilling.redeemCode`). Ergebnis über das Kaufereignis bzw. die Abfrage bei Rückkehr in die App (`didChangeAppLifecycleState` → `refresh`). Pro aus einem Code setzt `trialIsPromo`; die Erinnerung „Dein kostenloser Test endet am …“ kommt 3 Tage vor Ende der 2 Monate statt der 14 Tage. Direktlinks für Instagram: `LicensePolicy.playRedeemUri`, `appStoreRedeemUri` (Apple-ID der App fehlt noch, P-D32). Werbetext und Pflichtangaben: `STORE_LISTING.md`, P-R40. Steuerlich ohne Folge: Gratiszeit ohne Entgelt, Umsatz erst mit der ersten Store-Abrechnung (Prüfinstanz Steuerberater) |
| FA-13.12 | **Logo ohne Pro** (Entscheidung Auftraggeber 2026-10-16): Logo wählen geht im Onboarding und in den Stammdaten ohne Abo-Seite. `InvoiceLogo.forNewDocument` friert beim Speichern eines Entwurfs das Profil ohne `logo_path` ein, wenn `allows(Feature.invoiceLogo)` falsch ist (Basis, nur lesen, kein Abo); `InvoiceLogo.pathFor(…, logoAllowed:)` druckt Entwürfe nur mit Pro oder Store-Test. Gestellte Rechnungen behalten das eingefrorene Logo (GR-8). Das Profil behält `logo_path` und die Datei; nach dem Wechsel auf Pro erscheint das Logo wieder auf neuen Belegen. Ohne Pro zeigen die Stammdaten „Logo (Pro) – wird mit Basis nicht gedruckt“ |
| FA-13.11 | **PDF senden ohne Pro** (`sendPdfGated` in `feature_gate.dart`): Rechnung, Stornorechnung, Zahlungserinnerung und Mahnung werden in jedem Abo erzeugt (Mahnung samt Protokoll und SHA-256). Mit Pro öffnet „PDF senden“ das Teilen-Blatt mit Betreff und Mailtext. Ohne Pro zuerst die Abo-Seite mit Begründung; danach – ohne Kauf – das Systemblatt ohne Betreff und Text zum Speichern oder Drucken. **Stornorechnung:** Sie muss der Empfängerin zugehen (§ 14c UStG, § 11 Abs 12 UStG AT bzw. Rechnungsberichtigung § 31 Abs 5 UStDV); Speichern/Drucken und eigenes Weitergeben genügt dafür, die Pflicht ist also in Basis erfüllbar (Lastenheft 5.10, letzter Absatz). Technisch ist das Systemblatt dasselbe wie beim Senden; der Tarifschnitt ist Komfort (ein Tipp, Betreff, Text), keine harte Sperre. Ein eigener Druckdialog bräuchte das Paket `printing` (Entscheidung Auftraggeber) |

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
        bezahlt    │                │  stornieren (GR-14)
                   ▼                ▼
          ┌────────────────┐  ┌──────────────┐      ┌────────────────────┐
          │  Bezahlt       │─►│  Storniert   │─────►│  Stornorechnung    │
          │  (paid)        │  │  (cancelled) │ legt │  (cancellation)    │
          └────────────────┘  └──────────────┘  an  │  eigene Nummer     │
            stornieren (Rückzahlung)                └────────────────────┘
```

Alle Zustände außer *Entwurf* sind schreibgeschützt (`InvoiceStatus.isLocked`).
Stornierbar sind *Gestellt* und *Bezahlt* (`InvoiceStatus.canBeCancelled`).

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
| Onboarding / Stammdaten | `features/onboarding/company_setup_screen.dart` | Firmenprofil anlegen und bearbeiten, Firmenlogo, Skonto-Vorschlag und AGB-Adresse (FA-5.17, FA-5.19); Abschnitt „Wirtschaftsjahr und Termine“ (FA-10.1, nur Stammdaten) |
| Hauptnavigation | `features/home/home_shell.dart` | Vier Bereiche: Tab-Leiste (compact) oder Navigationsleiste links (medium, expanded), FA-9.2; einmaliges Angebot „App-Symbol auf den Startbildschirm“ (FA-1.19) |
| Übersicht | `features/dashboard/dashboard_screen.dart` | Abo-Hinweis (FA-13.8), Kassabuch, Umsatzsteuer, Grenzwertampel, Termin-Box „Nächste Termine“ (FA-10.3), Verlauf; zentrierter Knopf „Beleg fotografieren“ (FA-12.1), Zeitraum-Chips umbrechend; unten 112 dp Abstand, damit der Knopf keine Karte verdeckt |
| Belegliste | `features/receipts/receipt_list_screen.dart` | Suchen, filtern, öffnen; Chip-Reihe mit Jahr, Alle/Einnahmen/Ausgaben, „Storniert“, umbrechend (FA-12.4) |
| Beleg bearbeiten | `features/receipts/receipt_edit_screen.dart` | Erfassen, Seiten, Aufteilung nach Steuersätzen (`vat_split_editor.dart`, FA-2.33), Hinweisstreifen Link-QR (`link_invoice_strip.dart`, FA-2.42), Vermerk „vom Kassen-QR“ (FA-2.36), Originaldatei bei PDF/E-Rechnung (FA-2.41), automatisches Auslesen mit „Erneut auslesen“, Betrag, Fremdwährung mit „Kurs abrufen“ und Bankbetrag (FA-2.24 bis FA-2.26), Kategorie, Rechnungsnummer, Aussteller-UID, Kommentare; stornierte Belege nur lesen. Speicherleiste unten fixiert (`receipt_save_bar.dart`), über der Tastatur, Primärknopf 56 dp hoch: Telefon volle Breite, ab 600 dp rechtsbündig; bei neuen Seiten „Vollständig – Beleg speichern“ (FA-2.14) |
| Rechnungsliste | `features/invoices/invoice_list_screen.dart` | Status, PDF teilen, Aktionen; Knopf „Bezahlt“ mit Bottom-Sheet Zahlungseingang und Skonto (FA-5.12, FA-5.18); Korrigieren und Stornieren mit Bottom-Sheet (FA-5.31, FA-5.32), Löschen mit Bestätigung (FA-5.20) |
| Rechnung bearbeiten | `features/invoices/invoice_edit_screen.dart` | Kunde, Positionen mit Rabatt, Karte „Rabatt, Versand, Skonto“, Summe je Satz; Leiste `PrimaryActionBar` (`widgets/primary_action_bar.dart`) „Beenden“ / „Rechnung ausstellen“ bzw. „Beenden“ / „PDF senden“, Zurück speichert den Entwurf (FA-5.15 bis FA-5.20, FA-5.34) |
| Angebote | `features/offers/offer_screens.dart` | Liste mit Status und „gültig bis“; Formular mit Kunde, Gültigkeit, Positionen, Summe, „PDF senden“, „Zur Rechnung machen“ (FA-5.40 bis FA-5.47) |
| Artikel | `features/articles/article_screens.dart` | Liste mit Suche, Artikel anlegen/ändern/löschen (FA-5.44); Bottom-Sheet „Position übernehmen“ in `position_picker.dart` (FA-5.45) |
| Kunde bearbeiten | `features/invoices/customer_edit_screen.dart` | Kundenstammdaten, Schalter „Unternehmen“ (FA-5.24) |
| Mahnung (Bottom-Sheet) | `features/invoices/dunning_sheet.dart` | Stufe, bisherige Schreiben mit Storno, Frist, Mahnkosten mit Verbraucherhinweis, Zinsen, Pauschale, Vorschau, „erstellen und senden“ (FA-5.21 bis FA-5.23) |
| Plattformimport | `features/import/platform_import_screen.dart` | Eine Karte je Monat, Hinweise, Amazon-Gebührenrechnung, unten „Übernehmen“ (FA-2.43 bis FA-2.49); geöffnet aus der Hauptnavigation, wenn eine CSV/TSV/TXT geteilt wird |
| Datensicherung | `features/backup/backup_screen.dart` | Sicherung erstellen und teilen, wiederherstellen mit Vorschau; automatische Sicherung mit iCloud (iOS, FA-7.16) und Liste zum Wiederherstellen |
| Wiederherstellungscode | `features/backup/recovery_code_setup_screen.dart` | Druckblatt teilen/drucken, zwei Blöcke abtippen (FA-7.10) |
| Rechtliches | `features/settings/legal_screen.dart` | Impressum, Datenschutz, Nutzungsbedingungen, keine Steuerberatung, Support, Lizenzen (FA-11.4, FA-11.5) |
| Export | `features/export/export_screen.dart` | Zeitraum, Vorschau, Format |
| Einstellungen | `features/settings/settings_screen.dart` | Stammdaten, App-Sperre, Abo (FA-13.5), Symbol auf Startbildschirm (FA-1.19, nur Android), Belege auslesen, Fremdwährung (Tageskurs-Genehmigung), Kategorien, Rechtsrahmen, Hinweise |
| App-Sperre einrichten | `features/app_lock/app_lock_settings_screen.dart` | PIN, Biometrie, Sperrzeit, Hinweis „PIN vergessen“, Warnung ohne Sicherung |
| Sperrbildschirm | `features/app_lock/lock_screen.dart` | PIN oder Biometrie, Wartezeit nach Fehlversuchen; Abdeckung im App-Umschalter |
| Abo | `features/licensing/subscription_screen.dart` | Stand, Monatlich/Jährlich, Basis und Pro mit Store-Preis, Test, Pflichttext, Kauf wiederherstellen, Promo-Code einlösen (FA-13.13), Abo verwalten, Nutzungsbedingungen, Datenschutz (FA-13.5) |
| Hilfe | `features/help/help_screen.dart` | Suche im Handbuch (FA-11.2), Abschnitt lesen, Support-Mail ohne Treffer (FA-11.3); erreichbar über das Fragezeichen oben rechts (FA-11.1) |

**Navigation:** Vier Ziele – Übersicht, Belege, Rechnungen, Export – in der
Tab-Leiste (Telefon) bzw. in der Navigationsleiste links (Tablet, Querformat,
FA-9.2). Einstellungen erreicht man über das Zahnrad in der Übersicht, die
Hilfe über das Fragezeichen oben rechts auf jedem Hauptbildschirm (FA-11.1).

**Liste-Detail (expanded, FA-9.3):** Belegliste mit „Beleg bearbeiten“,
Rechnungsliste mit „Rechnung bearbeiten“ und Kundenliste mit „Kunde
bearbeiten“ stehen nebeneinander; ohne Auswahl zeigt der rechte Bereich einen
Hinweis.

---

## 8. Exportformate

### 8.0 Mahnschreiben (PDF)

`DunningPdf`: Absender, Empfänger, Datum, Titel „<Stufe> zu Rechnung <Nr.> vom
<Datum>“, sachlicher Text ohne Drohungen, Tabelle offener Rechnungsbetrag,
Mahnkosten, Verzugszinsen (Satz, Fundstelle), Pauschale – jeweils „nicht
umsatzsteuerbar“ – und Gesamt, neue Zahlungsfrist als Datum, Bankverbindung
mit Rechnungsnummer als Verwendungszweck. SHA-256 des gesendeten PDFs steht
im Datensatz und im Protokoll.

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
`TT.MM.JJJJ, hh:mm: Text`, getrennt durch ` | `), Teil („1/2“ bei aufgeteilten Belegen, sonst leer), Originaldatei
(„Name (SHA-256 …)“, mehrere durch ` | `; nur erste Zeile, FA-2.41).
Je Steuersatzzeile eine Zeile; Originalbetrag und Bankbetrag nur in der ersten Zeile eines Belegs.
Danach Summenzeilen für Einnahmen, Ausgaben, ggf. „Kursdifferenzen laut Bank“
(FA-2.26) und Ergebnis.

### 8.3 DATEV-Buchungsstapel (`datev`, nur DE)

EXTF-Format, Formatversion 700, Kategorie 21. Zeile 1 Metadaten, Zeile 2
Spaltenüberschriften, ab Zeile 3 die Buchungen.

- Gebucht wird immer **brutto**, ohne Vorzeichen
- Das Vorzeichen steckt im Soll/Haben-Kennzeichen: Einnahme `H`, Ausgabe `S`
- Belegdatum als `TTMM`; das Jahr steht im Header
- Header-Feld „WJ-Beginn“: erster Tag des Wirtschaftsjahres, das den Zeitraum enthält (GR-10)
- Buchungstext maximal 60 Zeichen, Semikola werden durch Komma ersetzt
- **Mehrere Steuersätze:** eine Buchung je Satz mit dem Brutto der Zeile; BU-Schlüssel bleibt leer (Automatikkonto), Zuordnung je Satz prüft die Kanzlei (P-S48)
- Berater- und Mandantennummer stehen als `0` – die Kanzlei ordnet den Stapel beim Import zu
- **Fremdwährung:** gebucht wird der umgerechnete Euro-Betrag mit `WKZ Umsatz` = `EUR`; die Felder `Kurs`, `Basis-Umsatz` und `WKZ Basis-Umsatz` bleiben leer, weil Kursrichtung und Pflichtkombination im EXTF-Format nicht gesichert geprüft sind (P-D23). Originalbetrag und Kurs stehen in der Belegliste (8.2). BMD (8.4) ebenso nur Euro

### 8.4 BMD-Buchungssätze (`bmd`, nur AT)

Spalten: Satzart, Konto, Gegenkonto, Belegdatum, Belegnummer, Buchungstext,
Betrag, Steuercode, Steuersatz, Steuerbetrag, Buchsymbol.

Steuercodes: Einnahme 20 % → `1`, 13 % → `3`, 10 % → `2`; Ausgabe 20 % → `11`,
13 % → `13`, 10 % → `12`; 0 % → `0`.
Buchsymbol: `KA` bei Barzahlung, sonst `BK`. Aufgeteilte Belege: ein Buchungssatz je Steuersatz mit eigenem Steuercode.

### 8.5 Umsatzsteuer-Zusammenfassung (`vatReturn`)

Stammdaten, Zeitraum, steuerpflichtige Umsätze je Satz mit Bemessungsgrundlage
und Steuer, Vorsteuer je Satz, Reverse Charge mit Kennzahlen des Landes
(Bemessungsgrundlage nur DE Kz 46, Steuer, Vorsteuer; FA-3.3), Zahllast oder
Guthaben, Ergebnis netto. Bei Kleinunternehmern zusätzlich der
Befreiungsvermerk.

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

**Codes auf dem Foto (FA-2.35):** dieselbe gebündelte ML-Kit-Familie (Barcode
Scanning) mit denselben Diagnosedaten an Google wie die Texterkennung; kein
neuer Empfänger. Geteilte Dateien (FA-2.38) kommen von einer anderen App auf
das Gerät, nichts geht hinaus. PDF und E-Rechnungen (FA-2.39, FA-2.40)
werden vollständig auf dem Gerät verarbeitet.

**Plattformimport (FA-2.43 bis FA-2.49):** die Datei kommt über Teilen bzw.
„Öffnen mit“ auf das Gerät und wird dort gelesen; nichts geht hinaus. Der Knopf
„Gebührenrechnungen öffnen“ übergibt nur die feste Adresse an den Browser.
Käuferdaten werden nicht übernommen (P-R36).

**Rechnung über Link-QR (FA-2.42):** nur auf Tippen „Laden“ ruft die App die
Adresse aus dem QR-Code beim Server dieser Domain ab (Betreiber ist der
Rechnungsaussteller bzw. sein Dienstleister). Übertragen werden die Adresse
(sie kann eine Rechnungs- oder Kundenkennung enthalten), IP-Adresse und
technische Verbindungsdaten; keine Daten aus der App. Offengelegt in
`PRIVACY.md`, Lastenheft 5.19 und `STORE_LISTING.md`; Prüfung P-R35.
„Im Browser öffnen“ übergibt die Adresse an den Browser des Systems.

**EZB-Kursabruf (FA-2.25):** nur auf Tippen „Kurs abrufen“ ruft die App eine
feste Datei der Europäischen Zentralbank ab (`eurofxref-hist-90d.xml` bzw.
`eurofxref-hist.xml`). Übertragen werden nur IP-Adresse und technische
Verbindungsdaten, keine Belegdaten, keine Währung, kein Betrag. Offengelegt in
`PRIVACY.md`, Lastenheft 5.19 und `STORE_LISTING.md`; Prüfung P-R18.

**Abo (FA-13.6):** beim Start und bei „Kauf wiederherstellen“ fragt die App
über Google Play Billing bzw. StoreKit beim Store des Geräts nach aktiven Abos;
beim Kauf öffnet das Kaufblatt des Stores. Die App sendet dabei nur die
Produkt-IDs; Store-Konto, Zahlungsdaten und Kaufbelege bleiben bei Apple bzw.
Google, der Anbieter erhält nur zusammengefasste Verkaufsberichte. Am Gerät
bleibt nur Stufe, Zeitpunkt der Bestätigung und Testbeginn (Schlüsselbund).
Offengelegt in `PRIVACY.md`, Lastenheft 5.19 und `STORE_LISTING.md`; Prüfung
P-R37.

**iCloud-Sicherung (FA-7.16, nur iOS, Opt-in):** die verschlüsselte
Vollsicherung liegt im App-eigenen iCloud-Drive-Container der Nutzerin; den
Upload übernimmt iOS. Empfänger ist Apple als Anbieter des iCloud-Kontos der
Nutzerin (aus Sicht der Nutzerin Auftragsverarbeiter, Server auch außerhalb
der EU). Der Schlüssel bleibt im Schlüsselbund des Geräts
(`synchronizable: false`, L-19.27); Apple sieht nur Dateiname, Größe und
Zeitpunkt. Der Anbieter erhält nichts. Offengelegt in `PRIVACY.md`,
Lastenheft 5.19 und `STORE_LISTING.md`; Prüfung P-B6, P-B9.

**Lernen je Lieferant (FA-2.50):** bleibt in der Datenbank auf dem Gerät;
nichts wird übertragen.

### 10.2 Berechtigungen

| Berechtigung | Plattformschlüssel | Zweck |
|---|---|---|
| Kamera | `NSCameraUsageDescription` | Belege abfotografieren |
| Fotobibliothek lesen | `NSPhotoLibraryUsageDescription` | Vorhandene Belegfotos hinzufügen |
| Fotobibliothek schreiben | `NSPhotoLibraryAddUsageDescription` | Rechnung in der Fotobibliothek ablegen |
| Face ID | `NSFaceIDUsageDescription` | App-Sperre entsperren (FA-1.16); Auswertung durch das System |
| Biometrie (Android) | `USE_BIOMETRIC` (über `local_auth`) | App-Sperre entsperren (FA-1.16); Auswertung durch das System |

Android `com.android.vending.BILLING` fügt das Paket `in_app_purchase_android` beim Bauen ins Manifest ein (keine Laufzeitabfrage).

Android benötigt für `image_picker` keine Manifest-Berechtigung, weil die
Aufnahme über die System-Kamera-App per Intent läuft.

**iOS-Datenschutz-Manifest** `ios/Runner/PrivacyInfo.xcprivacy` (Ressource im
Runner-Target): `NSPrivacyTracking` false, keine Tracking-Domains; Required-Reason-API
nur Dateizeitstempel `C617.1` (dart:io, App-Container); erhobene Datenarten
Kaufverlauf und sonstige Finanzinfos, nicht verknüpft, App-Funktionalität – wie
das App Privacy Label in `docs/STORE_LISTING.md`. Die Plugins bringen eigene
Manifeste mit. `CFBundleLocalizations` = `de`, damit iOS die App und die
Systemdialoge (Berechtigungstexte oben) als deutschsprachig führt. Abgleich im
ersten Review: P-B15.

Details: [`docs/PRIVACY.md`](PRIVACY.md).

---

## 11. Bekannte Grenzen

Offen benannt, weil eine Spezifikation, die ihre Lücken verschweigt, wertlos ist.

| Grenze | Auswirkung | Geplant |
|---|---|---|
| **Automatische Sicherung nicht auf Gerät erprobt** | iCloud-Container (FA-7.16) nur kompiliert, unsigniert; braucht vor dem ersten signierten Build den Container im Apple Developer Portal (STORE_ANMELDUNG, P-B13). Ordnerwahl und Schreiben laufen über eigenen Kotlin- bzw. Swift-Code, der hier nur kompiliert (CI), nicht auf einem Gerät getestet ist. Ob die Google-Drive-App unter Android Ordner zur Auswahl anbietet, ist offen (P-B1) | vor Release |
| **Keine revisionssichere Archivierung** | Das `audit_log` schafft Nachvollziehbarkeit im Alltag, ist aber keine manipulationssichere Protokollierung im Sinne einer Verfahrensdokumentation. Die App ist die Vorerfassung; die revisionssichere Aufbewahrung findet in der Kanzlei statt | – |
| **Keine Registrierkasse** | Wer die RKSV-Grenzen (15.000 € Umsatz und 7.500 € Barumsätze) überschreitet, braucht zusätzlich eine registrierkassenpflichtige Lösung | Nicht geplant |
| **E-Rechnung nur im Empfang** | Eingehende E-Rechnungen (ZUGFeRD/Factur-X, XRechnung UBL/CII, ebInterface) werden übernommen (FA-2.40). Ausgangsrechnungen sind nur PDF, keine E-Rechnung nach EN 16931; in Deutschland kommt die Versandpflicht gestaffelt bis 2028 | Backlog G1 |
| **Storno nur vollständig** | Die Stornorechnung hebt die ganze Rechnung auf (GR-14); Teilstorno einzelner Positionen oder Teilbeträge (L-3.18) gibt es noch nicht – dafür „Korrigieren“ (Storno + neue Rechnung). Die Rückzahlung wird am Stornotag gebucht, ein späterer Rückzahlungstag ist im Sheet zu wählen | später |
| **Steuerwerte fest im Code** | Kennwerte außer Steuersätzen (seit 0.3.4 `validFrom`, GR-3) haben kein Gültig-ab-Datum und ändern sich nur per App-Update; eine kurzfristige Gesetzesänderung erreicht die Nutzerin erst nach Store-Freigabe | Rechtsstand-Überwachung, Lastenheft L-20 und L-13.5, Stufe B |
| **Belegerkennung nicht auf Gerät erprobt** | Android-Teil im CI-Emulator mit R8 an einem synthetischen Kassenbon geprüft, Swift-Teil nur kompiliert; Korpus mit sechs echten Belegen (`test/fixtures/belege/`); Quote auf dem Gerät noch zu bestätigen (P-D22). Mehrsprachige Schlüsselwörter sind teils nur an synthetischen Texten geprüft. Gelernt wird je Kasse (FA-2.36) und je Lieferant (FA-2.50); Steuersatz-Aufteilungen und Beschreibungen werden nicht gelernt | vor Release |
| **Fremdwährung nur bei Ausgaben** | Eingangsbelege werden umgerechnet (FA-2.24 bis FA-2.27); Ausgangsrechnungen nur in Euro. Den BMF-Monatskurs lädt die App nicht, er wird von Hand übernommen; das EZB-Monatsmittel ist nur eine Näherung (P-S23, P-S24). DATEV/BMD exportieren nur Euro (P-D23). Ein Land mit anderer Währung setzt Mehrwährungsfähigkeit voraus | Backlog G7 |
| **Termine nur als Anzeige** | Die Termin-Box (FA-10.3) erinnert nicht aktiv; Bescheid-Termine (z. B. abweichende Vorauszahlungen, Nachzahlungen) kennt sie nicht. Teil- und Anzahlungen auf Rechnungen bildet die App nicht ab (P-S35) | Stufe 2: Benachrichtigungen |
| **Bewirtung ohne Abzugsbeschränkung** | Ein Bewirtungsbeleg wird nach Sätzen aufgeteilt, aber voll als Ausgabe und Vorsteuer gezählt; die Kürzung (AT 50 %, DE 70 % Betriebsausgabe) macht die Kanzlei (P-S46) | nach P-S46 |
| **Kleinunternehmerstatus nicht je Jahr** | Ob Ausgaben brutto zählen, richtet sich nach der aktuellen Einstellung, auch für Vorjahre | später |
| **Keine Teilzahlungen** | Mahnkosten und Zinsen werden nur bei voller Zahlung mitgebucht; Teilzahlungen und deren Anrechnung (§ 1416 ABGB, § 367 BGB) bildet die App noch nicht ab; Basiszinssätze ändern sich nur per App-Update (P-S44) | später |
| **Plattformimport ohne Dateiauswahl in der App** | Die Exportdatei kommt über Teilen bzw. „Öffnen mit“ (Dateien-App, Downloads); eine eigene Dateiauswahl fehlt. Nur EUR; Bestimmungsland für OSS nur näherungsweise (Marktplatz, Lieferland), bei PayPal/Stripe keins. Umsatzsteuer der Verkäufe ohne Steuerspalte zum Normalsatz (P-S51); Spaltennamen nur an synthetischen Dateien geprüft (P-S55) | später |
| **Mengen mit zwei Dezimalstellen** | Die Mengeneingabe verarbeitet zwei Nachkommastellen, obwohl das Datenmodell drei erlaubt | – |
| **Offene Detailseite beim Wechsel der Breitenklasse** | Wird ein Tablet von quer (expanded) auf hoch (medium) gedreht oder das Fenster verkleinert, während rechts ein Beleg, eine Rechnung oder ein Kunde in Bearbeitung ist, schließt sich der Detailbereich; ungespeicherte Eingaben gehen verloren. Gespeichertes bleibt unberührt | später |
| **Abo nicht mit echten Stores erprobt** | Die Lizenzlogik ist mit einem Store-Ersatz getestet (`test/licensing_test.dart`); Produkte in Play Console und App Store Connect fehlen noch (P-D30), Testkäufe ebenso (P-D4). Kaufbelege werden **nicht selbst** kryptografisch geprüft (L-22.4 offen): die App verlässt sich auf die Prüfung durch Play Billing bzw. StoreKit 2 im Paket. Ob StoreKit ohne Abo ein leeres Ergebnis meldet, ist unbekannt; die App wartet bis 7 s (P-D31). Die Testerinnerung kennt nur Käufe auf diesem Gerät; nach Neuinstallation fehlt sie | vor Store-Start |
| **Android-APK-Build nicht lokal verifiziert** | Im Entwicklungscontainer ist `dl.google.com` per Netzwerk-Policy gesperrt, das Android SDK ließ sich nicht installieren. Analyse, Format und Tests laufen lokal; die Plattform-Builds verifiziert die CI | – |

---

## 12. Maschinenlesbare Kenndaten

> **Diese Werte prüft `test/specification_sync_test.dart` gegen den Code.**
> Wird ein Wert im Code geändert, ohne ihn hier anzupassen, schlägt der Test fehl.
> Das ist der Mechanismus, der dieses Dokument aktuell hält.

```properties
spec.schema_version = 20
spec.oss_threshold_cents = 1000000
spec.primary_action_height_dp = 56
spec.min_touch_target_dp = 48
spec.dunning_default_fee_cents = 1000
spec.dunning_period_days = 14
spec.deadline_box_count = 4
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
spec.offer_number_pattern = AN-{YYYY}-{NNNN}
spec.offer_validity_days = 30
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
spec.license_trial_days = 14
spec.license_promo_code = JENIBUCHT2M
spec.license_promo_free_months = 2
spec.license_trial_reminder_days = 3
spec.license_offline_grace_days = 45
spec.license_offline_warn_days = 31
spec.license_product_ids = basis_monat,basis_jahr,pro_monat,pro_jahr

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
spec.at.fiscal_year_legal_ref = § 2 Abs 5 EStG
spec.at.deadline_shift_legal_ref = § 108 Abs 3 BAO
spec.at.monthly_vat_return_threshold_cents = 10000000
spec.at.vat_interval_basis = umsatz
spec.at.asks_federal_state = nein
spec.at.dunning_consumer_rate_bp = 400
spec.at.dunning_consumer_surcharge_bp = 0
spec.at.dunning_business_surcharge_bp = 920
spec.at.dunning_flat_fee_cents = 4000
spec.at.dunning_base_rates = 2025-01-01:253,2025-07-01:153,2026-01-01:153
spec.at.dunning_consumer_notice = nein
spec.at.dunning_interest_legal_ref = § 1000 Abs 1 ABGB | § 456 UGB
spec.at.reverse_charge_kz = -,057,066
spec.at.deadline_rules = UVA@15+2m | ZM@0+1m | ESt-Vorauszahlung@02-15,05-15,08-15,11-15 | ESt-/USt-Erklärung (FinanzOnline)@+1j06-30 | SVS-Beitrag@02-00,05-00,08-00,11-00~

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
spec.de.fiscal_year_legal_ref = § 4a EStG
spec.de.deadline_shift_legal_ref = § 108 Abs 3 AO
spec.de.monthly_vat_return_threshold_cents = 900000
spec.de.vat_interval_basis = steuer
spec.de.asks_federal_state = ja
spec.de.dunning_consumer_rate_bp = none
spec.de.dunning_consumer_surcharge_bp = 500
spec.de.dunning_business_surcharge_bp = 900
spec.de.dunning_flat_fee_cents = 4000
spec.de.dunning_base_rates = 2025-01-01:227,2025-07-01:127,2026-01-01:127
spec.de.dunning_consumer_notice = ja
spec.de.dunning_interest_legal_ref = § 288 Abs 1 BGB | § 288 Abs 2 BGB
spec.de.reverse_charge_kz = 46,47,67
spec.de.deadline_rules = UStVA@10+1m+1x | ZM@25+1m | ESt-Vorauszahlung@03-10,06-10,09-10,12-10 | Steuererklärungen@+1j07-31
```

Umrechnung: Beträge in Cent. `5500000` Cent = 55.000,00 €.

Terminregeln (`deadline_rules`): `15+2m` = 15. im zweiten Monat nach Ende des
Zeitraums (0 = Monatsletzter), `+1x` = zusätzlicher Monat bei
Dauerfristverlängerung, `02-15,…` = feste Tage, `+1j07-31` = Folgejahr,
`~` = ungefähr, ohne Verschiebung.

---

## 13. Änderungshistorie

| Version | Datum | App-Version | Änderung |
|---|---|---|---|
| 1.64 | 2026-10-16 | 0.16.0 | Prüfmappen für Steuerberatung und Rechtsberatung in `docs/pruefmappen/` (Verweis in 14), erzeugt aus Abschnitt 14; Beispielrechnungen mit `InvoicePdf`. Keine Verhaltensänderung der App. |
| 1.63 | 2026-10-16 | 0.16.0 | Release-Vorbereitung ohne Verhaltensänderung der App: iOS-Datenschutz-Manifest und `CFBundleLocalizations` de (10.2); Release-Workflow signiert Android-AAB und iOS-IPA über Secrets, optionaler Play-/TestFlight-Upload; Skript `tool/release/bundle_id_wechsel.sh` für O-33 (nicht ausgeführt). Neue Prüfpunkte P-B15, P-B16, P-D34. Prüfinstanzen: Rechtsanwalt (Datenschutzangaben deckungsgleich mit STORE_LISTING/PRIVACY), Softwareentwickler (Manifest nur mit tatsächlich genutzter API, keine Schlüssel im Repository), Steuerberater und UX ohne Befund (keine Oberflächen- oder Steueränderung). |
| 1.62 | 2026-10-16 | 0.16.0 | FA-2.50 Lernen je Lieferant (Schema 20 `supplier_memory`, 4.1, 10.1, 11); FA-7.16 iCloud-Sicherung unter iOS und Liste zum Wiederherstellen (5.5a, 7, 10.1, 11); `spec.schema_version` 20 (12); P-B13, P-B14, P-X11, P-D33 neu, P-D3 präzisiert (14). Geprüft mit den Prüfinstanzen Rechtsanwalt (Apple als Auftragsverarbeiter, Opt-in), Steuerberater (Gelerntes nur als Vorschlag, gebucht wird Bestätigtes), Softwareentwickler (Entitlements ohne Wirkung im unsignierten CI-Build), UX (Knöpfe ≥ 48 dp, Listeneinträge 56 dp, ein Tipp weniger beim Einrichten mit iCloud). |
| 1.61 | 2026-10-16 | 0.15.0 | FA-13.13 Promo-Code `JENIBUCHT2M` (2 Monate Pro gratis) über Apple-Angebotscodes und Google-Play-Promo-Codes, Abo-Seite „Promo-Code einlösen“; Kenndaten `spec.license_promo_code`, `spec.license_promo_free_months`; P-R40, P-D32. Kein Schemawechsel. |
| 1.60 | 2026-10-16 | 0.15.0 | Angebote und Artikel (FA-5.40 bis FA-5.47), Schema 19 mit `articles`, `offers`, `offer_items` (4.1); FA-5.2 um Angebote ergänzt; Bildschirme Angebote und Artikel (7); Kenndaten `spec.offer_number_pattern`, `spec.offer_validity_days`, `spec.schema_version` 19 (12); P-U8, P-R39 (14). |
| 1.59 | 2026-10-16 | 0.14.0 | FA-13.12 neu: Logo im Onboarding ohne Abo-Seite wählbar, gedruckt nur mit Pro oder Test; FA-13.2 angepasst. Kein Schemawechsel, keine neuen Kenndaten. |
| 1.58 | 2026-10-15 | 0.14.0 | O-35 entschieden: Store-Test 14 Tage nur Pro (FA-13.4), Wortlaut „14 Tage kostenlos, danach ‹Preis› pro ‹Zeitraum›, jederzeit vorher kündbar“ (FA-13.5); Widerruf über den Store unabhängig vom Test (P-L10). |
| 1.57 | 2026-10-15 | 0.14.0 | Pro-Umfang (Entscheidung Auftraggeber 2026-10-15, Lastenheft O-34): FA-13.2 neu mit `dataImport`, `pdfSending`, `dunningSending`, `invoiceLogo`, `exchangeRateFetch`, `taxOfficeSubmission` nur Pro; neu FA-13.11 PDF senden ohne Pro (Speichern/Drucken über Systemdialog, Stornorechnung erreicht die Kundin auch in Basis). Kein Schemawechsel, keine neuen Kenndaten. |
| 1.56 | 2026-10-15 | 0.14.0 | App-Version 0.14.0 (Testbuild): Lizenz und Abo (neuer Abschnitt 5.9, FA-13.1 bis FA-13.10; Lastenheft 5.10, 5.22): Anspruch keiner/nur lesen/Basis/Pro an einer Stelle, Belegerkennung nur Pro, neue Buchungen ab Basis, Lesen/Export/Sicherung immer; Paket `in_app_purchase`, eine Abogruppe mit vier Produkten, Test über die Stores, Abo-Seite mit Store-Preisen und Pflichttext, Kauf wiederherstellen, Abo verwalten; Stand im Schlüsselbund, offline 45 Tage gültig, Hinweis ab Tag 31; Herabstufen statt sperren. Lizenzprüfung nur mit `LICENSING=true`. Neuer Datenfluss in 10.1, Berechtigung BILLING in 10.2, neue Grenze in 11. Kenndaten `spec.license_*`. Neue Prüfpunkte P-R37, P-R38, P-X10, P-D30, P-D31; P-D4 präzisiert. Kein Schemawechsel. |
| 1.55 | 2026-10-15 | 0.13.2 | App-Version 0.13.2 (Testbuild), Gerätetest Google-Beleg: „$“ mit US-Merkmalen als USD-Vorschlag vorbelegt, bekannte Anbieter als Lieferant, Satz aus Steuerbetrag ohne Prozent (Apple-Beleg 16,50/99,00 → 20 %), Hinweis ohne Steuerausweis nicht für Kleinunternehmer (FA-2.28). Kein Schemawechsel. |
| 1.54 | 2026-10-15 | 0.13.1 | App-Version 0.13.1 (Testbuild), Fehlerbehebung Gerätetest 0.13.0: Beträge mit geschütztem Leerzeichen als Tausendertrenner werden gelesen (bearbeitete Rechnung und Korrekturentwurf zeigten 0 €); Leiste „Beenden“ / „PDF senden“, Zurück speichert den Entwurf (FA-5.34, FA-5.20); Teilen auf Android über eigenen FileProvider (FA-5.35). Neue Prüfpunkte P-X9, P-D29. |
| 1.53 | 2026-10-15 | 0.13.0 | App-Version 0.13.0 (Testbuild): Stornorechnung mit eigener Nummer aus dem gemeinsamen Nummernkreis, Bezug, Grund, negativen Beträgen je Satz, Rückzahlung als negative Einnahme bei bezahltem Original, Mahnungen mitstorniert; „Korrigieren“ = Storno + Entwurfskopie (GR-14, FA-5.11, FA-5.31 bis FA-5.33, 6.1; Schema 18). Menü „Rechtliches“ mit Rechtstexten als Assets und Entwurfsvermerk (FA-11.4, FA-11.5). Wiederherstellungscode als Druckblatt mit QR-Code und Bestätigung durch zwei Blöcke (FA-7.10). Grenze „Keine Storno- oder Korrekturrechnung“ ersetzt durch „Storno nur vollständig“. Neue Prüfpunkte P-S56, P-L20, P-X8, P-D28. |
| 1.52 | 2026-10-15 | 0.12.0 | App-Version 0.12.0 (Testbuild): Produkt- und App-Name „JeNi bucht“ (Android-Label, iOS CFBundleDisplayName/CFBundleName, App-Titel, Sperrbildschirm, Support-Betreff FA-11.3, Exportvermerk, Sicherungs-Betreff, CI-Artefakt `JeNi-bucht-<Version>-build-<Nr>.apk`); Bundle-ID unverändert `at.jesenko.buchhaltung` (Lastenheft O-33). Neu FA-1.4f: Formatprüfung E-Mail und Telefon in Profil und Kunde (O-30). P-R7 erledigt. |
| 1.51 | 2026-10-14 | 0.11.0 | Dokumentabgleich (Prüfinstanz Softwareentwickler), kein Codewechsel: Status im Kopf, Schemaversion in Abschnitt 4 auf 17 korrigiert, Bildschirm „Beleg bearbeiten“ um Aufteilung, Link-QR, Kassen-QR, Originaldatei ergänzt; Abschnitt 11: E-Rechnung-Empfang und Belegstorno-Status präzisiert, Lernspeicher erwähnt; Abschnitt 14: Zeilen je Gruppe nach Nummer sortiert (P-S45, P-L18, P-R26, P-D8, P-D20 bis P-D23), neuer Prüfpunkt P-D27 (Beta mit Zielgruppe, bisher verwaister Verweis P-Z1 in STORE_ANMELDUNG). |
| 1.50 | 2026-10-14 | 0.11.0 | App-Version 0.11.0 (Testbuild), Stufe B1: Plattformexporte Amazon (Transaktionsbericht DE/EN/FR/IT/ES, Abrechnung V2), PayPal, Shopify, Stripe über Teilen/„Öffnen mit“ (FA-2.43 bis FA-2.49), Bruttoprinzip, Reverse Charge mit Kennzahlen in Übersicht und UVA-Export (FA-3.3, FA-3.4, 8.5), OSS-/FBA-Warnung, Dubletten über Schema 17. Kenndaten `oss_threshold_cents`, `reverse_charge_kz`. Neue Prüfpunkte P-S51 bis P-S55, P-R36, P-U7. |
| 1.49 | 2026-10-14 | 0.10.0 | App-Version 0.10.0 (Testbuild), Stufe A3: Link-QR mit Hinweisstreifen, Laden nur nach Tipp, Domainwechsel nur nach erneuter Anzeige, nur PDF/XML ≤ 20 MB, sonst Browser (FA-2.42); neuer Datenfluss in 10.1. Neue Prüfpunkte P-R35, P-U6. |
| 1.48 | 2026-10-14 | 0.9.0 | App-Version 0.9.0 (Testbuild), Stufe A2: PDF-Rechnungen (FA-2.39), E-Rechnungen CII/UBL/ebInterface (FA-2.40), Originaldatei mit SHA-256 in Sicherung und Belegliste (FA-2.41, Schema 16), Teilen-Ziel für PDF/XML und iOS „Öffnen in“ (FA-2.38). |
| 1.47 | 2026-10-14 | 0.8.0 | App-Version 0.8.0 (Testbuild), Stufe A1: Codes auf dem Foto (FA-2.35 bis FA-2.38, Lastenheft L-27.1 bis L-27.4): Kassen-QR RKSV/TSE mit Vorrang bei Betrag, Datum, Sätzen, Zahlungs-QR EPC, Lernspeicher Kasse → Händler (Schema 15), Teilen-Ziel Android für Bilder. Neue Prüfpunkte P-S49, P-S50, P-U5. |
| 1.46 | 2026-10-14 | 0.7.0 | App-Version 0.7.0 (Testbuild). Beleg mit mehreren Steuersätzen (FA-2.33, FA-2.34, Lastenheft L-2.27), Schema 14 mit `receipt_vat_lines`, Auswertungen und Exporte je Satz (8.2 bis 8.4). Fehlerbehebung Gerätetest 0.6.0: Kleinunternehmer-Ausgaben brutto, Balken-Mindesthöhe, Ladevorgang ohne Überschreiben (FA-3.2, FA-3.5, FA-3.7); Termin-Box ans Ende. Mahnwesen: neue Frist, Mahnsymbol mit Verlauf (FA-5.26, FA-5.27); Sie-Form in Kundendokumenten (FA-5.28); Hinweis Leistungsdatum (FA-5.29); eingebettete PDF-Schrift mit € (FA-5.30). Einhandbedienung links und rechts (FA-12.7). Neue Prüfpunkte P-S46 bis P-S48, P-L19, P-X7. |
| 1.45 | 2026-10-14 | 0.6.0 | App-Version 0.6.0 (Testbuild) „Einhandbedienung“ nach DESIGN_SPEC 5a (Abschnitt 5.7a, FA-12.1 bis FA-12.6): zentrierter Knopf „Beleg fotografieren“, Stornieren/Löschen am Formularende in Fehlerfarbe, Seitenleiste 48 dp, umbrechende Chips, Jahr als Chip, Datum „Heute/Gestern“, `PrimaryActionBar` in Kunden- und Stammdatenformular. Kein Schemawechsel. Neue Prüfpunkte P-X1 bis P-X6. |
| 1.44 | 2026-10-14 | 0.5.0 | App-Version 0.5.0 (Testbuild): Mahnwesen (GR-13, FA-5.21 bis FA-5.25, Abschnitt 8.0, Lastenheft L-3.10, L-3.27 bis L-3.30): Zahlungserinnerung und Mahnungen beliebig oft, unveränderlich mit Storno, Mahnkosten 10 € ab 1. Mahnung mit Verbraucherhinweis, optionale Verzugszinsen act/365 je Halbjahr, Pauschale B2B, Kundenmerkmal „Unternehmen“, DE-Hinweis § 286 Abs 3 BGB, Mahnkosten bei Zahlung als nicht steuerbare Einnahme. Schema 13. Neue Kennwerte `spec.dunning_*`, `spec.*.dunning_*`. Neue Prüfpunkte P-S44, P-S45, P-R32 bis P-R34. |
| 1.43 | 2026-10-14 | 0.4.0 | App-Version 0.4.0 (Testbuild): Rabatt je Position und Gesamtrabatt anteilig je Satz, Versandkosten wie Hauptleistung, Skonto mit festem Datum und Betrag, Zahlung mit Skonto mindert Einnahme je Satz, AGB-Verweis (GR-12, FA-5.15 bis FA-5.19, Lastenheft L-3.21 bis L-3.26). UX-Vorgaben: `PrimaryActionBar`, „PDF senden“ nach dem Ausstellen, Tonal-Knopf „Bezahlt“, Bestätigung bei Storno/Löschen (FA-5.20). Schema 12. Neue Kennwerte `spec.primary_action_height_dp`, `spec.min_touch_target_dp`. Neue Prüfpunkte P-S40 bis P-S43, P-R30, P-R31. |
| 1.42 | 2026-10-14 | 0.3.5 | App-Version 0.3.5 (Testbuild): Wirtschaftsjahr, Termin-Box, bezahlte Rechnung als Einnahme, Hilfe offline. Schema 11. |
| 1.41 | 2026-10-14 | 0.3.4 | Hilfe Stufe 1 offline (Abschnitt 5.8, FA-11.1 bis FA-11.3, Abschnitt 7): Fragezeichen in der AppBar, BM25-Suche im als Asset eingebundenen Handbuch, Abschnitt lesen, Support-Mail ohne Anhang. Stufe 2 (KI) nur vorgemerkt. Neue Prüfpunkte P-R25, P-R26, P-D26. Kein Schemawechsel. |
| 1.40 | 2026-10-14 | 0.3.4 | Wirtschaftsjahr (GR-10, FA-10.1, FA-10.2, FA-3.1, FA-6.1, DATEV „WJ-Beginn“) und Termin-Box Stufe 1 (Abschnitt 5.6a, FA-10.3 bis FA-10.8) mit Feiertagen AT/DE und Verschiebung auf den nächsten Werktag. Fehlerbehebung Gerätetest 0.3.4: bezahlte Rechnung wird Einnahme am Tag des Zahlungseingangs (GR-11, FA-5.12), Nachbuchung alter Rechnungen; Übersicht mit 160 dp Abstand unten. Schema 11. Neue Kennwerte `spec.deadline_box_count`, `spec.*.fiscal_year_legal_ref`, `spec.*.deadline_shift_legal_ref`, `spec.*.monthly_vat_return_threshold_cents`, `spec.*.vat_interval_basis`, `spec.*.asks_federal_state`, `spec.*.deadline_rules`. Neue Prüfpunkte P-S32 bis P-S35, P-R24, P-D25. |
| 1.39 | 2026-10-14 | 0.3.4 | Vollständigkeitsbestätigung und Speichern zu einer Aktion zusammengelegt (FA-2.14, Abschnitt 7): Knopf „Vollständig – Beleg speichern (n Seiten)“, kein Häkchen mehr, Protokoll „Vollständigkeit bestätigt“. Neuer Prüfpunkt P-S31. Kein Schemawechsel. |
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

**Prüfmappen in `docs/pruefmappen/`:** `Pruefmappe_Steuerberater.pdf` und
`Pruefmappe_Rechtsanwalt.pdf` bündeln die offenen Punkte dieses Abschnitts nach
Themen mit Antwortfeld und Bitte um Fixpreisangebot. Die Generatoren
(`pruefmappe_*.py`) lesen die Tabellen hier bei jedem Lauf neu; Beispielrechnungen
erzeugt `beispiele_erzeugen_test.dart` mit dem PDF-Generator der App.

### Rechtsanwältin / Rechtsanwalt

| ID | Prüfpunkt | Vorbefund der Prüfinstanz | Benötigt vor | Status |
|---|---|---|---|---|
| P-R1 | Impressum und Offenlegung für Produktseite und App | § 5 ECG und § 25 Abs 5 MedienG (AT, „kleine Website"); § 5 DDG greift über das Herkunftslandprinzip nur mittelbar; Verbraucherschlichtungshinweis prüfen; ODR-Link entfallen seit 07/2025 | Produktseite | offen |
| P-R2 | Rabatt- und Streichpreiswerbung für Store-Abos | 30-Tage-Regel (§ 11 PAngV, § 9a PrAG) für Dienstleistungen streitig; Irreführungsverbot gilt immer; ohne vorher verlangten Listenpreis nur „Einführungspreis bis …" | erste Werbung | offen |
| P-R3 | BFSG (DE) / BaFG (AT) | voraussichtlich nicht anwendbar (B2B, Kleinstunternehmen); Unternehmensgröße bestätigen | vor Stufe B | offen |
| P-R4 | Tragweite der Bestätigung „keine Steuerberatung" und Haftungsbegrenzung in den AGB | begrenzt wirksam; Vorsatz, grobe Fahrlässigkeit, Personenschäden nicht ausschließbar | Release | offen |
| P-R5 | Abgrenzung zur Hilfeleistung in Steuersachen (StBerG, WTBG) bei UVA-Übermittlung und ESt-Vorbereitung | zulässig als Werkzeug, Übermittlung nur im Namen und mit Zugang der Nutzerin; keine Einzelfallempfehlung | Stufe B | offen |
| P-R6 | DSGVO: Datenschutzerklärung, Verzeichnis, TOM, Datenpannenprozess; ab Stufe C AVV und Unterauftragsverarbeiter | Rollen laut Lastenheft L-19 im Kern richtig, um Anbieter- und Store-Daten ergänzt | Release / Stufe C | offen |
| P-R7 | Markenrecherche „JeNi bucht" (TMview, Klassen 9, 35, 36, 42) | Recherche der Auftraggeberin ohne Befund (2026-10-15); Name festgelegt | Store-Eintrag | erledigt 2026-10-15 |
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

### UX / Einhandbedienung (DESIGN_SPEC 5a)

| ID | Prüfpunkt | Vorbefund der Prüfinstanz | Benötigt vor | Status |
|---|---|---|---|---|
| P-X1 | Einhandtest rechts und links auf einem 6,3"-Gerät: Beleg erfassen (≤ 4 Tipps), Rechnung bezahlt (≤ 2), mahnen (≤ 3), ohne Umgreifen | Widget-Tests prüfen Lage und Größe (Regel 12); Daumenreichweite nur real prüfbar | Release | offen |
| P-X2 | Fehltipp-Test mit 5 Personen: Stornieren/Löschen nie versehentlich, Bestätigung verstanden | Gefahrenknöpfe am Formularende mit Bestätigung | Release | offen |
| P-X3 | Tastaturen (Gboard, Samsung, iOS, mit Vorschlagsleiste): Primäraktion bleibt sichtbar, aktives Feld unverdeckt | `PrimaryActionBar` über viewInsets, Test mit 300 dp Tastatur | Release | offen |
| P-X4 | Systemschrift 200 %: keine abgeschnittenen Knöpfe und Chips, Formulare scrollbar | nicht automatisiert geprüft | Release | offen |
| P-X5 | Nutzung im Auto (Beifahrerin), mit Handschuhen, in direktem Sonnenlicht: Kontrast und Trefferflächen | — | Release | offen |
| P-X6 | System-Einhandmodus (Android) und Reachability (iOS) mit der App | — | Release | offen |
| P-X7 | Links- und Rechtshand auf dem Pixel 10: „Beleg erfassen“, „Neue Rechnung“, Rechnungskarte (Erinnern, Bezahlt, PDF senden), Mahnsymbol, „Weiteren Steuersatz hinzufügen“ ohne Umgreifen | Widget-Tests für Lage und Größe der zentrierten Knöpfe (Regel 12) | Release | offen |
| P-X8 | Einhandtest auf dem Pixel 10: Rechnung „Korrigieren“ und „Stornieren“ (Menü ⋮, Grund-Vorschlag mit einem Tipp, Knopf unten, nicht neben Abbrechen), Wiederherstellungscode (Druckblatt teilen, zwei Blöcke abtippen mit Tastatur offen, Knopf über der Tastatur), Einstellungen → Rechtliches lesen | Widget-Tests: Knöpfe ≥ 48 dp, Bestätigung erst nach richtigen Blöcken; Gefahrenknopf 56 dp volle Breite in Fehlerfarbe | Release | offen |
| P-X9 | Einhandtest auf dem Pixel 10: Rechnung bearbeiten, „Beenden“ und „PDF senden“ mit dem Daumen ohne Fehlgriff, nach dem Teilen-Blatt zurück im Formular, System-Zurück-Geste speichert den Entwurf bzw. fragt einmal | Widget-Test: beide Knöpfe ≥ 48 dp, Zurück ohne Kunde zeigt den Dialog (`invoice_form_ux_test.dart`) | Release | offen |
| P-X10 | Abo-Seite auf Pixel 10 und iPhone einhändig: Monatlich/Jährlich, Kaufknopf, Kauf wiederherstellen, Abo verwalten mit dem Daumen ohne Fehlgriff; Store-Kaufblatt erscheint, Rückkehr in die Abo-Seite; Hinweis auf der Übersicht verständlich; Beleg im Nur-Lese-Modus: Abo-Seite statt Verlust der Eingaben | Widget-Test: alle Bedienelemente ≥ 48 dp, Kaufknöpfe 56 dp volle Breite (`licensing_test.dart`) | Store-Start | offen |
| P-X11 | Einhandtest: Datensicherung „Wiederherstellen“ → Liste → Sicherung mit dem Daumen wählen; „Ausschalten“ nicht versehentlich neben „Ordner ändern“; Beleg mit „wie beim letzten Mal“ übernehmen ohne Korrektur | Knöpfe im Wrap mit 8 dp Abstand, Listeneinträge 56 dp, Gefahrenknopf mit Bestätigung | Release | offen |

### Softwareentwicklung (echte Geräte und Stores)

| ID | Prüfpunkt | Vorbefund der Prüfinstanz | Benötigt vor | Status |
|---|---|---|---|---|
| P-D1 | Update einer echten v1-Installation auf Schema 2 und folgende | Upgrade-Test mit ffi vorhanden; echtes Gerät fehlt | Release | offen |
| P-D2 | PDF mit Umlauten, CSV in Excel/Numbers | nicht verifiziert | Release | offen |
| P-D3 | Datensicherung und Wiederherstellung über iCloud Drive / Google Drive | iCloud (FA-7.16) und Ordnerwahl gebaut, auf Gerät offen (P-B12, P-B14) | Release | offen |
| P-D4 | Abo-Testkäufe in Sandbox beider Stores (Lizenztester Google, Sandbox-Konto Apple; Build mit `LICENSING=true`): Test 14 Tage Pro mit Übergang, Basis, Wechsel Basis↔Pro ohne Doppelabo, Jahresabo, Kündigung → Nur lesen mit Hinweis, Kauf wiederherstellen nach Neuinstallation, ausstehende Zahlung, Flugmodus (Stand bleibt), Grace Period | Logik mit Store-Ersatz getestet (`licensing_test.dart`, FA-13.1 bis FA-13.10); Adapter nur kompiliert | Store-Start | offen |
| P-D5 | iOS Privacy Manifest, Data-Safety- und Privacy-Label-Angaben inkl. aller SDKs | Manifest fehlt | erster Upload | offen |
| P-D6 | Android targetSdk-Vorgabe 2026, Signing, Bundle-ID `at.jesenko.buchhaltung` endgültig | Bundle-ID personenbezogen, nach Release unveränderlich | erster Upload | offen |
| P-D7 | Kamera, Fotoablage, Spracheingabe auf echten Geräten | — | Release | offen |
| P-U1 | VIES-Schnittstelle live auf echten Android- und iOS-Geräten: gültige, ungültige Nummer, Ausfall eines Mitgliedstaats; Abfragenummer kommt zurück | Endpunkt und Antwortformat aus Fachwissen, nicht live getestet | Release | offen |
| P-U2 | Nachweiswert von VIES mit Abfragenummer gegenüber FinanzOnline Stufe 2 (AT) und qualifizierter Bestätigungsabfrage § 18e UStG (DE) | VIES schwächer, aber als Hilfsnachweis anerkannt | Release | offen |
| P-U3 | Steuernummer auf österreichischen Rechnungen nicht nötig; DE Steuernummer oder USt-IdNr. genügt | beide Prüfinstanzen | Release | offen |
| P-U4 | Datenschutzerklärung und Store-Formulare (Google Data Safety, Apple Label) zur VIES-Abfrage durch Fachperson | Nutzerin Verantwortliche, Kommission Empfängerin, Anbieter unbeteiligt | erster Upload | offen |
| P-U5 | Kassen- und Zahlungs-QR auf echtem Gerät: SPAR-/Hofer-/Billa-Bon mit RKSV-QR (auch zerknittert, schräg, schwaches Licht), deutscher TSE-Bon, Rechnung mit GiroCode; Vermerk „vom Kassen-QR“ sichtbar; Teilen eines Fotos aus Galerie und Mail öffnet den Buchungsvorschlag mit einer Hand | Emulator prüft nur synthetische QR-Bilder (FA-2.35); Korpus Belege 1–6 wird im CI-Artefakt `ocr-belege` auf Codes ausgewertet | Release | offen |
| P-U6 | Link-QR auf echtem Gerät: Rechnung eines Anbieters mit QR-Link (z. B. Energie, Telefon), Streifen einhändig erreichbar, Domain lesbar, Laden einer PDF, Weiterleitung auf andere Domain zeigt neue Domain, HTML-Portal führt zu „Im Browser öffnen“ | Logik mit Testserver geprüft (`link_invoice_test.dart`), kein echter Anbieter | Release | offen |
| P-U8 | Angebote und Artikel auf echtem Gerät mit einer Hand: Rechnungsliste → „Angebote“ → neues Angebot mit Artikel aus „Aus Artikeln und Vorschlägen“, „PDF senden“, „Zur Rechnung machen“; Daumen erreicht alle Knöpfe, Bottom-Sheet mit Tastatur bedienbar | Widget-Test (Knöpfe ≥ 48 dp, Zeilen ≥ 48 dp), kein echtes Gerät | Release | offen |
| P-U7 | Plattformimport auf echtem Gerät: Transaktionsbericht in der Seller-Central-App bzw. im Browser herunterladen, mit einer Hand teilen bzw. in Dateien „Öffnen mit“ → Buchhaltung, Zusammenfassung lesbar, „Übernehmen“ mit dem Daumen; zweites Teilen derselben Datei bucht nichts doppelt | Widget-Test (Knopf unten, volle Breite, ≥ 56 dp), kein echtes Gerät | Release | offen |
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
| P-B13 | Eigentümer: iCloud-Container `iCloud.<Bundle-ID>` im Apple Developer Portal anlegen und der App-ID zuordnen (vor erstem signierten Build bzw. `release.yml`, nach O-33 für die neue Bundle-ID erneut) | ohne Container scheitert die Signatur mit Entitlement; unsignierter CI-Build unberührt | erster signierter iOS-Build | offen |
| P-B14 | Gerätetest iPhone: „Einrichten“ ohne Ordnerwahl schreibt nach iCloud Drive › JeNi bucht, Ordner in der Dateien-App sichtbar; „Wiederherstellen“ listet die Sicherungen auch auf einem Zweitgerät (ausgelagerte `.icloud`-Dateien werden geladen); iCloud abgemeldet → Ordnerwahl | nur kompiliert | vor Release | offen |
| P-B15 | Eigentümer, erste Einreichung: App Privacy Label in App Store Connect so ausfüllen wie `STORE_LISTING.md` (Formularantworten) und mit `ios/Runner/PrivacyInfo.xcprivacy` abgleichen; Xcode „Generate Privacy Report“ auf dem Archiv ohne Warnung; Apple-Review akzeptiert die Angaben | Manifest nach Plugin-Manifesten und eigenem Code erstellt, nicht von Apple bestätigt | erste Einreichung | offen |
| P-B16 | Eigentümer: Secrets für `release.yml` anlegen (RELEASE_PLAYBOOK „Secrets für den Release-Workflow“), Workflow einmal starten: signierte AAB und IPA entstehen, IPA erscheint in TestFlight; erste AAB von Hand in die Play Console | Workflow nur syntaktisch geprüft, ohne Secrets nicht lauffähig | erste Einreichung | offen |
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
| P-S31 | Steuerberatung: Genügt Speichern über den Knopf „Vollständig – Beleg speichern (n Seiten)“ mit Erklärzeile als Vollständigkeitsbestätigung (GoBD Rz. 136 ff. zum ersetzenden Scannen, Vollständigkeit § 146 Abs. 1 AO; AT § 131 BAO)? Eigenes Häkchen entfällt | Vorbefund Softwareentwickler: aktive, eindeutig beschriftete Handlung je Buchung mit neuen Seiten, Aussage steht unmittelbar am Knopf, Protokoll im `audit_log` mit Seitenzahl und „Vollständigkeit bestätigt“; ein vorab gesetztes Häkchen wäre schwächer. Gesetzlich ist keine bestimmte Form der Bestätigung vorgeschrieben (Verfahrensdokumentation) | vor Release | offen |
| P-S32 | Abweichendes Wirtschaftsjahr: Voraussetzungen und Bestätigungstexte (AT § 2 Abs 5 EStG, DE § 4a EStG); EÜR-Rechner/Freiberufler praktisch Kalenderjahr – reicht eine Bestätigung, oder soll die App die Auswahl bei EÜR sperren? | Steuerberater-Befund 2026-10-14: AT nur Firmenbuch + Bilanzierung + Zustimmung FA, DE nur Handelsregister + Einvernehmen FA; USt immer Kalenderjahr. Umgesetzt als einmalige Bestätigung (FA-10.2) | Release | offen |
| P-S33 | Termine: UVA-Grenzen (AT 100.000 € Vorjahresumsatz § 21 Abs 2 UStG; DE 9.000 € Vorjahressteuer § 18 Abs 2 UStG ab 2025), Jänner-/Dezember-Sonderregeln, Erklärungsfristen mit Steuerberatung (§ 134a BAO, § 149 Abs 3 AO), ZM-Zeitraum gleich Voranmeldungszeitraum (Vereinfachung), ESt-Vorauszahlungen immer angezeigt | Werte laut Befund im Code (FA-10.6, FA-10.7); Beraterfrist als „laut Kanzlei“ | Release | offen |
| P-S34 | SVS-Beitragsfälligkeit (§ 35 GSVG): Ende Feb./Mai/Aug./Nov.; Verschiebung bei Wochenende/Feiertag? | unsicher, daher „ca.“ ohne Verschiebung (FA-10.7) | Release | offen |
| P-S35 | Bezahlte Rechnung als Einnahme am Zahlungstag (Zuflussprinzip § 19 EStG AT, § 11 EStG DE); Kleinunternehmergrenze AT: App zählt Einnahmen nach Zahlungseingang (Ist) – richtig für Ist-Versteuerer (§ 17 UStG), bei Soll-Versteuerung nach Leistung? Teilzahlungen und Anzahlungen bildet die App nicht ab | umgesetzt nach Zufluss (GR-11); Soll-Basis nicht abgebildet | Release | offen |
| P-S40 | Gesamtrabatt anteilig nach Entgelt je Steuersatz mit Rabattzeile je Satz, Restcent nach größtem Rest (GR-12): genügt das § 11 Abs 1 Z 3 lit e UStG AT bzw. § 14 Abs 4 Nr. 7 UStG DE („im Voraus vereinbarte Minderung des Entgelts“)? | Vorbefund Steuerberater: Aufteilung nach Entgelten ist übliche und anerkannte Methode | Release | offen |
| P-S41 | Versandkosten als Nebenleistung: Satz der Hauptleistung, bei Mischsätzen anteilig nach Entgelt (EuGH C-111/05 Aktiebolaget NN, UStR Rz 347 AT, Abschn. 3.10 Abs 6 UStAE DE); fester Satz als Ausnahme | Vorbefund: Aufteilung nach Entgelten zulässig, andere Schlüssel (Gewicht) ebenfalls | Release | offen |
| P-S42 | Skonto bei Zahlung: Minderung je Satz nach Brutto-Anteil; Berichtigung im Zahlungsmonat (§ 16 UStG AT, § 17 UStG DE). App bucht nach Zufluss; bei Soll-Versteuerung wäre eine Korrekturbuchung im Zahlungsmonat zu den ursprünglichen Umsätzen nötig – reicht die geminderte Einnahme? Kein Beleg nötig (DE Abschn. 17.1 Abs 3 UStAE)? | Vorbefund: für Ist-Versteuerer korrekt, Soll nicht abgebildet (wie P-S35) | Release | offen |
| P-S43 | Skontotext auf der Rechnung: Pflichtangabe „Vereinbarung über Entgeltminderung“ (§ 14 Abs 4 Nr. 7 UStG DE) mit festem Datum und Betrag erfüllt; AT: ausreichend? Kleinunternehmer: nur geringere Einnahme | Vorbefund: Hinweis „Bei Zahlung bis … 2 % Skonto“ genügt (Abschn. 14.5 Abs 19 UStAE) | Release | offen |
| P-S44 | Basiszinssätze 2025–2026 je Halbjahr: AT OeNB (253, 153, 153 Bp), DE § 247 BGB (227, 127, 127 Bp) – amtlich abgleichen; Berechnung act/365 je Halbjahr, half-up je Abschnitt | Werte aus Fachwissen der Prüfinstanz, nicht amtlich abgerufen | Release | offen |
| P-S45 | Mahnkosten, Verzugszinsen und Pauschale als nicht umsatzsteuerbarer Schadenersatz (UStR Rz 9 AT, Abschn. 1.3 Abs 6 UStAE DE), Einnahme bei Zufluss mit 0 %, Kategorie „Sonstige Einnahmen“; Anrechnung nach § 1416 ABGB / § 367 BGB | Vorbefund Steuerberater: nicht steuerbar, Betriebseinnahme bei Zufluss | Release | offen |
| P-S46 | Bewirtung: soll die App die Abzugsbeschränkung abbilden? AT § 20 Abs 1 Z 3 EStG (50 % abzugsfähig, Vorsteuer voll bei Werbezweck), DE § 4 Abs 5 Nr. 2 EStG (70 % Betriebsausgabe, Vorsteuer voll bei Angemessenheit und Nachweis) samt Bewirtungsbeleg-Angaben (Anlass, Teilnehmer) | App teilt nur nach Sätzen auf (FA-2.33), zählt 100 %; keine Kategorie „Bewirtung“ mit Kürzung | Release | offen |
| P-S47 | Kleinunternehmer: Ausgaben brutto in der Einnahmen-Ausgaben-Rechnung, keine Vorsteuer (AT § 12 iVm § 6 Abs 1 Z 27 UStG 1994; DE § 19 Abs 1 UStG, § 9b Abs 1 EStG); Behandlung beim Wechsel des Status innerhalb eines Jahres | umgesetzt nach aktueller Einstellung (FA-3.2) | Release | offen |
| P-S48 | DATEV: Buchung je Satz eines aufgeteilten Belegs ohne BU-Schlüssel auf ein Automatikkonto – richtig importiert, oder braucht es Schlüssel bzw. Konto je Satz? | eine Buchung je Satz, BU leer (8.3) | Release | offen |
| P-S49 | RKSV-Kassen-QR ab 01.07.2026: Feld „Betrag-Satz-Besonders“ trägt 19 % **und** 4,9 % gemeinsam; ist die Zuordnung über den Belegtext (Satzzeile) zulässig, und reicht der Vorrang des QR für Betrag und Datum gegenüber dem Text? Echten Beleg mit 4,9 % prüfen | „Besonders“ nicht aus dem Code bestimmbar (BMF-Hinweis im A-SIT-Mustercode-Repository 13.03.2026, fiskaly); App nimmt den Satz aus dem Text, sonst Rückfrage (FA-2.36); finale Detailspezifikation nicht abrufbar | Release | offen |
| P-S50 | DSFinV-K Anhang I: Reihenfolge der Bruttobeträge im TSE-QR (`Kassenbeleg-V1`, IDs 1–5: 19 %, 7 %, 10,7 %, 5,5 %, 0 %) und Dezimalpunkt; mit echtem deutschem Kassenbeleg gegenprüfen | aus Fachwissen, amtliche DSFinV-K nicht abgerufen (FA-2.35) | Release | offen |
| P-S51 | Steuerberatung: Plattform-Sammelbuchung je Monat nach Bruttoprinzip (Umsatz als Einnahme inkl. Versand/Aktionsrabatt abzüglich Erstattungen, Gebühren und Werbung als eigene Ausgaben, Auszahlung nicht gebucht) – genügt ein Sammelbeleg je Monat (Einzelaufzeichnung § 131 BAO / § 146 AO über den Bericht)? Umsatzsteuer der Verkäufe ohne Steuerspalte zum Normalsatz herausgerechnet; Datum = letzter Buchungstag im Monat (Zufluss vs. Leistung) | Befund Steuerberater (Bruttoprinzip) umgesetzt (FA-2.46); Normalsatz-Annahme und Datum unsicher | vor Release | offen |
| P-S52 | Steuerberatung: Reverse Charge für Amazon-Gebühren (Amazon EU S.à r.l.) auch beim Kleinunternehmer (AT § 19 Abs 1 zweiter Satz iVm § 3a Abs 6 UStG 1994; DE § 13b Abs 1/5 UStG, Abs 8) ohne Vorsteuerabzug; Kennzahlen AT Kz 057/066, DE Kz 46/47/67; Leistender der Amazon-Werbung (Amazon Online Services/Amazon EU bzw. Inlandsgesellschaft?) | umgesetzt (FA-2.46, FA-3.3); Kennzahlen aus Fachwissen, Formular nicht abgerufen | vor Release | offen |
| P-S53 | Steuerberatung: OSS-Schwelle 10.000 € (Art 59c MwStSystRL; AT Art 3 Abs 5 UStG 1994; DE § 3c Abs 4 UStG) – Näherung Bestimmungsland über Amazon-Marktplatz bzw. Shopify-Lieferland ausreichend für eine Warnung? Lager in anderen Ländern (FBA Pan-EU/CEE) nur als Hinweis | umgesetzt als Warnung (FA-2.47) | vor Release | offen |
| P-S54 | Steuerberatung: Gebühren von PayPal (Europe) S.à r.l. et Cie, S.C.A. (LU) als steuerfreier Finanzumsatz (Art 135 Abs 1 lit d MwStSystRL; AT § 6 Abs 1 Z 8 UStG 1994; DE § 4 Nr 8 Buchst d UStG) ohne Reverse Charge; Stripe (Stripe Technology Europe Ltd./Stripe Payments Europe Ltd., IE) und Shopify Payments (Shopify International Ltd., IE) als steuerpflichtige Leistung mit Reverse Charge – Leistender und Behandlung je Vertrag/Rechnung bestätigen | nicht gesichert recherchiert (Quellen der Anbieter nicht abrufbar); so umgesetzt (FA-2.46) | vor Release | offen |
| P-S55 | Spaltennamen und Typwerte mit echten Exporten je Sprache abgleichen: Amazon Transaktionsbericht DE/EN/FR/IT/ES, Abrechnung V2 (amount-type/-description), PayPal Aktivitäten DE/EN, Shopify, Stripe | nur synthetische Dateien (`test/fixtures/plattform/`), Spaltennamen nach Hilfeseiten und Fachwissen | vor Release | offen |
| P-S56 | Stornorechnung (GR-14): (a) gemeinsamer Nummernkreis für Rechnungen und Stornorechnungen zulässig und ausreichend (AT § 11 Abs 1 Z 3 lit c UStG, UStR Rz 1535 ff.; DE § 14 Abs 4 Nr. 4 UStG, Abschn. 14.5 Abs 10 UStAE)? (b) Pflichtinhalt: Bezug Nummer und Datum, negative Beträge je Satz, Grund – genügt das als Berichtigung (§ 31 Abs 5 UStDV, Abschn. 14.11 UStAE) bzw. Rechnungsberichtigung AT? (c) § 14c UStG DE / § 11 Abs 12 UStG AT: Berichtigung des Steuerausweises erst mit Zugang beim Empfänger – reicht der Hinweis „PDF senden“? (d) Buchung: bezahlt → negative Einnahme je Satz am Rückzahlungstag (Ist-Versteuerung, § 17 UStG DE, § 16 UStG AT); offen → keine Buchung; bei Soll-Versteuerung wäre der Stornomonat maßgeblich (nicht abgebildet) | Vorbefund Steuerberater: Stornorechnung mit eigener Nummer und Bezug ist Praxis in AT und DE; ein Nummernkreis zulässig; Ist-Prinzip passt zur EAR. Rz-Fundstellen AT nicht am Volltext verifiziert | Release | offen |
| P-L12 | Anwältin: Diktat über die Systemtastatur – Anbieterin nicht verantwortlich, Hinweistext genügt | — | Release | offen |
| P-L13 | Gerätetest, nur bei eigener Spracherkennung: Erkennung im Flugmodus | — | später | offen |
| P-L14 | Anwältin: Rollen beim Vertragsarchiv mit KI (Anbieterin als Auftragsverarbeiterin), Muster-AVV, Rechtsgrundlage Beschäftigtendaten | — | Stufe C | offen |
| P-L15 | Anwältin bzw. Datenschutzberatung: DSFA und TIA; DPF-Zertifikat, Zero Data Retention und Speicherdauer bei Anthropic verifizieren | — | Stufe C | offen |
| P-L16 | Anwältin: KI-Ausgabetexte zu Verträgen auf RDG, RAO und UWG | — | Stufe C | offen |
| P-L17 | Anwältin: Art. 50 AI Act (Kennzeichnung) und aktuelle Fristen | — | Stufe C | offen |
| P-L18 | Anwältin: Lizenzpflichten ML Kit (Google APIs / ML Kit Terms), Lizenznennung in der App | — | Release | offen |
| P-L19 | Anwältin: Schriftlizenz Work Sans (SIL OFL 1.1) für in PDFs eingebettete Teilmengen und Auslieferung in der App; Lizenznennung | `assets/fonts/OFL.txt` liegt bei; OFL erlaubt Einbetten und Bündeln | Release | offen |
| P-L20 | Menü „Rechtliches“ (FA-11.4, FA-11.5): genügt die Darstellung (Impressum, Datenschutz, Nutzungsbedingungen offline in der App, Support-Mail) den Pflichten aus § 5 ECG, Art. 13 DSGVO und den Store-Vorgaben (Google Play Datenschutzerklärung in der App, Apple 5.1.1)? Entwurfsvermerk: im Testbuild sichtbar, im Store-Build nicht – Voraussetzung ist P-L1 (Texte final, `LegalDocument.reviewed = true`) | Vorbefund Rechtsanwalt: ein „Entwurf“-Vermerk in der veröffentlichten App wäre widersprüchlich und angreifbar (UWG, Transparenz); deshalb nur bis P-L1. Zusätzlich muss die Datenschutzerklärung unter einer öffentlichen URL stehen (Store-Pflicht) | Store-Einreichung | offen |
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
| P-R24 | Termin-Box: Formulierung „Berechnete Termine zur Orientierung, ohne Gewähr. Maßgeblich sind Bescheid, Finanzamt bzw. deine Steuerberatung.“ – genügt das gegenüber Verbraucherinnen/Unternehmerinnen (Haftung für falsch berechnete Fristen, AGB/Nutzungsbedingungen)? | Hinweis sichtbar unter jeder Termin-Box (FA-10.4); Nutzungsbedingungen noch nicht ergänzt | Release | offen |
| P-R25 | Hilfe Stufe 2 (KI-Antworten): Abgrenzung zur Hilfeleistung in Steuersachen (StBerG DE, WTBG AT), Haftung für falsche Antworten, Kennzeichnung als KI (Art. 50 KI-VO) | noch nicht gebaut (FA-11, Lastenheft L-26.6) | vor Stufe 2 | offen |
| P-R26 | Hilfe Stufe 2: Übermittlung der Frage an einen Server bzw. KI-Anbieter – Rechtsgrundlage, Auftragsverarbeitung, Drittlandtransfer, Eintrag in Datenflusstabelle und Store-Angaben | noch nicht gebaut | vor Stufe 2 | offen |
| P-R30 | AGB-Verweis auf der Rechnung: Wortlaut „Es gelten unsere Verkaufsbedingungen, abrufbar unter <URL>, soweit sie vereinbart wurden.“ – irreführend oder unbedenklich? Genügt der einmalige Hinweis an die Nutzerin, dass der Verweis allein AGB nicht einbezieht (§ 864a ABGB, § 305 Abs 2 BGB; B2B kaufmännisches Bestätigungsschreiben)? | Rechnung kommt nach Vertragsschluss, Verweis bezieht AGB nicht ein; Zusatz „soweit vereinbart“ vermeidet Irreführung | Release | offen |
| P-R31 | Rabatt- und Skontoangaben auf Rechnungen an Verbraucherinnen: Preisangaben (PAngV, PrAG), Klarheit des Skontotexts mit festem Datum und Betrag | unbedenklich, da reine Zahlungsbedingung | Release | offen |
| P-R32 | Mahnkosten 10 € je Mahnung (Entscheidung der Auftraggeberin): B2C nur angemessene, tatsächliche Kosten (AT § 1333 Abs 2 ABGB; DE §§ 280, 286 BGB, erste verzugsbegründende Mahnung nicht ersatzfähig, Rechtsprechung ca. 1–3 €). Genügt der Hinweis in der App, Entscheidung bei der Nutzerin? | Vorbefund Rechtsanwalt: 10 € gegenüber Verbrauchern regelmäßig zu hoch; Hinweis umgesetzt (FA-5.22) | Release | offen |
| P-R33 | Wortlaut der Zahlungserinnerung und Mahnung (sachlich, ohne Drohung, UWG/§ 4a UWG, KSchG), Hinweis § 286 Abs 3 BGB auf DE-Verbraucherrechnungen | Texte in `DunningService.bodyText`, `TaxProfile.dunning.consumerDefaultNotice` | Release | offen |
| P-R34 | Pauschale 40 € (§ 458 UGB, § 288 Abs 5 BGB) nur B2B, Anrechnung auf Rechtsverfolgungskosten; Verzugszinsen ohne Vereinbarung erst ab Verzug (DE: Mahnung oder 30 Tage mit Hinweis) | umgesetzt als Vorschlag, Entscheidung bei der Nutzerin | Release | offen |
| P-R35 | Link-QR (FA-2.42): Abruf beim Server des Rechnungsausstellers auf Tippen – Rolle der Nutzerin bzw. des Anbieters (DSGVO), Offenlegung in Datenschutzerklärung und Google Data Safety/Apple Label (Datenerhebung durch die App ja/nein), Warnhinweis gegen Phishing ausreichend? | keine Daten aus der App, nur Adresse/IP an die gezeigte Domain; Domain groß, Wechsel nur nach erneuter Anzeige, kein Login in der App | erster Upload | offen |
| P-R36 | Plattformimport (FA-2.49): Käuferdaten (Name, Adresse, E-Mail, Telefon) werden verworfen; bleiben Bestellnummern und Bestimmungsland (Aggregat) zulässig (Art 5 Abs 1 lit c DSGVO)? Rolle der Nutzerin gegenüber Käuferdaten in der geteilten Datei (Cache) | Test über alle Tabellen (`platform_import_test.dart`); keine Übertragung | erster Upload | offen |
| P-R37 | Abo (FA-13.5, FA-13.6): (a) Pflichttext der Abo-Seite vollständig und richtig für AT/DE-Verbraucherinnen (§ 312j Abs 2 BGB wesentliche Merkmale, Laufzeit, Verlängerung; § 4 FAGG; Apple 3.1.2; Google Play Abo-Richtlinie: Testdauer, Folgepreis, Kündigungsweg)? (b) Store-Abfrage und Kaufblatt als Datenfluss: Einordnung in Google Data Safety („Käufe – Kaufverlauf“, erhoben vom Store, nicht von der App?) und Apple Label („Käufe“, nicht mit Identität verknüpft?) | Vorbefund Rechtsanwalt: Verkäufer und Verantwortlicher für Kaufdaten sind Apple bzw. Google; die App erhebt keine Kaufdaten, verarbeitet aber den Abostatus am Gerät. Vorsorglich als „Käufe/Kaufverlauf, App-Funktion, nicht geteilt“ angeben. Der frühere Store-Text „Ohne Abschluss eines Abos endet der Test von selbst“ passte nicht zum Store-Test (läuft in das Abo über) und wurde berichtigt (§ 5 UWG, § 2 UWG AT) | Store-Einreichung | offen |
| P-R40 | Instagram-Werbung für den Promo-Code (Textvorschlag `STORE_LISTING.md`): „2 Monate gratis“ nur mit Folgepreis, automatischer Verlängerung und Kündbarkeit im selben Beitrag (§ 5a UWG DE, § 2 Abs 4 / Anhang Z 20 UWG AT; „gratis“-Werbung), Kennzeichnung als Werbung bei bezahlten Beiträgen Dritter (§ 5a Abs 4 UWG DE, § 6 TMG bzw. § 6 DDG, § 6 ECG AT, § 26 MedienG AT); Instagram-Bezeichnung „Bezahlte Partnerschaft“ | Vorbefund Rechtsanwalt: Textvorschlag nennt Preis, Verlängerung, Kündbarkeit und „Neukunden“; eigene Beiträge der Firma sind erkennbar Werbung, Influencer-Beiträge brauchen „Werbung“/„Anzeige“ am Anfang. Mittlere Sicherheit | vor der ersten Kampagne | offen |
| P-R39 | Angebots-PDF: „Dieses Angebot ist gültig bis <Datum>“ bindet die Unternehmerin bis zu diesem Tag (§ 148 BGB Annahmefrist; AT § 862 ABGB). Reicht das, oder braucht es eine Option „freibleibend“/„unverbindlich“? | Vorbefund Rechtsanwalt: Fristsetzung ist zulässig und schafft Klarheit; „freibleibend“ wäre nur eine Aufforderung zur Angebotsabgabe. Frage, ob Nutzerinnen das wählen können sollen. Mittlere Sicherheit | Release | offen |
| P-R38 | Jahresabo und automatische Verlängerung um ein weiteres Jahr gegenüber deutschen Verbraucherinnen: § 309 Nr. 9 BGB (seit 1.3.2022 stillschweigende Verlängerung nur auf unbestimmte Zeit mit Monatskündigung) – greift das bei Store-Abos, deren Vertragsbedingungen Apple bzw. Google stellen, oder trifft es den Anbieter über die Nutzungsbedingungen 4.3? Ebenso § 312k BGB (P-R12) | Vorbefund Rechtsanwalt: Verkäufer ist der Store, dessen Verlängerungsmechanik gilt; Nutzungsbedingungen 4.3 beschreiben sie nur. Restrisiko, wenn der Anbieter als Vertragspartner der Leistung gilt; Alternative wäre ein Hinweis „Jahresabo jederzeit zum Periodenende kündbar“. Mittlere Sicherheit | Store-Start | offen |
| P-S11 | USt-Kette der Store-Abos: Leistung an Apple/Google in Irland, Reverse Charge, UID, ZM, UVA; gelten die Store-Abrechnungen als Gutschrift (§ 11 Abs 7 UStG AT)? | Kette sicher, Rechnungsstellung offen | erster Verkauf | offen |
| P-S12 | Vorsteuerabzug für Unternehmerinnen aus Store-Quittungen | unklar; kein Versprechen in App oder Werbung | erster Verkauf | offen |
| P-S13 | Verbuchung der Store-Auszahlungen (netto als Erlös empfohlen, Zufluss/Abgrenzung, Fremdwährung), W-8BEN(-E) | — | erster Verkauf | offen |
| P-S14 | Zählen Store-Umsätze (Leistungsort Irland) zur Kleinunternehmergrenze des Anbieters? Zusammen mit O-26 | voraussichtlich nein | erster Verkauf | offen |
| P-D8 | Zusatzsicherung unter Windows (`tool/sicherung/sicherung.ps1`): Erstlauf, Aufgabenplanung, Wiederherstellung | Linux-Variante getestet, Windows-Skript nie ausgeführt | sofort | offen |
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
| P-D20 | iPad hoch und quer (alle vier Ausrichtungen), Split View und Slide Over (1/3, 1/2, 2/3), Stage Manager; App Review akzeptiert Multitasking ohne `UIRequiresFullScreen` | Info.plist enthält alle vier iPad-Ausrichtungen, kein `UIRequiresFullScreen`; nur auf macOS/Gerät prüfbar | Release | offen |
| P-D21 | Gerätetest mit Netzwerkmitschnitt: Erkennung läuft offline; welche Endpunkte ruft ML Kit auf (Firelog)? | gehört zu P-R19 | Release | offen |
| P-D22 | Belegerkennung an mindestens 30 echten Belegen (Supermarkt, Tankstelle, Hotel, Online-Rechnung, Kleinbetrag, Fremdwährung, zerknittert/schräg): Quote je Feld (Datum, Brutto, Satz, Händler, UID, Rechnungsnummer); Gerätetest Android und iOS, auch im Flugmodus (Erkennung muss offline laufen) | Parser mit Testtexten geprüft; Android-Engine im CI-Emulator (Release mit R8) an synthetischem Bon geprüft, ersetzt nicht den Gerätetest; iOS nur kompiliert | vor Release | offen |
| P-D23 | DATEV-Import eines Buchungsstapels mit Fremdwährungsbeleg in einer echten DATEV-Kanzlei: genügt Euro ohne WKZ/Kurs, oder sind `WKZ Umsatz`, `Kurs` (Richtung!) und `Basis-Umsatz` zu befüllen? Ebenso BMD. Dazu „Kurs abrufen“ auf echtem Gerät inkl. Fehlerfall ohne Netz | Export nur Euro, Originalwerte in der Belegliste; EZB-Parser mit Beispieldatei geprüft | vor Fremdwährung | offen |
| P-D24 | App-Symbol auf dem Startbildschirm auf echtem Pixel (per APK installiert): Angebot erscheint einmal nach dem Onboarding, Systemdialog „Zum Startbildschirm hinzufügen“, Symbol erscheint, Tippen startet die App; Eintrag in den Einstellungen; Verhalten unter Android 8 und mit einem Fremd-Launcher | Dart-Logik getestet, Kotlin nur kompiliert (CI) | Release | offen |
| P-D25 | Auf echtem Gerät: Update auf Schema 11 mit bereits bezahlter Rechnung (Nachbuchung, Übersicht und Grenze), Termin-Box, Dialog „bezahlt“, Abstand unter den schwebenden Knöpfen | Tests mit ffi und Widget-Logik; Gerät fehlt | Release | offen |
| P-D26 | Hilfe auf echtem Gerät (Android und iPhone): Fragezeichen erreichbar und nicht verdeckt, Suche „Beleg löschen“, „Rückseite“, „Kleinunternehmergrenze“ liefert passende Abschnitte, Abschnitt lesbar, „E-Mail an den Support“ öffnet die Mail-App mit Betreff und Version, ohne Mail-App Dialog mit Adresse | Suche und Bildschirm getestet; Kotlin/Swift nur kompiliert (CI) | Release | offen |
| P-D27 | Geschlossener Test mit mindestens 12 Testerinnen aus der Zielgruppe über 14 Tage (Google-Play-Pflicht für persönliche Konten; als Beta auch beim Organisationskonto sinnvoll): Rückmeldungen zu Belegerkennung, Einhandbedienung, Verständlichkeit | — | Release | offen |
| P-D28 | Druckblatt Wiederherstellungscode auf echtem Gerät: Teilen an Drucker/„Als PDF speichern“/Passwortmanager, Ausdruck lesbar, QR-Code mit Kamera lesbar und ergibt den Code; Wiederherstellung auf zweitem Gerät mit abgetipptem Code. Stornorechnung-PDF ansehen (negative Beträge, Umlaute) | PDF-Erzeugung getestet, QR nur über die `barcode`-Bibliothek des `pdf`-Pakets | Release | offen |
| P-D29 | Rechnung und Stornorechnung aus der App über Gmail (Android) senden, danach eine weitere Datei teilen; **beim Empfänger** öffnet der PDF-Anhang (kein „Download fehlgeschlagen“); ebenso Outlook-App und WhatsApp | Ursache im Quelltext share_plus 10.1.4 belegt (`clearShareCacheFolder` bei jedem Teilen); Kotlin nur kompiliert (CI) | Release | offen |
| P-D30 | Store-Produkte anlegen (STORE_ANMELDUNG.md Abschnitt Abo): eine Abogruppe, IDs `basis_monat`, `basis_jahr`, `pro_monat`, `pro_jahr` exakt wie im Code, Preise nach Lastenheft 5.10, Einführungsangebot 14 Tage gratis auf beiden Pro-Produkten, Grace Period an; Verträge für kostenpflichtige Apps, Bank- und Steuerdaten; Store-Build mit `--dart-define=LICENSING=true` (CI-Release-Workflow) | Code erwartet genau diese IDs (`spec.license_product_ids`); ohne Schalter läuft jeder Build als Testversion | Store-Start | offen |
| P-D32 | Promo-Code in beiden Stores anlegen (`STORE_ANMELDUNG.md` Formular 4, Abschnitt Promo-Code) und einlösen: Android über die Abo-Seite und über `https://play.google.com/redeem?code=JENIBUCHT2M`, iOS über das Einlöseblatt und über den App-Store-Link mit echter Apple-ID der App (`id=<APP_ID>` ersetzen); Pro aktiv nach Rückkehr, Erinnerung zum Ende der 2 Monate, Kündigung in der Gratiszeit kostenlos | Logik mit Store-Ersatz getestet (`licensing_test.dart`); Apple-ID der App existiert noch nicht | vor der ersten Kampagne | offen |
| P-D33 | Lernen je Lieferant an echten Belegen: zweiter Bon desselben Händlers (andere Filiale, schlechteres Foto) wird erkannt und vorbelegt; keine falsche Zuordnung bei ähnlichen Namen (z. B. „Billa“ / „Billa Plus“) | Unit-Tests mit Varianten | vor Release | offen |
| P-D34 | Store-Screenshots mit den Demodaten aus `STORE_LISTING.md` aufnehmen (Android 1080×1920, iPhone 6,9", iPad 13"), Inhalt gegen Werbe-Negativliste prüfen; optional automatisiert über `integration_test` (Plan dort) | nur Plan und Demodaten | erste Einreichung | offen |
| P-D31 | Store-Abfrage auf Geräten (FA-13.6): StoreKit 2 ohne aktives Abo – kommt innerhalb 7 s eine Meldung oder gilt „leer“ zu Recht? Android mit Abo in Grace Period bzw. Kontosperre (on hold) – meldet Play den Kauf weiter? Kein falsches Herabstufen bei schlechtem Netz | Verlässlichkeit nur mit geladener Produktliste; sonst bleibt der Stand | Store-Start | offen |
