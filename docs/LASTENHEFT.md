# Lastenheft – JeNi bucht, Buchhaltungsapp für Österreich und Deutschland

**Dokumentversion:** 1.84 · **Stand:** 2026-10-19 · **Status:** Entwurf zur Abstimmung
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
10. [Ausbaustufen](#10-ausbaustufen) · [10a. Umsetzungsstand](#10a-umsetzungsstand)
11. [Abnahmekriterien](#11-abnahmekriterien)
12. [Rahmenbedingungen und Annahmen](#12-rahmenbedingungen-und-annahmen)
13. [Risiken](#13-risiken)
14. [Offene Punkte](#14-offene-punkte) · [14a. Entscheidungen der Auftraggeberin](#14a-entscheidungen-der-auftraggeberin)
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

**Stand 2026-10-15 (App-Version 0.13.0, Testbuild):** Seit Sprint 1 sind unter
anderem Datensicherung (manuell und automatisch), App-Sperre, Belegerkennung mit
Kassen- und Zahlungs-QR, PDF- und E-Rechnungs-Übernahme, Fremdwährung, Belege mit
mehreren Steuersätzen, Rabatt/Skonto/Versand, Mahnwesen, Wirtschaftsjahr,
Termin-Box, Hilfe, Tablet-Layout, Einhandbedienung und der Import von
Plattformexporten, Stornorechnung, das Menü „Rechtliches“ und der Wiederherstellungscode als Druckblatt umgesetzt. Welche Anforderung in welcher Version umgesetzt
wurde, zeigt Abschnitt 10a; Datenbankschema 18, über 400 automatisierte Tests.

---

## 2. Produktvision und Geschäftsziele

### 2.1 Vision

> Ein Einzelunternehmer erledigt seine laufende Buchhaltung vollständig am Telefon —
> Beleg fotografieren oder diktieren statt sammeln, Rechnung unterwegs schreiben,
> Meldungen und Jahresabschluss ohne Zettelwirtschaft vorbereiten. Was heute Abende
> kostet, soll Minuten kosten.

### 2.1a Leitprinzip Einfachheit (fundamentale Anforderung)

Festgelegt von der Auftraggeberin am 2026-10-14: Oberstes Produktziel ist die
einfachste mögliche Nutzung aus Sicht der Anwenderin. Jede Funktion wird daran
gemessen, wie viele Schritte, Eingaben und Entscheidungen sie verlangt.

| ID | Anforderung | Priorität | Stufe |
|---|---|---|---|
| L-0.1 | Beleg fotografieren und auslesen funktioniert überall und jederzeit mit hoher Trefferquote; die Erkennung ist die Kernfunktion des Produkts | MUSS | A |
| L-0.2 | Felder werden aus dem Beleg vorgeschlagen (Betrag, Datum, Steuersatz, Händler, Beschreibung, Kategorie); die Nutzerin übernimmt mit einem Tipp und korrigiert nur Abweichungen | MUSS | A |
| L-0.3 | Wiederkehrende Bestätigungen werden mit der Hauptaktion zusammengelegt (z. B. Vollständigkeit = Speichern) | MUSS | A |
| L-0.4 | Gebuchte Belege gelten als betrieblich; die App stellt das nicht in Frage | MUSS | A |
| L-0.5 | Jede neue Funktion wird vor der Umsetzung auf die Zahl der Schritte geprüft; der kürzere Weg gewinnt | MUSS | A |
| L-0.6 | **Einhandbedienung mit dem Daumen**, links wie rechts gleich gut: Hauptaktion zentriert bzw. volle Breite unten, Zielflächen ≥ 48 dp, Gefahrenknöpfe abgesetzt. **Keine Händigkeits-Einstellung** (Entscheidung Auftraggeberin 2026-10-14, DESIGN_SPEC 5a). Umgesetzt in 0.6.0 und 0.7.0 (Spezifikation FA-12.1 bis FA-12.7) | MUSS | A |

Umsetzungsstand L-0.1 bis L-0.5: Belegerkennung und Vorschläge seit 0.3.0,
Kassen-QR seit 0.8.0; Vollständigkeit = Speichern seit 0.2.0 (FA-2.14);
Belege werden ohne Rückfrage zur betrieblichen Veranlassung gebucht.

### 2.2 Geschäftsziele

| ID | Ziel |
|---|---|
| G-1 | Kommerzielles Produkt mit wiederkehrenden Einnahmen über ein **Abonnement** |
| G-2 | Zusätzliche **Premium-Services** als separat buchbare Module über dem Basisabo |
| G-3 | Markteintritt in **Österreich und Deutschland**; die Zweisprachigkeit des Steuerrechts ist bewusst Alleinstellungsmerkmal, nicht Last. Mittelfristig weitere **EU-Länder der Eurozone** |
| G-4 | Datenschutz als Verkaufsargument: Buchhaltungsdaten bleiben beim Nutzer, solange er nichts anderes will |
| G-5 | Die Einnahmen finanzieren den Ausbau — insbesondere die laufende Pflege der Steuerwerte und Formulare, die jährlich anfällt |

### 2.3 Erfolgskriterien

| ID | Kriterium |
|---|---|
| E-1 | Ein neuer Nutzer kann ohne Anleitung vom Start bis zum ersten erfassten Beleg in unter fünf Minuten gelangen |
| E-2 | Eine Steuerberatung kann den Jahresexport ohne Rückfragen einlesen |
| E-3 | Das Produkt übersteht einen vollständigen Jahreszyklus inklusive Jahresabschluss im Echtbetrieb |
| E-4 | Keine Rechnung, die wegen fehlender Pflichtangaben beanstandet wird |
| E-5 | Ein Nutzer, der mitten im Jahr von einer anderen Lösung wechselt, kann ohne Bruch weiterarbeiten |

---

## 3. Zielgruppe

**Markteintritt:** Einzelunternehmen und Kleinbetriebe in Österreich und Deutschland.

| ID | Anforderung |
|---|---|
| Z-1 | Einzelunternehmer und Kleinunternehmer mit Einnahmen-Ausgaben-Rechnung — mit und ohne Kleinunternehmerregelung |
| Z-2 | Kleinbetriebe mit wenigen Mitarbeitern, weiterhin EAR, aber höherem Belegaufkommen und Regelbesteuerung |
| Z-3 | Fachlich sind keine Buchhaltungskenntnisse vorauszusetzen. Wer „Soll und Haben" nicht kennt, muss das Produkt trotzdem korrekt bedienen können |
| Z-4 | Bilanzierende Betriebe sind **nicht** Zielgruppe des Markteintritts, aber als spätere Ausbaustufe vorgesehen (siehe L-9) |
| Z-5 | **Händler mit eigenen Produkten** sind ausdrücklich eingeschlossen: sie brauchen Artikelstamm und Lagerstand (L-11), später die Anbindung ihrer Verkaufskanäle (L-12) |

### 3.1 Zielmärkte

| ID | Markt | Status |
|---|---|---|
| M-1 | **Österreich** | Markteintritt |
| M-2 | **Deutschland** | Markteintritt |
| M-3 | Weitere **EU-Länder der Eurozone** | Erweiterung, Reihenfolge offen (O-14) |

Der Zuschnitt ist bewusst eng: **EU-Mitgliedschaft und Euro** sind Voraussetzung
für einen Markt. Damit gilt überall dasselbe Grundmuster — gemeinsames
Mehrwertsteuersystem, UID-Prüfung über VIES, E-Rechnung nach EN 16931, OSS für
grenzüberschreitende Verkäufe, eine Währung. Ein weiterer Markt ist dann
überwiegend Konfiguration und keine Neuentwicklung.

> **Entscheidung vom 2026-10-09: Die Schweiz entfällt.** Sie war in Version 1.2
> noch als dritter Markteintritt vorgesehen. Sie ist weder EU-Mitglied noch
> Euro-Land und hätte Mehrwährungsfähigkeit, ein eigenes Zahlenformat, QR-Rechnung
> nach SIX-Standard, ein eigenes Datenschutzgesetz und eine vom EU-System
> abweichende Steuersystematik erfordert — rund sieben bis zehn Personenwochen auf
> dem Weg zur ersten verkaufbaren Version, für einen Markt, der das Produkt noch
> nicht bestätigt hat. Die Entscheidung ist umkehrbar; was dafür nötig wäre, ist
> in Version 1.2 dieses Dokuments beschrieben.

### Leitbild des typischen Nutzers

**Hauptzielgruppe (festgelegt am 2026-10-09):** alleinstehende Frau zwischen 20
und 60 Jahren, durchschnittliche Ausbildung, Einzelunternehmerin mit kleinem
Webshop oder Dienstleistung. Wenig technisches Verständnis, schnell überfordert
und frustriert. Produkt, Name und Werbung richten sich an sie. Daraus folgt für
jede Gestaltungsentscheidung: ein Schritt pro Bildschirm, Alltagssprache statt
Fachbegriff (Fachbegriff nur als Erklärung dahinter), keine Sackgassen, jede
Fehlermeldung sagt, was zu tun ist.

Weitere Nutzer: Handwerker, Berater, Kreative. Zwischen 20 und 200 Belegen im
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
| U-5 | Das Produkt wird in Märkten mit **unterschiedlichen Rechtsordnungen** eingesetzt; Steuerrecht, Pflichtangaben und Formate richten sich nach dem Sitz des Unternehmens |

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
| L-1.9 | Das Logo ergänzt Name und Anschrift auf der Rechnung, ersetzt sie nie; es wird bei der Rechnungslegung eingefroren, damit gestellte Rechnungen mit dem damaligen Logo reproduzierbar bleiben | MUSS | A |

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
| L-2.11 | **Zweitablage der Belegfotos** in einem eigenen Album der Fotobibliothek des Geräts (Apple Fotos bzw. Google Fotos) — als zusätzliche Sicherheit und weil der Nutzer dort ohnehin sucht | SOLL | A |
| L-2.12 | Die Zweitablage ist **standardmäßig ausgeschaltet** und muss vom Nutzer bewusst aktiviert werden; beim Einschalten wird erklärt, dass die Fotodienste automatisch in die Cloud synchronisieren | MUSS | A |
| L-2.13 | Die Zweitablage nutzt ein **eigenes Album** ("Buchhaltung") und mischt Belege nicht unter die privaten Fotos | MUSS | A |
| L-2.14 | Die Zweitablage ersetzt die Datensicherung nach L-7.1 nicht und wird im Produkt auch nicht als Sicherung bezeichnet — sie enthält nur Bilder, keine Buchungsdaten | MUSS | A |
| L-2.15 | **Mehrere Seiten je Beleg:** weitere Seiten aufnehmen, vor dem Speichern Reihenfolge ändern und einzelne Seiten löschen; danach feste Reihenfolge, nur noch Anhängen. Aufnahmen werden nach dem Speichern nie verändert, eine Bildverbesserung nur als Kopie | MUSS | A |
| L-2.16 | Vor dem Buchen neuer Seiten bestätigt die Nutzerin die Vollständigkeit („Alle Seiten inkl. beschriebener Rückseiten erfasst“); die Seitenzahl steht im Änderungsprotokoll | MUSS | A |
| L-2.17 | **Kommentare zu Belegen**, auch nach dem Buchen und bei stornierten Belegen: nur anhängbar, mit Systemzeitstempel, kein Bearbeiten oder Löschen, Korrektur als neuer Kommentar, Eintrag im Änderungsprotokoll; der Beleg bleibt unverändert. Kommentare stehen in Export und Sicherung | MUSS | A |
| L-2.20 | **Belege automatisch auslesen** (konkretisiert L-2.4, L-2.5): nach dem Foto werden alle Seiten auf dem Gerät erkannt; Belegdatum, Bruttobetrag, Umsatzsteuer je Satz, Netto, Händler, UID des Ausstellers und Rechnungsnummer werden mit Konfidenz vorgeschlagen und als „erkannt – bitte prüfen“ markiert. Gebucht wird erst nach Bestätigung beim Speichern; das Originalbild bleibt unverändert; „Erneut auslesen“ jederzeit | MUSS | A |
| L-2.21 | **Fremdwährung** nur bei Eingangsbelegen erkennen und mit dem Betrag laut Beleg speichern; die Umrechnung in Euro ist ein eigener späterer Schritt. Ausgangsrechnungen bleiben in Euro | MUSS | A |
| L-2.22 | Erkannte und bestätigte Werte je Feld, Erkennungs-Engine mit Version und Prüfsumme (SHA-256) der Originalbilder stehen im Änderungsprotokoll (GoBD-Nachvollziehbarkeit); keine Bilddaten im Protokoll | MUSS | A |
| L-2.23 | Die automatische Erkennung ist in den Einstellungen abschaltbar | MUSS | A |
| L-2.24 | **Fremdwährung bei Eingangsbelegen:** Originalbetrag (kleinste Einheit), ISO-Code, Kurs als Ganzzahl (Kurs × 10^6), Kursdatum, Kursquelle (BMF-Monat, EZB-Monatsmittel als Näherung, EZB-Tag, manuell, Bank); gebucht wird in Euro (Entscheidung Auftraggeberin 2026-10-12). **Umgesetzt** (Spezifikation FA-2.24, GR-9; Kurs als Einheiten je 1 € × 10^6) | MUSS | A |
| L-2.25 | Umsatzsteuer-Kurs: Monatskurs des Leistungs- bzw. Zahlungsmonats (§ 20 Abs 6 UStG AT, § 16 Abs 6 UStG DE); Tageskurs nur mit im Profil vermerkter Genehmigung des Finanzamts. **Umgesetzt** (FA-2.25; EZB-Monatsmittel als gekennzeichnete Näherung, BMF-Kurs manuell) | MUSS | A |
| L-2.26 | Einnahmen-Ausgaben-Rechnung: tatsächlicher Euro-Betrag laut Bank überschreibt den umgerechneten Wert; der Vorschlag bleibt protokolliert. **Umgesetzt** (FA-2.26, FA-2.27) | MUSS | A |
| L-2.27 | Ein Beleg mit **mehreren Steuersätzen** (Bewirtung Speisen/Getränke, Supermarkt) wird nach Sätzen aufgeteilt: Brutto je Satz, Netto und Steuer je Teil, Summe = Belegbetrag, Rest automatisch im letzten Teil; alle Auswertungen und Exporte je Satz (DATEV eine Buchung je Satz); Belegerkennung belegt die Aufteilung vor. Abzugsbeschränkung Bewirtung über die Kategorie „Bewirtung“ (Entscheidung 14a, umgesetzt 0.21.0, Spezifikation FA-2.60). **Umgesetzt** in 0.7.0 (FA-2.33, FA-2.34, Schema 14) | MUSS | A |
| L-2.18 | Kommentare lassen sich über die Diktierfunktion der Systemtastatur sprechen; die App selbst überträgt keine Sprache. Ein Hinweis nennt, dass die Tastatur je nach Gerät Sprache an Google oder Apple senden kann | SOLL | A |
| L-2.28 | **Lernen je Lieferant** (konkretisiert L-0.2, L-2.20): die App merkt sich je Lieferant (UID bzw. Name) den bestätigten Namen, Kategorie, Steuersatz, Währung und Zahlungsart und schlägt sie beim nächsten Beleg desselben Lieferanten „wie beim letzten Mal“ vor; erkannte Werte gehen vor, wo die Erkennung sicher ist. Nur auf dem Gerät. Teil der Belegerkennung (Pro). **Umgesetzt 0.16.0** (Spezifikation FA-2.50) | SOLL | A |

### 5.3 Ausgangsrechnungen

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-3.1 | Kundenstamm mit Anschrift, UID und Kontaktdaten | MUSS | A |
| L-3.2 | Rechnung mit mehreren Positionen, Mengen, Einheiten, Einzelpreisen und Steuersätzen | MUSS | A |
| L-3.3 | Fortlaufende, eindeutige Rechnungsnummer nach konfigurierbarem Muster | MUSS | A |
| L-3.4 | Das Produkt prüft alle Pflichtangaben nach § 11 UStG (AT) bzw. § 14 UStG (DE) vor dem Ausstellen und benennt Fehlendes | MUSS | A |
| L-3.5 | Kleinunternehmer: keine Umsatzsteuer, stattdessen der gesetzlich vorgeschriebene Hinweis | MUSS | A |
| L-3.6 | Gestellte Rechnungen sind unveränderlich | MUSS | A |
| L-3.7 | **Stornorechnung bzw. Rechnungskorrektur** mit Verweis auf die Ursprungsrechnung; die Ursprungsrechnung bleibt erhalten und wird gekennzeichnet. Das Wort „Gutschrift" wird auf dem Beleg nicht verwendet, weil es umsatzsteuerlich die Abrechnung durch den Leistungsempfänger bezeichnet (§ 14 Abs 2 UStG DE, § 11 Abs 7 UStG AT) | MUSS | A |
| L-3.8 | Rechnung als PDF teilen oder versenden | MUSS | A |
| L-3.9 | Zahlungsstatus pflegen; offene und überfällige Rechnungen sind auf einen Blick erkennbar | MUSS | A |
| L-3.10 | **Zahlungserinnerung und Mahnung** aus einer offenen, fälligen Rechnung beliebig oft erzeugen und versenden: Stufe 1 „Zahlungserinnerung“, danach „1. Mahnung“, „2. Mahnung“ usw. (PDF mit Verweis auf Rechnungsnummer, offenem Betrag, Kosten, Zinsen, Gesamt und neuer Frist als Datum); die Mahnstufe steht an der Rechnung; Hinweis „überfällig – mahnen?“ mit einem Tipp | MUSS | A |
| L-3.11 | Rechnungsvorschau vor dem Ausstellen | SOLL | A |
| L-3.12 | Wiederkehrende Rechnungen (Abo-Rechnungen an eigene Kunden) | KANN | C |
| L-3.13 | **Angebote** mit eigenem Nummernkreis, unabhängig vom Rechnungsnummernkreis | MUSS | A |
| L-3.14 | Ein Angebot hat **keine steuerliche Wirkung**: es erscheint weder im Kassabuch noch in der UVA, noch in der Grenzwertüberwachung | MUSS | A |
| L-3.15 | Ein Angebot lässt sich **mit einem Tipp in eine Rechnung umwandeln**; Positionen, Kunde und Preise werden übernommen und bleiben vor dem Ausstellen änderbar | MUSS | A |
| L-3.16 | Angebotsstatus: offen, angenommen, abgelehnt, abgelaufen; mit Gültigkeitsdatum | MUSS | A |
| L-3.17 | Angebot als PDF teilen; die PDF trägt sichtbar „Angebot", nie „Rechnung" | MUSS | A |
| L-3.18 | **Erstattung:** zu einer Rechnungskorrektur (L-3.7), auch über einen Teilbetrag oder einzelne Positionen, wird die Rückzahlung an den Kunden als Ausgabe mit Zahlungsdatum erfasst. Die Umsatzsteuer wird bei **Ist-Versteuerung im Zeitraum der Rückzahlung**, bei Soll-Versteuerung im Zeitraum der Korrektur berichtigt (§ 17 UStG DE, § 16 UStG AT) | MUSS | A |
| L-3.19 | Die im Kundenstamm hinterlegte **E-Mail-Adresse ist Standardempfänger** beim Versand von Rechnung, Angebot und Zahlungserinnerung; je Kunde ist eine abweichende Rechnungsadresse für E-Mails möglich | MUSS | A |
| L-3.20 | **Rücksendeschein** zu einer Rechnung: welche Positionen in welcher Menge zurückgehen, mit Grund; ohne steuerliche Wirkung, bis daraus eine Gutschrift (L-3.7) erzeugt wird. Je Rücksendung wählbar „Ware wieder verkaufbar? Ja / Nein"; bei Ja wird die Menge dem Lagerstand (L-11) wieder zugebucht, bei Nein nicht | SOLL | B |
| L-3.21 | **Rabatt** je Position und auf die ganze Rechnung, wahlweise in Prozent oder als Betrag. Der Gesamtrabatt wird anteilig nach Entgelt je Steuersatz verteilt und je Satz als Rabattzeile ausgewiesen (Entgeltminderung je Satz, § 11 Abs 1 Z 3 lit e UStG AT, § 14 Abs 4 Nr. 7 UStG DE) | MUSS | A |
| L-3.22 | **Versandkosten** als eigene Zeile; Steuer wie die Hauptleistung (Nebenleistung): ein Satz → dieser Satz, mehrere Sätze → anteilig nach Entgelt; ein fester Satz ist wählbar | MUSS | A |
| L-3.23 | **Skonto** als Tage und Prozent, Vorschlag aus den Stammdaten; auf der Rechnung mit festem Datum und Betrag | MUSS | A |
| L-3.24 | Beim Zahlungseingang fragt das Produkt mit einem Tipp „Mit Skonto bezahlt?“; die Einnahme je Steuersatz mindert sich anteilig, die Umsatzsteuer wird im Zahlungsmonat berichtigt (§ 16 UStG AT, § 17 UStG DE); die Rechnung bleibt unverändert | MUSS | A |
| L-3.25 | **AGB-Verweis**: Adresse der Verkaufsbedingungen im Profil, eingefroren mit der Rechnung, Hinweis „soweit sie vereinbart wurden“ auf Rechnung (und Angebot) | SOLL | A |
| L-3.26 | Beim Eintragen der AGB-Adresse einmaliger Hinweis, dass der Verweis auf der Rechnung allein die AGB nicht einbezieht | SOLL | A |
| L-3.27 | **Mahnkosten** 10,00 € je Mahnung ab der 1. Mahnung (Zahlungserinnerung kostenlos), änderbar; bei Privatkunden Hinweis, dass nur angemessene, tatsächliche Kosten zulässig sind. **Verzugszinsen** optional mit gesetzlichem Vorschlag (AT § 1000 ABGB, § 456 UGB; DE § 288 BGB), Basiszinssatz mit Gültigkeitsbeginn; 40-€-Pauschale nur gegenüber Unternehmen (§ 458 UGB, § 288 Abs 5 BGB) | MUSS | A |
| L-3.28 | Kundenmerkmal **Unternehmen** (vorbelegt Ja mit UID); in DE tragen Rechnungen an Privatkunden den Hinweis nach § 286 Abs 3 BGB | MUSS | A |
| L-3.31 | Jedes Mahnschreiben setzt eine **neue Zahlungsfrist** (vorbelegt +14 Tage), die im Schreiben steht und an der Rechnung gespeichert ist; „überfällig“ erst nach deren Ablauf. Gemahnte Rechnungen tragen in der Liste ein Symbol mit Stufe und Frist, Tipp zeigt den Verlauf. Kundendokumente (Rechnung, Erinnerung, Mahnung, Begleittext) **immer in Sie-Form, ohne Umschaltung auf Du** (Entscheidung Auftraggeberin 2026-10-14; die App-Oberfläche duzt). **Umgesetzt** in 0.7.0 (FA-5.26 bis FA-5.28) | MUSS | A |
| L-3.29 | Mahnschreiben sind **unveränderlich** (Text, Sätze, Beträge, PDF-Prüfsumme); nur Storno mit Begründung; sachlicher Ton ohne Drohungen; Versand wie Rechnung | MUSS | A |
| L-3.30 | Mahnkosten, Zinsen und Pauschale sind **nicht umsatzsteuerbar**, getrennt ausgewiesen und werden bei Zahlung als Einnahme gebucht; Anrechnung Kosten → Zinsen → Hauptforderung (§ 1416 ABGB, § 367 BGB) | MUSS | A |

### 5.4 E-Rechnung

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-4.1 | Ausgangsrechnungen als **XRechnung** und **ZUGFeRD** (Deutschland, EN 16931) erzeugen | MUSS | B |
| L-4.2 | Ausgangsrechnungen als **ebInterface** (Österreich) erzeugen | MUSS | B |
| L-4.3 | Eingehende strukturierte E-Rechnungen einlesen und als Beleg übernehmen; in Deutschland seit 2025 **Empfangspflicht für alle Unternehmen, auch Kleinunternehmer** — daher Basis-Tarif | MUSS | A |
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
| L-5.8 | **Management-Übersicht** als Startseite: Einnahmen, Ausgaben und Ergebnis im laufenden Monat und Jahr, offene Forderungen, Umsatzsteuer-Zahllast, Grenzwert-Ampel | MUSS | A |

### 5.6 Meldungen und Steuererklärungen

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-6.1 | **Quartalsweise Umsatzsteuervoranmeldung vorbereiten:** alle Kennzahlen feldgenau aufbereitet, so dass der Nutzer sie unmittelbar in FinanzOnline bzw. ELSTER übertragen kann | MUSS | B |
| L-6.2 | Monatliche UVA für Nutzer, die dazu verpflichtet sind | MUSS | B |
| L-6.3 | **Einkommensteuererklärung vorbereiten:** Zuordnung der Jahreszahlen zu den Feldern der Beilage (AT: E1a, DE: Anlage EÜR) | MUSS | B |
| L-6.4 | Fristenkalender mit Erinnerung an Melde- und Zahlungstermine | SOLL | B |
| L-6.5 | **Elektronische Übermittlung** der UVA über FinanzOnline-Webservice bzw. ELSTER — **im Buchhaltungstarif enthalten**, weil sie bei allen ernsthaften Mitbewerbern Standard ist (siehe [`WETTBEWERB.md`](WETTBEWERB.md)) | MUSS | B |
| L-6.6 | Elektronische Übermittlung der Einkommensteuererklärung — bleibt Premium-Service | KANN | C |
| L-6.7 | Das Produkt stellt an jeder Stelle klar, dass die Verantwortung für die Richtigkeit der Erklärung beim Unternehmer bleibt | MUSS | B |

### 5.7 Datensicherung

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-7.1 | **Vollständige, verschlüsselte Sicherung** aller Daten inklusive Belegfotos in eine Datei | MUSS | A |
| L-7.2 | Automatische Sicherung in den **persönlichen Cloud-Speicher des Nutzers** (iCloud bzw. Google Drive) — ohne Server des Anbieters | MUSS | A |
| L-7.3 | Wiederherstellung auf einem neuen Gerät mit Vorschau, was eingelesen wird | MUSS | A |
| L-7.4 | Warnung, wenn seit der letzten Sicherung zu viel Zeit vergangen ist | MUSS | A |
| L-7.5 | Keine Datenübertragung ohne ausdrückliche Zustimmung des Nutzers | MUSS | A |
| L-7.6 | Die automatische Sicherung ist **standardmäßig aus** und wird erst nach einer Erklärseite eingeschaltet: Inhalt samt Daten Dritter, Ziel beim gewählten Dienst unter dessen Bedingungen (oft außerhalb der EU), Verschlüsselung, Folge eines Code-Verlusts, Aufbewahrungspflicht | MUSS | A |
| L-7.7 | Der Schlüssel der automatischen Sicherung ist zufällig (256 Bit), liegt nur geräteintern (iOS-Schlüsselbund „nur dieses Gerät", Android Keystore) und wird beim Ausschalten gelöscht; die Nutzerin erhält einmal einen **Wiederherstellungscode** und bestätigt, ihn aufbewahrt zu haben | MUSS | A |
| L-7.8 | Ablage in einem **einmal gewählten Ordner** über die Dateiauswahl des Systems (Security-Scoped Bookmark bzw. Storage Access Framework); kein voreingestellter Dienst, kein Konto, kein OAuth | MUSS | A |
| L-7.9 | Jede automatische Sicherung wird nach dem Schreiben zurückgelesen und entschlüsselt; erst dann gilt sie als erfolgreich. Zeitpunkt der letzten geprüften Sicherung und jeder Fehlschlag mit Grund sind sichtbar, auch auf der Übersicht. Funktion „Sicherung prüfen" ohne Wiederherstellung | MUSS | A |
| L-7.10 | **Aufbewahrung im Ordner:** letzte 7 Sicherungen, je Monat eine für 12 Monate, **je Kalenderjahr eine dauerhaft**; fremde Dateien im Ordner werden nie angefasst. Hinweis: die Sicherung ersetzt die gesetzliche Aufbewahrung nicht | MUSS | A |
| L-7.11 | Vorlage für die Verfahrensdokumentation (Abschnitt Datensicherung), die die Nutzerin ergänzt | SOLL | B |
| L-7.12 | **Kein Anbieterschlüssel:** Sicherungen sind ausschließlich mit Schlüsseln verschlüsselt, die die Nutzerin kontrolliert (Kennwort, Wiederherstellungscode); als Testinvariante abgesichert. Eine Verschlüsselung, die nur der Anbieter öffnen kann, ist ausgeschlossen (Prüfinstanzen: GoBD/BAO-Lesbarkeit, AGB-Recht, UWG; technisch ohne Server wirkungslos) | MUSS | A |
| L-7.13 | **Offenes Sicherungsformat:** das Format wird in der Spezifikation vollständig beschrieben, mit einem Referenzskript zum Entschlüsseln ohne die App | SOLL | B |
| L-7.14 | **Archivexport für die Finanzverwaltung:** alle Daten und Belege mit Beschreibungsdatei in maschinell auswertbarer Form (Datenzugriff Z3, § 147 Abs 6 AO; § 131 Abs 3 BAO), dauerhaft verfügbar – auch ohne Abo, nach Kündigung und im Nur-Lese-Modus (ergänzt L-10.4) | MUSS | B |
| L-7.15 | **Nur-Lese-Modus nach Abo-Ende** ohne zeitliche Begrenzung, mindestens über die längste Aufbewahrungsfrist: ansehen, drucken, exportieren, wiederherstellen; gesperrt sind nur neue Buchungen | MUSS | B |
| L-7.16 | **Hinterlegung (Escrow):** Quellcode und Formatbeschreibung bei einem Treuhänder bzw. Zusage der Offenlegung bei Einstellung des Produkts; Hinweis im Handbuch, wie die Daten ohne die App lesbar bleiben | SOLL | C |
| L-7.17 | **Umgesetzt 0.16.0 (FA-7.16).** **iOS: Sicherung standardmäßig in den App-eigenen iCloud-Drive-Container** (iCloud Documents, kein CloudKit); einmaliger Hinweis zu Ort, Verschlüsselung und Abschaltbarkeit; abschaltbar in den Einstellungen (Art. 25 DSGVO) | MUSS | A |
| L-7.18 | **Umgesetzt 0.16.0 (FA-7.16).** iCloud nicht verfügbar (abgemeldet, deaktiviert): Rückfall auf die Ordnerwahl, Zustand sichtbar | MUSS | A |
| L-7.19 | „Gesichert“ erst nach bestätigtem Hochladen; Speicher voll und Upload-Fehler als Warnung | MUSS | A |
| L-7.20 | iCloud-Ordner in der Dateien-App sichtbar (Portabilität, L-7.13). **Entscheidung der Auftraggeberin vom 2026-10-12: MUSS**; umgesetzt mit L-7.17 in 0.16.0 (Spezifikation FA-7.16) | MUSS | A |
| L-7.21 | Android: Ordnerwahl (Storage Access Framework) ist der Hauptweg, mit Google Drive auf Pixel 10 erfolgreich getestet. Drive-Schnittstelle nur als Ersatz und nur mit Scope `drive.file`; `drive.appdata` ausgeschlossen | MUSS | A |
| L-7.22 | **Keine Anmeldung mit Google- oder Apple-Konto** und kein Konto beim Anbieter (Entscheidung der Auftraggeberin 2026-10-12); eine Drive-Autorisierung dient nur dem Dateizugriff | MUSS | A |

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
| L-10.1 | **Zwei Tarife:** ein Abo **Basis** und als Option **Pro** mit zusätzlichen Funktionen, jeweils monatlich und jährlich über die App Stores. Keine weiteren Stufen, kein Gratis-Tarif auf Dauer | MUSS | B |
| L-10.2 | Premium-Funktionen sind **in Pro gebündelt**, nicht einzeln buchbar; Pro ist jederzeit zu- und abwählbar | MUSS | B |
| L-10.3 | **14 Tage gratis mit vollem Funktionsumfang (Pro)** – bei **jedem** gewählten Abo, auch Basis (O-42): die Kundin wählt Basis oder Pro im Store, die ersten 14 Tage des ersten Abos sind kostenlos und enthalten alle Pro-Funktionen, danach gilt das gewählte Abo. Vor dem Abschluss nennt die App Testdauer, Preis danach, automatische Verlängerung und Kündigungsweg über die Store-Einstellungen (Apple Guideline 3.1.2); Erinnerung 3 Tage vor Ablauf (Basis: „Noch X Tage Pro inklusive – danach Basis. Jetzt auf Pro wechseln?“). Umsetzung über die Einführungsangebote der Stores | MUSS | B |
| L-10.4 | **Bei abgelaufenem Abo bleiben die Daten des Nutzers lesbar und exportierbar.** Buchhaltungsdaten dürfen nie hinter einer Paywall verschwinden — sie unterliegen einer gesetzlichen Aufbewahrungspflicht | MUSS | B |
| L-10.5 | Lizenzprüfung funktioniert offline über einen angemessenen Zeitraum | MUSS | B |
| L-10.6 | **Demo ohne Abo** (O-42): beim ersten Start ohne Abo zwei Wege – „Abo wählen – 14 Tage kostenlos“ und „Erst ansehen (Demo)“. Die Demo zeigt eine erfundene Musterfirma mit allen Bereichen in einer eigenen, schreibgeschützten Datenbank, die nie mit echten Daten vermischt wird; speichern, senden, teilen, exportieren und sichern geht nicht, jedes PDF trägt „MUSTER – DEMO“; ein Band oben führt zum Abo. Nach dem Abo beginnt die Einrichtung leer; die Demo bleibt über die Einstellungen erreichbar | MUSS | B |

**Tarifschnitt (entschieden am 2026-10-10, O-4).** Basis ist alles, was eine
ordentliche Buchhaltung braucht; Pro ist Komfort und Wachstum.

| Basis | Pro (zusätzlich) |
|---|---|
| Rechnungen, Angebote, Zahlungserinnerungen erstellen, Gutschriften, Rücksendescheine; PDF speichern oder drucken; Logo wählen (ohne Druck) | Belegerkennung per Kamera (L-2); PDF und Mahnungen mit einem Tipp senden; Logo auf neuen Rechnungen und Angeboten |
| Kunden und Artikel | E-Rechnung **ausstellen** (L-4) |
| **E-Rechnung empfangen** (Datei am Beleg, L-4.3) | E-Rechnung auslesen; Kontoauszug-Import (L-18); Plattformimport (L-28); „Kurs abrufen“ |
| Belege fotografieren, Kassabuch | UVA-Übermittlung FinanzOnline/ELSTER (L-6.5) |
| Management-Übersicht, Kleinunternehmer-Ampel, OSS-Warnung | Einkommensteuer-Vorbereitung, Saldenliste, rollender Jahresabschluss |
| Export an die Steuerberatung | Shop-Anbindung (L-12), Marketing-Modul (L-14) |
| Datensicherung, Spracheingabe | Cloud-Synchronisierung über mehrere Geräte (S-8) |

**Preise (entschieden am 2026-10-10, O-3),** inklusive Umsatzsteuer:

| Tarif | Listenpreis/Monat | Rabattpreis/Monat | Jahresabo (20 % auf den Listenpreis) |
|---|---|---|---|
| Basis | 14,90 € | 12,90 € | 143,04 € rechnerisch, Store-Preisstufe ≈ 142,90 € |
| Pro | 24,90 € | 19,90 € | 239,04 € rechnerisch, Store-Preisstufe ≈ 238,90 € |

Rabatte laufen über die Angebotsmechanik der Stores (Einführungs- und
Aktionsangebote). Ein Rabattpreis darf **nur beworben werden, wenn der
Listenpreis vorher tatsächlich und für einen nennenswerten Zeitraum verlangt
wurde**; sonst heißt er „Einführungspreis bis [Datum]" mit echter Befristung
(Irreführungsverbot § 5 UWG DE, § 2 UWG AT). Ob die 30-Tage-Regel (§ 11 PAngV,
§ 9a PrAG) auf Abo-Dienstleistungen anwendbar ist, ist streitig — siehe
Spezifikation Abschnitt 14, P-R2.

Eine gesetzliche Pflicht darf nie nur in Pro erfüllbar sein. Wird eine Funktion
zur Pflicht für die Zielgruppe, wandert sie nach Basis. **Ausnahme nach
Entscheidung der Auftraggeberin 2026-10-16 (14a):** Anlagen und
Anlagenverzeichnis neu anlegen nur in Pro; bestehende bleiben in jedem Abo
zugänglich und ihre AfA läuft weiter (P-S64, P-R43).

### 5.11 Artikelverwaltung

Bewusst **kein Warenwirtschaftssystem**, sondern eine schlanke Artikelliste mit
einem Zweck: Rechnungen schneller und fehlerfreier schreiben, ohne Bezeichnung
und Preis jedes Mal neu zu tippen.

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-11.1 | Artikel anlegen mit **Artikelnummer, Bezeichnung, kurzer Beschreibung, Nettopreis, Einheit und Steuersatz** | MUSS | A |
| L-11.2 | Die Artikelnummer ist eindeutig; das Produkt verhindert Doppelvergabe | MUSS | A |
| L-11.3 | **Lagerstand** je Artikel erfassen und fortschreiben, für Nutzer mit physischen Produkten | MUSS | B |
| L-11.4 | Lagerstand ist optional: Dienstleister führen Artikel ohne Bestandsführung | MUSS | B |
| L-11.5 | Artikel beim Schreiben einer Rechnung auswählen; Bezeichnung, Preis und Steuersatz werden übernommen und bleiben in der Rechnung **änderbar** | MUSS | A |
| L-11.6 | **Freitextpositionen bleiben jederzeit möglich** — für Dienstleistungen, Sonderanfertigungen und einmalige Leistungen. Niemand wird gezwungen, vorher einen Artikel anzulegen | MUSS | A |
| L-11.7 | Beim Ausstellen einer Rechnung wird der Lagerstand der enthaltenen Artikel fortgeschrieben; bei Storno entsprechend zurück | SOLL | B |
| L-11.8 | Warnung bei Unterschreiten eines je Artikel hinterlegten Mindestbestands | KANN | B |
| L-11.9 | Artikel suchen und nach Artikelnummer oder Bezeichnung finden | MUSS | A |
| L-11.10 | Artikelliste importieren und exportieren (CSV), damit ein bestehender Bestand nicht abgetippt werden muss | SOLL | B |
| L-11.11 | Ein Artikel, der in einer gestellten Rechnung verwendet wurde, bleibt erhalten; Rechnungen dürfen ihre Positionen nicht verlieren | MUSS | A |
| L-11.12 | **Einkaufspreis als freiwilliges Feld** je Artikel; ist er gesetzt, zeigt die App den Rohertrag je Stück und je Rechnung in Alltagssprache („Bei der Kerze bleiben dir 4,20 € pro Stück"). Ohne Einkaufspreis erscheint nichts davon | SOLL | B |

### 5.12 Verkaufskanäle

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-12.1 | Anbindung an **Amazon Seller** zur Übernahme von Bestellungen und Rechnungen | SOLL | C |
| L-12.2 | Anbindung an **Shopify** | SOLL | C |
| L-12.3 | Anbindung an **Google Merchant Center** | KANN | C |
| L-12.4 | Übernommene Verkäufe erzeugen Buchungen in der Einnahmenseite, ohne dass der Nutzer sie abtippt | SOLL | C |
| L-12.5 | Doppelverbuchung ist ausgeschlossen: jeder Kanalvorgang wird eindeutig identifiziert und nur einmal übernommen | MUSS | C |
| L-12.6 | Retouren und Gutschriften aus den Kanälen werden ebenso übernommen wie Verkäufe | MUSS | C |
| L-12.7 | Kanalgebühren und Provisionen werden als Ausgaben erfasst, damit das Ergebnis stimmt | SOLL | C |
| L-12.8 | Der Nutzer sieht vor der Übernahme, was gebucht wird, und kann einzelne Vorgänge ausschließen | MUSS | C |
| L-12.9 | Die Anbindung arbeitet **ausschließlich lesend**: Bestellungen und Rechnungen werden übernommen. **Lagerstände und Artikel werden nicht in die Kanäle zurückgeschrieben** — die dafür nötige Konfliktauflösung und das Überverkaufsrisiko stehen in keinem Verhältnis zum Nutzen | MUSS | C |
| L-12.10 | Der in L-11.3 geführte Lagerstand ist bewusst **einkanalig** und wird von der Kanalanbindung nicht verändert | MUSS | C |

> **Architektonische Folge:** Kanalanbindungen brauchen dauerhaft gültige
> Zugangstoken, Webhooks und zeitgesteuerte Abgleiche. Ein Telefon kann das nicht
> leisten — es ist offline, der Akku leer, oder das Betriebssystem beendet den
> Hintergrundprozess. Damit wird das **eigene Backend (S-8) zur Voraussetzung**
> dieses Blocks und rückt aus der Kür in die Pflicht der Stufe C. Die
> Buchhaltungsdaten bleiben weiterhin lokal; die Kanaldaten laufen über den Server.

### 5.13 Märkte und Erweiterbarkeit

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-13.1 | **Währung ist der Euro.** Eine Rechnungswährung mit Kursumrechnung ist nicht vorgesehen | MUSS | A |
| L-13.2 | Beträge werden ganzzahlig in Cent geführt. Das Datenmodell ist so anzulegen, dass eine zweite Währung später ergänzbar bleibt, ohne bestehende Daten umzubauen | MUSS | A |
| L-13.3 | Ausgangsrechnungen bleiben in Euro; Fremdwährung nur bei Eingangsbelegen (L-2.24). **Umgesetzt** | MUSS | A |
| L-13.3 | Ein **weiterer EU-Markt muss überwiegend Konfiguration sein**: Steuersätze, Grenzwerte, Kleinbetragsgrenzen, Pflichtangaben, Fristen, Zahlenformat und Rechtsverweise liegen an genau einer Stelle | MUSS | A |
| L-13.4 | **Zahlen- und Datumsformat je Markt**, auch innerhalb der Eurozone unterschiedlich | MUSS | A |
| L-13.5 | **Zeitlich gestaffelte Steuersätze.** Ein Steuersatz gilt nicht einfach, er gilt *ab einem Datum*. Befristete Satzänderungen hat es in beiden Zielmärkten bereits gegeben; eine Rechnung aus dem Vorjahr muss mit dem damals gültigen Satz darstellbar bleiben | MUSS | B |
| L-13.6 | **Landessprache je Markt:** Start nur auf Deutsch; mit jedem weiteren EU-Land kommt dessen Landessprache hinzu (O-7) | SOLL | C |
| L-13.8 | **Texte von Anfang an übersetzbar anlegen:** alle Oberflächentexte liegen in Sprachdateien (Flutter-Lokalisierung), nicht im Code. Eine neue Landessprache ist dann Übersetzung, kein Umbau | MUSS | A |
| L-13.7 | **OSS-Verfahren** für grenzüberschreitende Verkäufe an EU-Privatkunden oberhalb der Lieferschwelle — Voraussetzung für die Kanalanbindung (L-12), siehe R-10. **Je nach Nachfrage (O-12)** | KANN | C |
| L-13.9 | **OSS-Warnung:** Rechnungen an Privatkundinnen in anderen EU-Ländern (Fernverkäufe und elektronische Dienstleistungen) werden erkannt und summiert; maßgeblich sind **Vorjahr und laufendes Jahr**. Ab 80 % der EU-weiten Schwelle von 10.000 € (Art. 59c MwStSystRL, § 3c UStG DE, Art. 3 Abs 5 UStG AT) warnt die App und rät, die Steuerberatung einzubinden. Keine Berechnung ausländischer Steuersätze | MUSS | B |

> **Warum die Beschränkung auf EU und Euro trägt.** Die Länderabstraktion
> unterstellt heute ein gemeinsames Mehrwertsteuersystem. Innerhalb der Eurozone
> ist das richtig und ein weiterer Markt kostet Tage statt Wochen. Sobald ein Land
> außerhalb dazukommt, bricht die Annahme — und zwar an jeder Stelle gleichzeitig:
> Währung, Steuersystematik, Rechnungsrecht, Datenschutzrecht. Diese Grenze
> bewusst zu ziehen ist der Grund, warum L-13.3 überhaupt erfüllbar ist.

### 5.14 Marketing-Modul (Premium)

Das Produkt kennt Unternehmensprofil, Artikel, Rechnungen und Geschäftsverlauf.
Daraus lassen sich zielgerichtete Werbemittel erzeugen — LinkedIn- und
Instagram-Beiträge, Banner, Broschüren.

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-14.1 | Erzeugen von **Textbeiträgen** für LinkedIn und Instagram auf Basis von Unternehmensprofil und Artikelstamm | SOLL | C |
| L-14.2 | Erzeugen von **Bildmitteln**: Banner, Produktgrafiken, einfache Broschüren | SOLL | C |
| L-14.3 | Vorschläge berücksichtigen den Geschäftsverlauf — etwa meistverkaufte Artikel oder saisonale Muster | KANN | C |
| L-14.4 | **Kein Werbemittel wird ohne ausdrückliche Freigabe des Nutzers veröffentlicht oder versendet.** Jeder Entwurf ist vor der Verwendung bearbeitbar | MUSS | C |
| L-14.5 | **Es verlassen ausschließlich Unternehmens- und Artikeldaten das Gerät.** Kundennamen, Kundenanschriften, einzelne Rechnungen und Belegfotos werden **niemals** an einen Dienst zur Inhaltserzeugung übertragen; Geschäftsverlauf fließt nur aggregiert ein | MUSS | C |
| L-14.6 | Das Modul ist **standardmäßig aus** und wird einzeln aktiviert; beim Einschalten wird benannt, welche Daten an wen übertragen werden | MUSS | C |
| L-14.7 | **Zunächst nur Export**: der Nutzer erhält Text und Bild und veröffentlicht selbst. Direktes Veröffentlichen auf den Plattformen erst, wenn der Nutzen belegt ist | MUSS | C |
| L-14.8 | Erzeugte Inhalte sind als werblich erkennbar und enthalten **keine Preis-, Wirkungs- oder Vergleichsaussagen**, die der Nutzer nicht selbst gesetzt hat | MUSS | C |
| L-14.9 | Die Herkunft verwendeter Bildbestandteile ist geklärt und für kommerzielle Nutzung lizenziert | MUSS | C |
| L-14.10 | Direktes Veröffentlichen über die Plattform-Schnittstellen | KANN | C |

> **Was dieses Modul kostet, das nicht in Personenwochen steht.** Es ist das erste
> Modul, das Geschäftsdaten zur Verarbeitung an einen Dritten gibt. Damit wird der
> Anbieter zum Auftragsverarbeiter, es braucht einen Vertrag nach Art. 28 DSGVO,
> und die Zusage „keine Datenübertragung" in den Store-Angaben ist für Nutzer
> dieses Moduls nicht mehr haltbar. L-14.5 zieht deshalb eine harte Grenze:
> **Kundendaten bleiben auf dem Gerät.** Was ein Werbetext über das Unternehmen und
> seine Produkte sagen kann, braucht keinen einzigen Kundennamen.

### 5.15 E-Mail-Anbindung

**Entscheidung vom 2026-10-09 (O-18): Es gibt keine Postfach-Anbindung.**
Rechnungen werden ausschließlich über die Mail-App des Smartphones versendet
(L-15.1); die App greift weder schreibend noch lesend auf Gmail oder Microsoft 365
zu. Damit entfallen Anbieterprüfungen, Herausgeberverifizierung und
Auftragsverarbeitung für Postfachdaten. Belege kommen über den Teilen-Dialog
herein (L-15.2). Die Erläuterung unten bleibt als Begründung stehen.

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-15.1 | Eine Rechnung lässt sich aus der App heraus per E-Mail versenden: die App öffnet die Mail-App des Smartphones mit PDF im Anhang, Empfänger aus dem Kundenstamm (L-3.19) und vorbereitetem Text; gesendet wird von der Nutzerin selbst | MUSS | A |
| L-15.2 | **Die App ist Ziel des Teilen-Dialogs:** ein PDF oder eine E-Rechnung aus der Mail-App wird per „Teilen" direkt als Beleg übernommen | MUSS | B |
| L-15.3 | **Eigene Beleg-Eingangsadresse:** der Nutzer leitet Rechnungen an eine persönliche Adresse weiter, Anhänge werden automatisch zu Belegentwürfen | SOLL | C |
| ~~L-15.4~~ | **Entfällt (O-18, 2026-10-09).** Ursprünglich: **Versand über das eigene Postfach** des Nutzers (Gmail bzw. Microsoft Outlook), damit die Rechnung im gesendeten Ordner liegt und vom Empfänger als von ihm kommend erkannt wird | — | — |
| ~~L-15.5~~ | **Entfällt (O-18, 2026-10-09).** Ursprünglich: **Abholen aus dem Postfach:** eingehende Rechnungen und E-Rechnungen werden erkannt und als Belegentwürfe vorgeschlagen | — | — |
| ~~L-15.6~~ | **Entfällt (O-18, 2026-10-09).** Ursprünglich: **Zugriff nur auf einen abgegrenzten Bereich.** Wird L-15.5 umgesetzt, liest das Produkt ausschließlich ein vom Nutzer bestimmtes Label bzw. einen Ordner — niemals das gesamte Postfach | — | — |
| ~~L-15.7~~ | **Entfällt (O-18, 2026-10-09).** Ursprünglich: Jeder übernommene Beleg wird dem Nutzer **zur Bestätigung vorgelegt**, nie ungeprüft gebucht | — | — |
| ~~L-15.8~~ | **Entfällt (O-18, 2026-10-09).** Ursprünglich: Die Anbindung ist je Postfach einzeln zu aktivieren und jederzeit widerrufbar; beim Einschalten wird benannt, worauf zugegriffen wird | — | — |
| ~~L-15.9~~ | **Entfällt (O-18, 2026-10-09).** Ursprünglich: **E-Mail-Inhalte werden nicht gespeichert**, außer dem Anhang, der zum Beleg wird | — | — |

> **Warum Senden billig und Lesen teuer ist.** Technisch ist beides über die
> vorhandenen Schnittstellen möglich — die Annahme stimmt. Der Aufwand liegt
> jedoch nicht im Programmieren, sondern in den Auflagen der Anbieter, und die
> unterscheiden sich erheblich:
>
> **Senden** nutzt bei Google den Bereich `gmail.send`, der als *sensitiv* gilt:
> einmalige Überprüfung, keine laufenden Kosten. Microsoft verlangt für
> `Mail.Send` eine Herausgeberverifizierung über eine selbst kontrollierte Domain.
> Beides ist überschaubar.
>
> **Lesen** nutzt bei Google `gmail.readonly` und fällt damit unter die
> *eingeschränkten* Bereiche. Dafür verlangt Google eine **jährlich zu
> wiederholende Sicherheitsüberprüfung (CASA)** durch ein zugelassenes Labor.
> Die Angaben zu den Kosten schwanken je nach Quelle und Prüftiefe zwischen rund
> 500 und 5.000 US-Dollar pro Jahr, die Dauer zwischen vier und acht Wochen.
> Google legt die Prüftiefe fest, nicht der Entwickler. Microsoft ist hier
> deutlich zurückhaltender und kennt keine gleichwertige jährliche Pflichtprüfung.
>
> **Konsequenz für den Zuschnitt:** L-15.2 und L-15.3 liefern den Großteil des
> Nutzens ohne jede Anbieterprüfung — der Nutzer teilt oder leitet weiter, statt
> der App sein Postfach zu öffnen. Der direkte Postfachzugriff (L-15.5) steht
> deshalb bewusst als KANN am Ende der Kette, und zwar erst dann, wenn er sich
> gegen wiederkehrende vierstellige Kosten rechnet.
>
> Alle Angaben zu Prüfverfahren und Kosten stammen aus Sekundärquellen und sind
> vor einer Umsetzung gegen die Angaben von Google und Microsoft zu prüfen.

### 5.16 Datenübernahme beim Einstieg

Kaum ein Nutzer beginnt am 1. Jänner bei null. Er wechselt mitten im Jahr von
Excel, einer anderen App oder vom Schuhkarton — und bringt eine Vorgeschichte
mit, an die er anknüpfen muss.

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-16.1 | Beim Anlegen des Profils werden **Eröffnungswerte** erfasst: Umsatz des Vorjahres, Umsatz des laufenden Jahres bis zum Einstiegsdatum, offene Forderungen, offene Verbindlichkeiten, Kassen- und Bankbestand | MUSS | A |
| L-16.2 | Der **Vorjahresumsatz ist Pflichtangabe**, solange die Kleinunternehmerregelung aktiv ist. Ohne ihn ist die Grenzwertüberwachung wertlos oder — schlimmer — falsch beruhigend | MUSS | A |
| L-16.3 | Der **Rechnungsnummernkreis knüpft an den bestehenden Stand an**: wer aus einer Vorsoftware mit `RE-2026-0087` kommt, darf nicht wieder bei `0001` beginnen | MUSS | A |
| L-16.4 | **Anlagevermögen übernehmen** mit Anschaffungsdatum, Anschaffungskosten, Nutzungsdauer und Restbuchwert, damit die Abschreibung fortgeführt werden kann | SOLL | B |
| L-16.5 | **Belege und Buchungen importieren** aus CSV sowie aus DATEV- und BMD-Formaten der Vorsoftware | SOLL | B |
| L-16.6 | Jeder Import läuft über eine **Vorschau mit Spaltenzuordnung**; nichts wird ungeprüft übernommen | MUSS | B |
| L-16.7 | Importe sind als **Stapel gekennzeichnet und als Ganzes zurücknehmbar**, solange nichts darauf aufbaut | MUSS | B |
| L-16.8 | **Dubletten werden erkannt**, damit ein zweimal ausgeführter Import die Buchhaltung nicht verdoppelt | MUSS | B |
| L-16.9 | **Offene Rechnungen aus der Vorsoftware** werden als offene Posten übernommen, ohne den eigenen Nummernkreis zu belasten | SOLL | B |
| L-16.10 | **Altunterlagen als PDF archivieren**: Jahresabschlüsse, Steuerbescheide, Saldenlisten der Vorjahre liegen durchsuchbar beim Unternehmen, ohne maschinell ausgewertet zu werden | SOLL | B |
| L-16.12 | **Ausgangsrechnungen der Vorsoftware importieren** (CSV, PDF als Anhang): sie zählen zu Umsatz und Auswertung, behalten ihre Fremdnummer und belasten den eigenen Nummernkreis nicht | SOLL | B |
| L-16.11 | Das Produkt macht transparent, **ab welchem Datum seine Zahlen vollständig sind** — davor übernommene Eröffnungswerte, danach eigene Erfassung | MUSS | A |

> **Warum das keine Komfortfunktion ist.** Die Grenzwertüberwachung rechnet den
> Vorjahresumsatz heute aus den erfassten Belegen. Ein Nutzer, der die App im
> Oktober installiert, hat keine Belege aus dem Vorjahr — die Summe ist null, und
> die Ampel steht auf Grün, auch wenn er die Grenze längst gerissen hat. In
> Deutschland entscheidet der Vorjahresumsatz über das ganze laufende Jahr. Ohne
> L-16.1 und L-16.2 gibt das Produkt also eine falsche Entwarnung. Siehe O-19.
>
> **Was nicht geht, und zwar grundsätzlich:** einen beliebigen Jahresabschluss als
> PDF einlesen und daraus Buchungen gewinnen. Solche Dokumente haben kein
> einheitliches Format. L-16.10 legt sie deshalb bewusst nur ab; die wenigen
> Zahlen, die wirklich weitergetragen werden müssen, erfasst der Nutzer geführt
> über L-16.1.

### 5.17 Rechtlicher Rahmen und Haftungsabgrenzung

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-17.1 | Bei der **ersten Einrichtung** der App — ab Stufe C bei der Anlage des Nutzerkontos — **bestätigt der Nutzer ausdrücklich**, dass das Produkt Informationen bereitstellt, sie aber **nicht steuerrechtlich validiert**, und dass die Prüfung durch eine Steuerberatung erforderlich bleibt | MUSS | A |
| L-17.2 | Diese Bestätigung ist **von den AGB getrennt**, eigenständig, nicht vorausgewählt und nicht überspringbar | MUSS | A |
| L-17.3 | Die Bestätigung wird mit **Zeitstempel und Fassung des Textes nachweisbar** gespeichert — ohne Konto lokal auf dem Gerät und in jeder Sicherung enthalten, mit Konto zusätzlich beim Anbieter | MUSS | A |
| L-17.4 | Ändert sich der Text wesentlich, wird die Bestätigung **erneut eingeholt** | MUSS | A |
| L-17.5 | Der Hinweis erscheint zusätzlich **dort, wo er zählt**: vor dem Export an die Steuerberatung, bei der Vorbereitung von Meldungen und Steuererklärungen, beim Jahresabschluss | MUSS | A |
| L-17.6 | **Erzeugte Auswertungen und Meldungsvorbereitungen tragen den Hinweis im Dokument selbst** — nicht nur auf dem Bildschirm, auf dem sie entstanden sind | MUSS | A |
| L-17.7 | Das Produkt gibt **keine individuelle steuerliche Beratung**. Hinweise sind allgemeine Erläuterungen mit Angabe der Fundstelle, nie eine Empfehlung für den Einzelfall | MUSS | A |
| L-17.8 | Das Produkt bezeichnet sich **nirgends als geprüfte, zertifizierte oder validierte Steuersoftware**; es ist ein Werkzeug für das eigene Büro | MUSS | A |
| L-17.9 | **Pflichten als Anbieter nach DSGVO**: Verzeichnis der Verarbeitungstätigkeiten, Auftragsverarbeitungsverträge mit allen Unterauftragnehmern, technische und organisatorische Maßnahmen, Auskunfts- und Löschkonzept, Meldewege bei Datenschutzverletzungen | MUSS | B |
| L-17.10 | **Pflichtangaben als kommerzieller Anbieter**: Impressum, AGB, Widerrufsbelehrung, Preisangaben, Hinweise zur Vertragslaufzeit und Kündigung | MUSS | B |
| L-17.12 | **Produktseite** auf eigener Domain (Name folgt mit dem Produktnamen, O-2): eine einfache Einzelseite mit Links zu Google Play und App Store. Mindestinhalt: Impressum (§ 5 ECG, § 25 MedienG AT bzw. § 5 DDG DE), Datenschutzerklärung (Art. 13 DSGVO) mit eigener URL für beide Stores, Support-E-Mail, ab Stufe C Anleitung und Link zur Kontolöschung (Vorgabe von Google Play und Apple Guideline 5.1.1(v)), Hinweis auf Verbraucherschlichtung, Hinweis „keine Steuerberatung" (L-17.8). Ohne Tracking und ohne Cookies, damit kein Einwilligungsbanner nötig ist | MUSS | A |
| L-17.11 | Alle Rechtstexte werden **von einer Rechtsanwältin oder einem Rechtsanwalt erstellt oder geprüft**, nicht aus Vorlagen zusammengesetzt | MUSS | B |

> **Was der Hinweis leistet — und was nicht.** Die Abgrenzung trifft eine reale
> Rechtsgrenze: Hilfeleistung in Steuersachen ist in Deutschland nach dem
> Steuerberatungsgesetz und in Österreich nach dem WTBG den Berufsberechtigten
> vorbehalten. Eine Software, die rechnet, Formulare vorbereitet und Fundstellen
> nennt, bleibt diesseits dieser Grenze. Eine Software, die dem einzelnen Nutzer
> sagt, was er tun soll, überschreitet sie. L-17.7 zieht genau diese Linie.
>
> **Die Grenze des Hinweises:** Er deckt die *steuerliche Würdigung* ab, nicht die
> *Fehlerfreiheit der Software*. Rechnet das Produkt die Umsatzsteuer falsch,
> hilft kein Bestätigungshaken — dafür haftet der Anbieter. Haftungsabgrenzung und
> Testdisziplin sind deshalb keine Alternativen, sondern zwei Hälften derselben
> Sache. Das ist der Grund, warum NFA-3 jede steuerwirksame Berechnung unter
> Testpflicht stellt.

### 5.18 Kontoumsätze

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-18.1 | **Import von Kontoauszügen als Datei** (CSV und CAMT.053), die der Nutzer aus seinem Onlinebanking herunterlädt. Kein Bankzugang, kein Server, das Offline-Prinzip bleibt ungebrochen | MUSS | B |
| L-18.2 | Importierte Umsätze werden **Belegen und Rechnungen zugeordnet**; Vorschläge nach Betrag, Datum und Verwendungszweck, Bestätigung durch den Nutzer | MUSS | B |
| L-18.3 | Eine Zahlung zu einer offenen Rechnung setzt diese auf *bezahlt* | SOLL | B |
| L-18.4 | Umsätze ohne Beleg werden als offene Punkte sichtbar — die häufigste Lücke vor dem Jahresabschluss | MUSS | B |
| L-18.5 | Wiederholter Import desselben Auszugs erzeugt keine Dubletten | MUSS | B |
| L-18.6 | **Live-Bankanbindung** über einen lizenzierten Kontoinformationsdienst (PSD2) — später, als ausdrücklich einzuschaltende Ausnahme vom Offline-Prinzip | KANN | C |

> **Entscheidung vom 2026-10-09:** Start mit Datei-Import. Gegenüber deutschen
> Suiten, die eine Live-Anbindung schon im Einstiegstarif haben, ist das
> umständlicher — dafür bleibt das Datenschutzversprechen vollständig intakt, und
> es braucht keinen Server. L-18.6 hält die Tür für später offen.

### 5.19 Datenschutz

Bündelt, was bisher über die Module verteilt war, und legt die Rollen fest.

#### Nutzerkonto und Mehrgerätebetrieb

**Entscheidung vom 2026-10-10 (O-29):** Es gibt **keinen Server des Anbieters**,
auch nicht für die Synchronisierung. Mehrere Geräte einer Person und mehrere
Personen eines Unternehmens arbeiten über einen **Ordner in der Cloud der
Unternehmerin** zusammen. Damit entfällt das Nutzerkonto beim Anbieter ganz.
Ausgearbeitet mit den drei Prüfinstanzen.

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-19.1 | **Stufe A und B kommen ohne Nutzerkonto aus.** Das Abonnement läuft über den Kauf im App Store bzw. bei Google Play; die Lizenz hängt am Store-Konto, nicht an einem Konto beim Anbieter | MUSS | A |
| L-19.2 | **Kein Nutzerkonto beim Anbieter**, auch nicht in Stufe C. Geräte und Personen werden über einen gemeinsamen Cloud-Ordner und Schlüssel verbunden (L-19.15 ff.) | MUSS | C |
| L-19.3 | Die App bleibt ohne Synchronisierung voll nutzbar; der Mehrgerätebetrieb ist Opt-in | MUSS | C |
| L-19.12 | **Mehrere Geräte und Personen arbeiten parallel**; Änderungen werden synchronisiert, Konflikte erkannt und nie stillschweigend überschrieben. Gestellte Rechnungen und Stornos sind unveränderlich und werden nur angehängt. **Rechnungsnummern sind über alle Geräte eindeutig und je Nummernkreis fortlaufend:** jedes Gerät bzw. jede ausstellende Person hat einen eigenen Kreis mit festem Präfix (z. B. `2026-A-0001`), das nie wiederverwendet wird (UStAE 14.5 Abs 10; UStR Rz 1565). Alternativ ein einziges Ausstellgerät | MUSS | C |
| L-19.13 | **Wiederherstellung ohne Server:** Zugang zu den Daten auf einem neuen Gerät über den Wiederherstellungscode (L-7.7) oder die Freigabe durch ein bereits verbundenes Gerät; kein Passwort-Reset per E-Mail | MUSS | C |
| L-19.14 | ~~Zwei-Faktor-Anmeldung~~ entfällt mit L-19.2 (kein Konto). Schutz der Daten über Geräteschlüssel, Gerätesperre und die Bestätigung jedes neuen Geräts per QR-Code (L-19.18) | — | — |
| L-19.4 | ~~Kontodaten~~ entfällt mit L-19.2; es werden keine Kontodaten erhoben | — | — |
| L-19.15 | **Synchronisierung über ein Änderungsjournal je Gerät** im gemeinsamen Ordner: jedes Gerät schreibt nur eigene, einmal geschriebene Dateien (verschlüsselt, signiert); kein gemeinsames Bearbeiten einer Datenbankdatei. Zusammenführen deterministisch je Feld nach Zeitstempel (Hybrid Logical Clock); Belegfotos inhaltsadressiert. IDs geräteübergreifend als UUID | MUSS | C |
| L-19.16 | **Konfliktliste:** gleichzeitige Änderungen desselben Felds, Bearbeiten gegen Löschen, doppeltes Storno erscheinen mit beiden Fassungen, Person und Zeit; die verworfene Fassung bleibt im Protokoll. Gestellte Rechnungen haben nie Konflikte – tritt doch einer auf, ist es ein gemeldeter Integritätsfehler | MUSS | C |
| L-19.17 | **Präfix-Register der Nummernkreise** (Präfix, Person, Gerät, angelegt, stillgelegt), vergeben von der Inhaberin; Doppelvergabe oder ein auf zwei Geräten aktives Präfix wird beim Abgleich erkannt, gemeldet und über Storno und Neuausstellung korrigiert – nie automatisch umnummeriert. Lückenbericht je Kreis, exportierbar | MUSS | C |
| L-19.18 | **Einladen per QR-Code:** gemeinsamer Datenschlüssel, je Gerät bzw. Person mit deren Schlüsselpaar (X25519) eingewickelt; das neue Gerät wird auf dem Gerät der Inhaberin mit Fingerabdruck bestätigt. Kein Anbieter-Server, auch nicht für Einladung, Schlüsseltausch oder Push | MUSS | C |
| L-19.19 | **Nachvollziehbarkeit:** jeder Eintrag trägt Person, Gerät, Rolle und Zeitstempel (UTC) und ist je Gerät signiert (Ed25519); Einträge mit ungültiger Signatur werden verworfen und gemeldet. **Keine Auswertung je Person** (keine Statistik, kein Ranking, keine Aktivitätsübersicht) | MUSS | C |
| L-19.20 | **Rollen:** Inhaberin (alles, Zugänge, Nummernkreise), Mitarbeiterin mit Fakturierung (eigener Nummernkreis, keine Stammdaten, keine Meldungen), Mitarbeiterin Erfassung (Belege, Entwürfe), Steuerberatung (lesen, exportieren). Die Rollenliste ist von der Inhaberin signiert und wird beim Zusammenführen auf jedem Gerät geprüft. Die App sagt offen: ohne Server ist das kein harter Zugriffsschutz | MUSS | C |
| L-19.21 | **Hinweis für Beschäftigte** (Art. 13 DSGVO) beim Einladen, von der Mitarbeiterin vor dem ersten Eintrag bestätigt; mit Hinweis auf Betriebsrat (§ 87 Abs 1 Nr 6 BetrVG) bzw. § 96/96a ArbVG, § 10 AVRAG | MUSS | C |
| L-19.22 | **Zugang entziehen** in einem Schritt: Mitgliederliste ändern, Schlüssel wechseln, Kennung als „ausgeschieden" markieren, nicht löschen. Die App erklärt die Grenzen: bereits übertragene Daten bleiben auf dem Gerät der Person lesbar; die Cloud-Freigabe entzieht die Inhaberin selbst; Löschbestätigung arbeitsrechtlich einfordern | MUSS | C |
| L-19.23 | Warnung, wenn der Ordner an ein offensichtlich privates Konto freigegeben wird; Empfehlung eines Geschäftskontos | SOLL | C |
| L-19.24 | **Synchronisierung ist keine Sicherung:** die automatische Sicherung (L-7) bleibt getrennt, mit eigenem Ordner und Schlüssel | MUSS | C |
| L-19.25 | Gemischte Teams aus iOS und Android brauchen einen Cloud-Dienst, den beide Systeme als Ordner anbieten; die App benennt das beim Einrichten | MUSS | C |
| L-19.26 | **Vorlage der Verfahrensdokumentation** aus den Einstellungen: Berechtigungskonzept, Nummernkreise, Synchronisationsverfahren, Ablageort, Datensicherung, Ablauf beim Ausscheiden (ergänzt L-7.11) | SOLL | C |
| L-19.27 | Sicherungsschlüssel und Wiederherstellungscode werden nie über den iCloud-Schlüsselbund synchronisiert (`synchronizable: false`, `first_unlock_this_device`); Regressionstest | MUSS | A |
| L-19.28 | **iCloud eingetragen 0.16.0** (Tabelle unten, PRIVACY.md, STORE_LISTING); Drive-Schnittstelle offen. Datenflusstabelle, PRIVACY.md und STORE_LISTING um iCloud (iOS) und gegebenenfalls Drive-Schnittstelle ergänzen, sobald umgesetzt | MUSS | A |
| L-19.29 | Kursabruf bei der EZB nur auf Aktion der Nutzerin, mit Eintrag in Datenflusstabelle, PRIVACY.md und STORE_LISTING; manueller Kurs immer möglich; Quellenhinweis „EZB-Referenzkurs, ohne Gewähr“. **Umgesetzt** (FA-2.25) | MUSS | A |

#### Rollen

| Datenkategorie | Verantwortlicher | Anbieter ist |
|---|---|---|
| Buchhaltungsdaten am Gerät (Belege, Rechnungen, Kunden) | **der Nutzer** — er erfasst Daten seiner Kunden | nicht beteiligt; liefert nur Software |
| Synchronisierte Buchhaltungsdaten (Stufe C) | **die Unternehmerin**; Cloud-Dienst (Apple/Google …) ist ihr Auftragsverarbeiter nach dessen Bedingungen | **nicht beteiligt**: kein Server, kein Schlüssel, kein Zugriff (EuGH C-683/21) |
| Beschäftigte der Unternehmerin | handeln auf ihre Weisung (Art. 29 DSGVO), keine Dritten | nicht beteiligt |
| Daten an Marketing-Dienste (L-14) | der Nutzer | Auftragsverarbeiter mit Unterauftragnehmer |
| Abo-, Support- und Diagnosedaten | **der Anbieter** | Verantwortlicher; eigenes Verzeichnis, Datenschutzerklärung nach Art. 13 |
| Kaufabwicklung im Store | Apple bzw. Google | nicht beteiligt; Stores sind eigene Verantwortliche |

Ende-zu-Ende-Verschlüsselung hebt die Rolle als Auftragsverarbeiter nicht auf:
verschlüsselte personenbezogene Daten bleiben personenbezogen.

#### Datenflüsse

Jede Übertragung vom Gerät weg, auch die unscheinbaren:

| Datenfluss | Empfänger | Was | Ausgelöst durch | Opt-in | Stufe |
|---|---|---|---|---|---|
| Rechnung/Export teilen | vom Nutzer gewählt | PDF, CSV | Tippen auf Teilen | je Vorgang | vorhanden |
| Sicherung von Hand (L-7.1) | vom Nutzer gewählt (Teilen-Dialog) | mit Kennwort verschlüsselte Vollsicherung samt Fotos | Tippen auf „Sicherung erstellen“ | je Vorgang | vorhanden |
| Sicherung automatisch (L-7.2, L-7.6 ff.) | einmal gewählter Ordner, z. B. iCloud Drive oder Google Drive; Upload durch das Betriebssystem bzw. den Dokumentanbieter | mit Schlüssel verschlüsselte Vollsicherung samt Fotos | nach jeder Änderung höchstens täglich, beim Öffnen der App | **ja**, standardmäßig aus | vorhanden |
| iCloud-Sicherung, nur iOS (L-7.17 bis L-7.20) | Apple (iCloud Drive der Nutzerin, App-eigener Container „JeNi bucht“); Apple ist aus Sicht der Nutzerin Auftragsverarbeiter, Server auch außerhalb der EU | mit Schlüssel verschlüsselte Vollsicherung samt Fotos; Apple sieht nur Dateiname, Größe, Zeitpunkt; Schlüssel nie im iCloud-Schlüsselbund (L-19.27) | nach jeder Änderung höchstens täglich, beim Öffnen der App | **ja**, standardmäßig aus; Ziel bei „Einrichten“, wenn iCloud verfügbar | vorhanden (0.16.0) |
| Diagnose der Belegerkennung, nur Android (L-2.20, L-27.1) | Google (Google ML Kit Texterkennung und Barcode-Erkennung, beide gebündelt in der App) | Nutzungs- und Diagnosedaten der Bibliotheken (z. B. Gerätetyp, Leistung, Fehler); **keine Bilder, kein erkannter Text** | Nutzung der Belegerkennung | nein, kein offizielles Abschalten; Erkennung insgesamt abschaltbar (L-2.23). Prüfung P-R19, P-D21 | vorhanden |
| Dokumentenscanner, nur Android (Spezifikation FA-2.51) | Google (Google Play-Dienste: Download von Modell und Oberfläche des ML Kit Document Scanners) | Nutzungs- und Diagnosedaten der Play-Dienste; **keine Bilder** (Verarbeitung auf dem Gerät) | Tippen auf „Beleg fotografieren“ bzw. „Seiten scannen“ | nein; ohne Play-Dienste automatisch Kamera. Prüfung P-R42 | vorhanden (0.20.0) |
| Diktat (Spezifikation FA-2.61) | **keiner durch die App**: Audio verarbeitet nur der Spracherkennungsdienst des Systems auf dem Gerät (Android On-Device-Erkenner, iOS `requiresOnDeviceRecognition`); ohne Erkennung auf dem Gerät gibt es kein Diktat in der App, kein Rückfall ins Netz | – (Mikrofon nur während der Aufnahme) | Tippen auf das Mikrofon | je Vorgang | vorhanden |
| Wunsch oder Idee senden (L-26.7, Spezifikation FA-11.6) | **keiner durch die App**: die Nutzerin sendet selbst aus ihrer Mail-App an den Anbieter (office@jenibarb.com); der Anbieter ist für die E-Mail Verantwortlicher (Rolle „Support“) | Inhalt von der Nutzerin gewählt und vor dem Senden sichtbar: Art, Titel, Beschreibung; optional (Standard an) App-Version, Betriebssystem, Gerätemodell, Länderprofil, Abo-Stufe; nie Geschäftsdaten, Belege, Kennungen | Tippen auf „Per E-Mail senden“ und Absenden in der Mail-App | je Vorgang | vorhanden (0.22.2) |
| Mithelfer-Geräte (L-29.4, Spezifikation FA-17.4) | **keiner durch die App direkt**: der Mithelfer übergibt das Belegpaket über das Teilen-Blatt an einen Messenger bzw. eine Mail-App seiner Wahl, oder die App schreibt es in einen Cloud-Ordner des Betriebs, den beide Geräte gewählt haben (Upload durch Betriebssystem bzw. Dokumentanbieter). Messenger- bzw. Cloud-Anbieter sehen nur Chiffrat, Dateiname, Größe, Zeitpunkt | Belegbilder und Werte eines Belegs (Betrag, Lieferant, Datum, Kategorie, Beschreibung, Kommentar), Ende-zu-Ende verschlüsselt (AES-256-GCM) | Tippen auf „Senden“ | je Vorgang bzw. Wahl des Ordners | vorhanden (0.23.0) |
| Mailweg Mithelfer → SMTP (L-29.10, Spezifikation FA-17.10) | **Mailanbieter des Mithelfers** (sein eigenes Postfach, z. B. Google, Apple, A1) und Mailanbieter der Empfangsadresse; sehen Absender, Empfänger, Betreff `[JeNi-Beleg] ‹Kopplungs-ID›-‹Datum›-‹Nr›`, Zeitpunkt, Größe und das Chiffrat | Sammelpaket mit Belegbildern und Werten, Ende-zu-Ende verschlüsselt (AES-256-GCM); Anmeldename und Kennwort/App-Passwort des Mithelfers gehen nur an seinen SMTP-Server (TLS) | Einrichtung „Mit deinem E-Mail-Konto senden“ (einmalige Zustimmung), danach automatisch | einmal am Tag im Hintergrund und bei jedem Öffnen der App | vorhanden (0.24.0) |
| Mailweg Hauptgerät ← IMAP (L-29.10, Spezifikation FA-17.9, FA-17.11) | **Mailanbieter der Empfangsadresse** des Betriebs (Geschäfts-E-Mail oder eigene Adresse) | Anmeldename und Kennwort/App-Passwort (nur TLS); abgerufen werden Kopfzeilen gekennzeichneter Mails und die eigenen Belegmails; nur lesend, nichts wird verändert | Einrichtung „Empfang per E-Mail“, danach automatisch | etwa stündlich im Hintergrund und bei jedem Öffnen | vorhanden (0.24.0) |
| Serversuche Mail (Spezifikation FA-17.9) | **Mozilla** (`autoconfig.thunderbird.net`) bzw. Betreiber der Maildomain (`autoconfig.‹domain›`, `‹domain›/.well-known`) | nur die **Domain** der Adresse, IP-Adresse, technische Verbindungsdaten; bei Gmail/iCloud keine Abfrage | Tippen auf „Verbinden und speichern“ bzw. „Prüfen und speichern“ | je Einrichtung | vorhanden (0.24.0) |
| Rechnung über Link-QR (L-27.7) | Server der im QR-Code genannten Domain (Rechnungsaussteller bzw. dessen Dienstleister), direkt vom Gerät | Adresse aus dem QR-Code (kann eine Rechnungs- oder Kundenkennung enthalten), IP-Adresse, technische Verbindungsdaten; **keine Daten aus der App** | Tippen auf „Laden“ im Hinweisstreifen | je Vorgang | vorhanden |
| EZB-Kursabruf (L-2.25, L-19.29) | Europäische Zentralbank, direkt vom Gerät | nur Abruf einer festen Kursdatei: IP-Adresse, Zeitpunkt, technische Verbindungsdaten; **keine Belegdaten, keine Währung, kein Betrag** | Tippen auf „Kurs abrufen“ | je Vorgang | vorhanden |
| Foto-Zweitablage (L-2.11) | Fotobibliothek, ggf. deren Cloud | Belegfotos | Einschalten | ja | A |
| UID-Prüfung auf Tippen (L-1.3) | EU-Kommission (VIES), direkt vom Gerät | UID, eigene UID als Anfragende, IP-Adresse | Tippen auf „Jetzt prüfen“ | je Vorgang | vorhanden |
| UID-Prüfung automatisch (L-1.3, L-1.4) | EU-Kommission (VIES), direkt vom Gerät | wie oben, für eigene UID und Kunden mit Rechnung in den letzten 12 Monaten; vor jeder Rechnung an Kunden mit UID | wöchentlich beim Öffnen der App | **ja**, Schalter, standardmäßig aus | vorhanden |
| Rechnungsversand (L-15.1) | Mail-App des Nutzers | PDF | Tippen auf Senden | je Vorgang | A |
| Abo-Kauf und Abo-Abfrage (L-10.1, L-22.5) | Apple bzw. Google über die Store-Schnittstelle des Geräts (Google Play Billing, StoreKit) | Produktkennungen; beim Einlösen eines Promo-Codes der Code selbst (iOS im Einlöseblatt von Apple, Android als Adresse `play.google.com/redeem?code=…`); Store-Konto, Zahlung und Kaufbeleg verarbeitet der Store selbst. Am Gerät nur Stufe, Bestätigungszeitpunkt, Testbeginn (Schlüsselbund) | Kauf bzw. „Kauf wiederherstellen“; Abfrage beim Start der App | Kauf je Vorgang; Abfrage nein, technisch notwendig für den Anspruch, offengelegt. Prüfung P-R37 | vorhanden (nur Store-Build mit `LICENSING=true`) |
| Berichte teilen (Spezifikation FA-15.8 bis FA-15.10, FA-16.8) | vom Nutzer gewählt (Teilen-Dialog), z. B. Steuerberatung | Anlagenverzeichnis, Saldenliste, vorläufiger Jahresabschluss mit Belegliste, Buchungsexport und Vertragsliste (ZIP); Vertragsseiten und erkannter Text bleiben auf dem Gerät | Tippen auf den Bericht | je Vorgang | vorhanden (0.18.0) |
| U30-Datei teilen (L-6.5, Spezifikation FA-14.4) | vom Nutzer gewählt (Teilen-Dialog); Upload in FinanzOnline macht die Nutzerin selbst | Kennzahlen der Voranmeldung, Steuernummer (FASTNR), Zeitraum | Tippen auf „U30-Datei teilen“ | je Vorgang | vorhanden (0.17.0) |
| UVA-Übermittlung direkt (L-6.5) | FinanzOnline-Webservice bzw. ELSTER (ERiC), direkt vom Gerät | Kennzahlen der Voranmeldung, Zugangsdaten der Nutzerin | Freigabe der Meldung | je Vorgang | B |
| Regelpaket-Abruf (L-20.22) | Hosting des Anbieters (EU) | nur Abruf: IP-Adresse, Zeitpunkt, App-Version; keine Nutzdaten | automatisch, täglich | nein, technisch notwendig; in der Datenschutzerklärung offengelegt | B |
| Synchronisierung (L-19.15 ff.) | gemeinsamer Ordner in der Cloud der Unternehmerin; freigegebene Personen und Geräte | alle Buchhaltungsdaten, Ende-zu-Ende verschlüsselt, signiert, mit Kennung der erfassenden Person | Einrichten bzw. Einladung per QR-Code | **ja** | C |
| Marketing (L-14) | Dienst zur Inhaltserzeugung | nur Unternehmens- und Artikeldaten | Modul einschalten | ja | C |
| Kanäle (L-12) | Amazon, Shopify, Google Merchant Center | je nach Modul | Modul einschalten | ja | C |

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-19.5 | **Jeder neue Datenfluss wird im selben Schritt in diese Tabelle, in die Datenschutzerklärung und in die Store-Datensicherheitsangaben eingetragen.** Eine Funktion, die Daten überträgt, ist ohne diese drei Einträge nicht fertig | MUSS | A |
| L-19.6 | ~~Daten beim Anbieter in der EU~~ entfällt: beim Anbieter landen keine Buchhaltungsdaten (O-29). Ausnahme: Marketing-Modul nach L-21 | — | — |
| L-19.7 | Synchronisierte Daten sind **Ende-zu-Ende verschlüsselt**; weder Cloud-Dienst noch Anbieter können sie lesen | MUSS | C |

#### Löschung und Aufbewahrungspflicht

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-19.8 | Die App **löscht keine Buchungsbelege vor Ablauf der Aufbewahrungsfrist** (AT 7, DE 8 Jahre) ohne ausdrückliche Warnung; die Frist hat Vorrang vor dem Löschwunsch (Art. 17 Abs. 3 lit. b DSGVO) | MUSS | A |
| L-19.9 | ~~Löschung des Nutzerkontos~~ entfällt mit L-19.2. Beim Verlassen eines Teams bleiben die Daten der Unternehmerin vollständig erhalten | — | — |
| L-19.10 | Der Nutzer kann **Daten seiner Kunden** auf deren Anfrage auskunftsfähig zusammenstellen (alle Rechnungen und Stammdaten eines Kunden als Export) | SOLL | B |
| L-19.11 | Kundenstammdaten ohne aufbewahrungspflichtige Rechnungen sind löschbar; mit solchen Rechnungen wird auf die Frist verwiesen | MUSS | B |

> **Die Leitlinie.** Bis Stufe C gibt es beim Anbieter schlicht keine
> Nutzerdaten: kein Konto, kein Server, keine Kopie. Das ist die stärkste
> Datenschutzposition, die ein Produkt einnehmen kann, und sie ist nur so lange zu
> halten, wie L-19.5 ernst genommen wird. Rechtsgrundlagen und Rollen sind vor
> Stufe C anwaltlich zu bestätigen (L-17.11).

---

### 5.20 Rechtsstand-Überwachung

Auftrag vom 2026-10-10: Ein Agent prüft täglich, ob sich Gesetze, Steuersätze,
Grenzwerte oder Fristen geändert haben, damit die App immer nach aktuellem
Recht rechnet. Ausgearbeitet mit den drei Prüfinstanzen.

**Leitsatz: Der Agent schlägt vor, Menschen geben frei, die App prüft nach.**
Der Agent läuft beim Anbieter, nie auf dem Gerät, und hat weder Schreibrechte
auf den Code noch Zugriff auf den Signaturschlüssel. Ungeprüfte KI-Ergebnisse
erreichen nie eine Nutzerin.

```
amtliche Quellen ──► Agent (täglich) ──► Änderungsvorschlag mit Fundstelle und Zitat
                                              │  automatische Quellen- und Zitatprüfung
                                              ▼
                    Prüfinstanzen ──► Steuerberaterin + Entwickler (Vier Augen)
                                              │  Signatur offline
                                              ▼
                    Regelpaket (staging ≥ 48 h) ──► stable ──► App: Signatur, Schema,
                                                               Plausibilität, Golden Cases
                                                               ──► gilt ab Stichtag
```

#### Beobachtung und Vorschlag (Anbieterseite)

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-20.1 | **Tägliche Beobachtung** der amtlichen Quellen: AT RIS/BGBl, Findok, BMF; DE Bundesgesetzblatt (recht.bund.de), BMF-Schreiben, Bundestag-DIP zur Vorwarnung. Feed- und Textvergleich als Auslöser, der Agent fasst zusammen und erstellt den Vorschlag | MUSS | B |
| L-20.2 | **Nur amtliche Primärquellen sind maßgeblich** (Allowlist der Domains). Sekundärquellen dürfen nur auf eine Änderung hinweisen. Nutzungsbedingungen, Text-und-Data-Mining-Vorbehalte und Quellenangabe (RIS: CC BY 4.0) werden beachtet; Abfragerate begrenzt | MUSS | B |
| L-20.3 | **Halluzinationsschutz:** jeder Vorschlag enthält Wert, Gültig-ab, Fundstelle (Gesetzblatt, Paragraph), amtliche URL und wörtliches Zitat. Die Pipeline ruft die URL ab und prüft das Zitat; fehlt die Quelle oder stimmt das Zitat nicht, wird der Vorschlag automatisch verworfen | MUSS | B |
| L-20.4 | **Entwürfe sind nie freigabefähig.** Maßgeblich ist die Kundmachung; Regierungsentwürfe und Ankündigungen erzeugen nur eine interne Vorwarnung | MUSS | B |
| L-20.5 | Vorschläge entstehen als Änderungsantrag gegen die Regeldateien im Repository. Der Agent kann nicht zusammenführen, nicht freigeben, nicht signieren | MUSS | B |
| L-20.6 | **Lebenszeichen:** jeder Lauf wird protokolliert; bleibt er 48 h aus, oder steht ein bekannter Stichtag in weniger als 30 Tagen ohne freigegebenes Paket an, wird der Anbieter alarmiert | MUSS | B |

#### Freigabe und Veröffentlichung

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-20.7 | **Freigabe nach dem Vier-Augen-Prinzip:** fachlich durch eine Steuerberaterin, technisch durch einen Entwickler; vorher Prüfung durch die drei Prüfinstanzen. Ohne beide Freigaben kein Paket | MUSS | B |
| L-20.8 | **Vertrag mit der Steuerberaterin:** Freigabe für den Anbieter, nicht Beratung der Nutzerinnen; Haftung, Versicherung, Vertretung | MUSS | B |
| L-20.9 | **Signatur** (Ed25519) mit Schlüssel außerhalb jeder Agent- und CI-Umgebung (offline oder Schlüsseldienst), eigener manueller Schritt; Reserveschlüssel und Sperrliste für Notfälle | MUSS | B |
| L-20.10 | Jedes Paket enthält **Golden Cases** (Rechenbeispiele je geändertem Wert, jeweils Tag vor und Tag des Stichtags); die Pipeline rechnet sie mit dem echten Rechenkern nach | MUSS | B |
| L-20.11 | Kanäle *staging* (Testgeräte) und *stable*; ein Paket liegt mindestens 48 h auf staging. Auslieferung wenn möglich vor dem Stichtag | SOLL | B |
| L-20.12 | **Nachweis:** je Paket Version, Hash, Signatur, Diff, Quellenkopie mit Hash, Prüf- und Freigabeprotokoll mit Namen und Datum; unveränderlich mindestens 10 Jahre archiviert | MUSS | B |
| L-20.13 | Ein fehlerhaftes Paket lässt sich **zurückrufen** (signiertes Folgepaket); Rückruf und Ursache werden protokolliert | MUSS | B |

#### Anwendung in der App

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-20.14 | **Alle steuerlichen Kennwerte sind datengetrieben** mit Gültig-ab/-bis, Fundstelle und Übergangsregel: Steuersätze samt Zuordnung, Kleinunternehmergrenzen und Toleranz, Kleinbetragsrechnung, Aufbewahrungsfristen je Dokumentart, UVA-Schwellen und Fristen, OSS-Schwelle, E-Rechnungsstufen, Pflichtangaben und Rechnungshinweise. `TaxProfile` wird zu einem Stichtag aufgelöst und bleibt die einzige Stelle für Länderwerte (setzt L-13.5 um) | MUSS | B |
| L-20.15 | **Maßgeblich ist das Leistungsdatum**, nicht das Rechnungsdatum; jede Position trägt ein Leistungsdatum bzw. einen Leistungszeitraum. Anzahlungen behalten den Satz bei Vereinnahmung, die Schlussrechnung korrigiert | MUSS | B |
| L-20.16 | **Eingebaute Grundwerte** bleiben als Rückfall; die App rechnet immer, auch offline und ohne Paket. Rechnungen werden nie blockiert | MUSS | B |
| L-20.17 | **Prüfung auf dem Gerät vor jeder Anwendung:** Signatur vor dem Einlesen, Schema, Plausibilitätsgrenzen (z. B. Satz 0–300 ‰), monotone Versionsnummer (kein Zurückspielen alter Pakete), Ablaufdatum, Golden Cases mit dem echten Rechenkern. Scheitert eine Prüfung, wird das Paket verworfen und das letzte gültige behalten. Pakete enthalten ausschließlich Daten, keinen Code | MUSS | B |
| L-20.18 | **Gestellte Rechnungen werden nie neu berechnet.** Sie frieren Version und Hash des angewendeten Pakets ein (Regel 7) | MUSS | B |
| L-20.19 | **Nie automatisch** wirken: neue Zuordnung einer Leistung zu einem Satz, Wahlrechte (Verzicht auf Kleinunternehmerbefreiung, Ist/Soll, Dauerfristverlängerung), rückwirkende Änderungen, Auswirkungen auf gestellte Rechnungen. Diese erzeugen nur einen Hinweis mit Empfehlung, die Steuerberatung einzubinden | MUSS | B |
| L-20.20 | **Information der Nutzerin** vor und am Stichtag: was sich ändert, ab wann, Fundstelle, Hinweis „keine Steuerberatung" (L-17.5). Keine Empfehlung für den Einzelfall | MUSS | B |
| L-20.21 | **Rechtsstand sichtbar:** Paketversion und Prüfdatum in den Einstellungen; ab 30 Tagen ohne erfolgreiche Prüfung ein Hinweis „Steuerwerte zuletzt geprüft am …" | MUSS | B |
| L-20.22 | **Anonymer Abruf:** feste Datei je Land und Kanal, keine Geräte- oder Nutzerkennung, keine Nutzdaten, Hosting in der EU, IP-Adressen gekürzt oder Protokolle höchstens 14 Tage. Datenschutzerklärung, Store-Angaben und Datenflusstabelle (5.19) werden im selben Commit angepasst, der den Abruf einbaut | MUSS | B |
| L-20.23 | Keine Werbeaussage „immer aktuell" oder „garantiert"; angegeben wird der geprüfte Stand. In App und Handbuch wird offengelegt, dass die Recherche KI-gestützt ist und Menschen freigeben | MUSS | B |

#### Validierung der Funktion

Der Auftraggeber verlangt eine gute Validierung. Abnahme erst, wenn alle Punkte
erfüllt sind; die realen Prüfungen stehen in Spezifikation Abschnitt 14 (P-V…).

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-20.24 | **Rückspieltest:** der Agent wird gegen bekannte historische Änderungen laufen gelassen (DE 16/5 % Juli 2020 und Rückkehr, AT 5 % 2020/21, DE und AT Kleinunternehmer 2025). Abnahme nur, wenn alle erkannt werden und kein Vorschlag ohne gültiges Zitat durchkommt | MUSS | B |
| L-20.25 | **Fehlertests auf dem Gerät:** manipuliertes, unsigniertes, älteres, abgelaufenes und unplausibles Paket werden jeweils abgelehnt; Flugmodus über einen Stichtag hinweg rechnet mit den richtigen Werten | MUSS | B |
| L-20.26 | `specification_sync_test` prüft eingebaute Grundwerte, Regeldateien und Spezifikation gegeneinander, je Stichtag | MUSS | B |
| L-20.27 | **Probelauf mit der echten Steuerberaterin:** ein vollständiger Durchlauf vom Vorschlag bis zur Anwendung auf einem Testgerät, vor dem ersten echten Paket | MUSS | B |
| L-20.28 | Einmal pro Jahr Wiederholung des Rückspieltests mit den Änderungen des Vorjahres | SOLL | B |

**Häufigkeit:** Für die Zielgruppe sind etwa 3–10 relevante Änderungen je Land
und Jahr zu erwarten, gebündelt zum 1. Jänner. Täglich beobachtet wird, weil
Kundmachungen im Dezember oft nur Tage vor dem Inkrafttreten erscheinen;
Pakete erscheinen anlassbezogen, etwa 2–6 im Jahr.

**Bis Stufe B** kommen geänderte Werte wie bisher per App-Update.

### 5.21 Anbindung an Claude (KI-Dienst)

**Entscheidungen vom 2026-10-10:** Der Start erfolgt auf der heutigen
Claude-Anbindung; **innerhalb von sechs Monaten nach dem Launch** wird
**direkt auf die Anthropic API** umgestellt, unter **einem eigenen, neuen
Konto** des Anbieters. Betroffen sind Rechtsstand-Agent (L-20),
Marketing-Modul (L-14, S-13) und künftige KI-Funktionen. Ausgearbeitet mit den
drei Prüfinstanzen.

#### Grundsätze

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-21.1 | **Austauschbare Anbindung:** jeder Zugriff auf ein Sprachmodell läuft über genau eine Adapterschicht; Endpunkt, Modell, Region und Zugangsdaten sind Konfiguration, nie im Code verstreut. Der Adapter kann je Datenkategorie eine eigene Route haben (L-21.12) | MUSS | A |
| L-21.2 | **Kein API-Schlüssel in der App.** Aufrufe laufen ausschließlich beim Anbieter: Rechtsstand-Agent als geplanter Job, Marketing-Modul über ein eigenes kleines Backend. Die App spricht kein Sprachmodell direkt an | MUSS | A |
| L-21.3 | **Umstellung innerhalb von sechs Monaten nach dem Launch** auf die Anthropic API mit eigenem Konto, ohne App-Update für die Nutzerinnen | MUSS | C |
| L-21.4 | **Validierung der Umstellung:** dieselben Prüfungen laufen vor und nach dem Wechsel und müssen gleich gut bestehen — Rückspieltest (L-20.24) und Zitatprüfung (L-20.3) beim Agenten, eine feste Sammlung von Testaufträgen beim Marketing-Modul | MUSS | C |
| L-21.5 | Paralleler Probebetrieb: die neue Anbindung läuft vor der Umschaltung mindestens zwei Wochen mit, ihre Ergebnisse werden verglichen, aber nicht verwendet | SOLL | C |
| L-21.6 | **Datenschutz vor der Umschaltung:** Datenflusstabelle (5.19), Datenschutzerklärung, Store-Angaben, Liste der Unterauftragsverarbeiter und Verzeichnis der Verarbeitungstätigkeiten nennen Anthropic und die Verarbeitung in den USA; Auftragsverarbeitungsvertrag (Anthropic-DPA mit Standardvertragsklauseln) ist abgeschlossen und archiviert | MUSS | C |
| L-21.7 | Rückweg: die bisherige Anbindung bleibt bis zum Abschluss der Validierung umschaltbar; ebenso eine Ausweichroute, falls die Rechtsgrundlage für den US-Transfer wegfällt | SOLL | C |

#### Verarbeitungsort: muss es die EU sein?

Die Anthropic API erlaubt als Verarbeitungsort (`inference_geo`) nur „USA" oder
„global", **keine reine EU-Verarbeitung**. Ergebnis der Prüfinstanzen: Die
DSGVO verlangt keine EU-Verarbeitung, wenn der Transfer abgesichert ist
(Angemessenheitsbeschluss EU-US Data Privacy Framework oder
Standardvertragsklauseln mit Transfer-Folgenabschätzung). §§ 146 AO und 131 BAO
regeln den Ort der Bücher, nicht eine flüchtige Verarbeitung. Entscheidend ist
daher, **welche Daten** die KI erreichen:

| ID | Datenkategorie | Über die Anthropic API (USA/global)? | Prio | Stufe |
|---|---|---|---|---|
| L-21.8 | **Rechtsstand-Agent:** nur öffentliche Rechtsquellen | **Ja.** Prompts und Protokolle enthalten keine Nutzer- oder Personendaten | MUSS | B |
| L-21.9 | **Marketing-Modul:** Angaben der Nutzerin zu Firma und Produkten. Bei Einzelunternehmen ist der Firmenname ein Personenname, also personenbezogen | **Ja, mit Auflagen:** Opt-in mit Nennung von Anthropic und USA (L-14.6), Auftragsverarbeitungsvertrag, Datenschutzerklärung; das Backend lässt nur eine feste Liste von Feldern durch, Kundendaten der Nutzerin werden technisch abgewiesen (L-14.5) | MUSS | C |
| L-21.10 | **Buchhaltungsdaten und Belege** (Daten Dritter, auch besonders schützenswerte wie Arztrechnungen) | **Nein.** Bevorzugt Erkennung auf dem Gerät. Falls doch ein Sprachmodell nötig wird: eigene Route mit EU-Verarbeitung (Claude über Google Vertex AI „eu" oder AWS Bedrock EU) nach Datenschutz-Folgenabschätzung, oder Anthropic API nur mit vereinbarter Null-Speicherung (Zero Data Retention), Transfer-Folgenabschätzung und ausdrücklicher Information der Nutzerin | MUSS | — |
| L-21.11 | **Belegerkennung per KI** liefert nur einen Vorschlag; gebucht wird erst nach Bestätigung durch die Nutzerin. Das Original bleibt unverändert auf dem Gerät; je Beleg werden Modell, Vorschlag und bestätigter Wert protokolliert (GoBD, § 131 BAO); Verfahrensdokumentation beschreibt den KI-Schritt | MUSS | — |
| L-21.12 | Die Regel, welche Kategorie welche Route nimmt, ist **im Backend technisch erzwungen**, nicht nur dokumentiert | MUSS | C |

#### Betrieb rund um die Uhr (24/7)

Empfehlung der Prüfinstanz Softwareentwickler: **Für 24/7 ist kein zusätzlicher
Anthropic-Dienst nötig.** Das Self-Serve-Konto mit ausreichender Nutzungsstufe
genügt zum Launch. Ein vertragliches Verfügbarkeits-SLA gibt es dort nach
Kenntnisstand nicht; der „Priority Tier" ist für die aktuellen Modelle (Opus 5.5,
Sonnet 5.5) nicht verfügbar. **Die Verfügbarkeit sichert das eigene Design.**
Rund um die Uhr nötig ist nur das Marketing-Backend; der Rechtsstand-Agent ist
ein täglicher Job, der einen Ausfall am Folgetag nachholt. Die Buchhaltung
selbst hängt nie von der KI ab (NF-1, offline-first).

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-21.13 | **Konto:** eigene Organisation mit Firmen-E-Mail, mindestens zwei Administratoren mit Zwei-Faktor-Anmeldung, Firmendaten und UID in der Abrechnung; kommerzielle Bedingungen und DPA angenommen und archiviert | MUSS | C |
| L-21.14 | **Getrennte Workspaces** `prod`, `staging`, `rechtsstand-agent` mit eigenen Schlüsseln und Ausgabenlimits; Menschen nur mit den nötigen Rollen | MUSS | C |
| L-21.15 | **Zugang ohne langlebige Schlüssel:** Workload Identity Federation (z. B. GitHub-Actions-OIDC für den Agenten), sonst Service Account mit Schlüssel im Secret-Store und Rotation alle 90 Tage | MUSS | C |
| L-21.16 | **Ausgabenlimits** je Organisation und Workspace großzügig, Alarmschwellen bei 50 % und 80 % eng; im Backend ein Kontingent je Nutzerin und Tag | MUSS | C |
| L-21.17 | **Nutzungsstufe rechtzeitig vor dem Launch** durch Vorauszahlung anheben, damit die Rate Limits reichen; Limits danach in der Console prüfen | MUSS | C |
| L-21.18 | **Rechtsstand-Agent** als täglicher Job (z. B. GitHub Actions) mit Messages API, Websuche und Webabruf nur auf freigegebenen amtlichen Domains; Ergebnis als Änderungsantrag. Managed Agents erst nach Ende der Beta prüfen | MUSS | B |
| L-21.19 | **Marketing-Backend** in der EU gehostet: Anmeldung über das Store-Abo, Kontingent, Protokolle ohne Inhalte, Adapter, Feld-Allowlist (L-21.9), Warteschlange | MUSS | C |
| L-21.20 | **Wiederholung und Ausweichmodell:** bei Überlast und Serverfehlern Wiederholung mit wachsendem Abstand (Retry-After beachten), danach Wechsel auf ein kleineres Modell mit Kennzeichnung „vereinfachte Variante"; Aufträge in einer Warteschlange statt Fehlermeldung | MUSS | C |
| L-21.21 | **Überwachung:** Statusseite von Anthropic abonniert, eigene Kennzahlen (Fehlerquote, Antwortzeit, Kosten je Tag), externer Verfügbarkeitstest des Backends, Alarm per E-Mail oder Push; Fehlschlag des Agenten erzeugt eine Meldung | MUSS | C |
| L-21.22 | **Modellwahl:** Sonnet 5.5 als Standard, Haiku 5.5 als Ausweichmodell und Vorfilter, Opus 5.5 nur zur Zweitprüfung erkannter Rechtsänderungen; Prompt Caching für feste Anweisungen. Vor jeder Analyse ein Hash-Vergleich der Quelle, damit unveränderte Seiten keine KI-Kosten erzeugen | SOLL | B |
| L-21.23 | Ein Enterprise-Vertrag mit SLA wird erst angefragt, wenn Umsatz oder Last es rechtfertigen | KANN | — |
| L-21.24 | KI-Auslesung von Belegen nur per Opt-in; kein automatischer Rückfall von der Erkennung auf dem Gerät auf einen KI-Dienst | MUSS | B |

**Kostenannahmen (nicht verifiziert, aus Listenpreisen):** Rechtsstand-Agent
etwa 30–60 USD im Monat; Marketing-Modul etwa 250–350 USD je 1.000 aktive
Pro-Nutzerinnen mit 20 Aufträgen im Monat; Backend-Hosting 5–30 € im Monat.
Werden mit Messdaten aus dem Probebetrieb ersetzt.

### 5.22 Lizenz und Bezahlung

Ausgearbeitet mit den drei Prüfinstanzen am 2026-10-12. Checkliste zur
Einreichung: [`STORE_READINESS.md`](STORE_READINESS.md).

**Bezahlung ausschließlich über die Stores** (Apple In-App-Kauf, Google Play
Billing). Die Stores sind gegenüber den Kundinnen Verkäufer: sie kassieren,
führen die Umsatzsteuer ab, stellen Quittungen aus und regeln Widerruf und
Erstattung. Der Anbieter leistet an Apple bzw. Google in Irland (Reverse
Charge) und erhält die Auszahlung abzüglich Provision.

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-22.1 | **Lizenzmanager** in `lib/services`: liefert nur den Anspruch `keiner / nur lesen / Basis / Pro` (dazu `Demo`, solange die Demo läuft, L-10.6); Oberfläche und Funktionen fragen nur diesen Wert ab, nie die Store-Schnittstelle direkt | MUSS | B |
| L-22.2 | Paket `in_app_purchase` (StoreKit 2, Play Billing); **eine Abogruppe** mit den Stufen Basis < Pro, je monatlich und jährlich, damit Wechsel ohne Doppelabo gehen (Apple: Upgrade sofort, Downgrade zum Periodenende) | MUSS | B |
| L-22.3 | **14 Tage Test** als Einführungsangebot der Stores auf **allen vier Produkten** (Basis und Pro, Monat und Jahr; O-42); in der Testzeit des ersten Abos gibt die App auch bei Basis alle Pro-Funktionen frei (iOS: Einführungsangebot laut StoreKit 2; Android: 14 Tage ab Kaufzeitpunkt, Näherung); Rabatte über Einführungsangebote und Angebotscodes (serverseitig signierte Aktionsangebote entfallen ohne Server) | MUSS | B |
| L-22.4 | **Prüfung der Käufe auf dem Gerät:** StoreKit-2-Signatur bzw. Google-Kaufsignatur mit dem öffentlichen Lizenzschlüssel; Status mit Ablaufdatum geschützt gespeichert (Schlüsselbund/Keystore) | MUSS | B |
| L-22.5 | **Kulanz:** Billing-Grace-Period der Stores eingeschaltet; ohne Netz bleibt der volle Anspruch mindestens 14 Tage über das Ablaufdatum hinaus. Herabstufung nur nach Ankündigung in der App | MUSS | B |
| L-22.6 | **Herabstufen statt sperren:** Pro-Ende → Basis; Basis-Ende → Nur-Lese-Modus (L-7.15). Ansehen, Drucken, Export, Sicherung und Wiederherstellung bleiben immer möglich | MUSS | B |
| L-22.7 | **Abo-Seite vor dem Kauf:** Preis je Zeitraum inkl. USt, Laufzeit, automatische Verlängerung, Testende mit Folgepreis, Kündigungsweg, Links zu Nutzungsbedingungen und Datenschutz (Apple 3.1.2) | MUSS | B |
| L-22.8 | **„Abo verwalten/kündigen"** als Sprung in die Aboverwaltung des Stores; **„Käufe wiederherstellen"** | MUSS | B |
| L-22.9 | Preisänderungen laufender Abos nur über die Store-Mechanik (Zustimmung der Kundin); keine Preisanpassungsklausel in den Nutzungsbedingungen | MUSS | B |
| L-22.10 | **Kein Abrechnungs- oder Analyse-SDK Dritter** (z. B. RevenueCat) ohne vorherige Eintragung in 5.19, PRIVACY und STORE_LISTING und Auftragsverarbeitungsvertrag | MUSS | B |
| L-22.11 | Manipulationsschutz bewusst „ausreichend": Prüfung auf dem Gerät plus verschleierter Code; gegen gezieltes Knacken schützt ohne Server nichts | MUSS | B |
| L-22.12 | **Spätere In-App-Käufe:** dauerhafte Freischaltungen als Nicht-Verbrauchsartikel jederzeit möglich; Kontingente (z. B. Marketing-Erzeugungen) als Verbrauchsartikel erst mit Backend (S-8), weil ein Zähler am Gerät manipulierbar ist | KANN | C |
| L-22.13 | **Kein Direktverkauf, keine DMA-Alternativen** in Stufe A und B; Neubewertung nur, wenn der Umsatz die Ersparnis rechtfertigt (dann Widerruf, § 312k BGB, OSS, Zahlungsdienstleister, Lizenzserver) | MUSS | B |
| L-22.14 | **Anbieter-Steuern vor dem ersten Verkauf:** UID-Nummer, Zusammenfassende Meldung und UVA für Store-Erlöse (Leistungsort Irland), W-8BEN(-E), Buchungsregel für Auszahlungen; keine Werbung mit Vorsteuerabzug aus Store-Quittungen (P-S12) | MUSS | B |

**Store-Reife (Auszug, vollständig in STORE_READINESS.md):**

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-22.15 | Organisationskonten bei Google Play und Apple mit D-U-N-S-Nummer; öffentliche Händlerangaben nach DSA identisch mit dem Impressum | MUSS | A |
| L-22.16 | Release-Workflow getrennt von der CI: AAB mit Upload-Schlüssel, iOS über Fastlane nach TestFlight; Release ohne Upload-Schlüssel bricht ab | MUSS | A |
| L-22.17 | `PrivacyInfo.xcprivacy`, fest eingetragenes targetSdk, geklärte Export-Compliance (eigene AES-Verschlüsselung) | MUSS | A |
| L-22.18 | Menü „Rechtliches" in der App, auch offline: Impressum, Datenschutz, Nutzungsbedingungen, Support, „keine Steuerberatung" | MUSS | A |
| L-22.19 | Kein Crash-SDK; Absturzstatistik der Stores plus freiwilliger Fehlerbericht per E-Mail | MUSS | A |
| L-22.20 | Werbe-Negativliste in STORE_LISTING („finanzamtssicher", „GoBD-zertifiziert", „ersetzt Steuerberatung" u. a.); Prüfung vor jeder Textänderung | MUSS | A |
| L-22.21 | Wiederherstellungscode als lokal erzeugtes PDF bzw. Druckblatt mit QR-Code über Teilen/Drucken; keine Kopie in der App. Es gibt kein Konto und kein Passwort-Zurücksetzen beim Anbieter (L-7.12) | MUSS | A |
| L-22.22 | Bestätigung beim Einrichten durch Eingabe von zwei zufälligen Codeblöcken | MUSS | A |
| L-22.23 | Code-Selbsttest als Erinnerung (halbjährlich, vor Gerätewechsel); „Neuen Code erzeugen“, solange der Gerätschlüssel besteht, mit Hinweis, dass alte Sicherungen den alten Code brauchen | SOLL | B |
| L-22.24 | Passwortmanager-Autofill für den Code; Zwischenablage nach 60 s leeren | SOLL | B |
| L-22.25 | Hinweise zu Datenverlust bei Codeverlust und zur Aufbewahrungspflicht in Erklärseite, Handbuch und Nutzungsbedingungen | MUSS | A |
| L-22.26 | Promocodes nur über Store-Mechanismen (iOS `offerCodeRedemption`, Android `play.google.com/redeem`); kein eigenes Codefeld (Apple 3.1.1) | MUSS | A |
| L-22.27 | Aktionen als Store-Offers: (a) 1–3 Monate gratis nur für Neukundinnen, (b) Prozentrabatt auf das Jahresabo; je Partnerin eigener Custom Code mit Einlöselimit und Ablauf, regelmäßig ersetzt; Einmalcodes für Gewinnspiele | SOLL | B |
| L-22.28 | Affiliate-Abrechnung nur auf Basis der Console-Berichte; kein Tracking in der App | MUSS | B |
| L-22.29 | Aktionspreise mit Folgepreis, Laufzeit und Verlängerung; Jahresrabatt als Vergleich zum 12-fachen Monatspreis, kein Streichpreis ohne 30-Tage-Bezug | MUSS | A |
| L-22.30 | Optionale App-Sperre mit PIN (Pflicht-Rückfall) und optional Fingerabdruck/Face ID, lokal; Sperre beim Start und nach einstellbarer Zeit im Hintergrund; steigende Wartezeit nach Fehlversuchen; Inhalt im App-Umschalter verdeckt; kein Zurücksetzen durch den Anbieter, Weg ist Neuinstallation und Wiederherstellung aus der Sicherung, beim Einrichten erklärt mit Warnung ohne Sicherung. **Entscheidung der Auftraggeberin vom 2026-10-12; umgesetzt, Spezifikation FA-1.13 bis FA-1.18** | SOLL | A |

---

### 5.23 Vertragsarchiv (Stufe C)

Wunsch der Auftraggeberin vom 2026-10-12; geprüft von Steuerberater und
Rechtsanwalt (Prüfpunkte P-S16 bis P-S18, P-L14 bis P-L17 in Spezifikation
Abschnitt 14). Einzelunternehmerinnen bilanzieren nicht: Verträge zählen für
Einnahmen-Ausgaben-Rechnung, Abschreibung, Privatanteile und Aufbewahrung.

**Umsetzungsstand 0.19.0 (Wunsch der Auftraggeberin 2026-10-16):** der lokale
Teil ist gebaut – L-23.1 bis L-23.4, L-23.6 als Auszug mit Fundstelle ohne KI,
L-23.11 über Sicherung und `vertraege.csv` (Spezifikation 5.12). L-23.5 und
L-23.7 bis L-23.10 (KI-Analyse) bleiben Stufe C.

| ID | Anforderung | Priorität | Stufe |
|---|---|---|---|
| L-23.1 | Verträge (Dienst, Werk, Kauf, Leasing, Versicherung, Miete, Pacht, Dienstbarkeit, Darlehen) lokal und verschlüsselt ablegen, mit Typ, Partner, Laufzeit, Kündigungsfrist, Rate; verknüpfbar mit Belegen und Buchungen | MUSS | C |
| L-23.2 | Aufbewahrungsfrist je Vertrag ab Vertragsende und letzter darauf beruhender Buchung; Fristen über `TaxProfile`; Löschen vorher nur mit Warnung | MUSS | C |
| L-23.3 | Lokale Erinnerung an Kündigungs- und Verlängerungsfristen, Indexanpassungen, Fälligkeiten | SOLL | C |
| L-23.4 | Abgleich Rate laut Vertrag gegen gebuchte Zahlung; wiederkehrende Buchung nur als Vorschlag | SOLL | C |
| L-23.5 | Steuerliche Hinweise nur als allgemeine Information aus freigegebenem Textkatalog mit Normzitat; keine Einzelfallentscheidung über Privatanteil, Zurechnung, Absetzbarkeit | MUSS | C |
| L-23.6 | Rechtliche Ausgaben nur als Auszug und Zusammenfassung mit Fundstelle im Vertragstext; keine Wirksamkeitsurteile, Handlungsempfehlungen oder individuellen Schreiben | MUSS | C |
| L-23.7 | KI-Analyse nur per Opt-in je Funktion, standardmäßig aus; Vorschau je Vorgang mit Empfänger und Land; Route nach L-21.10, technisch erzwungen | MUSS | C |
| L-23.8 | Vor Übertragung lokale Texterkennung und Schwärzung personenbezogener Daten Dritter; Arbeitsverträge standardmäßig ausgeschlossen; besondere Kategorien (Art. 9 DSGVO) nie übertragen | MUSS | C |
| L-23.9 | Freischaltung erst mit AVV Anbieterin–Nutzerin, Anthropic-DPA mit SCC, DSFA und TIA, Einträgen nach L-19.5 und L-21.6 | MUSS | C |
| L-23.10 | KI-Ergebnisse gekennzeichnet (Art. 50 AI Act), mit Modell, Zeitpunkt, Vorschlag und bestätigtem Wert protokolliert; keine Bewertung von Beschäftigten (Anhang III Nr. 4) | MUSS | C |
| L-23.11 | Vertragsarchiv in Vollexport und Sicherung; Auskunftsexport je Vertragspartner | SOLL | C |

### 5.24 Wirtschaftsjahr

Entscheidung der Auftraggeberin 2026-10-14. Steuerberater-Befund: abweichendes
Wirtschaftsjahr in AT nur für im Firmenbuch eingetragene, bilanzierende
Unternehmer mit Zustimmung des Finanzamts (§ 2 Abs 5 EStG), in DE nur für im
Handelsregister eingetragene Gewerbetreibende (§ 4a EStG); EÜR-Rechner praktisch
Kalenderjahr. Real zu prüfen: Spezifikation 14, P-S32.
**Umgesetzt in 0.3.5** (Spezifikation GR-10, FA-10.1, FA-10.2).

| ID | Anforderung | Priorität | Stufe |
|---|---|---|---|
| L-24.1 | Profileinstellung „Erster Monat Wirtschaftsjahr“ (Monatsauswahl, Standard Jänner/Januar) | MUSS | A |
| L-24.2 | Das Wirtschaftsjahr wird nach dem Kalenderjahr bezeichnet, in dem es endet, z. B. „April 2026 – März 2027“ = 2027 | MUSS | A |
| L-24.3 | Monat ≠ Jänner nur nach einmaliger Bestätigung mit länderspezifischem Text aus dem `TaxProfile`; danach dauerhafter dezenter Hinweis | MUSS | A |
| L-24.4 | Umsatzsteuer, Voranmeldung und Kleinunternehmergrenze bleiben immer Kalenderjahr (Regressionstest) | MUSS | A |
| L-24.5 | Wirtschaftsjahr gilt für Kassabuch-Jahr, EÜR/E1a-Auswertung, Jahresfilter der Übersicht und des Exports, Exportdateinamen und DATEV-Header „WJ-Beginn“ | MUSS | A |

### 5.25 Steuer- und Abgabetermine

Entscheidung der Auftraggeberin 2026-10-14: Stufe 1 nur Anzeige auf der
Übersicht, keine Benachrichtigungen, kein neues Paket. Real zu prüfen:
Spezifikation 14, P-S33, P-S34, P-R24.
**L-25.1 bis L-25.7 und L-25.9 umgesetzt in 0.3.5** (Spezifikation FA-10.3 bis
FA-10.6, GR-11); die Termin-Box steht seit 0.7.0 am Ende der Übersicht. L-25.8
offen (Stufe B).

| ID | Anforderung | Priorität | Stufe |
|---|---|---|---|
| L-25.1 | Termin-Box auf der Übersicht mit den nächsten 3–4 Terminen: Datum, Bezeichnung, Tage bis dahin; Tipp zeigt Rechtsgrundlage | MUSS | A |
| L-25.2 | Regeln je Land im `TaxProfile` mit Fundstelle; Berechnung als reines Dart in `lib/services` | MUSS | A |
| L-25.3 | Feiertage AT/DE mit Ostern-Berechnung; Verschiebung auf den nächsten Werktag (§ 108 Abs 3 BAO, § 108 Abs 3 AO) | MUSS | A |
| L-25.4 | Bundesland nur in DE abfragen (Landesfeiertage); in AT nicht | MUSS | A |
| L-25.5 | Profilangaben mit Vorbelegung, später änderbar: Voranmeldungsrhythmus (aus dem Vorjahr vorgeschlagen), Dauerfristverlängerung (DE), ZM, Steuerberatung, SVS (AT) | MUSS | A |
| L-25.6 | Mit Steuerberatung: Erklärungsfrist „laut Kanzlei“; SVS-Termine als „ca.“ | MUSS | A |
| L-25.7 | Hinweis „Berechnete Termine zur Orientierung, ohne Gewähr. Maßgeblich sind Bescheid, Finanzamt bzw. deine Steuerberatung.“ | MUSS | A |
| L-25.8 | Stufe 2: lokale Benachrichtigungen vor Terminen | KANN | B |
| L-25.9 | Bezahlte Ausgangsrechnung ist Einnahme am Tag des Zahlungseingangs (Zuflussprinzip), Datum beim Markieren „bezahlt“ vorbelegt mit heute; offene Rechnungen zählen in der EÜR nicht; keine Doppelbuchung (Gerätetest 0.3.4, P-S35) | MUSS | A |

### 5.26 Hilfe in der App

Entscheidung der Auftraggeberin 2026-10-14: Stufe 1 offline, ohne Server.
Stufe 2 (KI-Antworten) erst nach der Server-Entscheidung. Real zu prüfen:
Spezifikation 14, P-R25, P-R26 (Stufe 2), P-D26.

| ID | Anforderung | Priorität | Stufe |
|---|---|---|---|
| L-26.1 | Hilfe-Symbol auf allen Hauptbildschirmen gut erreichbar, ohne die Erfassungsknöpfe zu verdecken | MUSS | A |
| L-26.2 | Suchfeld „Frag mich etwas …“; Treffer aus Benutzerhandbuch und Häufigen Fragen mit Überschrift und Auszug; deutsche Normalisierung und Synonyme („löschen“ findet „stornieren“) | MUSS | A |
| L-26.3 | Das Benutzerhandbuch ist die einzige Quelle; kein zweiter Hilfetext. Ein Test schlägt fehl, wenn die Hilfe nicht zum Handbuch passt | MUSS | A |
| L-26.4 | Kontext: aus dem Belegformular geöffnet zuerst Beleg-Themen | SOLL | A |
| L-26.5 | Ohne Treffer: E-Mail an den Support über die Mail-App, Betreff mit App-Version, keine Daten automatisch angehängt | MUSS | A |
| L-26.7 | **Wunsch oder Idee senden** aus den Einstellungen: Art (Neue Funktion/Verbesserung/Fehler), Titel optional, Beschreibung mit Diktat; Versand nur über die Mail-App der Nutzerin an die Support-Adresse; technische Angaben (App-Version, Betriebssystem, Gerätemodell, Länderprofil, Abo-Stufe) abschaltbar, nie Geschäftsdaten oder Belege; ohne Mail-App Text in die Zwischenablage. **Umgesetzt 0.22.2** (Spezifikation FA-11.6) | SOLL | A |
| L-26.6 | Stufe 2: Antworten durch ein KI-Modell auf einem Server, als KI gekennzeichnet, Opt-in, nur mit Prüfung P-R25/P-R26 | KANN | B |

Umsetzung Stufe 1: Spezifikation 5.8, FA-11.1 bis FA-11.3; **L-26.1 bis L-26.5
umgesetzt in 0.3.5**. L-26.6 offen (O-32).

### 5.27 Belege aus Codes, PDF und E-Rechnungen übernehmen

Entscheidung der Auftraggeberin 2026-10-14: Stufen A1 (Codes auf dem Foto,
Teilen-Ziel), A2 (PDF und E-Rechnungen), A3 (Link-QR) und B1 umsetzen; echte
Plattform-Schnittstellen (B2) zurückgestellt (O-32). Alles läuft auf dem
Gerät; einzige neue Übertragung ist der Abruf über einen Link-QR nach Tipp
(L-27.7, 5.19). Real zu prüfen: Spezifikation 14, P-S49, P-S50, P-R35, P-U5,
P-U6. **Umgesetzt:** A1 (L-27.1 bis L-27.3, L-27.4 für Bilder) in 0.8.0, A2
(L-27.4 für PDF/XML, L-27.5, L-27.6, L-27.8) in 0.9.0, A3 (L-27.7) in 0.10.0.
Die Kürzel A1–A3, B1, B2 bezeichnen Umsetzungsschritte dieses Blocks, nicht die
Ausbaustufen A/B/C aus Abschnitt 10.

| ID | Anforderung | Priorität | Stufe |
|---|---|---|---|
| L-27.1 | QR- und 2D-Codes werden auf **demselben Foto** wie der Text erkannt, offline, ohne zweiten Schritt | MUSS | A1 |
| L-27.2 | **Kassen-QR** (AT RKSV, DE TSE nach DSFinV-K) hat Vorrang bei Betrag, Datum und Steuersätzen (Aufteilung je Satz); Händler aus dem Text bzw. aus einem Lernspeicher Kasse → Händler; dezenter Vermerk „vom Kassen-QR“; das Foto bleibt der Beleg. Ein Satz, der aus dem Code nicht eindeutig hervorgeht (AT „Betrag-Satz-Besonders“: 19 % oder 4,9 %), wird nicht geraten | MUSS | A1 |
| L-27.3 | **Zahlungs-QR** (EPC069-12, „GiroCode“): Empfänger, IBAN, Betrag und Referenz vorbelegen | MUSS | A1 |
| L-27.4 | **Teilen-Ziel**: Bilder, PDF und XML aus anderen Apps an die App teilen ergibt direkt einen Buchungsvorschlag (Android; iOS über „Öffnen in …“ statt Share Extension, bestätigt von der Auftraggeberin 2026-10-14) | MUSS | A1/A2 |
| L-27.5 | **PDF-Rechnungen**: Textebene auslesen; ohne Textebene Rückfall auf Texterkennung eines Seitenbilds. iOS-Zugang über „Öffnen in …“ statt Share Extension (Entscheidung der Auftraggeberin 2026-10-14) | MUSS | A2 |
| L-27.6 | **E-Rechnungen** strukturiert übernehmen: ZUGFeRD/Factur-X (eingebettetes XML), XRechnung (UBL und CII), ebInterface (AT) – Lieferant, UID, Datum, Sätze, Beträge, IBAN | MUSS | A2 |
| L-27.7 | **Link-QR**: Hinweisstreifen unten „Rechnung von ‹Domain› laden?“, nur nach Tipp, nur https, Domain groß, Weiterleitung auf fremde Domain nur nach erneuter Anzeige, nur PDF/XML, Größenlimit, kein Login im Web-Fenster; sonst „Im Browser öffnen“ | MUSS | A3 |
| L-27.8 | Die **Originaldatei** (PDF, XML) wird unverändert mit SHA-256 aufbewahrt und ist Teil von Sicherung und Export (§ 132 BAO, § 147 AO, GoBD Rz 131 ff.) | MUSS | A2 |

### 5.28 Standardexporte von Verkaufsplattformen übernehmen (Stufe B1)

Ohne Server und ohne Zugangsdaten: die Nutzerin lädt den Standardbericht der
Plattform herunter und teilt ihn an die App. Echte Schnittstellen bleiben
Stufe B2 (O-32). Befund Steuerberater 2026-10-14 verbindlich (Bruttoprinzip,
Reverse Charge auch beim Kleinunternehmer). Real zu prüfen: Spezifikation 14,
P-S51 bis P-S55, P-R36, P-U7. Umsetzung 0.11.0: Spezifikation FA-2.43 bis
FA-2.49, FA-3.3, FA-3.4. **L-28.1 bis L-28.7 umgesetzt in 0.11.0.**

| ID | Anforderung | Priorität | Stufe |
|---|---|---|---|
| L-28.1 | Über Teilen bzw. „Öffnen mit“ wird das **Format automatisch erkannt**: Amazon Seller Central Transaktionsbericht (Datumsbereich) und Abrechnung Flatfile V2 mit Spaltennamen in DE/EN/FR/IT/ES, PayPal Aktivitäten, Shopify Auszahlungen und Bestellungen, Stripe Saldo-Transaktionen | MUSS | B1 |
| L-28.2 | **Eine Zusammenfassung je Monat** („März: 42 Verkäufe 1.230 €, Gebühren 210 € (Reverse Charge), Auszahlung 1.020 €“) und **ein Knopf „Übernehmen“** unten (≥ 56 dp); keine Rückfrage je Zeile | MUSS | B1 |
| L-28.3 | **Bruttoprinzip**: Umsätze getrennt von Gebühren und Werbung; die Auszahlung ist nur Geldtransfer und wird nicht als Einnahme gebucht | MUSS | B1 |
| L-28.4 | Gebühren und Werbung von Amazon EU S.à r.l. (Luxemburg) mit **Reverse Charge** (AT § 19 Abs 1 iVm § 3a Abs 6 UStG 1994; DE § 13b Abs 1/5 UStG), auch beim Kleinunternehmer Steuerschuld ohne Vorsteuerabzug; in der UVA-Auswertung als Reverse-Charge-Kennzahl je Land (`TaxProfile`). PayPal-, Stripe- und Shopify-Gebühren nach Leistendem behandeln, Unsicheres als Prüfpunkt | MUSS | B1 |
| L-28.5 | **Dubletten** über Abrechnungs-/Transaktions-ID still überspringen (eindeutiger Index, neue Migration); **Warnungen**: OSS bei B2C-Fernverkäufen in andere EU-Länder über 10.000 €/Jahr, Lager in anderen Ländern (FBA Pan-EU) | MUSS | B1 |
| L-28.6 | **Datensparsamkeit**: Käuferdaten (Name, Adresse, E-Mail, Telefon) werden nie übernommen; die Spalten werden verworfen, ein Test prüft es | MUSS | B1 |
| L-28.7 | Die Monatsrechnungen von Amazon bleiben **eigene Belege**: Hinweis „Gebührenrechnung aus Seller Central als Beleg ablegen“ mit direktem Link; Anleitung je Plattform im Handbuch mit direktem Link zur Berichtsseite | MUSS | B1 |

### 5.29 Mithelfer-Geräte / Belegsammler

**Entscheidung der Auftraggeberin vom 2026-10-17:** Familienbetriebe nutzen
mehrere Handys. Ein Hauptgerät führt die Bücher; Mithelfer-Geräte sammeln nur
Belege und senden sie verschlüsselt. Kein Anbieter-Server. Volle
Mehrgeräte-Synchronisierung bleibt O-38. Umsetzung 0.23.0: Spezifikation 5.13
(FA-17.1 bis FA-17.8). Real zu prüfen: Spezifikation 14, P-D42, P-R46, P-S65,
P-X20.

| ID | Anforderung | Priorität | Stufe |
|---|---|---|---|
| L-29.1 | **Koppeln per QR-Code** auf dem Hauptgerät (Einstellungen → Mithelfer-Geräte → „Gerät hinzufügen“); der Code trägt Kopplungs-ID, Schlüssel, Betriebsname und Weg. Mithelfer: „Dieses Gerät ist ein Mithelfer-Gerät (koppeln)“ in Schritt 2 der Ersteinrichtung (seit 0.31.0) | MUSS | A |
| L-29.2 | **Mithelfer-Modus nur zum Erfassen:** großer Aufnahmeknopf wie auf dem Hauptgerät, Foto/Datei, kurz Betrag, Lieferant, Datum, Kategorie aus der Texterkennung bestätigen, Kommentar mit Diktat; **keine** Buchung, Rechnung oder Auswertung; Liste der gesendeten Belege mit Status | MUSS | A |
| L-29.3 | Der Mithelfer **bewahrt nichts dauerhaft auf**: Bilder bis zum erfolgreichen Senden, danach gelöscht; nur eine Zusammenfassung ohne Bilder bleibt | MUSS | A |
| L-29.4 | **Zwei Wege je Kopplung:** (a) Messenger oder Mail über das Teilen-Blatt (Standard, ohne Einrichtung), (b) gemeinsamer Cloud-Ordner „Eingang“ des Betriebs; das Hauptgerät liest den Ordner beim Start und bei Rückkehr in die App | MUSS | A |
| L-29.5 | **Eingang** auf dem Hauptgerät: jeder Beleg öffnet im normalen Formular, vorbelegt und „von ‹Gerät›“ markiert; ein Tipp auf Speichern übernimmt; Ablehnen mit Grund; Dubletten (gleiche Kennung) werden erkannt | MUSS | A |
| L-29.6 | **Ende-zu-Ende verschlüsselt** und gegen Veränderung geschützt (AEAD); unbekannte oder getrennte Geräte werden mit klarer Meldung abgelehnt; Trennen wechselt den Schlüssel; der Mithelfer erhält nie Daten des Betriebs | MUSS | A |
| L-29.7 | **Tarif:** Koppeln ist Pro auf dem Hauptgerät; Mithelfer brauchen kein eigenes Abo, keine Gerätegrenze (entschieden 2026-10-17, 14a); ohne Pro nimmt der Eingang bereits gesendete Belege weiter an | MUSS | A |
| L-29.8 | iOS und Android in beliebiger Mischung | MUSS | A |
| L-29.9 | Hinweis: die Inhaberin bleibt für die Buchhaltung verantwortlich; Mithelfer handeln für sie (Handbuch, P-R46) | MUSS | A |
| L-29.10 | **E-Mail als Standardweg** (Entscheidung 2026-10-17, 14a): Hauptgerät empfängt an der Geschäfts-E-Mail (oder per Häkchen an einer anderen Adresse) und liest das Postfach **nur lesend** (IMAP, stündlich und beim Öffnen); der Mithelfer sendet einmal am Tag und beim Öffnen **aus seinem eigenen Postfach** (SMTP, einmalige Einrichtung nur in der Mithelfer-App) ein verschlüsseltes Sammelpaket; Kennwörter nur im sicheren Speicher des jeweiligen Geräts, nie im QR-Code; ohne Postfach tägliche Erinnerung mit Mailfenster; Cloud-Ordner optional, Datei „Exportieren“ als Notweg, WhatsApp nicht mehr beworben. Gesendete Belege bleiben verschlüsselt beim Mithelfer, Standard 90 Tage (einstellbar) – ersetzt L-29.3 für den Mailweg | MUSS | A |
| L-29.11 | Anmeldung über **Google-OAuth** (`gmail.send`) und **Microsoft-OAuth** (Graph `Mail.Send`) statt App-Passwort | KANN | B (offen, O-39) |

### 5.30 Steuerliche Registrierungen in mehreren Ländern

**Entscheidung des Auftraggebers vom 2026-10-18:** Viele Kleinbetriebe sind in
mehreren Ländern umsatzsteuerlich registriert. Beispiel: Spirits by JeNiBarb
e.U. ist in Österreich (Heimat) Kleinunternehmer, verkauft aber über Amazon
FBA mit Lager in Deutschland und hat deshalb eine deutsche USt-Registrierung
(USt-IdNr. DE…, Steuernummer, Finanzamt). Start mit AT und DE, ausgelegt für
weitere EU-Länder. Umsetzung 0.25.0: Spezifikation 5.14 (FA-18.1 bis FA-18.9).
Real zu prüfen: Spezifikation 14, P-S68 bis P-S74, P-X22, P-D45.

| ID | Anforderung | Priorität | Stufe |
|---|---|---|---|
| L-30.1 | In den Stammdaten **„Steuerliche Registrierungen“**: Heimat (Firmenprofil) plus „Weitere Länder“ mit „Land hinzufügen“ (≥ 56 dp); Länderauswahl AT/DE, weitere Länder sichtbar als „bald“ | MUSS | A |
| L-30.2 | Je Registrierung: Land, UID (Formatprüfung je Land), Steuernummer, Finanzamt (freier Text mit Vorschlag), Besteuerungsform (Regelbesteuerung, Kleinunternehmer, EU-Kleinunternehmer-Verfahren), Voranmeldungszeitraum (monatlich, vierteljährlich, jährlich, keine), Dauerfristverlängerung (DE), Beginn/Ende | MUSS | A |
| L-30.3 | Jede Einnahme/Ausgabe hat ein **Steuerland**; Standard Heimat; Auswahl im Formular nur bei mehr als einer Registrierung, ein Tipp zum Wechseln | MUSS | A |
| L-30.4 | Plattformimporte ordnen Verkäufe aus einem Lager im Ausland dem Steuerland mit Registrierung zu (Abgangsland laut Bericht, sonst FBA-Marktplatzland) | MUSS | A |
| L-30.5 | Kennzahlen der Voranmeldung **je Registrierung** (DE-Registrierung → UStVA nur aus DE-Belegen; AT-Kleinunternehmer-Heimat → U30 nur bei Reverse Charge); Gewinnermittlung (E1a/EÜR) bleibt im Heimatland über alle Länder | MUSS | A |
| L-30.6 | Termin-Box: Abgabe- und Zahlungstermine je Registrierung aus den Länderregeln (DE UStVA 10. des Folgemonats, mit Dauerfristverlängerung +1 Monat, DE-Jahreserklärung; AT UVA 15. des zweitfolgenden Monats, U1; OSS vierteljährlich; EU-KU-Meldung) mit Länderkürzel; nur Anzeige | MUSS | A |
| L-30.7 | Keine neue Datenübertragung (Datenflusstabelle 5.19 unverändert) | MUSS | A |
| L-30.8 | Weitere EU-Länder (IT, FR, ES, PL, CZ, NL) als reine Konfiguration im `TaxProfile` | SOLL | B |
| L-30.9 | Innergemeinschaftliches Verbringen (Warenbewegung ins Lager) als eigene Buchung mit Kennzahlen (DE Kz 89/61, AT ZM/U30) | — | entfällt (Entscheidung 2026-10-18, 14a; O-40 geschlossen) |

### 5.31 Abgaben & Rücklagen (Einzelunternehmen)

**Entscheidung des Auftraggebers vom 2026-10-19:** Der Umfang bleibt alles, was
ein **Einzelunternehmen** braucht, einschließlich der Abgaben ans Finanzamt und
der Sozialversicherung. Umsetzung 0.29.0: Spezifikation 5.15 (FA-19.1 bis
FA-19.6). Real zu prüfen: Spezifikation 14, P-S78 bis P-S83, P-R59, P-X25.

| ID | Anforderung | Priorität | Stufe |
|---|---|---|---|
| L-31.1 | Karte **„Rücklage für Steuern & SV“** auf der Übersicht mit empfohlener monatlicher Rücklage und Aufschlüsselung | MUSS | B |
| L-31.2 | Bildschirm **„Abgaben“** (aus Übersicht und „Für das Finanzamt“): Jahresschätzung je Abgabe, bisher bezahlt, offen, Termine | MUSS | B |
| L-31.3 | AT: SVS (PV, KV, Selbständigenvorsorge, UV) mit Mindest-/Höchstbeitragsgrundlage, Hinzurechnung, vorläufige Beiträge der ersten drei Jahre, Hinweis KU-Ausnahme; Einkommensteuer nach Tarif des Jahres mit Grundfreibetrag; ESt-Vorauszahlungen laut Bescheid | MUSS | B |
| L-31.4 | DE: Einkommensteuer § 32a, Solidaritätszuschlag, Kirchensteuer optional, Gewerbesteuer mit Freibetrag, Hebesatz und Anrechnung § 35 EStG, Freiberufler ohne GewSt; Kranken-/Pflegeversicherung als Eingabe laut Bescheid (Entscheidung Prüfinstanz Steuerberater, P-S83) | MUSS | B |
| L-31.5 | Abgabenkategorien; private bzw. nicht abziehbare Abgaben mindern den Gewinn nicht | MUSS | B |
| L-31.6 | Überall gekennzeichnet „Schätzung – ersetzt keine Steuerberatung“ | MUSS | B |
| L-31.7 | Kommunalsteuer, DB, DZ bzw. Lohnabgaben nur als Hinweis „fällt nur mit Dienstnehmern an“ | MUSS | B |
| L-31.8 | Pauschale Betriebsausgaben (AT Basispauschalierung) und investitionsbedingter Gewinnfreibetrag | KANN | C |

### 5.32 Ausbaustufe „Premium Plus“: GmbH und Lohnverrechnung (später)

**Entscheidung des Auftraggebers vom 2026-10-19:** GmbH und Lohnverrechnung
kommen **später** als eigene Stufe „Premium Plus“. Nur Anforderungsumriss, kein
Code.

| ID | Anforderung | Priorität | Stufe |
|---|---|---|---|
| L-32.1 | Dienstnehmer anlegen, monatliche Abrechnung (Brutto-Netto) | KANN | D |
| L-32.2 | AT: ÖGK-Beiträge für Dienstnehmer, Dienstgeberbeitrag (DB), Zuschlag (DZ), Kommunalsteuer, Lohnsteuer, Meldungen über ELDA (An-/Abmeldung, mBGM), Lohnzettel L16 | KANN | D |
| L-32.3 | DE: Lohnsteuer-Anmeldung (ELSTER), Sozialversicherungsmeldungen (DEÜV über sv.net/Lohnprogramm), Beitragsnachweis | KANN | D |
| L-32.4 | GmbH: Körperschaftsteuer, KESt/Kapitalertragsteuer auf Ausschüttungen, Mindest-KöSt (AT), doppelte Buchführung mit Bilanz (L-9.1) | KANN | D |
| L-32.5 | Eigener Tarif „Premium Plus“ über Pro; Lohnverrechnung braucht eigene Prüfung durch Personalverrechnung/Steuerberatung und Softwarezertifizierung (ELDA) | KANN | D |

### 5.33 Schnittstellen zu Buchhaltungsprogrammen der Kanzleien

**Entscheidung des Auftraggebers vom 2026-10-19:** GmbH-Nutzerinnen buchen
Belege in der App und schicken Saldenliste und Belegkopien an die Kanzlei, die
doppelt bucht. Dafür die Standardformate der Kanzleien unterstützen.

| ID | Anforderung | Priorität | Stufe | Stand |
|---|---|---|---|---|
| L-33.1 | DATEV-Buchungsstapel EXTF (Kategorie 21, Version 700) | MUSS | B | vorhanden (8.3), Import P-D50 |
| L-33.2 | Belegbilder zum DATEV-Stapel als ZIP mit Beleg-ID; DATEV Belegbildtransfer ist online (DATEV-Konto) und offline nicht möglich | MUSS | B | ZIP 0.29.0 (FA-15.12) |
| L-33.3 | BMD NTCS Buchungsimport (AT) | MUSS | B | vorhanden (8.4), Import P-D51 |
| L-33.4 | RZL (AT): Importformat prüfen, bis dahin Belegliste/BMD-CSV; eigener RZL-Export **zurückgestellt** (Entscheidung Auftraggeber 2026-10-19) | SOLL | B | zurückgestellt, später P-D52 |
| L-33.5 | Generische CSV-Belegliste | MUSS | B | vorhanden (8.2) |
| L-33.6 | Vorgabe **„Für Kapitalgesellschaft / doppelte Buchführung“**: Saldenliste PDF + Buchungsliste + Belegkopien ZIP | MUSS | B | 0.29.0 (FA-15.12), P-S84, P-D53 |

## 6. Nichtfunktionale Anforderungen

| ID | Anforderung |
|---|---|
| NF-1 | **Offline-first.** Alle Kernfunktionen ohne Netzverbindung nutzbar |
| NF-2 | **Datensparsamkeit.** Keine Analyse-, Tracking- oder Werbebibliotheken. Erhobene Daten verlassen das Gerät nur auf ausdrückliche Handlung des Nutzers. Jede Funktion, die diese Zusage einschränkt — Zweitablage in der Foto-Cloud (L-2.11), Kanalanbindung (L-12) — ist abschaltbar, standardmäßig aus und wird beim Einschalten erklärt |
| NF-3 | **Korrektheit vor Funktionsumfang.** Jede Berechnung mit steuerlicher Wirkung ist durch automatisierte Tests abgedeckt. Beträge werden ganzzahlig in Cent geführt |
| NF-4 | **Nachvollziehbarkeit.** Jede Änderung an gebuchten Daten ist protokolliert |
| NF-5 | **Antwortzeit.** Jede Bedienhandlung reagiert in unter 200 ms; ein Beleg ist in unter 30 Sekunden erfasst |
| NF-6 | **Barrierefreiheit.** Bedienbar mit Screenreader und vergrößerter Schrift; Farbe ist nie der einzige Informationsträger |
| NF-7 | **Sprache.** Oberfläche Deutsch, Zahlen- und Datumsformat nach Firmensitz (de_AT / de_DE). Weitere Sprachen mit weiteren Märkten |
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
| R-4 | DSGVO: siehe Block L-19 |
| R-5 | E-Rechnung nach EN 16931 für den deutschen B2B-Verkehr; Empfangspflicht besteht seit 2025, Versandpflicht gestaffelt bis 2028 |
| R-6 | Als kommerzielles Produkt zusätzlich: Impressum, AGB mit Haftungsbegrenzung (Vorsatz, grobe Fahrlässigkeit und Personenschäden sind nicht ausschließbar), Preisangaben. Bei Store-Abos regeln die Stores Widerruf und stellen die Rechnung an die Käuferin; eigene Widerrufsbelehrung und Kündigungsbutton (§ 312k BGB) erst bei Direktvertrieb |
| R-7 | Das Produkt ist **keine Registrierkasse** nach RKSV und sagt das unmissverständlich |
| R-8 | Das Produkt ist **keine Steuerberatung**; Verantwortung für Buchhaltung und Erklärungen bleibt beim Nutzer |
| R-9 | Alle steuerlichen Grenzwerte im Produkt tragen ihre Fundstelle und werden jährlich überprüft |
| R-10 | **Grenzüberschreitender Verkauf an Privatkunden in der EU** (relevant ab L-12): oberhalb der Lieferschwelle von 10.000 € gilt der Steuersatz des Bestimmungslandes, die Meldung läuft über den One-Stop-Shop. Der Steuerlayer kennt heute nur AT und DE im Inland und ist dafür zu erweitern |
| R-11 | Die Zweitablage von Belegen in der Fotobibliothek (L-2.11) ist in Datenschutzerklärung und Store-Datensicherheitsangaben auszuweisen, sobald sie verfügbar ist |
| R-12 | **Marketing-Modul (L-14):** Auftragsverarbeitungsvertrag nach Art. 28 DSGVO mit dem Anbieter der Inhaltserzeugung; Anpassung von Datenschutzerklärung und Store-Datensicherheitsangaben |
| R-13 | **Werberecht:** erzeugte Inhalte dürfen nicht irreführend sein (UWG). Preis-, Wirkungs- und Vergleichsaussagen verantwortet der Nutzer und müssen von ihm gesetzt sein |
| R-14 | **Kennzeichnung und Urheberrecht** bei erzeugten Bildmitteln: Nutzungsrechte für kommerzielle Verwendung sind nachweisbar zu klären |
| R-15b | **Berufsrechtliche Grenze:** Hilfeleistung in Steuersachen ist den Berufsberechtigten vorbehalten (StBerG in Deutschland, WTBG in Österreich). Das Produkt rechnet und bereitet vor, es berät nicht im Einzelfall |
| ~~R-15~~ | Entfällt mit O-18: keine Postfach-Anbindung |

---

## 8. Schnittstellen

| ID | Schnittstelle | Zweck | Stufe |
|---|---|---|---|
| S-1 | EU-MIAS/VIES | Prüfung von UID-Nummern | A |
| S-2 | iCloud Drive / Google Drive | Sicherung in den Speicher des Nutzers | A |
| S-3 | DATEV, BMD | Übergabe an die Steuerberatung | A |
| S-4 | XRechnung, ZUGFeRD, ebInterface | E-Rechnung | B |
| S-5 | App Store / Google Play Billing | Abonnement und Premium-Services | B |
| S-6 | FinanzOnline-Webservice, ELSTER/ERiC | Elektronische Übermittlung der UVA (Stufe B), der Einkommensteuer (Stufe C) | B |
| S-7 | Kontoauszug als Datei (CSV, CAMT.053) | Kontoumsätze einlesen und Belegen zuordnen — **ohne Server, ohne Bankzugang** (L-18) | B |
| S-8 | Eigenes Backend | **Nicht** für die Synchronisierung (O-29); nur noch Voraussetzung für die Kanalanbindung S-9 bis S-11 und das Marketing-Modul | C |
| S-9 | Amazon Selling Partner API | Verkaufsdaten aus dem Amazon-Seller-Konto | C |
| S-10 | Shopify Admin API | Verkaufsdaten aus dem Shopify-Shop | C |
| S-11 | Google (Merchant Center, zu bestätigen) | Verkaufs- bzw. Produktdaten | C |
| S-12 | Fotobibliothek des Geräts | Zweitablage der Belegfotos in eigenem Album | A |
| S-13 | Anthropic API (Claude), eigenes Konto, über das Marketing-Backend | Marketing-Modul L-14, Rechtsstand-Agent L-20; Auftragsverarbeiter, Verarbeitung USA/global (L-21) | C |
| S-14 | LinkedIn, Instagram | Direktes Veröffentlichen von Werbemitteln (L-14.10) | C |
| ~~S-15~~ | Gmail API | Entfällt (O-18) | — |
| ~~S-16~~ | Microsoft Graph (Outlook) | Entfällt (O-18) | — |
| S-17 | Teilen-Dialog des Betriebssystems | Beleg aus beliebiger App übernehmen (L-15.2) | B |
| S-18 | CSV, DATEV, BMD (lesend) | Übernahme von Altdaten aus der Vorsoftware (L-16.5) | B |

---

## 9. Abgrenzung

Was das Produkt ausdrücklich **nicht** leistet — und warum:

| Nicht enthalten | Begründung |
|---|---|
| Registrierkasse nach RKSV | Signatureinrichtung, Datenerfassungsprotokoll und Jahresbelegmeldung sind ein eigenes, zertifizierungspflichtiges Produkt |
| Browser- und Desktop-Version | Die Zielgruppe arbeitet am Smartphone; eine zweite Oberfläche verdoppelt Pflege und Tests (O-6) |
| Lohnverrechnung | Eigene Domäne mit eigener Haftung und eigenem Pflegeaufwand |
| Steuerberatung im Einzelfall | Das Produkt liefert Zahlen und Hinweise, keine Beratung |
| Vollwertige Warenwirtschaft | Eine schlanke Artikelverwaltung mit Lagerstand ist enthalten (L-11), weil sie das Rechnungschreiben beschleunigt. Was darüber hinausgeht — Stücklisten, Chargen, Seriennummern, Bestellwesen, Lieferantenverwaltung, Mehrlager — ist es nicht |
| Channel-Management | Die Kanalanbindung übernimmt Verkaufsdaten. Artikel und Lagerstände aktiv in die Kanäle zurückzuschreiben und dort zu synchronisieren ist ausdrücklich nicht Teil des Zielbilds (siehe O-10) |
| Auftragsbestätigungen, Lieferscheine | Angebote (L-3.13 ff.) und Rücksendescheine (L-3.20) sind enthalten. Der übrige Vertriebsbelegfluss bleibt fremde Domäne |
| Fremdwährungen | Nur Euro. Märkte außerhalb der Eurozone — auch die Schweiz — sind nicht vorgesehen; sie brächen das gemeinsame Grundmuster an jeder Stelle gleichzeitig |
| Werbekampagnen, Zielgruppenanalyse, Erfolgsmessung | Das Marketing-Modul (L-14) erzeugt Werbemittel. Kampagnensteuerung, Budgetverwaltung und Reichweitenauswertung sind fremde Domänen |
| Revisionssichere Archivierung | Das Produkt ist Vorerfassung; die revisionssichere Aufbewahrung findet in der Buchhaltung der Kanzlei statt |

---

## 10. Ausbaustufen

Die Stufen sind eine **Empfehlung zur Reihenfolge**, keine Einschränkung des
Zielbilds. Der Auftraggeber hat für die erste veröffentlichte Version den vollen
Umfang der Stufen A und B benannt; die Trennung dient der Planbarkeit und der
Möglichkeit, früher Rückmeldung von echten Nutzern zu bekommen.

**Stand 0.11.0:** Teile der Stufe B sind vorgezogen und umgesetzt
(Belegerkennung, E-Rechnung **empfangen**, Zahlungserinnerung und Mahnwesen,
Belegübernahme über den Teilen-Dialog, Plattformexporte als Datei). Aus Stufe A
fehlen noch u. a. Storno-/Korrekturrechnung, Angebote, Artikelverwaltung,
Zweitablage der Belegfotos, Rechtliches-Menü, Sprachdateien und die Store-Reife
(Release-Workflow, Privacy Manifest, Formulare). Einzelstand: Abschnitt 10a.

### Stufe A — veröffentlichungsfähig

Das Produkt ist verkaufbar und löst das Kernproblem. Enthält alles aus Sprint 1
plus: Datensicherung, Storno/Gutschrift, Spracheingabe, UID-Prüfung,
Rechnungsvorschau, Logo, **Artikelverwaltung ohne Bestandsführung** und die
**Zweitablage der Belegfotos**, **Eröffnungswerte beim Einstieg** und der
**Bestätigungsablauf zur Haftungsabgrenzung**; Rechnungsversand per E-Mail ist
bereits enthalten.

**Warum dieser Schnitt:** Datensicherung schließt die einzige echte Lücke des
heutigen Stands. Storno schließt die einzige fachliche Sackgasse. Beides zusammen
ergibt ein Produkt, das man guten Gewissens verkaufen kann.

### Stufe B — vollwertige Buchhaltung

Belegerkennung, E-Rechnung, Saldenliste, rollender Jahresabschluss, UVA- und
Einkommensteuer-Vorbereitung, Abonnement, Belegvorlagen, Zahlungserinnerung,
**Lagerstandsführung, Artikel-Import/Export**, die **Belegübernahme über den
Teilen-Dialog**, der **Altdaten-Import**, die **Rechtstexte samt
Datenschutz-Dokumentation** und die **Rechtsstand-Überwachung (L-20)**.

### Stufe C — Premium und Ausbau

Elektronische Übermittlung an FinanzOnline und ELSTER, doppelte Buchführung mit
Bilanz, Cloud-Synchronisierung mit Konto, Bankabgleich, mehrere Mandanten,
Liquiditätsvorschau, Peppol, **Kanalanbindung an Amazon, Shopify und Google**
samt dem dafür nötigen Backend und der OSS-Erweiterung des Steuerlayers, dazu
das **Marketing-Modul (L-14)** und die **E-Mail-Anbindung (L-15)**.

### Aufwandseinschätzung

Grobe Schätzung in Personenwochen Vollzeitentwicklung, ohne Puffer:

| Block | Stufe | Aufwand |
|---|---|---|
| Datensicherung verschlüsselt inkl. Cloud-Ablage | A | 3–4 |
| Storno- und Gutschriftsrechnung | A | 1–2 |
| Spracheingabe durchgängig | A | 1–2 |
| UID-Prüfung inkl. Protokoll | A | 1–2 |
| Rechnungsvorschau, Logo, Feinschliff | A | 1–2 |
| Artikelverwaltung inkl. Auswahl in der Rechnung | A | 2–3 |
| Zweitablage Belegfotos (Opt-in, eigenes Album) | A | 1 |
| Eröffnungswerte und Anschluss des Nummernkreises | A | 1–2 |
| Bestätigungsablauf und Hinweise an den Wirkstellen | A | 1–2 |
| Store-Reife: Icon, Screenshots, AGB, Impressum, Support | A | 2–3 |
| Angebote inkl. Umwandlung in Rechnung | A | 1–2 |
| Oberflächentexte in Sprachdateien auslagern (L-13.8) | A | 1 |
| Zahlungserinnerung, Erstattung, Kunden-E-Mail als Empfänger | A | 1–2 |
| Fehlerbehebungen aus der Prüfung (Schreibschutz, Nummernkreis, Belegstorno) | A | 1–2 |
| Lokalisierung realistisch statt 1 PW (Prüfinstanz Softwareentwickler) | A | +0,5–1 |
| Puffer 30 % (Prüfinstanz Softwareentwickler) | A | 6–9 |
| Store-Reife: Release-Workflow, Privacy Manifest, targetSdk, Formulare, Rechtliches-Menü (L-22.15 bis L-22.20) | A | 2–3 |
| **Summe Stufe A** | | **25–40** |
| Belegerkennung on-device | B | 3–5 |
| E-Rechnung XRechnung/ZUGFeRD/ebInterface | B | 4–6 |
| Saldenliste und rollender Jahresabschluss | B | 2–3 |
| UVA-Vorbereitung | B | 2–3 |
| Einkommensteuer-Vorbereitung | B | 3–4 |
| Abonnement und Lizenzlogik | B | 2–3 |
| Belegvorlagen, Rücksendeschein, Rechnungsimport | B | 2–3 |
| Lagerstandsführung, Artikel-Import/Export | B | 2–3 |
| Belegübernahme über den Teilen-Dialog | B | 1 |
| Altdaten-Import mit Vorschau, Stapel und Dublettenerkennung | B | 3–4 |
| Anlagevermögen übernehmen, Altunterlagen archivieren | B | 1–2 |
| Rechtstexte und DSGVO-Dokumentation (ohne Anwaltskosten) | B | 1–2 |
| Zeitlich gestaffelte Steuersätze (L-13.5) | B | 1–2 |
| UVA-Übermittlung FinanzOnline/ELSTER inkl. Herstellerregistrierung | B | 3–4 |
| Kontoauszug-Import und Zuordnung | B | 2–3 |
| OSS-Warnung (L-13.9) | B | 1 |
| Rechtsstand-Überwachung: Staffelung, Paket, Pipeline, Validierung (L-20) | B | 6–8 |
| Lizenzmanager, Abo-Seite, Käufe wiederherstellen (L-22.1 bis L-22.11) | B | 2–3 |
| **Summe Stufe B** | | **39–57** |
| **Stufe A + B zusammen** | | **64–97 Personenwochen** |
| Synchronisierung ohne Server: Journal, UUID-Migration, Konflikte, Nummernkreise je Gerät, Schlüssel und Einladung, Rollen, Zugangsentzug, Tests (L-19.12 ff.) | C | 56–83 |
| Backend als Voraussetzung der Kanalanbindung | C | 6–10 |
| Kanalanbindung je Kanal, nur lesend | C | 3–5 |
| OSS-Erweiterung des Steuerlayers | C | 3–4 |
| Marketing-Modul inkl. Auftragsverarbeitung und Freigabeablauf | C | 4–6 |
| Beleg-Eingangsadresse (Backend) | C | 2–3 |

Das entspricht etwa **elf bis siebzehn Monaten** durchgehender Entwicklung.
Der Rückgang gegenüber Version 1.2 geht vollständig auf den Entfall der Schweiz
zurück. Stufe C
kommt in ähnlicher Größenordnung hinzu; allein Backend, drei Kanäle und die
OSS-Erweiterung summieren sich auf 18–29 Personenwochen, bevor eine einzige der
übrigen Stufe-C-Anforderungen umgesetzt ist; das Marketing-Modul kommt mit vier
bis sechs Wochen hinzu.

---

## 10a. Umsetzungsstand

Welche Anforderungen in welcher App-Version umgesetzt sind. Maßgeblich für das
Verhalten ist die Spezifikation; je Version die Release Notes. Nicht genannte
Anforderungen sind offen.

| Version | Umgesetzte Anforderungen | Spezifikation |
|---|---|---|
| 0.1.0 | Sprint 1: Firmenprofil, Belege mit Foto, EÜR, Kleinunternehmer-Ampel, Rechnungen mit PDF, Exporte CSV/DATEV/BMD/USt; Eröffnungswerte (L-16.1, L-16.2, L-16.11), Belegstorno | 5.1 bis 5.6 |
| 0.2.0 | Datensicherung manuell und automatisch (L-7.1 bis L-7.11), Mehrseiten-Belege und Kommentare (L-2.15 bis L-2.18), Bestätigungen (L-17.1 bis L-17.4), App-Sperre (L-22.30), UID-Prüfung, Logo | 5.5a, 5.5b, FA-2.13 ff. |
| 0.3.0 – 0.3.4 | Belegerkennung (L-2.20 bis L-2.23), Fremdwährung (L-2.24 bis L-2.26, L-13.3, L-19.29), mehrsprachige Erkennung, Steuersatz 4,9 % AT ab 1.7.2026 | FA-2.19 bis FA-2.32 |
| 0.3.5 | Wirtschaftsjahr (L-24), Termin-Box (L-25.1 bis L-25.7), bezahlte Rechnung als Einnahme (L-25.9), Hilfe Stufe 1 (L-26.1 bis L-26.5) | 5.6a, 5.8 |
| 0.4.0 | Rabatt, Versand, Skonto, AGB-Verweis (L-3.21 bis L-3.26) | 5.5, GR-12 |
| 0.5.0 | Mahnwesen mit Mahnkosten 10 € (L-3.10, L-3.27 bis L-3.30) | FA-5.21 bis FA-5.25, GR-13 |
| 0.6.0 / 0.7.0 | Einhandbedienung (L-0.6); Beleg mit mehreren Steuersätzen (L-2.27); neue Frist, Mahnsymbol, Sie-Form (L-3.31) | 5.7a, FA-2.33, FA-5.26 bis FA-5.30 |
| 0.8.0 | Kassen- und Zahlungs-QR, Teilen-Ziel Bilder (L-27.1 bis L-27.4) | FA-2.35 bis FA-2.38 |
| 0.9.0 | PDF- und E-Rechnungen übernehmen, Originaldatei mit SHA-256, iOS „Öffnen in“ (L-27.4 bis L-27.6, L-27.8) | FA-2.38 bis FA-2.41 |
| 0.10.0 | Rechnung über Link-QR (L-27.7) | FA-2.42 |
| 0.11.0 | Plattformexporte Amazon, PayPal, Shopify, Stripe (L-28.1 bis L-28.7) | FA-2.43 bis FA-2.49 |
| 0.14.0 | Lizenz und Abo: Tarife Basis/Pro über die Stores (L-10.1, L-10.2, L-22.2), Test über das Einführungsangebot der Stores mit Erinnerung 3 Tage vorher (L-10.3, L-22.3), Daten ohne Abo lesbar und exportierbar (L-10.4, L-7.15, L-22.6), Offline-Gültigkeit 45 Tage (L-10.5, L-22.5), Lizenzmanager (L-22.1), Abo-Seite, Kauf wiederherstellen, Abo verwalten (L-22.7, L-22.8). **Offen:** eigene Signaturprüfung der Kaufbelege (L-22.4, heute durch die Store-Bibliotheken), Verschleierung (L-22.11), Promocodes (L-22.26) | 5.9, FA-13.1 bis FA-13.10 |
| 0.15.0 | Angebote mit eigenem Nummernkreis, Status, PDF und Umwandlung in die Rechnung (L-3.13 bis L-3.17); Artikel ohne Lager, Auswahl und Vorschläge in Rechnung und Angebot (L-11.1, L-11.2, L-11.5, L-11.6, L-11.9, L-11.11) | FA-5.40 bis FA-5.47 |
| 0.27.0 | Test auf allen vier Produkten mit „Pro inklusive in der Testzeit“ (L-10.3, L-22.3), Demo ohne Abo mit Startauswahl (L-10.6) | FA-13.4, FA-13.14, FA-13.15 |
| 0.28.0 | Geführte Ersteinrichtung mit Willkommensseite und Schritten (L-17.1, L-17.2), EU-KU-Nummer (L-30), Mithelfer-Hilfe und Koppeln aus den Einstellungen (L-29) | FA-1.13, FA-1.10, FA-13.15, FA-18.10, FA-17.13, FA-2.5 |
| 0.13.0 | Stornorechnung mit eigener Nummer und „Korrigieren“ (L-3.7; L-3.18 für die vollständige Erstattung, Teilerstattung offen), Menü „Rechtliches“ (L-22.18), Wiederherstellungscode als Druckblatt mit QR-Code und Bestätigung durch zwei Blöcke (L-22.21, L-22.22) | GR-14, FA-5.31 bis FA-5.33, FA-11.4, FA-11.5, FA-7.10 |

Außerdem umgesetzt ohne eigene L-ID: Tablet- und Querformat-Layout
(Spezifikation 5.7), App-Symbol auf dem Startbildschirm (FA-1.19).

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
| A-9 | Jede Oberfläche ist von der UX-Prüfinstanz auf Einhandbedienung geprüft (L-0.6) und auf einem echten Telefon angesehen |
| A-10 | Alle Prüfpunkte der Spezifikation Abschnitt 14 mit „Benötigt vor: Release“ sind bestätigt oder bewusst zurückgestellt |

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
| RK-8 | **Zulassungsverfahren der Kanäle.** Amazon verlangt eine Entwicklerregistrierung mit Freigabeprozess, Shopify eine App-Prüfung. Beides dauert Wochen und ist nicht durch Entwicklungsarbeit abzukürzen | mittel | Registrierung früh anstoßen, mit dem technisch einfachsten Kanal beginnen |
| RK-9 | **Grenzüberschreitende Umsatzsteuer (OSS)** wird bei Kanalverkäufen unterschätzt; falsche Steuersätze je Bestimmungsland führen zu falschen Meldungen | hoch | OSS-Erweiterung als eigene Anforderung (R-10) vor der ersten Kanalanbindung umsetzen |
| RK-10 | **Datenschutzversprechen wird verwässert.** Foto-Zweitablage und Kanalanbindung widersprechen der Zusage „keine Datenübertragung" | mittel | Beides standardmäßig aus, beim Einschalten erklärt, Datenschutzerklärung und Store-Angaben gleichzeitig anpassen |
| RK-11 | **Falscher Lagerstand** führt zu Überverkauf oder falscher Bewertung | mittel | Bestandsführung bleibt bewusst einfach und einkanalig; kein Rückschreiben in die Kanäle (L-12.9) |
| RK-12 | **Datenschutzversprechen bricht am Marketing-Modul.** Es ist das erste Modul, das Geschäftsdaten an einen Dritten gibt | hoch | L-14.5 verbietet die Übertragung von Kundendaten; Modul standardmäßig aus, Auftragsverarbeitungsvertrag vor der ersten Nutzung |
| RK-13 | **Erzeugte Werbung ist rechtswidrig** — irreführende Aussagen, fremde Marken, ungeklärte Bildrechte | mittel | L-14.8 und L-14.9; Freigabe durch den Nutzer ist verpflichtend (L-14.4) |
| RK-17 | **Falsche Entwarnung beim Einstieg.** Ohne Eröffnungswerte rechnet die Grenzwertüberwachung mit null Vorjahresumsatz und meldet „ok", wo sie warnen müsste | hoch | L-16.1 und L-16.2 in Stufe A; bis dahin als bekannte Grenze dokumentiert (O-19) |
| RK-18 | **Fehlerhafter Altdaten-Import** verfälscht die gesamte Buchhaltung rückwirkend und fällt oft erst beim Jahresabschluss auf | hoch | Vorschau vor der Übernahme (L-16.6), Importstapel rücknehmbar (L-16.7), Dublettenerkennung (L-16.8) |
| RK-19 | **Haftungsabgrenzung wird als Freibrief missverstanden.** Sie deckt die steuerliche Würdigung ab, nicht Rechenfehler im Produkt | hoch | Testpflicht für jede steuerwirksame Berechnung (NFA-3); Rechtstexte anwaltlich erstellen (L-17.11) |
| ~~RK-15~~ | Entfällt mit O-18: keine Postfach-Anbindung | — | — |
| ~~RK-16~~ | Entfällt mit O-18: keine Postfach-Anbindung | — | — |
| RK-14 | **Das Marketing-Modul verwässert das Produkt.** Buchhaltung und Werbung sind verschiedene Domänen; ein Modul, das weder gut buchhaltet noch gut wirbt, schadet beidem | mittel | Bewusst Stufe C, nach belegtem Kernnutzen; als eigenständiger Premium-Service kündbar |

---

## 14. Offene Punkte

Zu entscheiden, bevor die betroffene Anforderung umgesetzt wird:

| ID | Offener Punkt | Benötigt für |
|---|---|---|
| ~~O-1~~ | **Erledigt am 2026-10-10:** auch in Österreich darf der Vorjahresumsatz 55.000 € nicht überschritten haben, ohne Toleranz; vom Auftraggeber bestätigt, im Code umgesetzt (Spezifikation 1.4). Schriftliche Bestätigung der Steuerberatung zu Brutto/Netto und ausgenommenen Umsätzen bleibt empfohlen | erledigt |
| ~~O-2~~ | **Entschieden am 2026-10-15:** Produkt- und App-Name **„JeNi bucht“** (genau diese Schreibweise), nach Markenrecherche ohne Befund (O-25). Frühere Arbeitstitel „Jenny Bar“ und „Jenni bucht“ entfallen. Die technische Kennung (Bundle-ID/applicationId) bleibt vorerst `at.jesenko.buchhaltung`, siehe O-33 | erledigt |
| ~~O-3~~ | **Entschieden am 2026-10-10:** Basis 14,90 € (Rabatt 12,90 €), Pro 24,90 € (Rabatt 19,90 €), Jahresabo mit 20 % Rabatt; Details in Abschnitt 5.10 | erledigt |
| ~~O-22~~ | **Entschieden am 2026-10-09:** (a) UVA-Übermittlung in den Buchhaltungstarif, Stufe B (L-6.5); (b) Start mit Datei-Import der Kontoauszüge, Live-Anbindung später als Opt-in (L-18); (c) Angebote aufgenommen, Stufe A (L-3.13 ff.) | erledigt |
| ~~O-4~~ | **Entschieden am 2026-10-10:** 14 Tage gratis alles, danach Basis, optional Pro; Funktionsschnitt in Abschnitt 5.10 | erledigt |
| ~~O-5~~ | **Entschieden am 2026-10-09:** Entwicklung fortlaufend ohne feste Wochenstunden; Planung nach Stufen, nicht nach Kalenderdaten | erledigt |
| ~~O-6~~ | **Entschieden am 2026-10-10:** nur Android und iOS (Smartphone und Tablet); keine Browser- oder Desktop-Version | erledigt |
| ~~O-7~~ | **Entschieden am 2026-10-10:** Start nur auf Deutsch; mit jedem EU-Land dessen Landessprache (L-13.6), Texte dafür von Anfang an übersetzbar (L-13.8) | erledigt |
| ~~O-8~~ | **Entschieden am 2026-10-09:** Support per E-Mail, Antwort innerhalb von 3 Werktagen; FAQ in der App; Chatbot in einer späteren Version. **Keine Website** — siehe O-24 | erledigt |
| ~~O-9~~ | **Entschieden am 2026-10-09:** eigene Steuerberatung, ab sofort eingebunden; erster Auftrag ist O-1 | erledigt |
| ~~O-10~~ | ~~Übertragungsrichtung der Kanalanbindung~~ — **entschieden am 2026-10-09:** ausschließlich lesend, Bestellungen und Rechnungen, keine Lagerverwaltung (L-12.9) | erledigt |
| ~~O-11~~ | ~~Was ist mit „Google" gemeint?~~ — **entschieden am 2026-10-09:** Google Merchant Center | erledigt |
| ~~O-12~~ | **Entschieden am 2026-10-10:** zum Start nur Warnung vor der OSS-Lieferschwelle (L-13.9, Stufe B); volle OSS-Unterstützung (L-13.7) später je nach Nachfrage | erledigt |
| ~~O-13~~ | **Entschieden am 2026-10-10:** Einkaufspreis als freiwilliges Feld mit Rohertragsanzeige (L-11.12, Stufe B) | erledigt |
| O-14 | **Welche europäischen Märkte als nächste**, und in welcher Reihenfolge? Davon hängt ab, ab wann eine mehrsprachige Oberfläche gebraucht wird. **Vertagt am 2026-10-10:** Entscheidung nach dem Start in AT/DE anhand der Nachfrage | nach Release Stufe A/B |
| ~~O-15~~ | ~~Schweiz zum Start oder als erste Erweiterung?~~ — **entschieden am 2026-10-09:** die Schweiz entfällt, Fokus auf EU und Eurozone | erledigt |
| O-15b | **Welcher Dienst erzeugt die Marketing-Inhalte?** (früher doppelt als O-15 vergeben) Davon hängen Auftragsverarbeitungsvertrag, Kosten je Erzeugung und die Frage ab, ob der Betrieb in der EU erfolgt | Stufe C |
| ~~O-16~~ | Mit O-4 erledigt: es gibt keine einzeln buchbaren Module; das Marketing-Modul ist Teil von Pro | erledigt |
| O-17 | Sollen erzeugte Werbemittel versioniert und wiederverwendbar abgelegt werden, oder sind sie Wegwerfware? | Stufe C |
| ~~O-19~~ | **Behoben am 2026-10-09** (Umsatzanteile von L-16.1, L-16.2, L-16.11). Ursprünglich: **Bekannter Fehler:** Die Grenzwertüberwachung ermittelt den Vorjahresumsatz ausschließlich aus erfassten Belegen. Für einen neuen Nutzer ist er damit null, und die Ampel steht fälschlich auf Grün — in Deutschland entscheidet er über das ganze laufende Jahr. Behebung über L-16.1/L-16.2 | sofort; betrifft bestehenden Code |
| ~~O-25~~ | **Erledigt am 2026-10-15:** Markenrecherche zu „JeNi bucht“ abgeschlossen, ohne Befund. Markenanmeldung, Domain und Store-Eintrag folgen (Spezifikation 14, P-R7) | erledigt |
| O-26 | **Rechtsform und Absicherung des Anbieters.** **Entschieden 2026-10-12:** Start als Spirits by JeNiBarb e.U. (FN 643550 y, ATU81604346); Umwandlung in eine GmbH, sobald die Umsätze die Einzelunternehmerregelung übersteigen. **Haftpflicht (Vermögensschaden- und Produkthaftpflicht, P-R8): verschoben bis Launch** (Entscheidung 2026-10-15); Schritt 13a in `STORE_READINESS.md` vor der Einreichung | Launch |
| O-27 | **Laufende Kosten der Rechtsstand-Überwachung:** API-Kosten des Agenten (Annahme 30–90 €/Monat) und Bereitschaft plus Freigaben der Steuerberaterin (0,5–2 h je Änderung). Angebot einholen | vor Stufe B |
| ~~O-28~~ | **Entschieden am 2026-10-10:** direkt Anthropic API, ein eigenes neues Konto. EU-Verarbeitung von den Prüfinstanzen geprüft: nicht vorgeschrieben; Buchhaltungsdaten und Belege dürfen trotzdem nicht über die US-Route laufen (L-21.8 bis L-21.12) | erledigt |
| ~~O-29~~ | **Entschieden am 2026-10-10:** Sicherung und Synchronisierung bleiben in der Cloud der Nutzerin; kein Server und kein Konto beim Anbieter. Mehrere Geräte und mehrere Personen über gemeinsamen Ordner (L-19.12 ff.) | erledigt |
| ~~O-30~~ | **Entschieden am 2026-10-15:** E-Mail und Telefon werden **nur auf Form geprüft**, nicht verifiziert (kein Server, kein SMS-Dienst, passt zu O-29); die Nutzerin kann die Angaben jederzeit ändern. Umgesetzt in 0.12.0 (Spezifikation FA-1.4f) | erledigt |
| ~~O-31~~ | **Anbieterexklusive Verschlüsselung zur Kundenbindung?** Frage des Auftraggebers vom 2026-10-12, von den drei Prüfinstanzen verneint: Aufbewahrungs- und Prüfpflichten (§ 147 AO, § 131/132 BAO) nach Kündigung oder Wegfall des Anbieters nicht erfüllbar, AGB- und UWG-Risiko, technisch ohne Server wirkungslos. Bindung über Funktionen, Komfort und Importe; Produktschutz über Marke, Lizenzprüfung, Obfuskierung (L-7.12 bis L-7.16) | Empfehlung abgegeben |
| O-32 | **Anbieter-Server für Plattform-Connectoren** (Stufe B2: echte Schnittstellen zu Amazon, Booking & Co. statt Teilen/PDF/Link): zurückgestellt am 2026-10-14, mit der KI-Server-Frage (L-26.6, L-21) gemeinsam zu entscheiden | Stufe B2 |
| ~~O-34~~ | **Entschieden am 2026-10-15:** Pro umfasst mindestens Belegerkennung, Import aus Fremdplattformen (Amazon, PayPal, Shopify, Stripe) und das Auslesen von E-Rechnungen (ZUGFeRD, XRechnung, ebInterface), direkte Übermittlung an das Finanzamt, PDF senden von Rechnungen und Stornorechnungen, Logo auf Angeboten und Rechnungen, Senden von Zahlungserinnerungen und Mahnungen, „Kurs abrufen“. Ansehen, PDF speichern/drucken, Export, Sicherung bleiben in jeder Stufe frei (L-10.4). Umgesetzt: Spezifikation FA-13.2, FA-13.11 | erledigt |
| ~~O-35~~ | **Überholt durch O-42 (2026-10-19).** Bisher entschieden am 2026-10-15: Test nur auf Pro als Einführungsangebot der Stores: Abschluss von Pro mit 14 Tagen gratis, danach automatisch kostenpflichtig; in den 14 Tagen kostenlos kündbar oder Wechsel auf Basis. Kein eigener Basis-Test, kein App-Test. Text auf Abo-Seite und im Store: „14 Tage kostenlos, danach ‹Preis› pro Monat, jederzeit vorher kündbar“ | erledigt |
| ~~O-33~~ | **Umgesetzt am 2026-10-19 (App-Version 0.26.0, Freigabe Auftraggeber):** Kennung ist `at.jenibarb.jenibucht`. Bisher: **Bundle-ID für den Store festlegen** (Vorschlag `at.jenibarb.jenibucht`). Heute `at.jesenko.buchhaltung`; ein Wechsel erzwingt auf Testgeräten eine Neuinstallation (Daten vorher sichern) und ist nach der ersten Store-Einreichung nicht mehr möglich. **Entschieden 2026-10-15:** Wechsel auf `at.jenibarb.jenibucht` unmittelbar vor der ersten Store-Einreichung (bis dahin alte Kennung, damit Testgeräte ohne Neuinstallation aktualisieren); Umstellung mit dem vorbereiteten Skript `tool/release/bundle_id_wechsel.sh` | erledigt |
| O-36 | **Direkte Übermittlung ans Finanzamt (L-6.5), nächster Schritt:** (a) DE: ELSTER-Hersteller-ID beantragen (ERiC-Entwicklerbereich, https://www.elster.de/elsterweb/softwareprodukt) – **Antrag als Softwarehersteller von der Auftraggeberin am 2026-10-16 gestellt; Status: beantragt, Antwort ausstehend** – Voraussetzung für jede UStVA-Übermittlung aus der App; ERiC ist eine native Bibliothek je Plattform und braucht das Zertifikat der Nutzerin. (b) AT: Webservice-Übermittlung über FinanzOnline (Webservice-Benutzer der Nutzerin, Hersteller-UID) erst nach erfolgreichem Testupload der U30-Datei (Spezifikation P-D35) und Prüfung P-R5. Stand 0.17.0: Kennzahlen zum Kopieren (AT/DE) und U30-Datei zum Hochladen (AT) | Stufe B |
| O-37 | **ELSTER-Übermittlungsserver (DE) nach dem Launch:** ERiC gibt es nur für Windows, Linux und macOS, nicht für Android/iOS; direkte UStVA/EÜR-Übermittlung aus der App braucht daher einen Anbieter-Server. Skizze: verwalteter Container (kein eigenes Betriebssystem) bei einem Cloud-Anbieter mit Rechenzentrum in der EU; zustandslos – Meldung kommt verschlüsselt vom Gerät, wird an ELSTER weitergereicht, nichts wird gespeichert (weder Daten noch Zertifikat); grob 10–30 €/Monat. Beim Anbieter verbleiben trotz Cloud: Rolle als Auftragsverarbeiter (AVV mit dem Cloud-Anbieter, Datenschutzerklärung, Store-Angaben, Eintrag in 5.19), ERiC-Updates, Sicherheit des eigenen Codes, Haftung, ELSTER-Herstellerpflichten. Bis dahin: Kennzahlen zum Kopieren in „Mein ELSTER“ (FA-Stand 0.17.0). **Vertagt am 2026-10-16 durch die Auftraggeberin:** erst nach dem Launch und wenn genügend deutsche Nutzerinnen auf der Plattform sind; gemeinsam mit O-32 und der KI-Server-Frage betrachten | nach dem Launch |
| O-39 | **OAuth für den Mailweg** (L-29.11): Gmail und Microsoft 365/Outlook.com ohne App-Passwort. **To-dos Auftraggeberin:** (1) Google Cloud-Projekt anlegen, OAuth-Zustimmungsbildschirm mit Datenschutzerklärung auf eigener Domain, Bereich `gmail.send` (eingeschränkt) beantragen, OAuth-Verifizierung inkl. Sicherheitsprüfung (CASA) durchlaufen; (2) Azure-App-Registrierung (Microsoft Entra ID, „Konten in beliebigen Organisationen und persönliche Microsoft-Konten“), Berechtigung Graph `Mail.Send` (delegiert), Publisher Verification. Kosten und Pflichten: P-R48. Bis dahin App-Passwort (Gmail, iCloud) bzw. Kennwort | vor Store-Release offen |
| O-40 | **Innergemeinschaftliches Verbringen** (L-30.9): **geschlossen 2026-10-18** – Entscheidung der Auftraggeberin (14a): Verbringen ins Auslandslager wird nicht in der App gebucht, nur die Verkäufe aus dem Lager; die App warnt in „Für das Finanzamt“, dass DE Kz 89/61 (bzw. AT Kz 070/072/065) die Kanzlei ergänzt (Spezifikation FA-18.4, Grenze 11, P-S68) | erledigt |
| O-43 | **Tarif „Abgaben & Rücklagen“** (L-31): **Pro** (Rechenhilfe mit Mehrwert, passt zu Saldenliste/Jahresabschluss); Buchungen in Abgabenkategorien bleiben in jedem Anspruch normale Buchungen | entschieden 2026-10-19 – umgesetzt 0.30.0 |
| ~~O-42~~ | **Entschieden am 2026-10-19 (Auftraggeber), ersetzt O-35:** (A) Die Kundin wählt und startet ein Abo (Basis oder Pro, monatlich/jährlich) im Store; **alle vier Produkte** haben ein Einführungsangebot 14 Tage kostenlos, Kündigung in den 14 Tagen kostet nichts. Bei Basis gibt die App in den ersten 14 Tagen des ersten Abos alle Pro-Funktionen frei („Pro inklusive in der Testzeit“), danach Basis, Daten bleiben; Hinweis 3 Tage vorher „Noch X Tage Pro inklusive – danach Basis. Jetzt auf Pro wechseln?“. Pro bleibt Pro. Text: „14 Tage kostenlos testen – mit allen Pro-Funktionen. Danach gilt dein gewähltes Abo (Preis aus Store). Jederzeit vorher im Store kündbar.“ (B) **Demo ohne Abo** mit eigener Muster-Datenbank, nichts speichern, Wasserzeichen „MUSTER – DEMO“, Band „DEMO – Abo wählen, um mit deinen eigenen Daten zu starten“ (L-10.6). (C) „Store-Test nur auf Pro“ entfällt, ein App-eigener Test bleibt verworfen. Umgesetzt in 0.27.0: Spezifikation FA-13.4, FA-13.5, FA-13.14, FA-13.15; Store-Einrichtung `STORE_ANMELDUNG.md` Formular 4 | erledigt |
| O-41 | **Nächstes Land** (L-30.8): Empfehlung der [Länderanalyse](LAENDERANALYSE.md) vom 2026-10-18 – zuerst **Frankreich als weiteres Steuerland** (Registrierung für ein FBA-Lager, nur `TaxProfile` mit Sätzen, CA3 und Terminen), danach **Niederlande als erstes neues Heimatland** (keine E-Rechnungs- oder Kassenpflicht); Italien trotz größtem Markt erst später wegen SDI-Pflicht (braucht Server bzw. Vermittler). Vor Umsetzung die dort markierten Punkte („vor Umsetzung prüfen“) klären und in Spezifikation 14 aufnehmen | Entscheidung Auftraggeberin |
| O-38 | **Volle Mehrgeräte-Synchronisierung** (Weg 2 Cloud-Ordner mit Änderungsjournal nach L-19.15 ff. bzw. Weg 3 Anbieter-Server): nach dem Launch bei genügend Nutzerinnen, gemeinsam mit O-32/O-37 zu entscheiden. Bis dahin Mithelfer-Geräte als Einbahn (5.29) | nach dem Launch |
| O-20 | Welche Vorsoftware-Formate sind beim Import vorrangig zu unterstützen? Richtet sich nach dem, womit die ersten Nutzer tatsächlich kommen | Stufe B |
| ~~O-21~~ | **Vorläufig beantwortet am 2026-10-10 (Prüfinstanz Rechtsanwalt):** BFSG/BaFG voraussichtlich nicht anwendbar (B2B, Kleinstunternehmen). Grundbarrierefreiheit trotzdem als NF-Anforderung; Bestätigung siehe Spezifikation Abschnitt 14, P-R3 | erledigt |
| ~~O-23~~ | **Entschieden am 2026-10-09:** wählbar je Rücksendung über den Schalter „Ware wieder verkaufbar?" (L-3.20) | erledigt |
| ~~O-24~~ | **Entschieden am 2026-10-09:** eigene Einzelseite auf einer neuen Domain, die mit dem Produktnamen festgelegt wird (L-17.12) | erledigt |
| ~~O-18~~ | **Entschieden am 2026-10-09:** nur Versand über die Mail-App des Smartphones; keine Gmail- oder Microsoft-365-Anbindung, L-15.4 bis L-15.9 entfallen | erledigt |

### 14a. Entscheidungen der Auftraggeberin

Übersicht der Produktentscheidungen seit 2026-10-12, damit sie nicht nur in der
Historie stehen. Die Einzelheiten stehen an der genannten Stelle.

| Datum | Entscheidung | Fundstelle |
|---|---|---|
| 2026-10-12 | Rechtsform zum Start: Spirits by JeNiBarb e.U., später GmbH | O-26 |
| 2026-10-12 | App-Sperre SOLL/A; iCloud-Ordner in der Dateien-App MUSS | L-22.30, L-7.20 |
| 2026-10-12 | Belegerkennung Android mit Google ML Kit (gebündelt); Fremdwährung nur bei Eingangsbelegen, gebucht in Euro | L-2.20, L-2.24 |
| 2026-10-14 | **Leitprinzip Einfachheit** als fundamentale Anforderung | 2.1a |
| 2026-10-14 | **Belege gelten immer als betrieblich**, keine Rückfrage | L-0.4 |
| 2026-10-14 | **Einhandbedienung ohne Händigkeits-Einstellung** | L-0.6 |
| 2026-10-14 | Wirtschaftsjahr als Profileinstellung; USt und Kleinunternehmergrenze bleiben Kalenderjahr | 5.24 |
| 2026-10-14 | Termin-Box nur als Anzeige, ohne Benachrichtigungen | 5.25 |
| 2026-10-14 | Hilfe Stufe 1 offline; KI-Hilfe erst nach Server-Entscheidung | 5.26, O-32 |
| 2026-10-14 | Mahnkosten 10 € je Mahnung ab der 1. Mahnung | L-3.27 |
| 2026-10-15 | ~~Test über den Store nur auf Pro~~ (überholt 2026-10-19 durch O-42) | O-35, L-22.3 |
| 2026-10-15 | **Pro-Umfang:** Belegerkennung, Import (Plattformen, E-Rechnung auslesen), Finanzamt-Übermittlung, PDF senden (Rechnung, Storno), Logo, Mahnungen senden, Kurs abrufen; Ansehen, Speichern/Drucken, Export, Sicherung immer frei | O-34, 5.10 |
| 2026-10-15 | **Produkt- und App-Name „JeNi bucht“**; Bundle-ID bleibt vorerst | O-2, O-25 |
| 2026-10-15 | **Bundle-ID `at.jenibarb.jenibucht`**, Wechsel vor der ersten Store-Einreichung | O-33 |
| 2026-10-15 | Haftpflicht auf den Launch verschoben | O-26 |
| 2026-10-15 | E-Mail und Telefon nur Formatprüfung, keine Verifizierung | O-30 |
| 2026-10-15 | Store-Text kündigt das Abo mit „14 Tage kostenlos testen“ an, mit Folgepreis, ohne Streichpreise | O-4, `STORE_LISTING.md` |
| 2026-10-14 | Kundendokumente immer in Sie-Form (App-Oberfläche duzt) | L-3.31 |
| 2026-10-14 | Codes, PDF, E-Rechnungen, Link-QR und Plattformexporte umsetzen; iOS über „Öffnen in …“ statt Share Extension | 5.27, 5.28 |
| 2026-10-14 | Echte Plattform-Schnittstellen (Anbieter-Server) zurückgestellt | O-32 |
| 2026-10-14 | Testbuilds ohne Git-Tag; Release Notes nennen den Commit-Hash | RELEASE_PLAYBOOK |
| 2026-10-16 | „PDF senden“ in Basis als weiche Sperre (Abo-Seite, danach Speichern/Drucken) bleibt so | 5.10, Spez. FA-13.11 |
| 2026-10-16 | E-Rechnung **auslesen** Pro, **speichern** am Beleg in Basis genügt: Empfang per E-Mail reicht, Punkt erledigt | 5.10, L-4.3 |
| 2026-10-16 | **Promo-Code „JENIBUCHT2M“**: 2 Monate Pro gratis für Neukundinnen, beworben auf Instagram; wie der Test über die Stores (Apple-Angebotscode, Google-Play-Promo-Code), danach kostenpflichtig, vorher kostenlos kündbar oder Wechsel auf Basis; kein eigener Server | L-22.3, Spez. FA-13.13, `STORE_LISTING.md` |
| 2026-10-16 | **Logo im Onboarding ohne Abo-Seite wählbar**; gedruckt nur mit Pro oder im 14-Tage-Test. Danach mit Basis oder ohne Abo nicht auf neuen Rechnungen und Angeboten; gestellte behalten ihr eingefrorenes Logo; die Datei bleibt und kommt mit Pro zurück; Stammdaten zeigen „Logo (Pro) – wird mit Basis nicht gedruckt“ | L-1.7, 5.10, Spez. FA-13.12 |
| 2026-10-16 | **Anlagen nur Pro:** Investitionen aktivieren, AfA-Plan und Anlagenverzeichnis neu anlegen, ändern, ausscheiden nur mit Pro (wie Saldenliste und vorläufiger Jahresabschluss). Bereits erfasste Anlagen bleiben in jedem Abo ansehbar, ihr Anlagenverzeichnis exportierbar, ihre jährliche AfA wird nach einer Herabstufung weiter gebucht. Ohne Pro zählt eine Ausgabe voll als Betriebsausgabe; über der GWG-Grenze zeigt der Beleg einen Hinweis „muss aktiviert werden“ mit „(Pro)“. **Bewusste Abweichung** von der Regel in 5.10 („gesetzliche Pflicht nie nur in Pro“), gemildert durch Datenzugang und Hinweis; Prüfung P-S64, P-R43 | 5.10, Spez. FA-13.2, FA-15.1 |
| 2026-10-16 | **Vertragsarchiv in Basis und Pro**; Auslesen (Texterkennung, Kurzübersicht) nur Pro | 5.23, Spez. FA-13.2, FA-16.3 |
| 2026-10-16 | **Bewirtung automatisch gekürzt:** Kategorie „Bewirtung“ zählt ertragsteuerlich nur anteilig – AT 50 % (§ 20 Abs 1 Z 3 EStG, Regelfall Werbezweck), DE 70 % (§ 4 Abs 5 Satz 1 Nr. 2 EStG); Vorsteuer je Land nach Prüfinstanz (AT und DE voll); Kleinunternehmer: brutto × Anteil; nicht abziehbarer Teil in allen Auswertungen und Exporten; DE Anlass und Teilnehmer als freiwillige Felder; Belegerkennung schlägt Bewirtung für Restaurants vor. Schließt die Grenze zu P-S46 | L-2.27, Spez. FA-2.60, P-S46 |
| 2026-10-16 | **ELSTER-Softwarehersteller beantragt** (Antwort ausstehend) | O-36 |
| 2026-10-16 | **Wunsch oder Idee senden** in den Einstellungen: kurzes Formular, Versand über die Mail-App der Nutzerin an office@jenibarb.com, kein eigener Server, technische Angaben abschaltbar (Standard an) | L-26.7, Spez. FA-11.6 |
| 2026-10-17 | **Mithelfer-Geräte / Belegsammler** (Familienbetriebe): Koppeln per QR, Mithelfer nur Erfassen, Wege Messenger/Mail und gemeinsamer Ordner, Eingang mit Übernehmen; **Pro auf dem Hauptgerät**. Mithelfer-Geräte ohne eigenes Abo | 5.29, Spez. 5.13, O-38 |
| 2026-10-17 | **Bestätigt:** Mithelfer-Geräte brauchen **kein eigenes Abo**; **keine Gerätegrenze** | L-29.7 |
| 2026-10-17 | Neue Startkategorie **„Material und Werkzeug“** (Ausgabe); Baumarkt-Belege schlagen sie statt „Sonstige Ausgaben“ vor; bestehende Datenbanken erhalten sie per Migration | Spez. FA-2.31, P-S66 |
| 2026-10-18 | **Verbringen nicht in der App** (O-40): Ware ins Lager im Ausland (z. B. Amazon FBA) wird nicht gebucht; gebucht werden nur die Verkäufe aus dem Lager an Endkunden. Das Verbringen (ig. Lieferung/Erwerb) erledigt die Nutzerin bzw. ihre Kanzlei außerhalb der App; die App weist darauf hin | L-30.9, O-40, Spez. Grenze 11, FA-18.4 |
| 2026-10-18 | **Rechnungen immer im Heimatland besteuert**, unabhängig vom Land der Kundin (AT-Unternehmen → AT, DE-Unternehmen → DE); kein Steuerland-Chip auf Rechnungen | 5.30, Spez. Grenze 11 |
| 2026-10-18 | **Auslandsregistrierungen nur für die UID** (z. B. für ein Amazon-Lager), ohne Betriebsstätte; mehrere Länder möglich (jetzt DE, später FR, ES u. a.) | 5.30, P-S74, O-41 |
| 2026-10-18 | **Steuerliche Registrierungen in mehreren Ländern** (Auftrag): Heimat plus weitere Länder in den Stammdaten, Steuerland je Buchung, Importzuordnung FBA, Kennzahlen und Termine je Registrierung; Ertragsteuer bleibt im Heimatland. Start AT/DE, weitere Länder „bald“ | 5.30, Spez. 5.14, O-40 |
| 2026-10-17 | **Belegsammler per E-Mail als Standardweg:** Hauptgerät empfängt an der Geschäfts-E-Mail (Häkchen „Andere E-Mail-Adresse für den Empfang von Belegen“ wie bei einer abweichenden Rechnungsadresse) mit nur lesendem Postfachzugriff; der Mithelfer meldet sich **nur in der Mithelfer-App mit seinem eigenen Postfach** an und sendet einmal am Tag gesammelt; Cloud-Ordner optional, Datei-Export als Notweg, WhatsApp nicht mehr beworben; Google-/Microsoft-OAuth als offener Punkt | L-29.10, L-29.11, O-39, Spez. FA-17.9 ff. |
| 2026-10-16 | **Diktat auf dem Gerät** in Freitext- und Betragsfeldern (Auftrag); **entschieden 2026-10-16: in Basis und Pro** (Barrierefreiheit), keine Sperre | Spez. FA-2.61 |
| 2026-10-19 | **Test 14 Tage auf allen vier Abo-Produkten**; Basis in der Testzeit mit allen Pro-Funktionen, danach Basis; Hinweis 3 Tage vorher mit einem Tipp zu Pro | O-42, L-10.3, L-22.3 |
| 2026-10-19 | **Demo ohne Abo** mit eigener Muster-Datenbank, nichts speichern, Wasserzeichen auf PDFs, Teilen und Export gesperrt; Startauswahl „Abo wählen“ / „Erst ansehen (Demo)“ | O-42, L-10.6 |
| 2026-10-19 | „Store-Test nur auf Pro“ entfällt; App-eigener Test bleibt verworfen | O-42 (ersetzt O-35) |
| 2026-10-19 | **Geführte Ersteinrichtung**: Willkommensseite mit Logo (austauschbare Datei), „Los geht's“, „Erst ansehen (Demo)“, Sicherung wiederherstellen, Gerät koppeln; Schritte Bestätigungen – Unternehmen (Pflicht) – Zusatzdaten – Extras – Abo (im Testbuild ohne); Fortschritt, Zurück, „Später hinzufügen“, Fortsetzen nach dem Schließen; Startauswahl entfällt | L-17.1, L-17.2, Spezifikation FA-1.13, FA-13.15 |
| 2026-10-19 | Bestätigungen so knapp wie rechtlich zulässig (Prüfinstanz Rechtsanwalt): Häkchen „Keine Steuerberatung“ plus Knopf „Akzeptieren und weiter“ für Nutzungsbedingungen/Datenschutz | L-17.2, FA-1.10, P-R58 |
| 2026-10-19 | **EU-KU-Nummer (EX)** beim EU-Kleinunternehmer-Verfahren: eigenes Feld, getrennt von der UID, Formatprüfung, auf Rechnungen ins andere Land | L-30, FA-18.10, P-S76, P-S77 |
| 2026-10-19 | Belegfeld „Beschreibung“ heißt „Produkt oder Leistung“; Exportspalten bleiben unverändert | FA-2.5 |
| 2026-10-19 | Mithelfer: „?“-Erklärung neben „Gerät koppeln“/„Gerät hinzufügen“; „Als Mithelfer-Gerät koppeln“ in den Einstellungen eines Hauptgeräts (nur ohne Belege, mit Bestätigung) | L-29, FA-17.13 |
| 2026-10-19 | Demo zeigt in jeder Liste Musterdaten; Musterfirma ist Kleinunternehmerin AT (Ampel ≈ 27 %) mit DE-Registrierung; Musterverträge Mietvertrag Lager, Leasing, Dienstvertrag Teilzeitkraft | L-10.6, Spezifikation FA-13.14 |
| 2026-10-19 | Vertragsarchiv sichtbar: „Belege | Verträge“ und Einstellungen → Verträge; Dienstvertrag mit Datenschutzhinweis, nie KI-Übertragung | L-23, L-23.8, FA-16.9 |
| 2026-10-19 | Umfang bleibt Einzelunternehmen inkl. Abgaben ans Finanzamt und Sozialversicherung; „Abgaben & Rücklagen“ gebaut (0.29.0), Tarif-Vorschlag Pro offen | 5.31, O-43 |
| 2026-10-19 | GmbH und Lohnverrechnung (ÖGK für Dienstnehmer, DB, DZ, Kommunalsteuer, Lohnsteuer, ELDA) später als Stufe „Premium Plus“ | 5.32 |
| 2026-10-19 | GmbH-Nutzerinnen: Belege buchen, Saldenliste und Belegkopien an die Kanzlei; Standardschnittstellen DATEV, BMD, RZL, CSV und Vorgabe „Für Kapitalgesellschaft / doppelte Buchführung“ | 5.33 |
| 2026-10-19 | „Abgaben & Rücklagen“ nur Pro; ohne Pro Hinweis „(Pro)“ zur Abo-Seite, Basis in der Testzeit mit Pro inklusive, Demo zeigt es; Abgabenbuchungen bleiben in jedem Abo normale Buchungen | O-43, FA-19.1 |
| 2026-10-19 | RZL-Export jetzt nicht; zurückgestellt | L-33.4, P-D52 |
| 2026-10-19 | PDF-Betrachter in der App: jedes erzeugte PDF und PDF-Anhänge vor dem Senden/Drucken ansehen; Drucken über den Systemdialog in jedem Abo, Senden wie bisher Pro | FA-5.48, FA-13.11 |
| 2026-10-19 | Willkommensseite: Unterzeile „… nach den Regeln, die auch Profis anwenden“ (statt „mit der Qualität von Profis“, UWG) und vier Funktionszeilen | FA-1.13, P-R60 |

---

**Entscheidung 2026-10-16 (Dokumentenscanner):** Belege und Verträge werden mit dem Scanner des Systems erfasst (Android ML Kit Document Scanner, iOS VisionKit); gespeichert wird **nur das verarbeitete Bild**; ohne Scanner automatisch die Kamera. Umgesetzt in 0.20.0 (Spezifikation FA-2.51, Prüfpunkt P-S63).

## 15. Änderungshistorie

| Version | Datum | Änderung |
|---|---|---|
| 1.84 | 2026-10-19 | Rückmeldung zu 0.30.0: Mithelfer-Koppeln als Nebenoption in Schritt 2 der Ersteinrichtung statt auf der Willkommensseite (L-29.1). |
| 1.83 | 2026-10-19 | Entscheidungen des Auftraggebers vom 2026-10-19 (14a): O-43 entschieden (Pro), RZL-Export zurückgestellt (L-33.4), PDF-Betrachter, Willkommensseite |
| 1.82 | 2026-10-19 | Entscheidungen des Auftraggebers vom 2026-10-19 (14a): 5.31 Abgaben & Rücklagen (Einzelunternehmen, umgesetzt 0.29.0), 5.32 Ausbaustufe „Premium Plus“ (GmbH, Lohnverrechnung; nur Umriss), 5.33 Schnittstellen zu Kanzleiprogrammen (DATEV, BMD, RZL, CSV, Paket doppelte Buchführung); offener Punkt O-43 (Tarif). Keine neue Datenübertragung (5.19 unverändert). |
| 1.81 | 2026-10-19 | Rückmeldung des Auftraggebers vom 2026-10-19 (14a): geführte Ersteinrichtung, knappere Bestätigungen, EU-KU-Nummer (EX), Belegfeld „Produkt oder Leistung“, Mithelfer-Hilfe und Koppeln aus den Einstellungen (Spezifikation 1.86). |
| 1.80 | 2026-10-19 | Entscheidungen des Auftraggebers vom 2026-10-19 (14a, O-42 neu und erledigt, ersetzt O-35): Test auf allen vier Produkten mit Pro inklusive (L-10.3, L-22.3 neu gefasst), Demo ohne Abo (L-10.6 neu), L-22.1 um Demo ergänzt; Umsetzungsstand 0.27.0 (10a). Keine neue Datenübertragung (5.19 unverändert: Demo bleibt auf dem Gerät). |
| 1.79 | 2026-10-19 | O-33 umgesetzt: Bundle-ID/applicationId `at.jenibarb.jenibucht` ab App-Version 0.26.0. Keine neue Datenübertragung (5.19 unverändert). |
| 1.78 | 2026-10-18 | Entscheidungen 14a vom 2026-10-18 (Verbringen nicht in der App, Rechnungen im Heimatland, Registrierung nur für die UID); O-40 geschlossen, L-30.9 entfällt; neuer offener Punkt O-41 nächstes Land mit Verweis auf die [Länderanalyse](LAENDERANALYSE.md). Keine neue Datenübertragung (5.19 unverändert). |
| 1.77 | 2026-10-18 | Neuer Abschnitt 5.30 Steuerliche Registrierungen in mehreren Ländern (L-30.1 bis L-30.9, umgesetzt 0.25.0 außer L-30.8/L-30.9), Entscheidung in 14a, O-40 Verbringen. Keine neue Datenübertragung (5.19 unverändert, L-30.7). |
| 1.76 | 2026-10-17 | Mailweg der Mithelfer (L-29.10, L-29.11, umgesetzt 0.24.0 ohne OAuth): drei Zeilen in der Datenflusstabelle 5.19 (SMTP Mithelfer, IMAP Hauptgerät, Serversuche), Entscheidung in 14a, offener Punkt O-39 mit To-dos der Auftraggeberin (Google-Cloud-Projekt und OAuth-Verifizierung, Azure-App-Registrierung). |
| 1.75 | 2026-10-17 | 14a: Mithelfer ohne eigenes Abo und ohne Gerätegrenze entschieden (L-29.7); neue Startkategorie „Material und Werkzeug“ (umgesetzt 0.23.1). Keine neue Datenübertragung. |
| 1.74 | 2026-10-17 | Neuer Abschnitt 5.29 Mithelfer-Geräte / Belegsammler (L-29.1 bis L-29.9, umgesetzt 0.23.0), Zeile in der Datenflusstabelle 5.19, Entscheidung und Auslegung „ohne eigenes Abo“ in 14a, O-38 volle Mehrgeräte-Synchronisierung nach dem Launch. |
| 1.73 | 2026-10-16 | L-26.7 „Wunsch oder Idee senden“ (umgesetzt 0.22.2): Zeile in der Datenflusstabelle 5.19 (Übertragung nur durch die Nutzerin aus ihrer Mail-App, Inhalt von ihr gewählt), Entscheidung in 14a. |
| 1.72 | 2026-10-16 | O-37 neu: ELSTER-Übermittlungsserver (Cloud-Container, zustandslos) – vertagt auf nach dem Launch bei genügend deutschen Nutzerinnen. |
| 1.71 | 2026-10-16 | Diktat auf dem Gerät (Spezifikation FA-2.61): Zeile in der Datenflusstabelle 5.19 (keine Übertragung durch die App), Eintrag und Tarifvorschlag Basis in 14a. |
| 1.70 | 2026-10-16 | Entscheidung 14a Bewirtung mit Abzugsbeschränkung (L-2.27 angepasst, umgesetzt 0.21.0); O-36: ELSTER-Softwarehersteller am 2026-10-16 beantragt, Antwort ausstehend. Keine neue Datenübertragung (5.19 unverändert). |
| 1.69 | 2026-10-16 | Entscheidungen 14a: Anlagen nur Pro (Ausnahme zur Regel in 5.10, mit Datenzugang und Hinweis), Vertragsarchiv Basis/Pro mit Auslesen nur Pro; Vorschläge geschlossen. |
| 1.68 | 2026-10-16 | Dokumentenscanner des Systems (Entscheidung 14a), Datenfluss Play-Dienste in 5.19. |
| 1.67 | 2026-10-16 | 5.23 Vertragsarchiv lokal umgesetzt (L-23.1 bis L-23.4, L-23.6, L-23.11), L-23.1 um Pacht und Dienstbarkeit ergänzt; Tarifvorschlag in 14a; Datenfluss „Berichte teilen“ um Vertragsliste ergänzt. |
| 1.66 | 2026-10-16 | Anlagenverwaltung mit AfA, Anlagenverzeichnis, Saldenliste und vorläufiger Jahresabschluss umgesetzt (Spezifikation 5.11); Tarifvorschlag in 14a; Datenfluss „Berichte teilen“ in 5.19. |
| 1.65 | 2026-10-16 | L-6.1, L-6.3 umgesetzt, L-6.5 teilweise (U30-Datei, Spezifikation FA-14.x); Datenflusstabelle 5.19 um „U30-Datei teilen“ ergänzt; O-36 neu (ELSTER-Hersteller-ID, FinanzOnline-Webservice). |
| 1.64 | 2026-10-16 | L-2.28 Lernen je Lieferant neu und umgesetzt; L-7.17, L-7.18, L-7.20 umgesetzt (iCloud-Container); Datenflusstabelle 5.19 um iCloud ergänzt (L-19.28). |
| 1.63 | 2026-10-16 | Entscheidung Promo-Code „JENIBUCHT2M“ (14a); Datenfluss Abo um den Promo-Code ergänzt (5.19). |
| 1.62 | 2026-10-16 | Umsetzungsstand 0.15.0: Angebote und Artikelverwaltung (10a). |
| 1.61 | 2026-10-16 | Entscheidungen 2026-10-16 (14a): PDF senden bleibt weiche Sperre; E-Rechnung speichern in Basis genügt; Logo im Onboarding frei wählbar, gedruckt nur mit Pro/Test. Tarifschnitt 5.10 angepasst. |
| 1.60 | 2026-10-15 | O-35 entschieden (Store-Test nur Pro, 14a). |
| 1.59 | 2026-10-15 | Entscheidung der Auftraggeberin zum Pro-Umfang (O-34 erledigt, 14a); Tarifschnitt 5.10 angepasst: E-Rechnung auslesen, Plattformimport, PDF/Mahnung senden, Logo, Kurs abrufen in Pro. |
| 1.58 | 2026-10-15 | Umsetzungsstand 0.14.0 (10a): Lizenz und Abo (L-10.1 bis L-10.5, L-22.1 bis L-22.3, L-22.5 bis L-22.8; L-22.4 teilweise). Datenflusstabelle 5.19: Abo-Kauf und Abo-Abfrage als vorhanden, mit Inhalt. Neue offene Punkte O-34 (Plattformimport Basis oder Pro), O-35 (Test auch auf Basis). |
| 1.57 | 2026-10-15 | Umsetzungsstand 0.13.0 (10a): L-3.7, L-3.18 (vollständige Erstattung), L-22.18, L-22.21, L-22.22. Keine neue Datenübertragung: Druckblatt und Stornorechnung verlassen das Gerät nur über das Teilen der Nutzerin, wie Rechnungs-PDF und Sicherung (5.19 unverändert). |
| 1.56 | 2026-10-15 | O-33 entschieden: Bundle-ID `at.jenibarb.jenibucht` vor der ersten Store-Einreichung. |
| 1.55 | 2026-10-15 | Entscheidungen der Auftraggeberin (14a): Name „JeNi bucht“ (O-2, O-25 erledigt), neu O-33 Bundle-ID für den Store; O-26 Haftpflicht verschoben bis Launch; O-30 nur Formatprüfung (umgesetzt in 0.12.0); Store-Text „14 Tage kostenlos testen“. |
| 1.54 | 2026-10-14 | Dokumentabgleich mit Code 0.11.0 (Prüfinstanz Softwareentwickler): Ausgangslage aktualisiert; neu L-0.6 (Einhandbedienung ohne Händigkeits-Einstellung); Umsetzungsvermerke in 5.24 bis 5.28; 5.23 als Unterabschnitt eingeordnet; neuer Abschnitt 10a Umsetzungsstand und Stand-Hinweis in 10; Abnahmekriterien A-9, A-10; doppelte O-15 aufgelöst (O-15b), O-32 einsortiert, O-26 als teilweise entschieden; neuer Abschnitt 14a Entscheidungen der Auftraggeberin. |
| 1.53 | 2026-10-14 | L-27.4/L-27.5: iOS „Öffnen in …“ statt Share Extension von der Auftraggeberin bestätigt. Neu 5.28 (L-28.1 bis L-28.7, Stufe B1: Plattformexporte Amazon, PayPal, Shopify, Stripe), umgesetzt in 0.11.0 (Spezifikation FA-2.43 bis FA-2.49). Keine neue Datenübertragung (5.19 unverändert: Datei kommt aufs Gerät). Prüfpunkte P-S51 bis P-S55, P-R36, P-U7. |
| 1.52 | 2026-10-14 | A3 umgesetzt in 0.10.0 (L-27.7, Spezifikation FA-2.42). Neuer Datenfluss „Rechnung über Link-QR“ in 5.19, PRIVACY und STORE_LISTING (L-19.5); Prüfung P-R35. |
| 1.51 | 2026-10-14 | A2 umgesetzt in 0.9.0 (L-27.4 bis L-27.6, L-27.8; Spezifikation FA-2.38 bis FA-2.41). iOS-Teilen über „Öffnen in“ statt Share Extension. Keine neue Datenübertragung (5.19 unverändert). |
| 1.50 | 2026-10-14 | Neu 5.27 (L-27.1 bis L-27.8: Codes, Teilen-Ziel, PDF/E-Rechnung, Link-QR) und O-32 (Plattform-Connectoren zurückgestellt). 5.19: Barcode-Erkennung von ML Kit in der bestehenden Diagnosezeile. A1 umgesetzt in 0.8.0. |
| 1.49 | 2026-10-14 | L-3.31: Kundendokumente fest in Sie-Form, keine Du-Umschaltung (Entscheidung Auftraggeberin). |
| 1.48 | 2026-10-14 | Neu L-2.27 (Beleg mit mehreren Steuersätzen) und L-3.31 (neue Frist, Mahnsymbol, Sie-Form); umgesetzt in App-Version 0.7.0 (Spezifikation 1.46). Keine neue Datenübertragung (5.19 unverändert). |
| 1.47 | 2026-10-14 | Mahnwesen: L-3.10 präzisiert (Stufen, beliebig oft), neu L-3.27 bis L-3.30; umgesetzt in App-Version 0.5.0 (Spezifikation GR-13, FA-5.21 bis FA-5.25). |
| 1.46 | 2026-10-14 | Rabatt, Versandkosten, Skonto, AGB-Verweis (L-3.21 bis L-3.26), umgesetzt in App-Version 0.4.0 (Spezifikation 5.5, GR-12). |
| 1.45 | 2026-10-14 | Neuer Block L-26 Hilfe in der App: Stufe 1 offline umgesetzt (Spezifikation 5.8, FA-11.1 bis FA-11.3), Stufe 2 KI nach Server-Entscheidung (P-R25, P-R26). |
| 1.44 | 2026-10-14 | Neue Blöcke L-24 Wirtschaftsjahr und L-25 Steuer- und Abgabetermine (Entscheidungen der Auftraggeberin 2026-10-14); L-25.9 bezahlte Rechnung als Einnahme nach Zahlungseingang (Gerätetest 0.3.4). |
| 1.43 | 2026-10-14 | Leitprinzip Einfachheit als fundamentale Anforderung (2.1a, L-0.1 bis L-0.5): Erkennung überall, Vorschläge statt Pflichteingaben, Bestätigungen zusammenlegen, Belege gelten als betrieblich. |
| 1.42 | 2026-10-12 | L-2.24 bis L-2.26, L-13.3, L-19.29 Fremdwährung bei Eingangsbelegen umgesetzt (Spezifikation 1.28, FA-2.24 bis FA-2.27, Schema 10); Datenfluss EZB-Kursabruf in 5.19. |
| 1.41 | 2026-10-12 | Fremdwährung bei Eingangsbelegen (L-2.24 bis L-2.26, L-13.3, L-19.29), KI-Auslesung nur Opt-in (L-21.24); geprüft von Steuerberater und Rechtsanwalt; Android-Erkennung mit ML Kit entschieden. |
| 1.40 | 2026-10-12 | L-2.20 bis L-2.23 Belege automatisch auslesen, umgesetzt (Spezifikation FA-2.19 bis FA-2.23). Entscheidung der Auftraggeberin: Android Google ML Kit (gebündelt), dessen Diagnosedaten an Google in 5.19 offengelegt. Fremdwährung nur bei Eingangsbelegen. |
| 1.39 | 2026-10-12 | Entscheidungen der Auftraggeberin: L-22.30 App-Sperre KANN/C → SOLL/A und umgesetzt (Spezifikation 5.5b); L-7.20 iCloud-Ordner in der Dateien-App SOLL → MUSS (Bau mit L-7.17 offen). |
| 1.38 | 2026-10-12 | L-22.21 bis L-22.30: Wiederherstellungscode statt Passwort-Zurücksetzen, Promocodes und Affiliates über Store-Offers, Preisangaben. Erlösrechnung: rund 71 % des Bruttopreises kommen bei der Anbieterin an. Geprüft von allen drei Instanzen. |
| 1.37 | 2026-10-12 | Umgesetzt mit Schema 8: Firmenlogo (L-1.7, neu L-1.9), mehrseitige Belege mit Vollständigkeitsbestätigung (L-2.15, L-2.16), Kommentare nur anhängbar (L-2.17), Diktat über die Systemtastatur (L-2.18). Geprüft von Steuerberater und Softwareentwickler. |
| 1.36 | 2026-10-12 | Keine Anmeldung mit Google/Apple (L-7.22); iCloud-Container als Standard unter iOS (L-7.17 bis L-7.20); Android-Ordnerwahl bleibt Hauptweg (L-7.21); Schlüssel nie im iCloud-Schlüsselbund (L-19.27, L-19.28). Geprüft von Rechtsanwalt und Softwareentwickler. |
| 1.35 | 2026-10-12 | Neuer Block 5.23 Vertragsarchiv (Stufe C) nach Prüfung durch Steuerberater und Rechtsanwalt. O-26 entschieden: Spirits by JeNiBarb e.U.; Umwandlung in eine GmbH, sobald die Umsätze es rechtfertigen. |
| 1.34 | 2026-10-12 | Neuer Block 5.22 Lizenz und Bezahlung mit Store-Reife, mit den drei Prüfinstanzen ausgearbeitet: nur Store-Billing, Lizenzmanager ohne Server mit Prüfung am Gerät, Herabstufen statt sperren, Abo-Seite, Anbieter-Steuern, Organisationskonten, Release-Workflow. Neue Checkliste STORE_READINESS.md. |
| 1.33 | 2026-10-12 | Datenbindung geprüft (O-31): keine anbieterexklusive Verschlüsselung; neu L-7.12 bis L-7.16 (kein Anbieterschlüssel, offenes Format, Archivexport Z3, Nur-Lese-Modus, Escrow). |
| 1.32 | 2026-10-12 | Gerätetest: L-17.1 bis L-17.4 umgesetzt (Bestätigungen vor der ersten Nutzung, ohne Werbe-Einwilligung). O-30 neu (Verifizierung von E-Mail/Telefon). |
| 1.31 | 2026-10-10 | O-29 entschieden: kein Server und kein Konto beim Anbieter. Mehrgeräte- und Mehrpersonenbetrieb über einen Cloud-Ordner der Unternehmerin, mit den drei Prüfinstanzen ausgearbeitet (L-19.12 neu, L-19.13 ersetzt, L-19.15 bis L-19.26 neu; L-19.4, L-19.6, L-19.9, L-19.14 entfallen). Rollen- und Datenflusstabelle angepasst, S-8 nur noch für Kanäle. Aufwand Stufe C +56–83 PW. |
| 1.30 | 2026-10-10 | Automatische Sicherung mit den drei Prüfinstanzen ausgearbeitet und umgesetzt: L-7.6 bis L-7.11 (Opt-in mit Erklärseite, Geräteschlüssel mit Wiederherstellungscode, Ordnerwahl ohne Konto, Probe nach jedem Schreiben, Aufbewahrung 7/12/je Jahr dauerhaft). Datenflusstabelle geteilt. |
| 1.29 | 2026-10-10 | L-21 überarbeitet nach Entscheidung „direkt Anthropic API, eigenes Konto" und Prüfung durch die drei Instanzen: Verarbeitungsort je Datenkategorie (L-21.8 bis L-21.12), Betrieb rund um die Uhr ohne Zusatzdienst, gesichert durch eigenes Design (L-21.13 bis L-21.23), Kostenannahmen. S-13 auf Anthropic festgelegt, O-28 erledigt. |
| 1.28 | 2026-10-10 | Neuer Block L-21: Start auf der heutigen Claude-Anbindung, Umstellung auf eine andere Claude API innerhalb von sechs Monaten nach Launch; austauschbare Adapterschicht, kein Schlüssel in der App, Validierung vor und nach dem Wechsel. O-28 neu. |
| 1.27 | 2026-10-10 | Neuer Block L-20 Rechtsstand-Überwachung (Abschnitt 5.20), mit den drei Prüfinstanzen ausgearbeitet: Agent nur als Vorschlagsgeber beim Anbieter, Vier-Augen-Freigabe, signierte Regelpakete, Prüfung auf dem Gerät, Validierung mit Rückspieltest. Neuer Datenfluss Regelpaket-Abruf. O-27 neu. Aufwand Stufe B 39–57, A+B 64–97 Personenwochen. |
| 1.26 | 2026-10-10 | Ergebnisse der drei Prüfinstanzen eingearbeitet: „Gutschrift" durch Stornorechnung/Rechnungskorrektur ersetzt, Ist-Versteuerung bei Erstattung (L-3.7, L-3.18); E-Rechnungsempfang MUSS/A (L-4.3); OSS-Warnung mit Vorjahr (L-13.9); Probeabo-Pflichtangaben (L-10.3); Rabattwerbung (5.10); Rollen um Anbieter- und Store-Daten ergänzt (L-19); Apple-Kontolöschung (L-17.12); R-6 präzisiert; O-21 vorläufig beantwortet; O-25, O-26 neu. Aufwand Stufe A 25–40 inkl. Puffer. Punkte für die reale Prüfung stehen ausschließlich in Spezifikation Abschnitt 14. |
| 1.25 | 2026-10-10 | O-1 erledigt: Vorjahresgrenze Österreich 55.000 € umgesetzt. |
| 1.24 | 2026-10-10 | O-3 entschieden: Preise Basis/Pro mit Rabatt- und Jahresoption, Hinweis auf Streichpreisregeln. |
| 1.23 | 2026-10-10 | O-4 entschieden: Funktionsschnitt Basis/Pro in Abschnitt 5.10, E-Rechnung empfangen in Basis; Regel „gesetzliche Pflicht nie nur in Pro". |
| 1.22 | 2026-10-10 | Tarifmodell (O-4 teilweise, O-16): 14 Tage gratis mit vollem Umfang, danach Basis, optional Pro; keine Einzelmodule (L-10.1 bis L-10.3). |
| 1.21 | 2026-10-10 | O-13 entschieden: freiwilliger Einkaufspreis mit Rohertrag (L-11.12). |
| 1.20 | 2026-10-10 | O-12 entschieden: OSS-Warnung (neu L-13.9, Stufe B), volle OSS-Unterstützung L-13.7 auf KANN herabgestuft. Aufwand A+B 50–77 Personenwochen. |
| 1.19 | 2026-10-10 | O-14 vertagt: nächste EU-Märkte nach dem Start je nach Nachfrage. |
| 1.18 | 2026-10-10 | O-7 entschieden: Deutsch zum Start, Landessprache je weiterem EU-Land (L-13.6). Neu L-13.8: Oberflächentexte von Anfang an in Sprachdateien. |
| 1.17 | 2026-10-10 | O-6 entschieden: nur Smartphone und Tablet, keine Browser- oder Desktop-Version; in die Abgrenzung aufgenommen. |
| 1.16 | 2026-10-09 | O-18 entschieden: E-Mail nur über die Mail-App des Smartphones. L-15.4 bis L-15.9, S-15, S-16, R-15, RK-15, RK-16 und die zugehörigen Aufwandszeilen in Stufe C entfallen. |
| 1.15 | 2026-10-09 | O-23 entschieden: Lagerzubuchung beim Rücksendeschein wählbar je Rücksendung (L-3.20). |
| 1.14 | 2026-10-09 | Zweite Namensvariante „Jenni bucht" aufgenommen (O-2). |
| 1.13 | 2026-10-09 | Arbeitstitel „Jenny Bar" festgelegt (O-2). |
| 1.12 | 2026-10-09 | O-2: Namensrichtung festgelegt (weiblicher Vorname, Anklang an „Jenny Barb"). |
| 1.11 | 2026-10-09 | Hauptzielgruppe festgelegt (Abschnitt 3). O-24 entschieden: Produktseite als Einzelseite mit regulatorischem Mindestinhalt (L-17.12). Formatfehler in L-17.3 behoben. |
| 1.10 | 2026-10-09 | O-5, O-8, O-9 entschieden (fortlaufende Entwicklung; E-Mail-Support mit 3 Werktagen, FAQ in der App, keine Website; eigene Steuerberatung ab sofort). O-24 neu: Hosting der Pflichttexte ohne Website. |
| 1.9 | 2026-10-09 | Abgleich mit Nutzerwünschen: Zahlungserinnerung auf MUSS/A (L-3.10), Erstattung (L-3.18), Kunden-E-Mail als Standardempfänger (L-3.19), Rücksendeschein (L-3.20, Abgrenzung angepasst), Management-Übersicht (L-5.8), Import von Ausgangsrechnungen (L-16.12), paralleles Arbeiten mehrerer Geräte, Passwort-Reset und 2FA (L-19.12 bis L-19.14). O-23 neu. Aufwand A+B 48–75 Personenwochen. |
| 1.8 | 2026-10-09 | Neuer Block L-19 Datenschutz: kein Nutzerkonto bis zur Cloud-Synchronisierung (Stufe C), Rollen, vollständige Tabelle der Datenflüsse, Regel zu Löschung gegen Aufbewahrungspflicht. L-17.1/L-17.3 von „Registrierung" auf „erste Einrichtung" umgestellt; Widerspruch zu NFA-2 der Spezifikation aufgelöst. |
| 1.7 | 2026-10-09 | O-22 entschieden: UVA-Übermittlung in den Haupttarif (Stufe B), Kontoumsätze per Datei-Import (neuer Block L-18), Angebote aufgenommen (L-3.13 bis L-3.17). Aufwand Stufe A und B auf 46–72 Personenwochen. |
| 1.6 | 2026-10-09 | O-19 behoben. Umgesetzt sind die Umsatzanteile von L-16.1 sowie L-16.2 und L-16.11; Forderungen, Verbindlichkeiten und Kassenbestand aus L-16.1 bleiben offen. |
| 1.5 | 2026-10-09 | Neuer Block L-16 Datenübernahme beim Einstieg mit Eröffnungswerten, Altdaten-Import und Archivierung von Altunterlagen. Neuer Block L-17 Rechtlicher Rahmen und Haftungsabgrenzung mit ausdrücklicher Bestätigung bei der Registrierung. Zweiter bekannter Fehler derselben Art wie O-1 aufgenommen (O-19): der Vorjahresumsatz wird nur aus erfassten Belegen ermittelt und ist für neue Nutzer null. Drei neue Risiken. Aufwand Stufe A und B auf 40–63 Personenwochen angehoben. |
| 1.4 | 2026-10-09 | Google als Merchant Center präzisiert (O-11 erledigt). Neuer Block L-15 E-Mail-Anbindung mit gestuftem Zuschnitt: Teilen-Dialog und Beleg-Eingangsadresse vor dem direkten Postfachzugriff, weil Googles eingeschränkte Bereiche eine jährlich kostenpflichtige Sicherheitsprüfung auslösen. Zwei neue Risiken, R-15, vier neue Schnittstellen. |
| 1.3 | 2026-10-09 | Schweiz als Zielmarkt gestrichen; Fokus auf Österreich und Deutschland, Erweiterung auf EU-Länder der Eurozone. Block L-13 auf EU-Erweiterbarkeit zurückgeschnitten, Mehrwährung und QR-Rechnung entfallen. Neuer Block L-14 Marketing-Modul als Premium-Service mit harter Grenze gegen die Übertragung von Kundendaten. Aufwand Stufe A und B zurück auf 32–50 Personenwochen. |
| 1.2 | 2026-10-09 | Zielmärkte festgelegt: Österreich, Deutschland und Schweiz zum Start, weitere europäische Märkte als Erweiterung. Neuer Anforderungsblock L-13 Märkte und Internationalisierung mit Mehrwährung, Schweizer Länderprofil, QR-Rechnung und zeitlich gestaffelten Steuersätzen. Kanalanbindung auf ausschließlich lesend festgelegt (O-10 erledigt). Abgrenzung zur Währung korrigiert. Aufwand Stufe A und B auf 39–60 Personenwochen angehoben. |
| 1.1 | 2026-10-09 | Artikelverwaltung (L-11) und Verkaufskanäle (L-12) aufgenommen, Zweitablage der Belegfotos (L-2.11 bis L-2.14) ergänzt. Abgrenzung korrigiert: Warenwirtschaft war bisher vollständig ausgeschlossen. OSS-Pflicht (R-10) und vier neue Risiken aufgenommen, Aufwandsschätzung auf 31–48 Personenwochen für Stufe A und B angehoben. |
| 1.0 | 2026-10-09 | Erstfassung. Festlegung auf kommerzielles Produkt mit Abonnement und Premium-Services, Zielgruppe Einzelunternehmen und Kleinbetriebe in AT und DE, Datenhaltung lokal mit Sicherung in den Cloud-Speicher des Nutzers und späterem Cloud-Sync, Meldungen zunächst vorbereitend mit späterer elektronischer Übermittlung, Auswertungen auf EAR-Basis mit späterer doppelter Buchführung. |

### Pflege dieses Dokuments

Das Lastenheft steht **vor** der Spezifikation: Änderungen am Zielbild werden hier
eingetragen, bevor Code entsteht. Jede neue Anforderung bekommt eine ID, eine
Priorität und eine Stufe. Umgesetzte Anforderungen bleiben stehen — das Lastenheft
ist kein Aufgabenzettel, sondern die Beschreibung des gewollten Produkts.
