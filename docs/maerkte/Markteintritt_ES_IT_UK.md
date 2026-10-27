# Markteintritt Spanien, Italien, Vereinigtes Königreich – Entscheidungsvorlage „JeNi bucht“

Stand 2026-10-26 · Prüfinstanzen: Steuerberater, Rechtsanwalt, Softwareentwickler
Sicherheit: **hoch** = mehrere übereinstimmende Quellen oder amtlich · **mittel** = eine Quelle oder nicht amtlich · **niedrig** = Fachwissen, nicht online geprüft.
Ersetzt keine Beratung durch *asesor fiscal*, *commercialista* oder *accountant*. Die meisten Quellen sind Fachportale, nicht Amtsblätter. Vor einer Entscheidung die markierten Punkte am BOE, bei der Agenzia delle Entrate und auf gov.uk prüfen.

## Kurzfassung

1. **Spanien:** 2 Mio. *autónomos* (natürliche Personen). Es gibt **keine Kleinunternehmerbefreiung**. Ab 2027/2028 braucht jede Rechnungssoftware **VeriFactu** (Datensatzkette, QR-Code, Online-Meldung an die AEAT), dazu ab ca. Oktober 2028 B2B-E-Rechnung. → **Server- oder API-Anbindung nötig.**
2. **Italien:** Rund die Hälfte aller Neugründungen wählt den *regime forfettario* (242 529 im Jahr 2025). Seit 2024 muss **jede** Rechnung als **FatturaPA-XML über das SdI** laufen. → **Ohne Intermediär-API nicht verkaufsfähig.** FatturaPA ist nicht EN 16931.
3. **UK:** Es gibt keine E-Rechnungspflicht, aber **Making Tax Digital** für Einkommensteuer (seit 6. 4. 2026 ab 50 000 £, 2027 ab 30 000 £, 2028 ab 20 000 £). Pflicht sind quartalsweise **API-Meldungen an HMRC** mit HMRC-Produktionszugang und Betrugsschutz-Headern. Unterhalb der Grenze genügt eine einfache App. Die Konkurrenz ist stark und teils gratis.
4. **Rangfolge:** (1) AT/DE vertiefen. (2) UK als „MTD-Einstieg“ oder UK-Lite, falls Expansion. (3) Italien. (4) Frankreich. (5) Spanien. (6) USA nicht.

---

## A. SPANIEN

### 1. Zielgruppe und Buchführungspflichten
- **2 001 743 autónomos personas físicas** (Jänner 2026), RETA gesamt rund 3,47 Mio. Quellen: [MITES AUT 01/2026](https://www.mites.gob.es/estadisticas/AUT/AUT_01_2026.pdf), [Europa Press über Bolsamanía](https://www.bolsamania.com/noticias/mercados/economiaparo--uatae-destaca-afiliacion-practicamente-intacta-de-los-autonomos-en-julio-pese-a-perder-103-afiliados--23181463.html). Sicherheit **hoch**.
- **Bücher** bei *estimación directa simplificada*: libro registro de ingresos, gastos, bienes de inversión, dazu IVA-Register (*facturas emitidas/recibidas*). Quartalsweise *modelo 303* (IVA) und *130* (IRPF-Vorauszahlung), jährlich *390* und *Renta*. Sicherheit **mittel** (Fachwissen, deckt sich mit Herstellerangaben).
- Die App kann Einnahmen, Ausgaben und Beleg. **Es fehlen:** spanische Register-Formate, Modelo-303/130-Rechner, Retención IRPF (15 %/7 % auf Rechnungen von Freiberuflern an Unternehmen).

### 2. IVA und Kleinunternehmer
- **Keine allgemeine Umsatzgrenze für eine Befreiung.** Spanien hat die EU-KMU-Regelung (RL 2020/285, bis 85 000 €, seit 1. 1. 2025) **nicht umgesetzt**. Die Kommission hat Spanien deshalb vor den EuGH gebracht (2026). Quellen: [Maldita 16. 3. 2026](https://maldita.es/desinfo/20260316/bruselas-lleva-a-espana-a-los-tribunales-por-ser-el-unico-pais-de-la-ue-que-no-exime-de-iva-a-los-autonomos/), [fiscal-impuestos.com](https://www.fiscal-impuestos.com/comision-europea-tjue-espana-no-transponer-normas-iva), [El Español 3. 4. 2026](https://www.elespanol.com/mujer/estilo-vida/20260403/bruselas-cambia-normas-espana-cumplir-eximir-pagar-iva-pequenos-autonomos-tz/1003744173289_0.html). Sicherheit **mittel bis hoch**.
- **Sonderregeln:** *Recargo de equivalencia* für Einzelhändler (der Lieferant schlägt einen Zuschlag auf, der Händler meldet keine IVA), *módulos/estimación objetiva* für bestimmte Branchen. Beide brauchen eigene Steuerlogik. Sicherheit **niedrig** (Fachwissen).
- **Steuersätze:** 21/10/4 %. In Kanarien, Ceuta und Melilla gilt keine IVA (IGIC/IPSI). Das erfordert ein eigenes `TaxProfile`, sonst Fehlbuchungen. Sicherheit **niedrig**.
- **Rechnungspflichtangaben** (RD 1619/2012): Nummer und Serie, Datum, NIF und Adresse beider Parteien, Beschreibung, Steuersatz, Steuerbetrag, gegebenenfalls Retención IRPF. Ab VeriFactu zusätzlich ein **QR-Code** und der Text „VERI*FACTU“. Sicherheit **mittel**.

### 3. VeriFactu und E-Rechnung
- **VeriFactu** (RD 1007/2023, Reglamento de Sistemas Informáticos de Facturación): Jede Rechnungssoftware muss unveränderliche, verkettete Datensätze (Hash) erzeugen. Im Modus „VERI*FACTU“ sendet sie jeden Datensatz sofort an die AEAT, sonst gelten strengere Signatur- und Protokollpflichten. Der **Hersteller** muss eine *declaración responsable* abgeben und ist **seit 29. 7. 2025 verpflichtet**.
- **Termine:** Laut RDL 15/2025 gilt der **1. 7. 2027 für autónomos** und der 1. 1. 2027 für Gesellschaften. Am **5. 10. 2026** hat das Finanzministerium angekündigt, alles auf **Oktober 2028** zu verschieben. Das ist **noch nicht im BOE**. Quellen: [guiafiscal](https://guiafiscal.es/autonomos/verifactu-2026-guia/), [emprendedores.es](https://emprendedores.es/gestion/aplazamiento-verifactu-2028/), [spun.es](https://www.spun.es/verifactu/aplazamiento-2028), [TeamSystem](https://teamsystem.es/magazine/verifactu-se-retrasa-2027/). Sicherheit: RDL-Termine **hoch**, Verschiebung 2028 **mittel** (→ Prüfpunkt §14).
- **B2B-E-Rechnung (Ley Crea y Crece):** Die Verordnung ist **RD 238/2026**. Die **Orden HAC/1028/2026** (BOE 5. 10. 2026) startet die Fristen: 12 Monate für Unternehmen über 8 Mio. € (Okt. 2027), **24 Monate für alle übrigen, also auch autónomos (Okt. 2028)**. Format: UBL, CII, Facturae oder EDIFACT. **EN 16931 (UBL/CII) ist zulässig**, dazu kommt der Austausch über Plattformen oder die öffentliche Lösung der AEAT. Quellen: [Sage](https://www.sage.com/es-es/certificacion-software/ley-crea-y-crece/), [Wolters Kluwer](https://www.wolterskluwer.com/es-es/expert-insights/factura-electronica-obligatoria-que-es-plazos), [B2Brouter](https://www.b2brouter.net/es/ley-crea-crece-factura-electronica/). Sicherheit **mittel**.
- **Bedeutung für die Offline-App:**
  - Den Hash-Datensatz kann die App offline lokal führen. Für den VeriFactu-Modus braucht sie aber eine Online-Übermittlung mit **qualifiziertem Zertifikat der Nutzerin oder einer Vertretung** (Webservice AEAT, SOAP/XML). Eine Warteschlange, die bei Netz nachsendet, ist machbar.
  - Dazu kommen die Herstellererklärung (rechtliche Haftung, Strafen bis 150 000 € je Jahr und Produkt laut Art. 201 bis LGT; Sicherheit niedrig) und ab 2028 eine B2B-Plattform.
  - Der EN-16931-Generator ist für die B2B-E-Rechnung wiederverwendbar, für VeriFactu nicht, weil VeriFactu ein eigenes XML-Schema verwendet.
  - **Aufwand:** VeriFactu 6–8 Wochen, B2B über einen API-Partner (z. B. B2Brouter) 3–4 Wochen.

### 4. Weiteres
Sprache Spanisch, regional Katalanisch oder Baskisch nicht zwingend. **Baskenland und Navarra** haben mit **TicketBAI** ein eigenes System, das VeriFactu dort ersetzt (Sicherheit **mittel**). Das wäre ein zusätzliches Projekt oder ein Ausschluss dieser Regionen. Für Abos gelten EU-Verbraucherrecht und DSGVO wie in AT/DE, die AEPD ist Aufsicht. Stores: keine Besonderheiten.

### 5. Konkurrenz (Preise laut Vergleichsportalen, Sicherheit mittel)
| Anbieter | Preis ab |
|---|---|
| [Holded](https://www.holded.com/es/precios) | ca. 29 €/Monat (monatlich) |
| [Quipu](https://getquipu.com/precios) | 14–17 €/Monat |
| [Billin](https://www.billin.net/precios/) | 6,60–8 €/Monat |
| [Contasimple](https://www.contasimple.com/precios) | gratis (12 Dokumente/Jahr), sonst kostenpflichtig |
| AEAT-Gratis-App „VeriFactu“ | 0 € |

Quelle: [guiafiscal Vergleich 2026](https://guiafiscal.es/comparativas/mejor-programa-facturacion-autonomos/). Alle sind cloudbasiert und bereits VeriFactu-fähig.

### 6. Aufwand, Risiken, Empfehlung
- **Aufwand: 16–22 Wochen.** Davon `TaxProfile` ES mit Retención, Recargo und Kanarien-Ausschluss 4 Wochen, VeriFactu 6–8, B2B 3–4, Modelo-Rechner und Übersetzung 3–4, dazu Recht und Herstellererklärung.
- **Risiken:**
  - Herstellerhaftung
  - Termine ändern sich laufend
  - TicketBAI
  - Billigkonkurrenz und Gratis-App der AEAT
  - Keine Befreiung, also volle IVA-Logik schon für Kleinstunternehmer
- **Empfehlung: nicht jetzt.** Frühestens nach dem endgültigen BOE-Termin (2028) neu bewerten.

---

## B. ITALIEN

### 1. Zielgruppe und Buchführungspflichten
- **242 529 neue Partite IVA im forfettario im Jahr 2025.** Das sind 48,5 % aller 500 341 Neueröffnungen. Quelle: [MEF Osservatorio Sintesi 2025](https://www1.finanze.gov.it/finanze/osiva/public/contenuti/Sintesi_annuale_dati_2025.pdf), [informazionefiscale](https://www.informazionefiscale.it/partite-iva-aperture-adesioni-regime-forfettario-osservatorio-mef). Sicherheit **hoch**. Der Gesamtbestand an forfettari liegt laut Fachpresse bei etwa 1,8–2 Mio. (Sicherheit **niedrig**, nicht online bestätigt).
- **Pflichten im forfettario:** Es gibt **keine Buchführungs- und keine IVA-Registerpflicht**. Pflicht sind nur die Aufbewahrung der Rechnungen, die Steuererklärung (*Modello Redditi PF, quadro LM*) und die INPS-Beiträge. Die Steuer beträgt 15 % (5 % in den ersten 5 Jahren) auf den Umsatz × Rentabilitätskoeffizient (40–86 %). Sicherheit **mittel**.
- Eine Einnahmen-Ausgaben-App ist für forfettari **wenig nötig**, weil Ausgaben steuerlich keine Rolle spielen. Der Wert liegt in der **Rechnungsstellung über das SdI** und im Grenzwert- und Steuerrechner.

### 2. IVA und Kleinunternehmer
- **Grenze 85 000 €** Umsatz (Zufluss), unverändert 2026. Über 100 000 € fällt man **sofort** aus der Regelung, zwischen 85 000 und 100 000 € ab dem Folgejahr. Quellen: [studioripa](https://www.studioripa.it/in-evidenza/regime-forfettario-aggiornamento-2026/), [centrofiscale](https://centrofiscale.com/regime-forfettario-2026-limiti-e-controlli-automatici/), [FreeInvoice](https://www.freeinvoice.it/blog/guida-regime-forfettario-2026/). Sicherheit **hoch**.
- Forfettari stellen **keine IVA** in Rechnung. Pflichtvermerk: „Operazione effettuata ai sensi dell'art. 1, commi 54–89, L. 190/2014“. Über 77,47 € ist eine **marca da bollo von 2 €** fällig, die virtuell in der FatturaPA vermerkt und quartalsweise bezahlt wird. Sicherheit **mittel**.
- **Rechnungsangaben** (art. 21 DPR 633/72): Nummer, Datum, Partita IVA und Codice Fiscale, Daten des Kunden inklusive **Codice Destinatario oder PEC**, Natur-Code (z. B. N2.2 für forfettari). Sicherheit **mittel**.

### 3. SdI-E-Rechnung
- **Seit 1. 1. 2024** gilt die **Pflicht für alle forfettari**, B2B **und B2C**. Ausnahme: Gesundheitsleistungen an Privatpersonen, die über das Sistema TS laufen. Quellen: [pyva](https://pyva.it/blog/fatturazione-elettronica-regime-forfettario), [fatturah](https://www.fatturah.it/blog/fattura-elettronica-forfettari), [softwaresemplice](https://www.softwaresemplice.it/blog/regime-forfettario-fatturazione-elettronica/1212). Sicherheit **hoch**.
- **Format FatturaPA (XML, eigenes Schema)**. Das ist **nicht** der EN-16931-Generator. Wiederverwendbar sind das Datenmodell und die Validierungslogik, das XML-Mapping muss neu geschrieben werden (ca. 2–3 Wochen). Sicherheit **hoch**.
- **Übermittlung:**
  - Über PEC, das Portal „Fatture e Corrispettivi“ oder einen akkreditierten Webservice/SFTP. Für Webservice und SFTP braucht der Anbieter eine Akkreditierung beim SdI und einen dauerhaft erreichbaren Server.
  - Praktisch: **API eines Intermediärs** (z. B. Aruba, Openapi, A-Cube, FatturaPA-Provider), der Versand, Empfang, Rückmeldungen (*ricevute*) und Konservierung (*conservazione sostitutiva*, 10 Jahre) übernimmt. Die Nutzerin erteilt dafür eine Vollmacht.
  - Quellen: [informazionefiscale](https://www.informazionefiscale.it/come-inviare-fattura-elettronica-al-sdi-modalita-trasmissione), [ecnews](https://www.ecnews.it/fiscale/fisco-e-patrimonio/iva/modalita-trasmissione-recapito-della-fattura-elettronica/). Sicherheit **mittel**. Die Preise pro Rechnung sind nicht öffentlich, geschätzt wenige Cent bis 0,10 € (Sicherheit niedrig).
- **Offline-App:** Rechnungen offline erstellen und beim nächsten Netz senden ist erlaubt. Die Rechnung gilt erst mit SdI-Zustellung als ausgestellt, die Frist dafür beträgt 12 Tage. Der Rest der App bleibt offline.
- **Aufwand:** FatturaPA 2–3 Wochen, Intermediär-API mit Statusverwaltung und Eingangsrechnungen 4–5 Wochen.

### 4. Weiteres
Sprache Italienisch. Verbraucherrecht: EU-Recht, Codice del Consumo. Datenschutz: DSGVO, Aufsicht Garante. Bei der Intermediär-Anbindung wird ein **Auftragsverarbeiter** benötigt, der Eintrag in die Datenflusstabelle (L-19.5), PRIVACY.md und STORE_LISTING.md ist Pflicht. Stores: keine Besonderheiten.

### 5. Konkurrenz (Sicherheit mittel, Preise je Jahr ohne IVA)
| Anbieter | Preis ab |
|---|---|
| [Fatture in Cloud](https://www.fattureincloud.it/prezzi/) (TeamSystem) | 48 € im ersten Jahr, danach ca. 96 €/Jahr |
| [Aruba Fatturazione Elettronica](https://www.aruba.it/fatturazione-elettronica.aspx) | ca. 25–30 €/Jahr |
| [Fiscozen](https://www.fiscozen.it/prezzi/) | ca. 499 €/Jahr inklusive Steuerberater-Service |
| [FlexTax](https://www.flextax.it/) | ca. 366 €/Jahr inklusive Service (1 098 € für 3 Jahre) |
| Portal der Agenzia delle Entrate | gratis |

Quellen: [centrofiscale Vergleich 2026](https://centrofiscale.com/confronto-software-fatturazione-economici-2026/), [Fiscozen-Vergleich](https://www.fiscozen.it/guide/migliori-software-fatturazione-elettronica-2026/), [centrofiscale Fiscozen/FlexTax](https://centrofiscale.com/fiscozen-flextax-caf-confronto-2026/).
**Wichtig:** Reine Rechnungssoftware kostet hier 2–8 € pro Monat. Unsere 12,90 € sind **nicht marktfähig**, außer im Bündel mit Steuerberatungsleistung wie Fiscozen.

### 6. Aufwand, Risiken, Empfehlung
- **Aufwand: 10–14 Wochen.** Davon `TaxProfile` IT mit forfettario-Rechner, Koeffizienten und INPS 3 Wochen, FatturaPA 2–3, Intermediär 4–5, Übersetzung und Recht 2.
- **Risiken:**
  - Sehr niedriges Preisniveau
  - Laufende Kosten pro Rechnung
  - Konservierungspflicht
  - Ausgaben-Erfassung, der Kern unserer App, ist für forfettari fast wertlos
- **Empfehlung:** Technisch klar lösbar, wirtschaftlich schwach. Nur mit einem eigenen günstigen IT-Tarif (ca. 4–6 €/Monat) erwägen, **nach** Frankreich (gleiche Architektur: API-Partner).

---

## C. VEREINIGTES KÖNIGREICH

### 1. Zielgruppe und Buchführungspflichten
- Rund 4,2 Mio. Selbstständige, davon etwa 3 Mio. *sole traders* (Sicherheit **niedrig**, ONS-Größenordnung aus Fachwissen).
- **MTD-Kohorten:** 2026 rund 780 000–864 000 Personen (über 50 000 £), **2027 zusätzlich ca. 970 000** (30 000–50 000 £), 2028 weitere (20 000–30 000 £). Quellen: [Tax Adviser Magazine](https://www.taxadvisermagazine.com/article/new-figures-show-scale-mtd-challenge), [The Register 10. 4. 2026](https://www.theregister.com/2026/04/10/mtd_hmrc/), [Which?](https://www.which.co.uk/news/article/making-tax-digital-4-questions-answered-aUYig4e2qboX). Sicherheit **mittel**.
- **Bücher:** Unter MTD gelten digitale Aufzeichnungen je Geschäftsvorfall (Datum, Betrag, Kategorie), *cash basis* ist Standard. Dazu 4 Quartalsmeldungen und eine Jahreserklärung. In der ersten Pflichtphase gibt es keine Strafpunkte für verspätete Quartalsmeldungen. Quellen: [LITRG](https://www.litrg.org.uk/tax-nic/making-tax-digital-income-tax/when-does-making-tax-digital-start-me), [House of Commons Library](https://commonslibrary.parliament.uk/research-briefings/cbp-10573/). Sicherheit **hoch**.

### 2. VAT und Kleinunternehmer
- **Registrierungsgrenze 90 000 £** (seit 1. 4. 2024), darunter keine VAT. Quelle: [gov.uk VAT registration](https://www.gov.uk/vat-registration/when-to-register). Sicherheit **hoch**. Die Mehrheit der Zielgruppe ist **nicht VAT-pflichtig**.
- Sätze 20/5/0 %, Flat Rate Scheme als Option. Rechnungsangaben nur für VAT-Registrierte (VAT-Nummer, Satz, Steuerbetrag in GBP). Sicherheit **mittel**.
- **Neue Währung GBP**, `Money` bleibt in Pence (unkritisch). Neues `TaxProfile` UK.

### 3. MTD und E-Rechnung
- Es gibt **keine B2B-E-Rechnungspflicht vor 2029** (Sicherheit **niedrig**, Konsultation läuft). Der EN-16931-Generator wird nicht gebraucht.
- **MTD for Income Tax:** Die App muss über die **HMRC-API** (OAuth 2.0 je Nutzerin über Government Gateway) Quartalssummen und die Jahreserklärung senden. Damit sie Produktionszugang bekommt:
  - Registrierung im Developer Hub
  - Erfüllung der Nutzungsbedingungen
  - **Fraud-Prevention-Header** (Pflicht, inklusive Geräte-IDs)
  - Transaction Monitoring
  - Benannte verantwortliche Person
  - Danach Aufnahme in die Liste „compatible software“ von HMRC
  - Bearbeitungsdauer ca. 4 Wochen

  Quellen: [HMRC Terms of use](https://www.tax.service.gov.uk/api-documentation/docs/terms-of-use), [AccountingWEB Entwickler](https://www.accountingweb.co.uk/node/230314), [ICAEW Software](https://icaew.com/technical/tax/making-tax-digital/software). Sicherheit **mittel bis hoch**.
- **Offline-App:** Funktioniert ohne eigenen Server. Die App spricht direkt mit HMRC (Client-Secret-Schutz beachten, eventuell kleiner Token-Proxy). Erfassen bleibt offline, gesendet wird beim Melden. **Aufwand 6–8 Wochen** inklusive Anerkennung.
- **MTD for VAT** (alle VAT-Registrierten): ähnliche API, zusätzlich 2 Wochen, erst später nötig.

### 4. Weiteres
- Sprache Englisch, das ist am billigsten.
- **UK GDPR / Data Protection Act 2018**, Aufsicht ICO. Ein UK-Vertreter nach Art. 27 UK GDPR ist nötig, wenn kein UK-Sitz besteht (Sicherheit **mittel**). Die **ICO-Datenschutzgebühr** (ca. 52 £/Jahr) betrifft eher den Controller mit UK-Sitz, das muss geprüft werden.
- Die Übermittlung an HMRC ist eine **neue Datenübertragung**, Eintrag in L-19.5, PRIVACY.md und STORE_LISTING.md erforderlich.
- Verbraucherrecht: **DMCC Act 2024** mit neuen Abo-Regeln (Erinnerungen, einfache Kündigung). Inkrafttreten frühestens 2026/27, Sicherheit **niedrig**.
- Stores: Preise in GBP.

### 5. Konkurrenz (Sicherheit mittel, ohne VAT)
| Anbieter | Preis ab |
|---|---|
| [FreeAgent](https://www.freeagent.com/pricing/) | 19 £/Monat, **gratis** bei NatWest/RBS/Mettle |
| [QuickBooks Sole Trader](https://quickbooks.intuit.com/uk/pricing/) | ca. 10 £/Monat |
| [Xero Ignite](https://www.xero.com/uk/pricing-plans/) | ca. 16–18 £/Monat |
| [Coconut](https://www.getcoconut.com/pricing) | ca. 130 £/Jahr, gratis mit Zempler-Konto |
| [ANNA](https://anna.money/pricing) | MTD-Basis gratis |
| [Sage](https://www.sage.com/en-gb/sage-business-cloud/accounting/pricing/) | ca. 15 £/Monat |
| HMRC-Liste | [compatible software](https://www.gov.uk/guidance/find-software-thats-compatible-with-making-tax-digital-for-income-tax) |

Quellen: [ByteStart](https://www.bytestart.co.uk/self-employed-accounts/business-accounting-software/), [ANNA-Vergleich](https://anna.money/blog/guides/best-making-tax-digital-software-for-sole-traders/), [FreeAgent-Vergleich](https://www.freeagent.com/features/competitors/).

### 6. Aufwand, Risiken, Empfehlung
- **Aufwand: 10–13 Wochen.** Davon `TaxProfile` UK mit Kategorien SA103 und Tax/NI-Schätzung 3 Wochen, MTD-ITSA-API inklusive Anerkennung 6–8, Recht und Übersetzung 1–2.
- **Risiken:**
  - Gratis-Angebote der Banken
  - Starke Marken
  - HMRC kann den Zugang entziehen
  - Rechtsstand nach dem Brexit separat zu prüfen
- **Vorteile:**
  - Kein E-Rechnungszwang
  - Englisch
  - Klarer, wachsender Pflichtmarkt (2027 fast 1 Mio. neue Pflichtige)
  - Belegfoto plus „Quartal mit einem Tipp senden“ passt zum Leitprinzip
- **Empfehlung:** Bester Auslandskandidat. Zielfenster **Start vor 6. 4. 2027** (Kohorte 30 000 £), Entwicklung ab Jänner 2027.

---

## D. Gesamtvergleich

| | FR | ES | IT | UK | US |
|---|---|---|---|---|---|
| Zielgruppe | 2,7 Mio. micro | 2,0 Mio. autónomos | ca. 2 Mio. forfettari (niedrig) | ca. 3 Mio. sole traders, 1–2 Mio. MTD-pflichtig | ca. 30 Mio. Schedule C |
| Kleinunternehmer-Befreiung | ja (37 500/85 000 €) | **nein** | ja (85 000 €) | ja (90 000 £) | keine VAT, Sales Tax je Bundesstaat |
| E-Rechnung / Meldepflicht | PA-Pflicht ab 9/2027 | VeriFactu 7/2027 (evtl. 10/2028), B2B 10/2028 | SdI seit 2024, alle Rechnungen | keine, aber MTD-API | keine |
| Server/API nötig | ja, PA-Partner | ja, AEAT plus Herstellerhaftung | ja, Intermediär | ja, HMRC-API (direkt) | nein |
| EN 16931 wiederverwendbar | ja (Factur-X) | teilweise (B2B) | nein (FatturaPA) | nicht nötig | nicht nötig |
| Preisniveau Konkurrenz | mittel | 7–29 €/Monat | **2–8 €/Monat** | 0–19 £/Monat | 0–30 $/Monat |
| Aufwand (Wochen) | 10–14 | **16–22** | 10–14 | 10–13 | 12–16 (Sales-Tax-Logik, Recht, Steuerjahr) |
| Risiko | mittel | **hoch** | mittel | mittel | hoch (Haftung, Bundesstaaten) |

**Rangfolge**

1. **AT/DE vertiefen.** Gleicher Code, keine neuen Pflichten, Prüfpunkte in §14 abarbeiten.
2. **UK:** Englisch, kein E-Rechnungszwang, die Pflicht schafft Nachfrage (Kohorte April 2027). Die direkte HMRC-API braucht keinen Vertragspartner. Nachteil sind die Gratis-Konkurrenz, deshalb ist eine Positionierung „einfachste MTD-App mit Belegfoto“ nötig.
3. **Frankreich:** großer Markt, Factur-X wiederverwendbar, aber ab 9/2027 PA-Partner nötig.
4. **Italien:** technisch ähnlich wie FR, aber Preisniveau und geringer Nutzen der Ausgaben-Erfassung.
5. **Spanien:** keine Befreiung, VeriFactu-Herstellerhaftung, TicketBAI, Termine unklar. Erst nach endgültigem BOE-Termin neu prüfen.
6. **USA:** nicht verfolgen. Keine VAT macht es einfacher, aber 50 Sales-Tax-Regime, Haftungsrecht und Marketingkosten passen nicht zum Produkt.

**Vorschlag für Abschnitt 14 (Prüfung in der realen Welt), noch nicht eingetragen:**
- UK: Rechtsanwalt zu UK-Vertreter, ICO-Gebühr und DMCC; Steuerberater zur MTD-Datenauswahl
- ES: BOE-Bestätigung der Verschiebung auf 2028
- IT: Angebot eines Intermediärs mit Preis pro Rechnung

Suche: 14 Websuchen, Stand 26. 10. 2026.
