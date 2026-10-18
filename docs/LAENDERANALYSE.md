# Länderanalyse für die nächste Ausbaustufe

**Stand:** 2026-10-18 · **Zweck:** Auswahl des nächsten Landes nach AT/DE
(Lastenheft L-30.8, offener Punkt O-41) · **Erstellt von:** Prüfinstanzen
Steuerberater, Rechtsanwalt und Softwareentwickler (intern, ohne externe
Bestätigung)

> **Wichtig:** Alle Zahlen und Termine sind Stand 2026-10-18 und aus Fachwissen
> sowie Sekundärquellen zusammengetragen; amtliche Seiten waren aus der
> Entwicklungsumgebung nur eingeschränkt erreichbar. Mit **(u)** markierte
> Angaben sind unsicher (Termine wurden in mehreren Ländern schon mehrfach
> verschoben). Alles, was für eine Umsetzung tragend ist, steht in der
> Spalte „vor Umsetzung prüfen“ und kommt erst dann als Prüfpunkt in
> Spezifikation Abschnitt 14.

## 1. Zwei Arten, ein Land zu unterstützen

| Stufe | Was die App können muss | Aufwand |
|---|---|---|
| **A · weiteres Steuerland** | Registrierung für ein Lager (z. B. Amazon FBA) neben der Heimat: Steuersätze, Voranmeldung mit Kennzahlen, Termine, Finanzamt-Vorschlag, UID-Format – alles im `TaxProfile` (Spezifikation 5.14). Rechnungen und Ertragsteuer bleiben in der Heimat (Entscheidungen 2026-10-18) | klein bis mittel |
| **B · neues Heimatland** | Zusätzlich Kleinunternehmerregel, Rechnungspflichtangaben, E-Rechnung/Echtzeitmeldung, Ertragsteuer-Hilfszeilen, Exporte für Kanzleien, Feiertage, Sprache der Oberfläche, Store-Texte, Verbraucher- und Datenschutzrecht des Landes | groß |

Die Zielgruppe heute (AT/DE, Amazon-Händlerinnen) braucht zuerst **Stufe A**;
neue Kundinnen bringt nur **Stufe B**.

## 2. Vergleich der Kandidaten

Selbstständige: Eurostat, Arbeitskräfteerhebung, Tabelle `lfsa_esgaed`
(Selbstständige ohne und mit Beschäftigten, 15–74 Jahre), Jahr 2024, gerundet
in Tausend. Die Werte sind aus Sekundärquellen übernommen **(u)**; vor einer
Geschäftsentscheidung direkt bei Eurostat abrufen.

| Land | Selbstständige ca. (Tsd., 2024) | Kleinunternehmergrenze (Inland) | EU-KU-Verfahren (Art 284 ff. MwStSystRL) | E-Rechnung / Echtzeitmeldung | Kassen- und Belegpflicht | Gewinnermittlung Einzelunternehmen | Sprache |
|---|---|---|---|---|---|---|---|
| **IT** | ca. 4.900 | Regime forfettario bis 85.000 € (ohne MwSt) | ja | **SDI-Pflicht für alle**, auch forfettari, seit 01.01.2024 (B2B, B2C) | Registratore telematico (corrispettivi) | Pauschal (forfettario) bzw. vereinfachte Buchführung | Italienisch |
| **FR** | ca. 3.300 | Franchise en base 37.500 € Dienstl. / 85.000 € Waren (Reform 2025 zurückgenommen **(u)**) | ja | Empfang ab 01.09.2026, Ausstellung für KMU/Kleinst ab 01.09.2027 über Plattformen (PA) + E-Reporting **(u)** | Kassensoftware-Zertifizierung (NF 525) bei Barverkauf | Micro-entreprise pauschal, sonst Einnahmen-Ausgaben | Französisch |
| **ES** | ca. 3.200 | **keine** allgemeine Befreiung (nur Sonderregelungen) | ja (seit 2025) **(u)** | Verifactu ab 2027 **(u)**, TicketBAI im Baskenland, SII für Große; B2B-E-Rechnung geplant | Rechnung/Ticket statt Kasse | Estimación directa simplificada bzw. objetiva | Spanisch (+ Regionalsprachen) |
| **PL** | ca. 2.900 | 200.000 PLN (2026: 240.000 PLN **(u)**) | ja | **KSeF** Pflicht ab 01.02.2026 (Große), 01.04.2026 (übrige), Kleinstfälle ab 01.01.2027 | Fiskalkassen (online) für B2C | Ryczałt / KPiR (Einnahmen-Ausgaben-Buch) | Polnisch |
| **NL** | ca. 1.600 | KOR 20.000 € | ja | keine Pflicht (B2B-Pläne ab ~2030 **(u)**) | keine Kassenpflicht | Gewinn nach Bilanzgrundsätzen, für Kleine vereinfacht **(u)** | Niederländisch (Englisch verbreitet) |
| **BE** | ca. 850 | 25.000 € | ja | **Peppol B2B-Pflicht seit 01.01.2026**, E-Reporting ab 2028 **(u)** | GKS-Kasse nur Gastronomie u. ä. | Einnahmen-Ausgaben möglich | Niederländisch/Französisch/Deutsch |
| **CZ** | ca. 950 | 2.000.000 CZK (seit 2025) | ja | keine; Kontrollmeldung (kontrolní hlášení) für Registrierte | EET abgeschafft (2023) | Pauschalausgaben (paušál) bzw. Steuerevidenz | Tschechisch |
| **PT** | ca. 800 | 15.000 € (Art. 53 CIVA, seit 2025) | ja | ATCUD, SAF-T-PT, **zertifizierte Rechnungssoftware**; E-Rechnung B2B ab 2027 **(u)** | zertifizierte Software statt Kasse | Regime simplificado | Portugiesisch |
| **HU** | ca. 500 | 18 Mio. HUF **(u)** | ja | **RTIR**: jede Rechnung in Echtzeit an NAV (Online Számla) | Online-Kasse | KATA/átalányadó | Ungarisch |
| **SK** | ca. 400 | 50.000 € (seit 2025) | ja | E-Rechnung B2B geplant ab 2027 **(u)** | eKasa online | Pauschalausgaben | Slowakisch |
| **SI** | ca. 120 | 60.000 € (seit 2025 **(u)**) | ja | E-Rechnung B2B ab 2028 **(u)** | Fiskalisierung Barverkauf | normirani s.p. (pauschal) | Slowenisch |
| *RO* | *nur Hinweis* | 395.000 RON (2026 **(u)**) | ja | e-Factura B2B/B2C Pflicht | Fiskalkasse online | – | Rumänisch |
| *CH* (kein EU) | ca. 600 | MWST-Pflicht ab 100.000 CHF | – | keine | keine | Einnahmen-Ausgaben für Kleine | Deutsch/Französisch/Italienisch |

Quellen (Auswahl): Eurostat `lfsa_esgaed`; Richtlinie 2006/112/EG idF RL (EU)
2020/285 (EU-KU-Verfahren ab 01.01.2025) und RL (EU) 2025/516 (ViDA);
Agenzia delle Entrate „Fatturazione elettronica“ und L. 190/2014
(forfettario); Art. 293 B CGI und Loi de finances 2024 Art. 91 (FR
E-Rechnung); RD 1007/2023 und RDL 15/2025 (Verifactu); Ustawa o VAT
Art. 113, KSeF-Gesetz 2025 (PL); Wet OB Art. 25 (KOR); Loi du 6 février 2024
(BE Peppol); § 6 ZDPH (CZ); Art. 53 CIVA (PT); Áfa tv. 2017 (HU Online
Számla); § 4 Zákon o DPH (SK). Termine mit **(u)** vor Umsetzung neu prüfen.

### Amazon FBA und Verbraucher-/Store-Recht

| Land | FBA-Lager / Pan-EU | Bedeutung für die Zielgruppe heute | Store-/Verbraucherrecht |
|---|---|---|---|
| IT | ja (Pan-EU) | hoch: Pan-EU lagert auch in IT | Codice del Consumo; Italienisch in Store und App Pflicht für Verbraucher |
| FR | ja (Pan-EU) | **hoch**: zweithäufigstes Lagerland nach DE | Loi Toubon: französische Texte Pflicht; Code de la consommation |
| ES | ja (Pan-EU) | hoch | Spanisch; Ley General Consumidores |
| PL | ja (CEE-Programm, Pan-EU) | **hoch**: viele DE-Lagerungen laufen über PL/CZ | Polnisch |
| CZ | ja (CEE-Programm) | mittel–hoch | Tschechisch |
| NL | nein (amazon.nl beliefert aus DE) | gering als Lager, gut als Heimatmarkt | Niederländisch, Englisch akzeptiert **(u)** |
| BE, PT, HU, SK, SI | nein bzw. kaum | gering | Landessprache |

Store-Abwicklung, Preisangaben und Widerrufsrecht laufen über Apple und
Google; für Verbraucher-Abos gelten in allen EU-Staaten die Regeln der RL
2011/83/EU und 2019/770 einheitlich. Ab Stufe B braucht es je Land
übersetzte AGB, Datenschutzerklärung und Store-Texte (Rechtsanwalt: vor
Umsetzung prüfen).

## 3. Aufwand in `TaxProfile`-Begriffen (Softwareentwickler)

| Land | Stufe A (weiteres Steuerland) | Stufe B (Heimatland) | Besonderer Treiber |
|---|---|---|---|
| FR | **S**: Sätze 20/10/5,5/2,1 %, CA3 monatlich mit Kennzahlen, Termine (Fälligkeit je SIREN **(u)**), SIE für Ausländer | **XL** | Plattform-E-Rechnung und E-Reporting ab 2027: braucht Anbindung an eine PA (Server) |
| IT | **M**: Sätze 22/10/5/4 %, LIPE vierteljährlich, Jahreserklärung; Rappresentante fiscale/Direktregistrierung | **XL** | SDI-XML für jede Rechnung – nicht ohne Vermittler/Server, widerspricht offline-first |
| ES | **M**: 21/10/4 %, Modelo 303/390, SII nicht nötig | **XL** | keine Kleinunternehmerregel; Verifactu-Software-Anforderungen |
| PL | **L**: JPK_V7 (SAF-T-Datei) monatlich statt Kennzahlen | **XL** | KSeF-Pflicht, Polnisch |
| CZ | **L**: Kontrollmeldung je Rechnung | **L** | Tschechisch, kleiner Markt |
| NL | **S**: 21/9 %, Aangifte vierteljährlich | **M** | KOR, Niederländisch; kein E-Rechnungszwang, keine Kasse |
| BE | S | **XL** | Peppol-Pflicht seit 2026 |
| PT, HU | M | **XL** | zertifizierte Software bzw. Echtzeitmeldung |
| SK, SI | S–M | L | kleiner Markt, E-Rechnung ab 2027/28 |

S = wenige Tage, M = 1–2 Wochen, L = 3–6 Wochen, XL = Monate oder Server
nötig (Schätzung, ohne Übersetzung und Store-Freigaben).

## 4. Bewertung

Gewichtung: Nutzen für heutige Kundinnen (FBA, 30 %), Marktgröße (20 %),
Aufwand/Regulierung (30 %, offline-first ohne Server), Sprache/Recht (20 %).
Punkte 1–5, höher ist besser.

| Land | FBA-Nutzen | Markt | Aufwand | Sprache/Recht | **Gesamt** |
|---|---|---|---|---|---|
| **FR (Stufe A)** | 5 | 4 | 4 | 4 | **4,3** |
| **NL (Stufe B)** | 1 | 3 | 5 | 4 | **3,2** |
| IT (Stufe A) | 4 | 5 | 2 | 3 | 3,4 |
| ES (Stufe A) | 4 | 4 | 3 | 3 | 3,5 |
| PL (Stufe A) | 4 | 4 | 2 | 2 | 3,0 |
| CZ (Stufe A) | 3 | 2 | 2 | 2 | 2,3 |
| IT (Stufe B) | 2 | 5 | 1 | 2 | 2,3 |
| FR (Stufe B) | 2 | 4 | 1 | 2 | 2,1 |
| BE, PT, HU (B) | 1 | 2 | 1 | 2 | 1,4 |
| SK, SI (B) | 1 | 1 | 3 | 2 | 1,8 |

Lesart: Stufe-A-Länder werden untereinander verglichen, Stufe-B-Länder
untereinander; NL ist das beste neue Heimatland, obwohl es als Lagerland
nichts bringt.

## 5. Empfehlung

1. **Frankreich als weiteres Steuerland (Stufe A)** – sofort umsetzbar.
   - Die Auftraggeberin nennt FR selbst als nächste Registrierung (Entscheidung
     2026-10-18, Lastenheft 14a); Pan-EU lagert sehr häufig in FR.
   - Reine Konfiguration im `TaxProfile` (Sätze, CA3-Kennzahlen, Termine,
     SIE-Vorschlag) ohne neue Datenübertragung; die FR-E-Rechnungspflicht
     betrifft Rechnungen, die nach Entscheidung (b) immer aus der Heimat kommen.
   - Kleinster Aufwand je Kundin mit Nutzen; Spanien und Italien folgen nach
     demselben Muster.
2. **Niederlande als erstes neues Heimatland (Stufe B)** – danach.
   - Keine E-Rechnungs-, Echtzeit- oder Kassenpflicht: passt zu offline-first
     ohne Server.
   - Einfache Kleinunternehmerregel (KOR 20.000 €), digitale Affinität hoch.
   - Englisch verbreitet; nur eine weitere Oberflächensprache.

**Bewusst später:** Italien als Heimatland (größter Markt, aber SDI für jede
Rechnung braucht einen Vermittler-Server), Frankreich/Belgien als Heimatland
(Plattform-Pflicht), Polen/Ungarn/Portugal (KSeF, RTIR, zertifizierte
Software).

### Vor Umsetzung prüfen (noch keine Prüfpunkte in Spezifikation 14)

| Land | Punkt | Instanz |
|---|---|---|
| FR | CA3-Kennzahlen und Fälligkeit für ausländische Unternehmer (SIE, Service des impôts des entreprises étrangères), Pflicht zum Fiskalvertreter für EU-Unternehmer (nein **(u)**), E-Reporting-Pflicht für B2C-Verkäufe aus einem FR-Lager ab 2027 **(u)** | Steuerberater |
| FR | Französische Texte in der App für FR-Kundinnen (Loi Toubon) – erst bei Stufe B | Rechtsanwalt |
| NL | KOR-Bedingungen, Gewinnermittlung (Kasstelsel) und Aangifte-Termine; Store-Texte und AGB auf Niederländisch | Steuerberater, Rechtsanwalt |
| alle | Eurostat-Zahlen und alle mit **(u)** markierten Termine neu abrufen | Softwareentwickler |

Diese Punkte kommen erst als Prüfpunkte in Spezifikation Abschnitt 14, wenn
die Auftraggeberin das Land beauftragt (Lastenheft O-41).
