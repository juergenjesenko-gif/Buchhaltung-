# Steuerwerte UK, Irland, USA für ein künftiges `TaxProfile`

Prüfinstanz **Steuerberater**, Stand 2026-10-27, Steuerjahr UK 2026/27,
IE 2026, US 2026. Bezug: Lastenheft 5.34, `docs/maerkte/UK_Anforderungen.md`,
Prüfpunkt P-UK-03 (SPECIFICATION §14).

Ersetzt keine Steuerberatung. Spalte „Real?“ = Bestätigung durch eine
zugelassene Fachperson im jeweiligen Land nötig. Recherche: amtliche Seiten,
wo der Abruf gelang; sonst Fachwissen bzw. Sekundärquelle (dann Sicherheit
höchstens „mittel“). Alle Werte vor Umsetzung in Code einzeln gegen die URL
nachprüfen (Grundregel 8: Fundstelle im Code).

## 0. Welche App-Annahmen brechen

| Annahme in `TaxProfile` / App | UK | IE | US |
|---|---|---|---|
| Steuerjahr = Kalenderjahr | **bricht** (6.4.–5.4.) | passt | passt |
| Währung Euro | **bricht** (GBP) | passt | **bricht** (USD) |
| USt-Logik (Sätze, Vorsteuer, Kleinunternehmer) | passt sinngemäß (VAT, Schwelle rollierend 12 Monate) | passt sinngemäß (zwei Schwellen Waren/Dienstleistungen) | **bricht vollständig** (kein VAT; Sales Tax je Bundesstaat, nicht abbildbar) |
| Kleinunternehmer = Vorjahr/laufendes Jahr | **bricht** (rollierende 12 Monate + 30-Tage-Vorschau) | **bricht** (rollierende 12 Monate) | entfällt |
| EU-Reverse-Charge, UID, OSS | entfällt (Nicht-EU seit 2021; NI-Sonderregeln) | passt (EU) | entfällt |
| Einnahmen-Ausgaben-Rechnung | passt (Cash Basis seit 2024/25 Default) | passt näherungsweise | passt (Cash Method, Schedule C) |
| Sozialversicherung als Ja/Nein (`asksSocialInsurance`) | zu grob: Class 4 NIC über Einkommensteuer | PRSI Class S + USC | Self-Employment Tax 15,3 % |
| Feiertagskalender AT/DE | neu: England/Wales, Schottland, NI | neu: IE | neu: Federal Holidays (IRS verschiebt Fristen auf nächsten Werktag) |

## 1. Vereinigtes Königreich (sole trader)

| Feld / Thema | Wert | Fundstelle | Sicherheit | Real? |
|---|---|---|---|---|
| Steuerjahr (`fiscalYear*`) | 6. April – 5. April; Tax-Year-Basis für Gewinne seit 2024/25 (Basis Period Reform) | https://www.gov.uk/basis-period-reform | hoch | nein |
| Währung | GBP, Pence als int-Cent passt | – | hoch | nein |
| VAT-Registrierungsgrenze (`currentYearTurnoverLimit`) | £90.000 steuerbarer Umsatz in rollierenden 12 Monaten **oder** Erwartung > £90.000 in den nächsten 30 Tagen allein | https://www.gov.uk/vat-registration/when-to-register | hoch | nein |
| Abmeldegrenze | £88.000 (erwartet in den nächsten 12 Monaten) | https://www.gov.uk/vat-registration/cancel-registration | hoch | nein |
| Registrierungsfrist (`registrationDeadlineRules`) | Antrag binnen 30 Tagen nach Monatsende der Überschreitung; wirksam ab 1. des zweiten Folgemonats | https://www.gov.uk/vat-registration/when-to-register | hoch | nein |
| `turnoverIncludesVat` | nein, „VAT taxable turnover“ ohne VAT; befreite Umsätze zählen nicht | ebd. | hoch | nein |
| VAT-Sätze (`vatRates`) | 20 % Standard, 5 % reduced, 0 % zero-rated (+ exempt) | https://www.gov.uk/guidance/rates-of-vat-on-different-goods-and-services | hoch | nein |
| Rechnungspflichtangaben (`invoiceLegalRef`) | VAT Regulations 1995 reg. 14; Notice 700/21 §16: lfd. Nr., Datum, Leistungszeitpunkt, Name/Anschrift/VRN Lieferant, Kunde, Beschreibung, Menge, Nettobetrag je Satz, Satz, VAT-Summe | https://www.gov.uk/guidance/record-keeping-for-vat-notice-70021 | hoch | nein |
| Simplified invoice (`smallAmountInvoiceLimit`) | bis £250 brutto | ebd. | hoch | nein |
| VAT-Nummer (`vatIdLabel`, Beispiel) | „VAT registration number“, GB + 9 Ziffern | ebd. | hoch | nein |
| Steuernummer (`taxNumberLabel`) | „Unique Taxpayer Reference (UTR)“, 10 Ziffern; National Insurance number | https://www.gov.uk/find-utr-number | hoch | nein |
| Kleinunternehmer-Hinweis auf Rechnung (`smallBusinessInvoiceNote`) | keine Pflichtformel; nicht registrierter Unternehmer darf keine VAT ausweisen | Notice 700/21 | mittel | ja |
| VAT-Erklärung (`vatReturnLabel`, Intervall) | VAT Return quartalsweise (Staggers), fällig 1 Monat + 7 Tage nach Quartalsende, nur digital (MTD for VAT); Monatsrückgabe auf Antrag; Annual Accounting bis £1,35 Mio | https://www.gov.uk/submit-vat-return | hoch | nein |
| Cash Accounting Scheme (VAT) | Eintritt bis £1,35 Mio, Austritt ab £1,6 Mio | https://www.gov.uk/vat-cash-accounting-scheme | hoch | nein |
| Flat Rate Scheme | Eintritt bis £150.000 netto; Limited-Cost-Trader 16,5 % | https://www.gov.uk/vat-flat-rate-scheme | hoch | nein |
| Einkommensermittlung | Cash Basis ist seit 2024/25 Standard (Opt-out zu Accruals); keine Umsatzgrenze mehr | https://www.gov.uk/simpler-income-tax-cash-basis | hoch | nein |
| Trading Allowance | £1.000 je Steuerjahr (statt Einzelkosten) | https://www.gov.uk/guidance/tax-free-allowances-on-property-and-trading-income | hoch | nein |
| Registrierung Self Assessment | bis 5. Oktober nach Ende des Steuerjahres, in dem > £1.000 Bruttoeinnahmen | https://www.gov.uk/register-for-self-assessment/self-employed | hoch | nein |
| Fristen Self Assessment (`deadlineRules`) | Papier 31. Okt., online 31. Jan.; Zahlung Restschuld 31. Jan. | https://www.gov.uk/self-assessment-tax-returns/deadlines | hoch | nein |
| Payments on Account | je 50 % der Vorjahreslast am 31. Jan. und 31. Juli; entfällt, wenn Vorjahr < £1.000 oder > 80 % per PAYE abgezogen | https://www.gov.uk/understand-self-assessment-bill/payments-on-account | hoch | nein |
| MTD for Income Tax – Pflicht | ab 6.4.2026 bei Bruttoeinnahmen Selbstständig+Vermietung > £50.000 (Basis 2024/25), ab 6.4.2027 > £30.000 (Basis 2025/26), ab 6.4.2028 > £20.000 (Basis 2026/27) | https://www.gov.uk/guidance/check-if-youre-eligible-for-making-tax-digital-for-income-tax ; Sekundär: https://www.litrg.org.uk/tax-nic/making-tax-digital-income-tax/when-does-making-tax-digital-start-me | mittel (gov.uk-Seite im Lauf nicht abrufbar) | ja |
| MTD Quartale | Perioden 6.4.–5.7., –5.10., –5.1., –5.4.; Updates fällig 7. Aug., 7. Nov., 7. Feb., 7. Mai; Final Declaration 31. Jan.; Kalenderquartale wählbar | https://www.gov.uk/guidance/use-making-tax-digital-for-income-tax/send-quarterly-updates | mittel | ja |
| MTD Software | App müsste HMRC-anerkannte Software sein (API-Anbindung, Fraud-Prevention-Header) – technische, nicht nur steuerliche Hürde | https://www.gov.uk/guidance/find-software-thats-compatible-with-making-tax-digital-for-income-tax | hoch | ja |
| Class 2 NIC | seit 6.4.2024 keine Pflicht mehr; freiwillig bei Gewinn < Small Profits Threshold (£6.845 in 2025/26; 2026/27-Wert prüfen) | https://www.gov.uk/self-employed-national-insurance-rates | mittel | ja |
| Class 4 NIC | 6 % zwischen £12.570 und £50.270, 2 % darüber (Schwellen eingefroren) | ebd. | mittel (Satz 2026/27 auf gov.uk prüfen) | ja |
| Personal Allowance | £12.570 (eingefroren), Abschmelzung ab £100.000 | https://www.gov.uk/income-tax-rates | hoch | nein |
| Kilometerpauschale (simplified expenses) | 45p/Meile erste 10.000 Meilen, danach 25p; Motorrad 24p, Fahrrad 20p | https://www.gov.uk/simpler-income-tax-simplified-expenses/vehicles- | hoch | nein |
| Home Office (simplified) | 25–50 h/Monat £10, 51–100 h £18, ab 101 h £26 je Monat | https://www.gov.uk/simpler-income-tax-simplified-expenses/working-from-home | hoch | nein |
| Bewirtung (`entertainment`) | Client Entertainment nicht abziehbar (ITTOIA 2005 s.45); VAT darauf nicht abziehbar | https://www.gov.uk/hmrc-internal-manuals/business-income-manual/bim45000 | hoch | nein |
| Abschreibung (`depreciation`) | keine AfA, stattdessen Capital Allowances; Annual Investment Allowance £1 Mio; unter Cash Basis Anschaffungen meist sofort abziehbar (außer Autos) | https://www.gov.uk/capital-allowances/annual-investment-allowance | hoch | nein |
| Aufbewahrung (`retentionYears`) | Self Assessment: mind. 5 Jahre nach 31. Jan.-Frist (≈ 5 Jahre 10 Monate); VAT: 6 Jahre | https://www.gov.uk/self-employed-records/how-long-to-keep-your-records ; Notice 700/21 | hoch | nein |
| Mahnwesen (`dunning`) | Late Payment of Commercial Debts (Interest) Act 1998: Base Rate + 8 %, Pauschale £40/£70/£100 – nur B2B | https://www.gov.uk/late-commercial-payments-interest-debt-recovery | hoch | nein |
| Feiertage | getrennt England & Wales / Schottland / Nordirland | https://www.gov.uk/bank-holidays | hoch | nein |
| Nordirland | für Waren EU-VAT-Regeln (Windsor Framework), XI-Präfix | https://www.gov.uk/guidance/vat-and-movements-of-goods-between-great-britain-and-northern-ireland | hoch | ja |
| `foreignTaxOffices`, Reverse Charge EU, ZM | entfällt in EU-Form; UK-Reverse-Charge für Dienstleistungen aus dem Ausland und Domestic Reverse Charge Bau | https://www.gov.uk/guidance/vat-domestic-reverse-charge-for-building-and-construction-services | mittel | ja |

## 2. Irland (sole trader)

| Feld / Thema | Wert | Fundstelle | Sicherheit | Real? |
|---|---|---|---|---|
| Steuerjahr | Kalenderjahr | https://www.revenue.ie/en/self-assessment-and-self-employment/ | hoch | nein |
| Währung | EUR | – | hoch | nein |
| VAT-Schwelle Waren | €85.000 in rollierenden 12 Monaten (ab 1.1.2025; auch wenn ≥ 90 % Umsatz aus Waren) | https://www.revenue.ie/en/vat/vat-registration/who-should-register-for-vat/ ; Sekundär PwC https://taxsummaries.pwc.com/Ireland/Corporate/Other-taxes | mittel (revenue.ie im Lauf nicht abgerufen) | ja |
| VAT-Schwelle Dienstleistungen | €42.500 in rollierenden 12 Monaten | ebd. | mittel | ja |
| EU-Kleinunternehmerregelung (SME-Scheme, grenzüberschreitend, ab 2025) | EU-weit €100.000 Unionsumsatz | https://www.revenue.ie/en/vat/ | mittel | ja |
| VAT-Sätze | 23 % Standard, 13,5 %, 9 % (Gastronomie/Friseur ab 1.7.2026 laut Sekundärquellen – **prüfen**), 4,8 % (Vieh), 0 % | https://www.revenue.ie/en/vat/vat-rates/index.aspx | mittel | ja |
| VAT-Erklärung | VAT3 zweimonatlich, fällig 19. des Folgemonats (ROS: 23.); jährlich auf Antrag; RTD jährlich | https://www.revenue.ie/en/vat/filing-and-paying-vat/index.aspx | mittel | ja |
| VAT Cash Receipts Basis | bis €2 Mio Jahresumsatz | https://www.revenue.ie/en/vat/vat-registration/cash-receipts-basis/ | mittel | ja |
| Rechnungspflichtangaben | VATCA 2010 s.66, Reg. 20 VAT Regulations 2010: Datum, lfd. Nr., Name/Anschrift/VAT-Nr. Lieferant, Kunde, Beschreibung, Menge, Leistungsdatum, Netto je Satz, Satz, VAT-Betrag; Ausstellung binnen 15 Tagen nach Monatsende | https://www.revenue.ie/en/vat/vat-records-and-invoices/ | mittel | ja |
| Vereinfachte Rechnung | keine allgemeine Betragsgrenze wie DE/AT (B2C: Rechnung grds. nicht Pflicht) | ebd. | niedrig | ja |
| VAT-Nr. | „VAT number“ IE + 7 Ziffern + 1–2 Buchstaben; Steuernummer = PPSN | – | hoch | nein |
| Einkommensteuer-Erklärung | Form 11, fällig 31. Okt. des Folgejahres (ROS-Verlängerung meist Mitte Nov.) | https://www.revenue.ie/en/self-assessment-and-self-employment/filing-your-tax-return/index.aspx | hoch | nein |
| Preliminary Tax | fällig 31. Okt. des laufenden Jahres: 90 % laufendes Jahr oder 100 % Vorjahr oder 105 % Vor-Vorjahr (nur Lastschrift) | https://www.revenue.ie/en/self-assessment-and-self-employment/preliminary-tax/index.aspx | hoch | nein |
| PRSI Class S | 4,2 % seit Okt. 2025, Anhebung auf 4,35 % ab Okt. 2026 geplant; Mindestbeitrag €650; ab €5.000 Einkommen | https://www.gov.ie/en/department-of-social-protection/ | niedrig | ja |
| USC | gestaffelt, +3 % Zuschlag für Selbstständige über €100.000 | https://www.revenue.ie/en/jobs-and-pensions/usc/ | mittel | ja |
| Kilometer | keine gesetzliche Pauschale für Selbstständige; tatsächliche Kosten anteilig (Civil-Service-Sätze nur für Arbeitgeber-Erstattungen) | – | niedrig | ja |
| Home Office | tatsächliche Kosten anteilig (Strom, Heizung, Breitband); Remote Working Relief 30 % gilt für Arbeitnehmer | https://www.revenue.ie/en/jobs-and-pensions/eworking/ | mittel | ja |
| Bewirtung | nicht abziehbar (TCA 1997 s.840), Vorsteuer nicht abziehbar | – | mittel | ja |
| Abschreibung | Wear & Tear Allowance 12,5 % über 8 Jahre; Pkw gedeckelt | https://www.revenue.ie/en/companies-and-charities/corporation-tax-for-companies/capital-allowances-and-deductions/ | mittel | ja |
| Aufbewahrung | 6 Jahre (Einkommensteuer TCA s.886, VAT s.84) | https://www.revenue.ie/en/starting-a-business/starting-a-business/keeping-records.aspx | hoch | nein |
| Verzugszinsen | EU-Zahlungsverzugsrichtlinie (S.I. 580/2012): EZB + 8 %, Pauschale €40/€70/€100 | – | mittel | ja |
| EU-Themen | Reverse Charge, ZM (VIES), OSS wie AT/DE strukturell übertragbar | – | hoch | nein |

## 3. USA (sole proprietor, bundesweit)

| Feld / Thema | Wert | Fundstelle | Sicherheit | Real? |
|---|---|---|---|---|
| Steuerjahr | Kalenderjahr (Regelfall Einzelunternehmer) | https://www.irs.gov/businesses/small-businesses-self-employed/tax-years | hoch | nein |
| Währung | USD | – | hoch | nein |
| VAT | **kein bundesweites VAT**: `vatRates`, Vorsteuer, Kleinunternehmergrenze, VAT-Erklärung, Reverse Charge nicht anwendbar | – | hoch | nein |
| Sales Tax | je Bundesstaat/Gemeinde, Nexus-Schwellen (meist $100.000) – nur Hinweis in der App, keine Berechnung | – | hoch | ja |
| Formulare | Form 1040 + Schedule C (Gewinn), Schedule SE (SE Tax); fällig 15. April | https://www.irs.gov/forms-pubs/about-schedule-c-form-1040 | hoch | nein |
| Schedule-C-Kategorien | Teil II Zeilen 8–27 (Advertising, Car and truck, Commissions, Contract labor, Depreciation/179, Insurance, Interest, Legal/professional, Office, Rent, Repairs, Supplies, Taxes/licenses, Travel, Meals 50 %, Utilities, Wages, Other) + Teil III COGS; als Kategoriensatz verwendbar | https://www.irs.gov/instructions/i1040sc | hoch | nein |
| Estimated Tax (Form 1040-ES) | 15. April, 15. Juni, 15. Sept., 15. Jan. Folgejahr; Verschiebung auf nächsten Werktag | https://www.irs.gov/businesses/small-businesses-self-employed/estimated-taxes | hoch | nein |
| Self-Employment Tax | 15,3 % (12,4 % SS + 2,9 % Medicare) auf 92,35 % des Gewinns; Pflicht ab $400 Gewinn; SS-Beitragsgrenze 2026 $184.500; +0,9 % Additional Medicare ab $200.000 | https://www.irs.gov/businesses/small-businesses-self-employed/self-employment-tax-social-security-and-medicare-taxes ; https://www.ssa.gov/oact/cola/cbb.html | hoch (Grenze 2026: mittel) | nein |
| Standard Mileage Rate 2026 | 72,5 ¢/Meile ab 1.1.2026 (IR-2025-128); Sekundärquellen melden 76 ¢ ab 1.7.2026 – **auf irs.gov nicht bestätigt** | https://www.irs.gov/newsroom/irs-sets-2026-business-standard-mileage-rate-at-725-cents-per-mile-up-25-cents | hoch (72,5) / niedrig (76) | ja |
| Home Office simplified | $5 je sq ft, max. 300 sq ft (= $1.500) | https://www.irs.gov/businesses/small-businesses-self-employed/simplified-option-for-home-office-deduction | hoch | nein |
| Meals | 50 % abziehbar; Entertainment 0 % | https://www.irs.gov/publications/p463 | hoch | nein |
| Abschreibung | MACRS, Section 179, De-minimis-Safe-Harbor $2.500 je Beleg (ohne AFS); Bonus 100 % für ab 20.1.2025 erworbene Güter (OBBBA) | https://www.irs.gov/publications/p946 | mittel | ja |
| 1099-NEC | Meldepflicht für Zahlungen an Auftragnehmer: $600 bis 2025, **$2.000 ab Zahlungen 2026** (OBBBA), danach indexiert; Frist 31. Jan. | https://www.irs.gov/instructions/i1099mec | mittel | ja |
| 1099-K | Schwelle wieder > $20.000 **und** > 200 Transaktionen (OBBBA, rückwirkend) | https://www.irs.gov/businesses/understanding-your-form-1099-k | mittel | ja |
| Rechnungspflichtangaben | keine bundesrechtlichen Pflichtangaben | – | hoch | nein |
| Aufbewahrung | 3 Jahre ab Erklärung; 6 Jahre bei > 25 % Einnahmenauslassung; 7 Jahre bei Forderungsausfall/wertlosen Wertpapieren; Lohnsteuer 4 Jahre; Anlagegüter bis Ablauf der Frist für das Veräußerungsjahr | https://www.irs.gov/businesses/small-businesses-self-employed/how-long-should-i-keep-records | hoch | nein |
| Bundesstaaten | eigene Einkommensteuer (außer z. B. TX, FL, WA, NV …), eigene Fristen – außerhalb des Rahmens eines `TaxProfile` | – | hoch | ja |

## 4. Was im `TaxProfile` fehlt (für alle drei Länder)

1. **Steuerjahresbeginn** (Tag/Monat) statt fester Kalenderjahr-Annahme (UK).
2. **Währung** je Profil (GBP, USD) inkl. Formatierung; `Money` bleibt int.
3. **Rollierende 12-Monats-Schwelle** und **Vorschau-Schwelle** (UK 30 Tage) als
   eigene Schwellenart; **getrennte Schwellen Waren/Dienstleistungen** (IE).
4. **Abmeldegrenze** (UK £88.000).
5. **Umsatzsteuer abschaltbar** (US: `hasVat = false`), Sales-Tax-Hinweistext.
6. **Pauschalen**: Kilometer gestaffelt nach Fahrleistung (UK), Home Office
   gestaffelt nach Stunden (UK) bzw. nach Fläche (US).
7. **Trading Allowance** (UK £1.000) als Alternative zu Einzelkosten.
8. **Vorauszahlungsregeln** (UK Payments on Account, IE Preliminary Tax,
   US Estimated Tax) als `DeadlineRule`s mit länderspezifischer Bemessung.
9. **Sozialabgaben auf Gewinn** (Class 4 NIC, PRSI S, SE Tax) statt Ja/Nein.
10. **MTD-Status** (UK) inkl. Quartalsperioden zum 5. des Monats.
11. **Ausgabenkategorien je Land** (Schedule C Zeilen, SA103-Felder).

## 5. Offene Prüfpunkte für §14 (nur Vorschlag, Eintrag dort, nicht hier)

- UK: MTD-Schwellen/Basisjahre und Quartalsfristen gegen gov.uk; Class 2/4
  2026/27; Anforderungen an HMRC-anerkannte Software (zu P-UK-03).
- IE: Schwellen und 9-%-Satz ab 1.7.2026 gegen revenue.ie; PRSI-Satz ab
  Okt. 2026; Vereinfachte Rechnung.
- US: Mileage-Halbjahresanpassung 76 ¢; 1099-NEC $2.000; Bundesstaat-Thematik.
