# Lastenheft – Buchhaltungsapp für Österreich und Deutschland

**Dokumentversion:** 1.23 · **Stand:** 2026-10-09 · **Status:** Entwurf zur Abstimmung
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
| L-3.10 | **Zahlungserinnerung** aus einer überfälligen Rechnung erzeugen und versenden (PDF mit Verweis auf Rechnungsnummer, offenen Betrag und neue Frist); Mahnstufen werden an der Rechnung vermerkt | MUSS | A |
| L-3.11 | Rechnungsvorschau vor dem Ausstellen | SOLL | A |
| L-3.12 | Wiederkehrende Rechnungen (Abo-Rechnungen an eigene Kunden) | KANN | C |
| L-3.13 | **Angebote** mit eigenem Nummernkreis, unabhängig vom Rechnungsnummernkreis | MUSS | A |
| L-3.14 | Ein Angebot hat **keine steuerliche Wirkung**: es erscheint weder im Kassabuch noch in der UVA, noch in der Grenzwertüberwachung | MUSS | A |
| L-3.15 | Ein Angebot lässt sich **mit einem Tipp in eine Rechnung umwandeln**; Positionen, Kunde und Preise werden übernommen und bleiben vor dem Ausstellen änderbar | MUSS | A |
| L-3.16 | Angebotsstatus: offen, angenommen, abgelehnt, abgelaufen; mit Gültigkeitsdatum | MUSS | A |
| L-3.17 | Angebot als PDF teilen; die PDF trägt sichtbar „Angebot", nie „Rechnung" | MUSS | A |
| L-3.18 | **Erstattung:** zu einer Gutschrift (L-3.7), auch über einen Teilbetrag oder einzelne Positionen, wird die Rückzahlung an den Kunden als Ausgabe mit Zahlungsdatum erfasst; die Umsatzsteuer wird im Zeitraum der Gutschrift berichtigt | MUSS | A |
| L-3.19 | Die im Kundenstamm hinterlegte **E-Mail-Adresse ist Standardempfänger** beim Versand von Rechnung, Angebot und Zahlungserinnerung; je Kunde ist eine abweichende Rechnungsadresse für E-Mails möglich | MUSS | A |
| L-3.20 | **Rücksendeschein** zu einer Rechnung: welche Positionen in welcher Menge zurückgehen, mit Grund; ohne steuerliche Wirkung, bis daraus eine Gutschrift (L-3.7) erzeugt wird. Je Rücksendung wählbar „Ware wieder verkaufbar? Ja / Nein"; bei Ja wird die Menge dem Lagerstand (L-11) wieder zugebucht, bei Nein nicht | SOLL | B |

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
| L-10.3 | **14 Tage gratis mit vollem Funktionsumfang (Pro).** Die App zeigt deutlich, wann der Test endet und was danach kostet; Erinnerung 3 Tage vor Ablauf. Umsetzung über die Probezeiträume der Stores | MUSS | B |
| L-10.4 | **Bei abgelaufenem Abo bleiben die Daten des Nutzers lesbar und exportierbar.** Buchhaltungsdaten dürfen nie hinter einer Paywall verschwinden — sie unterliegen einer gesetzlichen Aufbewahrungspflicht | MUSS | B |
| L-10.5 | Lizenzprüfung funktioniert offline über einen angemessenen Zeitraum | MUSS | B |

**Tarifschnitt (entschieden am 2026-10-10, O-4).** Basis ist alles, was eine
ordentliche Buchhaltung braucht; Pro ist Komfort und Wachstum.

| Basis | Pro (zusätzlich) |
|---|---|
| Rechnungen, Angebote, Zahlungserinnerungen, Gutschriften, Rücksendescheine | Belegerkennung per Kamera (L-2) |
| Kunden und Artikel | E-Rechnung **ausstellen** (L-4) |
| **E-Rechnung empfangen und lesen** (L-4.3) | Kontoauszug-Import mit Zuordnung (L-18) |
| Belege fotografieren, Kassabuch | UVA-Übermittlung FinanzOnline/ELSTER (L-6.5) |
| Management-Übersicht, Kleinunternehmer-Ampel, OSS-Warnung | Einkommensteuer-Vorbereitung, Saldenliste, rollender Jahresabschluss |
| Export an die Steuerberatung | Shop-Anbindung (L-12), Marketing-Modul (L-14) |
| Datensicherung, Spracheingabe | Cloud-Synchronisierung über mehrere Geräte (S-8) |

Eine gesetzliche Pflicht darf nie nur in Pro erfüllbar sein. Wird eine Funktion
zur Pflicht für die Zielgruppe, wandert sie nach Basis.

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
| L-13.3 | Ein **weiterer EU-Markt muss überwiegend Konfiguration sein**: Steuersätze, Grenzwerte, Kleinbetragsgrenzen, Pflichtangaben, Fristen, Zahlenformat und Rechtsverweise liegen an genau einer Stelle | MUSS | A |
| L-13.4 | **Zahlen- und Datumsformat je Markt**, auch innerhalb der Eurozone unterschiedlich | MUSS | A |
| L-13.5 | **Zeitlich gestaffelte Steuersätze.** Ein Steuersatz gilt nicht einfach, er gilt *ab einem Datum*. Befristete Satzänderungen hat es in beiden Zielmärkten bereits gegeben; eine Rechnung aus dem Vorjahr muss mit dem damals gültigen Satz darstellbar bleiben | MUSS | B |
| L-13.6 | **Landessprache je Markt:** Start nur auf Deutsch; mit jedem weiteren EU-Land kommt dessen Landessprache hinzu (O-7) | SOLL | C |
| L-13.8 | **Texte von Anfang an übersetzbar anlegen:** alle Oberflächentexte liegen in Sprachdateien (Flutter-Lokalisierung), nicht im Code. Eine neue Landessprache ist dann Übersetzung, kein Umbau | MUSS | A |
| L-13.7 | **OSS-Verfahren** für grenzüberschreitende Verkäufe an EU-Privatkunden oberhalb der Lieferschwelle — Voraussetzung für die Kanalanbindung (L-12), siehe R-10. **Je nach Nachfrage (O-12)** | KANN | C |
| L-13.9 | **OSS-Warnung:** Rechnungen an Privatkundinnen in anderen EU-Ländern werden erkannt und summiert; ab 80 % der EU-weiten Lieferschwelle von 10.000 € (Art. 59c MwStSystRL; noch amtlich zu bestätigen) warnt die App und rät, die Steuerberatung einzubinden. Keine Berechnung ausländischer Steuersätze | MUSS | B |

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
| L-17.12 | **Produktseite** auf eigener Domain (Name folgt mit dem Produktnamen, O-2): eine einfache Einzelseite mit Links zu Google Play und App Store. Mindestinhalt: Impressum (§ 5 ECG, § 25 MedienG AT bzw. § 5 DDG DE), Datenschutzerklärung (Art. 13 DSGVO) mit eigener URL für beide Stores, Support-E-Mail, ab Stufe C Anleitung und Link zur Kontolöschung (Google-Play-Vorgabe), Hinweis „keine Steuerberatung" (L-17.8). Ohne Tracking und ohne Cookies, damit kein Einwilligungsbanner nötig ist | MUSS | A |
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

#### Nutzerkonto

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-19.1 | **Stufe A und B kommen ohne Nutzerkonto aus.** Das Abonnement läuft über den Kauf im App Store bzw. bei Google Play; die Lizenz hängt am Store-Konto, nicht an einem Konto beim Anbieter | MUSS | A |
| L-19.2 | **Ein Nutzerkonto entsteht erst mit der Cloud-Synchronisierung (S-8)**, weil es nur dafür gebraucht wird: um sich von weiteren Geräten aus anzumelden | MUSS | C |
| L-19.3 | Auch mit Konto bleibt die App **ohne Anmeldung nutzbar**; das Konto ist Voraussetzung für die Synchronisierung, nicht für die Buchhaltung | MUSS | C |
| L-19.12 | **Mehrere Geräte arbeiten parallel** auf denselben Daten; Änderungen werden synchronisiert, Konflikte erkannt und nie stillschweigend überschrieben. Gestellte Rechnungen sind unveränderlich und damit konfliktfrei; der Nummernkreis bleibt auch bei gleichzeitiger Vergabe lückenlos und eindeutig | MUSS | C |
| L-19.13 | **Passwort zurücksetzen** per Link an die hinterlegte E-Mail-Adresse; wegen Ende-zu-Ende-Verschlüsselung nur mit Wiederherstellungsschlüssel oder einem noch angemeldeten Gerät ohne Datenverlust | MUSS | C |
| L-19.14 | **Zwei-Faktor-Authentisierung** (TOTP-App, alternativ Passkey); einmalige Wiederherstellungscodes | MUSS | C |
| L-19.4 | Für das Konto werden nur die zur Anmeldung nötigen Daten erhoben (E-Mail-Adresse, Zugangsdaten). Keine Telefonnummer, kein Geburtsdatum, keine Profilangaben „für später" | MUSS | C |

#### Rollen

| Datenkategorie | Verantwortlicher | Anbieter ist |
|---|---|---|
| Buchhaltungsdaten am Gerät (Belege, Rechnungen, Kunden) | **der Nutzer** — er erfasst Daten seiner Kunden | nicht beteiligt; liefert nur Software |
| Kontodaten (Stufe C) | **der Anbieter** | Verantwortlicher |
| Synchronisierte Buchhaltungsdaten (Stufe C) | der Nutzer | **Auftragsverarbeiter**; Vertrag nach Art. 28 DSGVO mit jedem Nutzer |
| Daten an Marketing-Dienste (L-14) | der Nutzer | Auftragsverarbeiter mit Unterauftragnehmer |

#### Datenflüsse

Jede Übertragung vom Gerät weg, auch die unscheinbaren:

| Datenfluss | Empfänger | Was | Ausgelöst durch | Opt-in | Stufe |
|---|---|---|---|---|---|
| Rechnung/Export teilen | vom Nutzer gewählt | PDF, CSV | Tippen auf Teilen | je Vorgang | vorhanden |
| Sicherung (L-7.2) | iCloud bzw. Google Drive des Nutzers | verschlüsselte Vollsicherung | Einschalten | ja | A |
| Foto-Zweitablage (L-2.11) | Fotobibliothek, ggf. deren Cloud | Belegfotos | Einschalten | ja | A |
| UID-Prüfung (L-1.3) | EU-Kommission (VIES) | UID-Nummer | Prüfauftrag | je Vorgang | A |
| Rechnungsversand (L-15.1) | Mail-App des Nutzers | PDF | Tippen auf Senden | je Vorgang | A |
| Abo-Kauf (L-10.1) | Apple bzw. Google | Kaufvorgang | Kauf | je Vorgang | B |
| UVA-Übermittlung (L-6.5) | FinanzOnline bzw. ELSTER | Kennzahlen der Voranmeldung | Freigabe der Meldung | je Vorgang | B |
| Cloud-Synchronisierung (S-8) | Server des Anbieters | alle Buchhaltungsdaten, verschlüsselt | Konto anlegen | ja | C |
| Marketing (L-14) | Dienst zur Inhaltserzeugung | nur Unternehmens- und Artikeldaten | Modul einschalten | ja | C |
| Kanäle (L-12) | Amazon, Shopify, Google Merchant Center | je nach Modul | Modul einschalten | ja | C |

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-19.5 | **Jeder neue Datenfluss wird im selben Schritt in diese Tabelle, in die Datenschutzerklärung und in die Store-Datensicherheitsangaben eingetragen.** Eine Funktion, die Daten überträgt, ist ohne diese drei Einträge nicht fertig | MUSS | A |
| L-19.6 | Daten, die beim Anbieter landen (Stufe C), werden **in der EU** verarbeitet und gespeichert | MUSS | C |
| L-19.7 | Synchronisierte Daten sind **Ende-zu-Ende verschlüsselt**; der Anbieter kann Buchhaltungsdaten nicht lesen | SOLL | C |

#### Löschung und Aufbewahrungspflicht

| ID | Anforderung | Prio | Stufe |
|---|---|---|---|
| L-19.8 | Die App **löscht keine Buchungsbelege vor Ablauf der Aufbewahrungsfrist** (AT 7, DE 8 Jahre) ohne ausdrückliche Warnung; die Frist hat Vorrang vor dem Löschwunsch (Art. 17 Abs. 3 lit. b DSGVO) | MUSS | A |
| L-19.9 | Die Löschung des **Nutzerkontos** (Stufe C) entfernt Kontodaten und synchronisierte Kopien beim Anbieter; die Daten am Gerät bleiben, damit die Aufbewahrungspflicht erfüllbar bleibt | MUSS | C |
| L-19.10 | Der Nutzer kann **Daten seiner Kunden** auf deren Anfrage auskunftsfähig zusammenstellen (alle Rechnungen und Stammdaten eines Kunden als Export) | SOLL | B |
| L-19.11 | Kundenstammdaten ohne aufbewahrungspflichtige Rechnungen sind löschbar; mit solchen Rechnungen wird auf die Frist verwiesen | MUSS | B |

> **Die Leitlinie.** Bis Stufe C gibt es beim Anbieter schlicht keine
> Nutzerdaten: kein Konto, kein Server, keine Kopie. Das ist die stärkste
> Datenschutzposition, die ein Produkt einnehmen kann, und sie ist nur so lange zu
> halten, wie L-19.5 ernst genommen wird. Rechtsgrundlagen und Rollen sind vor
> Stufe C anwaltlich zu bestätigen (L-17.11).

---

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
| R-6 | Als kommerzielles Produkt zusätzlich: Impressum, AGB, Widerrufsbelehrung, Preisangaben, und eine eigene Rechnungslegung für die Aboerlöse |
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
| S-8 | Eigenes Backend | Synchronisierung mehrerer Geräte; **Voraussetzung für S-9 bis S-11** | C |
| S-9 | Amazon Selling Partner API | Verkaufsdaten aus dem Amazon-Seller-Konto | C |
| S-10 | Shopify Admin API | Verkaufsdaten aus dem Shopify-Shop | C |
| S-11 | Google (Merchant Center, zu bestätigen) | Verkaufs- bzw. Produktdaten | C |
| S-12 | Fotobibliothek des Geräts | Zweitablage der Belegfotos in eigenem Album | A |
| S-13 | Dienst zur Inhaltserzeugung (Text und Bild) | Marketing-Modul L-14; Auftragsverarbeiter | C |
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
Teilen-Dialog**, der **Altdaten-Import** und die **Rechtstexte samt
Datenschutz-Dokumentation**.

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
| **Summe Stufe A** | | **17–28** |
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
| **Summe Stufe B** | | **33–49** |
| **Stufe A + B zusammen** | | **50–77 Personenwochen** |
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
| O-1 | **Prüfung der österreichischen Kleinunternehmer-Logik.** Mehrere Quellen beschreiben § 6 Abs 1 Z 27 UStG so, dass **auch der Vorjahresumsatz** unter 55.000 € liegen muss. Die heutige Implementierung prüft nur das laufende Jahr. Amtliche Quellen waren aus der Entwicklungsumgebung nicht erreichbar — Bestätigung durch die Steuerberatung nötig | sofort; betrifft bestehenden Code |
| O-2 | Produktname und Bundle-ID. **Arbeitstitel seit 2026-10-09: „Jenny Bar"** (Wortspiel aus Jenny Barb und „bar bezahlen"). **Zweite Variante: „Jenni bucht"**. Endgültig erst nach Markenrecherche. **Richtung festgelegt am 2026-10-09:** weiblicher Vorname, gern mit Anklang an „Jenny Barb" (Wiedererkennung mit jenibarb.com), allein oder verbunden mit dem Thema (z. B. „Jenny bucht"). Markenrecherche AT/DE/EUIPO, Store-Suche und Domainprüfung vor Festlegung | vor dem ersten Store-Upload |
| O-3 | Preispunkte für Basisabo und Premium-Services — Vorschlag und Marktvergleich in [`WETTBEWERB.md`](WETTBEWERB.md) | Stufe B |
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
| O-15 | **Welcher Dienst erzeugt die Marketing-Inhalte?** Davon hängen Auftragsverarbeitungsvertrag, Kosten je Erzeugung und die Frage ab, ob der Betrieb in der EU erfolgt | Stufe C |
| ~~O-16~~ | Mit O-4 erledigt: es gibt keine einzeln buchbaren Module; das Marketing-Modul ist Teil von Pro | erledigt |
| O-17 | Sollen erzeugte Werbemittel versioniert und wiederverwendbar abgelegt werden, oder sind sie Wegwerfware? | Stufe C |
| ~~O-19~~ | **Behoben am 2026-10-09** (Umsatzanteile von L-16.1, L-16.2, L-16.11). Ursprünglich: **Bekannter Fehler:** Die Grenzwertüberwachung ermittelt den Vorjahresumsatz ausschließlich aus erfassten Belegen. Für einen neuen Nutzer ist er damit null, und die Ampel steht fälschlich auf Grün — in Deutschland entscheidet er über das ganze laufende Jahr. Behebung über L-16.1/L-16.2 | sofort; betrifft bestehenden Code |
| O-20 | Welche Vorsoftware-Formate sind beim Import vorrangig zu unterstützen? Richtet sich nach dem, womit die ersten Nutzer tatsächlich kommen | Stufe B |
| O-21 | Gilt das Barrierefreiheitsstärkungsgesetz für ein B2B-Produkt wie dieses? Zu klären, bevor die Oberfläche festgezurrt wird | vor Stufe B |
| ~~O-23~~ | **Entschieden am 2026-10-09:** wählbar je Rücksendung über den Schalter „Ware wieder verkaufbar?" (L-3.20) | erledigt |
| ~~O-24~~ | **Entschieden am 2026-10-09:** eigene Einzelseite auf einer neuen Domain, die mit dem Produktnamen festgelegt wird (L-17.12) | erledigt |
| ~~O-18~~ | **Entschieden am 2026-10-09:** nur Versand über die Mail-App des Smartphones; keine Gmail- oder Microsoft-365-Anbindung, L-15.4 bis L-15.9 entfallen | erledigt |

---

## 15. Änderungshistorie

| Version | Datum | Änderung |
|---|---|---|
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
