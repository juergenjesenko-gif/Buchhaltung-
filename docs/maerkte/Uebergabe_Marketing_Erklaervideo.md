# Übergabe an Entwicklung: Bildschirmaufnahmen für das Erklärvideo

Stand 2026-10-30 · von Marketing (Claude-Projekt „JeNi bucht") an Claude Code · Freigabe Auftraggeber: ja

## Zweck
Für das Erklärvideo „Was du hier kaufst" (Konzept: Projekt-Dokument `Erklaervideo_Konzept.md`) brauchen wir **echte Bildschirmaufnahmen der App** im Demo-Modus. JeNi rahmt nur Anfang und Ende; der Hauptteil zeigt die echte App.

## Was wir damit bezwecken
Die Reels machen neugierig – aber wer kaufen soll, muss vorher verstehen, **was er kauft**. Das Erklärvideo (ca. 100 s Langfassung für Website/YouTube/App-Store-Vorschau, 45-s-Fassung und 5 Kapitel-Clips für Social Media) soll einer selbstständigen Frau ohne Technikwissen in kurzer Zeit zeigen:
- wie man die App benutzt (ohne Vorwissen, ohne Einstellen),
- welche Arbeit sie einem abnimmt,
- was sie kostet – und ehrlich, was sie **nicht** macht.

Nach dem Video soll niemand mehr fragen müssen „Was kann die App eigentlich?". Kauf­entscheidung statt Neugier.

Aus Sicht des Auftraggebers sind die USPs (Reihenfolge = Gewicht):
1. **Beleg scannen und automatisch auslesen** – nichts selbst eintragen (wichtigste Funktion), auch fremdsprachige Belege und Fremdwährung
2. **Verträge ablegen, automatisch zusammenfassen, Zahlungsverpflichtungen automatisch anlegen**
3. **Übersicht über Einnahmen, Ausgaben, Saldenliste – in Echtzeit**
4. **Daten fürs Finanzamt aufbereitet** (Marketing formuliert „aufbereitet", nicht „übermittelt" – bitte bestätigen oder korrigieren)
5. **Archiv über die gesetzliche Aufbewahrungsfrist** (AT 7, DE 8 Jahre)
6. Über allem: **kein technisches Vorwissen nötig**, funktioniert ab der Installation

## Bitte bring dich ein
Du kennst die App am besten. Bitte ergänze vor den Aufnahmen kurz (als Antwort-Dokument an Marketing):
- **Fehlende USPs:** Was macht JeNi bucht besser oder einfacher als andere Lösungen, das oben fehlt? (z. B. offline, Daten bleiben am Gerät, Spracheingabe, Mithelfer-Geräte, Kassen-QR, Amazon/PayPal/Shopify/Stripe-Import, Kleinunternehmer-Ampel, Mahnen, Demo-Modus …) – bitte mit deiner Einschätzung, welche davon ins Video gehören.
- **Pflichtpunkte eines Erklärvideos** aus deiner Sicht: Was muss eine Käuferin unbedingt wissen, damit sie nach dem Kauf nicht enttäuscht ist (Grenzen aus Handbuch Kap. 14, Pro vs. Basis, Datensicherung)?
- **Zu starke Aussagen:** Prüfe die USP-Liste gegen den tatsächlichen Stand und das Lastenheft; markiere alles, was so nicht stimmt oder nur in Pro gilt.
- **Bessere Abläufe:** Wenn ein anderer Weg in der App eine Funktion eindrucksvoller oder schneller zeigt als die Liste unten – nimm ihn und sag Bescheid.
- Die Prüfinstanzen (UX, Rechtsanwalt) dürfen gerne einen Blick auf die Aussagen werfen.

## Technische Vorgaben
- **Format:** MP4 (H.264), Hochformat, mind. 1080×2340 (oder native Gerätauflösung), 30 fps, ohne Ton.
- **Daten:** ausschließlich Demo-Modus bzw. erfundene Demo-Daten (P-R56) – keine echten Namen, UID-Nummern, Händler. **Wasserzeichen „MUSTER – DEMO" bitte für die Aufnahmen ausblenden**, falls das über einen internen Schalter geht; sonst so lassen und Bescheid geben.
- **Bedienung ruhig und langsam:** jeder Tipp sichtbar (Touch-Anzeige einschalten, wenn möglich), 1 s Pause vor und nach jedem Schritt.
- **Statusleiste:** Uhrzeit 9:41, voller Akku, kein Benachrichtigungsrauschen.
- **Sprache der App:** Deutsch (Land: Österreich). Später gleiche Abläufe in EN/FR.
- **Weg:** egal – Emulator in CI (`adb screenrecord`), Integrationstest mit Aufzeichnung oder iOS-Simulator. Wichtig ist das Ergebnis; bitte nichts am Produkt ändern, um aufzunehmen.

## Liste der Aufnahmen (je 5–20 s)

| # | Kapitel im Video | Ablauf |
|---|---|---|
| A1 | Kein Vorwissen nötig | App-Erststart: Willkommen → „Los geht's" → die 5 Einrichtungsschritte zügig durchklicken → Übersicht |
| A2 | 1 · Scannen statt tippen – **Kernfunktion** | Beleg fotografieren (Demo-Bild eines Kassabons, AT, 20 %) → **automatisches Auslesen sichtbar: Lieferant, Datum, Betrag, Steuersatz, Kategorie füllen sich ohne eine einzige Eingabe** → „erkannt – bitte prüfen" → Speichern → Beleg erscheint sofort in der Liste und in der Übersicht. Kein Feld wird von Hand getippt. Wenn möglich zusätzlich als Zeitlupe/Nahaufnahme der sich füllenden Felder (A2b) |
| A3 | 1 · Fremdsprache | Beleg auf Slowenisch („Skupaj", „DDV") auslesen → Speichern |
| A4 | 1 · Fremdwährung | Beleg in USD (z. B. Software-Abo) → „Kurs abrufen" → Euro-Betrag erscheint → Speichern |
| A5 | 1 · Teilen | PDF-Rechnung aus einer anderen App an JeNi bucht teilen → Beleg angelegt |
| A6 | 2 · Verträge – **automatisch zusammengefasst** | Mehrseitigen Demo-Vertrag (z. B. Mietvertrag, 15 Seiten) scannen → **automatische Kurzübersicht**: Beginn, Betrag, Fälligkeit, Kündigungsfrist, Wertsicherung → Werte übernehmen → **Zahlungsverpflichtungen werden automatisch als regelmäßige Buchungen angelegt** (Liste der eingeplanten Zahlungen inkl. nächster Indexanpassung zeigen) |
| A7 | 3 · Alles im Blick | Übersicht: Zahlen + Kleinunternehmer-Ampel; dann einen Beleg buchen und zurück – Zahl ändert sich sichtbar |
| A8 | 3 · Saldenliste (Pro) | Saldenliste öffnen, kurz scrollen |
| A9 | Rechnungen | Angebot → mit einem Tipp zur Rechnung → Checkliste → PDF-Vorschau → Format E-Rechnung wählen |
| A10 | 4 · Fertig fürs Finanzamt | Export: Kennzahlen (UVA) anzeigen, U30-Datei (AT) erzeugen, Export an Steuerberatung teilen |
| A11 | 5 · Sicher archiviert | Belegliste nach Jahr filtern (älteres Jahr), Beleg mit „Original aufbewahrt" → **Anzeige der Aufbewahrungsfrist in Jahren** (AT 7 Jahre, DE 8 Jahre, „aufbewahren bis …"); bei Verträgen „bis wann aufbewahren"; Einstellungen → automatische Sicherung (je Jahr eine dauerhafte Sicherung). Falls die Frist nirgends in der Oberfläche sichtbar ist: bitte melden, dann blenden wir sie als Text ein |

## Bitte zusätzlich zurückmelden (für korrekte Einblendungen)
1. Welche dieser Funktionen sind **nur in Pro**? (Saldenliste laut Handbuch Pro; Verträge? E-Rechnung? Fremdwährung?)
2. Bestätigung: **keine** direkte Übermittlung an FinanzOnline/ELSTER (Handbuch Kap. 14, O-37) – Video sagt „fertig aufbereitet fürs Finanzamt".
3. Benutzerhandbuch Kap. 1 sagt noch „Kein Konto, keine Anmeldung, **kein Abo**" – widerspricht den Preisen (Lastenheft 5.10). Bitte prüfen.

## Lieferung
Dateien `erklaer_A1.mp4` … `erklaer_A11.mp4` als CI-Artefakt (direkter Artefakt-Link) oder im Repo unter `docs/marketing/erklaervideo/` (nicht in den App-Build). Danach schneidet Marketing das Video.
