# Spezifikation – Buchhaltung

**Dokumentversion:** 1.98 · **App-Version:** 0.37.0 · **Stand:** 2026-10-20
**Status:** Testbuild 0.21.0 (Schema 23); Store-Start offen, siehe Abschnitt 11 und 14

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

### GR-16 · Mehrere Steuerländer: Umsatzsteuer je Registrierung, Gewinn im Heimatland

Seit 0.25.0 (FA-18.x). Die **Heimatregistrierung** ist das Firmenprofil; weitere
Länder stehen in `tax_registrations`. Jeder Beleg hat ein **Steuerland**
(`receipts.tax_registration_id`, `NULL` = Heimat). Umsatzsteuer (Sätze,
Vorsteuerabzug, Kennzahlen, Termine) folgt dem `TaxProfile` des Steuerlands und
der Besteuerungsform der Registrierung; die Länderregeln stehen ausschließlich
im `TaxProfile` (`registrationDeadlineRules`, `foreignTaxOffices`, GR-6).
**Ertragsteuer bleibt im Heimatland:** E1a bzw. Anlage EÜR summieren alle
Steuerländer, jedes mit seinem Vorsteuerabzug; Anlagen gehören zur Heimat. Ein
Amazon-Lager begründet nach Vorbefund keine Betriebsstätte (P-S74). Die
Kleinunternehmergrenze der Heimat zählt nur Heimatumsätze (P-S70).

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

### GR-15 · Anlagevermögen: Abschreibung ganzzahlig, Summe exakt

Ein Beleg, der als Investition erfasst ist, ist **keine Betriebsausgabe**;
statt dessen zählt die AfA (`PeriodTotals.capitalizedExpense`,
`depreciation`, `operatingExpense`). Die Vorsteuer daraus bleibt abziehbar.
Anschaffungskosten netto, beim Kleinunternehmer brutto (AT § 6 Z 11 EStG,
DE § 9b Abs 1 EStG). AfA-Plan in `lib/services/assets/depreciation.dart`:
kumuliert abgerundet – nach `k` von `n` Zeiteinheiten (DE Monate, AT
Halbjahre) sind `AK × k ~/ n` Cent abgeschrieben, die Jahres-AfA ist die
Differenz; Summe aller Jahre = AK exakt, das letzte Jahr trägt den Rest.
Gebucht wird am 31.12. (planmäßig, Sammelposten), am Anschaffungstag (GWG) und
am Tag des Ausscheidens (Restbuchwert). Kein Erinnerungswert (bei der
Einnahmen-Ausgaben-Rechnung weder AT noch DE vorgeschrieben, P-S60). Länderwerte
nur in `TaxProfile.depreciation`.

### GR-17 · Buchungsregeln: Anteil in Promille, Privatanteil als Restgröße

Eine Buchungsregel (FA-20.x) teilt jede passende Ausgabe in betrieblichen Teil
und Privatanteil. Anteil in Promille (GR-3), aus Fahrtenbuch- oder
Flächenzahlen in Tausendsteln (GR-4) kaufmännisch gerundet. Je Beleg und
Steuersatzzeile: betrieblicher Teil `(|Betrag| × ‰ + 500) ~/ 1000` mit
Vorzeichen, Privatanteil = Rest (`BookingRuleSplit`), Summe exakt. Basis netto,
beim Kleinunternehmer brutto. Vorsteuer nur im betrieblichen Anteil; unter
`TaxProfile.mixedUse.minBusinessPermilleForInputVat` (AT, DE 10 %) keine
Vorsteuer, deren betrieblicher Teil wird Aufwand. Länderwerte nur in
`TaxProfile.mixedUse`.

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
Anwendungsdokumentenverzeichnis. Aktuelle Schemaversion: **30**
(`spec.schema_version`). Bilder liegen als Dateien daneben: Belegseiten in
`belege/`, Firmenlogos in `logo/`, Seiten im Eingang der Mithelfer-Geräte in
`eingang/<uuid>/` (bis zur Übernahme, FA-17.5).

### 4.1 Tabellen

| Tabelle | Zweck | Besonderheit |
|---|---|---|
| `company_profile` | Firmenstammdaten | Genau eine Zeile, erzwungen durch `CHECK (id = 1)`. Seit Schema 27 `oss_participant` (0/1, FA-18.6). Seit Schema 28 `eu_sme_id` (TEXT, EU-KU-Nummer mit Suffix EX, FA-18.10) |
| `levy_settings` | Schlüssel/Wert für „Abgaben & Rücklagen“ (FA-19.6): `income_tax_prepayment_quarter` (Cent), `social_insurance_exempt`, `church_tax`, `freelancer` (0/1), `trade_tax_multiplier` (%), `health_insurance_monthly` (Cent) | Schema 29 |
| `tax_registrations` | Weitere steuerliche Registrierungen (FA-18.2): `country_code`, `vat_id`, `tax_number`, `tax_office`, `scheme` (`standard`/`smallBusiness`/`euSmallBusiness`), `filing_interval` (`monthly`/`quarterly`/`annual`/`none`), `permanent_extension` (0/1), `valid_from`, `valid_to` | Schema 27. Löschen nur ohne Belege, sonst Ende-Datum |
| `categories` | Buchhaltungskategorien | 21 Startkategorien, `is_system = 1` schützt vor Löschen. Seit Schema 25 „Material und Werkzeug“ (SKR03 4985, bestehende Datenbanken erhalten sie bei der Migration). Seit Schema 29 Abgabenkategorien „Sozialversicherung“ (SKR03 1800, `socialInsurance`), „Einkommensteuer-Vorauszahlung“ (1810, `incomeTax`), „Gewerbesteuer“ (4320, `tradeTax`), FA-19.4. Seit Schema 23 `kind` (`entertainment` = Bewirtung, FA-2.60; bestehende Datenbanken erhalten „Bewirtung“ bei der Migration) |
| `customers` | Rechnungsempfänger | Löschen blockiert, solange Rechnungen bestehen. Seit Schema 13 `is_business` (1 = Unternehmen; bei der Migration 1, wo eine UID eingetragen ist). Seit Schema 30 `buyer_reference` (Leitweg-ID/Auftragsreferenz/Käuferreferenz), `supplier_number` (eigene Lieferantennummer bei der Kundin) und `e_invoice_format` (`zugferd` Standard, `xrechnung`, `ebInterface`; FA-5.49) |
| `dunning_notices` | Zahlungserinnerungen und Mahnungen: `invoice_id`, `level`, `issued_on`, `new_due_date`, `principal_cents`, `fee_cents`, `fees_total_cents`, `interest_cents`, `interest_rate_bp`, `flat_fee_cents`, `total_cents`, `text`, `pdf_sha256`, `cancelled_at`, `cancel_reason`, `created_at` | Schema 13. Unveränderlich (Trigger); einzig erlaubt: einmaliges Storno mit Begründung |
| `receipts` | Belege | Index auf `date` und `direction`. Werden nie gelöscht, nur storniert (`cancelled_at`). Seit Schema 11 `invoice_id` (Einnahme aus bezahlter Rechnung, eindeutig je Rechnung und Steuersatz); seit Schema 17 `reverse_charge` (0/1, Steuerschuld des Leistungsempfängers, FA-2.46); seit Schema 23 `entertainment_occasion`, `entertainment_participants` (TEXT, Anlass und Teilnehmer der Bewirtung, FA-2.60) |
| `receipt_vat_lines` | Steuersatzzeilen eines Belegs: `receipt_id`, `position` ab 1, `vat_permille`, `net_cents`, `vat_cents`, `gross_cents` | Schema 14. Je Zeile `net + vat == gross`, Summe der Zeilen = `receipts.gross_cents` (erzwungen in `ReceiptRepository.writeVatLines`). Bei der Migration wurde jeder bestehende Beleg zu genau einer Zeile; Einnahmen aus bezahlten Rechnungen und Mahnkosten schreiben ihre Zeile mit. Kopf des Belegs: Summen, `vat_permille` = Satz der größten Zeile. Auswertungen lesen nur Zeilen (ein Beleg ohne Zeile zählt mit seinem Kopf) |
| `cash_register_merchants` | Lernspeicher Kasse → Händler (FA-2.36): `register_key` (`AT:<Kassen-ID>`, `DE:<Seriennummer>`), `merchant`, `updated_at` | Schema 15. Ersetzt beim Speichern eines Belegs mit Kassen-QR |
| `contracts` | Vertragsarchiv (FA-16.1): `type`, `title`, `partner`, `start_date`, `end_date`, `notice_value`, `notice_unit`, `rate_cents`, `rhythm`, `vat_permille`, `indexation`, `next_index_date`, `comment`, `ocr_text` (lokal erkannt, Zeilen mit `[S.n]`), `original_path` | Schema 22; Seiten in `contract_pages` (`contract_id`, `position`, `image_path` im Belegspeicher `belege/`, nur anhängen), Verknüpfung `contract_receipts` (`contract_id`, `receipt_id`) |
| `fixed_assets` | Anlagevermögen (FA-15.1): `receipt_id` (Anschaffungsbeleg, optional), `name`, `acquired_on`, `cost_cents`, `category_key`, `useful_life_years`, `method` (`linear`/`gwg`/`pool`), `life_reason`, `comment`, `disposed_on`, `disposal_kind`, `disposal_proceeds_cents`, `disposal_receipt_id`, `disposal_comment` | Schema 21. AfA-Plan wird berechnet, nicht gespeichert; Änderungen im `audit_log` |
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
| `helper_pairings` | Mithelfer-Geräte auf dem Hauptgerät (FA-17.1): `id` (16 Byte hex), `device_name`, `key_hex` (256 Bit), `transport` (`mail`/`folder`/`share`; seit 0.24.0 Standard `mail`), `created_at`, `revoked_at` | Schema 24. Trennen setzt `revoked_at` und löscht den Schlüssel; Zeile bleibt, damit spätere Pakete als „getrennt“ erkannt werden |
| `helper_inbox` | Eingang (FA-17.5): `uuid` (Beleg), `pairing_id`, `device_name`, `received_at`, `status` (`pending`/`accepted`/`rejected`), `reason`, `values_json` (Werte ohne Bilder), `page_paths` | Schema 24. `uuid` Primärschlüssel = Dublettenerkennung; Seitenpfade werden beim Abschließen geleert |
| `helper_outbox` | Belege auf dem Mithelfer-Gerät (FA-17.3, FA-17.10): `uuid`, `created_at`, `file_name`, `transport`, `status` (`queued`/`sent`/`accepted`), `summary`, seit Schema 26 `sent_at`, `package_path` | Schema 24, 26. Bilder nur im **verschlüsselten Einzelpaket** unter `ausgang/‹uuid›.jenibeleg` (Mailweg), gelöscht nach Ablauf der Aufbewahrung; sonst nur Betrag und Lieferant |
| `helper_mail_seen` | Hauptgerät: verarbeitete Belegmails (FA-17.11): `message_id` (Primärschlüssel), `seen_at`, `result` | Schema 26. Verhindert doppeltes Lesen; die Mail selbst bleibt unverändert im Postfach |
| `helper_settings` | Schlüssel/Wert: Hauptgerät `inbox_folder`, `inbox_folder_label`, `mail_receive` (Häkchen, eigene Adresse, IMAP-Server ohne Kennwort), `mail_last_poll`; Mithelfer `link` (Kopplung als JSON samt Schlüssel und Empfangsadresse), `mail_send` (Adresse, SMTP-Server ohne Kennwort), `mail_last_send`, `mail_last_reminder`, `mail_seq`, `retention_days`; beide `mail_permissions_explained` | Schema 24. **Kennwörter nie hier**, nur im sicheren Speicher (FA-17.9) |
| `booking_rules` | Buchungsregeln (FA-20.1): `name`, `rule_type` (`privateShare`/`businessShare`), `category_ids` (kommagetrennt), `supplier`, `registration` (`all`/`home`/`one`), `registration_id`, `business_permille` (0–1000, CHECK), `basis` (`logbook`/`area`/`estimate`/`other`), `basis_part_milli`, `basis_total_milli`, `valid_from`, `valid_to`, `comment` (Pflicht), `created_at`, `updated_at` | Schema 31. Kein Löschen, Ende über `valid_to` |
| `booking_rule_attachments` | Anhänge einer Regel (Fahrtenbuch, Grundriss): `rule_id`, `file_path` (Ordner `belege/`), `file_name`, `note`, `created_at` | Schema 31. Trigger verbietet Ändern |
| `booking_rule_log` | Verlauf einer Regel: `rule_id`, `text`, `created_at` | Schema 31. Trigger verbietet Ändern; Einträge bei Anlegen, Ändern (mit Unterschied), Anhang, Ausnahme |
| `booking_rule_exclusions` | Buchungen, die von einer Regel ausgenommen sind: `rule_id`, `receipt_id`, `created_at` | Schema 31. Schlüssel (`rule_id`, `receipt_id`) |
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
| `eu_sme_id` | TEXT | EU-KU-Nummer mit Suffix „EX“ (Schema 28, FA-18.10), getrennt von `vat_id`; leer = keine |
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

**`receipts`** — seit Schema 27: `tax_registration_id` (INTEGER, Verweis auf `tax_registrations`, `NULL` = Heimat; Index `idx_receipts_registration`; FA-18.3). Zusätzlich seit Schema 3: `cancelled_at` (TEXT, Zeitpunkt der Stornierung, `NULL` = gültig). Seit Schema 9: `document_number` (TEXT, Rechnungsnummer des Ausstellers), `issuer_vat_id` (TEXT, UID des Ausstellers), `currency` (TEXT, ISO 4217, Standard `EUR`), `original_gross_cents` (INTEGER, Betrag laut Beleg in fremder Währung, sonst `NULL`). `net_cents`, `vat_cents`, `gross_cents` sind immer Euro (FA-2.21). Seit Schema 10 (FA-2.24): `fx_rate_micros` (INTEGER, Kurs je 1 € × 10^6), `fx_rate_date` (TEXT, `YYYY-MM` beim Monatskurs, sonst `YYYY-MM-DD`), `fx_rate_source` (TEXT: `bmf_monthly`, `ecb_monthly_avg`, `ecb_daily`, `manual`, `bank`), `bank_gross_cents` (INTEGER, tatsächlich abgebuchter Euro-Betrag, `NULL` = wie `gross_cents`)

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

21 Kategorien, drei für Einnahmen und achtzehn für Ausgaben (seit 0.29.0 die Abgabenkategorien „Sozialversicherung“, „Einkommensteuer-Vorauszahlung“, „Gewerbesteuer“, FA-19.4; seit 0.21.0 mit „Bewirtung“, FA-2.60; seit 0.23.1 „Material und Werkzeug“, SKR03 4985 Werkzeuge und Kleingeräte / SKR04 6845, BMD-Export EKR 5300, Prüfung P-S66), mit SKR03-Konten.
Vollständige Liste: `AppDatabase.seedCategories` in `lib/data/app_database.dart`.
Eigene Kategorien sind ergänzbar und löschbar; die vorgegebenen nicht.

---

## 5. Funktionale Anforderungen

### 5.1 Firmenprofil

| ID | Anforderung |
|---|---|
| FA-1.1 | Beim ersten Start zeigt die App die geführte Ersteinrichtung (FA-1.13), bis Firmenname und Land erfasst sind und der letzte Schritt abgeschlossen oder übersprungen ist |
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
| FA-1.8 | Bei aktiver Kleinunternehmerregelung fragt das Profil den **Umsatz des Vorjahres** und den **Umsatz des laufenden Jahres vor Beginn der Erfassung** ab, soweit die App diese Zeiträume nicht selbst kennt. Vorjahr Pflichtfeld, leer ist nicht 0. Laufendes Jahr seit 0.35.0 (Entscheidung Auftraggeber 2026-10-20) optional: leer wird als 0 gespeichert, mit Hinweis „Kannst du leer lassen. Buch dann die Belege seit 1.1. nach, damit Umsatz und Grenze stimmen.“ – nachgebuchte Belege zählen über die Jahressumme mit |
| FA-1.9 | Beim Wechsel zur Regelbesteuerung bleiben erfasste Eröffnungswerte erhalten |
| FA-1.10 | **Bestätigungen vor der ersten Nutzung** (L-17.1 bis L-17.4; Schritt 1 der Ersteinrichtung, sonst eigener Bildschirm bei neuer Fassung): „Keine Steuerberatung“ mit **eigenem, nicht vorausgewähltem Häkchen**; „Nutzungsbedingungen/Datenschutz“ mit Links auf die Volltexte in der App (Nutzungsbedingungen, Datenschutzerklärung, je 48 dp) und Annahme über den beschrifteten Knopf **„Akzeptieren und weiter“** (56 dp) mit dem Satz „Mit „Akzeptieren und weiter“: Ich akzeptiere …“ – zwei Tipps statt drei (Prüfinstanz Rechtsanwalt 2026-10-19, P-R58). Ohne Häkchen ist der Knopf gesperrt. Erst danach Einrichtung, Demo, Wiederherstellung oder Koppeln. Gespeichert in `consents` mit Art, Textfassung und Zeitpunkt; eine neue Fassung in `LegalText` wird erneut abgefragt. **Keine Einwilligung für Werbung**, da keine Daten dafür erhoben werden |
| FA-1.12 | **Firmenlogo** (Lastenheft L-1.7, L-1.9): Auswahl aus der Fotobibliothek in den Stammdaten, verkleinert auf höchstens 800 px Kantenlänge bei 90 % Qualität (`spec.logo_max_edge_px`, `spec.logo_quality_percent`), abgelegt als **neue** Datei in `logo/`; Entfernen möglich. Logodateien werden nie überschrieben oder gelöscht. Das Logo steht im PDF oben rechts **zusätzlich** zu Name und Anschrift, nie an ihrer Stelle. Es wird mit dem `seller_snapshot` bei der Rechnungslegung eingefroren: gestellte Rechnungen zeigen das damalige Logo (Rechnungen vor Schema 8 keines), Entwürfe das aktuelle (`InvoiceLogo`). Der `seller_snapshot` eines Entwurfs wird bei jedem Speichern erneuert, ab dem Ausstellen nicht mehr. Ein unlesbares Bild verhindert das PDF nicht |
| FA-1.11 | Kennwort- und Code-Felder haben ein Auge-Symbol zum Anzeigen (`PasswordField`) |
| FA-1.13 | **Geführte Ersteinrichtung** (Rückmeldung Auftraggeber 2026-10-19, `features/onboarding/setup_wizard.dart`): **Willkommensseite** (Reihenfolge seit 2026-10-20: Titel, 24 dp, Logo, 24 dp, Unterzeile, 40 dp, Funktionszeilen) mit dem endgültigen Hauptlogo (seit 0.33.0, Entscheidung Auftraggeber 2026-10-19; `assets/brand/logo.png` Marineblau, im Dunkelmodus `logo_dark.png` mit Hellblau-Linien, je 1x/2x/3x, 280 × 103 dp, ohne Rand, transparent; DESIGN_SPEC 10a), „Willkommen bei JeNi bucht“ (headlineMedium, seit 0.31.0), Unterzeile „Rechnungswesen und Buchhaltung leicht gemacht. Ohne Vorwissen, nach den Regeln, die auch Profis anwenden.“ (`SetupWizard.welcomeSubline`, Wortlaut P-R60, 20 dp unter dem Titel) und vier Funktionszeilen mit Symbol (40 dp darunter; `SetupWizard.welcomePoints`: Belege scannen und auslesen · Rechnungen & E-Rechnungen schreiben (seit 0.32.0; vorher „Rechnungen stellen, E-Rechnung lesen“) · Verträge und Fristen im Blick · Saldenliste und Jahresübersicht), **jede Zeile einzeilig auf 360 dp** (Widget-Test misst die Textbreite, P-R61), ohne Scrollen auf 360 × 740 dp; unten „Los geht's“ (56 dp) und darüber „Erst ansehen (Demo)“ (56 dp, 12 dp Abstand; fragt zuerst das Land, FA-13.14), darüber „Sicherung wiederherstellen“ (48 dp). **Mithelfer-Gerät** (seit 0.31.0, Entscheid UX-Instanz): keine Pflichtfrage, sondern oben in Schritt 2 die Nebenoption „Dieses Gerät ist ein Mithelfer-Gerät (koppeln)“ (48 dp) mit „?“ – die meisten richten ein Hauptgerät ein und tippen sie nie. Jeder Weg führt zuerst über die Bestätigungen, falls offen. **Schritt 1** Bestätigungen (FA-1.10). **Schritt 2 – Dein Unternehmen (Pflicht):** Land (zwei Segmente, 48 dp), Name oder Firma *, Inhaber:in, Rechtsform, Straße, PLZ, Ort, Besteuerung (Kleinunternehmer/Regelbesteuerung, Segmente); bei Kleinunternehmer Gründungsjahr und Eröffnungsumsätze (FA-1.8). „Weiter“ speichert das Profil mit den Vorgaben aus FA-1.5 (Rechnungsnummer, Zahlungsziel, Mahnwerte). **Schritt 3 – Zusatzdaten (optional):** UID (FA-1.4a), Steuernummer, Firmenbuch/Handelsregister mit Gericht (FA-1.4e), E-Mail, Telefon (FA-1.4f), IBAN, BIC, Bank. **Schritt 4 – Extras (optional):** Logo (FA-1.12, FA-13.12), Datensicherung samt Wiederherstellungscode (Bildschirm Datensicherung), Weitere Länder (FA-18.1). **Schritt 5 – Abo wählen** (FA-13.15), nur im Store-Build ohne Abo; im Testbuild entfällt er automatisch und Schritt 4 endet mit „Fertig“. Kopfzeile „Schritt n von 5“ (bzw. „von 4“) mit Fortschrittsbalken (`spec.setup_steps`); Zurück über Kopfzeile und Systemgeste; Hauptknopf unten volle Breite 56 dp, „Später hinzufügen“ als Textknopf darüber (≥ 48 dp, 12 dp Abstand). Fortsetzen: Schritt in `helper_settings.setup_step`, Eingaben von Schritt 2 vor dem Speichern als Entwurf `setup_draft` (gebündelt nach 0,5 s); nach dem Schließen geht es am gespeicherten Schritt weiter. Danach bleiben Stammdaten und Einstellungen der Ort zum Bearbeiten (unverändert) |

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
| FA-2.5 | Das Feld **„Produkt oder Leistung“** (bis 0.27.0 „Beschreibung“, intern `description`) ist Pflichtfeld; Fehlermeldung „Bitte gib Produkt oder Leistung an …“. Spaltenname im Export bleibt „Beschreibung“ (8.2) |
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
| FA-2.31 | **Beschreibung und Kategorie vorschlagen** (0.3.4, `ReceiptClassifier`): Branche aus bekannter Kette oder Schlüsselwörtern (Maut/Vignette, Parken, Tankstelle, Taxi, Hotel, Fahrkarte, Supermarkt, Drogerie, Büro, Elektronik, Post, Telefon, Fachliteratur). Beschreibung = **was gekauft wurde, nicht bei wem** (seit 0.22.3, Gerätetest 0.22.2): erste Artikelzeile vor der Summe, bereinigt um Menge („1 x“, „Stk“), Artikelnummer, Preis, Steuerkennzeichen und Kürzel („SET 3L Lasurpinsel-S 12,99 A“ → „Lasurpinsel“), bei mehreren Artikeln mit „ u. a.“, höchstens 40 Zeichen; ohne Artikelzeile die Branche („Maut“, „Treibstoff“, „Bewirtung“, „Baumarkt-Einkauf“), sonst leer. Der Händlername wird nie in die Beschreibung kopiert; Beschreibungen werden nicht je Lieferant gelernt. Nur in ein leeres Feld. **Lieferant:** bekannte Ketten AT/DE (u. a. BAUHAUS, OBI, Hornbach, hagebau, Lagerhaus, Hofer, Aldi, Billa, Spar, Merkur, Lidl, Penny, dm, Bipa, Müller, Rossmann, IKEA, MediaMarkt, Saturn, Libro, Thalia, Post, ÖBB, DB, Shell, OMV, BP, Eni, JET, Aral, Esso, Turmöl, Avanti, Rewe, Edeka, Kaufland, Netto, Action, TEDi, KiK, XXXLutz, Möbelix, Hervis, Intersport, Decathlon, Amazon) ohne Groß-/Kleinschreibung und mit OCR-Varianten (0/O, 5/S, 1/l) als Wort in den ersten acht Zeilen, sonst Zeile mit Rechtsform (GmbH, AG, KG, OG, e.U., Ltd …) im Kopf vor der ersten Zeile, Name endet an der Rechtsform; bei abgeschnittenem Kopf Kette weiter unten (Kartenbeleg) mit geringerer Konfidenz. Zeilen, die wie Artikel aussehen (Preis am Ende, Menge, Artikelnummer, Kürzel mit Mengeneinheit), sind nie Lieferant. Baumarkt (BAUHAUS, OBI, Hornbach, hagebau, Lagerhaus, toom) → „Material und Werkzeug“ (seit 0.23.1, Entscheidung Auftraggeberin 2026-10-17); Möbel, Sport/Diskont → Sonstige Ausgaben. Der Lieferanten-Lernspeicher (FA-2.50) geht weiter vor. Kategorie nur aus den Startkategorien und nur, wenn eine Kategorie mit diesem Namen existiert: Maut/Parken/Treibstoff → Kfz-Kosten, Taxi/Hotel/Fahrkarte → Reisekosten, Supermarkt/Drogerie → Sonstige Ausgaben. Beide Felder „erkannt – bitte prüfen“. Neue Belege starten mit „Sonstige Ausgaben“ bzw. „Sonstige Einnahmen“ statt der alphabetisch ersten Kategorie (vorher „Bankspesen“) |
| FA-2.32 | **Beleg ohne Steuerausweis** (z. B. nur Kartenbeleg): kein Satz erkannt, Betrag erkannt, Ausgabe → 0 % („ohne Vorsteuer“) mit Hinweis aus `TaxProfile.noVatShownHint` (AT § 11 Abs 6 UStG, DE § 33 UStDV); die App erfindet keinen Satz (P-S29). Erkannter Satz, den die App nicht kennt: nicht vorbelegen, Hinweis „in der App noch nicht hinterlegt“. Satz vor seinem Gültigkeitsbeginn: nicht vorbelegen, Hinweis „gilt aber erst ab …“ |
| FA-2.20 | Formularfelder **Rechnungsnummer** und **UID des Ausstellers** (Schema 9). Mehrere Steuersätze erkannt: seit 0.7.0 Aufteilung vorbelegt (FA-2.34) |
| FA-2.21 | **Fremdwährung** (L-2.21): nur bei Ausgaben. Erkannte Währung ≠ EUR füllt das Euro-Feld nicht, sondern schaltet das Formular auf Fremdwährung (FA-2.24) mit Betrag laut Beleg. Einnahmen bleiben immer Euro |
| FA-2.24 | **Fremdwährung umrechnen** (L-2.24): Schalter „Beleg in fremder Währung“ bei Ausgaben; Felder Währung (ISO 4217), Betrag laut Beleg, Kurs (Einheiten je 1 €, höchstens 6 Nachkommastellen), Kursquelle, Kursdatum; das Euro-Brutto wird nach GR-9 berechnet und angezeigt, Netto/Steuer nach GR-2 |
| FA-2.25 | **Kurs abrufen** (L-2.25, L-19.29): nur auf Knopfdruck lädt `EcbClient` `eurofxref-hist-90d.xml` (Beleg bis 80 Tage alt) bzw. `eurofxref-hist.xml` direkt bei der EZB, speichert alle Kurse in `ecb_rates` und nutzt danach den Speicher. Standard ist das **Mittel aller EZB-Tageskurse des Belegmonats** (half-up auf 10^-6), gekennzeichnet „EZB-Monatsmittel – Näherung an BMF-Kurs“; im laufenden Monat als vorläufig markiert. Den **Tageskurs** (letzter Kurs am oder vor dem Belegdatum) nutzt die App nur, wenn in den Einstellungen „Tageskurs vom Finanzamt genehmigt“ eingeschaltet ist. Manueller Kurs (Quelle `manual`, `bmf_monthly`, `bank`) jederzeit; ein von Hand geänderter EZB-Kurs wird zu `manual`. Hinweis „EZB-Referenzkurs, ohne Gewähr“ |
| FA-2.26 | **Bankbetrag** (L-2.26): optionales Feld „Tatsächlich abgebucht (EUR)“ (`bank_gross_cents`). `PeriodTotals.expenseFxDifference` = Σ(Bank − umgerechnet); `profit` zieht sie ab, `expensePaidGross` zeigt Ausgaben laut Bank. Vorsteuer, UVA und Umsatz bleiben beim Umsatzsteuer-Kurs |
| FA-2.27 | **Protokoll** (L-2.26): jedes Speichern eines Fremdwährungsbelegs schreibt `audit_log`-Eintrag `fx` mit Währung, Originalbetrag, Kurs, Quelle, Kursdatum, umgerechnetem Betrag und ggf. Bankbetrag mit Differenz |
| FA-2.22 | **Protokoll** (L-2.22): beim Speichern eines ausgelesenen Belegs ein `audit_log`-Eintrag `scan` mit Engine und Version, je Feld erkannter Wert mit Konfidenz, bestätigter Wert und Kennzeichen `GEÄNDERT`, sowie SHA-256 jedes Originalbilds. Keine Bilddaten, kein Volltext |
| FA-2.23 | **Abschaltbar** (L-2.23): Einstellungen → „Belege auslesen“, Standard an (`company_profile.receipt_scan_enabled`) |
| FA-2.33 | **Beleg mit mehreren Steuersätzen aufteilen** (L-2.27, 0.7.0), z. B. Bewirtung Speisen 10 %/Getränke 20 %, Supermarkt 4,9/10/20 %: im Formular „Weiteren Steuersatz hinzufügen“ (volle Breite, 48 dp). Je Teil Satz und **Bruttobetrag**; Netto und Steuer je Teil nach GR-2 (Steuer als Restgröße). Der erste Teil startet mit dem ganzen Betrag, der letzte Teil übernimmt automatisch den Rest (Belegbetrag − übrige Teile), bis er von Hand geändert wird. Speichern nur, wenn die Summe der Teile den Belegbetrag exakt ergibt; sonst Meldung mit Differenz. Teile mit gleichem Satz werden zusammengefasst, Teile mit 0 € entfallen; bleibt ein Teil, ist der Beleg wieder einfach. Bei Fremdwährung sind die Teile Euro-Beträge des umgerechneten Betrags. Belegliste zeigt die Sätze („10 % + 20 %“). Ausländische Steuer und 0 %-Regeln gelten je Teil (FA-2.29). Die Abzugsbeschränkung für Bewirtung hängt an der Kategorie, nicht an der Aufteilung (FA-2.60) |
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
| FA-2.51 | **Dokumentenscanner des Systems** (Entscheidung Auftraggeberin 2026-10-16): „Beleg fotografieren“, „Seite fotografieren“ und im Vertragsarchiv „Seiten scannen“ öffnen zuerst den Scanner – Android Google ML Kit Document Scanner (`play-services-mlkit-document-scanner` 16.0.0, voller Modus mit Filtern und Schattenentfernung, mehrere Seiten bis `spec.scanner_page_limit`, Import aus der Galerie erlaubt), iOS VisionKit `VNDocumentCameraViewController`. Eigener Channel `buchhaltung/document_scanner` (`DocumentScannerChannel.kt`, Klasse in `ReceiptTextChannel.swift`) statt Paket: gleiche Bauart wie Texterkennung, keine weitere Abhängigkeit. Jede Seite wird danach in einem Hintergrund-Isolate nachbearbeitet (`ScanEnhancer`, Paket `image`, das über `pdf` ohnehin im Build ist): lange Kante höchstens 2400 px, Tonwertkorrektur über die Helligkeit mit je 1 % Abschnitt, Gamma 0,85 (Papier weißer), Unscharf maskieren 3×3, fast farblose Seiten (mittlere Sättigung < 18) grau, JPEG-Qualität 85; nicht dekodierbare Seiten bleiben unverändert. Erst dann gehen die Seiten in den Belegspeicher und – über denselben Weg wie Kamerafotos (`ScanIntake`, Einstellung frisch geladen) – in die Texterkennung und Vorbelegung (FA-2.19). Robustheit (Gerätetest 0.21.0): jede Kanal-Antwort wird genau einmal abgeschlossen (Ergebnis, Abbruch, Fehler); die offene Antwort hängt am Prozess, nicht an der Activity; kommt nach der Rückkehr in die App kein Ergebnis, endet der Scan mit dem Fehler `lost` und einer Meldung (seit 0.22.1, nicht mehr still als Abbruch); alle Android-Request-Codes stehen eindeutig in `RequestCodes.kt` (Gerätetest 0.22.0: Scanner und Sicherungsordner teilten 4711, das Scan-Ergebnis wurde verschluckt; Test prüft Eindeutigkeit); **kein stiller Weg**: Plattformfehler außer `unavailable`, nicht ablegbare Seiten und Fehler beim Auslesen erscheinen als Meldung (`ScanIntake.onError`), scheitert nur die Nachbearbeitung (auch `Error` im Isolate), wird das Original abgelegt; ein neuer Aufruf ersetzt eine liegengebliebene Antwort; in Dart endet ein Doppeltipp sofort, die Sperre wird im `finally` zurückgesetzt. **Gespeichert wird nur das verarbeitete Bild** (P-S63). Abbrechen = nichts passiert. Kein Scanner (keine Play-Dienste, Modul-Download fehlgeschlagen, Huawei, iOS-Gerät ohne Unterstützung) → **automatisch** die bisherige Kamera, ohne Rückfrage. Der CI-Korpustest der Erkennung umgeht den Scanner (Bilder direkt) |
| FA-2.60 | **Bewirtung mit Abzugsbeschränkung** (Entscheidung Auftraggeberin 2026-10-16, Lastenheft 14a; schließt P-S46-Grenze): Startkategorie „Bewirtung“ (SKR03 4650, `categories.kind = 'entertainment'`, Schema 23). Ausgaben dieser Kategorie zählen nur anteilig als Betriebsausgabe: AT 50 % (§ 20 Abs 1 Z 3 EStG, Werbezweck; ohne Werbezweck 0 % – die App setzt den Regelfall 50 %), DE 70 % (§ 4 Abs 5 Satz 1 Nr. 2 EStG). Basis je Beleg: netto, beim Kleinunternehmer brutto. Abziehbarer Teil kaufmännisch auf Cent gerundet, nicht abziehbarer Teil = Rest (`EntertainmentSplit`); Summen = Summe der Belegwerte. **Vorsteuer voll** in beiden Ländern: DE § 15 Abs 1a Satz 2 UStG; AT § 12 Abs 2 Z 2 lit a UStG 1994 schließt nur Leistungen aus, die überwiegend (über 50 %) nicht abzugsfähig sind – die zur Hälfte abzugsfähige Bewirtung bleibt voll abziehbar (UStR 2000 Rz 1934; Sicherheit mittel, P-S46). Der nicht abziehbare Teil (`PeriodTotals.entertainmentNonDeductible`) wird dem Ergebnis hinzugerechnet und erscheint in Übersicht, Kennzahlen Jahreserklärung (Hilfszeile ohne Kennzahl, P-S46), Saldenliste, Jahresabschluss (E/A-Rechnung „Hinzurechnung“), Belegliste-CSV (Spalte und Summenzeile), USt-Zusammenfassung und DATEV (Umbuchung auf 4654, BU 40). Formular: bei Kategorie Bewirtung Hinweistext je Land; nur DE zusätzlich **Anlass** und **Teilnehmer** als freiwillige Vorschlagsfelder (§ 4 Abs 5 Satz 1 Nr. 2 Satz 2 EStG), Speichern nie blockiert. Belegerkennung schlägt für Restaurants (Gasthaus, Pizzeria, Tisch …) die Kategorie vor; der Lieferanten-Lernspeicher (FA-2.50) merkt sie sich. Kennwerte `spec.at.entertainment`, `spec.de.entertainment` |
| FA-2.61 | **Diktat auf dem Gerät** (Auftrag Auftraggeberin 2026-10-16): Mikrofonknopf (`DictationButton`, `lib/widgets/dictation_button.dart`, 48 × 48 dp) als Suffix in Freitextfeldern – Beleg: Beschreibung, Anlass, Teilnehmer, Notiz, Kommentar; Vertrag: Kommentar – und in jedem `MoneyField` (Betragsfelder). Tippen startet, erneutes Tippen oder Sprechpause beendet; Zwischentext live im Feld, Fehler stellt den alten Text wieder her. Nur Erkennung **auf dem Gerät** über eigenen Channel `buchhaltung/dictation`: Android `SpeechRecognizer.createOnDeviceSpeechRecognizer` ab Android 12 mit `isOnDeviceRecognitionAvailable` (`DictationChannel.kt`, `RECORD_AUDIO` zur Laufzeit), iOS `SFSpeechRecognizer` mit `requiresOnDeviceRecognition` und `supportsOnDeviceRecognition` (Klasse in `ReceiptTextChannel.swift`, Sprechpause 2 s). Sprache aus `TaxProfile.speechLocale` (de-AT/de-DE). Ohne Erkennung auf dem Gerät **kein Knopf**, kein Rückfall ins Netz; das Diktat der Tastatur bleibt. Beträge: `SpokenAmount.parse` (`lib/services/dictation/spoken_amount.dart`) liest „zwölf Euro fünfzig“, „zwölf komma fünf null“, „eintausendzweihundert“, „fünfzig Cent“, „1200,50“ u. a. in ganze Cent (höchstens 99 999 999,99 €); das Feld zeigt den Betrag als Vorschlag mit „Gesprochen – bitte prüfen“, bestätigt wird beim Speichern; Unverstandenes ändert das Feld nicht. Tarif: Vorschlag Basis (Barrierefreiheit), Lastenheft 14a; bis zur Entscheidung ohne Sperre |
| FA-2.62 | **Betrag und Sätze in fester Rangfolge** (Gerätetest 0.23.1, OMV-Beleg: 7,96 € zu 20 % statt 8,96 € mit 7,96 € zu 20 % und 1,00 € Pfand zu 0 %): (1) **Kassen-QR** (RKSV/TSE) mit Betrag je Satz, (2) **gedruckte Steuertabelle** mit einer Zeile je Satz („20,0 6,64 1,32 7,96“ / „0,0 1,00 0,00 1,00“, auch 0 %; Zeile gilt nur mit Rechenprobe Netto + Steuer = Brutto, bei 0 % Steuer 0,00), (3) Schlüsselwörter Gesamtbetrag/Summe/Total/Zu zahlen, (4) übrige Heuristik. Ein eindeutiger Gesamtbetrag größer als die lesbaren Tabellenzeilen bleibt stehen (fehlende Zeile). **Zahlungszeilen** (Wertbon, Gutschein, Karte, Mastercard, Maestro, Visa, Bankomat, Bar, Cash, kontaktlos, Rückgeld …) sind nie der Gesamtbetrag. Gedruckte Netto/Steuer je Satz werden in die Aufteilung übernommen, wenn Netto + Steuer = Teilbetrag und die Steuer höchstens 2 Cent + 1 Cent je 10 € von der Rechnung abweicht (Rundung je Position); sonst wird gerechnet (GR-2). **Codes auf jeder Seite** in jedem Weg (Kamera, Scanner, Datei/Teilen, Mithelfer-Eingang): bei PDF mit Textebene werden die Seitenbilder zusätzlich nach Codes durchsucht, beim Dokumentenscanner auch das unverbesserte Original vor der Kontrastverstärkung. **Händler**: kurze Kopfzeile, die mit einer bekannten Kette beginnt, ist der Name; OCR-Trennungen bekannter Wörter werden geschlossen („OMV Tankstel le“ → „OMV Tankstelle“). **Tankstelle ohne Treibstoff**: Kfz-Kosten und „Treibstoff“ nur bei Treibstoffzeile (Diesel, Super, Benzin, AdBlue, Liter/Literpreis); sonst Beschreibung aus den Artikeln (Kassenkürzel wie „VÖSL.MIN“ ausgeschrieben) und neutrale Kategorie. Korpusbeleg `omv_kaiserwald_20260519.jpg`, Prüfpunkt P-D43 |
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
| FA-4.14 | **Anzeige je Land** (seit 0.31.0): Kennt das Land eine eigene Vorjahresgrenze unter der laufenden (DE: 25.000 € / 100.000 €, § 19 Abs 1 UStG), misst der Balken an 25.000 €, solange der Umsatz darunter liegt (`SmallBusinessAssessment.displayLimit`, `nextYearLimit`), danach an 100.000 €. Über 25.000 € Status *Grenze naht* mit „In diesem Jahr bleibt die Regelung bis 100.000 €, ab dem nächsten Jahr gilt die Regelbesteuerung“; ab 80 % von 25.000 € Vorwarnung. Unter dem Balken die Grenzen des Landes (`limitsNote`): DE „§ 19 UStG: 25.000 € Vorjahr · 100.000 € laufendes Jahr“ (Gründungsjahr: 25.000 €), AT „§ 6 Abs 1 Z 27 UStG: 55.000 € im Vorjahr und im laufenden Jahr, Toleranz bis 60.500 €“ (P-S85) | 

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
| FA-5.46 | **Angebots-PDF** (`InvoicePdf.offer`, L-3.17, L-3.31): Titel „Angebot <Nummer>“, nie „Rechnung“; Kopf „Angebot für“, „Angebotsnummer“, „Angebotsdatum“, „Gültig bis“; statt Zahlungsangaben „Dieses Angebot ist gültig bis <Datum>. Wir freuen uns auf Ihren Auftrag.“ (Sie-Form) und AGB-Verweis; Kleinunternehmerhinweis wie bei Rechnungen. Logo nach FA-13.12. „PDF ansehen“ öffnet den Betrachter (FA-5.48), dort „Senden“ mit Tarifschnitt `pdfSending` (FA-13.11) |
| FA-5.44 | **Artikel** (`domain/article.dart`, `ArticleRepository`): Bezeichnung, Einzelpreis netto, Einheit, Steuersatz (bei Kleinunternehmern ausgeblendet), freiwillig Artikelnummer (eindeutig, L-11.2) und kurze Beschreibung. Liste mit Suche nach Bezeichnung oder Nummer ab sechs Artikeln (L-11.9). Kein Lagerstand (L-11.3 ist Stufe B) |
| FA-5.45 | **Position übernehmen** (L-11.5, L-11.6): Knopf „Aus Artikeln und Vorschlägen“ in Rechnung und Angebot öffnet ein Bottom-Sheet; oben die Artikel, darunter früher verwendete Positionen aus Rechnungen (ohne Stornorechnungen) und Angeboten, je Bezeichnung die zuletzt verwendete, ohne Dubletten zu Artikeln. Ein Tipp übernimmt Bezeichnung (mit Beschreibung), Einheit, Preis, Steuersatz, Menge 1 und ersetzt eine leere letzte Position; alles bleibt änderbar. Freie Positionen bleiben jederzeit möglich. Suchfeld unten im Sheet ab sechs Vorschlägen |
| FA-5.47 | **Erreichbarkeit** (UX-Prüfinstanz): Rechnungsliste oben zwei gleich breite Knöpfe „Angebote“ und „Artikel“ (48 dp); Angebotsformular unten `PrimaryActionBar` mit „PDF senden“ und „Speichern“ bzw. „Zur Rechnung machen“; Listenzeilen ≥ 56 dp; Zurück speichert ein gespeichertes Angebot still, ein neues mit Eingaben fragt einmal (wie FA-5.34). Geräteprüfung P-U8 |
| FA-5.48 | **PDF-Betrachter** (`features/pdf_viewer/pdf_viewer_screen.dart`, Paket `printing`): Jedes erzeugte PDF öffnet zuerst im Betrachter – Rechnung, Stornorechnung, Zahlungserinnerung/Mahnung, Angebot, Saldenliste, vorläufiger Jahresabschluss, Anlagenverzeichnis – und PDF-Anhänge eines Belegs („Ansehen“ neben der Originaldatei). Seiten als Bilder (144 dpi, `Printing.raster`) in einer `PageView` (wischen) mit `InteractiveViewer` (Pinch-Zoom bis 5×), Anzeige „Seite x von n“. Leiste unten, drei Knöpfe je 56 dp: **Schließen**, **Drucken** (Systemdruckdialog `Printing.layoutPdf`, dort auch „Als PDF speichern“; in jedem Anspruch frei, L-10.4), **Senden** (Rechnung/Storno/Angebot `pdfSending`, Mahnung `dunningSending` nach FA-13.11 mit „(Pro)“; Berichte und Anhänge wie ein Export). Angebot gilt erst nach „Senden“ als gesendet. **Demo:** Wasserzeichen steht im PDF selbst (FA-13.14) und ist im Betrachter sichtbar; Drucken und Senden gedimmt mit Hinweiszeile, Tippen öffnet das Demo-Blatt, nichts verlässt das Gerät. Gerätetest P-X26, P-D54. **Papier immer weiß** (seit 0.31.0): Seite auf weißem `Material` (`pdfPaperColor`, ohne Oberflächentönung), keine Farbfilter; im dunklen Modus bleibt nur der Rand dunkel (Rückmeldung zu 0.30.0: Seite wirkte dunkel, weil das Rasterbild transparent ist) |
| FA-5.49 | **E-Rechnung erstellen** (Entscheidung Auftraggeber 2026-10-19, L-4.1, L-4.2; `services/e_invoice/e_invoice_writer.dart`, `e_invoice_output.dart`): aus jeder gestellten Rechnung und Stornorechnung beim **Ansehen**. **Standard ZUGFeRD-PDF:** das Rechnungs-PDF wird eine **PDF/A-3b** (XMP mit `pdfaid:part` 3 und Factur-X-Erweiterung `fx`, Konformitätsstufe „EN 16931“, sRGB-Ausgabeabsicht `assets/icc/sRGB2014.icc`, eingebettete Schrift) mit eingebetteter `factur-x.xml` (`spec.einvoice_zugferd_file`, `AFRelationship` `Alternative`); XML nach UN/CEFACT CII D16B, Profil EN 16931 (`spec.einvoice_guideline_en16931`; ZUGFeRD 2.x / Factur-X 1.0x). Betrachter-Hinweis „Mit E-Rechnung (ZUGFeRD): Menschen lesen das PDF, Programme die Daten.“ **Behörden:** Format je Kundin (`customers.e_invoice_format`): **XRechnung 3.0** in CII-Syntax (`spec.einvoice_guideline_xrechnung`, BT-23 `urn:fdc:peppol.eu:2017:poacc:billing:01.0`, Leitweg-ID als BT-10) bzw. **ebInterface 6.1** (`spec.einvoice_ebinterface_namespace`, Auftragsreferenz als `OrderReference/OrderID`, Lieferantennummer als `InvoiceRecipientsBillerID`); der Betrachter zeigt das PDF, „**XML senden**“ (56 dp) teilt die XML-Datei (`XRechnung_<Nr>.xml`, `ebInterface_<Nr>.xml`), Drucken druckt das PDF. **Inhalt:** Nummer, Art 380 bzw. **381 (Stornorechnung als Gutschrift mit positiven Beträgen, Bezug BT-25/BT-26 auf die Rechnung)**, Datum, Leistungsdatum, Positionen mit Menge (Einheit nach UN/ECE Rec. 20, `unitCode`), Nettopreis, Positionsrabatt als Abschlag, Steuer je Position; Gesamtrabatt und Versandkosten als Ab-/Zuschlag **je Steuersatz** (wie `InvoiceTotals`), Steueraufstellung je Satz aus `InvoiceTotals.breakdown` (Steuer je Position gerundet, GR-5; EN 16931 BR-CO-17 lässt die Abweichung zur Summenrundung zu), Summen nach BR-CO-10/13/15; Kategorie `S`, bei Kleinunternehmer **`E` mit Befreiungsgrund = Pflichthinweis des Landes** (`smallBusinessInvoiceNote`, P-S86), 0 % bei Regelbesteuerung `Z`; Verkäufer mit UID (VA) und Steuernummer (FC), ohne UID Firmenbuchnummer (BT-30) bzw. Steuernummer als Kennung (BT-29, BR-CO-26); Kontakt, E-Mail (EM), IBAN/BIC (Zahlungsart 58), Zahlungsziel BT-9, Zahlungsbedingungen BT-20 mit Skonto in der Schreibweise `#SKONTO#TAGE=7#PROZENT=2.00#` (P-S87). **Prüfung vorher** (`EInvoiceCheck.missing`): fehlen Pflichtangaben (alle: Anschrift, UID oder Steuernummer, PLZ/Ort der Kundin; XRechnung zusätzlich Leitweg-ID, E-Mail beider Seiten, Telefon, IBAN; ebInterface Auftragsreferenz, Lieferantennummer, IBAN), entsteht keine E-Rechnung, der Hinweis nennt die Angaben („Ohne XRechnung – es fehlt: …“). **Tarif:** `Feature.eInvoiceIssue` nur Pro (Lastenheft 5.10); ohne Pro Hinweis „E-Rechnung … gibt es mit Pro“, in der Demo normales PDF. **Validierung:** Tests prüfen jede Variante gegen das XSD (Factur-X 1.09 EN 16931, ebInterface 6.1; `test/fixtures/e_invoice_schemas/`, `xmllint`) und die Rundreise über `EInvoiceParser` (gleiche Summen je Satz); intern zusätzlich mit Mustang 2.26 (EN-16931- und XRechnung-3.0-Schematron, veraPDF PDF/A-3b) ohne Fehler geprüft (14) |

**Pflichtangaben im PDF** (§ 11 UStG AT, § 14 UStG DE): Name und Anschrift von
Aussteller und Empfänger, Steuernummer bzw. UID des Ausstellers,
Ausstellungsdatum, fortlaufende Nummer, Menge und Bezeichnung der Leistung,
Liefer-/Leistungsdatum, Entgelt je Steuersatz, Steuersatz und Steuerbetrag oder
– bei Befreiung – der Grund der Befreiung.

### 5.5a Datensicherung

| ID | Anforderung |
|---|---|
| FA-7.1 | Vollsicherung aller Tabellen (konsistenter Schnappschuss per `VACUUM INTO`) und aller Belegfotos in **eine Datei** `Sicherung_JJJJ-MM-TT_HHMM.jbbackup` |
| FA-7.2 | Verschlüsselung AES-256-GCM, Schlüssel per Argon2id aus einem Kennwort der Nutzerin (19 MiB, 2 Durchläufe, Parallelität 1); seit 0.35.0 (Entscheidung Auftraggeber 2026-10-20) **Zahlencode aus genau 8 Ziffern** (`BackupCrypto.codeLength`, Ziffernblock), zweimal einzugeben; ältere Sicherungen mit Kennwort bleiben lesbar. Risiko: 10⁸ Codes sind bei erbeuteter Datei offline durchprobierbar (P-D58). Dateiformat siehe `lib/services/backup/backup_crypto.dart` |
| FA-7.3 | Ablage über den Teilen-Dialog: die Nutzerin wählt iCloud Drive, Google Drive, Dateien oder ein anderes Ziel. Kein Server des Anbieters, keine automatische Übertragung |
| FA-7.4 | Wiederherstellen: Datei wählen, Kennwort eingeben, **Vorschau** (Unternehmen, Datum, Anzahl Belege, Rechnungen, Kunden, Fotos), ausdrückliche Bestätigung; dann werden alle Daten und Fotos ersetzt, in einer Transaktion |
| FA-7.5 | Falsches Kennwort und veränderte Dateien werden erkannt (Authentifizierungs-Tag) und nicht eingelesen; fremde Dateien und Sicherungen einer neueren App-Version werden abgelehnt; ältere Sicherungen werden auf das aktuelle Schema migriert |
| FA-7.6 | Pfade im Archiv außerhalb von `belege/` und `logo/` werden verworfen. Gesichert werden alle Belegseiten und alle Logodateien; Seiten und Kommentare stecken in der Datenbank. Sicherungen ohne `logo/` (vor Schema 8) bleiben lesbar und werden auf Schema 8 migriert; beim Wiederherstellen werden beide Ordner ersetzt |
| FA-7.7 | Erinnerung auf der Übersicht, wenn noch nie oder seit **30 Tagen** nicht gesichert wurde (`spec.backup_reminder_days`) |
| FA-7.8 | Wiederherstellung auch direkt aus der Ersteinrichtung auf einem neuen Gerät; sie wird im `audit_log` vermerkt |
| FA-7.9 | **Automatische Sicherung** (Opt-in nach Erklärseite): Ordner einmal wählen (iOS `UIDocumentPicker` + Security-Scoped Bookmark, `ios/Runner/BackupFolderChannel.swift`; Android Storage Access Framework mit dauerhafter Berechtigung, `BackupFolderChannel.kt`); Kanal `buchhaltung/backup_folder`; derselbe Kanal liefert mit `pickFile` die Datei für die Wiederherstellung (kein `file_picker`) |
| FA-7.10 | Schlüssel: 256 Bit zufällig, gespeichert über `flutter_secure_storage` (iOS `first_unlock_this_device`, nicht synchronisiert); **Wiederherstellungscode** (Base32, 52 Zeichen in 13 Vierergruppen) nur als lokal erzeugtes **Druckblatt** (PDF mit Blöcken, QR-Code und Aufbewahrungshinweis, `RecoveryCodeSheet`) über Teilen/Drucken; die App zeigt den Code nicht an und behält keine Kopie (L-22.21). Danach „Code ist aufbewahrt“, sobald das Druckblatt geteilt wurde; das Abtippen von zwei Blöcken entfällt seit 0.35.0 (Entscheidung Auftraggeber 2026-10-20, Abweichung von L-22.22). Bildschirm `recovery_code_setup_screen.dart`, Knopf unten in der `PrimaryActionBar`. Ausschalten löscht den Schlüssel |
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
Feiertage in `lib/domain/holidays.dart`. Termine weiterer Registrierungen und
OSS: FA-18.5, FA-18.6 (Kennzeichen `q` = immer vierteljährlich).

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
| FA-9.1 | Breitenklassen nach Material 3 aus der **Fensterbreite** (auch im geteilten Bildschirm): compact < 600 dp, medium 600–839 dp, expanded ≥ 840 dp (`spec.window_medium_min_dp`, `spec.window_expanded_min_dp`). Seit 0.36.0 (Gerätetest 2026-10-20): bei einer Fensterhöhe unter 480 dp (`spec.window_compact_max_height_dp`, Telefon quer) höchstens medium – schmale Navigationsleiste mit Beschriftung, kein Liste-Detail, Inhalt über die volle Breite. Kein Widget vergleicht selbst mit Pixelzahlen |
| FA-9.2 | Hauptnavigation: compact `NavigationBar` unten; medium `NavigationRail` links mit Beschriftung unter dem Symbol; expanded ausgeklappte `NavigationRail`. Ziele und Reihenfolge unverändert (Abschnitt 7) |
| FA-9.3 | **Liste-Detail** ab expanded für Belege, Rechnungen und Kunden: Liste links (2/5), Bearbeitung rechts (3/5) in einem eigenen Navigator; Speichern schließt den Detailbereich und aktualisiert die Liste. Auf compact und medium wie bisher eigene Seite. Medium quer (z. B. Telefon quer) bleibt einspaltig, weil zwei Spalten unter 840 dp das Formular zu schmal machen |
| FA-9.4 | Formulare und Lesebereiche (Beleg, Rechnung, Kunde, Stammdaten, Bestätigungen, Einstellungen, App-Sperre, Datensicherung, Export) höchstens 640 dp breit, zentriert (`spec.max_content_width_dp`, DESIGN_SPEC D-5). **Grundsatz (Auftraggeber 2026-10-20):** Was nicht über die ganze Breite geht, steht immer horizontal zentriert – nie linksbündig mit leerem Rand rechts; nur über `ReadableWidth`, nie mit eigener Breitenbegrenzung. Sperrbildschirm höchstens 360 dp, zentriert und scrollbar; Dialoge nach Material 3 höchstens 560 dp |
| FA-9.5 | Hoch- und Querformat ohne Sperre: Android ohne `screenOrientation`, iOS iPhone hoch und quer, iPad alle vier Ausrichtungen. **Kein `UIRequiresFullScreen`**: die App unterstützt Split View und Slide Over auf dem iPad; Apple verlangt dafür alle vier iPad-Ausrichtungen. Gerätetest: P-D19, P-D20 |
| FA-9.6 | **Kopf scrollt mit** (seit 0.37.0, Gerätetest 2026-10-20): In den Listen Belege (Umschalter Belege/Verträge, Suche, Filter, Anzahl und Saldo) und Rechnungen (Angebote/Artikel, Offen, Überfällig) ist der Kopf Teil der Liste und scrollt mit; quer bliebe sonst kaum Platz für Einträge |

### 5.7a Einhandbedienung

Maßstab: `docs/DESIGN_SPEC.md` Abschnitt 5a (Prüfregel 1–12, symmetrisch für
beide Hände, keine Händigkeits-Einstellung).

| ID | Anforderung |
|---|---|
| FA-12.1 | Übersicht und Belegliste: runder Aufnahmeknopf „Beleg“ (`CaptureButton`, Kreis 76 dp, Kamerasymbol, Beschriftung darunter, `centerFloat`) unten in der Mitte, öffnet das Belegformular mit Scanner bzw. Kamera; links daneben „Foto“ (Galerie), rechts „Datei“ (PDF, E-Rechnung, Bild über die Dateiauswahl des Systems, Channel `buchhaltung/document_picker`, `DocumentPickerChannel.kt` bzw. Klasse in `ReceiptTextChannel.swift`, weiter wie geteilte Dateien L-27.4), je runder Kreis 56 dp, spiegelgleich, 48 dp Abstand zum Hauptknopf (`CaptureBar`, seit 0.22.1); **auf der Übersicht weicht die Leiste beim Scrollen aus** (seit 0.31.0, `ScrollHidingBar`/`ScrollHideController`): gleitet nach unten weg und blendet aus, erscheint nach `spec.capture_bar_show_after_s` = 5 s ohne Scrollen wieder (200 ms), ganz oben sofort; liegt ein Finger auf der Leiste, bleibt sie stehen; ausgeblendet nimmt sie keine Tipps an und ist für Screenreader verborgen; mit TalkBack/VoiceOver bleibt sie immer sichtbar (P-X27); jeder öffnet ein neues Belegformular mit den Seiten und liest aus, wird nichts gewählt, schließt sich das leere Formular wieder; im Belegformular derselbe Knopf mittig über „Beleg speichern“ („Seite“/„Rückseite?“), Foto aus der Galerie als kleinere Nebenaktion; Einnahme/Ausgabe im Formular (Entscheidung Auftraggeberin 2026-10-16, DESIGN_SPEC 5a Regel 13). Leere Belegliste: „Beleg erfassen“ ohne Kamera |
| FA-12.2 | Zerstörende Aktionen nicht in der AppBar: Beleg stornieren und Kunde löschen als rot umrandeter Bereich am Formularende (`DangerZone`, ≥ 24 dp Abstand zur Speicherleiste); Bestätigung mit Verb-Knopf in Fehlerfarbe (`confirmDestructive`), ebenso „Automatische Sicherung ausschalten“ und „Wiederherstellen“ |
| FA-12.3 | Belegseiten: Pfeile 48 dp mit 8 dp Abstand; Löschen einer neuen Seite über Antippen → Bottom-Sheet „Seite löschen“ mit Bestätigung |
| FA-12.4 | Chip-Reihen (Übersicht Zeitraum, Belegliste Filter) umbrechen (`Wrap`); das Jahr der Belegliste ist der erste Chip (Auswahl im Bottom-Sheet) statt AppBar-Menü |
| FA-12.5 | Belegdatum mit Schnellchips „Heute“ / „Gestern“ |
| FA-12.6 | Kunden- und Stammdatenformular speichern über `PrimaryActionBar` |
| FA-12.7 | **Links und rechts gleich** (Entscheidung der Auftraggeberin 2026-10-14, 0.7.0): Belegliste (seit 0.22.0 Aufnahmeknopf, FA-12.1), Rechnungsliste „Neue Rechnung“ und Kundenliste „Neuer Kunde“ als zentrierter, verlängerter Knopf (`centerFloat`, 56 dp) statt Plus rechts unten. Rechnungskarte: Aktionsleiste über die volle Breite mit „Erinnern/Mahnen“, „Bezahlt“ und „PDF senden“ (dritter Knopf in eigener Zeile); Stornieren/Löschen bleiben im Menü. Einstellungsseiten dürfen rechtslastig bleiben |

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
| FA-11.6 | **Wunsch oder Idee senden** (Einstellungen, Lastenheft L-26.7, `features/settings/feedback_screen.dart`, Text in `services/help/feedback_mail.dart`): Art als Chips (Neue Funktion – vorgewählt –, Verbesserung, Fehler melden; ein Tipp), Titel optional, Beschreibung mehrzeilig, Pflicht, mit Mikrofon (FA-2.61); Schalter „App-Version und Gerät mitsenden“ (Standard an: App-Version, Betriebssystem und Gerätemodell über `deviceInfo` im Kanal `buchhaltung/launcher`, Länderprofil, Abo-Stufe; nie Geschäftsdaten, Belege, Kennungen); Knopf „Per E-Mail senden“ unten, volle Breite, 56 dp (`PrimaryActionBar`). Öffnet die Mail-App wie FA-11.3 an `supportAddress` mit Betreff „[JeNi bucht] ‹Art›: ‹Titel oder die ersten 6 Wörter›“ und vorausgefülltem Text; die App sendet nichts selbst, kein eigener Server. Danach schließt sich das Formular. Ohne Mail-App: Empfänger, Betreff und Text in die Zwischenablage, Hinweis als SnackBar. Prüfpunkt P-R45 |
| FA-11.8 | **Versionsanzeige** (seit 0.35.0, Rückmeldung Auftraggeber 2026-10-20): am Ende der Einstellungen „JeNi bucht · Version 0.35.0 (16)“ mit Buildnummer (Android `versionName (versionCode)`, iOS `CFBundleShortVersionString (CFBundleVersion)`); dieselbe Angabe in Support- und Wunsch-Mails. Jede Auslieferung mit Verhaltensänderung erhöht die Version (RELEASE_NOTES) |

### 5.9 Lizenz und Abo

Lastenheft 5.10 und 5.22. Bezahlung **nur** über die Stores (Google Play
Billing, StoreKit 2) mit dem Paket `in_app_purchase`; kein Server, kein
Nutzerkonto, kein Drittanbieter-SDK. Code in `lib/services/licensing/`
(reines Dart bis auf den Adapter), Oberfläche in `lib/features/licensing/`.

| ID | Anforderung |
|---|---|
| FA-13.1 | **Ein Anspruch** (L-22.1): `Entitlement` = `none` (nie ein Abo), `readOnly` (Abo beendet), `basis`, `pro`, `demo` (nur solange die Demo läuft, FA-13.14; liefert `AppState.entitlement`). Basis in der Testzeit des ersten Abos ergibt `pro` (FA-13.4). Einzige Entscheidung über Funktionen ist `Entitlement.allows(Feature)` in `license_policy.dart`; Bildschirme fragen nur `AppState.allows` bzw. `ensureFeature` (`features/licensing/feature_gate.dart`), nie den Store und nie den Tarif |
| FA-13.2 | **Tarifschnitt** (Lastenheft 5.10, O-4; Pro-Umfang entschieden 2026-10-15, O-34): `Feature.newBookings` (neuen Beleg speichern, neue Rechnung speichern, Rechnung ausstellen) ab Basis. **Ab Basis auch** `eInvoiceIssue` (E-Rechnung ausstellen, FA-5.49; Entscheidung Auftraggeber 2026-10-19, O-44, Regel Lastenheft 5.10 „gesetzliche Pflicht nie nur in Pro“): ZUGFeRD-PDF und XML zustellen in Basis über das Teilen-Blatt (Speichern, Drucken, Teilen; „XML senden“ teilt die Datei), Senden mit einem Tipp bleibt `pdfSending` (Pro); ohne Abo, im Nur-Lese-Modus und in der Demo gesperrt. **Nur Pro:** `helperDevices` (Mithelfer-Geräte koppeln, FA-17.1; der Eingang nimmt in jedem Anspruch an; Mithelfer ohne eigenes Abo), `receiptRecognition` (Belegerkennung FA-2.19 ff.), `dataImport` (Plattformimport Amazon/PayPal/Shopify/Stripe FA-5.x L-28 und Auslesen von E-Rechnungen ZUGFeRD/XRechnung/ebInterface in den Beleg; die Datei selbst wird in jedem Abo angehängt), `pdfSending` (Rechnung und Stornorechnung mit einem Tipp senden, FA-13.11), `dunningSending` (Zahlungserinnerung/Mahnung senden; erstellen und protokollieren ab Basis), `invoiceLogo` (Logo **drucken** auf neuen Rechnungen und Angeboten; wählen, ändern, entfernen immer, FA-13.12), `exchangeRateFetch` („Kurs abrufen“ bei der EZB; Kurs eintippen immer), `contractSummary` (Texterkennung und Kurzübersicht im Vertragsarchiv, FA-16.3; Vertragsarchiv selbst ab Basis; entschieden 2026-10-16, Lastenheft 14a), `annualReports` (Saldenliste und vorläufiger Jahresabschluss, FA-15.9, FA-15.10; entschieden 2026-10-16), `levyReserve` (Karte und Bildschirm „Abgaben & Rücklagen“, FA-19.1 ff.; Entscheidung Auftraggeber 2026-10-19, O-43; ohne Pro Hinweiskarte „Abgaben & Rücklagen (Pro)“ zur Abo-Seite; Buchungen in Abgabenkategorien bleiben in jedem Anspruch normale Buchungen), `assetManagement` (Anlage anlegen, ändern, ausscheiden, FA-15.1 bis FA-15.7; Entscheidung Auftraggeberin 2026-10-16 trotz Regel Lastenheft 5.10 „gesetzliche Pflicht nie nur in Pro“, P-S64, P-R43). **Erfasste Anlagen bleiben in jedem Anspruch ansehbar, das Anlagenverzeichnis exportierbar und ihre jährliche AfA läuft nach einer Herabstufung weiter** (Gewinn bleibt richtig). Ohne Pro zählt eine Ausgabe voll als Betriebsausgabe; ist sie über der GWG-Grenze (`Depreciation.exceedsGwg`, Grenze und brutto/netto aus `TaxProfile`), zeigt der Beleg statt „Als Investition erfassen“ die Zeile „Als Investition erfassen (Pro)“ mit dem Hinweis, dass die Anschaffung aktiviert und ins Anlagenverzeichnis gehört; darunter erscheint ohne Pro nichts, `taxOfficeSubmission` (U30-Datei für FinanzOnline teilen, FA-14.4; Kennzahlen ansehen und kopieren bleibt frei). **Immer frei, auch ohne Abo:** ansehen, Belege und Entwürfe ändern, PDF speichern oder drucken über den Systemdialog, Export, Sicherung, Wiederherstellung (`Feature.dataExport`, nur in der Demo gesperrt), Rechtliches, Hilfe (L-10.4, L-7.15, L-22.6). **Demo** (FA-13.14): `receiptRecognition`, `exchangeRateFetch`, `annualReports` und `levyReserve` frei zum Ausprobieren, alles andere gesperrt, dazu jedes Speichern und Ändern (`ensureWritable`). Knöpfe gesperrter Funktionen tragen „(Pro)“ und führen zur Abo-Seite (`proLabel`, `ensureFeature`) |
| FA-13.3 | **Produkte** (L-22.2): eine Abogruppe mit `basis_monat`, `basis_jahr`, `pro_monat`, `pro_jahr` (Kenndaten `spec.license_product_ids`). Wechsel innerhalb der Gruppe ersetzt das Abo: Android über `ChangeSubscriptionParam` (anteilige Zeitgutschrift), iOS über die Abogruppe (Upgrade sofort, Downgrade zum Periodenende) |
| FA-13.4 | **Test** (L-10.3, L-22.3; **Entscheidung Auftraggeber 2026-10-19, O-42**, ersetzt O-35 „Store-Test nur auf Pro“): **alle vier Produkte** haben ein Einführungsangebot der Stores mit 14 Tagen kostenlos (Kenndaten `spec.license_trial_days`); die Kundin wählt und startet ein Abo (Basis oder Pro, monatlich oder jährlich) im Store, kündigt sie in den 14 Tagen, zahlt sie nichts; sonst geht der Test in das gewählte Abo über. Der Store entscheidet über die Berechtigung (Android: Angebot mit kostenloser erster Preisphase wird bevorzugt gekauft). **Pro inklusive in der Testzeit:** Wer Basis wählt, bekommt in den ersten 14 Tagen des **ersten** Abos alle Pro-Funktionen (`LicensePolicy.proIncludedUntil`, eine Stelle; `entitlement` liefert dann `pro`), danach Basis, Daten bleiben. Pro bleibt Pro. **Bestimmung:** Beginn = frühester je gemeldeter Kaufzeitpunkt (`LicenseRecord.trialStartedAt`, Schlüsselbund/Keystore; beim Kauf „jetzt“, bei jeder Store-Abfrage `StoreBilling.trialInfo()`: Android `purchaseTime`, iOS `originalPurchaseDate`). **iOS** zusätzlich `introOffer` aus der StoreKit-2-Transaktion (`jsonRepresentation`, `offerType` 1 = Einführungsangebot, `StoreTrialInfo.fromAppleTransactionJson`); meldet StoreKit eine bezahlte Transaktion, endet Pro inklusive sofort. **Android** liefert dem Gerät kein Testkennzeichen: Pro inklusive gilt, solange jetzt < Kaufzeitpunkt + 14 Tage – eine **Näherung** (Neuinstallation mit leerem Keystore nimmt den Kaufzeitpunkt des aktiven Abos; wer früher schon getestet hat, bekommt das Fenster trotzdem, P-D46). **3 Tage vor Ende** (`spec.license_trial_reminder_days`): bei Pro „Dein kostenloser Test endet am …“, bei Basis „Noch X Tage Pro inklusive – danach Basis. Jetzt auf Pro wechseln?“ (Tippen → Abo-Seite, ein Tipp zum Kauf). **Apple:** ein Einführungsangebot je Abogruppe und Apple-ID – wer Basis getestet hat, bekommt für Pro keinen zweiten Test; ein Wechsel auf Pro in der Testzeit wird sofort kostenpflichtig (Store-Blatt zeigt den Preis; P-D47). Das **Widerrufsrecht** für digitale Inhalte (§ 356 Abs 5 BGB, § 18 Abs 1 Z 11 FAGG) regelt der Store unabhängig vom Test (Befund Prüfinstanz Rechtsanwalt; Bestätigung P-L10) |
| FA-13.5 | **Abo-Seite** (`features/licensing/subscription_screen.dart`, L-22.7, L-22.8; Einstellungen → Abo, Übersicht-Hinweis, gesperrte Funktion): Stand, Umschalter Monatlich/Jährlich (56 dp), Karten Pro und Basis mit **Preis aus dem Store** inkl. USt je Zeitraum (nie im Code), ohne früheres Abo auf **beiden** Karten „14 Tage kostenlos testen – mit allen Pro-Funktionen. Danach gilt dein gewähltes Abo (‹Preis› pro ‹Zeitraum›). Jederzeit vorher im Store kündbar.“ (Wortlaut Auftraggeber 2026-10-19, O-42), bei Basis ergänzt um „Nach dem Test gilt der Umfang von Basis.“ (Befund Rechtsanwalt, P-R57); Knopf „‹Stufe› – 14 Tage kostenlos“ bzw. „‹Stufe› wählen“, 56 dp volle Breite. Stand bei Basis in der Testzeit: „Basis ist aktiv – in der Testzeit mit allen Pro-Funktionen bis ‹Datum›“; in der Demo „Du siehst gerade die Demo …“. Darunter Pflichttext: automatische Verlängerung um denselben Zeitraum, Kündigung spätestens 24 Stunden vor Ablauf in den Store-Einstellungen, Übergang des Tests, Widerruf und Erstattung über den Store, Daten bleiben immer lesbar. Zeilen „Kauf wiederherstellen“, „Abo verwalten oder kündigen“ (Sprung `https://play.google.com/store/account/subscriptions` bzw. `https://apps.apple.com/account/subscriptions`, ohne Browser Anleitung als Meldung), Nutzungsbedingungen, Datenschutzerklärung (offline, FA-11.5) |
| FA-13.6 | **Store-Abfrage** (L-22.5): beim Start im Hintergrund und bei „Kauf wiederherstellen“. Gilt als verlässlich nur, wenn der Store verfügbar ist **und** die Produktliste geladen wurde; dann `restorePurchases` und Sammeln der gemeldeten Käufe (bis 6 s plus 1 s). Unverlässlich (offline, Fehler) → Stand bleibt, Meldung „Store nicht erreichbar. Dein Abo gilt weiter.“ Offene Käufe werden abgeschlossen (`completePurchase`) |
| FA-13.7 | **Offline und Kulanz** (L-10.5, L-22.5): der zuletzt bestätigte Stand (Stufe, Zeitpunkt, je ein Abo, Testbeginn) liegt im Schlüsselbund bzw. Keystore (`flutter_secure_storage`, nur dieses Gerät, nie in der Sicherung) und gilt **45 Tage** ab der letzten Bestätigung (`spec.license_offline_grace_days`: längster Monat 31 + 14 Tage Kulanz). Ab Tag 31 (`spec.license_offline_warn_days`) bittet die Übersicht, die App einmal mit Internet zu öffnen |
| FA-13.8 | **Herabstufen statt sperren** (L-22.6): Pro endet → Basis, wenn Basis aktiv; sonst Nur lesen. Die Übersicht zeigt nach einer Herabstufung einmal „Dein Abo ‹Stufe› ist beendet …“ (bis zum Tippen); höchstens ein Abo-Hinweis zur Zeit (`features/licensing/license_notice.dart`), Reihenfolge Herabstufung, Testende (bei Basis mit Pro inklusive „Noch X Tage Pro inklusive – danach Basis. Jetzt auf Pro wechseln?“), Bestätigung fehlt, Nur lesen, kein Abo („14 Tage kostenlos testen – mit allen Pro-Funktionen.“); in der Demo keiner (dort das Demo-Band) |
| FA-13.9 | **Gesperrte Funktion:** `ensureFeature` öffnet die Abo-Seite mit Begründung und prüft danach erneut; das Formular bleibt mit allen Eingaben offen. Beim Beleg ersetzt bei fehlendem Pro der Knopf „Automatisch auslesen (Pro)“ das stille Auslesen |
| FA-13.10 | **Testbuild-Schalter:** Lizenzprüfung nur mit `--dart-define=LICENSING=true` (`LicensePolicy.enabled`); ohne ihn voller Umfang, kein Store-Zugriff, Abo-Seite zeigt „Testversion“. `release.yml` setzt den Schalter nur mit der Eingabe `abo` (seit 2026-10-20); TestFlight- und interne Play-Builds laufen ohne Abo mit allen Pro-Funktionen, damit Tester Pro prüfen können (P-D30) |
| FA-13.14 | **Demo ohne Abo** (Entscheidung Auftraggeber 2026-10-19, O-42; `lib/services/demo/`, `lib/features/demo/`): eigene **Muster-Datenbank im Arbeitsspeicher** (`DemoSession.open`), bei jedem Start neu aus `DemoDataset` befüllt und danach per `PRAGMA query_only` schreibgeschützt; `AppDatabase.database` und `AppState.repositories` zeigen solange auf sie, die echte Datei bleibt unberührt und wird beim Verlassen wieder angezeigt. **Land wählen** (seit 0.31.0): „Erst ansehen (Demo)“ und Einstellungen → „Demo ansehen“ öffnen zuerst das Blatt „Deutschland“ (zuerst, hervorgehoben) / „Österreich“ (`chooseDemoCountry`, `DemoDataset.seed(country:)`). **Deutschland** (`DemoDatasetDe`, Kenndaten `spec.demo_de_company`, `spec.demo_de_receipt_count`): erfundenes Einzelunternehmen „Muster Handel“ (Musterstadt, Bayern), **Kleinunternehmerin nach § 19 UStG** mit rund 14.500 € Umsatz – Ampel misst an 25.000 € und zeigt gut die Hälfte (FA-4.14) –, EÜR, zwei Kunden, 17 Belege mit 19 % und 7 % (Fachbuch), Barverkäufe, Krankenversicherung und ESt-Vorauszahlung, Hebesatz 400 % für die Gewerbesteuer in „Abgaben & Rücklagen“, Rechnungen bezahlt/offen/überfällig mit Zahlungserinnerung, Storno, Angebot, Mietvertrag; deutsche Fristen aus dem `TaxProfile`. **Österreich** (Kenndaten `spec.demo_company`, `spec.demo_receipt_count`): erfundene Firma „Muster Handel e.U.“ (Wien, **Kleinunternehmerin** nach § 6 Abs 1 Z 27 UStG 1994 mit Grenzwertampel bei rund 27 % – Jahresumsatz ≈ 15.000 € –, Registrierung DE für das Lager; eigene Rechnungen ohne Umsatzsteuer mit Kleinunternehmerhinweis, Belege mit der USt der Lieferanten; Rückmeldung 2026-10-19), drei Kunden, drei Artikel, 25 Belege (Tankstelle, Baumarkt, Bewirtung mit 10 % und 20 % auf einem Beleg, Büro, Werbung, Telefon, Versicherung, Wareneinkauf, Bank, Fachbuch, Barverkäufe, Lagerleistung DE 19 %, Hotel in CHF, Laptop als Anlage mit AfA), Rechnungen bezahlt/offen/überfällig mit Zahlungserinnerung, Storno mit Stornorechnung, zwei Angebote, Mietvertrag Lager mit Frist, Leasing Lieferwagen, Dienstvertrag einer erfundenen Teilzeitkraft, Versicherungsvertrag; Termin-Box, Kennzahlen, Saldenliste und vorläufiger Jahresabschluss ergeben sich daraus. Belegbilder **synthetisch im Code gezeichnet** (`DemoReceiptImage`, PNG in `demo_belege/`, nie in einer Sicherung, beim Verlassen gelöscht), keine Fotos aus `test/fixtures`, keine echten Marken (P-R56). UID, Steuernummer, IBAN sind Nullen-Platzhalter. **Alles ansehen, nichts speichern:** jedes Speichern/Ändern (`ensureWritable`) und jede gesperrte Funktion (`ensureFeature`) öffnet das Blatt „In der Demo wird nichts gespeichert. Mit einem Abo wäre das jetzt gebucht.“ mit „Abo wählen“ (56 dp) und „Weiter ansehen“; ein Schreibversuch, der doch die Datenbank erreicht, endet über `PlatformDispatcher.onError` ebenfalls dort. Scanner mit Erkennung geht, Speichern verwirft. Rechnung zusammenstellen geht; **jedes PDF** (Rechnung, Angebot, Storno, Mahnung, Saldenliste, Jahresabschluss) trägt auf jeder Seite schräg „MUSTER – DEMO“ (`PdfWatermark`, `spec.demo_watermark`, Titel und Stichwort in den Metadaten); Teilen, Senden, Export und Sicherung sind gesperrt (`ShareService` erzeugt keine Datei, `Feature.dataExport`, Sicherung zeigt „In der Demo wird nichts gesichert …“). Mithelfer-Geräte, Mailweg, UID-Prüfung und automatische Sicherung laufen in der Demo nicht. Band oben „DEMO – Abo wählen, um mit deinen eigenen Daten zu starten“ (≥ 48 dp, Tippen → Abo-Seite). Abo abgeschlossen → Demo endet, Einrichtung beginnt leer. Danach (und im Testbuild) Einstellungen → „Demo ansehen“; Band dann „DEMO – Musterdaten. Tippen zum Beenden“. **Listen im Stapel der Startseite** (Belege, Rechnungen, Kunden) laden bei jedem Wechsel in die Demo und zurück neu (`AppState.bookingsRevision`); bis 0.27.0 zeigten sie nach „Einstellungen → Demo ansehen“ weiter die echten (leeren) Daten |
| FA-13.15 | **Abo in der Ersteinrichtung** (ersetzt die Startauswahl von 0.27.0): „Erst ansehen (Demo)“ steht auf der Willkommensseite (FA-1.13), im Store-Build mit Band „DEMO – Abo wählen …“, im Testbuild mit „Demo beenden“. Schritt 5 „Abo wählen“ (nur Store-Build `LICENSING=true` ohne Abo): Testtext aus FA-13.5, Hauptknopf „Abo wählen – 14 Tage kostenlos“ (56 dp, öffnet die Abo-Seite; nach dem Kauf ist die Einrichtung fertig), „Später entscheiden“ (48 dp) beendet die Einrichtung ohne Abo (Funktionen dann wie FA-13.1) |
| FA-13.16 | **Preise aus Store-Phasen** (Entscheidung Auftraggeber 2026-10-19, Lastenheft 5.10 und 14a): erstes Jahr Einführungspreis, ab dem zweiten Jahr Grundpreis, davor 14 Tage gratis, wo der Store es zulässt. Die Abo-Seite baut Kopfzeile und Satz **nur aus den Preisphasen des Stores** (`StoreOffer.phases`, `OfferText.priceLine`/`summary`, `lib/services/licensing/offer_text.dart`): Android `SubscriptionOfferDetails.pricingPhases` (Preis, ISO-Dauer, Zyklen, Wiederholung), iOS StoreKit `introductoryPrice` (Kostenlos / Pay as you go / Pay up front) und Grundpreis. Beispiel: „14 Tage gratis, dann 6,90 €/Monat im ersten Jahr, danach 12,90 €/Monat. Verlängert sich automatisch, jederzeit im Store kündbar.“ Kopfzeile „6,90 €/Monat im ersten Jahr, danach 12,90 €/Monat“; 12 Monate bzw. 1 Jahr heißen „im ersten Jahr“, sonst „für N Monate“. Ohne Phasen bleibt der Text von FA-13.4 mit dem Grundpreis. Android wählt je Produkt: freigeschaltetes Rabattangebot vor Angebot mit Gratisphase vor mehr Phasen vor Basis-Tarif. **Zweiter Instagram-Code** `spec.license_promo_code_discount` = `spec.license_promo_discount_percent` % auf das Jahresabo im ersten Jahr: iOS Apple-Angebotscode; Android ist das nur als vom Entwickler bestimmtes Angebot mit Tag `jenibucht20` möglich (Google-Promo-Codes geben nur Gratisphasen), das die App nach Eingabe des Codes im Promo-Feld anzeigt (`DiscountPromo`, ohne Server, Code nicht geheim; O-46, P-R63). **Pro-Code** `spec.license_promo_code_discount_pro` auf `pro_jahr` (Apple: ein benutzerdefinierter Code je Angebot), auf Android schaltet er dasselbe Tag frei; Instagram bewirbt ihn, beide laufen parallel zu `JENIBUCHT2M` (Entscheidung 2026-10-19, O-46). **iOS** (Entscheidung 2026-10-19, O-45, Variante A plus Codes): Einführungsangebot 14 Tage „Kostenlos“ auf allen vier Produkten, danach Grundpreis; Text „14 Tage gratis, danach 12,90 €/Monat“. Einführungspreis erstes Jahr auf iOS nur per Angebotscode `JENIBUCHTSTART` (je Produkt ein Code, `STORE_ANMELDUNG.md` Formular 4), eingelöst über Apples Einlöseblatt, ohne App-Logik. Android behält das mehrphasige Angebot (14 Tage gratis → Einführungspreis → Grundpreis) Rechtliche Darstellung P-R62; Store-Einrichtung `STORE_ANMELDUNG.md` Formular 4 |
| FA-13.13 | **Promo-Code** (Entscheidung Auftraggeberin 2026-10-16): Code `spec.license_promo_code` für 2 Monate Pro gratis (`spec.license_promo_free_months`) für neue Abonnentinnen, beworben auf Instagram. Nur Store-Mechanik, kein eigener Server: Apple **Angebotscode** (benutzerdefinierter Code auf `pro_monat`/`pro_jahr`, „Kostenlos“, 2 Monate, Neukunden) und Google Play **Promo-Code** auf einem Angebot des Pro-Abos (kostenlose Phase 2 Monate). Wie der Test: danach kostenpflichtig, vorher kostenlos kündbar oder Wechsel auf Basis im Store. Abo-Seite: Zeile „Promo-Code einlösen“ (≥ 48 dp). iOS öffnet direkt Apples Einlöseblatt (`presentCodeRedemptionSheet`, Paket `in_app_purchase_storekit`), Android ein Bottom-Sheet mit leerem Codefeld und „Einlösen“ (56 dp), dann `https://play.google.com/redeem?code=<Code>` (`StoreBilling.redeemCode`). Ergebnis über das Kaufereignis bzw. die Abfrage bei Rückkehr in die App (`didChangeAppLifecycleState` → `refresh`). Pro aus einem Code setzt `trialIsPromo`; die Erinnerung „Dein kostenloser Test endet am …“ kommt 3 Tage vor Ende der 2 Monate statt der 14 Tage. Direktlinks für Instagram: `LicensePolicy.playRedeemUri`, `appStoreRedeemUri` (Apple-ID der App fehlt noch, P-D32). Werbetext und Pflichtangaben: `STORE_LISTING.md`, P-R40. Steuerlich ohne Folge: Gratiszeit ohne Entgelt, Umsatz erst mit der ersten Store-Abrechnung (Prüfinstanz Steuerberater) |
| FA-13.12 | **Logo ohne Pro** (Entscheidung Auftraggeber 2026-10-16): Logo wählen geht im Onboarding und in den Stammdaten ohne Abo-Seite. `InvoiceLogo.forNewDocument` friert beim Speichern eines Entwurfs das Profil ohne `logo_path` ein, wenn `allows(Feature.invoiceLogo)` falsch ist (Basis, nur lesen, kein Abo); `InvoiceLogo.pathFor(…, logoAllowed:)` druckt Entwürfe nur mit Pro oder in der Testzeit (auch Basis mit Pro inklusive). Gestellte Rechnungen behalten das eingefrorene Logo (GR-8). Das Profil behält `logo_path` und die Datei; nach dem Wechsel auf Pro erscheint das Logo wieder auf neuen Belegen. Ohne Pro zeigen die Stammdaten „Logo (Pro) – wird mit Basis nicht gedruckt“ |
| FA-13.11 | **PDF senden ohne Pro** (`sendPdfGated` in `feature_gate.dart`): Rechnung, Stornorechnung, Zahlungserinnerung und Mahnung werden in jedem Abo erzeugt (Mahnung samt Protokoll und SHA-256). Mit Pro öffnet „PDF senden“ das Teilen-Blatt mit Betreff und Mailtext. Ohne Pro zuerst die Abo-Seite mit Begründung; danach – ohne Kauf – das Systemblatt ohne Betreff und Text zum Speichern oder Drucken. **Stornorechnung:** Sie muss der Empfängerin zugehen (§ 14c UStG, § 11 Abs 12 UStG AT bzw. Rechnungsberichtigung § 31 Abs 5 UStDV); Speichern/Drucken und eigenes Weitergeben genügt dafür, die Pflicht ist also in Basis erfüllbar (Lastenheft 5.10, letzter Absatz). Technisch ist das Systemblatt dasselbe wie beim Senden; der Tarifschnitt ist Komfort (ein Tipp, Betreff, Text), keine harte Sperre. **Seit 0.30.0** hat der PDF-Betrachter (FA-5.48) einen eigenen Knopf **Drucken** mit dem Systemdruckdialog (Paket `printing`), frei in jedem Anspruch; damit ist Drucken auch in Basis ein Tipp und nicht mehr nur der Umweg über das Teilen-Blatt |

### 5.10 Meldungen ans Finanzamt

Lastenheft L-6.1, L-6.3, L-6.5. Code: `lib/services/tax_office/`
(`vat_return_figures.dart`, `u30_xml.dart`), Bildschirm
`features/tax_office/tax_office_screen.dart`. Kennzahlen ausschließlich in
`TaxProfile.vatReturnForm` und `TaxProfile.annualReturnForm` (GR-6), Kenndaten
`spec.*.vat_return_kz`, `spec.*.annual_return_kz`, `spec.u30_schema_version`.

**Umfang entschieden mit den Prüfinstanzen (2026-10-16):** AT Datei-Upload
(Variante a) ist gebaut; die direkte Übermittlung über die FinanzOnline-
Webservices (Variante b) und ELSTER/ERiC sind **nicht** gebaut (Begründung in
Abschnitt 11).

| ID | Anforderung |
|---|---|
| FA-14.1 | **Für das Finanzamt** (Export → oberste Karte): Zeitraum Jahr plus Quartal oder Monat, vorbelegt mit dem zuletzt abgeschlossenen Quartal. Zahlen aus `ReceiptRepository.totals` wie Übersicht und Export (FA-3.2, FA-3.3) |
| FA-14.2 | **Kennzahlen der Voranmeldung** (`VatReturnCalculator.build`): AT U30 – Kz 000 Summe der Bemessungsgrundlagen, Kz 022/006/029/124 je Satz 20/13/10/4,9 %, Kz 016 steuerfrei als Kleinunternehmer, Kz 057/066 Reverse Charge, Kz 060 Vorsteuer, Kz 095 Zahllast/Überschuss (nur Anzeige, rechnet FinanzOnline). DE UStVA – Kz 81/86 für 19/7 % in **vollen Euro** (Cent abgeschnitten, `wholeEuros`), Kz 46/47/67 Reverse Charge, Kz 66 Vorsteuer, Kz 83 verbleibende Vorauszahlung. Steuer je Satz rechnet das Portal aus der Bemessungsgrundlage; Cent-Abweichungen zur Summe der je Position gerundeten Steuer (GR-5) sind möglich und werden erklärt |
| FA-14.3 | **Kopieren mit einem Tipp:** jede Zeile ist eine Tippfläche ≥ 56 dp; der Tipp legt den Betrag ohne Tausenderpunkt mit Dezimalkomma (`KennzahlLine.copyText`, z. B. `1234,56` bzw. `1234`) in die Zwischenablage und meldet „Kz 022: … kopiert“ |
| FA-14.4 | **U30-Datei (nur AT, Pro, `Feature.taxOfficeSubmission`):** Knopf unten „U30-Datei teilen“ (56 dp, `PrimaryActionBar`) erzeugt XML nach BMF-Datenstrom U30 (Stand 07_2026, Abschnitt 8.7) und öffnet das Teilen-Blatt; darüber vier nummerierte Schritte für den Upload in FinanzOnline und „FinanzOnline öffnen“. Gesperrt (mit Begründung als Hinweis) bei: Steuernummer ergibt keine 9-stellige FASTNR (Finanzamtsnummer + Steuernummer), Umsätze zu einem Satz ohne eindeutige Kennzahl (z. B. 0 % beim Regelbesteuerten: steuerfrei, Ausfuhr, EU-Lieferung), negative Bemessungsgrundlage oder Vorsteuer (Typ `kz` erlaubt nur ≥ 0,01). Nullbeträge entfallen in der Datei, Kz 000 steht immer |
| FA-14.5 | **Kleinunternehmer** (AT § 6 Abs 1 Z 27 UStG, DE § 19 UStG): ohne Reverse Charge keine Voranmeldung – Hinweis „brauchst du keine …“, keine Kennzahlen, kein Knopf; es bleiben die Jahreszahlen (FA-14.6). Mit Reverse Charge Voranmeldung mit Kz 000/016/057 (AT) bzw. 46/47 (DE), Vorsteuer 0 (FA-3.4) |
| FA-14.6 | **Jahreszahlen** (`VatReturnCalculator.annual`, Wirtschaftsjahr wie L-24.5): AT E1a Kz 9040 Betriebseinnahmen netto; DE Anlage EÜR Kz 112 (bzw. Kz 111 als Kleinunternehmer), Kz 140 vereinnahmte USt, Kz 185 gezahlte Vorsteuer; dazu Betriebsausgaben gesamt (ohne Kennzahl, nach Art auf die Zeilen aufzuteilen) und Ergebnis. Jede Zeile kopierbar |
| FA-14.7 | **DE ohne Datei:** ELSTER nimmt Voranmeldungen nur über ERiC an; bis dahin Schritte für „Mein ELSTER“ und Link `https://www.elster.de/eportal/start` |
| FA-14.8 | **Keine Übermittlung durch die App:** Die App sendet nichts ans Amt; die Datei geht nur über das Teilen-Blatt dorthin, wo die Nutzerin sie ablegt (10.1). Hinweis „Die Meldung gibst du selbst ab“ (P-R5) |

### 5.11 Anlagen, AfA und Jahresabschluss

Code: `lib/domain/fixed_asset.dart`, `lib/services/assets/depreciation.dart`,
`lib/services/reports/`, `lib/data/asset_repository.dart`; Bildschirme
`features/assets/asset_screens.dart`, `features/reports/reports_screen.dart`.
Kenndaten `spec.*.depreciation`.

| ID | Anforderung |
|---|---|
| FA-15.1 | **Investition erfassen:** in einer gespeicherten Ausgabe die Zeile „Als Investition erfassen“ (≥ 48 dp) öffnet „Investition erfassen“ vorbelegt mit Beschreibung, Datum und Anschaffungskosten (netto, Kleinunternehmer brutto); ist der Beleg schon Anlage, „Anlage öffnen“. Ohne Beleg über Anlagen → „Anlage ohne Beleg erfassen“. Felder: Bezeichnung, Anschaffungs-/Inbetriebnahmedatum, Anschaffungskosten, Art, Abschreibungsart, Nutzungsdauer, Kommentar. Anlegen, Speichern und Ausscheiden nur Pro (`assetManagement`, FA-13.2); ansehen immer |
| FA-15.2 | **Vorschläge statt Pflicht:** Art wählt die Nutzungsdauer aus `TaxProfile.depreciation.classes` (AT: Computer 3, Software 3, Büromöbel 10, PKW 8 – mindestens 8 nach § 8 Abs 6 EStG –, Maschinen/Werkzeuge 5; DE: Computer und Software 1 nach BMF 22.02.2022, Büromöbel 13 nach AfA-Tabelle AV, PKW 6, Maschinen/Werkzeuge 5; Sonstiges 5), Fundstelle als Hilfetext. Abschreibungsart vorbelegt: GWG, wenn die Kosten bis zur Grenze reichen (AT 1.000 € Anschaffungskosten § 13 EStG, DE 800 € netto § 6 Abs 2 EStG), sonst linear |
| FA-15.3 | **Eigene Nutzungsdauer:** weicht sie vom Vorschlag ab, ist eine Begründung Pflicht; sie steht im Anlagenverzeichnis. Prüfung: PKW-Mindestdauer AT, 1–50 Jahre, GWG nur bis zur Grenze, Sammelposten nur DE von 250,01 bis 1.000 € netto (§ 6 Abs 2a EStG) |
| FA-15.4 | **AfA-Plan** (GR-15) als Vorschau im Formular: je Jahr AfA und Restbuchwert. AT Halbjahresregel (§ 7 Abs 2 EStG), DE monatsgenau (§ 7 Abs 1 Satz 4 EStG); DE Nutzungsdauer 1 Jahr voll im Anschaffungsjahr; Sammelposten fünf gleiche Teile ab dem Jahr der Bildung, Ausscheiden ändert ihn nicht |
| FA-15.5 | **Gewinn:** `ReceiptRepository.totals(depreciation:)` zieht Anschaffungsbelege von Anlagen aus dem Ergebnis ab und zählt die AfA mit Buchungstag im Zeitraum; Übersicht zeigt „davon Investitionen (nicht Ergebnis)“ und „Abschreibung (AfA)“, wenn vorhanden. Vorsteuer und UVA bleiben unverändert |
| FA-15.6 | **Ausscheiden / vollständig abschreiben** (Bottom-Sheet „Ausscheiden“): Art (verschrottet, verloren, verkauft, außerplanmäßig), Datum ab Anschaffung, **Kommentar Pflicht**, beim Verkauf Erlös brutto. Restbuchwert geht am Tag des Ausscheidens ab (DE vorher AfA bis zum Monat des Abgangs, AT keine AfA im Abgangsjahr – P-S60). Verkaufserlös wird als Einnahme gebucht (Steuer zum Normalsatz, Kleinunternehmer 0 %). Danach ist die Anlage schreibgeschützt |
| FA-15.7 | **Kommentare überall:** Anlage (Kommentar), Nutzungsdauer (Begründung), Ausscheiden (Pflichtkommentar) und je Bericht ein Kommentar an die Steuerberatung; alle stehen im PDF |
| FA-15.8 | **Anlagenverzeichnis (PDF, jedes Abo):** je Jahr alle vorhandenen Güter mit Bezeichnung, Art, Datum, Anschaffungskosten, Nutzungsdauer bzw. GWG/Sammelposten, Buchwert 1.1., AfA, Abgang, Buchwert 31.12., Kommentare und Abgänge (AT § 7 Abs 3 EStG, DE § 4 Abs 3 Satz 5 EStG). In jedem Anspruch, auch für Anlagen aus früherem Pro (FA-13.2) |
| FA-15.9 | **Saldenliste (PDF, Pro `annualReports`):** Summen je Kategorie und Richtung mit Konto und Belegzahl (ohne Anschaffungsbelege), AfA, Anlagen Buchwert Anfang/Zugänge/Ende, bei Regelbesteuerung Umsatzsteuer, Vorsteuer, Zahllast |
| FA-15.10 | **Vorläufiger Jahresabschluss (Pro):** PDF mit Einnahmen-Ausgaben-Rechnung (Gliederung E1a bzw. Anlage EÜR), Anlagenverzeichnis, Saldenliste, offenen Posten (nur Information, Zuflussprinzip) und Kommentar; jede Seite trägt „VORLÄUFIG – zur Prüfung und Fertigstellung durch die Steuerberatung“. Geteilt als ZIP mit Belegliste, DATEV- bzw. BMD-Export und Umsatzsteuer-Zusammenfassung |
| FA-15.12 | **Paket „Für Kapitalgesellschaft / doppelte Buchführung“** (Pro `annualReports`, Entscheidung Auftraggeber 2026-10-19, Lastenheft 14a): ZIP `Buchhaltungspaket_<von>_<bis>.zip` mit Saldenliste (PDF), Belegliste (8.2), DATEV-Buchungsstapel (8.3) und BMD-Buchungssätzen (8.4) unabhängig vom Land sowie allen Belegbildern als `Belege/<Beleg-ID>_<Datum>_<Seite>.<Endung>`; die Beleg-ID steht in DATEV „Belegfeld 1“ und BMD „Belegnummer“. Für GmbH-Nutzerinnen, deren Kanzlei doppelt bucht. Import-Prüfung P-D50 bis P-D53, P-S84 |
| FA-15.11 | **Berichte-Bildschirm** (Export → „Anlagen und Jahresabschluss“): Zeile Anlagen, Jahr (vorbelegt: letztes abgeschlossenes Wirtschaftsjahr), Kommentarfeld, drei Berichtszeilen ≥ 48 dp |

### 5.12 Vertragsarchiv

Lastenheft 5.23 (L-23.1 bis L-23.4, L-23.6 lokal, L-23.11). Code:
`lib/domain/contract.dart`, `lib/data/contract_repository.dart`,
`lib/services/contracts/`, Bildschirm `features/contracts/contract_screens.dart`.
**Alles bleibt auf dem Gerät.** Die KI-Zusammenfassung (L-23.5, L-23.7 bis
L-23.10, Stufe C mit Anbieter-Backend) ist nicht gebaut und hat keinen Knopf.

| ID | Anforderung |
|---|---|
| FA-16.1 | **Vertrag ablegen** (Export → „Verträge“): Art (Miete, Pacht, Leasing, Dienstbarkeit, Versicherung, Darlehen, Dienst-, Werk-, Kaufvertrag, Sonstiger), Bezeichnung, Vertragspartner, Beginn, Ende (leer = unbefristet), Kündigungsfrist (Zahl + Tage/Wochen/Monate), Rate brutto, Rhythmus, Steuersatz (Vorschlag Normalsatz), Wertsicherung als Text, nächste Indexanpassung, Kommentar. Speichern ab Basis |
| FA-16.2 | **Seiten wie bei Belegen:** fotografieren, mehrere aus der Galerie, über „Teilen“ (Bild oder PDF: das Belegformular zeigt oben „Ist das ein Vertrag? …“ – ein Tipp öffnet stattdessen „Vertrag ablegen“, ohne Rückfrage beim Teilen). PDF: Original und Seitenbilder im Belegspeicher, in der Sicherung enthalten. Seiten werden nur angehängt |
| FA-16.3 | **Kurzübersicht (Pro `contractSummary`):** Texterkennung auf dem Gerät (wie FA-2.19) speichert den Text lokal; `ContractTextExtractor` findet Daten (Beginn/Ende nach Stichworten), Laufzeit, Kündigungsfrist, Beträge bei Miete/Rate/Prämie/Pacht/Zins, Wertsicherung (VPI, Index) – je mit **Fundstelle Seite und Zeile** und Originalzeile. Tippen übernimmt den Wert ins Formular. Nur Auszug, keine rechtliche Bewertung, keine Empfehlung (L-23.6, P-R41) |
| FA-16.4 | **Termine in der Übersicht** (L-23.3): „Kündigen bis“ (Ende minus Frist; Monate kalendergenau, Monatsende bleibt Monatsende), „Vertragsende“, „Indexanpassung“ laufen in der Termin-Box mit den Steuerterminen (`DeadlineCalculator.upcoming(extra:)`) |
| FA-16.5 | **Abgleich** (L-23.4): erwartete Raten ab Beginn im Rhythmus; die letzten 12 bis heute werden mit verknüpften Belegen innerhalb ±`spec.contract_match_tolerance_days` Tagen abgeglichen: „gebucht ✓“, „gebucht … ≠ Rate“, „kein Beleg“. Belege verknüpfen über eine Liste (Vertragspartner zuerst) |
| FA-16.6 | **Wiederkehrende Buchung nur als Vorschlag:** „Rate … buchen (Vorschlag)“ zeigt Datum und Betrag, erst „Buchen“ legt die Ausgabe an (netto/USt aus brutto, GR-2) und verknüpft sie |
| FA-16.7 | **Aufbewahrung** (L-23.2): bis 31.12. des Jahres von Vertragsende bzw. letzter verknüpfter Buchung plus `TaxProfile.retentionYears`; unbefristet = „solange der Vertrag läuft“. Löschen nur über die Gefahrenzone, vor Fristende mit Warnung; löscht Seiten und Original |
| FA-16.8 | **Export** (L-23.11): Datenbank und Seiten in der Sicherung; `vertraege.csv` im Paket „Vorläufiger Jahresabschluss“ (FA-15.10). Leasing beim Kleinunternehmer und bei der Einnahmen-Ausgaben-Rechnung: Raten sind Ausgaben (Handbuch) |
| FA-16.9 | **Vertragsarchiv auffindbar** (Rückmeldung Auftraggeber 2026-10-19): oben in der Belegliste Umschalter **„Belege | Verträge“** (48 dp, Verträge öffnet die Vertragsliste), Zeile „Verträge“ in den Einstellungen, weiterhin Export → Verträge. Arten: Miete, Pacht, Leasing, Dienstbarkeit, Versicherung, Darlehen, **Dienstvertrag (Mitarbeiter:in)**, Werkvertrag, Kaufvertrag, Sonstiger Vertrag. Bei Dienstverträgen Hinweis im Formular: Daten Beschäftigter bleiben auf dem Gerät und in der verschlüsselten Sicherung, nie Übertragung an eine KI oder den Anbieter (L-23.8, `employeeContractHint`, `ContractType.hasEmployeeData`) |

---

### 5.13 Mithelfer-Geräte / Belegsammler

Lastenheft 5.29 (L-29.1 bis L-29.9), Entscheidung Auftraggeberin 2026-10-17.
Code: `lib/services/helper/`, `lib/data/helper_repository.dart`,
`lib/features/helper/`. Kein Anbieter-Server; volle Mehrgeräte-Synchronisierung
bleibt O-38 bzw. L-19.12 ff.

| ID | Anforderung |
|---|---|
| FA-17.1 | **Koppeln auf dem Hauptgerät** (Pro `helperDevices`, FA-13.2): Einstellungen → Mithelfer-Geräte → „Gerät hinzufügen“: Name und Weg (seit 0.24.0 Standard „Per E-Mail (automatisch)“, optional „Gemeinsamer Ordner“; „Per Datei teilen“ wird nicht mehr angeboten, ältere Kopplungen bleiben gültig) → QR-Code mit `JENIBELEG1:` + Base64url-JSON {Kopplungs-ID 16 Byte, Schlüssel 32 Byte aus `Random.secure`, Betriebsname, Gerätename, Weg, beim Mailweg Empfangsadresse `a`} – **nie ein Kennwort**. Ohne gültige Empfangsadresse öffnet „Gerät hinzufügen“ zuerst FA-17.9. Hinweis: Code nur dem eigenen Gerät zeigen (P-R46) |
| FA-17.2 | **Mithelfer-Modus:** „Dieses Gerät ist ein Mithelfer-Gerät (koppeln)“ in Schritt 2 der Ersteinrichtung bzw. „QR-Code fotografieren“ (Scanner/Kamera, Code über die Codeerkennung von FA-2.19) oder Code einfügen. Danach zeigt die App nur den Mithelfer-Start (kein Profil, keine Buchungen, Rechnungen, Berichte, Einstellungen). „Kopplung aufheben“ im Menü. Mithelfer brauchen **kein eigenes Abo** (Vorschlag Lastenheft 14a) |
| FA-17.3 | **Erfassen und senden:** Aufnahmeleiste wie FA-12.1 (Scanner, Galerie, Datei; PDF wird zu Seitenbildern); Vorschläge aus der Texterkennung auf dem Gerät (Betrag in EUR, Lieferant, Datum, Beschreibung, Kategorie aus den Startkategorien); Kommentar mit Diktat. „Senden“ verpackt und verschlüsselt (8.9) und übergibt dem Weg; **erst nach erfolgreichem Senden** (Mailweg: nach dem verschlüsselten Ablegen, FA-17.10) werden die Aufnahmen gelöscht. Gemerkt bleibt Betrag · Lieferant mit Status „wartet auf Versand“, „gesendet“ bzw. „übernommen“ |
| FA-17.4 | **Wege** (seit 0.24.0 Standard E-Mail, FA-17.9 bis FA-17.12; die folgenden bleiben als Option bzw. Notweg): (a) Teilen-Blatt (Notweg „Exportieren“ beim Mithelfer und ältere Kopplungen; WhatsApp wird nicht mehr empfohlen) (Android eigener Kanal `share_out`, iOS share_plus), Datei `‹id8›_‹uuid›.jenibeleg`, MIME `application/octet-stream`; das Hauptgerät empfängt über „Teilen“/„Öffnen mit“ (Android-Filter `application/octet-stream` und `application/x-jenibeleg`, dazu `VIEW` mit Endung `.jenibeleg`; iOS eigener Dateityp `at.jenibarb.jenibucht.jenibeleg` in `UTExportedTypeDeclarations` (seit 0.26.0; die frühere Kennung `at.jesenko.buchhaltung.jenibeleg` bleibt als `UTImportedTypeDeclarations` und in `CFBundleDocumentTypes` angemeldet) und `CFBundleDocumentTypes` (Rang Owner), „Öffnen in JeNi bucht“ direkt aus Mail, WhatsApp, Signal und Dateien, `ShareInChannel` kopiert die Datei in die App und leitet in den Eingang; seit 0.23.1, vorher „In Dateien sichern“ nötig; Erkennung an Endung **oder** Kennung `JBHP`) oder über „Belegpaket öffnen“ im Eingang (Dateiauswahl). Teilen-Blatt auf dem iPhone/iPad als `UIActivityViewController` mit Ankerpunkt. **Gemischte Geräte** (Hauptgerät Android mit Mithelfer-iPhone und umgekehrt): Paketformat rein Dart und plattformunabhängig (8.9), QR-Kopplung über die Codeerkennung beider Systeme (ML Kit bzw. Vision `VNDetectBarcodesRequest`). Beim Ordnerweg zeigt die App immer den Kurzhinweis `helperFolderHint`: iCloud Drive gibt es auf Android nicht, gemischte Familien nehmen Google Drive, OneDrive oder Dropbox (über Dateien-App bzw. Android-Dokumentanbieter) oder Messenger/Mail. (b) Gemeinsamer Ordner: beide Geräte wählen denselben Cloud-Ordner „Eingang“ über die Ordnerauswahl der Datensicherung (`BackupFolderChannel`); der Mithelfer schreibt je Beleg eine Datei, das Hauptgerät liest beim Start und bei jeder Rückkehr in die App. „übernommen“ sieht der Mithelfer nur im Ordnerweg (Datei vom Hauptgerät entfernt) |
| FA-17.5 | **Eingang auf dem Hauptgerät:** Antippen öffnet das normale Belegformular mit Seiten und Werten, Vermerk „von ‹Gerät›“ an jedem vorbelegten Feld, Kommentar in der Notiz; kein erneutes Auslesen (Steuersatz wählt die Inhaberin). „Beleg speichern“ = übernehmen; danach werden Seiten im Eingang und das Paket im Ordner gelöscht. Ablehnen mit Grund. Der Eingang nimmt Pakete **in jedem Anspruch** an (L-22.6: nichts geht verloren) |
| FA-17.6 | **Sicherheit:** AES-256-GCM, Kopf als zusätzliche Daten (AEAD); verändertes Paket → „beschädigt oder verändert“; unbekannte Kopplung → „nicht gekoppelt“; getrennte Kopplung → „getrennt, bitte neu koppeln“; keine Datei dieses Formats → Meldung. Gleiche Beleg-UUID ein zweites Mal → „schon im Eingang“, nicht doppelt |
| FA-17.7 | **Trennen** auf dem Hauptgerät löscht den Schlüssel und markiert die Kopplung; neu koppeln erzeugt Kennung und Schlüssel neu. Das Mithelfer-Gerät erhält **nie Daten** vom Hauptgerät zurück |
| FA-17.8 | Hinweis im Bildschirm Mithelfer-Geräte: die Inhaberin bleibt für die Buchhaltung verantwortlich; Mithelfer senden nur Vorschläge |
| FA-17.9 | **Mailweg – Hauptgerät** (Entscheidung Auftraggeberin 2026-10-17, Lastenheft 14a; Standardweg): Mithelfer-Geräte → „Empfang per E-Mail“ (`mail_receive_screen.dart`). Empfangsadresse ist **die Geschäfts-E-Mail aus den Stammdaten**; Häkchen „Andere E-Mail-Adresse für den Empfang von Belegen“ (wie eine abweichende Rechnungsadresse) öffnet ein eigenes Feld. Darunter „Postfach lesen (nur lesen)“: Kennwort oder App-Passwort, Server **automatisch** (`MailAutoconfig`: eingebaut Gmail/iCloud; sonst Mozilla-ISPDB `autoconfig.thunderbird.net/v1.1/‹domain›`, `autoconfig.‹domain›/mail/config-v1.1.xml`, `‹domain›/.well-known/autoconfig/mail/config-v1.1.xml`; übertragen wird nur die Domain) oder von Hand (Server, Port, SSL/TLS bzw. STARTTLS, Benutzer). „Verbinden und speichern“ prüft die Anmeldung (`LOGIN`, `EXAMINE INBOX`). **TLS ist Pflicht** (IMAPS 993 oder STARTTLS; ohne Verschlüsselung keine Anmeldung, Einträge mit `plain` werden ignoriert). Kennwort nur im sicheren Speicher (`flutter_secure_storage`, iOS `first_unlock_this_device`, nicht synchronisiert), nie in Datenbank, Sicherung oder QR-Code. Ohne Kennwort wird nur die Adresse gespeichert (Pakete dann von Hand über „Öffnen mit“) |
| FA-17.10 | **Mailweg – Mithelfer** („Mit deinem E-Mail-Konto senden“, `helper_mail_setup_screen.dart`; Entscheidung: der Mithelfer meldet sich **nur in der reduzierten Mithelfer-App mit seinem eigenen Postfach** an, nie auf dem Hauptgerät): einmalig Adresse und Kennwort/App-Passwort, Server wie FA-17.9 (SMTP 465 SSL/TLS oder 587 STARTTLS, `AUTH PLAIN`, sonst `AUTH LOGIN`). Gmail und iCloud mit nummerierter Anleitung und direktem Link (`https://myaccount.google.com/apppasswords`, `https://account.apple.com` → Anmeldung und Sicherheit → App-spezifische Passwörter). „Senden“ im Erfassen legt den Beleg als verschlüsseltes Einzelpaket ab (Status „wartet auf Versand“). Versand **einmal am Tag** im Hintergrund und **bei jedem Öffnen der App**: **eine** Mail mit **einem** Sammelpaket (8.9, Version 2) aller noch nicht gesendeten Belege, Betreff `[JeNi-Beleg] ‹Kopplungs-ID›-‹JJJJMMTT›-‹Nr›` (Nr. je Tag ab 1), Text ohne Geschäftsdaten. Danach Status „gesendet“; das verschlüsselte Paket bleibt auf dem Gerät und wird nach `spec.helper_mail_retention_days` Tagen (Menü „Aufbewahrung“: 30/90/180/365) gelöscht; wartende Belege nie. Menü „Exportieren“ teilt alle gespeicherten als eine Datei (Notweg). **Ohne eingerichtetes Postfach**: Startseite zeigt „Mit deinem E-Mail-Konto senden“ und „Per Mail-App senden“; im Hintergrund höchstens **einmal am Tag** die lokale Mitteilung „Belege senden“, Antippen öffnet das Mailfenster des Systems mit Empfänger, Betreff und Anhang (Android `ACTION_SEND` mit Selektor `mailto:`, iOS `MFMailComposeViewController`, ohne Mailkonto Teilen-Blatt); mit dem Öffnen gelten die Belege als gesendet |
| FA-17.11 | **Abruf auf dem Hauptgerät** (`HelperMailInbox`, `ImapReader`): stündlich im Hintergrund und bei jedem Öffnen/Zurückkehren (höchstens alle 2 Minuten) sowie beim Öffnen des Eingangs. `UID SEARCH SUBJECT "[JeNi-Beleg]"`, je Treffer nur Kopf (`BODY.PEEK[HEADER.FIELDS (MESSAGE-ID SUBJECT)]`); nur Betreff mit gültigem Kennzeichen **und** bekannter Kopplungs-ID wird ganz geladen (`BODY.PEEK[]`), Anhänge `.jenibeleg` (auch in weitergeleiteten Mails) entschlüsselt und in den Eingang gelegt. **Nie** `STORE`, `COPY`, `MOVE`, `EXPUNGE` oder `DELETE`: nichts wird gelöscht, verschoben oder als gelesen markiert. Verarbeitete Message-IDs in `helper_mail_seen`; fremde Mails werden nicht gemerkt. Import idempotent über die Beleg-UUID: dieselben Belege in mehreren Mails oder Dateien kommen einmal in den Eingang. Getrennte Kopplung: Mail gemerkt, Belege abgelehnt (FA-17.6) |
| FA-17.12 | **Hintergrund und Berechtigungen:** Android WorkManager (Paket `workmanager`) periodisch 1 h (Hauptgerät, `spec.helper_mail_poll_minutes`) bzw. 24 h (Mithelfer, `spec.helper_mail_send_hours`) mit Bedingung „Netz verbunden“; iOS `BGAppRefreshTask` `at.jenibarb.jenibucht.mailsync` (gleicher Name als WorkManager-Aufgabe, `mailTaskId`) (bestmöglich, iOS bestimmt den Zeitpunkt). Zeitentscheidungen rein in Dart (`HelperMailSchedule`). Vor den Systemabfragen **einmal** eine Erklärung (Mitteilungen für die Erinnerung, iPhone-Hintergrundaktualisierung); danach Abfrage der Mitteilungsberechtigung (Android 13+ `POST_NOTIFICATIONS`, iOS Alert/Ton) über `flutter_local_notifications`. Eigene IMAP/SMTP-Implementierung in reinem Dart (`lib/services/mail/`), weil `enough_mail` 2.1.7 `xml` < 7 verlangt und mit der vorhandenen `xml` ^7.1 (E-Rechnungen) kollidiert; nur die benutzten Befehle, Tests mit Ersatzserver. Google-OAuth (`gmail.send`) und Microsoft-OAuth (Graph `Mail.Send`) nicht gebaut: offener Punkt Lastenheft 14a |
| FA-17.13 | **Hilfe und Koppeln aus den Einstellungen** (Rückmeldung Auftraggeber 2026-10-19, `features/helper/helper_help_sheet.dart`): „?“-Knopf (48 dp) neben „Dieses Gerät ist ein Mithelfer-Gerät (koppeln)“ (Schritt 2 der Ersteinrichtung), in der Kopfzeile von „Mithelfer-Geräte“ und „Ich helfe mit“ sowie im Blatt „Gerät hinzufügen“; öffnet das Blatt „Was ist ein Mithelfer-Gerät?“ (nur Belege fotografieren und senden; bucht nichts, sieht keine Buchhaltung; AES-256, Schlüssel nur über den QR-Code; Standard eigenes Postfach, sonst Ordner oder Teilen; Trennen auf dem Hauptgerät) mit „Verstanden“ (56 dp). Einstellungen eines Hauptgeräts: neben „Mithelfer-Geräte“ die Zeile **„Als Mithelfer-Gerät koppeln“** (56 dp): mit Belegen oder Rechnungen auf dem Gerät nur Hinweis „Nicht auf diesem Gerät“ (`HelperRepository.hasBookkeepingData`); sonst Bestätigung „Zum Mithelfer-Gerät machen?“ (Stammdaten bleiben gespeichert, sind bis zum Aufheben der Kopplung nicht sichtbar), dann „Ich helfe mit“ |

### 5.14 Steuerliche Registrierungen in mehreren Ländern

Lastenheft 5.30 (L-30.1 bis L-30.7), Entscheidung Auftraggeber 2026-10-18,
Regel GR-16. Code: `lib/domain/tax_registration.dart`,
`lib/data/tax_registration_repository.dart`,
`lib/features/settings/tax_registration_screen.dart`,
`DeadlineCalculator.forRegistration`, `RegistrationScope` in
`lib/data/repositories.dart`. Beispiel: österreichischer Kleinunternehmer mit
deutscher USt-Registrierung wegen Amazon-FBA-Lager (Prüfinstanz Steuerberater,
P-S68).

| ID | Anforderung |
|---|---|
| FA-18.1 | **Stammdaten → „Steuerliche Registrierungen“** (in der Ersteinrichtung optional über Schritt 4 „Weitere Länder“, FA-1.13): Zeile Heimat (Land, Kleinunternehmer/Regelbesteuerung), darunter je weiterem Land eine Zeile 56 dp (Besteuerung, Zeitraum, UID, Ende), Knopf **„Land hinzufügen“** volle Breite 56 dp. Länderauswahl als Bottom-Sheet: AT/DE ohne Heimatland, bereits angelegte ausgegraut, IT, FR, ES, PL, CZ, NL sichtbar mit „bald“ (`upcomingRegistrationCountries`). Einstellungen zeigen „+ DE“ in der Stammdatenzeile |
| FA-18.2 | **Formular je Land:** Besteuerung (Regelbesteuerung – Standard; Kleinunternehmer; EU-Kleinunternehmer-Verfahren), UID mit Formatprüfung (`VatIdFormat`) und passendem Länderpräfix, Steuernummer, Finanzamt (freier Text, vorbelegt aus `TaxProfile.foreignTaxOffices` des Registrierungslands für das Heimatland: AT-Unternehmen in DE → „Finanzamt München“, `spec.de.foreign_tax_offices`; DE-Unternehmen in AT → „Finanzamt Österreich, Dienststelle Graz-Stadt“, P-S71), Voranmeldungszeitraum (monatlich – Standard, vierteljährlich, nur jährlich), Dauerfristverlängerung (nur wo `hasPermanentExtension`, DE § 46 UStDV), Beginn und Ende. Ohne Regelbesteuerung wird der Zeitraum „keine“ gespeichert. „Land entfernen“ in der Gefahrenzone, nur ohne Belege |
| FA-18.3 | **Steuerland je Beleg:** Im Belegformular Chips „Steuerland“ (Heimatkürzel, z. B. AT, und jedes am Belegdatum gültige weitere Land) **nur bei mindestens einer weiteren Registrierung**; Heimat vorgewählt, ein Tipp wechselt. Der Wechsel setzt den Steuersatz auf den Normalsatz des Landes (0 bei Kleinunternehmer) und zeigt dessen Sätze. Rechnungen buchen immer auf die Heimat (Grenze 11) |
| FA-18.4 | **Für das Finanzamt:** Bei weiteren Registrierungen Chips je Land über dem Zeitraum. Heimat: nur Belege ohne Steuerland, Heimatformular (AT-Kleinunternehmer: U30 nur bei Reverse Charge, sonst Hinweis). Weiteres Land: nur dessen Belege, dessen `vatReturnForm` und Vorsteuerabzug nach Besteuerungsform (DE-Regelbesteuerung → UStVA Kz 81/86/66/83); ohne Regelbesteuerung Hinweis statt Kennzahlen (P-S69). Bei jeder weiteren Registrierung mit Kennzahlen Warnhinweis `TaxProfile.warehouseTransferHint` des Registrierungslands: Verbringen ins Lager ist nicht enthalten, DE Kz 89/61 bzw. AT Kz 070/072/065 trägt die Steuerberatung selbst ein (Entscheidung 2026-10-18, Grenze 11) |
| FA-18.5 | **Termine je Registrierung** (Termin-Box, nur Anzeige wie FA-10.3): Regeln aus `TaxProfile.registrationDeadlineRules` des Registrierungslands (`spec.*.registration_deadline_rules`) – DE: UStVA 10. des Folgemonats bzw. nach Quartalsende, mit Dauerfristverlängerung einen Monat später (§ 18 Abs 1 UStG, § 46 UStDV), USt-Jahreserklärung 31.07. des Folgejahres (§ 18 Abs 3 UStG, § 149 Abs 2 AO); AT: UVA 15. des zweitfolgenden Monats (§ 21 Abs 1 UStG), U1 30.06. (§ 21 Abs 4 UStG, § 134 BAO). Bezeichnung mit Länderkürzel („DE · UStVA Januar 2027“), Verschiebung auf den nächsten Werktag mit den bundesweiten Feiertagen des Registrierungslands (P-S71), nur Zeiträume zwischen Beginn und Ende; „nur jährlich“ → nur Jahreserklärung; „keine“, Kleinunternehmer oder EU-KU → keine Termine im anderen Land |
| FA-18.6 | **Heimattermine:** Schalter „One-Stop-Shop (OSS)“ in „Wirtschaftsjahr und Termine“ → OSS-Erklärung vierteljährlich bis Ende des Folgemonats (Art 369g MwStSystRL; AT Art 25a UStG, DE § 18j Abs 3 UStG; P-S72), unabhängig vom UVA-Zeitraum, **ohne** Verschiebung auf den nächsten Werktag (`DeadlineRule.shiftsToWorkday`, Kenndaten `=`); ebenso die EU-KU-Meldung. Mindestens eine Registrierung im EU-Kleinunternehmer-Verfahren → „EU-KU-Meldung“ vierteljährlich bis Ende des Folgemonats im Heimatland (Art 284d MwStSystRL; P-S69) |
| FA-18.7 | **Kleinunternehmergrenze der Heimat** (FA-4.x) zählt nur Belege ohne Steuerland; Umsätze aus einem Lager im anderen Land sind dort steuerbar (P-S70). Die EU-weite Grenze des EU-KU-Verfahrens (100.000 €) prüft die App nicht (Grenze 11) |
| FA-18.8 | **Gewinnermittlung** (E1a/Anlage EÜR) im Heimatland über alle Steuerländer (`PeriodTotals +`), je Land mit dessen Vorsteuerabzug; Anlagen und AfA nur Heimat; Hinweis „Alle Steuerländer zusammen“. Übersicht, Kassabuch und Exporte rechnen weiter über alle Belege mit den Heimatregeln (Grenze 11) |
| FA-18.9 | **Plattformimport** (FA-2.43 ff.): Abgangsland je Verkauf aus der Spalte `ship-from-country`/`sale-depart-country` u. ä., sonst bei Versand durch Amazon (FBA) das Marktplatzland. Besteht dafür eine am Verkaufstag gültige Registrierung, wird je Monat **eine eigene Sammelbuchung** mit diesem Steuerland gebucht (Normalsatz des Landes bzw. Steuer laut Bericht, steuerfrei bei Kleinunternehmer-/EU-KU-Registrierung), Beschreibung „Amazon März 2026 (DE): n Verkäufe“. Hinweise: „Lager dort angenommen“ (nur Marktplatzland, P-S73) und „Fernverkauf“ (Abgangsland ≠ Bestimmungsland). Gebühren bleiben Heimat (Reverse Charge am Sitz). Ohne Registrierung unverändert mit Pan-EU-Hinweis |
| FA-18.10 | **EU-KU-Nummer (EX)** (Rückmeldung Auftraggeber 2026-10-19; Art 284 Abs 3 MwStSystRL idF RL (EU) 2020/285, DE § 19a UStG, AT § 6 Abs 1 Z 27 UStG 1994 idF AbgÄG 2024): Im Formular einer Registrierung mit Besteuerung „EU-Kleinunternehmer-Verfahren“ ersetzt das Feld **„EU-KU-Nummer (EX)“** die UID des Landes. Die Nummer vergibt der Heimatstaat, deshalb steht sie **einmal im Firmenprofil** (`company_profile.eu_sme_id`, Schema 28), getrennt von der eigenen UID; die Registrierung speichert keine UID. Formatprüfung offline (`EuSmeIdFormat`): AT `ATU` + 8 Ziffern mit UID-Prüfziffer + `EX`, DE `DE` + 9 Ziffern mit Prüfziffer + `EX` (`spec.eu_sme_id_suffix`), Präfix des Heimatlands, leer erlaubt (P-S76). **Rechnung:** Kleinunternehmer-Rechnung an einen Kunden in einem anderen Land als dem Heimatland zeigt im Kopf „EU-KU-Nr.: …“ neben Steuernummer und UID (`InvoiceTexts.showsEuSmeId`); die Nummer wird mit dem `seller_snapshot` eingefroren (GR-8). Pflicht und Ort der Angabe: P-S77 |

### 5.15 Abgaben & Rücklagen

Code: `lib/domain/levy_rules.dart` (`TaxProfile.levies`), `lib/services/levies/`,
`lib/data/levy_settings_repository.dart`; Bildschirm
`features/levies/levies_screen.dart`. Kenndaten `spec.*.income_tax_<Jahr>`,
`spec.*.profit_allowance`, `spec.*.social_insurance`,
`spec.*.social_insurance_business_expense`, `spec.*.surcharges`,
`spec.*.trade_tax`. Nur Einzelunternehmen (Lastenheft 5.31); Lohnabgaben folgen
mit „Premium Plus“ (Lastenheft 5.32). Alles ist als **„Schätzung – ersetzt keine
Steuerberatung“** gekennzeichnet (P-R59). Tarif **Pro** (Entscheidung Auftraggeber 2026-10-19, Lastenheft O-43,
`Feature.levyReserve`, FA-13.2); Basis in der Testzeit hat es als „Pro
inklusive“, die Demo zeigt es. Buchungen in Abgabenkategorien bleiben in jedem
Anspruch normale Buchungen (auch FA-19.4).

| ID | Anforderung |
|---|---|
| FA-19.1 | **Karte „Rücklage für Steuern & SV“** auf der Übersicht direkt unter dem Ergebnis, sobald eine Abgabe > 0 geschätzt ist: empfohlene Rücklage pro Monat (offene Jahressumme / restliche Monate inkl. laufendem, auf volle Euro aufgerundet) und „offen“ je Abgabe; ganze Karte tippbar → Bildschirm „Abgaben & Rücklagen“. **Ohne Pro** statt der Karte eine Zeile „Abgaben & Rücklagen (Pro)“ (56 dp) zur Abo-Seite; ebenso der Einstieg in „Für das Finanzamt“ |
| FA-19.2 | **Schätzung AT:** Gewinn bis heute (E/A, FA-19.4) plus gebuchte SVS-Beiträge, linear auf 12 Monate hochgerechnet = Beitragsgrundlage (Hinzurechnung § 25 Abs 2 Z 2 GSVG), begrenzt auf Mindest-/Höchstbeitragsgrundlage; PV 18,5 %, KV 6,8 %, Selbständigenvorsorge 1,53 %, UV fix 12,95 €/Monat. Erste drei Jahre ab Gründungsjahr: Hinweis „vorläufig vorgeschrieben … Nachbemessung später“ (§ 25a GSVG). KU-Ausnahme (§ 4 Abs 1 Z 7 GSVG): Hinweis, wenn Umsatz ≤ 55.000 € und Gewinn ≤ 6.613,20 €; Schalter „Ausnahme beantragt“ lässt nur UV. Einkommensteuer: Gewinn − SVS − Grundfreibetrag (15 % bis 33.000 €, § 10 EStG 1988) nach Stufentarif des Jahres (§ 33 EStG 1988, kaufmännisch auf Cent). Hinweis: Kommunalsteuer, DB, DZ nur mit Dienstnehmern |
| FA-19.3 | **Schätzung DE:** Gewinn hochgerechnet; Gewerbesteuer außer bei Freiberuflerin (Schalter, Vorschlag aus Rechtsform): Gewinn auf 100 € abgerundet − 24.500 € × 3,5 % × Hebesatz (Eingabe, Vorschlag 400 %); zvE = Gewinn − Kranken-/Pflegeversicherung (Monatsbetrag laut Bescheid × 12, P-S83); ESt nach § 32a EStG (Grundtabelle, volle Euro) minus Anrechnung § 35 EStG (4,0 × Messbetrag, höchstens GewSt und ESt); Solidaritätszuschlag mit Freigrenze 20.350 € und Milderungszone 11,9 %; Kirchensteuer optional 8 % (BY, BW) bzw. 9 % nach Bundesland im Profil. Lohnsteuer/Sozialabgaben nur mit Arbeitnehmern (Hinweis) |
| FA-19.4 | **Abgabenkategorien und E/A:** „Sozialversicherung“, „Einkommensteuer-Vorauszahlung“, „Gewerbesteuer“ (Kennung `categories.kind`). `ReceiptRepository.totals(nonDeductibleKinds:)` rechnet Buchungen der Kategorien aus `LevyRules.nonDeductibleKinds` dem Ergebnis wieder hinzu: Einkommensteuer immer (privat), Gewerbesteuer (§ 4 Abs 5b EStG), DE Kranken-/Pflegeversicherung (Sonderausgabe); AT SVS bleibt Betriebsausgabe. Saldenliste, vorläufiger Abschluss und Kennzahlen zeigen die Hinzurechnung. „Bisher bezahlt“ = Summe der Buchungen je Kennung im Kalenderjahr bis heute |
| FA-19.5 | **Nächste Zahlungen:** ESt-Vorauszahlung (AT 15.2./15.5./15.8./15.11., DE 10.3./10.6./10.9./10.12.) und SVS-Beitrag (Ende Feb./Mai/Aug./Nov., nur mit SVS-Versicherung) aus `TaxProfile.deadlineRules`, höchstens vier, ESt mit Betrag laut Bescheid; dieselben Termine stehen in der Termin-Box (FA-10.3). Umsatzsteuer-Zahllast des laufenden Quartals (Regelbesteuerung) als eigene Zeile |
| FA-19.6 | **Angaben:** ESt-Vorauszahlung je Quartal (Bescheid); AT Schalter KU-Ausnahme; DE Monatsbetrag KV/PV, Schalter Freiberuflich, Hebesatz, Schalter Kirchensteuer. Keine Pflichtfelder; „Angaben speichern“ unten volle Breite 56 dp. Einstieg auch aus „Für das Finanzamt“ (oberste Karte) |

### 5.16 Buchungsregeln

Entscheidung Auftraggeber 2026-10-20 (Lastenheft 14a). Code:
`lib/domain/booking_rule.dart`, `lib/services/booking_rule_split.dart`,
`lib/services/booking_rule_templates.dart`,
`lib/data/booking_rule_repository.dart`,
`lib/services/reports/booking_rule_report.dart`, Bildschirme
`features/booking_rules/`. Kenndaten `spec.at.mixed_use`, `spec.de.mixed_use`.
Tarif **Pro** (`Feature.bookingRules`, Entscheidung Auftraggeber 2026-10-20,
O-47): anlegen und ändern; bestehende Regeln wirken in jedem Anspruch weiter,
sonst stimmt der Gewinn nicht. Alles ist **„Grundlage für die Steuerberatung –
ersetzt keine individuelle Beratung“** (P-R65).

| ID | Anforderung |
|---|---|
| FA-20.1 | **Regel:** Name, Art (Privatanteil / betrieblicher Anteil; gespeichert wird immer der betriebliche Anteil), Geltungsbereich (Kategorien und/oder Lieferant als Namensteil ohne Groß-/Kleinschreibung, Steuerland alle/Heimat), Anteil in Promille, Grundlage (Fahrtenbuch km betrieblich/gesamt, Fläche m² Büro/gesamt – Anteil daraus berechnet –, Schätzung, Sonstige), gültig ab/bis (einschließlich), **Begründung Pflicht**. Mindestens Kategorie oder Lieferant. Bildschirm „Buchungsregeln“ (Einstellungen) und Formular mit „Speichern“ unten 56 dp |
| FA-20.2 | **Anhänge und Verlauf:** Foto (Kamera) oder Datei (PDF, Bild) mit optionaler Notiz („Büro im Grundriss rot markiert“), gespeichert wie Belegseiten; nur anhängbar. Verlauf unveränderlich: Anlegen, Änderungen mit alt → neu, Anhang, Ausnahme |
| FA-20.3 | **Wirkung:** `ReceiptRepository.totals(mixedUse:)` wertet für alle Ausgaben im Zeitraum (ohne Storno, ohne Anlagenzugang) die erste passende Regel aus (die zuerst angelegte gewinnt, GR-17). `PeriodTotals.rulePrivatePart` wird dem Ergebnis hinzugerechnet (wie Bewirtung), die nicht abziehbare Vorsteuer (`ruleInputVatRemoved`) aus `expenseVat` und `inputVatByRate` herausgerechnet – wirkt auf UVA/Kennzahlen und Zahllast; unter 10 % betrieblicher Nutzung entfällt die Vorsteuer ganz und ihr betrieblicher Teil wird Aufwand (`ruleVatAsExpense`). Kleinunternehmer: Basis brutto, keine Vorsteuer. Kassabuch und Belegsummen bleiben brutto unverändert. Vorsichtige Umsetzung: anteiliger Vorsteuerabzug statt voller Zuordnung mit unentgeltlicher Wertabgabe (DE § 3 Abs 9a UStG, AT § 3a Abs 1a UStG 1994); PKW-Vorsteuerausschluss AT (§ 12 Abs 2 Z 2 lit b UStG 1994) regelt weiter die Kategorie/Erfassung (P-S88) |
| FA-20.4 | **An der Buchung:** im Belegformular unter der Kategorie Karte „Regel: PKW 30 % betrieblich“ (56 dp), Tippen öffnet die Regel; bei gespeicherten Belegen Schalter „Diese Buchung ausnehmen“ (`booking_rule_exclusions`), die Buchung zählt dann voll; die nächste passende Regel greift |
| FA-20.5 | **Berichte:** Saldenliste und vorläufiger Jahresabschluss bekommen „davon Privatanteile laut Buchungsregeln“ bzw. „Hinzurechnung Privatanteile laut Buchungsregeln“ und den Abschnitt **„Buchungsregeln und Angaben für die Steuerberatung“**: je Regel Anteil, Buchungen (ausgenommene), Aufwand, betrieblich, Privatanteil, nicht abziehbare Vorsteuer, Art, Gültigkeit, Geltungsbereich, Grundlage mit Zahlen, Begründung, Anhangsliste, Hinweis. Das Paket für die Steuerberatung enthält zusätzlich `Buchungsregeln.csv` und den Ordner `Buchungsregeln/` mit den Anhängen |
| FA-20.6 | **Hilfeartikel mit Vorlage:** Handbuch-Abschnitte „Privat-PKW teilweise betrieblich“ und „Büro in der eigenen Wohnung“ (Beispiele AT/DE mit Fundstellen) zeigen unten „Regel anlegen“ (56 dp); die Vorlage füllt Name, Kategorie (Kfz-Kosten bzw. Miete & Betriebskosten), Grundlage, Zahlen (3.000 von 10.000 km; 12 von 80 m²), Begründung und „ab 1.1. des Jahres“ vor (`BookingRuleTemplate`) |
| FA-20.7 | **Demo:** je eine Musterregel PKW 30 % (Fahrtenbuch, Autowerkstatt Muster) und Büro 15 % (12 m² von 80 m², Energie Muster) mit je einem Beleg (AT und DE) |
| FA-20.8 | **KI-Chat (nicht gebaut, Lastenheft L-21 Stufe C):** Chat in der Hilfe über einen eigenen Server-Proxy zu Anthropic (Schlüssel nie in der App), Einwilligung, AVV, US-Transfer, keine Art.-9-Daten; erklärt Regeln, stellt Fragen und **schlägt** eine Buchungsregel und Aufgaben (z. B. Grundriss hochladen, Büro markieren, m² eingeben) **vor**, die die Nutzerin bestätigt; dokumentiert mit Gesprächsauszug. Positionierung: Eingangsinformation für die Steuerberatung, „bereitet das Gespräch mit der Steuerberatung vor und spart Zeit“ (P-R66) |

### 5.17 Regelstand und Aktualisieren-Hinweis

Entscheidung Auftraggeber 2026-10-20 (Lastenheft 14a). Code
`lib/services/rules_freshness.dart`, Werte `TaxProfile.rulesAsOf`,
`TaxProfile.rulesValidUntil`; Pflegeprozess und Checkliste aller Werte mit
amtlicher Quelle, Veröffentlichungszeitpunkt, Codestelle und `spec.*`-Schlüssel
in [`REGELPFLEGE.md`](REGELPFLEGE.md) (Grundlage der wöchentlichen
Recherche-Routine). Offline, kein Server.

| ID | Anforderung |
|---|---|
| FA-21.1 | **Regelstand je Land** im `TaxProfile` (AT, DE: Stand 01.01.2026, gültig bis 31.12.2026); Einstellungen zeigen „Steuerregeln: Stand 01.01.2026, gültig für 2026 (AT/DE)“ (gleiche Stände von Heimat und Registrierungen zusammengefasst) |
| FA-21.2 | **Hinweis auf der Übersicht:** ist heute nach `rulesValidUntil` eines aktiven Profils (Heimat oder Registrierung), ein Band „Für <Jahr> gibt es neue Steuerwerte – bitte App aktualisieren.“ (einmal, nicht blockierend, ganze Fläche tippbar ≥ 48 dp) → Store-Seite (Android `https://play.google.com/store/apps/details?id=at.jenibarb.jenibucht`, iOS Platzhalter bis zur App-Store-ID, P-D57) |
| FA-21.3 | **Rechnen läuft weiter:** Abgaben & Rücklagen und Kennzahlen eines Jahres nach dem Regelstand nutzen die letzten Werte und zeigen „Werte von <Jahr> – Schätzung unsicher“ |

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
| Alle Bildschirme | `main.dart` (`builder`) | Tippen neben ein Eingabefeld schließt die Tastatur (iOS-Ziffernblock hat keine Fertig-Taste; Gerätetest 2026-10-20) |
| Ersteinrichtung | `features/onboarding/setup_wizard.dart` | Willkommensseite (Logo, Los geht's, Demo, Sicherung wiederherstellen, Gerät koppeln mit „?“) und Schritte 1 bis 5 mit Fortschritt, Zurück, „Später hinzufügen“ (FA-1.13) |
| Bestätigungen | `features/onboarding/consent_screen.dart` | `ConsentPanel`: Häkchen „keine Steuerberatung“, Links auf Nutzungsbedingungen und Datenschutzerklärung, „Akzeptieren und weiter“ (FA-1.10); Schritt 1 der Einrichtung bzw. eigener Bildschirm bei neuer Fassung |
| Stammdaten | `features/onboarding/company_setup_screen.dart` | Firmenprofil anlegen und bearbeiten, Firmenlogo, Skonto-Vorschlag und AGB-Adresse (FA-5.17, FA-5.19); Abschnitt „Wirtschaftsjahr und Termine“ (FA-10.1, nur Stammdaten) |
| Hauptnavigation | `features/home/home_shell.dart` | Vier Bereiche: Tab-Leiste (compact) oder Navigationsleiste links (medium, expanded), FA-9.2; einmaliges Angebot „App-Symbol auf den Startbildschirm“ (FA-1.19) |
| Übersicht | `features/dashboard/dashboard_screen.dart` | Abo-Hinweis (FA-13.8), Kassabuch, Umsatzsteuer, Grenzwertampel, Termin-Box „Nächste Termine“ (FA-10.3), Verlauf; Aufnahmeleiste unten mittig: „Foto“, runder Knopf „Beleg“, „Datei“ (FA-12.1), weicht beim Scrollen aus und kommt nach 5 s zurück; Grenzwertampel mit Grenzen des Landes (FA-4.14); Zeitraum-Chips umbrechend; unten 112 dp Abstand, damit der Knopf keine Karte verdeckt |
| Belegliste | `features/receipts/receipt_list_screen.dart` | Umschalter „Belege | Verträge“ oben (FA-16.9); Suchen, filtern, öffnen; Aufnahmeleiste „Foto“ – „Beleg“ – „Datei“ unten mittig (FA-12.1); Chip-Reihe mit Jahr, Alle/Einnahmen/Ausgaben, „Storniert“, umbrechend (FA-12.4) |
| Beleg bearbeiten | `features/receipts/receipt_edit_screen.dart` | Erfassen, Seiten (Aufnahmeknopf mittig über Speichern, FA-12.1), Mikrofon in Freitext- und Betragsfeldern (FA-2.61), Aufteilung nach Steuersätzen (`vat_split_editor.dart`, FA-2.33), Hinweisstreifen Link-QR (`link_invoice_strip.dart`, FA-2.42), Vermerk „vom Kassen-QR“ (FA-2.36), Originaldatei bei PDF/E-Rechnung (FA-2.41), automatisches Auslesen mit „Erneut auslesen“, Betrag, Fremdwährung mit „Kurs abrufen“ und Bankbetrag (FA-2.24 bis FA-2.26), Kategorie, Rechnungsnummer, Aussteller-UID, Kommentare; stornierte Belege nur lesen. Speicherleiste unten fixiert (`receipt_save_bar.dart`), über der Tastatur, Primärknopf 56 dp hoch: Telefon volle Breite, ab 600 dp rechtsbündig; bei neuen Seiten „Vollständig – Beleg speichern“ (FA-2.14) |
| Rechnungsliste | `features/invoices/invoice_list_screen.dart` | Status, PDF teilen, Aktionen; Knopf „Bezahlt“ mit Bottom-Sheet Zahlungseingang und Skonto (FA-5.12, FA-5.18); Korrigieren und Stornieren mit Bottom-Sheet (FA-5.31, FA-5.32), Löschen mit Bestätigung (FA-5.20) |
| Rechnung bearbeiten | `features/invoices/invoice_edit_screen.dart` | Kunde, Positionen mit Rabatt, Karte „Rabatt, Versand, Skonto“, Summe je Satz; Leiste `PrimaryActionBar` (`widgets/primary_action_bar.dart`) „Beenden“ / „Rechnung ausstellen“ bzw. „Beenden“ / „PDF senden“, Zurück speichert den Entwurf (FA-5.15 bis FA-5.20, FA-5.34) |
| Angebote | `features/offers/offer_screens.dart` | Liste mit Status und „gültig bis“; Formular mit Kunde, Gültigkeit, Positionen, Summe, „PDF senden“, „Zur Rechnung machen“ (FA-5.40 bis FA-5.47) |
| Artikel | `features/articles/article_screens.dart` | Liste mit Suche, Artikel anlegen/ändern/löschen (FA-5.44); Bottom-Sheet „Position übernehmen“ in `position_picker.dart` (FA-5.45) |
| Kunde bearbeiten | `features/invoices/customer_edit_screen.dart` | Kundenstammdaten, Schalter „Unternehmen“ (FA-5.24); Abschnitt „E-Rechnung“ mit drei ganzen Zeilen (≥ 56 dp) ZUGFeRD-PDF (Standard) · XRechnung · ebInterface, darunter je nach Wahl Käuferreferenz (optional), Leitweg-ID bzw. Auftragsreferenz und Lieferantennummer (FA-5.49) |
| Mahnung (Bottom-Sheet) | `features/invoices/dunning_sheet.dart` | Stufe, bisherige Schreiben mit Storno, Frist, Mahnkosten mit Verbraucherhinweis, Zinsen, Pauschale, Vorschau, „erstellen und senden“ (FA-5.21 bis FA-5.23) |
| Plattformimport | `features/import/platform_import_screen.dart` | Eine Karte je Monat, Hinweise, Amazon-Gebührenrechnung, unten „Übernehmen“ (FA-2.43 bis FA-2.49); geöffnet aus der Hauptnavigation, wenn eine CSV/TSV/TXT geteilt wird |
| Abgaben & Rücklagen | `features/levies/levies_screen.dart` | Hinweis „Schätzung – ersetzt keine Steuerberatung“, Rücklage pro Monat, Jahresschätzung je Abgabe mit bezahlt/offen und Fundstelle (Tippen), nächste Zahlungen, Angaben mit „Angaben speichern“ unten (FA-19.1 bis FA-19.6); Karte `LevyReserveCard` auf der Übersicht |
| PDF ansehen | `features/pdf_viewer/pdf_viewer_screen.dart` | Seiten wischen, Pinch-Zoom, „Seite x von n“; unten Schließen, Drucken, Senden je 56 dp; Demo: Drucken/Senden gedimmt mit Demo-Blatt (FA-5.48) |
| Datensicherung | `features/backup/backup_screen.dart` | Sicherung erstellen und teilen, wiederherstellen mit Vorschau; automatische Sicherung mit iCloud (iOS, FA-7.16) und Liste zum Wiederherstellen |
| Wiederherstellungscode | `features/backup/recovery_code_setup_screen.dart` | Druckblatt teilen/drucken, dann „Code ist aufbewahrt“ (FA-7.10) |
| Wunsch oder Idee | `features/settings/feedback_screen.dart` | Art, Titel, Beschreibung mit Diktat, technische Angaben abschaltbar, „Per E-Mail senden“ unten (FA-11.6) |
| Rechtliches | `features/settings/legal_screen.dart` | Impressum, Datenschutz, Nutzungsbedingungen, keine Steuerberatung, Support, Lizenzen (FA-11.4, FA-11.5) |
| Export | `features/export/export_screen.dart` | Karte „Für das Finanzamt“, Zeitraum, Vorschau, Format |
| Verträge | `features/contracts/contract_screens.dart` | Liste mit Art, Partner, nächstem Termin, Rate; „Vertrag ablegen“ mit Seiten, Kurzübersicht (Pro), Fristen, Zahlung, Abgleich, Buchungsvorschlag, Belege verknüpfen, Aufbewahrung, Löschen (FA-16.1 bis FA-16.8) |
| Anlagen und Jahresabschluss | `features/reports/reports_screen.dart` | Zeile Anlagen, Jahr, Kommentar, Anlagenverzeichnis, Saldenliste (Pro), vorläufiger Jahresabschluss als Paket (Pro) (FA-15.12) |
| Anlagen | `features/assets/asset_screens.dart` | Liste mit Buchwert heute, unten „Anlage ohne Beleg erfassen“; „Investition erfassen“/„Anlage“ mit AfA-Plan, unten „Ausscheiden“ und „Speichern“, Bottom-Sheet Ausscheiden (FA-15.1 bis FA-15.7) |
| Steuerliche Registrierungen | `features/settings/tax_registration_screen.dart` | Abschnitt in den Stammdaten: Heimat, weitere Länder (Zeilen 56 dp), „Land hinzufügen“ 56 dp mit Länder-Bottom-Sheet (Zeilen 56 dp, „bald“), Formular mit Besteuerung, UID, Steuernummer, Finanzamt-Vorschlag, Zeitraum, Dauerfristverlängerung, Beginn/Ende, „Speichern“ unten 56 dp, „Land entfernen“ in der Gefahrenzone (FA-18.1, FA-18.2) |
| Für das Finanzamt | `features/tax_office/tax_office_screen.dart` | Steuerland-Chips bei weiteren Registrierungen (FA-18.4), Zeitraum, Kennzahlen der UVA/UStVA zum Kopieren, Schritte und Portal-Link, „U30-Datei teilen“ (Pro, nur AT), Jahreszahlen E1a/Anlage EÜR (FA-14.1 bis FA-14.8) |
| Einstellungen | `features/settings/settings_screen.dart` | Verträge (FA-16.9), „Als Mithelfer-Gerät koppeln“ (FA-17.13); Stammdaten, App-Sperre, Abo (FA-13.5), „Demo ansehen“ bzw. „Demo beenden“ (FA-13.14), Symbol auf Startbildschirm (FA-1.19, nur Android), Belege auslesen, Fremdwährung (Tageskurs-Genehmigung), Kategorien, Rechtsrahmen, Wunsch oder Idee senden (FA-11.6), Rechtliches, Hinweise |
| App-Sperre einrichten | `features/app_lock/app_lock_settings_screen.dart` | PIN, Biometrie, Sperrzeit, Hinweis „PIN vergessen“, Warnung ohne Sicherung |
| Sperrbildschirm | `features/app_lock/lock_screen.dart` | PIN oder Biometrie, Wartezeit nach Fehlversuchen; Abdeckung im App-Umschalter |
| Demo: Land wählen | `features/demo/demo_screens.dart` (`chooseDemoCountry`) | Blatt „Musterfirma aus welchem Land?“: „Deutschland“ (gefüllt, oben, vorausgewählt) und „Österreich“, je 56 dp; ein Tipp startet (FA-13.14) |
| Demo-Band und Hinweisblatt | `features/demo/demo_screens.dart` (`DemoBanner`, `DemoUnavailable`), `features/demo/demo_sheet.dart` | Band oben über allen Seiten in der Demo; Blatt „In der Demo wird nichts gespeichert …“ mit „Abo wählen“/„Weiter ansehen“ unten (FA-13.14) |
| Abo | `features/licensing/subscription_screen.dart` | Stand, Monatlich/Jährlich, Basis und Pro mit Store-Preis, Test, Pflichttext, Kauf wiederherstellen, Promo-Code einlösen (FA-13.13), Abo verwalten, Nutzungsbedingungen, Datenschutz (FA-13.5) |
| Hilfe | `features/help/help_screen.dart` | Suche im Handbuch (FA-11.2), Abschnitt lesen, Support-Mail ohne Treffer (FA-11.3); erreichbar über das Fragezeichen oben rechts (FA-11.1) |
| Mithelfer-Geräte | `features/helper/helper_devices_screen.dart` | „?“ oben (FA-17.13); Eingang, Empfang per E-Mail, gemeinsamer Ordner (optional), gekoppelte Geräte mit „Trennen“ (48 dp), „Gerät hinzufügen“ unten 56 dp → Name und Weg (E-Mail vorgewählt) im scrollbaren Bottom-Sheet → QR-Code (FA-17.1) |
| Belege per E-Mail empfangen | `features/helper/mail_receive_screen.dart` | Geschäfts-E-Mail, Häkchen „Andere E-Mail-Adresse für den Empfang von Belegen“ (56 dp) mit Feld, Kennwort/App-Passwort, Anleitung mit Link (48 dp), „Server selbst eintragen“ (48 dp), Fehlermeldung oben, „Verbinden und speichern“ unten 56 dp (FA-17.9) |
| Mithelfer: E-Mail-Konto | `features/helper/helper_mail_setup_screen.dart` | Adresse, App-Passwort, Gmail-/iCloud-Anleitung mit Link (48 dp), Server von Hand, „Prüfen und speichern“ unten 56 dp; einmalige Erklärung der Berechtigungen (FA-17.10, FA-17.12) |
| Eingang | `features/helper/inbox_screen.dart` | Belege der Mithelfer, Zeile 64 dp antippen = Belegformular „von ‹Gerät›“, Ablehnen 48 dp mit Grund, „Belegpaket öffnen“ unten (FA-17.5) |
| Mithelfer: Start | `features/helper/helper_home_screen.dart` | Ersetzt die Hauptnavigation auf dem Mithelfer-Gerät: Aufnahmeleiste unten mittig wie FA-12.1, Hinweise „Mit deinem E-Mail-Konto senden“ und „Jetzt senden“/„Per Mail-App senden“ (volle Breite, 48 dp), Belege mit „wartet auf Versand“/„gesendet“/„übernommen“, Menü: E-Mail-Konto, Aufbewahrung, Exportieren, Ordner wählen, Kopplung aufheben (FA-17.2, FA-17.10) |
| Mithelfer: Beleg senden | `features/helper/helper_capture_screen.dart` | Seiten, Betrag, Lieferant, Datum, Kategorie (Startkategorien), Beschreibung, Kommentar mit Diktat; „Senden“ unten 56 dp (FA-17.3) |
| Mithelfer: koppeln | `features/helper/helper_pair_screen.dart` | „QR-Code fotografieren“ unten 56 dp, Code von Hand einfügen; erreichbar über „Dieses Gerät ist ein Mithelfer-Gerät (koppeln)“ in Schritt 2 der Ersteinrichtung (FA-17.2) |
| Mithelfer: Hilfe (Blatt) | `features/helper/helper_help_sheet.dart` | „Was ist ein Mithelfer-Gerät?“, „Verstanden“ 56 dp; „Als Mithelfer-Gerät koppeln“ aus den Einstellungen mit Prüfung und Bestätigung (FA-17.13) |

**Navigation:** Vier Ziele – Übersicht, Belege, Rechnungen, Export – in der
Tab-Leiste (Telefon) bzw. in der Navigationsleiste links (Tablet, Querformat,
FA-9.2). Einstellungen erreicht man über das Zahnrad in der Übersicht, die
Hilfe über das Fragezeichen oben rechts auf jedem Hauptbildschirm (FA-11.1).

**Liste-Detail (expanded, FA-9.3):** Belegliste mit „Beleg bearbeiten“,
Rechnungsliste mit „Rechnung bearbeiten“ und Kundenliste mit „Kunde
bearbeiten“ stehen nebeneinander; ohne Auswahl zeigt der rechte Bereich einen
Hinweis.

---

**Buchungsregeln** (FA-20.1): Einstellungen → „Buchungsregeln“ (Liste,
„Regel anlegen“ unten 56 dp) → Formular „Buchungsregel“ (Name, Art als
Segmentschalter, Grundlage, Zahlen, Anteil, Kategorien als Chips, Lieferant,
Steuerland, Gültigkeit als 48-dp-Knöpfe, Begründung, Anhänge Foto/Datei,
Verlauf; „Speichern“ unten 56 dp). Hilfeartikel mit Vorlage: „Regel anlegen“
unten (FA-20.6).

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

Spalten (Namen stabil, auch nach der Umbenennung des Formularfelds in „Produkt oder Leistung“, FA-2.5): Datum, Art, Beschreibung, Geschäftspartner, Kategorie, Konto,
Zahlungsart, Netto, USt-Satz, USt-Betrag, Brutto, Währung, Originalbetrag, Kurs (je EUR, 6 Nachkommastellen), Kursquelle,
Kursdatum, Bankbetrag EUR, Beleg vorhanden, Notiz, Seiten, Kommentare (je
`TT.MM.JJJJ, hh:mm: Text`, getrennt durch ` | `), Teil („1/2“ bei aufgeteilten Belegen, sonst leer), Originaldatei
(„Name (SHA-256 …)“, mehrere durch ` | `; nur erste Zeile, FA-2.41), Nicht abziehbar, Anlass, Teilnehmer (nur Bewirtung, erste Zeile, FA-2.60).
Je Steuersatzzeile eine Zeile; Originalbetrag und Bankbetrag nur in der ersten Zeile eines Belegs.
Danach Summenzeilen für Einnahmen, Ausgaben, ggf. „Kursdifferenzen laut Bank“
(FA-2.26), ggf. „Bewirtung nicht abziehbar“ (FA-2.60) und Ergebnis.

### 8.3 DATEV-Buchungsstapel (`datev`, nur DE)

EXTF-Format, Formatversion 700, Kategorie 21. Zeile 1 Metadaten, Zeile 2
Spaltenüberschriften, ab Zeile 3 die Buchungen.

- Gebucht wird immer **brutto**, ohne Vorzeichen
- Das Vorzeichen steckt im Soll/Haben-Kennzeichen: Einnahme `H`, Ausgabe `S`
- Belegdatum als `TTMM`; das Jahr steht im Header
- Header-Feld „WJ-Beginn“: erster Tag des Wirtschaftsjahres, das den Zeitraum enthält (GR-10)
- Buchungstext maximal 60 Zeichen, Semikola werden durch Komma ersetzt
- **Mehrere Steuersätze:** eine Buchung je Satz mit dem Brutto der Zeile; BU-Schlüssel bleibt leer (Automatikkonto), Zuordnung je Satz prüft die Kanzlei (P-S48)
- **Bewirtung (FA-2.60):** Buchung voll auf 4650 mit Vorsteuer, danach Umbuchung des nicht abziehbaren Teils 4654 an 4650 mit BU 40 (ohne Steuer), damit die Vorsteuer voll bleibt. Zuordnung prüft die Kanzlei (P-S46). BMD (AT) bucht ohne Umbuchung; den Teil zeigen Belegliste und Saldenliste
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

### 8.7 U30-Datei für FinanzOnline (nur AT)

XML nach BMF-Datenstrom „ERKLAERUNGS_UEBERMITTLUNG“ U30, XSD-Stand 07_2026
(`spec.u30_schema_version`), UTF-8, Dateiname `U30_JJJJ-MM_JJJJ-MM.xml`.
`INFO_DATEN` mit `ART_IDENTIFIKATIONSBEGRIFF` FASTNR, Paketnummer (Sekunden
seit 2020, 1 bis 999999999), Datum und Uhrzeit; eine `ERKLAERUNG art="U30"`
mit `ALLGEMEINE_DATEN` (ANBRINGEN U30, ZRVON/ZRBIS als Jahr-Monat, FASTNR),
`LIEFERUNGEN_LEISTUNGEN_EIGENVERBRAUCH` (KZ000, `STEUERFREI`, `VERSTEUERT`)
und `VORSTEUER` in der Reihenfolge der XSD; Beträge mit Punkt und zwei
Nachkommastellen, Attribut `type="kz"`. Kz 095 steht nicht in der Datei.
Gegen die XSD 07_2026 mit `xmllint` geprüft (Regelbesteuert mit Reverse
Charge und 4,9 %, Kleinunternehmer mit Reverse Charge); Prüfung durch das BMF
und Testupload: P-D35.

### 8.8 Berichte für die Steuerberatung (PDF, ZIP)

`AnnualReportPdf` (Work Sans, A4, Kopfzeile „VORLÄUFIG …“ in Rot, Fußzeile
Seite x von y und Erstelldatum). Dateinamen `Anlagenverzeichnis_<von>_<bis>.pdf`,
`Saldenliste_…pdf`, `Vorlaeufiger_Jahresabschluss_…pdf`; Paket
`Jahresabschluss_vorlaeufig_<von>_<bis>.zip` mit dem PDF und den CSV-Exporten
aus 8.2 bis 8.5 (FA-15.10). Paket für doppelte Buchführung
`Buchhaltungspaket_<von>_<bis>.zip`: Saldenliste, Belegliste, DATEV- und
BMD-Export, Ordner `Belege/` mit `<Beleg-ID>_<Datum>_<Seite>.<Endung>`
(FA-15.12). DATEV „Beleglink“ (Feld 20) bleibt leer; DATEV Belegbildtransfer
ist ein Online-Dienst und offline nicht möglich (P-D50). RZL: kein eigenes
Format, Import über Belegliste/BMD-CSV zu prüfen (P-D52). Seit 0.34.0 im
Paket `Buchungsregeln.csv` (Regel, Art, Betrieblich, Grundlage, Gültig,
Geltungsbereich, Begründung, Anhänge, Buchungen, Ausgenommen, Aufwand, davon
betrieblich, Privatanteil, Vorsteuer nicht abziehbar; letzte Zeile Hinweis)
und `Buchungsregeln/<Regel>_<Anhang>_<Datei>` (FA-20.5).

### 8.9 Belegpaket der Mithelfer-Geräte (`.jenibeleg`)

`HelperPackage` (`lib/services/helper/helper_package.dart`), Formatversion 1 (ein Beleg) und seit 0.24.0 **Version 2 (Sammelpaket)**:
4 Byte Kennung `JBHP`, 1 Byte Version, 16 Byte Kopplungs-ID, 12 Byte Nonce,
Chiffrat, 16 Byte GCM-Tag; die ersten 21 Byte sind zusätzliche
authentifizierte Daten. Klartext UTF-8-JSON: `v` (1), `uuid` (UUID v4),
`device`, `created` (ISO 8601), `date` (`JJJJ-MM-TT`), `gross` (Cent, ganzzahlig),
`counterparty`, `category` (Name einer Startkategorie), `description`,
`comment`, `pages` (Base64 der Seitenbilder, JPEG/PNG wie aufgenommen).
Dateiname `‹erste 8 Zeichen der Kopplungs-ID›_‹uuid›.jenibeleg`, eigener
MIME-Typ `application/x-jenibeleg` (gesendet als `application/octet-stream`).

**Version 2 (FA-17.10):** gleicher Kopf mit Versionsbyte 2, Klartext
`{"v": 2, "receipts": [‹Beleg wie Version 1›, …]}`, Dateiname
`‹id8›_‹JJJJMMTT›-‹Nr›.jenibeleg`. Version 1 bleibt lesbar; der Import ist
über die Beleg-UUID idempotent. Die Mail trägt das Paket als Base64-Anhang
(`multipart/mixed`, RFC 2045), Betreff wie FA-17.10.

**Plattformunabhängig (seit 0.23.1 geprüft):** nur Byte-Folgen ohne
mehrbytige Ganzzahlen (keine Bytereihenfolge), UTF-8-JSON, Bilder unverändert
als Base64, AES-256-GCM nach NIST SP 800-38D in reinem Dart (`cryptography`).
`test/helper_package_platform_test.dart` verpackt und öffnet über Kreuz mit
der Vorgabe- und der reinen Dart-Implementierung und vergleicht mit dem festen
Prüfmuster `test/fixtures/belegpaket/pruefmuster_v1.jenibeleg` (Schlüssel
0x00…0x1f, Kopplung 0xa0…0xaf, Nonce 0x10…0x1b). Ändert sich das Muster, ist
das eine neue Formatversion.

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
3. U30-Datei für FinanzOnline teilen (FA-14.4); die App selbst überträgt
   nichts an das Finanzamt
4. Dokumentenscanner unter Android (FA-2.51): Google Play-Dienste laden
   Modell und Oberfläche und können Nutzungs- und Diagnosedaten an Google
   senden; Bilder bleiben auf dem Gerät (P-R42). iOS VisionKit sendet nichts
5. Berichte und Jahresabschluss-Paket für die Steuerberatung teilen
   (FA-15.8 bis FA-15.10), mit Vertragsliste `vertraege.csv` (FA-16.8);
   Vertragsseiten und erkannter Text bleiben sonst auf dem Gerät

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

**Mithelfer-Geräte (FA-17.x):** Belegpakete (Bilder und Werte eines Belegs)
gehen Ende-zu-Ende verschlüsselt vom Mithelfer- zum Hauptgerät, entweder über
das Teilen-Blatt an einen Messenger bzw. eine Mail-App, die die Nutzerin wählt,
oder in einen Cloud-Ordner des Betriebs, den beide Geräte gewählt haben. Der
Messenger- bzw. Cloud-Anbieter sieht nur das Chiffrat, Dateiname, Größe und
Zeitpunkt; der Anbieter der App erhält nichts. Der Kopplungsschlüssel geht nur
per QR-Code von Bildschirm zu Kamera. Offengelegt in `PRIVACY.md`,
Lastenheft 5.19 und `STORE_LISTING.md`; Prüfung P-R46.

**Mailweg der Mithelfer (FA-17.9 bis FA-17.12, seit 0.24.0):**
(a) *Mithelfer-Gerät → SMTP-Server des Mithelfers*: eine Mail je Tag mit dem
verschlüsselten Sammelpaket, Absender ist das **eigene Postfach des
Mithelfers** (Kennwort nur auf seinem Gerät), Empfänger die Empfangsadresse
des Betriebs. Der Mailanbieter sieht Absender, Empfänger, Betreff (Kennzeichen,
Kopplungs-ID, Datum, Nummer), Zeitpunkt, Größe und das Chiffrat – keine
Belegwerte, keine Bilder. (b) *Hauptgerät → IMAP-Server der Empfangsadresse*:
Anmeldung nur lesend, Abruf der Kopfzeilen von Mails mit Kennzeichen und der
eigenen Belegmails; Kennwort nur im sicheren Speicher des Hauptgeräts.
(c) *Serversuche*: nur die **Domain** der Adresse an Mozilla
(`autoconfig.thunderbird.net`) bzw. an `autoconfig.‹domain›` /
`‹domain›/.well-known` (Betreiber der Domain); bei Gmail/iCloud nichts.
(d) Hintergrundaufträge laufen auf dem Gerät (WorkManager/BGTaskScheduler);
lokale Mitteilungen ohne Server. Die Verbindungen sind TLS-verschlüsselt; der
Anbieter der App erhält nichts. Offengelegt in `PRIVACY.md`, Lastenheft 5.19
und `STORE_LISTING.md`; Prüfung P-R47.

### 10.2 Berechtigungen

| Berechtigung | Plattformschlüssel | Zweck |
|---|---|---|
| Kamera | `NSCameraUsageDescription` | Belege abfotografieren; auch VisionKit-Scanner (iOS). Android: der ML-Kit-Scanner läuft in Google Play-Diensten und braucht keine Kamera-Berechtigung der App |
| Fotobibliothek lesen | `NSPhotoLibraryUsageDescription` | Vorhandene Belegfotos hinzufügen |
| Fotobibliothek schreiben | `NSPhotoLibraryAddUsageDescription` | Rechnung in der Fotobibliothek ablegen |
| Face ID | `NSFaceIDUsageDescription` | App-Sperre entsperren (FA-1.16); Auswertung durch das System |
| Biometrie (Android) | `USE_BIOMETRIC` (über `local_auth`) | App-Sperre entsperren (FA-1.16); Auswertung durch das System |
| Mitteilungen | Android 13+ `POST_NOTIFICATIONS` (über `flutter_local_notifications`), iOS Mitteilungen | Erinnerung „Belege senden“ beim Mithelfer (FA-17.10); Abfrage erst nach Erklärung |
| Hintergrund | Android `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK` (über `workmanager`), iOS `UIBackgroundModes` `fetch`, `BGTaskSchedulerPermittedIdentifiers` | Postfach stündlich lesen bzw. täglich senden (FA-17.12) |
| Internet | Android `INTERNET` | IMAP/SMTP und Serversuche (FA-17.9), wie bisher EZB und Link-QR |

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
| **Scanner nicht auf Gerät erprobt** | ML Kit Document Scanner und VisionKit nur kompiliert (CI); Bedienung, Rückfall ohne Play-Dienste und R8-Regeln am echten Gerät offen (P-D37, P-D38). Die Scanner-Oberfläche stammt vom System; Daumenreichweite dort nicht beeinflussbar (P-X15) | vor Release |
| **Abgaben nur geschätzt** | Einzelveranlagung ohne andere Einkünfte, lineare Hochrechnung, keine Absetzbeträge, kein investitionsbedingter Gewinnfreibetrag, keine pauschalen Betriebsausgaben, keine GewSt-Hinzurechnungen, KiSt ohne Kappung, KV/PV DE nur als Eingabe; Tarife 2025 und 2026 (spätere Jahre nutzen 2026); keine GmbH- und Lohnabgaben (Premium Plus) | P-S78 bis P-S83 |
| **EU-KU-Nummer nur offline geprüft** | Format und Prüfziffer (FA-18.10), keine Abfrage bei BZSt oder Finanzamt; die EU-weite Grenze 100.000 € prüft die App nicht (FA-18.7) | P-S76 |
| **Vertragsarchiv ohne KI** | Kurzübersicht nur als Stichwort-Heuristik auf dem Gerät (FA-16.3), keine Zusammenfassung, keine Steuerhinweise (L-23.5, L-23.7 bis L-23.10, Stufe C); PDF nur über „Teilen“ (keine Dateiauswahl); keine Benachrichtigung, nur Termin-Box; Auskunftsexport je Vertragspartner fehlt | Stufe C |
| **Anlagen vereinfacht** | AfA-Jahre sind Kalenderjahre, auch bei abweichendem Wirtschaftsjahr; keine Gebäude (AT § 8 EStG, DE § 7 Abs 4 EStG), keine degressive oder Sonder-AfA, keine Investitionsfreibeträge (AT § 11 EStG) und kein Investitionsabzugsbetrag (DE § 7g EStG); keine PKW-Luxustangente (AT 40.000 €); Sammelposten pro Gut statt einheitlich je Jahr; die Saldenliste ordnet Ausgaben nach Kategorie, nicht nach Formularzeile | später, P-S59 |
| **Keine direkte Übermittlung ans Finanzamt** | AT: U30 nur als Datei zum Hochladen (FA-14.4). Die FinanzOnline-Webservices (Session- und File-Upload-Webservice) bräuchten einen Webservice-Benutzer der Nutzerin (Teilnehmer-ID, Benutzer-ID, PIN) im Schlüsselbund und eine Hersteller-UID; Entscheidung der Prüfinstanzen: erst nach Testupload der Datei (P-D35), Abgrenzung P-R5 und Sicherheitskonzept für die Zugangsdaten. DE: ELSTER nur über ERiC (native Bibliothek, Herstellerregistrierung, Zertifikat der Nutzerin) – bis dahin Kennzahlen zum Kopieren (FA-14.7). Keine Zusammenfassende Meldung: die App erfasst keine innergemeinschaftlichen Lieferungen oder Leistungen mit Kunden-UID; keine Jahreserklärung U1/USt-Erklärung als Datei | Stufe B (L-6.5) |
| **Automatische Sicherung nicht auf Gerät erprobt** | iCloud-Container (FA-7.16) nur kompiliert, unsigniert; braucht vor dem ersten signierten Build den Container im Apple Developer Portal (STORE_ANMELDUNG, P-B13). Ordnerwahl und Schreiben laufen über eigenen Kotlin- bzw. Swift-Code, der hier nur kompiliert (CI), nicht auf einem Gerät getestet ist. Ob die Google-Drive-App unter Android Ordner zur Auswahl anbietet, ist offen (P-B1) | vor Release |
| **Keine revisionssichere Archivierung** | Das `audit_log` schafft Nachvollziehbarkeit im Alltag, ist aber keine manipulationssichere Protokollierung im Sinne einer Verfahrensdokumentation. Die App ist die Vorerfassung; die revisionssichere Aufbewahrung findet in der Kanzlei statt | – |
| **Keine Registrierkasse** | Wer die RKSV-Grenzen (15.000 € Umsatz und 7.500 € Barumsätze) überschreitet, braucht zusätzlich eine registrierkassenpflichtige Lösung | Nicht geplant |
| **E-Rechnung: Grenzen beim Ausstellen** (seit 0.32.0, FA-5.49) | XRechnung nur in CII-Syntax (UBL nicht gebaut; beide gleichwertig zugelassen). Keine Bestellnummer je Rechnung (BT-13), nur die Käuferreferenz der Kundin. Kein Reverse Charge auf Ausgangsrechnungen (0 % bei Regelbesteuerung → Kategorie `Z`). ebInterface nur gegen das XSD geprüft, nicht gegen die Geschäftsregeln von e-Rechnung.gv.at (P-D56). Kein Versand über Peppol oder Portal-Schnittstelle (L-4.5), Upload macht die Nutzerin. Ohne Pro (bzw. in der Demo) normales PDF | Backlog G1, O-44 |
| **Storno nur vollständig** | Die Stornorechnung hebt die ganze Rechnung auf (GR-14); Teilstorno einzelner Positionen oder Teilbeträge (L-3.18) gibt es noch nicht – dafür „Korrigieren“ (Storno + neue Rechnung). Die Rückzahlung wird am Stornotag gebucht, ein späterer Rückzahlungstag ist im Sheet zu wählen | später |
| **Steuerwerte fest im Code** | Kennwerte außer Steuersätzen (seit 0.3.4 `validFrom`, GR-3) haben kein Gültig-ab-Datum und ändern sich nur per App-Update; eine kurzfristige Gesetzesänderung erreicht die Nutzerin erst nach Store-Freigabe | Rechtsstand-Überwachung, Lastenheft L-20 und L-13.5, Stufe B |
| **Belegerkennung nicht auf Gerät erprobt** | Android-Teil im CI-Emulator mit R8 an einem synthetischen Kassenbon geprüft, Swift-Teil nur kompiliert; Korpus mit sechs echten Belegen (`test/fixtures/belege/`); Quote auf dem Gerät noch zu bestätigen (P-D22). Mehrsprachige Schlüsselwörter sind teils nur an synthetischen Texten geprüft. Gelernt wird je Kasse (FA-2.36) und je Lieferant (FA-2.50); Steuersatz-Aufteilungen und Beschreibungen werden nicht gelernt | vor Release |
| **Fremdwährung nur bei Ausgaben** | Eingangsbelege werden umgerechnet (FA-2.24 bis FA-2.27); Ausgangsrechnungen nur in Euro. Den BMF-Monatskurs lädt die App nicht, er wird von Hand übernommen; das EZB-Monatsmittel ist nur eine Näherung (P-S23, P-S24). DATEV/BMD exportieren nur Euro (P-D23). Ein Land mit anderer Währung setzt Mehrwährungsfähigkeit voraus | Backlog G7 |
| **Termine nur als Anzeige** | Die Termin-Box (FA-10.3) erinnert nicht aktiv; Bescheid-Termine (z. B. abweichende Vorauszahlungen, Nachzahlungen) kennt sie nicht. Teil- und Anzahlungen auf Rechnungen bildet die App nicht ab (P-S35) | Stufe 2: Benachrichtigungen |
| **Bewirtung nur mit Regelsatz** | Die Kürzung (AT 50 %, DE 70 %, FA-2.60) gilt für jede Ausgabe der Kategorie „Bewirtung“; AT-Bewirtung ohne Werbezweck (0 %) und unangemessene Aufwendungen erkennt die App nicht. Keine eigene Kennzahl in E1a/Anlage EÜR (P-S46); BMD ohne Umbuchung | später |
| **Mehrere Steuerländer: erste Stufe** | Nur AT und DE wählbar (weitere „bald“, L-30.8). Rechnungen buchen immer auf die Heimat und werden nach den Regeln des Heimatlands besteuert, unabhängig vom Land der Kundin (Entscheidung 2026-10-18; kein Steuerland-Chip auf Rechnungen); Übersicht, Kassabuch und Exporte (CSV, DATEV, BMD, Saldenliste) rechnen über alle Belege mit den Heimatregeln. **Innergemeinschaftliches Verbringen ins Lager wird nicht gebucht** (Entscheidung 2026-10-18, O-40 geschlossen): gebucht werden nur die Verkäufe aus dem Lager an Endkunden. Die Kennzahlen des Lagerlands sind deshalb unvollständig (DE ig. Erwerb Kz 89 und Vorsteuer Kz 61; Heimat AT ig. Lieferung/Verbringen in UVA und ZM) – „Für das Finanzamt“ warnt bei jeder weiteren Registrierung; die Nutzerin bzw. ihre Kanzlei erfasst das Verbringen außerhalb der App (P-S68). Keine Prüfung der EU-weiten 100.000-€-Grenze des EU-KU-Verfahrens. Feiertage des Registrierungslands nur bundesweit. Lagerland aus dem Marktplatz nur angenommen (P-S73); der Amazon-USt-Transaktionsbericht wird nicht als eigenes Format erkannt | L-30.8, L-30.9, O-40 |
| **Kleinunternehmerstatus nicht je Jahr** | Ob Ausgaben brutto zählen, richtet sich nach der aktuellen Einstellung, auch für Vorjahre | später |
| **Keine Teilzahlungen** | Mahnkosten und Zinsen werden nur bei voller Zahlung mitgebucht; Teilzahlungen und deren Anrechnung (§ 1416 ABGB, § 367 BGB) bildet die App noch nicht ab; Basiszinssätze ändern sich nur per App-Update (P-S44) | später |
| **Plattformimport ohne Dateiauswahl in der App** | Die Exportdatei kommt über Teilen bzw. „Öffnen mit“ (Dateien-App, Downloads); eine eigene Dateiauswahl fehlt. Nur EUR; Bestimmungsland für OSS nur näherungsweise (Marktplatz, Lieferland), bei PayPal/Stripe keins. Umsatzsteuer der Verkäufe ohne Steuerspalte zum Normalsatz (P-S51); Spaltennamen nur an synthetischen Dateien geprüft (P-S55) | später |
| **Mengen mit zwei Dezimalstellen** | Die Mengeneingabe verarbeitet zwei Nachkommastellen, obwohl das Datenmodell drei erlaubt | – |
| **Offene Detailseite beim Wechsel der Breitenklasse** | Wird ein Tablet von quer (expanded) auf hoch (medium) gedreht oder das Fenster verkleinert, während rechts ein Beleg, eine Rechnung oder ein Kunde in Bearbeitung ist, schließt sich der Detailbereich; ungespeicherte Eingaben gehen verloren. Gespeichertes bleibt unberührt | später |
| **Mailweg ohne OAuth** | Gmail und iCloud nur mit App-Passwort (Anmeldung in zwei Schritten nötig), Microsoft 365/Outlook.com ohne Basic-Auth gar nicht; Google-OAuth (`gmail.send`) und Microsoft-OAuth (Graph `Mail.Send`) erst nach Einrichtung durch die Auftraggeberin (Lastenheft 14a). iOS-Hintergrund nur bestmöglich: ohne Öffnen der App kann ein Tag vergehen. Beim Rückfall über die Mail-App gelten Belege mit dem Öffnen des Mailfensters als gesendet, auch wenn die Mail verworfen wird („Exportieren“ hilft) | O-38 |
| **Mithelfer-Geräte ohne Synchronisierung** | Nur Einbahn Mithelfer → Hauptgerät (FA-17.x). Der Kopplungsschlüssel liegt in der Datenbank (und damit in der Datensicherung), nicht im Schlüsselbund; wer den QR-Code fotografiert, kann Pakete senden, bis getrennt wird. „übernommen“ nur im Ordnerweg. iOS empfängt Pakete aus Messengern über „In Dateien sichern“ und „Belegpaket öffnen“ (kein „Öffnen in …“-Dokumenttyp). Der Mithelfer schlägt nur Startkategorien vor und keinen Steuersatz. Volle Mehrgeräte-Synchronisierung: O-38 | O-38 |
| **Testzeit auf Android nur genähert** | Google Play meldet der App nicht, ob ein Abo im kostenlosen Test läuft. „Pro inklusive“ beim Basis-Abo gilt deshalb 14 Tage ab dem frühesten Kaufzeitpunkt, den die App je gesehen hat (FA-13.4); nach Neuinstallation mit leerem Keystore auch für Kundinnen, die früher schon getestet haben. Genau ginge es nur mit der Google Play Developer API auf einem Server (L-22.10: kein Server) | P-D46 |
| **Demo ohne PDF-Vorschau in der App** | Behoben in 0.30.0: der PDF-Betrachter (FA-5.48) zeigt das Muster-PDF mit Wasserzeichen; Senden und Drucken bleiben in der Demo gesperrt | erledigt |
| **Abo nicht mit echten Stores erprobt** | Die Lizenzlogik ist mit einem Store-Ersatz getestet (`test/licensing_test.dart`); Produkte in Play Console und App Store Connect fehlen noch (P-D30), Testkäufe ebenso (P-D4). Kaufbelege werden **nicht selbst** kryptografisch geprüft (L-22.4 offen): die App verlässt sich auf die Prüfung durch Play Billing bzw. StoreKit 2 im Paket. Ob StoreKit ohne Abo ein leeres Ergebnis meldet, ist unbekannt; die App wartet bis 7 s (P-D31). Die Testerinnerung kennt nur Käufe auf diesem Gerät; nach Neuinstallation fehlt sie | vor Store-Start |
| **Buchungsregeln nur als Kostenaufteilung** | Seit 0.34.0 (FA-20.x): Anteil je Regel; 1-%-Regelung, Kilometergeld, Arbeitsplatz- und Homeoffice-Pauschalen, volle Vorsteuerzuordnung mit Wertabgabe und eine Regel je Registrierung im UI („Nur Registrierung“ nur im Datenmodell) sind nicht abgebildet; bei mehreren passenden Regeln gilt die zuerst angelegte | P-S88 |
| **Android-APK-Build nicht lokal verifiziert** | Im Entwicklungscontainer ist `dl.google.com` per Netzwerk-Policy gesperrt, das Android SDK ließ sich nicht installieren. Analyse, Format und Tests laufen lokal; die Plattform-Builds verifiziert die CI | – |

---

## 12. Maschinenlesbare Kenndaten

> **Diese Werte prüft `test/specification_sync_test.dart` gegen den Code.**
> Wird ein Wert im Code geändert, ohne ihn hier anzupassen, schlägt der Test fehl.
> Das ist der Mechanismus, der dieses Dokument aktuell hält.

```properties
spec.schema_version = 31
# E-Rechnung erstellen (FA-5.49)
spec.einvoice_guideline_en16931 = urn:cen.eu:en16931:2017
spec.einvoice_guideline_xrechnung = urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0
spec.einvoice_zugferd_file = factur-x.xml
spec.einvoice_ebinterface_namespace = http://www.ebinterface.at/schema/6p1/
spec.helper_mail_poll_minutes = 60
spec.helper_mail_send_hours = 24
spec.helper_mail_retention_days = 90
spec.u30_schema_version = 07_2026
spec.contract_match_tolerance_days = 20
spec.scanner_page_limit = 20
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
spec.seed_category_count = 21
spec.seed_category_income_count = 3
spec.seed_category_expense_count = 18
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
spec.window_compact_max_height_dp = 480
spec.max_content_width_dp = 640
spec.license_trial_days = 14
spec.license_promo_code = JENIBUCHT2M
spec.license_promo_free_months = 2
spec.license_promo_code_discount = JENIBUCHT20
spec.license_promo_code_discount_pro = JENIBUCHT20PRO
spec.license_promo_discount_percent = 20
spec.license_trial_reminder_days = 3
spec.license_offline_grace_days = 45
spec.license_offline_warn_days = 31
spec.license_product_ids = basis_monat,basis_jahr,pro_monat,pro_jahr

# Demo ohne Abo (FA-13.14, O-42)
spec.demo_company = Muster Handel e.U.
spec.demo_receipt_count = 30
spec.demo_watermark = MUSTER – DEMO
spec.demo_de_company = Muster Handel
spec.demo_de_receipt_count = 17
# Aufnahmeleiste der Übersicht weicht beim Scrollen aus (FA-12.1)
spec.capture_bar_show_after_s = 5
# Geführte Ersteinrichtung (FA-1.13), EU-KU-Nummer (FA-18.10)
spec.setup_steps = 5
spec.eu_sme_id_suffix = EX

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
spec.at.vat_return_kz = U30;000;200=022,130=006,100=029,49=124;016;060;095;cent;u30Xml
spec.at.annual_return_kz = E1a;9040;9040;-;-
spec.at.entertainment = 500;voll;nein;§ 20 Abs 1 Z 3 EStG;§ 12 Abs 2 Z 2 lit a UStG 1994
spec.at.rules_as_of = 2026-01-01
spec.at.rules_valid_until = 2026-12-31
spec.at.mixed_use = 100;§ 4 Abs 1 und § 20 Abs 1 Z 1 EStG 1988;§ 12 Abs 2 Z 1 lit a UStG 1994
spec.at.depreciation = halfYear;100000;ak;-;§ 7 Abs 3 EStG;computer=3,software=3,furniture=10,car=8min8,tools=5,other=5
spec.at.deadline_rules = UVA@15+2m | ZM@0+1m | ESt-Vorauszahlung@02-15,05-15,08-15,11-15 | ESt-/USt-Erklärung (FinanzOnline)@+1j06-30 | SVS-Beitrag@02-00,05-00,08-00,11-00~ | OSS-Erklärung@0+1mq= | EU-KU-Meldung@0+1mq=
spec.at.registration_deadline_rules = UVA@15+2m | USt-Jahreserklärung (U1)@+1j06-30
spec.at.foreign_tax_offices = DE=Finanzamt Österreich, Dienststelle Graz-Stadt
# Abgaben & Rücklagen (FA-19.x) – § 33 EStG 1988, § 10 Abs 1 Z 1 EStG 1988, §§ 25, 27 GSVG
spec.at.income_tax_2025 = stufen:1330800=0,2161700=2000,3583600=3000,6916600=4000,10307200=4800,100000000=5000,none=5500
spec.at.income_tax_2026 = stufen:1353900=0,2199200=2000,3645800=3000,7036500=4000,10485900=4800,100000000=5000,none=5500
spec.at.social_insurance_business_expense = ja
spec.at.profit_allowance = 1500;3300000
spec.at.social_insurance = 1850;680;153;1295;661320;9702000;5500000;661320;3
spec.at.surcharges = none
spec.at.trade_tax = none

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
spec.de.dunning_base_rates = 2025-01-01:227,2025-07-01:127,2026-01-01:127,2026-07-01:152
spec.de.dunning_consumer_notice = ja
spec.de.dunning_interest_legal_ref = § 288 Abs 1 BGB | § 288 Abs 2 BGB
spec.de.reverse_charge_kz = 46,47,67
spec.de.vat_return_kz = UStVA;-;190=81,70=86;-;66;83;euro;none
spec.de.annual_return_kz = Anlage EÜR;112;111;140;185
spec.de.entertainment = 700;voll;ja;§ 4 Abs 5 Satz 1 Nr. 2 EStG;§ 15 Abs 1a Satz 2 UStG
spec.de.rules_as_of = 2026-01-01
spec.de.rules_valid_until = 2026-12-31
spec.de.mixed_use = 100;§ 4 Abs 4, § 12 Nr. 1 EStG;§ 15 Abs 1 Satz 2, Abs 4 UStG
spec.de.depreciation = monthly;80000;netto;25001-100000;§ 4 Abs 3 Satz 5 EStG;computer=1,software=1,furniture=13,car=6,tools=5,other=5
spec.de.deadline_rules = UStVA@10+1m+1x | ZM@25+1m | ESt-Vorauszahlung@03-10,06-10,09-10,12-10 | Steuererklärungen@+1j07-31 | OSS-Erklärung@0+1mq= | EU-KU-Meldung@0+1mq=
spec.de.registration_deadline_rules = UStVA@10+1m+1x | USt-Jahreserklärung@+1j07-31
spec.de.foreign_tax_offices = AT=Finanzamt München
# Abgaben & Rücklagen (FA-19.x) – § 32a EStG, SolZG 1995, KiStG, §§ 11, 16 GewStG, § 35 EStG
spec.de.income_tax_2025 = formel:12096,17443,93230,68480,17664,101513,277825,1091192,1924667
spec.de.income_tax_2026 = formel:12348,17799,91451,69878,17310,103487,277825,1113563,1947038
spec.de.social_insurance_business_expense = nein
spec.de.profit_allowance = none
spec.de.social_insurance = none
spec.de.surcharges = 550;2035000;1190;900;BY=800,BW=800
spec.de.trade_tax = 2450000;350;400;4000
```

Umrechnung: Beträge in Cent. `5500000` Cent = 55.000,00 €.

Terminregeln (`deadline_rules`): `15+2m` = 15. im zweiten Monat nach Ende des
Zeitraums (0 = Monatsletzter), `+1x` = zusätzlicher Monat bei
Dauerfristverlängerung, `02-15,…` = feste Tage, `+1j07-31` = Folgejahr,
`~` = ungefähr, ohne Verschiebung; `=` = genau, ohne Verschiebung auf den
nächsten Werktag (EU-Fristen, P-S72).

Abgaben (FA-19.x): `income_tax_<Jahr>` = `stufen:` Obergrenze in Cent=Satz in
Basispunkten (`none` = unbegrenzt) bzw. `formel:` Grundfreibetrag, Grenze Zone 2,
Faktor Zone 2 (Hundertstel), Grenze Zone 3, Faktor Zone 3, Konstante Zone 3
(Cent), Grenze Zone 4, Abzug Zone 4 und 5 (Cent) nach § 32a Abs 1 EStG;
`profit_allowance` = Satz (bp); Höchstgewinn (Cent); `social_insurance` = PV;
KV; Selbständigenvorsorge (bp); UV je Monat; Mindest- und Höchstbeitragsgrundlage
je Jahr; KU-Ausnahme Umsatz- und Einkünftegrenze (Cent); Jahre vorläufiger
Beitragsgrundlage; `surcharges` = Soli (bp); Freigrenze (Cent); Milderung (bp);
Kirchensteuer Standard (bp); je Land; `trade_tax` = Freibetrag (Cent);
Messzahl (bp); Hebesatz-Vorschlag (%); Anrechnungsfaktor (Promille).

Bewirtung (`entertainment`, FA-2.60): abziehbarer Anteil in Promille;
Vorsteuer `voll`; Anlass/Teilnehmer abfragen `ja`/`nein`; Fundstelle
Ertragsteuer; Fundstelle Vorsteuer.

Regelstand (`rules_as_of`, `rules_valid_until`, FA-21.1): Stichtag und letzter
Gültigkeitstag der eingebauten Werte; Pflege nach `docs/REGELPFLEGE.md`.

Gemischte Nutzung (`mixed_use`, FA-20.3): Mindestanteil betrieblich für den
Vorsteuerabzug in Promille; Fundstelle Privatanteil; Fundstelle Vorsteuer.

---

## 13. Änderungshistorie

| Version | Datum | App-Version | Änderung |
|---|---|---|---|
| 1.98 | 2026-10-20 | 0.37.0 | App-Version 0.37.0. FA-9.6 neu: Kopf der Beleg- und Rechnungsliste scrollt mit. Prüfinstanz UX (quer mehr Platz, Filter mit einem Wisch nach oben wieder erreichbar). |
| 1.97 | 2026-10-20 | 0.36.0 | App-Version 0.36.0. FA-9.4 Grundsatz „nicht volle Breite = zentriert“. FA-9.1: Telefon quer (Höhe < 480 dp) höchstens medium, kein Dreispalten-Layout; Kennwert `spec.window_compact_max_height_dp` (12). Vertrag ablegen: „Scannen“ und „Galerie“ gleich breit, darunter „Text erkennen“ volle Breite. Prüfinstanzen: UX (Daumenreichweite quer, 48 dp), Softwareentwickler (Material-3-Höhenklasse). |
| 1.96 | 2026-10-20 | 0.35.0 | App-Version 0.35.0; Versionsanzeige mit Buildnummer am Ende der Einstellungen und in Support-Mails (FA-11.8). FA-7.2 Zahlencode 8 Ziffern statt Kennwort; FA-7.10 ohne Abtippen von Blöcken; FA-13.10 Release-Builds nur mit Eingabe `abo` mit Lizenzprüfung; P-D58. Tastatur schließt bei Tippen neben ein Eingabefeld (alle Bildschirme, iOS-Ziffernblock ohne Fertig-Taste, Abschnitt 7). FA-1.8: Umsatz des laufenden Jahres vor Erfassungsbeginn optional (leer = 0, Hinweis zum Nachbuchen); FA-1.13: Willkommensseite Titel über dem Logo, mehr Abstand vor den Funktionszeilen. Prüfinstanzen: UX (weniger Pflichtfelder, passt auf 360 × 740), Steuerberater (Grenze stimmt erst nach Nachbuchen, Hinweis genügt), Softwareentwickler (kein Schemawechsel). |
| 1.95 | 2026-10-20 | 0.34.0 | Entscheidungen Auftraggeber 2026-10-20: Buchungsregeln Pro entschieden (O-47); Regelstand je Land (neu 5.17, FA-21.1 bis FA-21.3), Aktualisieren-Hinweis auf der Übersicht, Kennzeichnung „Werte von <Jahr> – Schätzung unsicher“; neue Pflegedatei `REGELPFLEGE.md`. Kenndaten neu `spec.*.rules_as_of`, `spec.*.rules_valid_until` (12). Prüfpunkte P-D57, P-X30 (14). Kein Schemawechsel. |
| 1.94 | 2026-10-20 | 0.34.0 | App-Version 0.34.0 (Testbuild). Buchungsregeln (Entscheidung Auftraggeber 2026-10-20, Lastenheft 14a): neuer Abschnitt 5.16 FA-20.1 bis FA-20.8, GR-17 (3), Schema 31 mit `booking_rules`, `booking_rule_attachments`, `booking_rule_log`, `booking_rule_exclusions` (4.1), Wirkung auf Gewinn und Vorsteuer (`PeriodTotals.rulePrivatePart`, `ruleInputVatRemoved`, `ruleVatAsExpense`), Karte an der Buchung mit Ausnahme, Abschnitt „Buchungsregeln und Angaben für die Steuerberatung“ in Saldenliste/Jahresabschluss und Paket (8.8), Bildschirme (7), Hilfeartikel mit „Regel anlegen“, Demo-Musterregeln (`spec.demo_receipt_count` 30, `spec.demo_de_receipt_count` 17); Tarif Pro (O-47); KI-Chat als Lastenheft Stufe C beschrieben, nicht gebaut (FA-20.8). Kenndaten `spec.schema_version` 31, neu `spec.*.mixed_use` (12). Prüfpunkte P-S88 bis P-S90, P-R65, P-R66, P-X29, interne Prüfung 2026-10-20 Buchungsregeln (14). Prüfmappen neu erzeugt. |
| 1.93 | 2026-10-19 | 0.33.0 | Endgültiges Logo (Lastenheft 14a): FA-1.13 Willkommensseite mit Hauptlogo hell/dunkel; App-Symbol (Android klassisch, adaptiv, Android-13-Monochrom; iOS-Satz; Startbildschirm Hellblau bzw. Marineblau im Dunkelmodus) aus Vektor-Rekonstruktion; Farbschema Seed Marineblau #0B3A67, Primärfarbe hell exakt Marineblau, Container Hellblau #EAF2FF. P-R63 um den neuen Werbetext ohne „statt“-Preis ergänzt. Prüfinstanzen: UX (Logo 280 dp, Dunkelmodus helle Linien statt Karte, passt auf 360 × 740 ohne Scrollen), Softwareentwickler (Symbolgrößen, sichere Zone, iOS 1024 ohne Alpha), Rechtsanwalt (Werbetext ohne Vergleichspreis, Nutzungsrechte Logo), Steuerberater (nicht betroffen). Kein Schemawechsel. |
| 1.92 | 2026-10-19 | 0.32.0 | Entscheidungen Auftraggeber 2026-10-19 (Lastenheft 14a): O-44 E-Rechnung ausstellen ab Basis (FA-13.2, Zustellung in Basis über Teilen-Blatt, Senden mit einem Tipp bleibt Pro); O-45 Apple Variante A plus Codes (14 Tage gratis auf iOS, Preis erstes Jahr nur per Angebotscode `JENIBUCHTSTART`), O-46 Pro-Code `JENIBUCHT20PRO` parallel (FA-13.16, Kenndatum `spec.license_promo_code_discount_pro`). Prüfinstanzen: Steuerberater (Pflicht § 27 Abs. 38 UStG, ohne Befund), Rechtsanwalt (Preisangabe iOS ohne Jahrespreis, P-R62/P-R63 bleiben), Softwareentwickler (Store-Mechanik, ohne Befund), UX (keine neue Bedienung). Kein Schemawechsel. |
| 1.91 | 2026-10-19 | 0.32.0 | App-Version 0.32.0 (Testbuild). E-Rechnung erstellen (Entscheidung Auftraggeber 2026-10-19, L-4.1, L-4.2): ZUGFeRD-PDF (PDF/A-3b mit `factur-x.xml`, EN 16931) als Standard, XRechnung 3.0 (CII) und ebInterface 6.1 für Behörden mit „XML senden“ (FA-5.49), Kundenfelder Leitweg-ID/Auftragsreferenz, Lieferantennummer, Format (Schema 30, 4.1, 4.2, 7), Tarif `eInvoiceIssue` Pro mit Vorschlag Basis (FA-13.2, O-44), Grenze „E-Rechnung nur im Empfang“ ersetzt durch „Grenzen beim Ausstellen“ (11); Willkommensseite „Rechnungen & E-Rechnungen schreiben“ (FA-1.13); Kenndaten `spec.schema_version` 30, `spec.einvoice_*` (12); Prüfpunkte P-S86, P-S87, P-R64, P-D56, P-X28, interne Prüfung 2026-10-19 E-Rechnung (14). |
| 1.90 | 2026-10-19 | 0.31.0 | FA-13.16 Preise aus Store-Phasen (Einführungspreis erstes Jahr, Grundpreis ab dem zweiten Jahr, Test), Abo-Seite baut den Text aus `pricingPhases` bzw. `introductoryPrice`; zweiter Instagram-Code `JENIBUCHT20` (20 % aufs Jahresabo im ersten Jahr), Kenndaten `spec.license_promo_code_discount`, `spec.license_promo_discount_percent`. Neue Prüfpunkte P-R62, P-R63, P-D55. Prüfinstanzen: Rechtsanwalt (PAngV, UWG, § 312j BGB, Werbetext), Softwareentwickler (Store-Möglichkeiten ohne Server, Apple ein Einführungsangebot je Gruppe), UX (keine neue Bedienung, Text unter dem Preis). Kein Schemawechsel. |
| 1.89 | 2026-10-19 | 0.31.0 | App-Version 0.31.0 (Testbuild). Rückmeldung Auftraggeber zu 0.30.0: Willkommensseite – Unterzeile mit Punkt statt Gedankenstrich, Titel größer, Abstände größer, Funktionszeilen einzeilig auf 360 dp, „Sicherung wiederherstellen“ ohne Vorsatz, Mithelfer-Koppeln als Nebenoption in Schritt 2 (FA-1.13, FA-17.2, FA-17.13); PDF-Betrachter mit weißem Papier auch im dunklen Modus (FA-5.48); Aufnahmeleiste der Übersicht weicht beim Scrollen aus (FA-12.1, 7); Grenzwertampel je Land mit DE-Vorjahresgrenze 25.000 € und Grenzenhinweis (FA-4.14); Demo mit Landeswahl und deutscher Musterfirma (FA-13.14, 7); Kenndaten `spec.demo_de_company`, `spec.demo_de_receipt_count`, `spec.capture_bar_show_after_s` (12); Prüfpunkte P-X27, P-S85, P-R61, interne Prüfung 2026-10-19 Rückmeldung 0.30.0 (14). Kein Schemawechsel. |
| 1.88 | 2026-10-19 | 0.30.0 | App-Version 0.30.0 (Testbuild). Entscheidungen Auftraggeber 2026-10-19: „Abgaben & Rücklagen“ nur Pro (O-43, `Feature.levyReserve`, FA-13.2, 5.15, FA-19.1); PDF-Betrachter mit Paket `printing` (neu FA-5.48: wischen, Pinch-Zoom, Seitenanzeige, Schließen/Drucken/Senden 56 dp, Demo gesperrt) als erster Schritt jedes erzeugten PDF und für PDF-Anhänge; FA-13.11 Drucken frei; FA-5.46; Grenze „Demo ohne PDF-Vorschau“ erledigt (11); Willkommensseite mit Unterzeile und vier Funktionszeilen (FA-1.13); RZL-Export zurückgestellt (P-D52 bleibt). Prüfpunkte P-X26, P-D54, P-R60, interne Prüfung 2026-10-19 PDF-Betrachter (14). Kein Schemawechsel, keine neuen Kenndaten. |
| 1.87 | 2026-10-19 | 0.29.0 | App-Version 0.29.0 (Testbuild). Abgaben & Rücklagen (Auftrag Auftraggeber 2026-10-19, Lastenheft 5.31, 14a): neuer Abschnitt 5.15 FA-19.1 bis FA-19.6, `TaxProfile.levies` (AT Stufentarif 2025/2026, Grundfreibetrag, GSVG; DE § 32a 2025/2026, Soli, KiSt, GewSt mit § 35), Schätzung `LevyEstimator`, Karte auf der Übersicht, Bildschirm „Abgaben & Rücklagen“ (7), Einstieg in „Für das Finanzamt“; Schema 29 `levy_settings` und Abgabenkategorien (4.1, 4.2), Hinzurechnung nicht abziehbarer Abgaben in der E/A (FA-19.4); Paket „Für Kapitalgesellschaft / doppelte Buchführung“ mit Belegkopien (FA-15.12, 8.8); Grenze „Abgaben nur geschätzt“ (11); Kenndaten `spec.schema_version` 29, `spec.seed_category_count` 21, `spec.seed_category_expense_count` 18, `spec.demo_receipt_count` 28, neu `spec.*.income_tax_<Jahr>`, `profit_allowance`, `social_insurance`, `social_insurance_business_expense`, `surcharges`, `trade_tax` (12). Prüfpunkte P-S78 bis P-S84, P-R59, P-D50 bis P-D53, P-X25, interne Prüfung 2026-10-19 Abgaben (14). Prüfmappen neu erzeugt. Demo: SVS-Quartalsbeiträge, ESt-Vorauszahlung, Rücklagenkarte. |
| 1.86 | 2026-10-19 | 0.28.0 | App-Version 0.28.0 (Testbuild). Rückmeldung Auftraggeber 2026-10-19 (Lastenheft 14a): geführte Ersteinrichtung mit Willkommensseite und fünf Schritten, Fortsetzen nach dem Schließen (FA-1.13, FA-1.1); Bestätigungen mit einem Häkchen und „Akzeptieren und weiter“ (FA-1.10); Startauswahl ersetzt durch Willkommensseite und Schritt 5 (FA-13.15); EU-KU-Nummer (EX) im Profil, Formular und auf der Rechnung (FA-18.10, FA-18.1), Schema 28 `company_profile.eu_sme_id` (4.1, 4.2); Belegfeld „Produkt oder Leistung“, Exportspalte bleibt (FA-2.5, 8.2); Hilfe zum Mithelfer-Gerät und „Als Mithelfer-Gerät koppeln“ in den Einstellungen (FA-17.13); Bildschirme (7); Grenze „EU-KU-Nummer nur offline geprüft“ (11); Kenndaten `spec.schema_version` 28, `spec.setup_steps`, `spec.eu_sme_id_suffix` (12); Prüfpunkte P-R58, P-S76, P-S77, P-X24, P-D49, interne Prüfung (14). Nachtrag: Demo als Kleinunternehmerin AT mit Ampel ≈ 27 %, Leasing- und Dienstvertrag, Listen laden in der Demo neu (FA-13.14); Vertragsarchiv über „Belege | Verträge“ und Einstellungen, Dienstvertrag mit Datenschutzhinweis (FA-16.9). |
| 1.85 | 2026-10-19 | 0.27.0 | App-Version 0.27.0 (Testbuild). Entscheidungen Auftraggeber 2026-10-19 (O-42, ersetzt O-35; Lastenheft 14a): Test 14 Tage auf allen vier Produkten, Basis in der Testzeit mit allen Pro-Funktionen (FA-13.4 neu gefasst, `LicensePolicy.proIncludedUntil`, `StoreBilling.trialInfo`, iOS `offerType`, Android Zeitfenster), Abo-Seite und Hinweise neu formuliert (FA-13.5, FA-13.8), `Entitlement.demo` und `Feature.dataExport` (FA-13.1, FA-13.2); Demo ohne Abo mit eigener schreibgeschützter Muster-Datenbank, Wasserzeichen „MUSTER – DEMO“, Teilen/Export/Sicherung gesperrt (FA-13.14), Startauswahl (FA-13.15), Bildschirme (7), Grenzen (11), Kenndaten `spec.demo_company`, `spec.demo_receipt_count`, `spec.demo_watermark` (12), Prüfpunkte P-R55 bis P-R57, P-S75, P-D46 bis P-D48, P-X23, interne Prüfung 2026-10-19 (14). Onboarding: Rechtsform-Auswahl bricht auf 360 dp um statt überzulaufen. Kein Schemawechsel. |
| 1.84 | 2026-10-19 | 0.26.0 | App-Version 0.26.0 (Testbuild): Bundle-ID/applicationId gewechselt auf `at.jenibarb.jenibucht` (Lastenheft O-33, Freigabe 2026-10-19): Android `applicationId`/`namespace`, Kotlin-Paket, iOS `PRODUCT_BUNDLE_IDENTIFIER` (Runner, RunnerTests), iCloud-Container folgt (`iCloud.at.jenibarb.jenibucht`, P-B13), Dateityp `at.jenibarb.jenibucht.jenibeleg` mit alter Kennung als importiertem Typ (FA-17.4), Hintergrundaufgabe `at.jenibarb.jenibucht.mailsync` (FA-17.12), Play-Paketname in `release.yml`; P-D6 präzisiert. Kanalnamen `buchhaltung/*` unverändert. Keine Kennwertänderung. |
| 1.83 | 2026-10-18 | 0.25.0 | Entscheidungen der Auftraggeberin 2026-10-18 (Lastenheft 14a): Verbringen ins Auslandslager nicht in der App, Rechnungen immer Heimat, Auslandsregistrierung nur für die UID. FA-18.4 Warnhinweis „Verbringen nicht enthalten“ (`TaxProfile.warehouseTransferHint`, DE Kz 89/61, AT Kz 070/072/065); FA-18.6 OSS und EU-KU-Meldung ohne Verschiebung auf den Werktag (`DeadlineRule.shiftsToWorkday`, Kenndaten `=`, 12); Grenze 11 präzisiert. Interne Prüfung Steuerberater und Rechtsanwalt: P-S68 bis P-S74 und P-R5 intern geprüft, P-R4 bleibt offen – extern (14, neue Ergebnistabelle 2026-10-18). Prüfmappen neu erzeugt. Länderanalyse für die nächste Ausbaustufe (`docs/LAENDERANALYSE.md`, Lastenheft O-41). |
| 1.82 | 2026-10-18 | 0.25.0 | App-Version 0.25.0 (Testbuild). Steuerliche Registrierungen in mehreren Ländern (Auftrag Auftraggeber 2026-10-18, Lastenheft 5.30): GR-16 neu (3); Schema 27 `tax_registrations`, `receipts.tax_registration_id`, `company_profile.oss_participant` (4.1, 4.2); 5.14 FA-18.1 bis FA-18.9; 5.6a Verweis; Bildschirm „Steuerliche Registrierungen“ und Steuerland-Chips in „Für das Finanzamt“ (7); Grenze „Mehrere Steuerländer: erste Stufe“ (11); Kenndaten `spec.schema_version` 27, `spec.*.deadline_rules` um OSS und EU-KU-Meldung, neu `spec.*.registration_deadline_rules`, `spec.*.foreign_tax_offices` (12). Neue Prüfpunkte P-S68 bis P-S74, P-X22, P-D45. Prüfinstanzen: Steuerberater (JeNiBarb: FBA-Lager in DE → DE-Registrierung und DE-Regelbesteuerung für Verkäufe ab DE-Lager, Verbringen als ig. Erwerb Kz 89/61, deutsches § 19 nur für Inländer, EU-KU-Verfahren nur unter Bedingungen; AT-KU ohne U30 außer RC; Ertragsteuer nur AT; Finanzamt München; P-S68 bis P-S74), Rechtsanwalt (keine neue Übertragung, Finanzamt nur Vorschlag; P-R5 unverändert), Softwareentwickler (Migration neu, `RegistrationScope` statt Länder-ifs, Fremdschlüssel mit Löschsperre, Datensicherung über alle Tabellen), UX (Chips nur ab zwei Registrierungen, Heimat vorgewählt, Land hinzufügen und Länderzeilen 56 dp, Gefahrenzone am Formularende, ein Tipp zum Wechseln). |
| 1.81 | 2026-10-17 | 0.24.0 | App-Version 0.24.0 (Testbuild). Belegsammler per E-Mail als Standardweg (Entscheidungen Auftraggeberin 2026-10-17, Lastenheft 14a): FA-17.9 bis FA-17.12 neu, FA-17.1/17.3/17.4 angepasst; Sammelpaket Version 2 (8.9); Schema 26 `helper_mail_seen`, `helper_outbox.sent_at`/`package_path` (4.1); Bildschirme (7); Datenflüsse IMAP/SMTP/Serversuche und Berechtigungen (10.1, 10.2); Grenze „Mailweg ohne OAuth“ (11); Kenndaten `spec.schema_version` 26, `spec.helper_mail_poll_minutes`, `spec.helper_mail_send_hours`, `spec.helper_mail_retention_days` (12). Neue Prüfpunkte P-R47, P-R48, P-D44, P-X21, P-S67. Prüfinstanzen: Rechtsanwalt (eigenes Postfach des Beschäftigten mit einmaliger Einwilligung, Inhaberin Verantwortliche, Mailanbieter nur Chiffrat, Store-Angaben „nicht erhoben“ bleibt, ISPDB-Abruf offenlegen; P-R47, P-R48), Steuerberater (Belege bleiben Vorschläge, verschlüsselte Kopie beim Mithelfer bis 90 Tage ersetzt keine Aufbewahrung; P-S67), Softwareentwickler (`enough_mail` wegen `xml`-Konflikt nicht nutzbar → eigenes IMAP/SMTP, nur lesende Befehle, TLS Pflicht, Kennwort im Keystore/Schlüsselbund, `workmanager` 0.10.10 und `flutter_local_notifications` 22.3.2 gepflegt, Desugaring nötig; Tests mit Ersatzserver), UX (E-Mail vorgewählt, Bottom-Sheet scrollbar statt Überlauf auf 360×740, Fehler oben sichtbar, alle Knöpfe ≥ 48 dp, Speichern unten 56 dp, ein Einrichtungsschritt je Gerät). |
| 1.80 | 2026-10-17 | 0.23.2 | App-Version 0.23.2 (Testbuild). Belegerkennung OMV-Beleg (FA-2.62): Rangfolge Kassen-QR > Steuertabelle mit mehreren Zeilen (auch 0 %) > Gesamtbetrag/Summe/Total > Rest; Zahlungszeilen nie Gesamtbetrag; gedruckte Netto/Steuer je Satz mit Toleranz übernommen; Codes auf jeder Seite, auch PDF-Seitenbilder und unverbessertes Scan-Original; Händler „OMV Tankstelle“ trotz OCR-Trennung; Tankstelle ohne Treibstoff nicht Kfz-Kosten. Korpus um den OMV-Beleg erweitert. Prüfinstanzen: Steuerberater (Pfand 0 % als eigener Satz, Vorsteuer nur aus 20 %-Teil; ohne Befund), Softwareentwickler (Rangfolge in Tests, Korpus-Regression), UX (kein zusätzlicher Schritt, weniger Korrekturen), Rechtsanwalt ohne Befund. Kein Schemawechsel. |
| 1.79 | 2026-10-17 | 0.23.1 | App-Version 0.23.1 (Testbuild). Belegsammler gemischt Android/iPhone (Entscheidung Auftraggeberin 2026-10-17, FA-17.4, 8.9): Paketformat plattformunabhängig mit Prüfmuster, iOS-Dateityp `.jenibeleg` (Öffnen in…), Android „Öffnen mit“ über eigenen MIME-Typ und Endung, Teilen-Blatt mit iPad-Anker, Ordnerhinweis für gemischte Familien; P-D42 auf beide Richtungen erweitert. UX: kein zusätzlicher Schritt, ein Umweg weniger auf dem iPhone; Rechtsanwalt/Steuerberater ohne Befund (keine neue Übertragung durch die App). Entscheidungen Auftraggeberin (Lastenheft 14a): Mithelfer-Geräte ohne eigenes Abo und ohne Gerätegrenze bestätigt (FA-17.x unverändert). Neue Startkategorie „Material und Werkzeug“ (SKR03 4985, SKR04 6845, BMD EKR 5300), Schema 25 ergänzt sie in bestehenden Datenbanken (4.1); Baumarkt-Belege schlagen sie vor (FA-2.31). `spec.schema_version` 25, `spec.seed_category_count` 18, `spec.seed_category_expense_count` 15 (12). Neuer Prüfpunkt P-S66. Prüfinstanzen: Steuerberater (Konto Werkzeuge/Kleingeräte, Material für Aufträge ggf. Wareneinsatz – Kanzlei, P-S66), Softwareentwickler (Migration neu, idempotent), UX (nur anderer Vorschlag, kein Schritt mehr), Rechtsanwalt ohne Befund. |
| 1.78 | 2026-10-17 | 0.23.0 | Mithelfer-Geräte / Belegsammler (5.13, FA-17.1 bis FA-17.8; Lastenheft 5.29): Schema 24 `helper_pairings`, `helper_inbox`, `helper_outbox`, `helper_settings` (4.1), Belegpaket `.jenibeleg` (8.9), Bildschirme (7), Datenfluss (10.1), Grenze (11), `spec.schema_version` 24 (12), Pro `helperDevices` (FA-13.2). Neue Prüfpunkte P-D42, P-R46, P-S65, P-X20. Prüfinstanzen: Rechtsanwalt (Inhaberin bleibt Verantwortliche, Übertragung nur über Wege der Nutzerin, Store-Angaben wie Teilen), Steuerberater (nur Vorschläge, Buchung auf dem Hauptgerät, Bild unverändert, Papierbeleg aufbewahren bis P-S65), Softwareentwickler (AES-256-GCM mit Kopf als AAD wie Datensicherung, Schlüssel 256 Bit, Dublettenschutz über UUID, Migration neu, Bilder erst nach Senden gelöscht), UX (Aufnahmeleiste unverändert, Senden/Gerät hinzufügen unten 56 dp, Ablehnen 48 dp, Standardweg ohne Einrichtung). |
| 1.77 | 2026-10-17 | 0.22.3 | FA-2.31 nach Gerätetest 0.22.2 (BAUHAUS-Bon): Beschreibung aus Artikelzeilen statt Händlername, sonst Branche, sonst leer; Lieferant bevorzugt Rechtsform und bekannte Ketten AT/DE (erweitert, OCR-Varianten), Artikelzeilen nie Lieferant. Kein Schemawechsel. |
| 1.76 | 2026-10-16 | 0.22.2 | App-Version 0.22.2 (Testbuild). FA-11.6 „Wunsch oder Idee senden“ (Lastenheft L-26.7): Formular in den Einstellungen, Versand über die Mail-App der Nutzerin, technische Angaben abschaltbar; Kanalmethode `deviceInfo`; Abschnitt 7; neuer Prüfpunkt P-R45. Prüfinstanzen: Rechtsanwalt (keine Übertragung durch die App, Inhalt vor dem Senden sichtbar, Anbieter Verantwortlicher für die E-Mail; Store-Wertung als P-R45), Softwareentwickler (vorhandener Kanal statt `url_launcher`, Adresse an einer Stelle, Tests mit Fake-Launcher), UX (Chips ≥ 48 dp, ein Tipp, nur ein Pflichtfeld, Senden unten volle Breite 56 dp, Fehlermeldung am Feld), Steuerberater ohne Befund. |
| 1.75 | 2026-10-16 | 0.22.1 | Gerätetest 0.22.0 (Pixel): nach dem Scan Formular leer, keine Seite. Ursache: Android-Request-Code 4711 doppelt (Scanner, Sicherungsordner), Ergebnis verschluckt, Rückfall nach `onResume` meldete still „abgebrochen“. FA-2.51: eindeutige Codes in `RequestCodes.kt`, Fehler `lost` statt stillem Abbruch, Meldung bei jedem Fehler, Original bei gescheiterter Nachbearbeitung. FA-12.1, Abschnitt 7 (Entscheidung Auftraggeberin): „Foto“ und „Datei“ als kleinere runde Knöpfe neben „Beleg“ auf Übersicht und Belegliste (DESIGN_SPEC 1.4 Regel 13). Neue Prüfpunkte P-X19, P-D41. Prüfinstanzen: Softwareentwickler (Ursache im Code belegt, Widget-Tests mit Fake-Scanner und echten JPEG-Bytes), UX (56 dp ≥ 48 dp, 48 dp Abstand, spiegelgleich, Hauptknopf größer und mittig, leeres Formular schließt sich bei Abbruch), Rechtsanwalt/Steuerberater ohne Befund (keine Datenübertragung, Bild aus Galerie/Datei unverändert). |
| 1.74 | 2026-10-16 | 0.22.0 | App-Version 0.22.0 (Testbuild). Diktat auf dem Gerät (FA-2.61) in Freitext- und Betragsfeldern, eigener Channel, kein Netz-Rückfall; Abschnitt 7; neue Prüfpunkte P-D40, P-X18, P-R44. Prüfinstanzen: Rechtsanwalt (keine Übertragung durch die App, Mikrofon nur auf Tippen, Berechtigungstexte; Systemdienst offenlegen, P-R44), Softwareentwickler (On-Device-APIs mit Verfügbarkeitsprüfung, Antwort-Lebenszyklus, Tests mit Fake-Channel, Zahlwort-Parser nur `int`), UX (Mikrofon 48 dp als Suffix, Abstand zu Löschen unverändert, Betrag nur Vorschlag, ein Tipp Start/Stopp). |
| 1.73 | 2026-10-16 | 0.22.0 | Aufnahmeknopf (Entscheidung Auftraggeberin): runder Knopf „Beleg“ ≥ 72 dp unten in der Mitte auf Übersicht, Belegliste und im Belegformular (FA-12.1, FA-12.7, Abschnitt 7; DESIGN_SPEC 1.3 Regel 13); neue Prüfpunkte P-X17, P-D39 (Scanner-Fix 0.21.1 auf echten Geräten). UX-Instanz: Kreis 76 dp, gleiche Stelle auf allen Belegbildschirmen, Speichern bleibt volle Breite darunter, Abstand zu Löschen (Formularende) unverändert, mit Tastatur ausgeblendet; Nebenaktion Galerie kleiner. |
| 1.72 | 2026-10-16 | 0.21.1 | Gerätetest 0.21.0 (Pixel): Scanner nach dem ersten Scan bis zum Neustart gesperrt, Vorbelegung blieb aus. FA-2.51 ergänzt: Antwort genau einmal, am Prozess statt an der Activity, Abbruch nach Rückkehr ohne Ergebnis, Dart-Sperre im `finally`; Scan-Seiten über denselben Weg in die Erkennung wie Kamerafotos; eigene Nachbearbeitung (`ScanEnhancer`) vor Speichern und Erkennung; Dateinamen im Belegspeicher mit Laufnummer (mehrere Seiten in derselben Millisekunde). Prüfinstanzen: Softwareentwickler (Ursachen, Tests mit Fake-Channel), Steuerberater (Nachbearbeitung im Rahmen des Vorbefunds zu P-S63: Kontrast, nichts entfernt), UX ohne Befund (keine neue Bedienung). |
| 1.71 | 2026-10-16 | 0.21.0 | App-Version 0.21.0 (Testbuild). Bewirtung mit Abzugsbeschränkung (FA-2.60, Entscheidung Auftraggeberin Lastenheft 14a): Kategorie „Bewirtung“, AT 50 %/DE 70 %, Vorsteuer voll (AT nach Prüfinstanz Steuerberater: § 12 Abs 2 Z 2 lit a UStG 1994, UStR Rz 1934, mittel), Hinzurechnung in Übersicht, Kennzahlen, Saldenliste, Jahresabschluss, CSV, DATEV; Anlass/Teilnehmer (DE). Schema 23, 17 Startkategorien, neue Kenndaten `spec.*.entertainment`; Grenze in 11 ersetzt; P-S46 neu gefasst, P-X16 neu. UX-Instanz: Felder im bestehenden Formular, volle Breite, kein Pflichtfeld, kein zusätzlicher Schritt. |
| 1.70 | 2026-10-16 | 0.20.0 | Entscheidungen Auftraggeberin (Lastenheft 14a): Anlagen anlegen, ändern, ausscheiden nur Pro (`Feature.assetManagement`, FA-13.2, FA-15.1, FA-15.8); bestehende Anlagen, Verzeichnis und AfA in jedem Anspruch; GWG-Hinweis am Beleg ohne Pro. Vertragsarchiv ab Basis, Kurzübersicht Pro bestätigt. Neue Prüfpunkte P-S64, P-R43. Prüfinstanzen: Steuerberater (Gewinn ohne Aktivierung zu niedrig, P-S64), Rechtsanwalt (Konflikt mit Regel 5.10, P-R43), Softwareentwickler (Prüfung über `Depreciation.exceedsGwg`, AfA ohne Tarifabfrage), UX (eine Zeile ≥ 48 dp, „(Pro)“ wie überall, kein zusätzlicher Dialog). |
| 1.69 | 2026-10-16 | 0.20.0 | Interne Prüfung aller offenen Steuer- und Rechtspunkte in 14 durch die Prüfinstanzen Steuerberater und Rechtsanwalt (Auftrag Auftraggeberin): neuer Status *intern geprüft* (Definition in 14), 52 Punkte mit Ergebnis, Quellen und Sicherheit in „Ergebnisse der internen Prüfung“; Prüfmappen enthalten nur noch *offene* Punkte, intern geprüfte im Anhang. Fund P-S44: DE-Basiszinssatz 1,52 % ab 1.7.2026 ergänzt (Kenndaten `spec.de.dunning_base_rates`). Softwareentwickler: Test für das zweite Halbjahr 2026; UX ohne Befund (keine Oberflächenänderung). |
| 1.68 | 2026-10-16 | 0.20.0 | Dokumentenscanner des Systems für Belege und Verträge (FA-2.51): ML Kit Document Scanner (Android), VisionKit (iOS), eigener Channel, Rückfall auf die Kamera ohne Rückfrage, nur verarbeitetes Bild gespeichert; 10.1, 10.2, Grenze 11; Kenndaten `spec.scanner_page_limit`. Neue Prüfpunkte P-S63, P-R42, P-D37, P-D38, P-X15. Prüfinstanzen: Steuerberater (bildliche Übereinstimmung entzerrter Scans als Prüfpunkt), Rechtsanwalt (Play-Dienste-Telemetrie offenlegen), Softwareentwickler (eigener Channel statt Plugin, R8-Regel, kein neues Swift-File im Projekt), UX (Scanner-UI vom System, ein Tipp weniger: Zuschneiden entfällt). |
| 1.67 | 2026-10-16 | 0.19.0 | Vertragsarchiv lokal (5.12, FA-16.1 bis FA-16.8): Schema 22 `contracts`, `contract_pages`, `contract_receipts` (4.1), Seiten wie Belege, Kurzübersicht mit Fundstelle (Pro `contractSummary`, FA-13.2), Fristen in der Termin-Box, Abgleich und Buchungsvorschlag, Aufbewahrung und Löschwarnung, `vertraege.csv`; Bildschirm (7), 10.1, Grenze 11; Kenndaten `spec.contract_match_tolerance_days`, `spec.schema_version` 22. Neue Prüfpunkte P-R41, P-S62, P-X14, P-D36. Prüfinstanzen: Rechtsanwalt (nur Auszug mit Fundstelle, keine Bewertung, L-23.6), Steuerberater (Aufbewahrung über `retentionYears`, Leasing als Ausgabe), Softwareentwickler (keine Datenübertragung, Seiten im vorhandenen Speicher, Migration neu), UX (Speichern unten 56 dp, Teilen ohne Rückfrage, Vertrag mit einem Tipp). |
| 1.66 | 2026-10-16 | 0.18.0 | Anlagen, AfA und Berichte (GR-15, 5.11 FA-15.1 bis FA-15.11): Schema 21 `fixed_assets` (4.1), AfA-Plan ganzzahlig mit exakter Summe, GWG, Sammelposten DE, Ausscheiden mit Pflichtkommentar und Verkaufserlös, Gewinn mit AfA statt Anschaffung (FA-15.5), Anlagenverzeichnis (jedes Abo), Saldenliste und vorläufiger Jahresabschluss als PDF/ZIP (Pro `annualReports`, FA-13.2), Bildschirme (7), PDF-Format 8.8, Datenfluss 10.1, Grenze 11. Kenndaten `spec.*.depreciation`, `spec.schema_version` 21. Neue Prüfpunkte P-S59, P-S60, P-S61, P-X13. Prüfinstanzen: Steuerberater (Werte mit Fundstellen, unsichere als P-S59/P-S60), Softwareentwickler (Migration neu, Plan berechnet statt gespeichert), Rechtsanwalt (Kennzeichnung VORLÄUFIG, keine Beratung), UX (Speichern unten 56 dp, Auswahlzeilen ≥ 48 dp, Pflichtkommentar nur beim Ausscheiden und bei abweichender Nutzungsdauer). |
| 1.65 | 2026-10-16 | 0.17.0 | Meldungen ans Finanzamt (5.10, FA-14.1 bis FA-14.8): Kennzahlen UVA/UStVA und E1a/Anlage EÜR zum Kopieren, U30-Datei für FinanzOnline (8.7, Pro), Bildschirm „Für das Finanzamt“ (7), Datenfluss 10.1, Grenze in 11, FA-13.2 angepasst. Kenndaten `spec.*.vat_return_kz`, `spec.*.annual_return_kz`, `spec.u30_schema_version`. Neue Prüfpunkte P-S57, P-S58, P-D35, P-X12, P-R5 präzisiert. Prüfinstanzen: Steuerberater (Kennzahlen aus BMF-XSD 07_2026 und Formularwissen, Kleinunternehmer ohne UVA außer Reverse Charge), Softwareentwickler (XML gegen XSD validiert; Webservice und ERiC zurückgestellt), Rechtsanwalt (Werkzeug, Abgabe durch die Nutzerin, keine Daten an Dritte durch die App), UX (Zeilen 56 dp, Knopf unten 56 dp, Kopieren mit einem Tipp). |
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

Status (seit 2026-10-16):

- *offen* – noch von einer echten Fachperson, einem Amt oder auf einem echten
  Gerät zu prüfen (*offen – extern*). Nur diese Punkte stehen in den Prüfmappen.
- *intern geprüft* (mit Datum und Sicherheit hoch/mittel) – die Prüfinstanz hat
  den Punkt selbstständig mit Gesetz, Verwaltungsanweisung oder Rechtsprechung
  beantwortet; Ergebnis und Quellen stehen unten in „Ergebnisse der internen
  Prüfung“. Keine Bestätigung durch eine Fachperson; die Prüfmappen listen
  diese Punkte im Anhang zur Stichprobe.
- *extern bestätigt* bzw. *bestätigt* (mit Datum und Prüferin) · *widerlegt*
  (mit Folge) · *erledigt*.
- Entscheidungen der Auftraggeberin bleiben als solche gekennzeichnet und sind
  kein Prüfstatus.

**Prüfmappen in `docs/pruefmappen/`:** `Pruefmappe_Steuerberater.pdf` und
`Pruefmappe_Rechtsanwalt.pdf` bündeln die Punkte dieses Abschnitts mit Status
*offen* nach Themen mit Antwortfeld und Bitte um Fixpreisangebot; *intern
geprüfte* Punkte stehen dort nur im Anhang (Kurzergebnis und Quelle zur
Stichprobe). Die Generatoren
(`pruefmappe_*.py`) lesen die Tabellen hier bei jedem Lauf neu; Beispielrechnungen
erzeugt `beispiele_erzeugen_test.dart` mit dem PDF-Generator der App.

### Rechtsanwältin / Rechtsanwalt

| ID | Prüfpunkt | Vorbefund der Prüfinstanz | Benötigt vor | Status |
|---|---|---|---|---|
| P-R1 | Impressum und Offenlegung für Produktseite und App | § 5 ECG und § 25 Abs 5 MedienG (AT, „kleine Website"); § 5 DDG greift über das Herkunftslandprinzip nur mittelbar; Verbraucherschlichtungshinweis prüfen; ODR-Link entfallen seit 07/2025 | Produktseite | intern geprüft 2026-10-16 (mittel) |
| P-R2 | Rabatt- und Streichpreiswerbung für Store-Abos | 30-Tage-Regel (§ 11 PAngV, § 9a PrAG) für Dienstleistungen streitig; Irreführungsverbot gilt immer; ohne vorher verlangten Listenpreis nur „Einführungspreis bis …" | erste Werbung | intern geprüft 2026-10-16 (mittel) |
| P-R3 | BFSG (DE) / BaFG (AT) | voraussichtlich nicht anwendbar (B2B, Kleinstunternehmen); Unternehmensgröße bestätigen | vor Stufe B | intern geprüft 2026-10-16 (mittel) |
| P-R4 | Tragweite der Bestätigung „keine Steuerberatung" und Haftungsbegrenzung in den AGB | begrenzt wirksam; Vorsatz, grobe Fahrlässigkeit, Personenschäden nicht ausschließbar | Release | offen |
| P-R5 | Abgrenzung zur Hilfeleistung in Steuersachen (StBerG, WTBG) bei UVA-Übermittlung und ESt-Vorbereitung; seit 0.17.0 Kennzahlen und U30-Datei (FA-14.x), Abgabe durch die Nutzerin selbst; vor Webservice-Übermittlung (Zugangsdaten der Nutzerin im Gerät) erneut prüfen | zulässig als Werkzeug, Übermittlung nur im Namen und mit Zugang der Nutzerin; keine Einzelfallempfehlung | Stufe B | intern geprüft 2026-10-18 (mittel); vor Webservice-Übermittlung (Stufe B) erneut *offen – extern* |
| P-R6 | DSGVO: Datenschutzerklärung, Verzeichnis, TOM, Datenpannenprozess; ab Stufe C AVV und Unterauftragsverarbeiter | Rollen laut Lastenheft L-19 im Kern richtig, um Anbieter- und Store-Daten ergänzt | Release / Stufe C | offen |
| P-R7 | Markenrecherche „JeNi bucht" (TMview, Klassen 9, 35, 36, 42) | Recherche der Auftraggeberin ohne Befund (2026-10-15); Name festgelegt | Store-Eintrag | erledigt 2026-10-15 |
| P-R8 | Rechtsform, Haftung, Versicherung des Anbieters | Einzelunternehmen haftet persönlich | Release | offen |
| P-R9 | AI Act Art. 50 (Kennzeichnung KI-Inhalte) und Urheberrecht im Marketing-Modul; Produkthaftungsrichtlinie (EU) 2024/2853 | Pflichten wahrscheinlich | Stufe C | intern geprüft 2026-10-16 (mittel) |

### Steuerberaterin / Steuerberater

| ID | Prüfpunkt | Vorbefund der Prüfinstanz | Benötigt vor | Status |
|---|---|---|---|---|
| P-S1 | AT Kleinunternehmer: (a) brutto oder netto? (b) Gilt die Toleranz **unbeschränkt oder nur einmal in 5 Jahren?** (c) Welche Umsätze zählen nicht (Hilfsgeschäfte, bestimmte steuerfreie Umsätze)? | (a) **bestätigt vom Auftraggeber am 2026-10-10: brutto** — ohne Steuerausweis gleich netto, ausgewiesene Umsatzsteuer zählt mit; umgesetzt (FA-4.1). (b) **entschieden vom Auftraggeber am 2026-10-10:** App rechnet mit der harten Grenze, Toleranz nur als Warnung mit Verweis an die Steuerberatung (FA-4.4); damit für die App ohne Bedeutung. (c) App zählt alle Einnahmen | **sofort** (c) | intern geprüft 2026-10-16 (hoch) |
| P-S2 | DE Gründungsjahr: Grenze 25.000 € statt 100.000 € im laufenden Jahr | seit Spezifikation 1.11 im Code (FA-4.13, Schema 3) | Release | intern geprüft 2026-10-16 (hoch) |
| P-S3 | DE Zuordnung des Umsatzes nach Zahlungseingang statt Belegdatum | Abweichung möglich über den Jahreswechsel | Stufe B | intern geprüft 2026-10-16 (mittel) |
| P-S4 | AT ermäßigter Satz 4,9 % für Grundnahrungsmittel ab 1.7.2026 | angekündigt, Beschluss unbekannt; nicht im Code | sofort | intern geprüft 2026-10-16 (hoch) |
| P-S5 | DE Aufbewahrung: 8 Jahre Belege, 10 Jahre Bücher; AT 7 Jahre, 22 Jahre Grundstücke | Code führt nur eine Frist je Land; Löschung findet nicht statt | vor Löschfunktion | intern geprüft 2026-10-16 (hoch) |
| P-S6 | AT E-Rechnung B2B | keine nationale Pflicht bekannt | Stufe B | intern geprüft 2026-10-16 (hoch) |
| P-S7 | UVA-Schwellen und Befreiungen AT/DE, DE-Neugründerregel ab 2027 | AT-Befreiungsgrenze ab 2025 unsicher | Stufe B | offen |
| P-S8 | Rechnungshinweis DE Kleinunternehmer | „Steuerbefreiung nach § 19 UStG (Kleinunternehmer)" empfohlen; seit Spezifikation 1.5 im Code | Release | intern geprüft 2026-10-16 (hoch) |
| P-S9 | AT Rechnung über 10.000 € brutto braucht UID des Empfängers | Prüfung im Formular fehlt | Release | intern geprüft 2026-10-16 (hoch) |
| P-S10 | GoBD/BAO: Unveränderbarkeit, Verfahrensdokumentation, RKSV-Abgrenzung bei Bareinnahmen | Belege werden seit Spezifikation 1.11 storniert statt gelöscht (FA-2.11); Unveränderbarkeit des `audit_log` und Verfahrensdokumentation offen | Release | offen |
| P-S68 | **Spirits by JeNiBarb e.U. (AT-Kleinunternehmer, Amazon FBA mit Lager in DE):** (a) DE-Registrierung Pflicht ab erster Einlagerung? (b) Verkäufe ab DE-Lager an DE-Kunden in DE steuerbar (§ 3 Abs 6 UStG) und **regelbesteuert** (19 % Spirituosen), monatliche UStVA in den ersten zwei Jahren (§ 18 Abs 2 S 4 UStG)? (c) Verbringen AT→DE: in DE ig. Erwerb (§ 1a Abs 2 UStG, Kz 89, Vorsteuer Kz 61), in AT ig. Lieferung (Art 3 Abs 1 Z 1 BMR) – greift für den AT-Kleinunternehmer die Befreiung § 6 Abs 1 Z 27 UStG vor Art 6 Abs 1 BMR, ZM nötig? (d) Gebühren Amazon EU (LU) bleiben RC in AT (Sitz) | Vorbefund Steuerberater 2026-10-18: (a) ja, (b) ja, Regelbesteuerung, da § 19 UStG nur im Inland ansässigen Unternehmern offensteht (§ 19 Abs 1 UStG idF JStG 2024); (c) DE-Seite gesichert, AT-Seite unsicher (mittel), App bucht Verbringen nicht (O-40); (d) ja (§ 3a Abs 6 UStG 1994). Sicherheit: (a)(b)(d) hoch, (c) mittel. Quellen: §§ 1a, 3 Abs 6, 18, 19 UStG; Art 3, 6, 7 BMR; § 6 Abs 1 Z 27 UStG 1994; UStAE 1a.2 | Release | intern geprüft 2026-10-18 (hoch; (c) mittel) |
| P-S69 | **EU-Kleinunternehmer-Verfahren statt DE-Registrierung** (seit 1.1.2025): Voraussetzungen (EU-Jahresumsatz ≤ 100.000 €, DE-Grenzen 25.000/100.000 €, Teilnahme über FinanzOnline mit EX-Kennung), vereinbar mit FBA-Lager und Verbringen? Meldefrist vierteljährlich einen Monat nach Quartalsende (Art 284d MwStSystRL) im Heimatland; Fundstellen AT/DE (§ 6 Abs 1 Z 27 UStG 1994 idF AbgÄG 2024, §§ 19, 19a UStG) | Vorbefund: grundsätzlich möglich, aber bei Lagerung in DE wegen ig. Erwerb aus Verbringen praktisch kaum nutzbar; App bietet die Form an, erzeugt dann keine DE-Termine und die EU-KU-Meldung. Sicherheit mittel | Release | intern geprüft 2026-10-18 (mittel) |
| P-S70 | Kleinunternehmergrenze der Heimat: zählen Umsätze aus dem DE-Lager (in DE steuerbar) zur AT-Grenze 55.000 € (§ 6 Abs 1 Z 27 UStG 1994: „im Inland“)? App rechnet sie nicht mit (FA-18.7). Gegenprobe DE-Heimat mit AT-Lager | Vorbefund: nein, nur im Inland steuerbare Umsätze; für EU-KU zusätzlich EU-Gesamtumsatz. Sicherheit mittel | Release | intern geprüft 2026-10-18 (hoch) |
| P-S71 | Zuständiges Finanzamt für ausländische Unternehmer: AT-Unternehmen in DE → Finanzamt München (§ 21 Abs 1 S 2 AO, § 1 Abs 1 UStZustV, aktuelle Fassung?); DE-Unternehmen in AT → Finanzamt Österreich, Dienststelle Graz-Stadt (§ 60 Abs 2 BAO, AVOG 2010)? Feiertage für die Fristverschiebung: am Sitz des Finanzamts (Bayern) oder bundesweit? | Vorbefund: München hoch, Graz-Stadt mittel; Feiertage: App nimmt bundesweite (unsicher) | Release | intern geprüft 2026-10-18 (mittel) |
| P-S72 | OSS-Erklärung: Frist Ende des Folgemonats nach Quartalsende (Art 369g MwStSystRL) – Verschiebung bei Wochenende/Feiertag? Fernverkäufe aus dem DE-Lager in andere EU-Länder: Meldung über das AT-OSS mit Abgangsland DE? | Vorbefund: Frist hoch; Verschiebung nach EU-Recht nein (mittel) – App verschiebt wie alle Termine; Fernverkäufe über Heimat-OSS (hoch) | Release | intern geprüft 2026-10-18 (hoch) |
| P-S73 | Importzuordnung (FA-18.9): FBA-Verkauf auf amazon.de ⇒ Lager DE als Annahme vertretbar? Bei Pan-EU/CEE nur mit USt-Transaktionsbericht (`SALE_DEPART_COUNTRY`); Steuer laut Bericht oder Normalsatz 19 % für Spirituosen | Vorbefund: als Vorschlag mit Hinweis vertretbar, Prüfung durch die Kanzlei je Quartal. Sicherheit mittel | Release | intern geprüft 2026-10-18 (mittel) |
| P-S74 | Ertragsteuer: begründet das FBA-Lager in DE eine Betriebsstätte (§ 12 AO, Art 5 DBA AT-DE)? App: Gewinn nur in AT (E1a) über alle Steuerländer (GR-16) | Vorbefund: nein, keine Verfügungsmacht über das Amazon-Lager (h. M.), Sicherheit mittel | Release | intern geprüft 2026-10-18 (mittel) |
| P-S75 | Plausibilität der Demo-Musterdaten (FA-13.14, `lib/services/demo/demo_dataset.dart`): seit 0.28.0 AT-Kleinunternehmerin (Rechnungen ohne USt mit Hinweis § 6 Abs 1 Z 27 UStG 1994, Jahresumsatz ≈ 15.000 €) mit DE-Registrierung (zuvor AT-Regelbesteuerung); Diesel nur mit Vorsteuer, weil Fiskal-LKW (§ 12 Abs 2 Z 2 lit b UStG AT); Bewirtung 10 %/20 % auf einem Beleg mit Anlass und Teilnehmern (50 % ESt, Vorsteuer voll); Versicherung und Bankspesen ohne USt (§ 6 Abs 1 Z 9 lit c, Z 8 UStG AT); Hotel Zürich in CHF ohne Vorsteuer; Lagerleistung DE 19 % statt steuerfreier Raummiete (§ 4 Nr. 12 UStG DE); Laptop 1.199 € netto über der GWG-Grenze, AfA 3 Jahre; Rechnungen nur an inländische Kundschaft (Beratung an eine deutsche GmbH wäre Reverse Charge); Fachbuch 10 % | Vorbefund Steuerberater: nach Korrektur der drei Befunde (Fiskal-LKW, Lagerleistung, Reverse Charge) stimmig; die Demo ist Anschauung, keine Musterbuchhaltung | Store-Start | offen |
| P-S76 | EU-KU-Nummer (FA-18.10): Aufbau in AT (Finanzamt Österreich: `ATU` + 8 Ziffern + `EX`?) und DE (BZSt: `DE` + 9 Ziffern + `EX`, auch ohne eigene USt-IdNr.?) nach Art 284 Abs 3 MwStSystRL; gilt die Prüfziffer der UID? | Annahme nach Richtlinie und Verwaltungsinformationen aus Fachwissen, keine amtliche Seite abgerufen; Prüfung leer erlaubt, damit eine abweichende Nummer nur warnt, indem sie nicht gespeichert wird | Store-Start | offen |
| P-S77 | EU-KU-Nummer auf der Rechnung (FA-18.10): Pflicht nach dem Recht des anderen Mitgliedstaats (z. B. DE § 34a UStDV für EU-Kleinunternehmer aus AT; AT § 11 UStG für DE-Unternehmer) und Ort im Kopf; reicht „EU-KU-Nr.“ als Bezeichnung, braucht es zusätzlich einen Befreiungshinweis des Gastlands? | App: Nummer im Kopf bei Kleinunternehmer-Rechnung an Kunden in einem anderen Land, Befreiungshinweis wie bisher aus dem Heimatprofil | Store-Start | offen |
| P-S78 | Abgaben AT 2026 (FA-19.2): Tarifstufen 13.539/21.992/36.458/70.365/104.859/1 Mio. € (§ 33 Abs 1 EStG 1988, Progressionsabgeltung 2026); SVS: PV 18,5 %, KV 6,8 %, SV 1,53 %, UV 12,95 €/Monat, Mindestbeitragsgrundlage 551,10 €/Monat (6.613,20 €/Jahr), Höchstbeitragsgrundlage 8.085 €/Monat (97.020 €/Jahr); Gewinnfreibetrag nur Grundfreibetrag 15 % bis 33.000 € – amtlich (RIS, SVS-Werte 2026) abgleichen | Tarif hoch (usp.gv.at, BMF, Beispiel 40.000 € → 7.447,20 € im Test); SVS mittel (WKO-Infoblatt 2026, Sekundärquellen, UV 12,95 vs. 12,96 € Rundung) | Release | offen |
| P-S79 | Abgaben AT: Beitragsgrundlage = Gewinn + gebuchte SVS-Beiträge (Hinzurechnung § 25 Abs 2 Z 2 GSVG) als Näherung für „vorgeschriebene“ Beiträge; vorläufige Beitragsgrundlage in den ersten drei Jahren = Mindestbeitragsgrundlage (§ 25a GSVG), Nachbemessung als Hinweis; KU-Ausnahme § 4 Abs 1 Z 7 GSVG (Umsatz ≤ 55.000 €, Einkünfte ≤ 6.613,20 €) nur als Hinweis/Schalter, weitere Voraussetzungen (Vorversicherungszeiten, Alter) nicht geprüft | Vorbefund Steuerberater: vertretbare Schätzung, gekennzeichnet | Release | offen |
| P-S80 | Konten der Abgabenkategorien (FA-19.4): Sozialversicherung SKR03 1800 (DE privat) bzw. BMD-Export EKR 7800 Sammelkonto (AT Betriebsausgabe), Einkommensteuer SKR03 1810 / EKR 9600, Gewerbesteuer SKR03 4320; E/A: AT SVS Betriebsausgabe (§ 4 Abs 4 Z 1 lit a EStG 1988), ESt privat (§ 20 Abs 1 Z 6 EStG 1988, § 12 Nr 3 EStG), GewSt nicht abziehbar (§ 4 Abs 5b EStG), DE KV/PV Sonderausgabe (§ 10 Abs 1 Nr 3 EStG) | Vorbefund Steuerberater: Behandlung hoch, Konten mittel | Release | offen |
| P-S81 | Abgaben DE 2025/2026 (FA-19.3): § 32a EStG-Formeln (2026: GFB 12.348 €, 914,51/1.400; 173,10/2.397/1.034,87; 0,42 − 11.135,63; 0,45 − 19.470,38), Soli-Freigrenze 2026 20.350 € mit 11,9 % Milderung, Kirchensteuer 8 % BY/BW, sonst 9 %, ohne Kappung und ohne Sonderausgabenabzug der KiSt; Grundtabelle (Einzelveranlagung) | Formeln aus Fachwissen (Steuerfortentwicklungsgesetz), Stetigkeit an den Zonengrenzen im Test geprüft; amtliche Quelle nicht abrufbar → mittel | Release | offen |
| P-S82 | Gewerbesteuer-Schätzung (FA-19.3): Gewinn = Gewerbeertrag ohne Hinzurechnungen/Kürzungen (§§ 8, 9 GewStG), Abrundung auf 100 €, Freibetrag 24.500 €, Messzahl 3,5 %, Hebesatz-Vorschlag 400 %, Anrechnung § 35 EStG 4,0-fach gedeckelt auf tatsächliche GewSt und ESt (Ermäßigungshöchstbetrag vereinfacht) | Vorbefund Steuerberater: für Einzelunternehmen ohne Hinzurechnungen vertretbar | Release | offen |
| P-S83 | Kranken-/Pflegeversicherung DE (FA-19.3): Entscheidung Prüfinstanz Steuerberater: Monatsbetrag laut Beitragsbescheid eingeben statt schätzen (Zusatzbeitrag je Kasse, Kinderlosenzuschlag, Mindestbemessung, Nachberechnung nach Steuerbescheid); voll als Vorsorgeaufwand vom zvE abgezogen (vereinfachend: ohne 4 %-Kürzung Krankengeld, ohne Höchstbetrag) | Vorbefund: richtungsrichtig, leicht zu günstig | Release | offen |
| P-S84 | Doppelte Buchführung / Kapitalgesellschaft (FA-15.12): genügt das Paket Saldenliste (PDF) + Belegliste/DATEV/BMD-CSV + Belegkopien mit Beleg-ID im Dateinamen der Kanzlei für die Übernahme? Kategorien als Sachkonten-Vorschlag (SKR03/EKR) | nur Austauschformat, keine Bilanz | Release | offen |
| P-S85 | Grenzwertampel je Land (FA-4.14): DE § 19 UStG ab 2025 – Vorjahr ≤ 25.000 €, laufendes Jahr ≤ 100.000 € (Wegfall ab dem Umsatz, der 100.000 € übersteigt), Gründungsjahr ≤ 25.000 €; Balken misst an 25.000 € und warnt, dass über 25.000 € das **Folgejahr** regelbesteuert ist. AT § 6 Abs 1 Z 27 UStG ab 2025 – 55.000 € brutto, Toleranz 10 % (60.500 €) mit Wegfall erst ab dem übersteigenden Umsatz, ohne Fünfjahresregel. Wortlaut der Meldungen fachlich richtig und nicht missverständlich? | intern geprüft 2026-10-19 (hoch für die Grenzwerte, mittel für den Wortlaut) | Release | offen |
| P-S86 | E-Rechnung Kleinunternehmer (FA-5.49): Kategorie `E` (steuerbefreit) mit Befreiungsgrund „Steuerbefreiung nach § 19 UStG (Kleinunternehmer).“ bzw. „Umsatzsteuerbefreit – Kleinunternehmer gemäß § 6 Abs 1 Z 27 UStG.“, ohne VATEX-Code; ohne UID die Steuernummer als FC und als Verkäuferkennung BT-29 (BR-CO-26). Empfänger und Prüfprogramme akzeptieren das? Kleinunternehmer DE sind nach § 34a UStDV von der Ausstellungspflicht ausgenommen, dürfen aber E-Rechnungen senden | intern geprüft 2026-10-19 (mittel) | Release | offen |
| P-S87 | E-Rechnung Inhalt (FA-5.49): Storno als 381 mit positiven Beträgen und Bezug BT-25; Skonto als `#SKONTO#`-Zeile in BT-20; Steuer je Position gerundet (GR-5) gegen BR-CO-17-Toleranz; 0 % bei Regelbesteuerung als `Z`; Leistungsdatum BT-72 = Lieferdatum oder Rechnungsdatum; Pflichtangaben § 14 Abs 4 UStG DE / § 11 UStG AT vollständig in der XML? | Mustang/Schematron ohne Fehler (intern) | Release | offen |
| P-S88 | Gemischt genutzte Ausgaben mit Buchungsregel (FA-20.3): (a) DE: anteiliger Vorsteuerabzug bei Aufteilung zulässig (§ 15 Abs 4 UStG) statt voller Zuordnung mit Wertabgabe § 3 Abs 9a Nr. 1 UStG; unter 10 % unternehmerischer Nutzung kein Abzug (§ 15 Abs 1 Satz 2 UStG); Privatanteil keine Betriebsausgabe (§ 12 Nr. 1 EStG). (b) AT: Vorsteuer nur im unternehmerischen Ausmaß (§ 12 Abs 2 Z 1 lit a UStG 1994, 10-%-Grenze), Eigenverbrauch § 3a Abs 1a; PKW-Vorsteuer bleibt ausgeschlossen (§ 12 Abs 2 Z 2 lit b UStG 1994, außer emissionsfrei, Rz 1919 UStR) – Nutzerin muss beim PKW-Beleg die Vorsteuer weglassen bzw. die Kategorie wählen. (c) Kleinunternehmer: Aufteilung brutto. (d) Gebäude/Wohnung: Vorsteuer auf Mietanteil Büro | Vorbefund Steuerberater: vorsichtig und vertretbar; Wahlrechte (volle Zuordnung) nicht abgebildet. Sicherheit mittel | Release | offen |
| P-S89 | Hilfeartikel „Privat-PKW teilweise betrieblich“ (FA-20.6): AT – PKW im Betriebsvermögen erst bei > 50 % betrieblicher Nutzung, sonst Kilometergeld 0,50 €/km für betriebliche Fahrten (§ 26 Z 4 EStG 1988 idF ab 2025, sinngemäß für Unternehmer), Luxustangente 40.000 € (PKW-Angemessenheitsverordnung), Fahrtenbuch als Nachweis; DE – 1-%-Regelung nur bei > 50 % betrieblicher Nutzung (§ 6 Abs 1 Nr. 4 Satz 2 EStG), sonst Fahrtenbuch (Satz 3) oder Kostenaufteilung bzw. bei Privatvermögen 0,30 €/km (§ 4 Abs 5 Nr. 6 / H 4.7 EStH), Elektro 0,25 % bzw. 0,5 % (§ 6 Abs 1 Nr. 4 Satz 2 Nr. 3 ff. EStG, Bruttolistenpreisgrenze aktuell?) | Vorbefund Steuerberater aus Fachwissen, keine amtliche Seite abgerufen; Werte je Jahr prüfen. Sicherheit mittel | Release | offen |
| P-S90 | Hilfeartikel „Büro in der eigenen Wohnung“ (FA-20.6): AT – Arbeitszimmer im Wohnungsverband nur bei Mittelpunkt der gesamten betrieblichen Tätigkeit und ausschließlicher Nutzung (§ 20 Abs 1 Z 2 lit d EStG 1988), sonst Arbeitsplatzpauschale 1.200 € bzw. 300 € (§ 4 Abs 4 Z 8 EStG 1988, seit 2022); DE – häusliches Arbeitszimmer als Mittelpunkt: tatsächliche Kosten oder Jahrespauschale 1.260 € (§ 4 Abs 5 Satz 1 Nr. 6b EStG idF JStG 2022), sonst Tagespauschale 6 €/Tag, höchstens 1.260 € (Nr. 6c); Flächenanteil m² als Aufteilungsmaßstab | Vorbefund Steuerberater, Sicherheit mittel | Release | offen |

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
| P-K4 | Steuerberatung bestätigt: flüchtige KI-Verarbeitung ohne Speicherung ist kein „Führen der Bücher" im Ausland (§ 146 Abs 2 AO, § 131 BAO) | beide Prüfinstanzen: kein Verlagerungsantrag nötig, solange Ablage auf dem Gerät | vor KI-Belegerkennung | intern geprüft 2026-10-16 (mittel) |
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
| P-X12 | Einhandtest „Für das Finanzamt“ auf Pixel 10 und iPhone: Quartal wählen, Kennzahl antippen und in FinanzOnline bzw. „Mein ELSTER“ im Browser einfügen, „U30-Datei teilen“ mit dem Daumen | Widget-Test: Zeilen und Knopf ≥ 48 dp (`tax_office_test.dart`) | Release | offen |
| P-X13 | Einhandtest Anlagen auf Pixel 10 und iPhone: Ausgabe öffnen → „Als Investition erfassen“ → Art wählen → Speichern; Ausscheiden mit Kommentar über der Tastatur; Berichte teilen | Widget-Test: Speichern 56 dp im unteren Drittel, Auswahlzeilen und Berichtszeilen ≥ 48 dp (`fixed_asset_test.dart`) | Release | offen |
| P-X14 | Einhandtest Vertragsarchiv: PDF aus Mail teilen → Hinweis „Ist das ein Vertrag?“ antippen; Seiten fotografieren; Kurzübersicht-Zeile antippen; Rate als Vorschlag buchen; Löschen nur über Gefahrenzone mit Warnung | Widget-Test: Speichern 56 dp im unteren Drittel, Knöpfe ≥ 48 dp (`contract_test.dart`) | Release | offen |
| P-X15 | Einhandtest Scanner: „Beleg fotografieren“ → Systemscanner (Android/iOS) mit dem Daumen auslösen, Seiten hinzufügen, „Fertig/Speichern“ erreichbar; Rückkehr ins Formular mit allen Seiten; Abbrechen ohne Beleg-Anlage. Die Scanner-Oberfläche liefert das System (nicht änderbar) | nicht automatisierbar | Release | offen |
| P-X16 | Einhandtest Bewirtung (FA-2.60): Kategorie „Bewirtung“ mit dem Daumen wählen, Hinweis lesbar; DE: Anlass und Teilnehmer erreichen, Tastatur verdeckt die Speicherleiste nicht, Speichern ohne die Felder möglich | Widgettests nur für Logik | Release | offen |
| P-X17 | Blindtest Aufnahmeknopf (FA-12.1, DESIGN_SPEC 5a Regel 13): auf Pixel 10 und iPhone einhändig rechts und links, ohne hinzusehen, den runden Knopf „Beleg“ auf Übersicht und Belegliste treffen; im Belegformular „Seite“ treffen, ohne „Beleg speichern“ auszulösen; TalkBack/VoiceOver liest „Beleg fotografieren“ | Widget-Test: Kreis ≥ 72 dp, Mitte ± 2 dp, über Speichern | Release | offen |
| P-X20 | Einhandtest Mithelfer (FA-17.2, FA-17.3, FA-17.5): auf dem Mithelfer-Gerät „Beleg“ unten mittig, „Senden“ unten mit dem Daumen ohne Umgreifen; auf dem Hauptgerät Ablehnen (48 dp) neben der Zeile nicht versehentlich treffen; QR-Code auf 360-dp-Gerät vollständig und scharf | Widget-Test: Aufnahmeknopf ≥ 72 dp mittig im unteren Drittel, Nebenknöpfe ≥ 48 dp | Release | offen |
| P-X21 | Einhandtest Mailweg (FA-17.9, FA-17.10): Häkchen „Andere E-Mail-Adresse …“ und „Verbinden und speichern“ mit dem Daumen; Mithelfer: App-Passwort aus der Google-/Apple-Seite kopieren und einfügen ohne Umgreifen, „Jetzt senden“ (48 dp) nicht mit „Beleg“ (Aufnahmeknopf) verwechseln; Bottom-Sheet „Gerät hinzufügen“ mit offener Tastatur auf 360-dp-Gerät | Widget-Tests: Häkchen 56 dp, Knöpfe ≥ 48 dp, Speichern 56 dp, Bottom-Sheet scrollbar (`helper_mail_ui_test.dart`) | Release | offen |
| P-X22 | Einhandtest Steuerland (FA-18.1, FA-18.3) ab 0.25.0 auf Pixel und iPhone: Stammdaten → „Land hinzufügen“ → Deutschland → Speichern mit dem Daumen; im Belegformular Chip „DE“ ein Tipp, Steuersatz springt auf 19 %; Chips nicht neben Gefahrenknöpfen | Widget-Test misst 56 dp (`test/tax_registration_test.dart`); Gerät offen | Release | offen |
| P-X19 | Blindtest Aufnahmeleiste (FA-12.1, DESIGN_SPEC 5a Regel 13): einhändig rechts und links „Foto“, „Beleg“ und „Datei“ ohne hinzusehen treffen, kein Fehltipp auf den Nachbarn; TalkBack/VoiceOver liest „Foto aus der Galerie als Beleg“ und „Datei als Beleg wählen“ | Widget-Test: 56 dp, 48 dp Abstand, spiegelgleich, 360 und 412 dp | Release | offen |
| P-X18 | Einhandtest Diktat (FA-2.61): Mikrofon im Feld Beschreibung/Notiz und im Betrag mit dem Daumen treffen, ohne das Feld daneben zu öffnen; Stopp mit einem Tipp; Vorschlag im Betrag sichtbar, Tastatur verdeckt die Speicherleiste nicht | Widget-Test: Knopf ≥ 48 dp | Release | offen |
| P-X23 | Einhandtest Demo (FA-13.14, FA-13.15) auf Pixel 10 und iPhone: Startauswahl „Abo wählen – 14 Tage kostenlos“ und „Erst ansehen (Demo)“ mit dem Daumen ohne Fehlgriff (64 dp, 16 dp Abstand); Hinweisblatt „Abo wählen“/„Weiter ansehen“ (56 dp, 12 dp Abstand) unten; das Band oben ist für den Daumen schwer erreichbar – genügt, dass jede gesperrte Aktion das Blatt unten zeigt? | Widget-Test: Knöpfe ≥ 48 dp im unteren Drittel, Abstand ≥ 12 dp, Band ≥ 48 dp (`demo_test.dart`) | Store-Start | offen |
| P-X24 | Einhandtest Ersteinrichtung (FA-1.13) auf Pixel 10 und iPhone: Willkommensseite bis Schritt 4 nur mit dem Daumen; „Später hinzufügen“ nicht mit „Weiter“ verwechselt (12 dp Abstand); Tastatur verdeckt in Schritt 2 und 3 kein Feld und den Hauptknopf nicht dauerhaft; Zurück-Geste führt einen Schritt zurück | `setup_wizard_test.dart`: Höhen 56/48 dp, Abstand ≥ 12 dp, Daumenzone, Schrittfolge, Überspringen, Fortsetzen | Store-Start | offen |
| P-X25 | Einhandtest „Abgaben & Rücklagen“ (FA-19.1, FA-19.2) auf Pixel 10 und iPhone: Karte auf der Übersicht mit dem Daumen tippen, Angaben ändern (Tastatur verdeckt nicht das Feld), „Angaben speichern“ unten 56 dp; Schalter ≥ 48 dp | Widget-Test 360 × 740 dp (Speichern ≥ 56 dp, Schalter ≥ 48 dp) | Release | offen |
| P-X26 | Einhandtest PDF-Betrachter (FA-5.48) auf Pixel 10 und iPhone: Rechnung ansehen, mit dem Daumen wischen und zoomen, Drucken/Senden/Schließen unten 56 dp ohne Fehltipp; Demo: Wasserzeichen lesbar, Demo-Blatt bei Drucken/Senden; Willkommensseite (FA-1.13) ohne Scrollen auf 360 × 740 dp mit Systemschrift und großer Schrift | Widget-Test mit Ersatzbild und Work Sans 360 × 740 / 412 × 915 dp | Release | offen |
| P-X27 | Einhandtest Rückmeldung 0.30.0 auf Pixel 10 und iPhone: Übersicht scrollen – Aufnahmeleiste gleitet weg, kommt nach 5 s und ganz oben sofort zurück, kein Verschwinden während eines Tipps, TalkBack/VoiceOver: Leiste bleibt (FA-12.1); PDF im dunklen Modus mit weißem Papier und Originalfarben (FA-5.48); Willkommensseite jede Funktionszeile einzeilig mit Systemschrift (FA-1.13); „Dieses Gerät ist ein Mithelfer-Gerät (koppeln)“ in Schritt 2 gut erreichbar, kein Fehltipp; Demo-Landeswahl mit einem Tipp (FA-13.14) | Widget-Tests `scroll_auto_hide_test.dart`, `pdf_viewer_test.dart`, `welcome_page_test.dart` (Textbreite gemessen), `demo_test.dart` | Release | offen |
| P-X29 | Einhandtest Buchungsregeln (FA-20.x) auf Pixel 10 und iPhone: Hilfeartikel PKW → „Regel anlegen“ → km ändern (Tastatur verdeckt das Anteilsfeld nicht) → Speichern; Foto Grundriss anhängen mit Notiz; Beleg Kfz-Kosten öffnen, Karte „Regel: PKW 30 % betrieblich“ tippen, Schalter „Diese Buchung ausnehmen“ mit dem Daumen; Kategorie-Chips 48 dp | Widget- und Einheitentests `booking_rules_test.dart` | Release | offen |
| P-X30 | Regelstand (FA-21.x) auf Pixel 10 und iPhone: Gerätedatum auf 2.1.2027 stellen, Band „Für 2027 gibt es neue Steuerwerte …“ erscheint einmal, Tippen öffnet die Store-Seite (Play Store-App bzw. App Store), Übersicht bleibt bedienbar; Abgaben zeigen „Werte von 2026 – Schätzung unsicher“ | `rules_freshness_test.dart` | Release | offen |
| P-X28 | Einhandtest E-Rechnung (FA-5.49) auf Pixel 10 und iPhone: Kundin auf XRechnung stellen (ganze Zeile 56 dp, Leitweg-ID-Feld erscheint, Tastatur verdeckt nichts), Rechnung ansehen, Hinweiszeile lesbar, „XML senden“ öffnet das Teilen-Blatt mit `XRechnung_<Nr>.xml`; ZUGFeRD-PDF per Mail an sich selbst, in einem E-Rechnungs-Viewer (z. B. Mustang, ELSTER-Viewer, e-Rechnung.gv.at-Prüfung) öffnen | Widget-Tests `one_hand_test.dart`, `pdf_viewer_test.dart` | Release | offen |

### Softwareentwicklung (echte Geräte und Stores)

| ID | Prüfpunkt | Vorbefund der Prüfinstanz | Benötigt vor | Status |
|---|---|---|---|---|
| P-D1 | Update einer echten v1-Installation auf Schema 2 und folgende | Upgrade-Test mit ffi vorhanden; echtes Gerät fehlt | Release | offen |
| P-D2 | PDF mit Umlauten, CSV in Excel/Numbers | nicht verifiziert | Release | offen |
| P-D3 | Datensicherung und Wiederherstellung über iCloud Drive / Google Drive | iCloud (FA-7.16) und Ordnerwahl gebaut, auf Gerät offen (P-B12, P-B14) | Release | offen |
| P-D4 | Abo-Testkäufe in Sandbox beider Stores (Lizenztester Google, Sandbox-Konto Apple; Build mit `LICENSING=true`): Test 14 Tage Pro mit Übergang, Basis, Wechsel Basis↔Pro ohne Doppelabo, Jahresabo, Kündigung → Nur lesen mit Hinweis, Kauf wiederherstellen nach Neuinstallation, ausstehende Zahlung, Flugmodus (Stand bleibt), Grace Period | Logik mit Store-Ersatz getestet (`licensing_test.dart`, FA-13.1 bis FA-13.10); Adapter nur kompiliert | Store-Start | offen |
| P-D5 | iOS Privacy Manifest, Data-Safety- und Privacy-Label-Angaben inkl. aller SDKs | Manifest fehlt | erster Upload | offen |
| P-D6 | Android targetSdk-Vorgabe 2026, Signing, Bundle-ID `at.jenibarb.jenibucht` endgültig (Wechsel O-33 am 2026-10-19) | nach dem ersten Upload unveränderlich | erster Upload | offen |
| P-D7 | Kamera, Fotoablage, Spracheingabe auf echten Geräten | — | Release | offen |
| P-U1 | VIES-Schnittstelle live auf echten Android- und iOS-Geräten: gültige, ungültige Nummer, Ausfall eines Mitgliedstaats; Abfragenummer kommt zurück | Endpunkt und Antwortformat aus Fachwissen, nicht live getestet | Release | offen |
| P-U2 | Nachweiswert von VIES mit Abfragenummer gegenüber FinanzOnline Stufe 2 (AT) und qualifizierter Bestätigungsabfrage § 18e UStG (DE) | VIES schwächer, aber als Hilfsnachweis anerkannt | Release | intern geprüft 2026-10-16 (mittel) |
| P-U3 | Steuernummer auf österreichischen Rechnungen nicht nötig; DE Steuernummer oder USt-IdNr. genügt | beide Prüfinstanzen | Release | intern geprüft 2026-10-16 (hoch) |
| P-U4 | Datenschutzerklärung und Store-Formulare (Google Data Safety, Apple Label) zur VIES-Abfrage durch Fachperson | Nutzerin Verantwortliche, Kommission Empfängerin, Anbieter unbeteiligt | erster Upload | offen |
| P-U5 | Kassen- und Zahlungs-QR auf echtem Gerät: SPAR-/Hofer-/Billa-Bon mit RKSV-QR (auch zerknittert, schräg, schwaches Licht), deutscher TSE-Bon, Rechnung mit GiroCode; Vermerk „vom Kassen-QR“ sichtbar; Teilen eines Fotos aus Galerie und Mail öffnet den Buchungsvorschlag mit einer Hand | Emulator prüft nur synthetische QR-Bilder (FA-2.35); Korpus Belege 1–6 wird im CI-Artefakt `ocr-belege` auf Codes ausgewertet | Release | offen |
| P-U6 | Link-QR auf echtem Gerät: Rechnung eines Anbieters mit QR-Link (z. B. Energie, Telefon), Streifen einhändig erreichbar, Domain lesbar, Laden einer PDF, Weiterleitung auf andere Domain zeigt neue Domain, HTML-Portal führt zu „Im Browser öffnen“ | Logik mit Testserver geprüft (`link_invoice_test.dart`), kein echter Anbieter | Release | offen |
| P-U8 | Angebote und Artikel auf echtem Gerät mit einer Hand: Rechnungsliste → „Angebote“ → neues Angebot mit Artikel aus „Aus Artikeln und Vorschlägen“, „PDF senden“, „Zur Rechnung machen“; Daumen erreicht alle Knöpfe, Bottom-Sheet mit Tastatur bedienbar | Widget-Test (Knöpfe ≥ 48 dp, Zeilen ≥ 48 dp), kein echtes Gerät | Release | offen |
| P-U7 | Plattformimport auf echtem Gerät: Transaktionsbericht in der Seller-Central-App bzw. im Browser herunterladen, mit einer Hand teilen bzw. in Dateien „Öffnen mit“ → Buchhaltung, Zusammenfassung lesbar, „Übernehmen“ mit dem Daumen; zweites Teilen derselben Datei bucht nichts doppelt | Widget-Test (Knopf unten, volle Breite, ≥ 56 dp), kein echtes Gerät | Release | offen |
| P-B1 | Android: bietet die Google-Drive-App bei der Ordnerwahl (Storage Access Framework) Ordner an? Test auf Pixel und Samsung mit aktueller Drive-App. Wenn nein: Entscheidung über Anbindung der Drive-Schnittstelle | Drive bot lange keine Ordner an; unsicher | vor Release | **bestanden 2026-10-12** (Auftraggeberin, Pixel 10: Sicherung und automatische Sicherung nach Google Drive). Wiederherstellung aus Drive siehe P-B12 |
| P-B2 | iOS: Bookmark auf einen iCloud-Drive-Ordner nach Neustart, Update und offline; Upload durch das System | — | vor Release | offen |
| P-B3 | Laufzeit einer großen Sicherung (viele Fotos) beim Öffnen der App; Verhalten bei Wechsel in den Hintergrund | — | vor Release | offen |
| P-B4 | Steuerberatung: verschlüsselte Sicherungskopie in einer US-Cloud neben den Originaldaten am Gerät ist kein „Führen der Bücher im Ausland“ (§ 146 Abs 2a/2b AO, § 131 BAO); Fristen nach BEG IV (8/10 Jahre) | beide Instanzen: nach h. M. unkritisch, kippt wenn die Cloud-Kopie die einzige wird | Release | intern geprüft 2026-10-16 (mittel) |
| P-B5 | Store-Angaben zur automatischen Sicherung (gehört zu P-U4) | keine Erhebung durch den Anbieter | erster Upload | offen |
| P-B6 | Anwältin: iCloud-Sicherung standardmäßig an mit Hinweis, ohne Einwilligung zulässig; Hinweis auf Kundendaten und Drittland USA bei Apple | — | vor Release | offen |
| P-B7 | Gerätetest iPhone: iCloud an, aus, voll, abgemeldet; Wiederherstellung auf Zweitgerät mit Code | nur real prüfbar | vor Release | offen |
| P-B8 | Anwältin: Formular Datensicherheit in der Play Console bei Ordnerwahl bzw. Drive-Schnittstelle | — | erster Upload | offen |
| P-B9 | Apple-Review: „Data Not Collected“ trotz iCloud-Sicherung akzeptiert | — | erster Upload | offen |
| P-B10 | Gerätetest: Ordnerwahl mit Google Drive auf Samsung und Xiaomi, automatische Sicherung im Hintergrund; danach Entscheidung über Drive-Schnittstelle | — | vor Release | offen |
| P-B11 | Google: OAuth-Verifizierung für `drive.file`, nur wenn der Ersatzweg gebaut wird | — | bei Bedarf | offen |
| P-B12 | Gerätetest: Wiederherstellung aus einer Sicherung in Google Drive auf einem zweiten oder frisch installierten Gerät | Zurückholen ist der eigentliche Prüfstein | vor Release | offen |
| P-B13 | Eigentümer: iCloud-Container `iCloud.at.jenibarb.jenibucht` (seit O-33, 2026-10-19) im Apple Developer Portal anlegen und der App-ID `at.jenibarb.jenibucht` zuordnen (vor erstem signierten Build bzw. `release.yml`) | ohne Container scheitert die Signatur mit Entitlement; unsignierter CI-Build unberührt | erster signierter iOS-Build | offen |
| P-B14 | Gerätetest iPhone: „Einrichten“ ohne Ordnerwahl schreibt nach iCloud Drive › JeNi bucht, Ordner in der Dateien-App sichtbar; „Wiederherstellen“ listet die Sicherungen auch auf einem Zweitgerät (ausgelagerte `.icloud`-Dateien werden geladen); iCloud abgemeldet → Ordnerwahl | nur kompiliert | vor Release | offen |
| P-B15 | Eigentümer, erste Einreichung: App Privacy Label in App Store Connect so ausfüllen wie `STORE_LISTING.md` (Formularantworten) und mit `ios/Runner/PrivacyInfo.xcprivacy` abgleichen; Xcode „Generate Privacy Report“ auf dem Archiv ohne Warnung; Apple-Review akzeptiert die Angaben | Manifest nach Plugin-Manifesten und eigenem Code erstellt, nicht von Apple bestätigt | erste Einreichung | offen |
| P-B16 | Eigentümer: Secrets für `release.yml` anlegen (RELEASE_PLAYBOOK „Secrets für den Release-Workflow“), Workflow einmal starten: signierte AAB und IPA entstehen, IPA erscheint in TestFlight; erste AAB von Hand in die Play Console | Workflow nur syntaktisch geprüft, ohne Secrets nicht lauffähig | erste Einreichung | offen |
| P-M1 | Steuerberatung AT bestätigt Nummernkreise je Gerät/Person mit Präfix (UStR Rz 1565); DE nach UStAE 14.5 Abs 10 | Prüfinstanzen: zulässig, wenn Präfix fest und dokumentiert | Stufe C | intern geprüft 2026-10-16 (mittel) |
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
| P-L11 | Anwältin: Änderungsklausel (Ziffer 11) mit Zustimmung in der App wirksam? | BGH XI ZR 26/20, OGH streng | Release | intern geprüft 2026-10-16 (mittel) |
| P-S15 | Steuerberatung: Kommentarkonzept (nur anhängbar, im Export) und Muster-Verfahrensdokumentation für mehrseitig fotografierte Belege (GoBD Rz. 136 ff., § 132 Abs 2 BAO) | — | Release | offen |
| P-S16 | Steuerberatung: Aufbewahrungsfrist je Vertragstyp AT/DE (BEG IV) für das Vertragsarchiv | — | Stufe C | offen |
| P-S17 | Steuerberatung bzw. Kammer: Katalog der KI-Hinweistexte zu Verträgen auf Vorbehaltsaufgaben (StBerG, WTBG) | — | Stufe C | offen |
| P-S18 | Steuerberatung: Leasing-Sonderzahlung und Zurechnung bei Einnahmen-Ausgaben-Rechnung AT/DE | — | Stufe C | offen |
| P-S19 | Steuerberatung: Zusammenfassende Meldung und UID-Pflicht bei Store-Auszahlungen als Kleinunternehmerin AT | — | erste Auszahlung | intern geprüft 2026-10-16 (mittel) |
| P-S20 | Steuerberatung: kein Reverse Charge auf die Store-Provision (fiktiver Leistender), Bemessungsgrundlage Auszahlung; Abrechnungsbelege Google/Apple | — | erste Auszahlung | intern geprüft 2026-10-16 (mittel) |
| P-S21 | Steuerberatung: Store-Umsätze zählen nicht zur 55.000-€-Grenze (§ 6 Abs 1 Z 27 UStG)? | — | erste Auszahlung | intern geprüft 2026-10-16 (mittel) |
| P-S22 | Steuerberatung: Affiliate-Provisionen (Reverse Charge, Gutschrift), Einkommensteuer- und SVS-Schätzung mit echten Zahlen | Preispolitik der Auftraggeberin | vor Preisfestlegung | offen |
| P-S23 | Steuerberatung AT: BMF-Durchschnittskurs nach § 20 Abs 6 UStG, Stichtag bei Soll- und Istbesteuerung, Steuerbetrag in Euro auf Fremdwährungsrechnungen | Umgesetzt: Monatskurs des Belegmonats; BMF-Kurs nur manuell (Quelle `bmf_monthly`), Standard EZB-Monatsmittel als Näherung (FA-2.25) | vor Fremdwährung | offen |
| P-S24 | Steuerberatung DE: Abschn. 14.5 Abs. 22 UStAE; darf das EZB-Monatsmittel den BMF-Kurs ersetzen? | Umgesetzt als gekennzeichnete Näherung „EZB-Monatsmittel – Näherung an BMF-Kurs“; manueller BMF-Kurs jederzeit | vor Fremdwährung | offen |
| P-S25 | Steuerberatung: Kurs für die Kleinunternehmergrenze bei Fremdwährungsumsätzen | Betrifft nur Einnahmen; diese bleiben Euro (L-13.3), daher derzeit ohne Wirkung | vor Fremdwährung | intern geprüft 2026-10-16 (mittel) |
| P-S26 | Steuerberatung: Unterschied Umsatzsteuer-Kurs zu Bankbetrag in E1a bzw. Anlage EÜR | Umgesetzt: Bankbetrag überschreibt nur das EÜR-Ergebnis als Kursdifferenz (FA-2.26), Vorsteuer bleibt beim USt-Kurs | vor Fremdwährung | offen |
| P-S27 | Steuerberatung: Ausländische Umsatzsteuer auf Belegen (z. B. dänische MOMS 25 %, deutsche USt 19 % bei Nutzerin in AT) ist im Inland nicht als Vorsteuer abziehbar; App belegt 0 % vor und verweist auf das Vorsteuer-Vergütungsverfahren. Bestätigen: Buchung brutto ohne Vorsteuer korrekt, Hinweistext ausreichend | Umgesetzt (FA-2.29), Befund der Prüfinstanz Steuerberater noch zu bestätigen | vor Release | intern geprüft 2026-10-16 (hoch) |
| P-S28 | Steuerberatung AT: 4,9 % nach § 10 Abs 1a UStG 1994 iVm Anlage 3 (laut RIS BGBl. I Nr. 37/2026), Leistungen ab 1.7.2026, unbefristet. Wortlaut, Anlage 3 und BGBl.-Nr. im RIS abgleichen; Abgrenzung Grundnahrungsmittel (KN-Positionen, Fett-/Zuckergrenze) | Umgesetzt: Satz im TaxProfile Österreich mit `validFrom` 2026-07-01 (GR-3); Befund der Prüfinstanz Steuerberater 2026-10-14 | vor Release | intern geprüft 2026-10-16 (mittel) |
| P-S29 | Steuerberatung: Kartenbeleg ohne Steuerausweis – Betriebsausgabe ja, Vorsteuer nein (§ 11 Abs 6, § 12 Abs 1 Z 1 UStG 1994; DE § 33 UStDV, § 15 UStG). Hinweistext bestätigen | Umgesetzt (FA-2.32): 0 % vorbelegt, Hinweis `noVatShownHint` | vor Release | intern geprüft 2026-10-16 (hoch) |
| P-S30 | Steuerberatung: Hinweistext ausländische USt je Land (AT FinanzOnline, DE BZSt; Frist 30.09. Folgejahr; Mindestbeträge 50 €/400 €; nicht für Kleinunternehmer) | Umgesetzt (FA-2.29, `foreignVatHint`) | vor Release | intern geprüft 2026-10-16 (mittel) |
| P-S31 | Steuerberatung: Genügt Speichern über den Knopf „Vollständig – Beleg speichern (n Seiten)“ mit Erklärzeile als Vollständigkeitsbestätigung (GoBD Rz. 136 ff. zum ersetzenden Scannen, Vollständigkeit § 146 Abs. 1 AO; AT § 131 BAO)? Eigenes Häkchen entfällt | Vorbefund Softwareentwickler: aktive, eindeutig beschriftete Handlung je Buchung mit neuen Seiten, Aussage steht unmittelbar am Knopf, Protokoll im `audit_log` mit Seitenzahl und „Vollständigkeit bestätigt“; ein vorab gesetztes Häkchen wäre schwächer. Gesetzlich ist keine bestimmte Form der Bestätigung vorgeschrieben (Verfahrensdokumentation) | vor Release | intern geprüft 2026-10-16 (mittel) |
| P-S32 | Abweichendes Wirtschaftsjahr: Voraussetzungen und Bestätigungstexte (AT § 2 Abs 5 EStG, DE § 4a EStG); EÜR-Rechner/Freiberufler praktisch Kalenderjahr – reicht eine Bestätigung, oder soll die App die Auswahl bei EÜR sperren? | Steuerberater-Befund 2026-10-14: AT nur Firmenbuch + Bilanzierung + Zustimmung FA, DE nur Handelsregister + Einvernehmen FA; USt immer Kalenderjahr. Umgesetzt als einmalige Bestätigung (FA-10.2) | Release | intern geprüft 2026-10-16 (mittel) |
| P-S33 | Termine: UVA-Grenzen (AT 100.000 € Vorjahresumsatz § 21 Abs 2 UStG; DE 9.000 € Vorjahressteuer § 18 Abs 2 UStG ab 2025), Jänner-/Dezember-Sonderregeln, Erklärungsfristen mit Steuerberatung (§ 134a BAO, § 149 Abs 3 AO), ZM-Zeitraum gleich Voranmeldungszeitraum (Vereinfachung), ESt-Vorauszahlungen immer angezeigt | Werte laut Befund im Code (FA-10.6, FA-10.7); Beraterfrist als „laut Kanzlei“ | Release | offen |
| P-S34 | SVS-Beitragsfälligkeit (§ 35 GSVG): Ende Feb./Mai/Aug./Nov.; Verschiebung bei Wochenende/Feiertag? | unsicher, daher „ca.“ ohne Verschiebung (FA-10.7) | Release | offen |
| P-S35 | Bezahlte Rechnung als Einnahme am Zahlungstag (Zuflussprinzip § 19 EStG AT, § 11 EStG DE); Kleinunternehmergrenze AT: App zählt Einnahmen nach Zahlungseingang (Ist) – richtig für Ist-Versteuerer (§ 17 UStG), bei Soll-Versteuerung nach Leistung? Teilzahlungen und Anzahlungen bildet die App nicht ab | umgesetzt nach Zufluss (GR-11); Soll-Basis nicht abgebildet | Release | offen |
| P-S40 | Gesamtrabatt anteilig nach Entgelt je Steuersatz mit Rabattzeile je Satz, Restcent nach größtem Rest (GR-12): genügt das § 11 Abs 1 Z 3 lit e UStG AT bzw. § 14 Abs 4 Nr. 7 UStG DE („im Voraus vereinbarte Minderung des Entgelts“)? | Vorbefund Steuerberater: Aufteilung nach Entgelten ist übliche und anerkannte Methode | Release | intern geprüft 2026-10-16 (mittel) |
| P-S41 | Versandkosten als Nebenleistung: Satz der Hauptleistung, bei Mischsätzen anteilig nach Entgelt (EuGH C-111/05 Aktiebolaget NN, UStR Rz 347 AT, Abschn. 3.10 Abs 6 UStAE DE); fester Satz als Ausnahme | Vorbefund: Aufteilung nach Entgelten zulässig, andere Schlüssel (Gewicht) ebenfalls | Release | intern geprüft 2026-10-16 (mittel) |
| P-S42 | Skonto bei Zahlung: Minderung je Satz nach Brutto-Anteil; Berichtigung im Zahlungsmonat (§ 16 UStG AT, § 17 UStG DE). App bucht nach Zufluss; bei Soll-Versteuerung wäre eine Korrekturbuchung im Zahlungsmonat zu den ursprünglichen Umsätzen nötig – reicht die geminderte Einnahme? Kein Beleg nötig (DE Abschn. 17.1 Abs 3 UStAE)? | Vorbefund: für Ist-Versteuerer korrekt, Soll nicht abgebildet (wie P-S35) | Release | offen |
| P-S43 | Skontotext auf der Rechnung: Pflichtangabe „Vereinbarung über Entgeltminderung“ (§ 14 Abs 4 Nr. 7 UStG DE) mit festem Datum und Betrag erfüllt; AT: ausreichend? Kleinunternehmer: nur geringere Einnahme | Vorbefund: Hinweis „Bei Zahlung bis … 2 % Skonto“ genügt (Abschn. 14.5 Abs 19 UStAE) | Release | intern geprüft 2026-10-16 (mittel) |
| P-S44 | Basiszinssätze 2025–2026 je Halbjahr: AT OeNB (253, 153, 153 Bp), DE § 247 BGB (227, 127, 127 Bp) – amtlich abgleichen; Berechnung act/365 je Halbjahr, half-up je Abschnitt | Werte aus Fachwissen der Prüfinstanz, nicht amtlich abgerufen | Release | intern geprüft 2026-10-16 (mittel) |
| P-S45 | Mahnkosten, Verzugszinsen und Pauschale als nicht umsatzsteuerbarer Schadenersatz (UStR Rz 9 AT, Abschn. 1.3 Abs 6 UStAE DE), Einnahme bei Zufluss mit 0 %, Kategorie „Sonstige Einnahmen“; Anrechnung nach § 1416 ABGB / § 367 BGB | Vorbefund Steuerberater: nicht steuerbar, Betriebseinnahme bei Zufluss | Release | intern geprüft 2026-10-16 (mittel) |
| P-S66 | Material und Werkzeug (FA-2.31): Konto SKR03 4985 (SKR04 6845) und BMD EKR 5300 passend? Auftragsmaterial eines Handwerksbetriebs eher Wareneinsatz (SKR03 3000/3400)? | Umgesetzt in 0.23.1: 4985, Kanzlei bucht bei Bedarf um | Release | offen |
| P-S46 | Bewirtung (FA-2.60): (a) AT Vorsteuer voll aus zur Hälfte abzugsfähiger Bewirtung (§ 12 Abs 2 Z 2 lit a UStG 1994, UStR 2000 Rz 1934)? (b) Regelfall AT 50 % ohne Rückfrage nach Werbezweck vertretbar? (c) Eintrag der nicht abziehbaren Bewirtung in E1a bzw. Anlage EÜR (eigene Kennzahl/Zeile?) (d) DATEV-Umbuchung 4654 an 4650 mit BU 40 und Bewirtungsnachweis DE mit Anlass/Teilnehmer als freiwillige Felder ausreichend? | Umgesetzt in 0.21.0: AT 50 %, DE 70 %, Vorsteuer voll, Hilfszeile ohne Kennzahl | Release | offen |
| P-S47 | Kleinunternehmer: Ausgaben brutto in der Einnahmen-Ausgaben-Rechnung, keine Vorsteuer (AT § 12 iVm § 6 Abs 1 Z 27 UStG 1994; DE § 19 Abs 1 UStG, § 9b Abs 1 EStG); Behandlung beim Wechsel des Status innerhalb eines Jahres | umgesetzt nach aktueller Einstellung (FA-3.2) | Release | intern geprüft 2026-10-16 (mittel) |
| P-S48 | DATEV: Buchung je Satz eines aufgeteilten Belegs ohne BU-Schlüssel auf ein Automatikkonto – richtig importiert, oder braucht es Schlüssel bzw. Konto je Satz? | eine Buchung je Satz, BU leer (8.3) | Release | offen |
| P-S49 | RKSV-Kassen-QR ab 01.07.2026: Feld „Betrag-Satz-Besonders“ trägt 19 % **und** 4,9 % gemeinsam; ist die Zuordnung über den Belegtext (Satzzeile) zulässig, und reicht der Vorrang des QR für Betrag und Datum gegenüber dem Text? Echten Beleg mit 4,9 % prüfen | „Besonders“ nicht aus dem Code bestimmbar (BMF-Hinweis im A-SIT-Mustercode-Repository 13.03.2026, fiskaly); App nimmt den Satz aus dem Text, sonst Rückfrage (FA-2.36); finale Detailspezifikation nicht abrufbar | Release | offen |
| P-S50 | DSFinV-K Anhang I: Reihenfolge der Bruttobeträge im TSE-QR (`Kassenbeleg-V1`, IDs 1–5: 19 %, 7 %, 10,7 %, 5,5 %, 0 %) und Dezimalpunkt; mit echtem deutschem Kassenbeleg gegenprüfen | aus Fachwissen, amtliche DSFinV-K nicht abgerufen (FA-2.35) | Release | offen |
| P-S51 | Steuerberatung: Plattform-Sammelbuchung je Monat nach Bruttoprinzip (Umsatz als Einnahme inkl. Versand/Aktionsrabatt abzüglich Erstattungen, Gebühren und Werbung als eigene Ausgaben, Auszahlung nicht gebucht) – genügt ein Sammelbeleg je Monat (Einzelaufzeichnung § 131 BAO / § 146 AO über den Bericht)? Umsatzsteuer der Verkäufe ohne Steuerspalte zum Normalsatz herausgerechnet; Datum = letzter Buchungstag im Monat (Zufluss vs. Leistung) | Befund Steuerberater (Bruttoprinzip) umgesetzt (FA-2.46); Normalsatz-Annahme und Datum unsicher | vor Release | offen |
| P-S52 | Steuerberatung: Reverse Charge für Amazon-Gebühren (Amazon EU S.à r.l.) auch beim Kleinunternehmer (AT § 19 Abs 1 zweiter Satz iVm § 3a Abs 6 UStG 1994; DE § 13b Abs 1/5 UStG, Abs 8) ohne Vorsteuerabzug; Kennzahlen AT Kz 057/066, DE Kz 46/47/67; Leistender der Amazon-Werbung (Amazon Online Services/Amazon EU bzw. Inlandsgesellschaft?) | umgesetzt (FA-2.46, FA-3.3); Kennzahlen aus Fachwissen, Formular nicht abgerufen | vor Release | intern geprüft 2026-10-16 (mittel) |
| P-S53 | Steuerberatung: OSS-Schwelle 10.000 € (Art 59c MwStSystRL; AT Art 3 Abs 5 UStG 1994; DE § 3c Abs 4 UStG) – Näherung Bestimmungsland über Amazon-Marktplatz bzw. Shopify-Lieferland ausreichend für eine Warnung? Lager in anderen Ländern (FBA Pan-EU/CEE) nur als Hinweis | umgesetzt als Warnung (FA-2.47) | vor Release | intern geprüft 2026-10-16 (mittel) |
| P-S54 | Steuerberatung: Gebühren von PayPal (Europe) S.à r.l. et Cie, S.C.A. (LU) als steuerfreier Finanzumsatz (Art 135 Abs 1 lit d MwStSystRL; AT § 6 Abs 1 Z 8 UStG 1994; DE § 4 Nr 8 Buchst d UStG) ohne Reverse Charge; Stripe (Stripe Technology Europe Ltd./Stripe Payments Europe Ltd., IE) und Shopify Payments (Shopify International Ltd., IE) als steuerpflichtige Leistung mit Reverse Charge – Leistender und Behandlung je Vertrag/Rechnung bestätigen | nicht gesichert recherchiert (Quellen der Anbieter nicht abrufbar); so umgesetzt (FA-2.46) | vor Release | offen |
| P-S55 | Spaltennamen und Typwerte mit echten Exporten je Sprache abgleichen: Amazon Transaktionsbericht DE/EN/FR/IT/ES, Abrechnung V2 (amount-type/-description), PayPal Aktivitäten DE/EN, Shopify, Stripe | nur synthetische Dateien (`test/fixtures/plattform/`), Spaltennamen nach Hilfeseiten und Fachwissen | vor Release | offen |
| P-S56 | Stornorechnung (GR-14): (a) gemeinsamer Nummernkreis für Rechnungen und Stornorechnungen zulässig und ausreichend (AT § 11 Abs 1 Z 3 lit c UStG, UStR Rz 1535 ff.; DE § 14 Abs 4 Nr. 4 UStG, Abschn. 14.5 Abs 10 UStAE)? (b) Pflichtinhalt: Bezug Nummer und Datum, negative Beträge je Satz, Grund – genügt das als Berichtigung (§ 31 Abs 5 UStDV, Abschn. 14.11 UStAE) bzw. Rechnungsberichtigung AT? (c) § 14c UStG DE / § 11 Abs 12 UStG AT: Berichtigung des Steuerausweises erst mit Zugang beim Empfänger – reicht der Hinweis „PDF senden“? (d) Buchung: bezahlt → negative Einnahme je Satz am Rückzahlungstag (Ist-Versteuerung, § 17 UStG DE, § 16 UStG AT); offen → keine Buchung; bei Soll-Versteuerung wäre der Stornomonat maßgeblich (nicht abgebildet) | Vorbefund Steuerberater: Stornorechnung mit eigener Nummer und Bezug ist Praxis in AT und DE; ein Nummernkreis zulässig; Ist-Prinzip passt zur EAR. Rz-Fundstellen AT nicht am Volltext verifiziert | Release | intern geprüft 2026-10-16 (mittel) |
| P-S57 | Steuerberatung: Kennzahlen der Voranmeldung (FA-14.2, FA-14.5): AT U30 Kz 000, 022 (20 %), 006 (13 %), 029 (10 %), 124 (4,9 % ab 07/2026), 016 (Kleinunternehmer), 057/066, 060, 095; DE UStVA Kz 81, 86 (volle Euro), 46/47/67, 66, 83. Muss ein Kleinunternehmer nur wegen Reverse Charge eine UVA/UStVA abgeben (AT § 21 UStG, DE § 18 Abs 4a UStG), und mit Kz 000/016? Welche Kennzahl für 0 %-Umsätze eines Regelbesteuerten (App sperrt die Datei)? | Kz-Positionen aus der BMF-XSD 07_2026; Bedeutung von Kz 124 als 4,9 % aus Lage nach Kz 022 und Gesetzesänderung abgeleitet, Formular nicht abgerufen | Release | offen |
| P-S58 | Steuerberatung: Jahreszahlen (FA-14.6) – AT E1a Kz 9040 für Betriebseinnahmen auch als Kleinunternehmer; DE Anlage EÜR Kz 111/112, 140, 185 für das aktuelle Formularjahr; reicht „Betriebsausgaben gesamt, nach Art aufteilen“ oder soll die App Kategorien Kennzahlen zuordnen? | aus Fachwissen, Formulare nicht abgerufen; Kz 9040 im BMF-XSD Jahreserklärungen vorhanden | Release | offen |
| P-S59 | Steuerberatung: Anlagen-Katalog und Regeln (FA-15.2 bis FA-15.4): AT Nutzungsdauern Computer 3, Software 3, Büromöbel 10, Maschinen/Werkzeuge 5 (Praxiswerte), PKW 8 (§ 8 Abs 6 EStG); DE Computer/Software 1 (BMF 22.02.2022 – voll im Anschaffungsjahr oder monatsgenau?), Büromöbel 13 (AfA-Tabelle AV 6.15), PKW 6 (4.2.1), Maschinen/Werkzeuge 5; GWG-Grenze AT 1.000 € beim Kleinunternehmer brutto (nicht abziehbare USt in den AK)? DE 800 € stets netto (§ 6 Abs 2 S 1 EStG); Sammelposten je Gut statt einheitlich je Wirtschaftsjahr zulässig als Vereinfachung? | aus Fachwissen und Gesetzestext, amtliche Seiten nicht abgerufen | Release | offen |
| P-S60 | Steuerberatung: Ausscheiden (FA-15.6) – AT im Abgangsjahr keine AfA, ganzer Restbuchwert als Abgang (oder anteilige/halbe AfA?); DE AfA bis Monat des Abgangs (R 7.4 Abs 8 EStR); Verkaufserlös als Betriebseinnahme mit USt zum Normalsatz; kein Erinnerungswert bei E/A in AT und DE; Anschaffungskosten des Kleinunternehmers brutto | Vorbefund Steuerberater: Summenwirkung im Abgangsjahr gleich, nur Aufteilung AfA/Restbuchwert offen | Release | offen |
| P-S61 | Steuerberatung: Saldenliste und vorläufiger Jahresabschluss (FA-15.9, FA-15.10) – brauchbar als Übergabe an die Kanzlei? Gliederung, Kennzeichnung „VORLÄUFIG“, ZIP mit Belegliste und DATEV/BMD | Musterbericht mit Testdaten erzeugen und vorlegen | Release | offen |
| P-S62 | Steuerberatung: Aufbewahrung von Verträgen (FA-16.7) – AT 7 Jahre ab Ende des Kalenderjahres (§ 132 Abs 1 BAO, bei Grundstücken länger), DE 10/8/6 Jahre je nach Unterlage (§ 147 Abs 3 AO): passt eine Frist aus `retentionYears` ab Vertragsende bzw. letzter Buchung? Leasing beim Kleinunternehmer und bei E/A nur als Ausgabe (Handbuch) | aus Fachwissen; Sonderfälle Grundstücke und Darlehen nicht abgebildet | Release | intern geprüft 2026-10-16 (mittel) |
| P-S64 | Basis ohne Anlagen (FA-13.2): eine Ausgabe über der GWG-Grenze wird voll als Betriebsausgabe gebucht; die Nutzerin muss selbst aktivieren und das Anlagenverzeichnis führen. Genügt der Hinweis am Beleg? Folgen bei Betriebsprüfung (Gewinnkorrektur, Verzeichnis fehlt) und ob die Übersicht den Gewinn ohne Pro als „vorläufig“ kennzeichnen soll | Vorbefund Steuerberater: Gewinn ist dann zu niedrig; Hinweis notwendig, nicht hinreichend | Release | offen |
| P-S63 | Steuerberatung: **bildliche Übereinstimmung** bei Belegen aus dem Dokumentenscanner (FA-2.51) – gespeichert wird nur das entzerrte, zugeschnittene und gefilterte Bild (Entscheidung Auftraggeberin). Ab 0.21.1 zusätzlich eigene Nachbearbeitung (Tonwertkorrektur, Aufhellen, Nachschärfen; fast farblose Belege in Graustufen) – reicht das, auch wenn ein schwach farbiger Stempel dadurch grau wird? Genügt das der Aufbewahrung „bildlich übereinstimmend“ (AT § 132 Abs 2 BAO, DE § 147 Abs 2 AO iVm GoBD Rz. 136 ff., Ersetzendes Scannen)? Braucht es eine Verfahrensdokumentation zum Scanvorgang? | Vorbefund Steuerberater: Perspektivkorrektur und Kontrastverbesserung üblich und zulässig, solange Inhalt vollständig und lesbar; Filter dürfen nichts entfernen (Stempel, Vermerke) | Release | intern geprüft 2026-10-16 (mittel) |
| P-L12 | Anwältin: Diktat über die Systemtastatur – Anbieterin nicht verantwortlich, Hinweistext genügt | — | Release | intern geprüft 2026-10-16 (mittel) |
| P-L13 | Gerätetest, nur bei eigener Spracherkennung: Erkennung im Flugmodus | — | später | offen |
| P-L14 | Anwältin: Rollen beim Vertragsarchiv mit KI (Anbieterin als Auftragsverarbeiterin), Muster-AVV, Rechtsgrundlage Beschäftigtendaten | — | Stufe C | offen |
| P-L15 | Anwältin bzw. Datenschutzberatung: DSFA und TIA; DPF-Zertifikat, Zero Data Retention und Speicherdauer bei Anthropic verifizieren | — | Stufe C | offen |
| P-L16 | Anwältin: KI-Ausgabetexte zu Verträgen auf RDG, RAO und UWG | — | Stufe C | offen |
| P-L17 | Anwältin: Art. 50 AI Act (Kennzeichnung) und aktuelle Fristen | — | Stufe C | offen |
| P-L18 | Anwältin: Lizenzpflichten ML Kit (Google APIs / ML Kit Terms), Lizenznennung in der App | — | Release | offen |
| P-L19 | Anwältin: Schriftlizenz Work Sans (SIL OFL 1.1) für in PDFs eingebettete Teilmengen und Auslieferung in der App; Lizenznennung | `assets/fonts/OFL.txt` liegt bei; OFL erlaubt Einbetten und Bündeln | Release | intern geprüft 2026-10-16 (hoch) |
| P-L20 | Menü „Rechtliches“ (FA-11.4, FA-11.5): genügt die Darstellung (Impressum, Datenschutz, Nutzungsbedingungen offline in der App, Support-Mail) den Pflichten aus § 5 ECG, Art. 13 DSGVO und den Store-Vorgaben (Google Play Datenschutzerklärung in der App, Apple 5.1.1)? Entwurfsvermerk: im Testbuild sichtbar, im Store-Build nicht – Voraussetzung ist P-L1 (Texte final, `LegalDocument.reviewed = true`) | Vorbefund Rechtsanwalt: ein „Entwurf“-Vermerk in der veröffentlichten App wäre widersprüchlich und angreifbar (UWG, Transparenz); deshalb nur bis P-L1. Zusätzlich muss die Datenschutzerklärung unter einer öffentlichen URL stehen (Store-Pflicht) | Store-Einreichung | offen |
| P-R10 | Öffentliche Händleradresse und Telefon (DSA-„Trader"-Angaben) festlegen, identisch mit dem Impressum | Postfach reicht nicht; Geschäftsadresse ratsam | erster Upload | intern geprüft 2026-10-16 (mittel) |
| P-R11 | Nutzungsbedingungen als eigene EULA (Apple) bzw. verlinkt (Google): Gewährleistung und Regress, Rolle der Stores, Herabstufung/Nur-Lese-Modus, Volljährigkeit | — | Release | offen |
| P-R12 | Wortlaut der Abo- und Testseite (§§ 312j, 312k BGB, PAngV, Apple 3.1.2); greift § 312k bei Store-Abos? | h. M.: nein, Sprung in die Store-Verwaltung genügt | Release | offen |
| P-R13 | Finaler Store-Text und Screenshots auf UWG und „keine Steuerberatung" | — | vor jeder Einreichung | offen |
| P-R14 | App Privacy Labels und Data Safety zu Käufen ohne Dritt-SDK | Käufe nur über die Stores, nicht „erhoben" | erster Upload | offen |
| P-R15 | Anwältin: Haftung und Hinweispflicht bei Datenverlust durch verlorenen Wiederherstellungscode (AT/DE, B2B/B2C) | — | Release | offen |
| P-R16 | Anwältin: Affiliate- bzw. Influencer-Vertrag, Werbekennzeichnung (§ 6 ECG, UWG), Mithaftung | — | vor erster Aktion | offen |
| P-R17 | Anwältin: Preisangaben bei Gratisphase und Jahresrabatt (PAngV, PrAG, Omnibus-RL) | — | Release | offen |
| P-R18 | Anwältin: EZB-Nutzungsbedingungen; datenschutzrechtliche Einordnung des Kursabrufs (IP-Adresse) | Abruf nur auf Knopfdruck, nur IP-Adresse, offengelegt in PRIVACY, 5.19, STORE_LISTING; Hinweis „EZB-Referenzkurs, ohne Gewähr“ | vor Fremdwährung | intern geprüft 2026-10-16 (mittel) |
| P-R19 | Anwältin: ML-Kit-Telemetrie laut aktueller Google-Doku, Opt-out, Angaben in Play Data Safety und Apple Privacy Label | Entscheidung ML Kit 2026-10-12 | Release | offen |
| P-R20 | Anwältin: Haftungsbegrenzung bei Fehlerkennung in den Nutzungsbedingungen (KSchG, BGB) | — | Release | offen |
| P-R22 | Google Play: wird ein eingetragenes Einzelunternehmen (e.U.) als Organisationskonto angenommen? Welche Nachweise (D-U-N-S, Firmenbuchauszug)? | Organisationskonto erspart den 14-Tage-Test mit 12 Testerinnen | vor Kontoanlage | offen |
| P-R23 | Apple: Anmeldung als Einzelperson (Einzelunternehmen ist laut Apple keine Organisation); Verkäufername im Store = persönlicher Name; Migration bei späterer GmbH | Apple Account Help D-U-N-S | vor Kontoanlage | intern geprüft 2026-10-16 (mittel) |
| P-R24 | Termin-Box: Formulierung „Berechnete Termine zur Orientierung, ohne Gewähr. Maßgeblich sind Bescheid, Finanzamt bzw. deine Steuerberatung.“ – genügt das gegenüber Verbraucherinnen/Unternehmerinnen (Haftung für falsch berechnete Fristen, AGB/Nutzungsbedingungen)? | Hinweis sichtbar unter jeder Termin-Box (FA-10.4); Nutzungsbedingungen noch nicht ergänzt | Release | offen |
| P-R25 | Hilfe Stufe 2 (KI-Antworten): Abgrenzung zur Hilfeleistung in Steuersachen (StBerG DE, WTBG AT), Haftung für falsche Antworten, Kennzeichnung als KI (Art. 50 KI-VO) | noch nicht gebaut (FA-11, Lastenheft L-26.6) | vor Stufe 2 | offen |
| P-R26 | Hilfe Stufe 2: Übermittlung der Frage an einen Server bzw. KI-Anbieter – Rechtsgrundlage, Auftragsverarbeitung, Drittlandtransfer, Eintrag in Datenflusstabelle und Store-Angaben | noch nicht gebaut | vor Stufe 2 | offen |
| P-R30 | AGB-Verweis auf der Rechnung: Wortlaut „Es gelten unsere Verkaufsbedingungen, abrufbar unter <URL>, soweit sie vereinbart wurden.“ – irreführend oder unbedenklich? Genügt der einmalige Hinweis an die Nutzerin, dass der Verweis allein AGB nicht einbezieht (§ 864a ABGB, § 305 Abs 2 BGB; B2B kaufmännisches Bestätigungsschreiben)? | Rechnung kommt nach Vertragsschluss, Verweis bezieht AGB nicht ein; Zusatz „soweit vereinbart“ vermeidet Irreführung | Release | intern geprüft 2026-10-16 (mittel) |
| P-R31 | Rabatt- und Skontoangaben auf Rechnungen an Verbraucherinnen: Preisangaben (PAngV, PrAG), Klarheit des Skontotexts mit festem Datum und Betrag | unbedenklich, da reine Zahlungsbedingung | Release | intern geprüft 2026-10-16 (mittel) |
| P-R32 | Mahnkosten 10 € je Mahnung (Entscheidung der Auftraggeberin): B2C nur angemessene, tatsächliche Kosten (AT § 1333 Abs 2 ABGB; DE §§ 280, 286 BGB, erste verzugsbegründende Mahnung nicht ersatzfähig, Rechtsprechung ca. 1–3 €). Genügt der Hinweis in der App, Entscheidung bei der Nutzerin? | Vorbefund Rechtsanwalt: 10 € gegenüber Verbrauchern regelmäßig zu hoch; Hinweis umgesetzt (FA-5.22) | Release | intern geprüft 2026-10-16 (mittel) |
| P-R33 | Wortlaut der Zahlungserinnerung und Mahnung (sachlich, ohne Drohung, UWG/§ 4a UWG, KSchG), Hinweis § 286 Abs 3 BGB auf DE-Verbraucherrechnungen | Texte in `DunningService.bodyText`, `TaxProfile.dunning.consumerDefaultNotice` | Release | offen |
| P-R34 | Pauschale 40 € (§ 458 UGB, § 288 Abs 5 BGB) nur B2B, Anrechnung auf Rechtsverfolgungskosten; Verzugszinsen ohne Vereinbarung erst ab Verzug (DE: Mahnung oder 30 Tage mit Hinweis) | umgesetzt als Vorschlag, Entscheidung bei der Nutzerin | Release | intern geprüft 2026-10-16 (hoch) |
| P-R35 | Link-QR (FA-2.42): Abruf beim Server des Rechnungsausstellers auf Tippen – Rolle der Nutzerin bzw. des Anbieters (DSGVO), Offenlegung in Datenschutzerklärung und Google Data Safety/Apple Label (Datenerhebung durch die App ja/nein), Warnhinweis gegen Phishing ausreichend? | keine Daten aus der App, nur Adresse/IP an die gezeigte Domain; Domain groß, Wechsel nur nach erneuter Anzeige, kein Login in der App | erster Upload | offen |
| P-R36 | Plattformimport (FA-2.49): Käuferdaten (Name, Adresse, E-Mail, Telefon) werden verworfen; bleiben Bestellnummern und Bestimmungsland (Aggregat) zulässig (Art 5 Abs 1 lit c DSGVO)? Rolle der Nutzerin gegenüber Käuferdaten in der geteilten Datei (Cache) | Test über alle Tabellen (`platform_import_test.dart`); keine Übertragung | erster Upload | intern geprüft 2026-10-16 (mittel) |
| P-R37 | Abo (FA-13.5, FA-13.6): (a) Pflichttext der Abo-Seite vollständig und richtig für AT/DE-Verbraucherinnen (§ 312j Abs 2 BGB wesentliche Merkmale, Laufzeit, Verlängerung; § 4 FAGG; Apple 3.1.2; Google Play Abo-Richtlinie: Testdauer, Folgepreis, Kündigungsweg)? (b) Store-Abfrage und Kaufblatt als Datenfluss: Einordnung in Google Data Safety („Käufe – Kaufverlauf“, erhoben vom Store, nicht von der App?) und Apple Label („Käufe“, nicht mit Identität verknüpft?) | Vorbefund Rechtsanwalt: Verkäufer und Verantwortlicher für Kaufdaten sind Apple bzw. Google; die App erhebt keine Kaufdaten, verarbeitet aber den Abostatus am Gerät. Vorsorglich als „Käufe/Kaufverlauf, App-Funktion, nicht geteilt“ angeben. Der frühere Store-Text „Ohne Abschluss eines Abos endet der Test von selbst“ passte nicht zum Store-Test (läuft in das Abo über) und wurde berichtigt (§ 5 UWG, § 2 UWG AT) | Store-Einreichung | offen |
| P-R40 | Instagram-Werbung für den Promo-Code (Textvorschlag `STORE_LISTING.md`): „2 Monate gratis“ nur mit Folgepreis, automatischer Verlängerung und Kündbarkeit im selben Beitrag (§ 5a UWG DE, § 2 Abs 4 / Anhang Z 20 UWG AT; „gratis“-Werbung), Kennzeichnung als Werbung bei bezahlten Beiträgen Dritter (§ 5a Abs 4 UWG DE, § 6 TMG bzw. § 6 DDG, § 6 ECG AT, § 26 MedienG AT); Instagram-Bezeichnung „Bezahlte Partnerschaft“ | Vorbefund Rechtsanwalt: Textvorschlag nennt Preis, Verlängerung, Kündbarkeit und „Neukunden“; eigene Beiträge der Firma sind erkennbar Werbung, Influencer-Beiträge brauchen „Werbung“/„Anzeige“ am Anfang. Mittlere Sicherheit | vor der ersten Kampagne | offen |
| P-R41 | Vertragsarchiv-Kurzübersicht (FA-16.3): reicht „nur Fundstellen, keine rechtliche Prüfung“ für die Grenze L-23.6 (keine Rechtsberatung nach RAO/RDG)? Wortlaut der Hinweise; Fristberechnung „Kündigen bis“ als reine Rechenhilfe ohne Gewähr (Zugang, Quartalsende, Verlängerungsklauseln) | Vorbefund Rechtsanwalt: zulässig als Auszug ohne Bewertung; Hinweis auf fehlende Gewähr für Fristen empfohlen | Release | offen |
| P-R43 | Anlagen nur in Pro (Entscheidung Auftraggeberin 2026-10-16, FA-13.2) entgegen Lastenheft 5.10 „gesetzliche Pflicht nie nur in Pro“: Ist es irreführend (§ 5 UWG DE, § 2 UWG AT) oder ein Mangel (§ 327e BGB, VGG), wenn Basis eine Buchhaltung anbietet, die das Pflichtverzeichnis (§ 7 Abs 3 EStG AT, § 4 Abs 3 Satz 5 EStG DE) nicht führt? Reicht der Hinweis am Beleg und in Store-Text/Handbuch? | Vorbefund Rechtsanwalt: vertretbar bei klarer Angabe im Tarifvergleich und Hinweis am Beleg; Daten bleiben zugänglich | Release | offen |
| P-R42 | Datenschutz Dokumentenscanner Android (FA-2.51): Google Play-Dienste laden das Scanner-Modul und können Nutzungs-/Diagnosedaten senden; Angaben in PRIVACY und Google Data Safety ausreichend? Auftragsverarbeitung/Rolle Google wie bei ML Kit (P-R19) | Vorbefund: Bilder bleiben laut Google auf dem Gerät; Telemetrie wie gebündeltes ML Kit offenlegen | Release | offen |
| P-R44 | Datenschutz Diktat (FA-2.61): Audio wird nur vom Spracherkennungsdienst des Systems auf dem Gerät verarbeitet (Android: Systemdienst, z. B. „Speech Services by Google“; iOS: Apple, `requiresOnDeviceRecognition`); die App überträgt nichts. Genügt die Offenlegung in PRIVACY (Berechtigung Mikrofon/Spracherkennung) und die Store-Angabe „Audio nicht erhoben“? Kann der Systemdienst selbst Diagnosedaten senden (Rolle Google/Apple)? | Vorbefund: keine Erhebung durch die App, Systemdienst in PRIVACY nennen | Release | offen |
| P-R46 | Mithelfer-Geräte (FA-17.x): (a) Mithelfer (Familie, Beschäftigte) handeln für die Inhaberin, die Verantwortliche bleibt; bei Beschäftigten Hinweis nach Art. 13 DSGVO bzw. Mitbestimmung (§ 87 Abs 1 Nr 6 BetrVG, § 96/96a ArbVG) nötig? (b) Übertragung über einen von der Nutzerin gewählten Messenger bzw. Cloud-Ordner als „nicht erhoben durch die App“ für Google Play und Apple; (c) Hinweis „Code nur dem eigenen Gerät zeigen“ ausreichend | Rechtsanwalt intern: (a) Inhaberin Verantwortliche, Mithelfer weisungsgebunden, Hinweis im Handbuch; (b) wie Export/Teilen nicht erhoben, mittel; (c) ja, mittel | Release | offen |
| P-R47 | Mailweg (FA-17.9 bis FA-17.12): (a) Beschäftigte nutzen ihr **eigenes Postfach** (privat oder dienstlich) zum Senden – genügt die einmalige Zustimmung beim Einrichten samt Handbuchhinweis, oder braucht es eine Vereinbarung/Betriebsvereinbarung (§ 87 Abs 1 Nr 6 BetrVG, § 96a ArbVG)? (b) Lesender IMAP-Zugriff des Hauptgeräts auf die Geschäftsadresse: Hinweis an Absender anderer Mails nötig (es werden nur Kopfzeilen gekennzeichneter Mails gelesen)? (c) Store-Datensicherheit: Übertragung an Mailanbieter der Nutzerin als „nicht erhoben“ (wie Teilen), Abruf der Domain bei Mozilla ISPDB offenlegen; (d) Datenschutzerklärung ergänzt | Rechtsanwalt intern: (a) Einwilligung plus Handbuchhinweis vertretbar, bei Beschäftigten Mitbestimmung prüfen, mittel; (b) nein, Zweckbindung über Kennzeichen, mittel; (c) ja wie Teilen, Domain-Abruf offenlegen, mittel; (d) ja | Release | offen |
| P-R48 | Google-OAuth (`gmail.send`, eingeschränkter Bereich) und Microsoft Graph `Mail.Send`: Bedingungen der OAuth-Verifizierung (Google CASA-Sicherheitsprüfung für restricted scopes, Datenschutzerklärung auf eigener Domain, Demo-Video) und Microsoft Publisher Verification – Kosten und Pflichten vor dem Bau klären | nicht gebaut (Lastenheft 14a, offener Punkt) | vor Bau | offen |
| P-R55 | Demo (FA-13.14): genügt das schräge Wasserzeichen „MUSTER – DEMO“ auf jeder PDF-Seite samt gesperrtem Teilen, damit kein Muster als echte Rechnung oder Unterlage verwendet werden kann (§ 11 UStG AT, § 14 UStG DE, § 2 UWG AT, § 5 UWG DE)? Braucht die Demo vor den Bestätigungen einen eigenen Hinweis, oder reichen die bestätigten Nutzungsbedingungen? | Vorbefund Rechtsanwalt: ja – Wasserzeichen, Titel „MUSTER – DEMO“ in den Metadaten, Nullen-Platzhalter bei UID/IBAN und gesperrtes Teilen schließen eine Verwechslung praktisch aus; die Demo startet erst nach den Bestätigungen | Store-Einreichung | offen |
| P-R56 | Erfundene Namen der Demo („Muster Handel e.U.“, „Maria Muster“, „Beispiel Bau GmbH“, „Musterfirma Nord GmbH“, „Anna Probe“, Händler wie „Tankstelle Am Ring“, „Baumarkt Huber“, „Gasthaus Zur Linde“, Liste `DemoDataset.merchants`): Kollision mit eingetragenen Firmen (Firmenbuch AT, Handelsregister DE) oder Marken (DPMA, EUIPO, ÖPA) ausschließen; Screenshots der Demo im Store ohne fremde Marken | Vorbefund Rechtsanwalt: Gattungsbegriffe mit Allerweltsnamen, keine Logos, Test prüft bekannte Handelsmarken; eine Namensgleichheit mit einem kleinen echten Betrieb ist nicht ausgeschlossen, Recherche kurz und billig | Store-Einreichung | offen |
| P-R57 | Test auf Basis und Pro mit „Pro inklusive in der Testzeit“ (FA-13.4, FA-13.5, O-42): Texte auf Abo-Seite, Startauswahl und im Store („14 Tage kostenlos testen – mit allen Pro-Funktionen. Danach gilt dein gewähltes Abo (Preis aus Store). Jederzeit vorher im Store kündbar.“, bei Basis „Nach dem Test gilt der Umfang von Basis.“) ausreichend nach § 5a UWG DE und § 2 Abs 4 / Anhang Z 20 UWG AT („gratis“), § 4 Abs 1 Z 4, 5, 13 FAGG und § 312j Abs 2 BGB (Preis, Laufzeit, Verlängerung vor dem Kauf), § 5 ECG, Apple Guideline 3.1.2 und Google-Play-Richtlinie zu Abos und Tests (Testdauer, Preis danach, Kündigung)? Ist der Hinweis 3 Tage vorher („Noch X Tage Pro inklusive – danach Basis. Jetzt auf Pro wechseln?“) ohne Nennung der Basis-Abbuchung zulässig? | Vorbefund Rechtsanwalt: Kern erfüllt – Dauer, Folgepreis aus dem Store je Karte, automatische Verlängerung, Kündigungsweg und Daten bleiben stehen vor dem Kaufknopf; das Kaufblatt des Stores wiederholt Preis und Testende. Risiko war, dass „mit allen Pro-Funktionen“ beim Basis-Abo den Umfang nach dem Test verschleiert (Irreführung über wesentliche Merkmale) – deshalb der Zusatz auf der Basis-Karte. Apple: ein Einführungsangebot je Gruppe, Wechsel auf Pro in der Testzeit sofort kostenpflichtig – das zeigt das Store-Blatt, ein eigener Satz im Handbuch | Store-Einreichung | offen |
| P-R58 | Bestätigungen (FA-1.10, L-17.2): genügt für die Nutzungsbedingungen der beschriftete Knopf „Akzeptieren und weiter“ mit Links auf den Volltext und dem Satz „Mit „Akzeptieren und weiter“: Ich akzeptiere die Nutzungsbedingungen und habe die Datenschutzerklärung zur Kenntnis genommen.“ (Einbeziehung § 305 Abs 2 BGB, § 864a ABGB; Datenschutzerklärung als Information Art 13 DSGVO), während „Keine Steuerberatung“ ein eigenes Häkchen behält? | Interne Prüfung: ja, Häkchen nur dort, wo L-17.2 Eigenständigkeit verlangt; Nachweis mit Zeitstempel und Fassung unverändert (`consents`) | Store-Start | offen |
| P-R59 | Abgabenschätzung (FA-19.x): Abgrenzung zur geschäftsmäßigen Hilfeleistung in Steuersachen (DE §§ 2, 5 StBerG; AT § 2 WTBG 2017, Vorbehaltsaufgaben § 2 Abs 1 WTBG): allgemeine Berechnung aus eigenen Buchungen mit gesetzlichen Tarifen, Kennzeichnung „Schätzung – ersetzt keine Steuerberatung“ auf Karte und Bildschirm, keine Einzelfallberatung, keine Übermittlung; Haftungsausschluss in Nutzungsbedingungen (Verbraucher: § 6 KSchG, §§ 307 ff. BGB – kein Ausschluss grober Fahrlässigkeit) | Vorbefund Rechtsanwalt: Werkzeug wie Steuerrechner (BGH I ZR 113/20 Smartlaw) – mittel; Werbeaussagen im Store ohne „berechnet deine Steuer“ | Store-Start | offen |
| P-R60 | Werbeaussage Willkommensseite und Store-Kurzbeschreibung (FA-1.13): „nach den Regeln, die auch Profis anwenden“ statt des gewünschten „mit der Qualität von Profis“; Funktionszeilen nur für Gebautes (E-Rechnungen werden empfangen/gelesen, nicht erstellt); „automatisch auslesen“ und „Saldenliste“ sind Pro – Hinweis auf Tarife in der Store-Beschreibung genügt? (§ 2 UWG AT, § 5 UWG DE) | intern geprüft 2026-10-19, mittel | vor Store-Start | offen |
| P-R61 | Funktionszeilen der Willkommensseite ab 0.31.0 gekürzt (einzeilig): „Belege scannen und auslesen“, „Rechnungen stellen, E-Rechnung lesen“, „Verträge und Fristen im Blick“, „Saldenliste und Jahresübersicht“ – nur Gebautes, kein „E-Rechnung schreiben“; deutsche Demo-Musterfirma „Muster Handel“ mit erfundenen Personen, Händlern und Platzhalternummern (wie P-R56) | intern geprüft 2026-10-19, mittel (§ 2 UWG AT, § 5 UWG DE) | vor Store-Start | offen |
| P-R62 | Preisdarstellung FA-13.16: Kopfzeile Einführungspreis mit gleich großem Folgepreis, Satz mit Zeitraum, automatischer Verlängerung, Testende und Kündigungsweg vor dem Kaufknopf; „Einführungspreis im ersten Jahr“ ohne „statt“-Preis ist keine Preisermäßigung im Sinn des § 11 PAngV (gilt zudem nur für Waren; AT § 9a PrAG ebenso); Gesamtpreis inkl. USt (§ 3 PAngV); wesentliche Merkmale vor der Bestellung (§ 312j Abs 2 BGB, § 4 FAGG), Bestellknopf „zahlungspflichtig“ stellt das Store-Kaufblatt (§ 312j Abs 3 BGB); Instagram-Texte in `STORE_LISTING.md` nennen Folgepreis, Verlängerung, Kündbarkeit und Zielgruppe (§ 5a UWG DE, § 2a UWG AT); unterschiedliche Angebote je Store (Apple ohne Test, siehe O-45) im Werbetext kenntlich | Prüfinstanz Rechtsanwalt 2026-10-19, mittel | vor der ersten Kampagne | offen |
| P-R63 | 20-%-Code `JENIBUCHT20`: „20 % Rabatt“ bezieht sich auf den Einführungspreis des ersten Jahres (55,20 € / 103,20 €), nicht auf den Grundpreis – Werbung muss die Bezugsgröße nennen (§ 5 UWG); auf Android ist das Rabattangebot technisch für alle sichtbar, die den Code kennen (kein Server) – zulässig, aber Zielgruppe „Neukundinnen“ dort nicht durchsetzbar (vom Auftraggeber am 2026-10-19 akzeptiert, O-46; Werbung mit `JENIBUCHT20PRO`). Neu seit O-45: auf dem iPhone ist der Preis ohne Code im ersten Jahr der Grundpreis (179 €), „103,20 € statt 129 €“ dort also nur zutreffend, wenn 129 € als Einführungspreis per Code (`JENIBUCHTSTARTPROJAHR`) tatsächlich angeboten wird – Bezugsgröße je Store prüfen. **Seit 2026-10-19 (Wortlaut Auftraggeber) ohne „statt“-Preis:** „Mit Code JENIBUCHT20PRO: 20 % auf das erste Jahr JeNi bucht Pro. Danach 179 €/Jahr, jederzeit kündbar.“ plus Endpreis mit Code (103,20 € bzw. Basis 55,20 €) und Pflichtzeilen (`STORE_LISTING.md`); offen bleibt, ob „20 % auf das erste Jahr“ ohne genannte Bezugsgröße genügt und ob der Endpreis mit Code in beiden Stores gleich eingerichtet ist | Prüfinstanz Rechtsanwalt/Softwareentwickler 2026-10-19, mittel | vor der Kampagne | offen |
| P-R65 | Buchungsregeln und Hilfeartikel (FA-20.x): Abgrenzung zur Hilfeleistung in Steuersachen (§§ 2, 5 StBerG; § 2 WTBG 2017) – die App rechnet mit dem Anteil, den die Nutzerin festlegt, Vorlagen sind Beispiele mit Fundstelle; Hinweis „Grundlage für die Steuerberatung – ersetzt keine individuelle Beratung“ in Formular, Hilfe, Bericht und CSV ausreichend? | Vorbefund Rechtsanwalt: zulässig als Werkzeug ohne Einzelfallempfehlung (wie P-R5); keine Aussage „ersetzt die Steuerberatung“. Sicherheit mittel | Release | offen |
| P-R66 | KI-Chat Stufe C (FA-20.8, L-21): Wortlaut „bereitet das Gespräch mit der Steuerberatung vor und spart Zeit“ statt „ersetzt ein Gespräch“ (§ 2 UWG AT, § 5 UWG DE, StBerG/WTBG); Vorschlag einer Regel durch KI als unzulässige Einzelfallberatung? Einwilligung, AVV, Drittlandtransfer, keine Art.-9-Daten, AI Act Art. 50 Kennzeichnung | Vorbefund: Vorschlag + Bestätigung durch Nutzerin mit Hinweis vertretbar, Formulierung des Auftraggebers zu ändern; vor Bau extern prüfen | Stufe C | offen |
| P-R64 | E-Rechnung (FA-5.49): Lizenz der mitgelieferten Dateien – Farbprofil sRGB2014.icc (ICC, frei weitergebbar, unverändert) in der App, Factur-X-XSD (FNFE-MPE/FeRD) und ebInterface-XSD (AUSTRIAPRO) nur in den Tests; Werbeaussage „Rechnungen & E-Rechnungen schreiben“ (Willkommensseite, Store) zulässig, obwohl E-Rechnung ausstellen Pro ist (Tarifhinweis in der Beschreibung); keine Zusicherung der Annahme durch Behördenportale | intern geprüft 2026-10-19, mittel (§ 2 UWG AT, § 5 UWG DE) | vor Store-Start | offen |
| P-R45 | „Wunsch oder Idee senden“ (FA-11.6): bestätigen, dass eine von der Nutzerin selbst aus ihrer Mail-App gesendete E-Mail mit technischen Angaben für Google Play („Datensicherheit“) und Apple („App-Datenschutz“) nicht als Erheben durch die App gilt; sonst Angaben in STORE_LISTING anpassen | Rechtsanwalt intern: nicht erhoben (wie Teilen/Export), mittel | Release | offen |
| P-R39 | Angebots-PDF: „Dieses Angebot ist gültig bis <Datum>“ bindet die Unternehmerin bis zu diesem Tag (§ 148 BGB Annahmefrist; AT § 862 ABGB). Reicht das, oder braucht es eine Option „freibleibend“/„unverbindlich“? | Vorbefund Rechtsanwalt: Fristsetzung ist zulässig und schafft Klarheit; „freibleibend“ wäre nur eine Aufforderung zur Angebotsabgabe. Frage, ob Nutzerinnen das wählen können sollen. Mittlere Sicherheit | Release | intern geprüft 2026-10-16 (hoch) |
| P-R38 | Jahresabo und automatische Verlängerung um ein weiteres Jahr gegenüber deutschen Verbraucherinnen: § 309 Nr. 9 BGB (seit 1.3.2022 stillschweigende Verlängerung nur auf unbestimmte Zeit mit Monatskündigung) – greift das bei Store-Abos, deren Vertragsbedingungen Apple bzw. Google stellen, oder trifft es den Anbieter über die Nutzungsbedingungen 4.3? Ebenso § 312k BGB (P-R12) | Vorbefund Rechtsanwalt: Verkäufer ist der Store, dessen Verlängerungsmechanik gilt; Nutzungsbedingungen 4.3 beschreiben sie nur. Restrisiko, wenn der Anbieter als Vertragspartner der Leistung gilt; Alternative wäre ein Hinweis „Jahresabo jederzeit zum Periodenende kündbar“. Mittlere Sicherheit | Store-Start | offen |
| P-S11 | USt-Kette der Store-Abos: Leistung an Apple/Google in Irland, Reverse Charge, UID, ZM, UVA; gelten die Store-Abrechnungen als Gutschrift (§ 11 Abs 7 UStG AT)? | Kette sicher, Rechnungsstellung offen | erster Verkauf | offen |
| P-S12 | Vorsteuerabzug für Unternehmerinnen aus Store-Quittungen | unklar; kein Versprechen in App oder Werbung | erster Verkauf | offen |
| P-S13 | Verbuchung der Store-Auszahlungen (netto als Erlös empfohlen, Zufluss/Abgrenzung, Fremdwährung), W-8BEN(-E) | — | erster Verkauf | offen |
| P-S14 | Zählen Store-Umsätze (Leistungsort Irland) zur Kleinunternehmergrenze des Anbieters? Zusammen mit O-26 | voraussichtlich nein | erster Verkauf | intern geprüft 2026-10-16 (mittel) |
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
| P-D30 | Store-Produkte anlegen (STORE_ANMELDUNG.md Abschnitt Abo): eine Abogruppe, IDs `basis_monat`, `basis_jahr`, `pro_monat`, `pro_jahr` exakt wie im Code, Preise nach Lastenheft 5.10, Einführungsangebot 14 Tage gratis auf **allen vier** Produkten (O-42), Grace Period an; Verträge für kostenpflichtige Apps, Bank- und Steuerdaten; Store-Build mit `--dart-define=LICENSING=true` (CI-Release-Workflow) | Code erwartet genau diese IDs (`spec.license_product_ids`); ohne Schalter läuft jeder Build als Testversion | Store-Start | offen |
| P-D32 | Promo-Code in beiden Stores anlegen (`STORE_ANMELDUNG.md` Formular 4, Abschnitt Promo-Code) und einlösen: Android über die Abo-Seite und über `https://play.google.com/redeem?code=JENIBUCHT2M`, iOS über das Einlöseblatt und über den App-Store-Link mit echter Apple-ID der App (`id=<APP_ID>` ersetzen); Pro aktiv nach Rückkehr, Erinnerung zum Ende der 2 Monate, Kündigung in der Gratiszeit kostenlos | Logik mit Store-Ersatz getestet (`licensing_test.dart`); Apple-ID der App existiert noch nicht | vor der ersten Kampagne | offen |
| P-D33 | Lernen je Lieferant an echten Belegen: zweiter Bon desselben Händlers (andere Filiale, schlechteres Foto) wird erkannt und vorbelegt; keine falsche Zuordnung bei ähnlichen Namen (z. B. „Billa“ / „Billa Plus“) | Unit-Tests mit Varianten | vor Release | offen |
| P-D34 | Store-Screenshots mit den Demodaten aus `STORE_LISTING.md` aufnehmen (Android 1080×1920, iPhone 6,9", iPad 13"), Inhalt gegen Werbe-Negativliste prüfen; optional automatisiert über `integration_test` (Plan dort) | nur Plan und Demodaten | erste Einreichung | offen |
| P-D35 | U30-Datei beim BMF prüfen: Upload einer Testdatei in FinanzOnline (Eingaben → Übermittlungen → Upload, bzw. Test-Upload), Annahme ohne Fehler für Monat und Quartal, Kleinunternehmer mit Reverse Charge; Menüpfad im Handbuch bestätigen; Stand der XSD vor jedem Release mit den BMF-Seiten „Informationen für Softwarehersteller“ abgleichen | XML gegen XSD 07_2026 (Kopie aus github.com/FlorianRauscha/fon-api, BMF-Seite gesperrt) mit `xmllint` gültig | Release | offen |
| P-D36 | Vertragsarchiv auf Pixel 10 und iPhone: mehrseitiges PDF teilen (Seitenbilder, Original), Texterkennung über mehrere Seiten, Kurzübersicht an einem echten Miet- und Leasingvertrag (Treffer und Fundstellen stimmen), Sicherung und Wiederherstellung mit Vertragsseiten | Heuristik nur an synthetischem Text geprüft | Release | offen |
| P-D37 | Android-Gerätetest Dokumentenscanner (Pixel 10, Release-Build mit R8): Modul-Download beim ersten Start, mehrseitiger Scan, Galerie-Import, Ergebnis in Belegseiten und Texterkennung; Gerät/Emulator ohne Play-Dienste bzw. Huawei → Kamera ohne Rückfrage | nur CI-Build | Release | offen |
| P-D42 | Gerätetest Mithelfer ab 0.23.1, **gemischt in beide Richtungen**: (1) Pixel als Hauptgerät, iPhone als Mithelfer; (2) iPhone als Hauptgerät, Android als Mithelfer. Je Richtung: QR in der App fotografieren und koppeln; Beleg über das Teilen-Blatt (iPhone: `UIActivityViewController`, auch iPad) per WhatsApp/Signal/Mail senden; auf dem Hauptgerät Datei antippen → „Öffnen mit JeNi bucht“ (Android) bzw. „Öffnen in JeNi bucht“ aus Mail, WhatsApp und Dateien (iOS, ohne Umweg über „In Dateien sichern“) → Eingang; Weg Ordner über Google Drive, OneDrive oder Dropbox, den beide Systeme zeigen (iCloud Drive nur iPhone–iPhone), Hinweis sichtbar; nach Übernahme „übernommen“ beim Mithelfer; Trennen → nächstes Paket abgelehnt; Bilder auf dem Mithelfer nach dem Senden gelöscht | Tests mit Ordner-Ersatz und Teilen-Rückruf (`helper_devices_test.dart`) | Release | offen |
| P-D43 | Gerätetest OMV-Beleg ab 0.23.2 (FA-2.62): Originalbon Dobl (Kaiserwald) mit Kamera, Dokumentenscanner und als geteiltes Foto erfassen; erwartet 8,96 € mit 7,96 € zu 20 % (Netto 6,64, Steuer 1,32) und 1,00 € zu 0 %, Vermerk „vom Kassen-QR“, Händler „OMV Tankstelle“, Kategorie nicht Kfz-Kosten; zusätzlich ML-Kit-Ergebnis als Korpus-JSON aus dem CI-Job übernehmen | `receipt_omv_test.dart`, Korpus `erwartet.json` | Release | offen |
| P-D44 | Gerätetest Mailweg ab 0.24.0: (1) Hauptgerät Pixel mit Geschäftsadresse bei einem AT-Anbieter (z. B. World4You, A1) über Autoconfig, dann mit Gmail-App-Passwort; (2) Mithelfer iPhone mit iCloud-App-Passwort und Android mit Gmail-App-Passwort; je zwei Belege erfassen, App schließen, am nächsten Tag ohne Öffnen prüfen, ob die Mail gesendet wurde (Android WorkManager; iOS bestmöglich) und ob sie binnen einer Stunde im Eingang liegt; Mail im Postfach bleibt ungelesen und unverschoben; dieselbe Mail weiterleiten → kein doppelter Beleg; Mithelfer ohne Postfach: Mitteilung „Belege senden“ einmal am Tag, Antippen öffnet Mailfenster mit Anhang (Android Gmail, iOS Apple Mail); falsches App-Passwort → Meldung, Belege warten; Trennen → nächste Mail abgelehnt; Aufbewahrung 30 Tage wählen | `helper_mail_test.dart` mit Ersatzserver, `helper_mail_ui_test.dart` | Release | offen |
| P-D45 | Gerätetest 0.25.0: Update von 0.24.0 mit vorhandenen Belegen (Migration 26 → 27), DE-Registrierung anlegen, Amazon-Abrechnung (FBA amazon.de) importieren → Sammelbuchung „(DE)“, „Für das Finanzamt“ DE zeigt Kz 81/66, Termin-Box „DE · UStVA …“; Datensicherung wiederherstellen | Migration und Rechnung mit Tests geprüft; Gerät offen | Release | offen |
| P-D46 | Testzeit am echten Gerät (FA-13.4, O-42): Android – Basis mit Einführungsangebot kaufen → sofort alle Pro-Funktionen, Hinweis „Noch 3 Tage Pro inklusive …“ an Tag 11, ab Tag 15 Basis (Lizenztester mit verkürzter Testdauer); App neu installieren → Fenster ab dem `purchaseTime` des Abos, nicht neu; Konto, das schon getestet hat (Play bietet keinen Test) → Näherung dokumentieren. iOS (Sandbox/TestFlight) – Basis mit Einführungsangebot → `offerType` 1 → Pro; nach der ersten Verlängerung → Basis | Logik mit Store-Ersatz getestet (`licensing_test.dart`: Android-Fenster, iOS-Kennzeichen, Neuinstallation); `jsonRepresentation`-Felder von StoreKit 2 nur aus der Dokumentation | Store-Start | offen |
| P-D47 | Einführungsangebot je Abogruppe (Apple) und Wechsel in der Testzeit: Basis getestet → Pro ohne zweiten Test; Wechsel Basis → Pro in der Testzeit wird auf beiden Stores sofort zum Pro-Preis abgerechnet (Android `withTimeProration`, Apple Upgrade sofort)? Store-Blatt zeigt den Preis; Rückmeldung in der App „Pro ist aktiv“ | Vorbefund Softwareentwickler: so dokumentiert von Apple (ein Einführungsangebot je Gruppe) und Google (kein zweiter Test nach Wechsel); am Gerät nicht erprobt | Store-Start | offen |
| P-D48 | Demo am echten Gerät (FA-13.14, FA-13.15): Startauswahl beim ersten Store-Build-Start; Demo öffnet unter 2 s, Band sichtbar, alle Bereiche voll; Speichern, Bezahlt, Storno, Mahnung, Stammdaten → Blatt statt Fehler; Scanner mit Erkennung füllt das Formular, Speichern verwirft, kein Bild in `belege/`; Teilen/Export/Sicherung gesperrt; Abo kaufen → Demo endet, Einrichtung leer, echte Datenbank ohne Musterdaten; Einstellungen → „Demo ansehen“ mit Abo; `PRAGMA query_only` auf Android- und iOS-SQLite wirksam | Widget- und Unit-Tests mit `sqflite_common_ffi` (`test/demo_test.dart`): Abschottung, Schreibschutz, Wasserzeichen je Seite, Teilen gesperrt | Store-Start | offen |
| P-D49 | Ersteinrichtung am echten Gerät (FA-1.13): App in Schritt 2 (Entwurf) und Schritt 3 aus dem App-Umschalter schließen → Neustart setzt am Schritt fort; Wiederherstellen von der Willkommensseite landet ohne Einrichtung in der Übersicht; Koppeln von der Willkommensseite zeigt den Mithelfer-Start | Test mit echter SQLite-Datenbank im Speicher | Store-Start | offen |
| P-D50 | DATEV-Import des Buchungsstapels (EXTF 700, Kategorie 21, Formatversion 13) in DATEV Kanzlei-Rechnungswesen bzw. DATEV Unternehmen online mit echter Kanzlei; Beleglink (Feld 20 „Beleglink“) bleibt leer – Belegbilder als ZIP mit Beleg-ID; DATEV Belegbildtransfer ist ein Online-Dienst (DATEV-Konto, Schnittstelle „Belegbilderservice“) und offline nicht möglich | Format im Code, kein echter Import | Release | offen |
| P-D51 | BMD NTCS: Import der BMD-CSV über den Importassistenten (Buchungsimport) mit echter Kanzlei, Steuercodes und Buchsymbole | kein echter Import | Release | offen |
| P-D52 | RZL (AT): Import der Belegliste bzw. BMD-CSV über den RZL-Importassistenten (frei zuordenbare Spalten) – eigenes RZL-Format nötig? | nicht gebaut, Format nicht gesichert recherchiert | vor RZL-Export | offen |
| P-D53 | Paket „Für Kapitalgesellschaft / doppelte Buchführung“ auf echtem Gerät: Größe des ZIP mit vielen Belegbildern (Speicher, Teilen per Mail-Limit), Öffnen am PC | Widget-/Unit-Test ohne Bilder | Release | offen |
| P-D54 | Paket `printing` 5.15 im Release-Build: Android mit R8 (Rasterung über `PdfRenderer`, Druck über Print Framework; keine eigene Keep-Regel nötig, Plugin-Klasse über den Plugin-Registrant), iOS-Pods-Build (Podspec ab iOS 8, App ab iOS 15; PDFKit/UIPrintInteractionController); Drucken auf echtem Drucker und „Als PDF speichern“, mehrseitige Rechnung, Speicher bei 10 Seiten | nur Unit-/Widget-Test; CI baut | Release | offen |
| P-D55 | Store-Phasen am Gerät (FA-13.16): iPhone (O-45) Sandbox sieht „14 Tage gratis, danach 12,90 €/Monat“ ohne Jahrespreis, `JENIBUCHTSTART` im Einlöseblatt gibt 6,90 €/Monat für 12 Monate, `JENIBUCHT20PRO` 103,20 € fürs erste Pro-Jahr; Android Testkonto sieht „14 Tage gratis, dann 6,90 €/Monat im ersten Jahr, danach 12,90 €/Monat“ für `basis_monat`, Jahresabo „69 €/Jahr im ersten Jahr, danach 129 €/Jahr“; ein Konto mit früherem Abo sieht nur den Grundpreis; `JENIBUCHT20` im Promo-Feld zeigt das Rabattangebot und kauft es; ob ein Google-Promo-Code (`JENIBUCHT2M`) auf einem Angebot mit Gratis- **und** Rabattphase die Rabattphase behält (Google ersetzt nur die Testdauer?); iOS: Einführungsangebot laut gewählter Variante O-45 erscheint auf der Abo-Seite und im Kaufblatt, Angebotscode `JENIBUCHT20` (Pay up front 1 Jahr) | Text mit Unit-Test, Store-Werte nur am Gerät | vor Store-Start | offen |
| P-D58 | Sicherung von Hand mit 8-stelligem Zahlencode (FA-7.2): vor Store-Start Geräteschlüssel zusätzlich (Schlüsselbund/Keystore) oder stärkeres Argon2id prüfen; Rechtsanwalt: genügt das der DSGVO Art. 32 für Buchhaltungsdaten? | Entscheidung Auftraggeber „nur Code fürs Erste“; Softwareentwickler: offline in Tagen bis Wochen durchprobierbar | Store-Start | offen |
| P-D57 | App-Store-ID für den Aktualisieren-Hinweis (FA-21.2, `RulesFreshness.iosStoreUrl`) nach der Freigabe eintragen; Android-Link öffnet die Play-Store-App statt des Browsers? | Platzhalter `id0000000000` | Store-Start iOS | offen |
| P-D56 | E-Rechnung-Validierung (FA-5.49): KoSIT-Validator mit XRechnung-3.0-Konfiguration und Mustang/veraPDF in der CI (heute nur intern mit Mustang 2.26 geprüft, Tests prüfen XSD und Rundreise); ebInterface 6.1 gegen die Geschäftsregeln von e-Rechnung.gv.at (Upload-Test im USP); ZUGFeRD-PDF aus dem Release-Build (echte Schrift, Logo) erneut mit veraPDF | nur intern | Release | offen |
| P-S65 | Belegbilder vom Mithelfer-Gerät (FA-17.3): aufgenommen auf einem fremden Gerät, dort nach dem Senden gelöscht, auf dem Hauptgerät unverändert gespeichert – genügt das den Aufbewahrungs- und Ordnungsvorschriften (§ 132 BAO, § 147 AO, GoBD Rz 136 ff. ersetzendes Scannen) und wie in die Verfahrensdokumentation aufnehmen? | Steuerberater intern: Original (Papier) bleibt beim Betrieb bis zur Entscheidung über ersetzendes Scannen; Bild unverändert übernommen, Herkunft „von ‹Gerät›“ in der Notiz, mittel | Release | offen |
| P-S67 | Verschlüsselte Kopie der Belege auf dem Mithelfer-Gerät bis zur Aufbewahrungsfrist (Standard 90 Tage) und Belegmails im Postfach der Geschäftsadresse: Teil der Aufbewahrung nach § 132 BAO / § 147 AO oder nur Transport? Muss die Verfahrensdokumentation den Mailweg nennen? | Steuerberater intern: nur Transport, maßgeblich ist der gebuchte Beleg auf dem Hauptgerät (und Papier bis P-S65), Mailweg in der Verfahrensdokumentation nennen, mittel | Release | offen |
| P-D41 | Gerätetest 0.22.1 (Pixel 10): Scan von Übersicht, Belegliste und im Formular zeigt Seitenbild, „Erneut auslesen“ und Vorbelegung; Sicherungsordner wählen und Sicherung wiederherstellen funktionieren weiter (Request-Codes neu); „Datei“ mit PDF, XRechnung/ZUGFeRD und Bild aus Google Drive und Downloads; iPhone: „Datei“ über die Dateien-App | Widget-Tests mit Fake-Channels, Test auf eindeutige Request-Codes | Release | offen |
| P-D39 | Gerätetest Scanner-Fix 0.21.1 (Pixel 10 und iPhone): zweimal hintereinander scannen, auch aus neuem Beleg über Übersicht und Belegliste; Abbrechen und erneut scannen; nach dem Scan Vorbelegung von Betrag und Händler; Nachbearbeitung (Papier hell, Schrift kräftig, Thermobon grau) sichtbar und Erkennung nicht schlechter als mit Kamerafoto | Widget-/Unit-Tests mit Fake-Channel und synthetischen Bildern | Release | offen |
| P-D40 | Gerätetest Diktat (Pixel 10 mit Android 16, iPhone): Knopf nur bei Erkennung auf dem Gerät; im Flugmodus funktioniert das Diktat; Erlaubnis Mikrofon/Spracherkennung (Texte deutsch); „zwölf Euro fünfzig“, „eintausendzweihundert“, „zwölf komma fünf null“ in de-AT und de-DE; Gerät ohne On-Device-Erkennung (Android 11 bzw. ältere iPhones) zeigt keinen Knopf | Unit-Tests Parser, Widget-Tests mit Fake-Channel | Release | offen |
| P-D38 | iOS-Gerätetest VisionKit-Scanner (iPhone): mehrseitig, Abbrechen, Rückkehr; Kamera-Hinweistext | nur CI-Build | Release | offen |
| P-D31 | Store-Abfrage auf Geräten (FA-13.6): StoreKit 2 ohne aktives Abo – kommt innerhalb 7 s eine Meldung oder gilt „leer“ zu Recht? Android mit Abo in Grace Period bzw. Kontosperre (on hold) – meldet Play den Kauf weiter? Kein falsches Herabstufen bei schlechtem Netz | Verlässlichkeit nur mit geladener Produktliste; sonst bleibt der Stand | Store-Start | offen |

### Ergebnisse der internen Prüfung (2026-10-16)

Prüfinstanzen Steuerberater und Rechtsanwalt, Auftrag der Auftraggeberin vom
2026-10-16. Amtliche Seiten (RIS, gesetze-im-internet.de, OeNB) waren aus der
Entwicklungsumgebung nicht abrufbar; geprüft wurde mit Websuche (Bundesbank,
BMF, USP, WKO) und Fachwissen zu Gesetz und Richtlinien. Punkte unter
„mittel“ nimmt die Fachperson im Anhang der Prüfmappe stichprobenartig mit.
Für alles, was hier fehlt, gilt weiter *offen – extern*.

| ID | Ergebnis | Quellen | Sicherheit |
|---|---|---|---|
| P-B4 | Eine zusätzliche verschlüsselte Kopie in einer Cloud neben dem Original im Inland ist keine Verlagerung der Buchführung; kritisch nur, wenn die Cloud-Kopie die einzige Ablage wird. Fristen siehe P-S5. | § 146 Abs 2 bis 2b AO; § 131 Abs 1 BAO; § 147 Abs 3 AO idF BEG IV | mittel |
| P-K4 | Flüchtige Verarbeitung ohne Speicherung im Ausland ist kein „Führen und Aufbewahren“ der Bücher dort; kein Verlagerungsantrag, solange Original und Ablage am Gerät bleiben. | § 146 Abs 2 bis 2b AO; § 131 Abs 1 BAO; GoBD Rz. 4 | mittel |
| P-L11 | Eine ausdrückliche Zustimmung in der App vor Weiternutzung ist wirksam; unwirksam wäre nur eine Zustimmungsfiktion durch Schweigen. Wortlaut prüft die Anwältin mit P-L1. | BGH XI ZR 26/20 vom 27.04.2021; OGH 4 Ob 59/09v; § 6 Abs 1 Z 2 KSchG | mittel |
| P-L12 | Die Spracherkennung der Systemtastatur liegt in der Verantwortung des Tastaturanbieters; die App erhält nur Text. Ein Hinweis in der Datenschutzerklärung genügt. | Art. 4 Nr. 7, Art. 13 DSGVO | mittel |
| P-L19 | OFL 1.1 erlaubt Einbetten in Dokumente und Bündeln mit Software; Lizenztext muss bei Auslieferung der Schrift beiliegen (`assets/fonts/OFL.txt`, Lizenzseite der App). Für eingebettete Teilmengen in PDFs keine weitere Pflicht. | SIL Open Font License 1.1, Präambel und Bedingungen 1–2; OFL-FAQ 1.11 | hoch |
| P-M1 | Mehrere Nummernkreise (je Gerät/Person mit festem Präfix) sind zulässig, wenn jede Nummer einmalig bleibt und die Kreise dokumentiert sind. | UStR Rz 1565; Abschn. 14.5 Abs 10 UStAE | mittel |
| P-R1 | Pflichtangaben nach § 5 ECG und § 25 MedienG (kleine Website: Name, Unternehmensgegenstand, Wohnort/Sitz) für AT; der ODR-Link ist mit Aufhebung der ODR-Verordnung ab 20.07.2025 entfallen; Schlichtungshinweis nur bei Teilnahme (P-L8). Die Texte prüft die Anwältin mit P-L1. | § 5 ECG; § 25 MedienG; VO (EU) 2024/3228; § 19 AStG | mittel |
| P-R2 | Die Vorgabe zum niedrigsten Preis der letzten 30 Tage gilt nach Wortlaut nur für Waren; für Abos gilt das Irreführungsverbot. Streichpreise nur, wenn der Vergleichspreis tatsächlich verlangt wurde, sonst „Einführungspreis bis …“. | § 11 PAngV; § 9a PrAG; Art. 6a RL 98/6/EG idF RL (EU) 2019/2161; § 5 UWG, § 2 UWG AT | mittel |
| P-R3 | Dienstleistungen von Kleinstunternehmen (unter 10 Beschäftigten, höchstens 2 Mio. € Umsatz oder Bilanzsumme) sind ausgenommen; die Auftraggeberin erfüllt das derzeit. Bei Wachstum erneut prüfen. | § 3 Abs 3 BFSG; § 2 Abs 2 BaFG; Art. 4 Abs 5 RL (EU) 2019/882 | mittel |
| P-R9 | Pflichten bestehen: Art. 50 KI-VO gilt ab 02.08.2026 (Kennzeichnung KI-erzeugter Inhalte); Software ist Produkt nach der neuen Produkthaftungsrichtlinie (Anwendung auf ab 09.12.2026 in Verkehr gebrachte Produkte). Umsetzung erst mit dem Marketing-Modul (Stufe C); Texte dann über P-L17. | Art. 50, 113 VO (EU) 2024/1689; Art. 4 Nr. 1, Art. 51 RL (EU) 2024/2853 | mittel |
| P-R10 | DSA verlangt von Unternehmern auf Marktplätzen Name, Anschrift, Telefon, E-Mail; die Angaben sind identisch mit dem Impressum. Festlegung passt. | Art. 30 Abs 1 und 7 VO (EU) 2022/2065 (DSA); § 5 ECG | mittel |
| P-R18 | EZB-Referenzkurse dürfen mit Quellenangabe frei genutzt werden. Abruf auf Knopfdruck mit IP-Adresse ist auf berechtigtes Interesse gestützt und offengelegt; Hinweis „EZB-Referenzkurs, ohne Gewähr“ genügt. | EZB-Website „Copyright and reuse“; Art. 6 Abs 1 lit f, Art. 13 DSGVO | mittel |
| P-R23 | Apple führt Einzelunternehmen als „Individual“; Verkäufername ist der persönliche Name; Organisation erst mit eigener Rechtspersönlichkeit und D-U-N-S, Wechsel später über Apple-Support möglich. | Apple Developer „Choosing a Membership“, „Enrollment – Organizations“ (D-U-N-S) | mittel |
| P-R30 | Ein Verweis erst auf der Rechnung bezieht AGB nicht ein; der Zusatz „soweit sie vereinbart wurden“ vermeidet den Eindruck einer Einbeziehung und ist nicht irreführend. Einmaliger Hinweis an die Nutzerin genügt. | § 864a ABGB; § 305 Abs 2 BGB; § 5 UWG | mittel |
| P-R31 | Skonto ist eine Zahlungsbedingung, keine Preisangabe; der Gesamtpreis steht auf der Rechnung. Unbedenklich bei festem Datum und Betrag. | § 3 PAngV; § 4 PrAG; § 5 UWG | mittel |
| P-R32 | Bestätigt: gegenüber Verbrauchern nur tatsächliche, angemessene Kosten; die erste verzugsbegründende Mahnung ist in DE nicht ersatzfähig; 10 € sind regelmäßig zu hoch. Der Hinweis in der App (FA-5.22) und die Entscheidung bei der Nutzerin sind angemessen. | § 1333 Abs 2 ABGB; §§ 280, 286 BGB; BGH NJW 1985, 320 | mittel |
| P-R34 | Bestätigt: 40-€-Pauschale nur unter Unternehmern, angerechnet auf Rechtsverfolgungskosten; Verzugszinsen ohne Vereinbarung ab Mahnung bzw. 30 Tage nach Rechnung, bei Verbrauchern nur mit Hinweis. | § 458 UGB; § 288 Abs 5 BGB; § 286 Abs 3 BGB; RL 2011/7/EU | hoch |
| P-R36 | Bestellnummern und Bestimmungsland als Aggregat sind für Buchung und OSS-Warnung erforderlich und zulässig; Käuferdaten zu verwerfen entspricht der Datenminimierung. Die Nutzerin ist Verantwortliche für die geteilte Datei. | Art. 5 Abs 1 lit c, Art. 6 Abs 1 lit c DSGVO; § 132 BAO, § 147 AO | mittel |
| P-R39 | Fristsetzung bindet bis zum Datum und ist zulässig; eine Option „freibleibend“ ist nicht nötig. | § 148 BGB; § 862 ABGB | hoch |
| P-S1 | (c) Außer Ansatz bleiben nach § 6 Abs 1 Z 27 UStG 1994 u. a. Hilfsgeschäfte einschließlich Geschäftsveräußerungen sowie bestimmte steuerfreie Umsätze (Z 8 lit d und j, Z 9 lit b, Z 26). Die App zählt alle Einnahmen und überschätzt damit höchstens; das ist für eine Warnung die sichere Seite. Keine Änderung. | § 6 Abs 1 Z 27 UStG 1994 idF AbgÄG 2024; UStR Rz 994 ff. | hoch |
| P-S2 | Richtig: Im Gründungsjahr darf der Umsatz 25.000 € nicht übersteigen; wird die Grenze überschritten, gilt ab diesem Umsatz die Regelbesteuerung. Code (FA-4.13) entspricht dem. | § 19 Abs 1 Satz 2 und 3 UStG idF JStG 2024; BMF-Schreiben vom 18.03.2025, Abschn. 19.1 UStAE | hoch |
| P-S3 | Der Gesamtumsatz für § 19 UStG ist nach vereinnahmten Entgelten zu berechnen; die Zuordnung nach Zahlungseingang ist daher richtig, nicht nach Belegdatum. | § 19 Abs 2 UStG; Abschn. 19.1 Abs 2 UStAE | mittel |
| P-S4 | Beschlossen: 4,9 % ab 1.7.2026 für Waren der Anlage 3 (BGBl. I Nr. 37/2026); im Code als Satz mit `validFrom` 2026-07-01 (siehe P-S28). Punkt damit erledigt. | BGBl. I Nr. 37/2026; BMF „Bundesgesetz, mit dem das UStG 1994 geändert wird“ (2026); USP „Neuer Umsatzsteuersatz von 4,9 Prozent“ | hoch |
| P-S5 | DE: Buchungsbelege 8 Jahre, Bücher/Aufzeichnungen 10 Jahre, Handels- und Geschäftsbriefe 6 Jahre; AT: 7 Jahre, Grundstücksunterlagen 22 Jahre. Fristbeginn Ende des Kalenderjahres. Da die App nichts löscht, keine Änderung; vor einer Löschfunktion Frist je Unterlagenart einführen. | § 147 Abs 3 und 4 AO idF BEG IV; § 132 Abs 1 BAO; § 18 Abs 10 UStG 1994 | hoch |
| P-S6 | AT: keine allgemeine B2B-E-Rechnungspflicht, nur gegenüber dem Bund (IKT-Konsolidierungsgesetz). Hinweis DE: Empfang von E-Rechnungen seit 1.1.2025 Pflicht, Ausstellung gestaffelt ab 2027/2028 (eigenes Thema, nicht dieser Punkt). | § 5 IKT-KonG; § 11 Abs 2 UStG 1994; § 14 Abs 1 UStG DE idF Wachstumschancengesetz; § 27 Abs 38 UStG DE | hoch |
| P-S8 | Pflicht ist ein Hinweis auf die Steuerbefreiung; ein bestimmter Wortlaut ist nicht vorgeschrieben. „Steuerbefreiung nach § 19 UStG (Kleinunternehmer)“ genügt. | § 34a UStDV idF JStG 2024; Abschn. 19.5 UStAE (BMF 18.03.2025) | hoch |
| P-S9 | Regel bestätigt (UID des Empfängers bei Gesamtbetrag über 10.000 € brutto, Inlandsleistung an Unternehmer). Vorbefund „Prüfung fehlt“ ist überholt: `TaxProfile.largeInvoiceVatIdLimit` wird in `invoice_requirements.dart` geprüft. | § 11 Abs 1 Z 3 lit i UStG 1994; UStR Rz 1508a | hoch |
| P-S14 | Nein. Leistungen an Apple bzw. Google (Leistungsort Irland, § 3a Abs 6 UStG 1994) sind im Inland nicht steuerbar und zählen nicht zur 55.000-€-Grenze, die auf im Inland steuerbare Umsätze abstellt. Gilt gemeinsam mit P-S21. | § 6 Abs 1 Z 27 UStG 1994; § 3a Abs 6 UStG 1994; Art. 9a DVO (EU) 282/2011 | mittel |
| P-S19 | Auch als Kleinunternehmerin braucht die Auftraggeberin für B2B-Leistungen an Unternehmer in anderen Mitgliedstaaten eine UID und muss eine Zusammenfassende Meldung abgeben. | Art. 21 Abs 3 UStG 1994 (Binnenmarktregelung); § 28 Abs 1 UStG 1994; UStR Rz 4351 | mittel |
| P-S20 | Der Store gilt gegenüber der Endkundin als Leistender (Kommissionsfiktion); die Auftraggeberin leistet an den Store. Die Provision ist keine eigene Leistung an sie, kein Reverse Charge; Bemessungsgrundlage ist die Auszahlung. | Art. 9a DVO (EU) 282/2011; § 3a Abs 4 UStG 1994; UStR Rz 642c | mittel |
| P-S21 | Wie P-S14: nicht steuerbare Auslandsumsätze zählen nicht zur Grenze. | § 6 Abs 1 Z 27 UStG 1994; § 3a Abs 6 UStG 1994 | mittel |
| P-S25 | Ohne Wirkung, solange Einnahmen in Euro bleiben (L-13.3). Bei Fremdwährungseinnahmen gilt der Umrechnungskurs nach § 20 Abs 6 UStG 1994 bzw. § 16 Abs 6 UStG DE auch für die Grenze. | § 20 Abs 6 UStG 1994; § 16 Abs 6 UStG DE | mittel |
| P-S27 | Bestätigt: Abziehbar ist nur inländische Umsatzsteuer; ausländische Steuer wird über das Vorsteuer-Vergütungsverfahren erstattet. Buchung brutto ohne Vorsteuer ist richtig. | § 12 Abs 1 Z 1 UStG 1994; § 15 Abs 1 Nr. 1 UStG DE; RL 2008/9/EG | hoch |
| P-S28 | Satz, Stichtag und Fundstelle bestätigt (BGBl. I Nr. 37/2026, Anlage 3, Lieferungen ab 1.7.2026). Die Abgrenzung je Ware (KN-Position) trifft die Nutzerin am Beleg; die App bietet den Satz nur an. | BGBl. I Nr. 37/2026; BMF-Fachinformation „Umsatzsteuersenkung auf ausgewählte Nahrungsmittel“; WKO-Info Umsatzsteuersenkung Nahrungsmittel | mittel |
| P-S29 | Bestätigt: Ohne Steuerausweis kein Vorsteuerabzug, Betriebsausgabe brutto. Auch die Kleinbetragsrechnung braucht den Steuersatz. | § 11 Abs 6, § 12 Abs 1 Z 1 UStG 1994; § 15 Abs 1 Nr. 1 UStG, § 33 UStDV | hoch |
| P-S30 | Bestätigt: Antrag elektronisch im Ansässigkeitsstaat (FinanzOnline bzw. BZSt-Portal) bis 30.09. des Folgejahres; Mindestbeträge 400 € (Teiljahr) bzw. 50 € (Jahr); Kleinunternehmer sind ausgeschlossen. | Art. 3, 15, 17 RL 2008/9/EG; § 21 Abs 9 UStG 1994 iVm VO BGBl. II 222/2009; § 18g UStG DE | mittel |
| P-S31 | Eine bestimmte Form der Vollständigkeitsbestätigung ist nicht vorgeschrieben; eine aktive, eindeutig beschriftete Handlung mit Protokoll genügt, wenn sie in der Verfahrensdokumentation beschrieben ist (diese bleibt P-S15). | GoBD (BMF 28.11.2019, geändert 11.03.2024) Rz. 136 ff., 151 ff.; § 146 Abs 1 AO; § 131 BAO | mittel |
| P-S32 | Bestätigt: Abweichendes Wirtschaftsjahr AT nur für Rechnungsleger nach § 5 bzw. protokollierte Unternehmer mit Zustimmung des Finanzamts, DE nur für im Handelsregister eingetragene Gewerbetreibende (und Land- und Forstwirte) mit Einvernehmen; USt immer Kalenderjahr. Einmalige Bestätigung genügt. | § 2 Abs 5 EStG 1988; § 4a Abs 1 EStG DE; § 16 Abs 1 UStG DE, § 20 Abs 1 UStG 1994 | mittel |
| P-S40 | Aufteilung eines Gesamtrabatts nach Entgelten je Steuersatz ist sachgerecht und anerkannt; ausgewiesen je Satz erfüllt die Pflichtangabe. | § 14 Abs 4 Nr. 7 UStG, Abschn. 14.5 Abs 19 UStAE; § 11 Abs 1 Z 3 lit e UStG 1994 | mittel |
| P-S41 | Versandkosten teilen als Nebenleistung das Schicksal der Hauptleistung; bei Mischsätzen ist die Aufteilung nach Entgelten zulässig (Vereinfachung der Finanzverwaltung). | Abschn. 3.10 Abs 5 und 6 UStAE; UStR Rz 347 | mittel |
| P-S43 | Ein Hinweis „Bei Zahlung bis … x % Skonto“ genügt; die Höhe muss sich nicht betragsmäßig je Satz ergeben. | Abschn. 14.5 Abs 19 UStAE; § 11 Abs 1 Z 3 lit e UStG 1994 | mittel |
| P-S44 | DE amtlich: 1,27 % ab 1.1.2026, **1,52 % ab 1.7.2026** (Bundesbank) – fehlte im Code und wurde ergänzt. AT: Basiszinssatz ändert sich nur bei Änderung des EZB-Hauptrefinanzierungssatzes um mindestens 0,5 Prozentpunkte, daher 1,53 % unverändert (OeNB-Tabelle nicht abrufbar, deshalb mittel). | Bundesbank-Pressemitteilung „Basiszinssatz zum 1. Juli 2026: 1,52 %“; § 247 BGB; Art. I § 1 2. Euro-JuBeG; OeNB „Basis- und Referenzzinssätze“ | mittel |
| P-S45 | Bestätigt: Verzugszinsen, Mahnkosten und Pauschale sind echter Schadenersatz, nicht steuerbar; Betriebseinnahme bei Zufluss. | Abschn. 1.3 Abs 6 UStAE; UStR Rz 9; § 4 Abs 3 EStG | mittel |
| P-S46 | Regeln: AT 50 % der Bewirtung mit Werbezweck abzugsfähig, DE 70 % mit Bewirtungsnachweis. Vorsteuer DE voll (§ 15 Abs 1a Satz 2 UStG). AT: § 12 Abs 2 Z 2 lit a UStG 1994 versagt den Vorsteuerabzug nur, wenn die Entgelte **überwiegend** nicht abzugsfähig sind; bei 50 % ist das nicht der Fall, Vorsteuer voll (UStR 2000 Rz 1934). Umgesetzt 0.21.0 (FA-2.60, Entscheidung Auftraggeberin). Kennzahlzuordnung in E1a/EÜR nicht gesichert → Hilfszeile | § 20 Abs 1 Z 3 EStG 1988; § 12 Abs 2 Z 2 lit a UStG 1994; UStR 2000 Rz 1934; § 4 Abs 5 Satz 1 Nr. 2 EStG DE; § 15 Abs 1a UStG DE | mittel |
| P-S47 | Bestätigt: Kleinunternehmer buchen Ausgaben brutto, kein Vorsteuerabzug. Beim Statuswechsel im Jahr gilt die Einstellung ab dem Wechsel; Vorsteuerberichtigung bei Anlagen (§ 12 Abs 10 UStG 1994, § 15a UStG) bildet die App nicht ab – Hinweis an die Steuerberatung genügt. | § 6 Abs 1 Z 27, § 12 Abs 10 UStG 1994; § 19 Abs 1 Satz 4, § 15a UStG; § 9b Abs 1 EStG | mittel |
| P-S52 | Bestätigt: Reverse Charge gilt auch für Kleinunternehmer, ohne Vorsteuerabzug; Kennzahlen AT Kz 057/066, DE Kz 46/47 und 67. Leistender der Werbung steht auf der jeweiligen Amazon-Rechnung und ist dort abzulesen. | § 19 Abs 1 zweiter Satz, § 3a Abs 6 UStG 1994; § 13b Abs 1, 5 und 8 UStG; Formulare U30 2026, USt 1 A 2026 | mittel |
| P-S53 | Für eine Warnung genügt die Näherung über Marktplatz bzw. Lieferland. Schwelle 10.000 € EU-weit für Fernverkäufe und TBE-Leistungen bestätigt. | Art. 59c MwStSystRL; Art. 3 Abs 5 UStG 1994 (Binnenmarktregelung); § 3c Abs 4 UStG | mittel |
| P-S56 | (a) Ein gemeinsamer Nummernkreis ist zulässig, solange jede Nummer einmalig ist. (b) Bezug auf Nummer und Datum, negative Beträge je Satz und Grund genügen. (c) Berichtigung wirkt mit Zugang beim Empfänger; Hinweis „PDF senden“ ist ausreichend. (d) Ist-Buchung bei Rückzahlung richtig für die EAR. | § 14 Abs 4 Nr. 4 UStG, § 31 Abs 5 UStDV, Abschn. 14.5 Abs 10, 14.11, 14c.1 UStAE; § 11 Abs 1 Z 3 lit c, § 11 Abs 12, § 16 UStG 1994 | mittel |
| P-S62 | Verträge sind in DE als Handels- oder Geschäftsbriefe 6 Jahre, als Buchungsbelege 8 Jahre aufzubewahren, in AT 7 Jahre; Beginn mit Ende des Kalenderjahres der letzten Wirkung (letzte Buchung). Die eine Frist aus `retentionYears` ab Vertragsende ist die sichere Obergrenze; Grundstücke und Darlehen sind als Grenze dokumentiert. | § 147 Abs 3 AO idF BEG IV; § 132 Abs 1 BAO; § 18 Abs 10 UStG 1994 | mittel |
| P-S63 | Entzerren, Zuschneiden und Kontrastverbessern sind zulässig, solange der Inhalt vollständig und lesbar bleibt; der Scanvorgang gehört in die Verfahrensdokumentation (siehe P-S15). | GoBD Rz. 136 ff.; Muster-Verfahrensdokumentation Ersetzendes Scannen (BStBK/DStV); § 132 Abs 2 BAO | mittel |
| P-U2 | AT: Für die Stufe-2-Bestätigung ist FinanzOnline bzw. MIAS/VIES mit Abfragenummer anerkannt. DE: VIES-Ausdruck ist Hilfsnachweis, die qualifizierte Bestätigung nach § 18e UStG beim BZSt ist stärker. Vorbefund bestätigt. | UStR Rz 4357 f.; § 18e UStG; Abschn. 18e.1 UStAE | mittel |
| P-U3 | AT: Steuernummer ist keine Pflichtangabe, UID des Ausstellers schon. DE: Steuernummer oder USt-IdNr. des Ausstellers genügt. | § 11 Abs 1 Z 3 lit h UStG 1994; § 14 Abs 4 Nr. 2 UStG | hoch |

### Ergebnisse der internen Prüfung (2026-10-18) – mehrere Steuerländer

Prüfinstanzen Steuerberater und Rechtsanwalt, Auftrag der Auftraggeberin vom
2026-10-18, auf Grundlage ihrer Entscheidungen vom selben Tag (Lastenheft 14a):
(a) Verbringen ins Auslandslager wird nicht in der App gebucht, nur die
Verkäufe aus dem Lager; (b) Rechnungen werden immer im Heimatland besteuert;
(c) Auslandsregistrierungen dienen nur der dortigen UID, ohne Betriebsstätte,
in mehreren Ländern möglich. Websuche (USP, WKO, IHK) war eingeschränkt
ergiebig; geprüft mit Gesetz, Richtlinie und Verwaltungsanweisungen aus
Fachwissen. Die Ergebnisse ersetzen keine Beratung im Einzelfall der
Nutzerin; die App rechnet, die Kanzlei entscheidet.

**Befund Vollständigkeit der DE-UStVA:** Weil das Verbringen nicht gebucht
wird, fehlen in der UStVA des Lagerlands der ig. Erwerb (DE Kz 89, § 1a Abs 2
UStG) und die gleich hohe Vorsteuer (Kz 61, § 15 Abs 1 Satz 1 Nr. 3 UStG). Die
Zahllast ändert sich bei vollem Vorsteuerabzug nicht, die Erklärung ist ohne
diese Zeilen aber **unvollständig** (§ 18 Abs 1 UStG, § 153 AO). Umgesetzt:
Warnhinweis in „Für das Finanzamt“ bei jeder weiteren Registrierung mit
Kennzahlen (FA-18.4, `TaxProfile.warehouseTransferHint`).

| ID | Ergebnis | Quellen | Sicherheit |
|---|---|---|---|
| P-S68 | (a) Ja: Wer Ware in einem DE-Lager hält und von dort liefert, führt in DE steuerbare Umsätze aus und muss sich vor der ersten Einlagerung registrieren; schon das Verbringen ist in DE ein steuerbarer ig. Erwerb. (b) Ja: § 19 UStG steht seit 2025 nur im Inland ansässigen Unternehmern offen → Regelbesteuerung 19 %, UStVA in Gründungsjahr und Folgejahr monatlich. (c) DE: ig. Erwerb Kz 89/Vorsteuer Kz 61; AT: das Verbringen ist eine fiktive ig. Lieferung, die nach Art 6 Abs 1 BMR steuerfrei ist und in UVA und ZM gehört; die KU-Befreiung des § 6 Abs 1 Z 27 tritt dahinter zurück (mittel) – **außerhalb der App** (Entscheidung a), Hinweis in App und Handbuch. (d) Ja, Gebühren Amazon EU S.à r.l. → RC am Sitz in AT. | §§ 1a Abs 2, 3 Abs 6, 15 Abs 1 Nr. 3, 18 Abs 2 Satz 4, 19 Abs 1 UStG idF JStG 2024; Abschn. 1a.2 UStAE; Art 3 Abs 1 Z 1, Art 6 Abs 1, Art 21 Abs 3 BMR; § 3a Abs 6 UStG 1994; USP „Zusammenfassende Meldung“; WKO Exporthandbuch Deutschland | hoch, (c) AT-Seite mittel |
| P-S69 | Das EU-KU-Verfahren befreit nur Lieferungen und Leistungen im anderen Staat (Art 284 MwStSystRL), nicht den ig. Erwerb aus dem Verbringen. Mit eigenem Lager in DE bleibt damit ohnehin eine DE-Registrierung nötig; das Verfahren passt praktisch nicht zum FBA-Lager. Die App bietet die Form an, zeigt dann Hinweis statt Kennzahlen – genügt. | Art 284, 284d MwStSystRL idF RL (EU) 2020/285; § 19a UStG; § 6 Abs 1 Z 27 UStG 1994 idF AbgÄG 2024 | mittel |
| P-S70 | Nein: Die AT-Grenze stellt auf im Inland steuerbare Umsätze ab, Lieferungen ab DE-Lager sind in DE steuerbar. FA-18.7 richtig. Für ein EU-KU-Verfahren zählt zusätzlich der EU-Gesamtumsatz (100.000 €), den die App nicht prüft (Grenze 11). Spiegelbildlich DE-Heimat mit AT-Lager (§ 19 Abs 1 UStG: „im Inland“). | § 6 Abs 1 Z 27 UStG 1994; § 19 Abs 1 UStG; Art 284 Abs 2 MwStSystRL | hoch |
| P-S71 | München für AT-Unternehmer bestätigt (zentrale Zuständigkeit nach UStZustV). Graz-Stadt: Das Finanzamt Österreich ist für Unternehmer ohne Sitz/Betriebsstätte im Inland zuständig, Dienststelle Graz-Stadt als Sonderzuständigkeit (mittel). Feiertage: maßgeblich ist der Ort der Behörde (§ 108 Abs 3 AO, Bayern); die App verschiebt nur nach bundesweiten Feiertagen und zeigt damit höchstens einen **früheren** Termin – sichere Seite, Grenze 11 bleibt. | § 21 Abs 1 Satz 2 AO; § 1 Abs 1 UStZustV; § 108 Abs 3 AO; § 60 Abs 2 BAO, AVOG 2010 | mittel |
| P-S72 | Frist Ende des Folgemonats bestätigt. Das Unionsrecht kennt keine Verschiebung auf den nächsten Werktag (Erläuterungen der Kommission zum E-Commerce-Paket); die App verschob bisher und hätte einen zu späten Termin gezeigt → **behoben**: OSS und EU-KU-Meldung ohne Verschiebung (`shiftsToWorkday: false`). Fernverkäufe aus dem DE-Lager in andere EU-Länder meldet die Nutzerin im Heimat-OSS mit Abgangsland DE. | Art 369g Abs 1, Art 369f MwStSystRL; Art 25a Abs 6 UStG 1994; § 18j Abs 3 UStG; Europäische Kommission, Explanatory Notes VAT e-commerce (2020), Kap. 4 | hoch |
| P-S73 | Als Vorschlag mit sichtbarem Hinweis vertretbar; maßgeblich ist das Abgangsland laut USt-Transaktionsbericht. Die Kanzlei gleicht je Quartal mit dem Amazon-Bericht ab. | § 3 Abs 6 UStG; Art 32 MwStSystRL; Amazon „VAT Transactions Report“ | mittel |
| P-S74 | Keine Betriebsstätte: Ein fremdes Lager, über das die Unternehmerin keine eigene Verfügungsmacht hat, ist keine feste Geschäftseinrichtung; zudem nimmt Art 5 Abs 4 DBA AT-DE Lagerung und Auslieferung aus. Entspricht Entscheidung (c). Ändert sich das (eigenes Lager, eigenes Personal), neu prüfen. | § 12 AO; § 29 BAO; Art 5 Abs 1 und 4 DBA AT-DE 2000; OECD-MK Art 5 Rz 66 ff. | mittel |
| P-R5 | Kennzahlen aus den eigenen Belegen anzuzeigen und kopieren zu lassen ist Rechnen mit einem Werkzeug, keine Hilfeleistung in Steuersachen im Einzelfall; die Erklärung gibt die Nutzerin selbst ab. Der Hinweis auf das fehlende Verbringen ist allgemein und keine Einzelfallempfehlung. Bei Übermittlung über Webservice mit Zugangsdaten der Nutzerin erneut extern prüfen. | §§ 1, 2 StBerG; § 2 Abs 1 RDG; BGH I ZR 113/20 (Smartlaw) vom 09.09.2021; § 2 WTBG 2017 | mittel |

Nicht intern abschließbar und weiter *offen – extern*: **P-R4** (Haftungsbegrenzung):
Der Hinweis auf das nicht gebuchte Verbringen und die Bestätigung „keine
Steuerberatung“ mindern das Risiko, ersetzen aber keine Prüfung des
AGB-Wortlauts durch eine Anwältin; Vorsatz und grobe Fahrlässigkeit sind nicht
ausschließbar (§ 309 Nr. 7 BGB, § 6 Abs 1 Z 9 KSchG). Ein unvollständiger
Kennzahlenblock ohne Warnung wäre ein Produktfehler; mit dem Warnhinweis ist
der Umfang der Leistung klar beschrieben.

### Ergebnisse der internen Prüfung (2026-10-19) – Test auf allen Stufen und Demo

Prüfinstanzen Rechtsanwalt, Steuerberater, Softwareentwickler und UX zu den
Entscheidungen des Auftraggebers vom 2026-10-19 (O-42, Lastenheft 14a). Geprüft
mit Gesetz, Store-Richtlinien und Paketquellen (`in_app_purchase_storekit`
0.4.13: `SK2PurchaseDetails`, `jsonRepresentation`) aus Fachwissen; keine
amtlichen Seiten abgerufen. Alles, was eine Fachperson oder ein Gerät
bestätigen muss, steht als *offen* in den Tabellen oben (P-R55 bis P-R57,
P-S75, P-D46 bis P-D48, P-X23).

- **Rechtsanwalt – Testtext (P-R57):** Wortlaut des Auftraggebers übernommen.
  Ergänzt auf der Basis-Karte „Nach dem Test gilt der Umfang von Basis.“, weil
  „mit allen Pro-Funktionen“ sonst den Umfang des bezahlten Basis-Abos
  überzeichnet (§ 5 Abs 1 Z 1 UWG DE, § 2 Abs 1 Z 1 UWG AT). Preis immer aus
  dem Store, je Karte neben dem Kaufknopf; Verlängerung, Kündigungsweg
  (24 Stunden vorher, Store) und Übergang in das Abo im Pflichttext (§ 312j
  Abs 2 BGB, § 4 Abs 1 FAGG, Apple 3.1.2, Google Play Abo-Richtlinie). Der
  frühere Satz „Der kostenlose Test von Pro …“ ist ersetzt; „Store-Test nur
  auf Pro“ kommt in Code und Texten nicht mehr vor (O-35 überholt).
- **Rechtsanwalt – Demo (P-R55, P-R56):** Wasserzeichen auf jeder Seite,
  gesperrtes Teilen und Nullen-Platzhalter verhindern eine Verwendung als
  echte Rechnung; Musterdaten ohne echte Marken und ohne Fotos Dritter.
  Ausprobierte Scans werden beim Verlassen gelöscht (Datenminimierung,
  Art. 5 Abs 1 lit c DSGVO); kein Datenfluss vom Gerät, deshalb keine
  Änderung an Datenflusstabelle, `PRIVACY.md` und Store-Datensicherheit.
- **Steuerberater – Musterdaten (P-S75):** drei Befunde eingearbeitet: Diesel
  mit Vorsteuer nur für einen Fiskal-LKW (§ 12 Abs 2 Z 2 lit b UStG AT),
  Lagerleistung statt steuerfreier Raummiete in DE (§ 4 Nr. 12 UStG DE),
  keine Beratungsrechnung mit österreichischer USt an die deutsche GmbH
  (Leistungsort § 3a Abs 6 UStG AT, Reverse Charge § 19 Abs 1 UStG AT).
- **Softwareentwickler:** Ein Anspruch bleibt die einzige Quelle
  (`Entitlement.allows`, `AppState.entitlement`); Testzeit nur in
  `LicensePolicy.proIncludedUntil`. Abschottung doppelt: eigene
  In-Memory-Datenbank **und** `PRAGMA query_only`; Teilen ohne Datei,
  Belegbilder im eigenen Ordner außerhalb der Sicherung. Android-Näherung und
  Apple-Gruppenregel als Grenzen (Abschnitt 11, P-D46, P-D47).
- **UX:** Startauswahl unten, 64 dp, 16 dp Abstand; Hinweisblatt 56 dp, 12 dp
  Abstand; Band oben 48 dp mit Kontrast > 4,5 : 1 (Weiß auf `#8A4F00`). Das
  Band liegt außerhalb der Daumenzone – zulässig, weil jede gesperrte Aktion
  dieselbe Wahl unten anbietet (P-X23). Nebenbefund behoben: Rechtsform im
  Onboarding lief auf 360 dp über den Rand.

### Ergebnisse der internen Prüfung (2026-10-19) – Ersteinrichtung, EU-KU-Nummer

Prüfinstanzen Rechtsanwalt, Steuerberater, Softwareentwickler und UX zur
Rückmeldung des Auftraggebers vom 2026-10-19 (Lastenheft 14a). Geprüft aus
Gesetz und Fachwissen, keine amtlichen Seiten abgerufen; offen in den Tabellen
oben: P-R58, P-S76, P-S77, P-X24, P-D49.

- **Rechtsanwalt – Bestätigungen (P-R58):** L-17.2 verlangt Eigenständigkeit
  nur für „Keine Steuerberatung“; dort bleibt das nicht vorausgewählte
  Häkchen. Nutzungsbedingungen werden wirksam einbezogen durch Hinweis,
  zumutbare Kenntnisnahme (Links auf die Volltexte in der App) und
  Einverständnis über einen eindeutig beschrifteten Knopf (§ 305 Abs 2 BGB,
  § 864a ABGB); die Datenschutzerklärung ist Information nach Art 13 DSGVO
  und braucht keine Einwilligung. Ergebnis: zwei statt drei Tipps, Nachweis
  in `consents` unverändert. Kein neuer Datenfluss (EU-KU-Nummer bleibt auf
  dem Gerät und erscheint nur auf Rechnungen, die die Nutzerin selbst teilt),
  daher keine Änderung an Datenflusstabelle, `PRIVACY.md`, Store-Angaben.
- **Steuerberater – EU-KU-Nummer (P-S76, P-S77):** Die Nummer erteilt der
  Ansässigkeitsstaat (Art 284 Abs 3 MwStSystRL), Suffix „EX“; sie gehört zum
  Unternehmen, nicht zur Registrierung im Gastland, und kann neben einer UID
  bestehen → eigenes Profilfeld. Auf Rechnungen in das Gastland anzugeben,
  solange das Verfahren genutzt wird; Hinweis auf die Steuerbefreiung wie
  bisher. Aufbau je Land und Pflicht im Einzelnen offen.
- **Softwareentwickler:** Migration 28 nur ergänzend (GR-7); Fortsetzen über
  den vorhandenen Schlüsselspeicher `helper_settings` (kein weiteres
  Schema); Profil wird in Schritt 2 gespeichert, der Schritt vorher, damit
  `_Root` die Einrichtung weiter zeigt; Startauswahl und
  `AppState.showStartChoice` entfernt. Exportspalte „Beschreibung“ bleibt,
  damit Kanzlei-Importe nicht brechen.
- **UX:** Hauptknopf unten 56 dp, „Später hinzufügen“ darüber 48 dp mit
  12 dp Abstand (nicht neben einem Gefahrenknopf), Land und Besteuerung als
  Segmente statt Auswahllisten (ein Tipp), Fortschritt oben, Zurück-Geste;
  Willkommensseite mit beiden großen Knöpfen in der Daumenzone. Befund
  behoben: die untere Leiste füllte zunächst die ganze Höhe (Center ohne
  `heightFactor`), Formular unsichtbar. Gerätetest: P-X24.
- **Nachtrag Demo und Verträge (Rückmeldung 2026-10-19):** Ursache der leeren
  Listen: Belege- und Rechnungsliste leben im `IndexedStack` der Startseite
  und luden nur einmal; jetzt neu bei jeder Änderung von
  `bookingsRevision` (auch Demo betreten/verlassen). Steuerberater: Demo als
  Kleinunternehmerin plausibel – eigene Rechnungen und Barverkäufe ohne USt,
  Kleinunternehmerhinweis aus der Rechnung, Lieferantenbelege mit
  ausgewiesener USt ohne Vorsteuerabzug; DE-Lagerleistung bleibt der
  DE-Registrierung zugeordnet (P-S75). Rechtsanwalt: Dienstvertrag mit
  erfundener Person; Hinweis zur Datensparsamkeit (Art 5 Abs 1 lit c DSGVO)
  und Ausschluss von KI-Übertragung (L-23.8); kein neuer Datenfluss. UX:
  Umschalter 48 dp oben in der Liste, leere Liste scrollbar statt Überlauf
  auf 360 dp.


### Ergebnisse der internen Prüfung (2026-10-19) – Abgaben & Rücklagen

| ID | Ergebnis der Prüfinstanz | Quellen | Sicherheit |
|---|---|---|---|
| P-S78 | Tarif 2026 bestätigt (Beispiel usp.gv.at 40.000 € → 7.447,20 €). SVS-Werte 2026 aus WKO-Infoblatt und Sekundärquellen übereinstimmend; Unfallversicherung 12,95 €/Monat (155,40 €/Jahr). Gewinnfreibetrag: nur Grundfreibetrag automatisch, investitionsbedingter nicht. | § 33 Abs 1 EStG 1988; usp.gv.at „Tarifstufen“; BMF Steuertarif; WKO Infoblatt Sozialversicherung 2026; §§ 25, 27 GSVG | Tarif hoch, SVS mittel |
| P-S79 | Hinzurechnung der Beiträge richtig; Abweichung nur, wenn gebucht ≠ vorgeschrieben. Ausnahme § 4 Abs 1 Z 7 GSVG nur auf Antrag, daher Hinweis statt Automatik. | § 25 Abs 2 Z 2, § 25a, § 4 Abs 1 Z 7 GSVG | mittel |
| P-S80 | AT SVS Betriebsausgabe, ESt privat, DE KV/PV Sonderausgabe, GewSt nicht abziehbar – so umgesetzt (`LevyRules.nonDeductibleKinds`). | § 4 Abs 4 Z 1 lit a, § 20 Abs 1 Z 6 EStG 1988; § 4 Abs 5b, § 10 Abs 1 Nr 3, § 12 Nr 3 EStG | hoch (Konten mittel) |
| P-S81 | Formeln an den Zonengrenzen stetig; Werte 2025 aus dem Steuerfortentwicklungsgesetz. Kirchensteuer-Kappung und Sonderausgabenabzug weggelassen (Schätzung zu hoch, sichere Seite). | § 32a EStG; §§ 3, 4 SolZG 1995; KiStG der Länder | mittel |
| P-S82 | Für Einzelunternehmen ohne Mieten/Zinsen-Hinzurechnung vertretbar; Anrechnung höchstens tatsächliche GewSt. | §§ 7, 11, 16 GewStG; § 35 EStG | hoch |
| P-S83 | Entscheidung: Eingabe des Monatsbetrags laut Bescheid statt Schätzung – eine Schätzung mit Zusatzbeitrag je Kasse und Nachberechnung wäre zu oft falsch. | § 240 SGB V; § 10 Abs 1 Nr 3 EStG | mittel |
| P-R59 | Allgemeine Rechenhilfe aus eigenen Daten, deutlich gekennzeichnet, ist keine Hilfeleistung in Steuersachen im Einzelfall; keine Erklärung, keine Übermittlung. Store-Texte: „schätzt“, nicht „berechnet verbindlich“. | §§ 2, 5 StBerG; § 2 RDG; BGH I ZR 113/20; § 2 WTBG 2017 | mittel |
| UX | Karte direkt unter dem Ergebnis, ganze Karte tippbar; Bildschirm mit Speichern unten volle Breite 56 dp, Schalter als ganze Zeile ≥ 48 dp, keine Pflichtfelder, ein Schritt zum Speichern; keine Gefahrenknöpfe. Ohne Befund. | DESIGN_SPEC 5a | hoch |


### Ergebnisse der internen Prüfung (2026-10-19) – PDF-Betrachter, Abgaben Pro, Willkommensseite

- **Softwareentwickler – Paketwahl:** `printing` 5.15 (DavBfr, Apache-2.0,
  selber Autor wie das schon genutzte `pdf`, aktiv gepflegt) statt `pdfx`:
  rendert mit Plattformmitteln (Android `PdfRenderer`, iOS PDFKit), also ohne
  mitgelieferte PDFium-Binärdatei – kleiner; bringt den Systemdruckdialog
  gleich mit; voll offline. `PdfPreview` aus dem Paket nicht verwendet, weil
  dessen Knopfleiste oben liegt und nicht gegated werden kann; eigener
  Betrachter mit `Printing.raster` und eigener Leiste. Rasterung und Druck
  sind für Tests austauschbar. R8: keine Reflection, keine Regel nötig; iOS
  ab 15 erfüllt die Podspec (P-D54).
- **Rechtsanwalt – Willkommensseite (P-R60):** „mit der Qualität von Profis“
  ist eine nicht nachprüfbare Qualitätsbehauptung und könnte als irreführend
  gelten (§ 2 UWG AT, § 5 UWG DE), zumal die App keine Steuerberatung ersetzt;
  gewählt wurde „nach den Regeln, die auch Profis anwenden“ (nachprüfbar:
  Belegprinzip, USt je Position, GoBD-Unveränderbarkeit). „E-Rechnung
  schreiben“ nicht genannt, solange nicht gebaut.
- **Steuerberater:** Abgabenkategorien bleiben in jedem Anspruch normale
  Buchungen; die Hinzurechnung nicht abziehbarer Abgaben in der E/A (FA-19.4)
  läuft unabhängig vom Tarif weiter – nur die Schätzung ist Pro.
- **UX:** Betrachter-Leiste unten in der Daumenzone, drei gleich breite
  Knöpfe 56 dp mit Symbol über Text (lesbar bei großer Schrift), „Senden“
  rechts gefüllt, „Schließen“ links – kein Gefahrenknopf. Demo: Knöpfe
  gedimmt, aber tippbar mit Erklärung statt stumm deaktiviert. Hinweiszeile
  „Abgaben & Rücklagen (Pro)“ 56 dp, ganze Zeile tippbar. Willkommensseite:
  Logo und Text oben, Liste darunter, große Knöpfe unverändert unten; passt
  ohne Scrollen auf 360 × 740 dp (Widget-Test). Gerätetest P-X26.


### Ergebnisse der internen Prüfung (2026-10-19) – Rückmeldung zu 0.30.0

- **UX – Mithelfer-Gerät:** Eine eigene Frage „Hauptgerät oder Mithelfer?“
  nach „Los geht's“ kostete jede Hauptnutzerin einen Schritt. Entschieden:
  Nebenoption oben in Schritt 2 („Dieses Gerät ist ein Mithelfer-Gerät
  (koppeln)“, 48 dp, „?“ daneben), weit weg vom Hauptknopf unten – kein
  Fehltipp, keine Pflichtfrage. Der Mithelfer erreicht sie mit zwei Tipps.
- **UX – Aufnahmeleiste:** Ausblenden nur bei echter Scrollbewegung; liegt
  ein Finger auf der Leiste, bleibt sie; ausgeblendet keine Tipps (kein
  Phantomtipp in eine unsichtbare Fläche); 5 s ist kurz genug, damit sie
  nach dem Lesen wieder da ist; ganz oben sofort. Bedienungshilfen: Leiste
  immer sichtbar, weil Screenreader-Nutzer das Scrollen nicht sehen.
  Trefferflächen unverändert (76/56 dp). Gerätetest P-X27.
- **UX – Demo-Landeswahl:** Zwei Knöpfe 56 dp im unteren Blatt, Deutschland
  gefüllt oben (größerer Markt), ein Tipp startet; Wischen nach unten bricht ab.
- **Softwareentwickler – PDF dunkel:** Ursache: `Printing.raster` liefert
  PNG mit transparentem Hintergrund, das auf dunklem `Material` lag. Lösung:
  weißes Papier, keine Tönung, keine Filter; Test im dunklen Thema.
- **Steuerberater – Grenzen (P-S85):** DE § 19 Abs 1 UStG i. d. F. JStG 2024
  (ab 01.01.2025): Vorjahr 25.000 €, laufendes Jahr 100.000 €, Wegfall ab
  dem Umsatz, mit dem 100.000 € überschritten werden; im Gründungsjahr
  25.000 €. AT § 6 Abs 1 Z 27 UStG i. d. F. Progressionsabgeltungsgesetz
  2025: 55.000 € brutto, Toleranz 10 % bis Jahresende, Fünfjahresregel
  entfallen. Code (`TaxProfile`) war bereits je Land richtig; neu ist nur die
  Anzeige der 25.000-€-Folgejahresgrenze in DE. Sicherheit hoch.
- **Rechtsanwalt (P-R61):** Gekürzte Funktionszeilen nennen nur Gebautes;
  „E-Rechnung lesen“ statt „empfangen“ ist enger und richtig. Deutsche Demo
  nur mit erfundenen Namen. Sicherheit mittel.


### Ergebnisse der internen Prüfung (2026-10-19) – E-Rechnung erstellen

- **Steuerberater – Formate und Pflicht:** DE: Empfang seit 01.01.2025 für
  alle Pflicht; Ausstellen ab 01.01.2027 bei Vorjahresumsatz über 800.000 €,
  ab 01.01.2028 für alle (§ 14 Abs 1, § 27 Abs 38 UStG i. d. F.
  Wachstumschancengesetz); Kleinunternehmer ausgenommen (§ 34a UStDV),
  ebenso Kleinbetragsrechnungen bis 250 €. Zulässig sind EN-16931-konforme
  Formate (XRechnung, ZUGFeRD ab Profil EN 16931/COMFORT; nicht MINIMUM und
  BASIC-WL). B2G DE: XRechnung mit Leitweg-ID (E-Rechnungsverordnung des
  Bundes). AT: keine allgemeine B2B-Pflicht (P-S6); Bund verlangt
  e-Rechnung (IKT-KonG, E-Rechnung-UStV), Formate ebInterface oder
  XRechnung/Peppol, Auftragsreferenz und Lieferantennummer Pflicht. Für
  Kleinunternehmer Kategorie `E` mit dem gesetzlichen Hinweis als
  Befreiungsgrund (P-S86). Sicherheit hoch (Pflichten), mittel (Kodierung).
- **Softwareentwickler – Umsetzung:** Writer auf den Modellen der App
  (`Invoice`, `InvoiceTotals`), Rundreise über den vorhandenen
  `EInvoiceParser`. PDF/A-3 mit dem schon genutzten Paket `pdf` 3.13
  (`PdfaRdf`, `PdfaFacturxRdf`, `PdfaColorProfile`, `PdfaAttachedFiles`),
  keine neue Abhängigkeit; XMP und Info-Wörterbuch gleich befüllt.
  Ergebnis Mustang 2.26 (veraPDF + EN-16931- und XRechnung-3.0-Schematron):
  alle 13 Muster (KU, Regelbesteuerung mit 19/7 %, Positions- und
  Gesamtrabatt, Versand, Skonto, Storno, AT) **gültig**, PDF/A-3b konform.
  ebInterface 6.1 XSD-gültig. KoSIT-Validator in der CI: P-D56.
- **Rechtsanwalt (P-R64):** Werbeaussage erst jetzt, nachdem gebaut und
  getestet; ICC-Profil frei weitergebbar; Schemadateien nur in Tests.
- **UX:** Normalfall ohne jede Frage (ZUGFeRD steckt im PDF); Behörde einmal
  bei der Kundin wählen, Feld erscheint erst dann; im Betrachter bleibt die
  Leiste gleich, nur „XML senden“ statt „Senden“ und eine Hinweiszeile.
  Ohne Befund. Gerätetest P-X28.
- **Tarif (O-44, entschieden 2026-10-19: ab Basis):** zuerst nach Lastenheft
  5.10 als Pro umgesetzt, jetzt ab Basis, weil das Ausstellen in DE ab 2028 Pflicht für alle
  Regelbesteuerten wird und eine Buchhaltungs-App ohne gesetzlich nötiges
  Format im Basis-Tarif schwer zu vermitteln ist; Änderung ist eine Zeile.

### Ergebnisse der internen Prüfung (2026-10-20) – Buchungsregeln

- **Steuerberater:** Privatanteil ist keine Betriebsausgabe (AT § 20 Abs 1 Z 1
  EStG 1988, DE § 12 Nr. 1 EStG); Vorsteuer nur im unternehmerischen Ausmaß,
  10-%-Grenze in beiden Ländern (§ 12 Abs 2 Z 1 lit a UStG 1994, § 15 Abs 1
  Satz 2 UStG). DE erlaubt alternativ volle Zuordnung mit Wertabgabe; die App
  wählt die vorsichtige Aufteilung (P-S88). AT-PKW: Vorsteuerausschluss
  unabhängig von der Regel (P-S88 b). Kleinunternehmer brutto. Hilfewerte
  P-S89, P-S90. Sicherheit mittel.
- **Rechtsanwalt:** Werkzeug ohne Einzelfallempfehlung zulässig; Hinweis
  „Grundlage für die Steuerberatung – ersetzt keine individuelle Beratung“
  überall, wo Zahlen entstehen (P-R65). KI-Chat: Formulierung des
  Auftraggebers „ersetzt ein Gespräch“ nicht verwenden, stattdessen „bereitet
  das Gespräch mit der Steuerberatung vor und spart Zeit“ (P-R66).
- **Softwareentwickler:** neue Migration 31, keine bestehende geändert;
  Rundung je Zeile, Summen exakt (Test über −4 € bis 4 € und acht Anteile);
  Regeln werden in `totals` ausgewertet, alle Aufrufer übergeben
  `TaxProfile.mixedUse`; Anhänge im Belegordner und damit in der Sicherung.
- **UX:** Vorlage aus der Hilfe = ein Tipp bis zum vorbefüllten Formular,
  Speichern unten 56 dp, Zahlen statt Prozentrechnen (Anteil wird berechnet),
  Ausnahme als Schalter an der Buchung, keine Rückfrage beim Buchen
  (Leitprinzip). Gerätetest P-X29.
- **Tarif:** Pro (Entscheidung Auftraggeber 2026-10-20, O-47).
