# Regelpflege – Steuerwerte aktuell halten

**Stand:** 2026-10-20 · Entscheidung Auftraggeber 2026-10-20 (Lastenheft 14a)

Diese Datei ist die Checkliste für **jeden Rechts- und Steuerwert**, den die App
fest eingebaut hat. Sie wird von einer **wöchentlichen automatischen
Recherche-Routine** gelesen und vor jedem Jahreswechsel vollständig
abgearbeitet. Jeder Wert steht mit amtlicher Quelle, üblichem
Veröffentlichungszeitpunkt, Codestelle und `spec.*`-Schlüssel
(`docs/SPECIFICATION.md` Abschnitt 12, geprüft von
`test/specification_sync_test.dart`).

Die App kennt ihren eigenen Regelstand: `TaxProfile.rulesAsOf` und
`TaxProfile.rulesValidUntil` (`spec.at.rules_as_of`,
`spec.at.rules_valid_until`, `spec.de.…`). Ist der Tag nach
`rulesValidUntil` erreicht, zeigt die Übersicht „Für <Jahr> gibt es neue
Steuerwerte – bitte App aktualisieren.“ (FA-21.2). **Mit jedem Jahrespaket
werden beide Daten erhöht** – erst wenn alle Werte unten für das neue Jahr
geprüft sind.

## Ablauf (jede Änderung)

1. **Recherche:** amtliche Quelle aus der Tabelle abrufen, Fassung und Datum
   notieren; Sekundärquellen nur als Hinweis.
2. **Prüfinstanz:** Steuerberater (Werte, Fristen), Rechtsanwalt (Texte,
   Store), Softwareentwickler (Formate, ERiC) beantworten selbstständig mit
   Quelle und Sicherheit (CLAUDE.md „Oberstes Gesetz“). Unsicheres in
   `SPECIFICATION.md` Abschnitt 14 als Prüfpunkt.
3. **Ändern:** Wert in der Codestelle (nur `TaxProfile` bzw. die genannte
   Konstante, GR-6), Fundstelle als Kommentar (Grundregel 8), `spec.*`-Wert,
   Tests; Spezifikation (Abschnitte 3, 5, 12, 13), Handbuch, falls genannt.
4. **Regelstand** (`rulesAsOf`, `rulesValidUntil`) erst erhöhen, wenn alle
   Werte des neuen Jahres für das Land geprüft sind.
5. **Release:** Version erhöhen, `RELEASE_NOTES.md` mit Commit, Build über CI,
   Store-Update. Übergang: Werte mit Gültigkeitsdatum (z. B. Steuersatz ab
   1.7.) im Voraus einbauen, nie rückwirkend raten.

## Kalender

| Wann | Was | Länder |
|---|---|---|
| wöchentlich | BGBl/RIS-Neuerungen, BMF-Info, Bundesgesetzblatt DE, BMF-Schreiben DE; Store-Richtlinien | AT, DE |
| Ende Dez./Anfang Jan. | Basiszinssatz zum 1.1. | AT, DE |
| Ende Juni/Anfang Juli | Basiszinssatz zum 1.7. | AT, DE |
| Sept.–Okt. | Progressionsabgeltung AT (Tarifstufen, Absetzbeträge), Kilometergeld | AT |
| Okt.–Nov. | SVS-Werte (Beitragsgrundlagen, UV-Beitrag) des Folgejahres | AT |
| Nov.–Dez. | Jahressteuergesetz DE, Grundfreibetrag/Tarif § 32a, Soli-Freigrenze | DE |
| Dez. | Store: Ziel-API Android (Frist meist 31.8.), Xcode/iOS-SDK-Pflicht (meist April) | — |
| jährlich vor 31.12. | **Regelstand** erhöhen, Prüfmappen neu erzeugen | AT, DE |

## Österreich

| Wert | Codestelle | `spec.*` | Amtliche Quelle | Veröffentlicht |
|---|---|---|---|---|
| Umsatzsteuersätze (20/13/10/4,9 % ab 1.7.2026) | `lib/domain/country.dart` `TaxProfile.austria.vatRates` | `spec.at.vat_permille`, `spec.at.vat_49_valid_from`, `spec.at.default_vat_permille` | https://www.ris.bka.gv.at/GeltendeFassung.wxe?Abfrage=Bundesnormen&Gesetzesnummer=10004873 (UStG 1994 § 10) | mit Budgetbegleitgesetz, meist Herbst |
| Kleinunternehmergrenze 55.000 €, Toleranz | `TaxProfile.austria.currentYearTurnoverLimit`, `toleranceLimit`, `previousYearTurnoverLimit` | `spec.at.turnover_limit_cents`, `spec.at.tolerance_limit_cents`, `spec.at.previous_year_limit_cents`, `spec.at.turnover_basis` | UStG 1994 § 6 Abs 1 Z 27 (RIS wie oben) | unregelmäßig (AbgÄG) |
| Kleinbetragsrechnung 400 €, UID-Pflicht > 10.000 € | `smallAmountInvoiceLimit`, `largeInvoiceVatIdLimit` | `spec.at.small_amount_invoice_limit_cents`, `spec.at.large_invoice_vat_id_limit_cents` | UStG 1994 § 11 | unregelmäßig |
| UVA-Grenze monatlich (100.000 €), Intervall | `monthlyVatReturnThreshold`, `vatIntervalBasis` | `spec.at.monthly_vat_return_threshold_cents`, `spec.at.vat_interval_basis` | UStG 1994 § 21; https://www.bmf.gv.at | unregelmäßig |
| Fristen UVA, ESt, SVS, ZM, OSS | `TaxProfile.austria.deadlineRules`, `registrationDeadlineRules` | `spec.at.deadline_rules`, `spec.at.registration_deadline_rules` | UStG § 21, BAO § 108, EStG § 45, https://www.svs.at | bei Gesetzesänderung |
| Aufbewahrung 7 Jahre | `retentionYears` | `spec.at.retention_years` | BAO § 132, https://www.ris.bka.gv.at/GeltendeFassung.wxe?Abfrage=Bundesnormen&Gesetzesnummer=10003940 | selten |
| Basiszinssatz (Verzugszinsen) | `TaxProfile.austria` `dunning.baseRates` | `spec.at.dunning_base_rates` | https://www.oenb.at/Statistik/Standardisierte-Tabellen/zinssaetze-und-wechselkurse/zinssaetze.html | 1.1. und 1.7. (Veröffentlichung kurz davor) |
| Verzugszinsen, Pauschale 40 € | `dunning` | `spec.at.dunning_*` | UGB § 456, § 458; ABGB § 1000 | selten |
| AfA, GWG 1.000 €, Halbjahresregel, Nutzungsdauern | `TaxProfile.austria.depreciation` | `spec.at.depreciation` | EStG 1988 § 7, § 13, https://www.ris.bka.gv.at/GeltendeFassung.wxe?Abfrage=Bundesnormen&Gesetzesnummer=10004570 | Budget/Steuerreform |
| Bewirtung 50 % | `TaxProfile.austria.entertainment` | `spec.at.entertainment` | EStG § 20 Abs 1 Z 3; UStG § 12 Abs 2 Z 2 lit a | selten |
| Gemischte Nutzung 10 % | `TaxProfile.austria.mixedUse` | `spec.at.mixed_use` | UStG § 12 Abs 2 Z 1 lit a | selten |
| Einkommensteuertarif je Jahr | `lib/domain/levy_rules.dart` (`TaxProfile.austria.levies.incomeTaxByYear`) | `spec.at.income_tax_<Jahr>` | EStG § 33; Progressionsabgeltungs-VO, https://www.bmf.gv.at | Sept.–Okt. für Folgejahr |
| Gewinnfreibetrag | `levies.profitAllowance` | `spec.at.profit_allowance` | EStG § 10 | Budget |
| SVS: PV/KV/SV-Sätze, UV, Mindest-/Höchstbeitragsgrundlage, KU-Ausnahme | `levies.socialInsurance` | `spec.at.social_insurance`, `spec.at.social_insurance_business_expense` | GSVG §§ 25, 25a, 27, https://www.ris.bka.gv.at/GeltendeFassung.wxe?Abfrage=Bundesnormen&Gesetzesnummer=10008422; Werte: https://www.svs.at | Okt.–Nov. (ASVG-Aufwertungszahl) |
| Arbeitsplatzpauschale 1.200/300 €, Kilometergeld 0,50 € | nur Handbuch Kapitel 18 (keine Rechnung) | – (P-S89, P-S90) | EStG § 4 Abs 4 Z 8, § 26 Z 4 | Budget |
| PKW-Vorsteuerausschluss, Luxustangente 40.000 € | Handbuch Kapitel 18, Demo | – | UStG § 12 Abs 2 Z 2 lit b; PKW-Angemessenheits-VO | selten |
| Kennzahlen UVA (U30), E1a | `vatReturnForm`, `annualReturnForm`; `lib/services/tax_office/u30_xml.dart` `U30Xml.schemaVersion` | `spec.at.vat_return_kz`, `spec.at.annual_return_kz`, `spec.at.reverse_charge_kz`, `spec.u30_schema_version` | https://www.bmf.gv.at/services/finanzonline/informationen-fuer-softwarehersteller.html | Formularjahr, meist Dez. |
| E-Rechnung Bund (ebInterface-Version) | `lib/services/e_invoice/` | `spec.einvoice_ebinterface_namespace` | https://www.erechnung.gv.at, https://www.ebinterface.at | neue Version ca. alle 2–3 Jahre |
| OSS-Schwelle 10.000 € | `lib/domain/country.dart` | `spec.oss_threshold_cents` | MwStSystRL Art 59c; UStG Art 3 Abs 5 BMR | selten |

## Deutschland

| Wert | Codestelle | `spec.*` | Amtliche Quelle | Veröffentlicht |
|---|---|---|---|---|
| Umsatzsteuersätze 19/7 % | `TaxProfile.germany.vatRates` | `spec.de.vat_permille`, `spec.de.default_vat_permille` | https://www.gesetze-im-internet.de/ustg_1980/__12.html | bei Gesetzesänderung |
| Kleinunternehmer 25.000/100.000 €, Gründungsjahr | `currentYearTurnoverLimit`, `previousYearTurnoverLimit`, `foundingYearLimit` | `spec.de.turnover_limit_cents`, `spec.de.previous_year_limit_cents`, `spec.de.founding_year_limit_cents`, `spec.de.turnover_basis` | https://www.gesetze-im-internet.de/ustg_1980/__19.html | Jahressteuergesetz (Nov.–Dez.) |
| Kleinbetragsrechnung 250 € | `smallAmountInvoiceLimit` | `spec.de.small_amount_invoice_limit_cents` | https://www.gesetze-im-internet.de/ustdv_1980/__33.html | selten |
| UStVA monatlich > 9.000 €, Neugründer | `monthlyVatReturnThreshold` | `spec.de.monthly_vat_return_threshold_cents` | https://www.gesetze-im-internet.de/ustg_1980/__18.html | JStG |
| Fristen UStVA, Dauerfristverlängerung, ESt-Vorauszahlung, ZM, OSS | `TaxProfile.germany.deadlineRules`, `registrationDeadlineRules` | `spec.de.deadline_rules`, `spec.de.registration_deadline_rules` | UStG § 18, AO § 108, EStG § 37 | bei Gesetzesänderung |
| Aufbewahrung 8/10 Jahre | `retentionYears` | `spec.de.retention_years` | https://www.gesetze-im-internet.de/ao_1977/__147.html | selten |
| Basiszinssatz | `TaxProfile.germany` `dunning.baseRates` | `spec.de.dunning_base_rates` | https://www.bundesbank.de/de/bundesbank/organisation/agb-und-regelungen/basiszinssatz-607820 | 1.1. und 1.7. (Veröffentlichung Ende Dez./Ende Juni) |
| Verzugszinsen +5/+9 Prozentpunkte, Pauschale 40 € | `dunning` | `spec.de.dunning_*` | BGB §§ 247, 288 | selten |
| AfA, GWG 800 €, Sammelposten 250–1.000 €, Nutzungsdauern | `TaxProfile.germany.depreciation` | `spec.de.depreciation` | https://www.gesetze-im-internet.de/estg/__6.html, § 7 EStG, AfA-Tabellen BMF | JStG / Wachstumsgesetze |
| Bewirtung 70 % | `TaxProfile.germany.entertainment` | `spec.de.entertainment` | EStG § 4 Abs 5 Satz 1 Nr. 2 | selten |
| Gemischte Nutzung 10 % | `TaxProfile.germany.mixedUse` | `spec.de.mixed_use` | UStG § 15 Abs 1 Satz 2 | selten |
| Einkommensteuertarif § 32a je Jahr | `levies.incomeTaxByYear` | `spec.de.income_tax_<Jahr>` | https://www.gesetze-im-internet.de/estg/__32a.html; BMF-Programmablaufplan | Nov.–Dez. für Folgejahr |
| Soli-Freigrenze, Kirchensteuer | `levies.surcharges` | `spec.de.surcharges` | SolZG § 3, § 4; KiStG der Länder | Nov.–Dez. |
| Gewerbesteuer Freibetrag, Messzahl, § 35 | `levies.tradeTax` | `spec.de.trade_tax` | GewStG §§ 11, 16; EStG § 35 | selten |
| Homeoffice-Pauschale 6 €/Tag, max. 1.260 €; Arbeitszimmer 1.260 € | nur Handbuch Kapitel 18 | – (P-S90) | EStG § 4 Abs 5 Satz 1 Nr. 6b, 6c | JStG |
| 1-%-Regelung, Elektro 0,25 %/0,5 %, Bruttolistenpreisgrenze, 0,30 €/km | nur Handbuch Kapitel 18 | – (P-S89) | EStG § 6 Abs 1 Nr. 4 | JStG / Wachstumsgesetze |
| Kennzahlen UStVA, Anlage EÜR | `vatReturnForm`, `annualReturnForm` | `spec.de.vat_return_kz`, `spec.de.annual_return_kz`, `spec.de.reverse_charge_kz` | https://www.elster.de; BMF-Schreiben zu den Vordruckmustern | Formularjahr, meist Nov.–Jan. |
| ERiC-Version (ELSTER-Übermittlung, noch nicht gebaut) | – | – | https://www.elster.de/elsterweb/entwickler | 2–3 Releases im Jahr |
| E-Rechnung: XRechnung-Version, Pflichtstufen 2025/2027/2028 | `lib/services/e_invoice/` | `spec.einvoice_guideline_xrechnung`, `spec.einvoice_guideline_en16931`, `spec.einvoice_zugferd_file` | https://xeinkauf.de/xrechnung/, https://www.ferd-net.de, UStG § 14, § 27 Abs 38 | XRechnung meist Jan./Juli |

## Store und Plattform

| Wert | Codestelle | Quelle | Veröffentlicht |
|---|---|---|---|
| Android Ziel-API (targetSdk) | `android/app/build.gradle*` | https://developer.android.com/google/play/requirements/target-sdk | jährlich, Frist meist 31.8. |
| Google-Play-Richtlinien (Datensicherheit, Abos) | `docs/STORE_LISTING.md` | https://support.google.com/googleplay/android-developer/answer/16810878 und Policy-Center | laufend |
| Apple SDK-/Xcode-Pflicht, Datenschutzangaben | `ios/`, `docs/STORE_LISTING.md` | https://developer.apple.com/news/upcoming-requirements/ | meist April |
| Store-Seite für den Aktualisieren-Hinweis | `lib/services/rules_freshness.dart` `RulesFreshness.storeUrl` | – | bei App-Store-Freigabe die echte App-Store-ID eintragen (P-D57) |

## Regelstand

| Land | `rulesAsOf` | `rulesValidUntil` | `spec.*` |
|---|---|---|---|
| AT | 2026-01-01 | 2026-12-31 | `spec.at.rules_as_of`, `spec.at.rules_valid_until` |
| DE | 2026-01-01 | 2026-12-31 | `spec.de.rules_as_of`, `spec.de.rules_valid_until` |
