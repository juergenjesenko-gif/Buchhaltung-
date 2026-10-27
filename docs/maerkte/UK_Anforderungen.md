# UK-Markteintritt „JeNi bucht“ – Anforderungen, Ausweitung AT/DE, Fahrplan

Stand 2026-10-26 · Prüfinstanzen: Steuerberater (UK/AT/DE), Rechtsanwalt (UK/EU), Softwareentwickler, UX
Sicherheit: **H** = hoch (amtliche Quelle), **M** = mittel (Sekundärquelle / ältere Kenntnis), **N** = niedrig (bitte real prüfen).
Hinweis: Diese Ausarbeitung ersetzt keine Steuer- oder Rechtsberatung. Sie bereitet die echte Prüfung (Abschnitt C, P-Punkte) vor.

Repo-Befund (ohne Änderung): Die App erzeugt heute bereits U30-XML für FinanzOnline
(`lib/services/tax_office/u30_xml.dart`, `vat_return_figures.dart`, Bildschirm `lib/features/tax_office/tax_office_screen.dart`);
es gibt also schon einen „Datei exportieren und selbst hochladen“-Weg für AT. Eine Direktübermittlung gibt es nicht.

---

## A) Was wir für UK brauchen – Checkliste

### A1. HMRC Making Tax Digital (MTD) für Income Tax

Rahmen: MTD ITSA gilt seit **6.4.2026** für Selbstständige/Vermieter mit Einkommen > £50.000, ab **6.4.2027 > £30.000**, ab 2028 > £20.000 (H, Wikipedia/GOV.UK). Unsere Zielgruppe (Kleinunternehmerinnen) fällt größtenteils **ab April 2027** hinein – das ist genau unser Startfenster.

| # | Aufgabe | Aufwand | Wer | Sicherheit |
|---|---|---|---|---|
| 1 | Konto im HMRC Developer Hub anlegen, Sandbox-Anwendung registrieren, Testnutzer erzeugen | 1 Tag | Entwickler | H |
| 2 | APIs anbinden (Sandbox): **Business Details** (Unternehmen/ID finden), **Obligations** (Fristen für Quartale und Jahresabschluss), **Self-Employment Business** (Quartalsupdates = kumulative Periodensummen, Jahresangaben/Allowances), **Individual Calculations** (Steuerberechnung auslösen/abrufen und **Final Declaration** abgeben). Das frühere „End of Period Statement“ (EOPS) ist für MTD ITSA abgeschafft – bitte im aktuellen End-to-End-Guide gegenprüfen | 4–6 Wochen | Entwickler | M |
| 3 | **Fraud-Prevention-Header** (Gov-Client-*, Gov-Vendor-*) – gesetzliche Pflicht vor Produktionszugang; Prüfung über die „Test Fraud Prevention Headers API“. Verbindungsart für uns: `MOBILE_APP_DIRECT` (App spricht direkt mit HMRC) oder `MOBILE_APP_VIA_SERVER` (falls wir einen Server dazwischen schalten). Device-ID einmal erzeugen und dauerhaft speichern, Zeitzone, Bildschirm, Lokale IPs, User-IDs, Vendor-Version | 1–2 Wochen | Entwickler | H (Pflicht) / M (genaue Headerliste je Methode) |
| 4 | **OAuth 2.0 ohne eigenen Server?** HMRC nutzt Authorization-Code-Flow mit `client_secret`. Ein Secret in einer App ist nicht geheim (aus APK extrahierbar), und HMRC-Nutzungsbedingungen verlangen, es zu schützen. **Empfehlung: kleiner, zustandsloser Token-Tausch-Dienst** (z. B. Cloudflare Worker / Cloud Function), der nur Code→Token tauscht und **keine Buchhaltungsdaten** sieht; Steuerdaten gehen weiter direkt App→HMRC (`MOBILE_APP_DIRECT`). Tokens (Access 4 h, Refresh 18 Monate) im Keystore/Keychain (`flutter_secure_storage`). Folge: Offline-first bleibt, aber wir betreiben erstmals einen Dienst → Datenschutz-Doku (LASTENHEFT 5.19, PRIVACY, STORE_LISTING) | 1 Woche + Betrieb | Entwickler, Rechtsanwalt | M |
| 5 | **Produktionszugang**: Antrag im Developer Hub mit Nachweis der Sandbox-Tests (Testszenarien aus dem End-to-End-Guide), Fragebogen, Header-Prüfung, Demo. Erfahrungswert mehrere Wochen bis wenige Monate | 4–10 Wochen Wartezeit | Auftraggeber (Antrag), Entwickler | M |
| 6 | **Listing in HMRC-Softwareliste** („Find software that works with MTD for Income Tax“) – HMRC prüft Mindestfunktionen; Listung ist Vertriebsvoraussetzung | im Antrag enthalten | Auftraggeber | M |
| 7 | **Mindestfunktionen**: digitale Aufzeichnungen je Geschäftsvorfall (haben wir), Quartalsupdates, Jahreskorrekturen, Steuerberechnung anzeigen, Final Declaration (HMRC erlaubt für den Start teils „Teilumfang + andere Software“; Endziel End-to-End). **Bridging** (Tabelle → Software) ist für Nutzer erlaubt, aber für uns irrelevant, weil wir selbst Aufzeichnungen führen. Digitale Verbindungen zwischen Programmen: kein Abtippen | in #2 | Entwickler, Steuerberater | M |
| 8 | **Ausgabenkategorien → SA103-Felder** (SA103F Box 17–30 bzw. „consolidated expenses“ bei Umsatz < £90.000, Box 20/SA103S). Jede App-Kategorie bekommt eine UK-Zuordnung in `TaxProfile` (z. B. costOfGoods, travelCosts, premisesRunningCosts, adminCosts, professionalFees, otherExpenses …) | 1 Woche | Steuerberater, Entwickler | M |

### A2. Steuerregeln → `TaxProfile` UK

| Regel | Wert | Sicherheit |
|---|---|---|
| Steuerjahr | 6. April – 5. April; Quartale 6.4–5.7, 6.7–5.10, 6.10–5.1, 6.1–5.4 (Option Kalenderquartale) | H |
| Trading Allowance | £1.000 Bruttoeinnahmen steuerfrei (statt tatsächlicher Ausgaben wählbar) | H |
| Cash Basis | Seit 2024/25 Standard (Zuflussprinzip), Accruals per Option | H |
| Simplified Expenses | Kilometergeld Auto 45p/Meile bis 10.000, danach 25p; Motorrad 24p; Home-Office-Pauschale £10/£18/£26 je Monat (25–50 / 51–100 / 101+ Std.) | H/M |
| VAT | Registrierungsgrenze £90.000 (seit 1.4.2024), Satz 20/5/0 %; VAT-Rechnung: Nummer, Datum, Lieferdatum, VAT-Nr., Name/Adresse, Beschreibung, Netto je Satz, VAT gesamt in GBP; vereinfachte Rechnung bis £250. **VAT-Meldung über MTD for VAT** wäre eigene API (später) | H |
| NIC | Class 2 seit 6.4.2024 nicht mehr zu zahlen (freiwillig möglich), **Class 4: 6 % zwischen £12.570 und £50.270, 2 % darüber** – Werte für 2027/28 bei Budget prüfen | M |
| Einkommensteuer (Rücklagenschätzung) | Personal Allowance £12.570, 20/40/45 % (Schottland abweichend!) | H (Schottland = Profilschalter) |
| Vorauszahlungen | Payments on account 31. Jan. und 31. Juli; Restzahlung 31. Jan. | H |
| Aufbewahrung | mind. 5 Jahre nach dem 31.-Januar-Abgabetermin | H |

### A3. Recht

| Punkt | Befund | Sicherheit |
|---|---|---|
| UK GDPR | Gilt für uns, sobald wir UK-Personen gezielt ansprechen | H |
| ICO-Gebühr | Tier 1: £52 (£47 per Lastschrift), seit 17.2.2025. Ob ein Unternehmen **ohne UK-Niederlassung** zahlen muss: ICO-Fee-Pflicht knüpft an UK-Niederlassung – vermutlich nein, aber prüfen (P-UK-04) | H (Betrag) / N (Pflicht) |
| Art. 27 UK GDPR – UK-Vertreter | EU-Sitz befreit nicht. Ausnahme nur bei „gelegentlicher“ Verarbeitung ohne umfangreiche sensible Daten. Bei Offline-App ohne Server verarbeiten **wir** kaum Daten; mit Token-Dienst + Abo-Verwaltung schon. Empfehlung: Vertreterdienst (ca. £300–1.000/Jahr) einkalkulieren, Pflicht rechtlich klären | M |
| DMCC Act – Abo-Regeln | Gilt laut Entwurf für Abos ab **1.1.2027**: Vorab-Info, Erinnerungen vor Verlängerung/Ende Probezeit, einfache Kündigung, 14-Tage-„cooling-off“ bei Verlängerung >1 Jahr. Bei Store-Abos übernehmen Apple/Google Teile; Hinweise in App/Paywall prüfen | M |
| Verbraucherrecht | Bei B2B-Nutzung (Selbstständige) teils nicht anwendbar; Abo wird aber oft als Verbraucher abgeschlossen → wie Verbraucher behandeln | M |
| Store | Steuer-/Finanz-App: Google „Financial features“-Erklärung, Apple Datenschutzlabels; UK-Preis in GBP inkl. 20 % VAT (Stores führen ab) | M |
| Datenschutz-Doku | HMRC-Datenfluss + Token-Dienst später in LASTENHEFT 5.19, PRIVACY.md, STORE_LISTING.md (im selben Commit) | H (Hausregel) |

### A4. Lokalisierung
en-GB-Strings (Flutter `intl`/ARB, erstmals Mehrsprachigkeit → 1–2 Wochen Umbau), GBP mit `£1,234.56`, Datum `26/10/2026`, Begriffe („receipt“, „invoice“, „self-employed“), englischer Store-Text und Screenshots, englisches Handbuch. Aufwand gesamt **3–4 Wochen**. UX: Daumenbedienung bleibt; längere englische Texte prüfen.

### A5. Wiederverwendung Irland / USA
- **Irland**: Euro (vorhanden), USt-Grenzen **€42.500 Dienstleistung / €85.000 Waren** seit 1.1.2025, 2026 unverändert (M); Sätze 23/13,5/9/4,8/0 %. Steuererklärung über **ROS**; ROS hat keine offene Mobil-API wie HMRC → Export statt Direktübermittlung. E-Invoicing B2B ab ca. 2028 schrittweise geplant (N). Wiederverwendbar: en-Strings, Kategorien, EU-VIES, EN 16931.
- **USA**: wiederverwendbar sind Englisch, Profil-Architektur, Quartalsdenke (Estimated Tax 4×/Jahr), Schedule-C-Kategorien ähnlich SA103. Nicht: keine staatliche API für Einzelpersonen (IRS-Filing nur über MeF-zugelassene Anbieter), Sales Tax je Bundesstaat. Empfehlung: USA nur als „Ausgaben-/Belegbuch + Schedule-C-Export“.

---

## B) Lässt sich das auf AT und DE ausweiten?

| | Österreich – FinanzOnline Webservices | Deutschland – ELSTER/ERiC |
|---|---|---|
| Heute in der App | U30-XML-Export (vorhanden) | keine UStVA/ELSTER-Übermittlung gefunden |
| Technik | SOAP: Session-Webservice (Login mit Teilnehmer-ID, Webservice-Benutzer-ID, PIN, **Hersteller-UID**), dann File-Upload/USt-Webservice mit U30-XML (H, BMF-PDFs) | ERiC = native C-Bibliothek, Herstellerkennung nötig, kostenlos nach Registrierung beim BayLfSt (H). Offizielle ERiC-Builds für Windows/Linux/macOS; **Android/iOS nicht offiziell** (M) |
| Mobil machbar? | **Ja**, reines HTTPS/SOAP aus Dart, kein Server nötig | **Schwierig**: ERiC auf dem Handy nicht unterstützt → bräuchte eigenen Server mit ERiC (Datenfluss!) oder Drittanbieter |
| Nutzen | Hoch: UVA mit einem Tipp statt Datei hochladen | Hoch, aber Lösung bricht Offline-/Kein-Server-Prinzip |
| Aufwand | 2–3 Wochen | 6–10 Wochen + Serverbetrieb, Zertifikatshandling |
| Risiken | Nutzerin muss einmalig Webservice-Benutzer in FinanzOnline anlegen (3–5 Schritte; Anleitung nötig); BMF gibt keinen Technik-Support; PIN-Speicherung im Keystore | Sicherheit/Haftung beim Server, Datenschutz, ERiC-Updates jährlich |
| Empfehlung | **Nach UK umsetzen** (Q3 2027), U30 zuerst, E1a später | **Zurückstellen**; vorher klären ob ERiC-Lizenz Serverbetrieb / Mobilnutzung erlaubt (P-DE-ERIC) |

Reihenfolge: 1. UK MTD (Pflichtmarkt, Zeitdruck) → 2. AT U30-Direktübermittlung → 3. DE nur nach Klärung ERiC-Mobil.

---

## C) Fahrplan bis UK-Start vor 6.4.2027

| Phase | Zeitraum | Inhalt |
|---|---|---|
| 0 Entscheidung | bis 6.11.2026 | Auftraggeber: Token-Dienst ja/nein, Budget Art.-27-Vertreter |
| 1 Grundlagen | 9.11.–4.12.2026 | Developer-Hub, Sandbox, Lokalisierung en-GB, `TaxProfile` UK (Steuerjahr, Kategorien SA103, GBP) |
| 2 MTD-Anbindung | 7.12.2026–29.1.2027 | OAuth + Token-Dienst, Fraud-Header, Business Details/Obligations/Quartalsupdates/Calculation, Sandbox-Testszenarien |
| 3 Zulassung | 1.2.–15.3.2027 | Produktionsantrag, HMRC-Prüfung, Software-Listing; parallel Recht: Privacy en-GB, DMCC-Paywall, Store-Listing |
| 4 Beta & Start | 15.3.–31.3.2027 | Test mit 5–10 UK-Selbstständigen auf echten Geräten, Store-Freigabe; Start vor 6.4.2027 |
| 5 Nachzug | Apr.–Dez. 2027 | Final Declaration End-to-End (erste fällig 31.1.2028 für 2026/27-Pflichtige), MTD VAT, AT FinanzOnline-Direkt, Irland |

Risiko: Die HMRC-Zulassung ist der kritische Pfad. Puffer: Start notfalls mit „Quartalsupdates“ und Final Declaration erst im Herbst 2027.

### Vorgeschlagene Prüfpunkte für SPECIFICATION Abschnitt 14
- **P-UK-01** HMRC Production-Credentials erteilt, Software in HMRC-Liste (Amt)
- **P-UK-02** Fraud-Header mit `MOBILE_APP_DIRECT` von HMRC als gültig bestätigt (Amt/Test-API)
- **P-UK-03** UK-Steuerberater bestätigt SA103-Zuordnung, Class-4-NIC/Einkommensteuer-Schätzung, Simplified Expenses
- **P-UK-04** UK-Datenschutzanwalt: ICO-Gebühr nötig? Art.-27-Vertreter nötig?
- **P-UK-05** Anwalt: Paywall/Abo-Texte DMCC-konform (Stand 1.1.2027)
- **P-UK-06** HMRC-Nutzungsbedingungen erlauben Token-Tausch-Dienst ohne Datenzugriff; Client-Secret-Handling OK
- **P-UK-07** Echte Geräte (Android/iOS): OAuth-Login im System-Browser, Rücksprung, Daumenbedienung en-GB
- **P-UK-08** Beta mit echten UK-Selbstständigen: Quartalsupdate in Produktion erfolgreich
- **P-AT-FON-01** BMF: Hersteller-UID als EU-Firma, U30-Upload per Webservice aus Mobil-App; Testupload
- **P-DE-ERIC-01** BayLfSt: ERiC-Nutzung mobil/serverseitig erlaubt?
- **P-IE-01** Revenue: aktuelle USt-Grenzen und Rechnungsangaben Irland

---

## Quellen
- HMRC API-Dokumentation MTD ITSA: https://developer.service.hmrc.gov.uk/api-documentation/docs/api?categoryFilters=INCOME_TAX_MTD
- HMRC End-to-End-Guide / Integration: https://developer.service.hmrc.gov.uk/guides/income-tax-mtd-end-to-end-service-guide/documentation/how-to-integrate.html
- Fraud Prevention: https://developer.service.hmrc.gov.uk/guides/fraud-prevention/
- Self Assessment Assist API: https://developer.service.hmrc.gov.uk/api-documentation/docs/api/service/self-assessment-assist/1.0
- Erfahrungsberichte: https://www.freecodecamp.org/news/how-to-connect-to-hmrc-making-tax-digital-api/ · https://taptax.co.uk/blog/5-things-that-surprised-me-building-on-hmrcs-making-tax-digital-api · https://dev.to/virendravyas/what-hmrcs-fraud-prevention-headers-actually-require-that-the-docs-dont-tell-you-1kn9
- MTD Überblick: https://en.wikipedia.org/wiki/Making_Tax_Digital
- DMCC Abo-Regeln: https://www.wiggin.co.uk/insight/digital-markets-competition-and-consumer-act-tracker/ · https://www.taylorwessing.com/en/insights-and-events/insights/2026/04/subscription-contracts · https://www.osborneclarke.com/insights/uk-digital-markets-competition-and-consumers-act-subscription-contracts-regime-take-shape
- ICO-Gebühr: https://www.lewissilkin.com/insights/2025/02/06/fee-payable-to-the-ico-to-increase-in-february-102jzb9 · https://www.barcouncilethics.co.uk/wp-content/uploads/2019/11/Data-Protection-Fees-payable-to-the-ICO-July-2026.pdf
- Irland USt-Grenzen: https://www.xero.com/ie/guides/vat-threshold-ireland/ · https://www.matheson.com/insights/irish-budget-2025-key-announcements/
- ELSTER/ERiC: https://www.elster.de/eportal/infoseite/entwickler · https://www.elster.de/eportal/infoseite/apps
- FinanzOnline: https://www.bmf.gv.at/dam/jcr:570753b2-d511-4194-a03e-33f0ac7371ec/BMF_Session_Webservice_2.pdf · https://www.bmf.gv.at/dam/jcr:7f3258d4-5d58-455d-9bfe-a352a4effd73/BMF_File_Upload_Webservice_2.pdf · https://www.bmf.gv.at/dam/jcr:5e4a2cd3-0ff1-472a-9fe0-af10cdcf5277/BMF_USt-Webservice.pdf
- Steuerwerte UK (Allowance, Cash Basis, Simplified Expenses, NIC, VAT £90k) aus GOV.UK-Kenntnisstand, in dieser Runde nicht einzeln neu recherchiert → Sicherheit M, über P-UK-03 bestätigen.
