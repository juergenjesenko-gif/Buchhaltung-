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

Nachgeprüft von der Prüfinstanz **Steuerberater** am 2026-10-30 an amtlichen
Quellen. **Methode und Grenze:** Direktabruf von revenue.ie, gov.ie,
irishstatutebook.ie und citizensinformation.ie ist aus der
Entwicklungsumgebung gesperrt (Proxy 403 bzw. DNS nicht aufgelöst). Geprüft
wurde über eine Websuche, die auf diese Domains beschränkt war; die Werte
stammen aus den dort angezeigten Textauszügen der genannten amtlichen Seiten.
„hoch“ = mehrere amtliche Auszüge stimmen überein; vor Umsetzung im Code die
URL einmal im Browser öffnen (Grundregel 8).

| Feld / Thema | Wert | Fundstelle (amtlich) | Sicherheit | Real? |
|---|---|---|---|---|
| Steuerjahr | Kalenderjahr | https://www.revenue.ie/en/self-assessment-and-self-employment/guide-to-self-assessment/pay-file-system.aspx | hoch | nein |
| Währung | EUR | – | hoch | nein |
| VAT-Schwelle Waren | **€85.000** Jahresumsatz (seit 1.1.2025, FA 2024; 2026 unverändert); gilt auch bei gemischten Umsätzen, wenn ≥ 90 % aus Warenlieferungen | https://www.revenue.ie/en/vat/vat-registration/who-should-register-for-vat/vat-thresholds.aspx ; https://www.revenue.ie/en/tax-professionals/documents/notes-for-guidance/vat/vat-guidance-notes-fa2024.pdf | hoch | nein |
| VAT-Schwelle Dienstleistungen | **€42.500** Jahresumsatz (seit 1.1.2025) | ebd. | hoch | nein |
| Zeitraumregel der Schwelle | „annual turnover … in any continuous period of 12 months“ (rollierend), Registrierung freiwillig darunter möglich; Wortlaut s.6 VATCA 2010 nicht im Original eingesehen | https://www.revenue.ie/en/vat/vat-registration/who-should-register-for-vat/vat-thresholds.aspx ; https://www.revenue.ie/en/tax-professionals/tdm/income-tax-capital-gains-tax-corporation-tax/part-38/38-01-03b.pdf | mittel | ja (P-IE-01) |
| Erwerbsschwelle innergemeinschaftl. Erwerb | €41.000 (getrennt von den Registrierungsschwellen) | https://www.revenue.ie/en/vat/vat-registration/goods-services-abroad/index.aspx | hoch | nein |
| EU-SME-Scheme (grenzüberschreitend, ab 1.1.2025) | Unionsumsatz bis €100.000 | https://www.revenue.ie/en/tax-professionals/tdm/value-added-tax/eu-vat-sme-scheme/eu-vat-sme-scheme.pdf | mittel | ja |
| VAT-Sätze 2026 | 23 % Standard; 13,5 % reduziert (z. B. Brennstoffe, Bauleistungen, Reinigung, Kurzzeit-Mietwagen); **9 % zweiter reduzierter Satz: ab 1.7.2026 zusätzlich Friseurleistungen sowie Speisen/Getränke (ohne Alkohol, Flaschenwasser, Softdrinks) in Restaurant, Catering, heißem Take-away – vorher 13,5 %; ohne Befristung; Hotelübernachtung bleibt 13,5 %** (FA 2025); 4,8 % Vieh (ohne Hühner), Windhunde, Pferdemiete; 0 % (Export, Grundnahrungsmittel, Bücher, Kinderkleidung); Pauschalausgleich Landwirte 4,5 % | https://www.revenue.ie/en/vat/vat-rates/search-vat-rates/current-vat-rates.aspx ; https://www.revenue.ie/en/vat/vat-rates/what-are-vat-rates/second-reduced-rate-vat.aspx ; https://www.revenue.ie/en/tax-professionals/documents/notes-for-guidance/vat/vat-guidance-notes-fa2025.pdf ; https://www.gov.ie/en/department-of-finance/press-releases/government-marks-reduction-of-vat-rate-to-9-for-food-businesses-and-hairdressers/ | hoch | nein |
| VAT-Erklärung VAT3 | zweimonatlich (Jan–Feb, Mär–Apr, … Nov–Dez); Erklärung und Zahlung bis **19.** des Folgemonats, bei Abgabe **und** Zahlung über ROS bis **23.** | https://www.revenue.ie/en/vat/accounting-for-vat/how-to-account-for-value-added-tax/when-vat-becomes-payable.aspx | hoch | nein |
| Andere Perioden | auf Antrag/Zuteilung: monatlich (Dauer-Erstattungsfälle), vier- oder sechsmonatlich bei geringer Jahresschuld (€3.001–€14.400 bzw. darunter), jährlich mit Lastschrift; Revenue stellt Lastschrift auf VDD um, dabei Rückkehr zu zweimonatlich | ebd.; https://www.revenue.ie/en/starting-a-business/documents/direct-debit-modernisation.pdf ; https://www.revenue.ie/en/tax-professionals/calendar/index.aspx | mittel | ja (P-IE-02) |
| VAT RTD (Return of Trading Details) | jährlich, Pflicht für alle VAT-Registrierten, zusammen mit der letzten VAT3 des Wirtschaftsjahres; Frist laut Kalender/Agent's Guide 2026 **19.**, laut RTD-Leitfaden **23.** (ROS) des Folgemonats nach Ende des Wirtschaftsjahres | https://www.revenue.ie/en/tax-professionals/tdm/value-added-tax/part09-obligations-accountable-persons/return/VAT-RTD-S76.pdf ; https://www.revenue.ie/en/tax-professionals/calendar/index.aspx | mittel (Quellen widersprechen sich beim Tag) | ja (P-IE-02) |
| VAT Moneys Received Basis | auf Antrag; Grenze €2 Mio in 12 Monaten (bzw. überwiegend B2C-Umsätze) | https://www.revenue.ie/en/vat/accounting-for-vat/accounting-for-vat-on-moneys-received/vat-moneys-received-basis-eligibility-cancellation.aspx | mittel | ja |
| Rechnungspflicht | VAT-Rechnung Pflicht an andere Unternehmer, öffentliche Stellen, Unternehmer in anderen EU-Staaten; **an Privatpersonen keine Pflicht** (Revenue kann nach s.108B VATCA ein Dokument verlangen); Ausstellung binnen **15 Tagen nach Ende des Leistungsmonats**; Nicht-Registrierte dürfen keine VAT ausweisen (sonst Steuerschuld) | https://www.revenue.ie/en/vat/vat-records-invoices-credit-notes/invoices/who-must-issue-vat-invoice.aspx ; https://www.revenue.ie/en/vat/vat-records-invoices-credit-notes/invoices/what-is-vat-invoice.aspx ; https://www.revenue.ie/en/vat/interest-and-penalties/invoices-issued-by-unregistered-persons/index.aspx | hoch | nein |
| Rechnungspflichtangaben | s.66 VATCA 2010 i. V. m. Reg. 20 S.I. 639/2010: Ausstellungsdatum, fortlaufende eindeutige Nummer, voller Name/Anschrift/VAT-Nr. Lieferant, Name/Anschrift Kunde, Menge und Art der Leistung, Leistungsdatum (bzw. Anzahlungsdatum), Nettoentgelt je Satz, Einzelpreis netto, Rabatte, VAT-Satz, VAT-Betrag je Satz; **bei Reverse Charge: VAT-Nr. des Kunden und Vermerk „reverse charge applies“, kein VAT-Betrag**; Margen-/Auktionatorschema ohne VAT-Ausweis | https://www.revenue.ie/en/vat/vat-records-invoices-credit-notes/invoices/information-required-vat-invoice.aspx ; https://www.irishstatutebook.ie/eli/2010/si/639/made/en/print | hoch (Regel-Nr. 20 im Volltext nicht eingesehen) | nein |
| Kleinbetragsrechnung | **keine amtliche Betragsgrenze** wie § 33 UStDV / § 11 Abs. 6 UStG-AT gefunden; Kassenbon an Privatkunden genügt, da dort keine Rechnungspflicht | wie oben | niedrig | ja (P-IE-03) |
| VAT-Nr. | IE + 7 Ziffern + 1 Buchstabe, oder + 2 Buchstaben (neues Format, z. B. IE1234567AA); Altformat Ziffer–Buchstabe–5 Ziffern–Buchstabe (z. B. 1F23456T) noch im Umlauf; Prüfung über VIES | https://www.revenue.ie/en/tax-professionals/tdm/value-added-tax/vat-information-exchange-system-VIES/vies-traders-manual.pdf ; https://www.revenue.ie/en/tax-professionals/tdm/income-tax-capital-gains-tax-corporation-tax/part-38/38-01-03b.pdf | hoch | nein |
| Reverse Charge / ZM | B2B-Dienstleistungen an EU-Unternehmer: Ort beim Kunden, VAT-Nr. prüfen und angeben, Rechnung mit Reverse-Charge-Vermerk; innergemeinschaftliche Warenlieferung 0 %; VIES-Meldung – strukturell wie AT/DE | https://www.revenue.ie/en/vat/vat-on-services/when-is-vat-charged-on-services/vat-obligations-of-Irish-traders-supplying-services-to-business-customers-abroad.aspx ; https://www.revenue.ie/en/vat/goods-and-services-to-and-from-abroad/intracommunity-supplies/supplies-of-goods-to-businesses-in-the-european-union-eu.aspx | hoch | nein |
| Einkommensteuer-Erklärung | Form 11 für 2025: **31.10.2026** (fällt auf Samstag, keine allgemeine Verschiebung); ROS-Verlängerung bis **Mi 18.11.2026** nur, wenn Abgabe **und** Zahlung (Restschuld 2025 + Preliminary Tax 2026) über ROS; Datum wird jährlich per eBrief festgelegt | https://www.revenue.ie/en/tax-professionals/ebrief/2026/no-0342026.aspx ; https://www.revenue.ie/en/self-assessment-and-self-employment/filing-your-tax-return/index.aspx | hoch | nein |
| Preliminary Tax | fällig 31.10. des laufenden Jahres (mit Form 11 Vorjahr): mind. 90 % laufendes Jahr oder 100 % Vorjahr oder 105 % Vor-Vorjahr (nur bei Lastschrift und wenn Vor-Vorjahr nicht null) | https://www.revenue.ie/en/self-assessment-and-self-employment/guide-to-self-assessment/preliminary-tax.aspx | hoch | nein |
| Aufbewahrung | **6 Jahre** ab dem Geschäftsvorfall (Einkommensteuer s.886 TCA 1997, VAT s.84 VATCA 2010); kürzer nur mit schriftlicher Genehmigung; Ausnahmen für Immobilienfälle | https://www.revenue.ie/en/vat/vat-records-invoices-credit-notes/vat-records-to-be-kept/how-long-keep-records.aspx ; https://www.revenue.ie/en/self-assessment-and-self-employment/dcpl/record-keeping/index.aspx | hoch | nein |
| PRSI Class S | 4,2 % bis 30.9.2026, **4,35 % ab 1.10.2026**; für Selbstveranlagung **Mischsatz 4,2375 % auf das Einkommen 2026**; Mindestbeitrag €650; Pflicht ab €5.000 Jahreseinkommen | https://www.gov.ie/en/department-of-social-protection/publications/prsi-class-s-rates/ ; https://www.citizensinformation.ie/en/social-welfare/irish-social-welfare-system/social-insurance-prsi/class-s-prsi/ | hoch | nein |
| USC | gestaffelt, +3 % Zuschlag für Selbstständige über €100.000 (Bänder 2026 hier nicht geprüft) | https://www.revenue.ie/en/jobs-and-pensions/usc/ | mittel | ja |
| Kilometer / Reisekosten | **keine Pauschale für Selbstständige:** Revenue erkennt Civil-Service-Kilometer- und Tagessätze bei sole traders ausdrücklich **nicht** an; tatsächliche Kfz-Kosten anteilig nach Verhältnis betriebliche/gesamte Kilometer; Pkw-Abschreibung 12,5 % über 8 Jahre, Höchstwert €24.000, CO2-abhängig (ab 1.1.2027 strengere Bänder) | https://www.revenue.ie/en/employing-people/employee-expenses/travel-and-subsistence/civil-service-rates.aspx ; https://www.revenue.ie/en/tax-professionals/tdm-wm/income-tax-capital-gains-tax-corporation-tax/part-11/11-00-01.pdf | hoch | nein |
| Home Office | tatsächliche Kosten anteilig (Strom, Heizung, Breitband); Remote Working Relief 30 % gilt für Arbeitnehmer | https://www.revenue.ie/en/jobs-and-pensions/eworking/ | mittel | ja |
| Bewirtung | nicht abziehbar (TCA 1997 s.840), Vorsteuer nicht abziehbar | – | mittel | ja |
| Abschreibung | Wear & Tear Allowance 12,5 % über 8 Jahre | https://www.revenue.ie/en/tax-professionals/tdm-wm/income-tax-capital-gains-tax-corporation-tax/part-11/11-00-01.pdf | mittel | ja |
| Fristverschiebung Feiertage | **keine allgemeine Regel** „Wochenende/Feiertag → nächster Werktag“ bei Revenue; Revenue legt Ersatzdaten einzeln fest (eBrief); nur Lastschrifteinzug am 9. rückt auf nächsten Werktag. Feiertagskalender IE (10 public holidays inkl. St Brigid's Day) daher nur für Anzeige/Lastschrift | https://www.revenue.ie/en/tax-professionals/tdm/collection/direct-debit/preliminary-income-tax-direct-debit-guidelines.pdf ; https://www.citizensinformation.ie/en/employment/employment-rights-and-conditions/leave-and-holidays/public-holidays/ | mittel | ja (P-IE-04) |
| Verzugszinsen | EU-Zahlungsverzugsrichtlinie (S.I. 580/2012): EZB + 8 %, Pauschale €40/€70/€100 | – | mittel | ja |
| Rechtsform | sole trader: keine Eintragung in ein Register, Anmeldung nur bei Revenue (Form TR1); **CRO nur bei Business Name** (Handeln unter einem anderen als dem eigenen Familiennamen), binnen 1 Monat, €20 online / €40 Papier; Business Name schafft keine eigene Rechtsperson | https://cro.ie/registration/business-name/ ; https://www.revenue.ie/en/starting-a-business/starting-a-business/registering.aspx ; https://www.citizensinformation.ie/en/employment/types-of-employment/self-employment/becoming-self-employed/ | hoch | nein |

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
- IE (Stand 2026-10-30): P-IE-01 Wortlaut Zeitraumregel s.6 VATCA;
  P-IE-02 VAT-Perioden/RTD-Frist (19. oder 23.) bei Steuerberater oder ROS;
  P-IE-03 Kleinbetragsrechnung/Kassenbon; P-IE-04 Fristverschiebung bei
  Wochenende/Feiertag; Direktabruf revenue.ie im Browser nachholen.
- US: Mileage-Halbjahresanpassung 76 ¢; 1099-NEC $2.000; Bundesstaat-Thematik.
