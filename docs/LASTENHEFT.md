# Lastenheft – Buchhaltungsapp für Österreich und Deutschland

**Dokumentversion:** 1.0 · **Stand:** 2026-10-09 · **Status:** Entwurf zur Abstimmung
**Auftraggeber:** Jürgen Jesenko (privates Vorhaben) · **Umsetzung:** Claude Code

> Ein Lastenheft beschreibt, **was** das Produkt leisten soll und **warum** — nicht,
> wie es gebaut wird. Das Wie steht in [`SPECIFICATION.md`](SPECIFICATION.md), die
> jeder Anforderung von hier eine Umsetzung zuordnet.
>
> Dieses Dokument wird wie die übrigen gepflegt: Änderungen am Zielbild werden
> hier eingetragen, bevor Code entsteht. Regeln in [`CLAUDE.md`](../CLAUDE.md).

## Inhalt

1. [Ausgangslage](#1-ausgangslage)
2. [Produktvision und Geschäftsziele](#2-produktvision-und-geschäftsziele)
3. [Zielgruppe](#3-zielgruppe)
4. [Einsatzumfeld](#4-einsatzumfeld)
5. [Funktionale Anforderungen](#5-funktionale-anforderungen)
6. [Nichtfunktionale Anforderungen](#6-nichtfunktionale-anforderungen)
7. [Rechtliche Anforderungen](#7-rechtliche-anforderungen)
8. [Schnittstellen](#8-schnittstellen)
9. [Abgrenzung](#9-abgrenzung)
10. [Ausbaustufen](#10-ausbaustufen)
11. [Abnahmekriterien](#11-abnahmekriterien)
12. [Rahmenbedingungen und Annahmen](#12-rahmenbedingungen-und-annahmen)
13. [Risiken](#13-risiken)
14. [Offene Punkte](#14-offene-punkte)
15. [Änderungshistorie](#15-änderungshistorie)

---

## 1. Ausgangslage

Es existiert ein lauffähiger Stand aus Sprint 1 (App-Version 0.1.0): Firmenprofil,
Belegerfassung mit Foto, Einnahmen-Ausgaben-Rechnung, Kleinunternehmer-Überwachung,
Ausgangsrechnungen mit PDF und vier Exportformate für die Steuerberatung. Offline,
ohne Konto, Android und iOS. 109 automatisierte Tests, CI grün.

Dieses Lastenheft hebt das Vorhaben von einem Werkzeug für den Eigenbedarf auf ein
**kommerzielles Produkt**. Damit ändern sich Anspruch, Umfang und Rechtsrahmen
grundlegend — der bestehende Code bleibt Grundlage, ist aber nicht das Ziel.

---

## 2. Produktvision und Geschäftsziele

### 2.1 Vision

> Ein Einzelunternehmer erledigt seine laufende Buchhaltung vollständig am Telefon —
> Beleg fotografieren oder diktieren statt sammeln, Rechnung unterwegs schreiben,
> Meldungen und Jahresabschluss ohne Zettelwirtschaft vorbereiten. Was heute Abende
> kostet, soll Minuten kosten.

### 2.2 Geschäftsziele

| ID | Ziel |
|---|---|
| G-1 | Kommerzielles Produkt mit wiederkehrenden Einnahmen über ein **Abonnement** |
| G-2 | Zusätzliche **Premium-Services** als separat buchbare Module über dem Basisabo |
| G-3 | Markteintritt in **Österreich und Deutschland** gleichzeitig; die Zweisprachigkeit des Steuerrechts ist bewusst Alleinstellungsmerkmal, nicht Last |
| G-4 | Datenschutz als Verkaufsargument: Buchhaltungsdaten bleiben beim Nutzer, solange er nichts anderes will |
| G-5 | Die Einnahmen finanzieren den Ausbau — insbesondere die laufende Pflege der Steuerwerte und Formulare, die jährlich anfällt |

### 2.3 Erfolgskriterien

| ID | Kriterium |
|---|---|
| E-1 | Ein neuer Nutzer kann ohne Anleitung vom Start bis zum ersten erfassten Beleg in unter fünf Minuten gelangen |
| E-2 | Eine Steuerberatung kann den Jahresexport ohne Rückfragen einlesen |
| E-3 | Das Produkt übersteht einen vollständigen Jahreszyklus inklusive Jahresabschluss im Echtbetrieb |
| E-4 | Keine Rechnung, die wegen fehlender Pflichtangaben beanstandet wird |

---

## 3. Zielgruppe

**Markteintritt:** Einzelunternehmen und Kleinbetriebe in Österreich und Deutschland.

| ID | Anforderung |
|---|---|
| Z-1 | Einzelunternehmer und Kleinunternehmer mit Einnahmen-Ausgaben-Rechnung — mit und ohne Kleinunternehmerregelung |
| Z-2 | Kleinbetriebe mit wenigen Mitarbeitern, weiterhin EAR, aber höherem Belegaufkommen und Regelbesteuerung |
| Z-3 | Fachlich sind keine Buchhaltungskenntnisse vorauszusetzen. Wer „Soll und Haben" nicht kennt, muss das Produkt trotzdem korrekt bedienen können |
| Z-4 | Bilanzierende Betriebe sind **nicht** Zielgruppe des Markteintritts, aber als spätere Ausbaustufe vorgesehen (siehe L-9) |

### Leitbild des typischen Nutzers

Handwerker, Berater, Kreative oder Dienstleister. Zwischen 20 und 200 Belegen im
Monat. Hat eine Steuerberatung, will ihr aber nicht jeden Schuhkarton bringen.
Arbeitet überwiegend am Telefon, selten am Rechner. Hat Angst, etwas falsch zu
machen — und genau diese Angst muss das Produkt nehmen, nicht verstärken.

---

## 4. Einsatzumfeld

| ID | Anforderung |
|---|---|
| U-1 | Mobile App für **Android und iOS**, Bedienung in Hochformat mit einer Hand |
| U-2 | Einsatz unterwegs: Baustelle, Auto, Kassa — oft mit schlechter oder ohne Netzverbindung |
| U-3 | Vollständige Nutzbarkeit **ohne Internetverbindung**; Netz wird nur für ausdrücklich angestoßene Vorgänge gebraucht (UID-Prüfung, Sicherung, später Sync) |
| U-4 | Bedienung mit schmutzigen Händen und bei Sonnenlicht muss möglich sein: große Ziele, hoher Kontrast, Spracheingabe als Alternative zum Tippen |

---

## 5. Funktionale Anforderungen

Priorität: **MUSS** = ohne das kein Release · **SOLL** = wichtig, verhandelbar ·
**KANN** = wünschenswert. Spalte *Stufe* siehe [Abschnitt 10](#10-ausbaustufen).

### 5.1 Unternehmensprofil und Stammdaten

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-1.1 | Der Nutzer legt ein Unternehmensprofil mit allen für Rechnungen und Meldungen nötigen Daten an: Firma, Inhaber, Rechtsform, Anschrift, Kontakt, Steuernummer, UID/USt-IdNr., Bankverbindung | MUSS | A |
| L-1.2 | Das Land (AT/DE) bestimmt Steuersätze, Feldbezeichnungen, Rechtsverweise, Fristen und verfügbare Exportformate | MUSS | A |
| L-1.3 | Die **UID/USt-IdNr. wird auf Gültigkeit geprüft** — formal immer, gegen das EU-MIAS/VIES-Register auf Anforderung | MUSS | A |
| L-1.4 | Auch **Kunden-UIDs** sind prüfbar, mit nachweisbarem Prüfprotokoll (Datum, Ergebnis) — bei innergemeinschaftlichen Leistungen ist das ein Sorgfaltsnachweis | MUSS | A |
| L-1.5 | Die Kleinunternehmerregelung ist ein- und ausschaltbar; die Folgen werden in verständlicher Sprache erklärt | MUSS | A |
| L-1.6 | Das Produkt benennt jederzeit, welche Pflichtangaben für rechtssichere Rechnungen noch fehlen | MUSS | A |
| L-1.7 | Firmenlogo für Rechnungen hinterlegbar | SOLL | A |
| L-1.8 | Mehrere Unternehmen/Mandanten in einer Installation | KANN | C |

### 5.2 Belegerfassung

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-2.1 | Beleg fotografieren oder aus der Fotobibliothek wählen | MUSS | A |
| L-2.2 | Bruttobetrag eingeben, Netto und Umsatzsteuer werden sofort sichtbar errechnet | MUSS | A |
| L-2.3 | **Spracheingabe als gleichwertige Alternative zum Tippen** — jedes Textfeld und jeder Betrag ist diktierbar | MUSS | A |
| L-2.4 | **Belegerkennung (OCR):** Betrag, Datum, Händler und Steuersatz werden aus dem Foto vorgeschlagen; Vorschläge sind immer korrigierbar und werden nie ungeprüft übernommen | MUSS | B |
| L-2.5 | Die Belegerkennung läuft **auf dem Gerät**; ein Beleg verlässt das Telefon dafür nicht | MUSS | B |
| L-2.6 | Kombinierte Erfassung: Foto aufnehmen und dazu frei sprechen, daraus entsteht ein Belegentwurf zur Bestätigung | SOLL | B |
| L-2.7 | Kategorie, Zahlungsart, Geschäftspartner und Notiz erfassbar | MUSS | A |
| L-2.8 | Belege sind durchsuchbar, filterbar und nach Zeitraum gruppiert | MUSS | A |
| L-2.9 | Wiederkehrende Belege als Vorlage speicherbar | SOLL | B |
| L-2.10 | Änderungen und Löschungen werden nachvollziehbar protokolliert | MUSS | A |

### 5.3 Ausgangsrechnungen

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-3.1 | Kundenstamm mit Anschrift, UID und Kontaktdaten | MUSS | A |
| L-3.2 | Rechnung mit mehreren Positionen, Mengen, Einheiten, Einzelpreisen und Steuersätzen | MUSS | A |
| L-3.3 | Fortlaufende, eindeutige Rechnungsnummer nach konfigurierbarem Muster | MUSS | A |
| L-3.4 | Das Produkt prüft alle Pflichtangaben nach § 11 UStG (AT) bzw. § 14 UStG (DE) vor dem Ausstellen und benennt Fehlendes | MUSS | A |
| L-3.5 | Kleinunternehmer: keine Umsatzsteuer, stattdessen der gesetzlich vorgeschriebene Hinweis | MUSS | A |
| L-3.6 | Gestellte Rechnungen sind unveränderlich | MUSS | A |
| L-3.7 | **Storno- und Gutschriftsrechnung** mit Verweis auf die Ursprungsrechnung; die Ursprungsrechnung bleibt erhalten und wird gekennzeichnet | MUSS | A |
| L-3.8 | Rechnung als PDF teilen oder versenden | MUSS | A |
| L-3.9 | Zahlungsstatus pflegen; offene und überfällige Rechnungen sind auf einen Blick erkennbar | MUSS | A |
| L-3.10 | Zahlungserinnerung aus einer bestehenden Rechnung erzeugen | SOLL | B |
| L-3.11 | Rechnungsvorschau vor dem Ausstellen | SOLL | A |
| L-3.12 | Wiederkehrende Rechnungen (Abo-Rechnungen an eigene Kunden) | KANN | C |

### 5.4 E-Rechnung

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-4.1 | Ausgangsrechnungen als **XRechnung** und **ZUGFeRD** (Deutschland, EN 16931) erzeugen | MUSS | B |
| L-4.2 | Ausgangsrechnungen als **ebInterface** (Österreich) erzeugen | MUSS | B |
| L-4.3 | Eingehende strukturierte E-Rechnungen einlesen und als Beleg übernehmen | SOLL | B |
| L-4.4 | Das Produkt erklärt dem Nutzer, wann er welches Format braucht — die Pflichten sind gestaffelt und schwer zu durchschauen | MUSS | B |
| L-4.5 | Versand über Peppol | KANN | C |

### 5.5 Auswertung und Jahresabschluss

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-5.1 | Einnahmen-Ausgaben-Rechnung für wählbare Zeiträume (Monat, Quartal, Jahr) | MUSS | A |
| L-5.2 | Umsatzsteuer je Steuersatz, Vorsteuer, Zahllast oder Guthaben | MUSS | A |
| L-5.3 | **Saldenliste** je Kategorie bzw. Konto mit Vergleich zum Vorzeitraum | MUSS | B |
| L-5.4 | **Rollender Jahresabschluss:** fortlaufende Ergebnisrechnung über zwölf Monate, jederzeit abrufbar statt einmal im Jahr | MUSS | B |
| L-5.5 | Kleinunternehmer-Grenzwertüberwachung mit den unterschiedlichen Regeln je Land und rechtzeitiger Warnung | MUSS | A |
| L-5.6 | Liquiditätsübersicht: was ist offen, was ist fällig, was ist zu erwarten | SOLL | C |
| L-5.7 | Auswertungen auf Basis der **Einnahmen-Ausgaben-Rechnung**; doppelte Buchführung siehe L-9 | MUSS | B |

### 5.6 Meldungen und Steuererklärungen

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-6.1 | **Quartalsweise Umsatzsteuervoranmeldung vorbereiten:** alle Kennzahlen feldgenau aufbereitet, so dass der Nutzer sie unmittelbar in FinanzOnline bzw. ELSTER übertragen kann | MUSS | B |
| L-6.2 | Monatliche UVA für Nutzer, die dazu verpflichtet sind | MUSS | B |
| L-6.3 | **Einkommensteuererklärung vorbereiten:** Zuordnung der Jahreszahlen zu den Feldern der Beilage (AT: E1a, DE: Anlage EÜR) | MUSS | B |
| L-6.4 | Fristenkalender mit Erinnerung an Melde- und Zahlungstermine | SOLL | B |
| L-6.5 | **Elektronische Übermittlung** der UVA über FinanzOnline-Webservice bzw. ELSTER — als kostenpflichtiger Premium-Service | SOLL | C |
| L-6.6 | Elektronische Übermittlung der Einkommensteuererklärung — Premium-Service | KANN | C |
| L-6.7 | Das Produkt stellt an jeder Stelle klar, dass die Verantwortung für die Richtigkeit der Erklärung beim Unternehmer bleibt | MUSS | B |

### 5.7 Datensicherung

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-7.1 | **Vollständige, verschlüsselte Sicherung** aller Daten inklusive Belegfotos in eine Datei | MUSS | A |
| L-7.2 | Automatische Sicherung in den **persönlichen Cloud-Speicher des Nutzers** (iCloud bzw. Google Drive) — ohne Server des Anbieters | MUSS | A |
| L-7.3 | Wiederherstellung auf einem neuen Gerät mit Vorschau, was eingelesen wird | MUSS | A |
| L-7.4 | Warnung, wenn seit der letzten Sicherung zu viel Zeit vergangen ist | MUSS | A |
| L-7.5 | Keine Datenübertragung ohne ausdrückliche Zustimmung des Nutzers | MUSS | A |

### 5.8 Übergabe an die Steuerberatung

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-8.1 | Belegliste als Tabelle (CSV) für beliebige Zeiträume | MUSS | A |
| L-8.2 | DATEV-Buchungsstapel (Deutschland) | MUSS | A |
| L-8.3 | BMD-Buchungssätze (Österreich) | MUSS | A |
| L-8.4 | Umsatzsteuer-Zusammenfassung mit Bemessungsgrundlagen | MUSS | A |
| L-8.5 | Belegfotos als Paket, Dateinamen passend zur Buchungszeile | SOLL | B |
| L-8.6 | Kontenzuordnung je Kategorie durch den Nutzer anpassbar | MUSS | A |

### 5.9 Ausbau zur doppelten Buchführung

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-9.1 | Echte Buchungssätze mit Soll und Haben, Kontenrahmen, Eröffnungs- und Schlussbilanz — als **Premium-Modell** für bilanzierende Betriebe | KANN | C |
| L-9.2 | Das Datenmodell der Stufe A/B ist so anzulegen, dass L-9.1 später ergänzt werden kann, ohne die Datenbasis bestehender Nutzer neu aufzubauen | MUSS | A |

### 5.10 Abonnement und Premium-Services

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-10.1 | **Basisabonnement** (monatlich und jährlich) über die App Stores | MUSS | B |
| L-10.2 | Zusätzlich buchbare **Premium-Services** über dem Basisabo | MUSS | C |
| L-10.3 | Testzeitraum vor dem ersten Kauf | SOLL | B |
| L-10.4 | **Bei abgelaufenem Abo bleiben die Daten des Nutzers lesbar und exportierbar.** Buchhaltungsdaten dürfen nie hinter einer Paywall verschwinden — sie unterliegen einer gesetzlichen Aufbewahrungspflicht | MUSS | B |
| L-10.5 | Lizenzprüfung funktioniert offline über einen angemessenen Zeitraum | MUSS | B |

---

## 6. Nichtfunktionale Anforderungen

| ID | Anforderung |
|---|---|
| NF-1 | **Offline-first.** Alle Kernfunktionen ohne Netzverbindung nutzbar |
| NF-2 | **Datensparsamkeit.** Keine Analyse-, Tracking- oder Werbebibliotheken. Erhobene Daten verlassen das Gerät nur auf ausdrückliche Handlung |
| NF-3 | **Korrektheit vor Funktionsumfang.** Jede Berechnung mit steuerlicher Wirkung ist durch automatisierte Tests abgedeckt. Beträge werden ganzzahlig in Cent geführt |
| NF-4 | **Nachvollziehbarkeit.** Jede Änderung an gebuchten Daten ist protokolliert |
| NF-5 | **Antwortzeit.** Jede Bedienhandlung reagiert in unter 200 ms; ein Beleg ist in unter 30 Sekunden erfasst |
| NF-6 | **Barrierefreiheit.** Bedienbar mit Screenreader und vergrößerter Schrift; Farbe ist nie der einzige Informationsträger |
| NF-7 | **Sprache.** Oberfläche Deutsch, Zahlen- und Datumsformat nach Firmensitz (de_AT / de_DE) |
| NF-8 | **Wartbarkeit.** Länderspezifisches Steuerrecht ist an einer Stelle gebündelt, damit die jährliche Anpassung eine Konfigurationsänderung bleibt |
| NF-9 | **Verständlichkeit.** Fehlermeldungen benennen, was zu tun ist — nicht, was schiefging |
| NF-10 | **Verfügbarkeit der Daten.** Datenverlust ist der schwerste denkbare Fehler. Jede Architekturentscheidung wird daran gemessen |

---

## 7. Rechtliche Anforderungen

| ID | Anforderung |
|---|---|
| R-1 | Rechnungen erfüllen § 11 UStG (AT) bzw. § 14 UStG (DE) einschließlich Kleinbetragsregelung |
| R-2 | Kleinunternehmerregelung nach § 6 Abs 1 Z 27 UStG (AT) und § 19 UStG (DE) korrekt abgebildet, inklusive der unterschiedlichen Grenzen und Toleranzen |
| R-3 | Aufbewahrungsfristen werden dem Nutzer kommuniziert (AT 7 Jahre, DE 8 Jahre für Buchungsbelege) |
| R-4 | DSGVO: Datenschutzerklärung, Auskunfts- und Löschkonzept. Für Stufe C zusätzlich Auftragsverarbeitungsvertrag und Verzeichnis der Verarbeitungstätigkeiten |
| R-5 | E-Rechnung nach EN 16931 für den deutschen B2B-Verkehr; Empfangspflicht besteht seit 2025, Versandpflicht gestaffelt bis 2028 |
| R-6 | Als kommerzielles Produkt zusätzlich: Impressum, AGB, Widerrufsbelehrung, Preisangaben, und eine eigene Rechnungslegung für die Aboerlöse |
| R-7 | Das Produkt ist **keine Registrierkasse** nach RKSV und sagt das unmissverständlich |
| R-8 | Das Produkt ist **keine Steuerberatung**; Verantwortung für Buchhaltung und Erklärungen bleibt beim Nutzer |
| R-9 | Alle steuerlichen Grenzwerte im Produkt tragen ihre Fundstelle und werden jährlich überprüft |

---

## 8. Schnittstellen

| ID | Schnittstelle | Zweck | Stufe |
|---|---|---|---|
| S-1 | EU-MIAS/VIES | Prüfung von UID-Nummern | A |
| S-2 | iCloud Drive / Google Drive | Sicherung in den Speicher des Nutzers | A |
| S-3 | DATEV, BMD | Übergabe an die Steuerberatung | A |
| S-4 | XRechnung, ZUGFeRD, ebInterface | E-Rechnung | B |
| S-5 | App Store / Google Play Billing | Abonnement und Premium-Services | B |
| S-6 | FinanzOnline-Webservice, ELSTER/ERiC | Elektronische Übermittlung von Meldungen | C |
| S-7 | Bankkonto (CAMT, EBICS oder PSD2) | Kontoumsätze einlesen und Belegen zuordnen | C |
| S-8 | Eigenes Backend | Synchronisierung mehrerer Geräte | C |

---

## 9. Abgrenzung

Was das Produkt ausdrücklich **nicht** leistet — und warum:

| Nicht enthalten | Begründung |
|---|---|
| Registrierkasse nach RKSV | Signatureinrichtung, Datenerfassungsprotokoll und Jahresbelegmeldung sind ein eigenes, zertifizierungspflichtiges Produkt |
| Lohnverrechnung | Eigene Domäne mit eigener Haftung und eigenem Pflegeaufwand |
| Steuerberatung im Einzelfall | Das Produkt liefert Zahlen und Hinweise, keine Beratung |
| Warenwirtschaft, Lager, Angebote | Fremde Domäne; Fokus ist Buchhaltung |
| Fremdwährungen | Nur Euro. Mehrwährungsfähigkeit erst mit einem Markt außerhalb der Eurozone |
| Revisionssichere Archivierung | Das Produkt ist Vorerfassung; die revisionssichere Aufbewahrung findet in der Buchhaltung der Kanzlei statt |

---

## 10. Ausbaustufen

Die Stufen sind eine **Empfehlung zur Reihenfolge**, keine Einschränkung des
Zielbilds. Der Auftraggeber hat für die erste veröffentlichte Version den vollen
Umfang der Stufen A und B benannt; die Trennung dient der Planbarkeit und der
Möglichkeit, früher Rückmeldung von echten Nutzern zu bekommen.

### Stufe A — veröffentlichungsfähig

Das Produkt ist verkaufbar und löst das Kernproblem. Enthält alles aus Sprint 1
plus: Datensicherung, Storno/Gutschrift, Spracheingabe, UID-Prüfung,
Rechnungsvorschau, Logo.

**Warum dieser Schnitt:** Datensicherung schließt die einzige echte Lücke des
heutigen Stands. Storno schließt die einzige fachliche Sackgasse. Beides zusammen
ergibt ein Produkt, das man guten Gewissens verkaufen kann.

### Stufe B — vollwertige Buchhaltung

Belegerkennung, E-Rechnung, Saldenliste, rollender Jahresabschluss, UVA- und
Einkommensteuer-Vorbereitung, Abonnement, Belegvorlagen, Zahlungserinnerung.

### Stufe C — Premium und Ausbau

Elektronische Übermittlung an FinanzOnline und ELSTER, doppelte Buchführung mit
Bilanz, Cloud-Synchronisierung mit Konto, Bankabgleich, mehrere Mandanten,
Liquiditätsvorschau, Peppol.

### Aufwandseinschätzung

Grobe Schätzung in Personenwochen Vollzeitentwicklung, ohne Puffer:

| Block | Stufe | Aufwand |
|---|---|---|
| Datensicherung verschlüsselt inkl. Cloud-Ablage | A | 3–4 |
| Storno- und Gutschriftsrechnung | A | 1–2 |
| Spracheingabe durchgängig | A | 1–2 |
| UID-Prüfung inkl. Protokoll | A | 1–2 |
| Rechnungsvorschau, Logo, Feinschliff | A | 1–2 |
| Store-Reife: Icon, Screenshots, AGB, Impressum, Support | A | 2–3 |
| **Summe Stufe A** | | **9–15** |
| Belegerkennung on-device | B | 3–5 |
| E-Rechnung XRechnung/ZUGFeRD/ebInterface | B | 4–6 |
| Saldenliste und rollender Jahresabschluss | B | 2–3 |
| UVA-Vorbereitung | B | 2–3 |
| Einkommensteuer-Vorbereitung | B | 3–4 |
| Abonnement und Lizenzlogik | B | 2–3 |
| Belegvorlagen, Zahlungserinnerung | B | 1–2 |
| **Summe Stufe B** | | **17–26** |
| **Stufe A + B zusammen** | | **26–41 Personenwochen** |

Das entspricht etwa **sechs bis zehn Monaten** durchgehender Entwicklung. Stufe C
ist darin nicht enthalten und dürfte denselben Umfang noch einmal haben.

---

## 11. Abnahmekriterien

| ID | Kriterium |
|---|---|
| A-1 | Statische Analyse ohne Befund, Formatierung eingehalten, alle Tests grün |
| A-2 | Jede steuerliche Berechnung ist durch Tests abgedeckt; die Invariante `netto + USt = brutto` gilt ausnahmslos |
| A-3 | Spezifikation und Benutzerhandbuch sind zum Code passend |
| A-4 | Android- und iOS-Build laufen in der CI durch |
| A-5 | Ein vollständiger Durchlauf auf echten Geräten: Onboarding, Beleg, Rechnung, Storno, Export, Sicherung, Wiederherstellung |
| A-6 | Eine Steuerberatung hat je einen Probeexport für AT und DE eingelesen und bestätigt |
| A-7 | Die steuerlichen Grenzwerte wurden vor dem Release gegen die geltende Rechtslage geprüft |
| A-8 | Datenschutzerklärung, Impressum und AGB liegen vor und sind veröffentlicht |

---

## 12. Rahmenbedingungen und Annahmen

| ID | Rahmenbedingung |
|---|---|
| B-1 | Technologie: Flutter, eine Codebasis für Android und iOS |
| B-2 | Lokale Datenhaltung in SQLite; der Nutzer braucht kein Konto, um zu arbeiten |
| B-3 | Entwicklungsumgebung: der Android-SDK ist im Container nicht installierbar; Plattform-Builds laufen in der CI, iOS-Builds auf macOS-Runnern |
| B-4 | Die Bundle-ID muss **vor dem ersten Store-Upload** endgültig festgelegt werden — sie ist danach unveränderlich |
| B-5 | Ein Apple-Entwicklerkonto (99 $/Jahr) und ein Google-Play-Konto (25 $ einmalig, mit Identitätsprüfung) werden benötigt |
| B-6 | Die Pflege der Steuerwerte ist ein **jährlich wiederkehrender Aufwand**, kein einmaliger |
| B-7 | Für Stufe C entstehen laufende Serverkosten und DSGVO-Pflichten als Auftragsverarbeiter |

---

## 13. Risiken

| ID | Risiko | Wirkung | Gegenmaßnahme |
|---|---|---|---|
| RK-1 | **Falsche steuerliche Werte im Produkt.** Ein falscher Grenzwert führt zu falschen Rechnungen beim Nutzer | sehr hoch | Werte an einer Stelle, mit Fundstelle, durch Tests gegen die Spezifikation abgesichert, jährliche Prüfung als fester Termin |
| RK-2 | **Haftung bei kommerziellem Vertrieb.** Der Nutzer verlässt sich auf das Produkt | hoch | Klare Abgrenzung in AGB und Oberfläche, keine Zusicherung steuerlicher Richtigkeit, Prüfung durch Steuerberatung vor Release |
| RK-3 | **Datenverlust beim Nutzer** | hoch | Datensicherung ist Stufe A und Releasevoraussetzung |
| RK-4 | **Umfang der Stufe B wird unterschätzt**, besonders E-Rechnung und Einkommensteuer | hoch | Stufe A früh veröffentlichen, Stufe B gegen echte Nutzerrückmeldung priorisieren |
| RK-5 | **Elektronische Übermittlung** erfordert Registrierung als Softwarehersteller und laufende Formularpflege | mittel | Bewusst erst Stufe C, als Premium-Service mit eigener Preisgestaltung |
| RK-6 | **Store-Ablehnung** wegen fehlender Angaben oder unklarer Berechtigungstexte | mittel | Release-Playbook abarbeiten, frühe TestFlight- und interne Tests |
| RK-7 | **Abhängigkeit von Drittbibliotheken**, die vor einem Store-Release aktualisiert werden müssen | niedrig | Abhängigkeiten bewusst knapp halten |

---

## 14. Offene Punkte

Zu entscheiden, bevor die betroffene Anforderung umgesetzt wird:

| ID | Offener Punkt | Benötigt für |
|---|---|---|
| O-1 | **Prüfung der österreichischen Kleinunternehmer-Logik.** Mehrere Quellen beschreiben § 6 Abs 1 Z 27 UStG so, dass **auch der Vorjahresumsatz** unter 55.000 € liegen muss. Die heutige Implementierung prüft nur das laufende Jahr. Amtliche Quellen waren aus der Entwicklungsumgebung nicht erreichbar — Bestätigung durch die Steuerberatung nötig | sofort; betrifft bestehenden Code |
| O-2 | Produktname und Bundle-ID | vor dem ersten Store-Upload |
| O-3 | Preispunkte für Basisabo und Premium-Services | Stufe B |
| O-4 | Zuschnitt der Premium-Services: Was gehört ins Basisabo, was kostet extra | Stufe B |
| O-5 | Zeitrahmen und verfügbare Arbeitszeit pro Woche | Planung |
| O-6 | Weitere Plattformen (Web, Desktop) gewünscht? | Stufe C |
| O-7 | Englische Oberfläche für nicht deutschsprachige Unternehmer in AT/DE? | Stufe C |
| O-8 | Wie wird Support geleistet, und mit welcher Reaktionszeit? | vor Release |
| O-9 | Steuerberatung als fachlicher Prüfer — wer, und ab wann eingebunden? | Stufe A |

---

## 15. Änderungshistorie

| Version | Datum | Änderung |
|---|---|---|
| 1.0 | 2026-10-09 | Erstfassung. Festlegung auf kommerzielles Produkt mit Abonnement und Premium-Services, Zielgruppe Einzelunternehmen und Kleinbetriebe in AT und DE, Datenhaltung lokal mit Sicherung in den Cloud-Speicher des Nutzers und späterem Cloud-Sync, Meldungen zunächst vorbereitend mit späterer elektronischer Übermittlung, Auswertungen auf EAR-Basis mit späterer doppelter Buchführung. |

### Pflege dieses Dokuments

Das Lastenheft steht **vor** der Spezifikation: Änderungen am Zielbild werden hier
eingetragen, bevor Code entsteht. Jede neue Anforderung bekommt eine ID, eine
Priorität und eine Stufe. Umgesetzte Anforderungen bleiben stehen — das Lastenheft
ist kein Aufgabenzettel, sondern die Beschreibung des gewollten Produkts.
