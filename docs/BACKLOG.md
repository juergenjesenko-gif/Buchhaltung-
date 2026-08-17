# Product Backlog

Priorisiert. Oben steht, was als Nächstes gebaut wird.

**Produktziel:** Ein Einzelunternehmer in Österreich oder Deutschland führt seine
Buchhaltung vollständig am Telefon – Beleg fotografieren statt sammeln, Rechnung
unterwegs schreiben, am Jahresende einen Export an die Kanzlei schicken.

**Zielgruppe Sprint 1–3:** Einzelunternehmer und Kleinunternehmer. Keine
Lohnverrechnung, keine doppelte Buchführung, keine Mehrbenutzerfähigkeit.

---

## Erledigt (Sprint 1)

### EPIC A – Firmenprofil

**A1 · Als Unternehmer will ich mein Unternehmen einmalig anlegen, damit die App
die für mich geltenden Steuerregeln kennt.** ✅

- [x] Land Österreich oder Deutschland wählbar
- [x] Firmenname, Inhaber, Rechtsform, Anschrift, Kontaktdaten
- [x] Steuernummer und UID/USt-IdNr. mit landesabhängiger Bezeichnung
- [x] Kleinunternehmerregelung ein-/ausschaltbar mit Erklärung der Folgen
- [x] Bankverbindung für den Zahlungsblock der Rechnung
- [x] Ohne Firmenname und Land startet die App ins Onboarding
- [x] Beim Bearbeiten springt der Rechnungsnummernzähler nicht zurück

**A2 · Als Unternehmer will ich sehen, welche Angaben mir für rechtssichere
Rechnungen noch fehlen.** ✅

- [x] `missingInvoiceFields` prüft die Pflichtangaben des Ausstellers
- [x] Hinweis auf dem Dashboard, der direkt in die Stammdaten führt
- [x] Wer USt ausweist, muss eine UID hinterlegen (Formularvalidierung)

### EPIC B – Belege

**B1 · Als Unternehmer will ich einen Beleg abfotografieren und in unter 30
Sekunden erfasst haben.** ✅

- [x] Kamera und Galerie als Quelle
- [x] Foto auf 2000 px und 85 % Qualität reduziert
- [x] Nur relativer Pfad in der Datenbank (iOS ändert den Container-Pfad bei Updates)
- [x] Bruttobetrag eingeben, Netto und USt werden live angezeigt
- [x] Beschreibung ist Pflicht – ein Beleg ohne Bezeichnung ist später nutzlos
- [x] Kategorie, Zahlungsart, Geschäftspartner, Notiz
- [x] Belegdatum wählbar, Zukunft ausgeschlossen

**B2 · Als Unternehmer will ich einen Beleg wiederfinden.** ✅

- [x] Liste nach Monat gruppiert
- [x] Suche über Beschreibung, Partner und Notiz
- [x] Filter Einnahmen/Ausgaben, Jahreswahl über die Aufbewahrungsfrist
- [x] Saldo der sichtbaren Auswahl

**B3 · Als Unternehmer will ich einen Beleg korrigieren oder löschen können,
ohne dass die Buchhaltung intransparent wird.** ✅

- [x] Bearbeiten und Löschen möglich
- [x] Jede Änderung landet im `audit_log`
- [x] Löschen erst nach Rückfrage

### EPIC C – Kassabuch

**C1 · Als Unternehmer will ich jederzeit wissen, wie ich dastehe.** ✅

- [x] Einnahmen, Ausgaben, Ergebnis für Monat/Vormonat/Quartal/Jahr/Vorjahr
- [x] Umsatzsteuer je Satz, Vorsteuer, Zahllast bzw. Guthaben
- [x] Balkenverlauf über sechs Monate
- [x] Letzte fünf Belege als Schnellzugriff

**C2 · Als Kleinunternehmer will ich rechtzeitig gewarnt werden, bevor ich die
Umsatzgrenze reiße.** ✅

- [x] Österreich: 55.000 € mit 10 % Toleranz (§ 6 Abs 1 Z 27 UStG)
- [x] Deutschland: 25.000 € Vorjahr / 100.000 € laufendes Jahr (§ 19 UStG)
- [x] Ampel ok → nähert sich (ab 80 %) → in Toleranz → überschritten
- [x] Klartext-Erklärung der jeweiligen Rechtsfolge

### EPIC D – Rechnungen

**D1 · Als Unternehmer will ich eine Rechnung schreiben, die alle Pflichtangaben
erfüllt.** ✅

- [x] Kundenstamm mit Anschrift und UID
- [x] Positionen mit Menge, Einheit, Einzelpreis netto, Steuersatz
- [x] Teilmengen exakt (0,25 Std × 99,99 € = 25,00 €)
- [x] Liefer-/Leistungsdatum als Pflichtfeld
- [x] Fortlaufende Nummer nach konfigurierbarem Muster
- [x] Nummer wird erst beim Ausstellen gezogen, nicht beim Entwurf
- [x] Kleinunternehmer: keine USt, dafür der gesetzliche Hinweistext
- [x] Checkliste zeigt, was vor dem Ausstellen fehlt

**D2 · Als Unternehmer will ich die Rechnung als PDF verschicken.** ✅

- [x] A4-PDF mit Absender, Empfänger, Metadaten, Positionstabelle
- [x] USt je Satz aufgeschlüsselt
- [x] Zahlungsblock mit IBAN und Fälligkeit
- [x] Fußzeile mit Seitenzahl, mehrseitig lauffähig
- [x] Teilen über das System-Teilen-Blatt

**D3 · Als Unternehmer will ich, dass eine gestellte Rechnung unveränderlich
bleibt.** ✅

- [x] Ab Status „Gestellt“ ist das Formular gesperrt
- [x] Aussteller- und Empfängerdaten werden als JSON eingefroren
- [x] Nur Entwürfe sind löschbar, gestellte Rechnungen werden storniert
- [x] Rechnungsnummer ist in der Datenbank eindeutig (UNIQUE INDEX)

### EPIC E – Export

**E1 · Als Unternehmer will ich meiner Kanzlei die Daten so übergeben, dass sie
sie einlesen kann.** ✅

- [x] Belegliste als CSV mit Summenzeilen
- [x] DATEV-Buchungsstapel EXTF 700 (nur Deutschland sichtbar)
- [x] BMD-Buchungssätze (nur Österreich sichtbar)
- [x] Umsatzsteuer-Zusammenfassung mit Bemessungsgrundlagen
- [x] Vorschau mit Belegzahl und Summen, bevor geteilt wird
- [x] Kontenmapping SKR03 → österreichischer Einheitskontenrahmen

---

## Als Nächstes (Sprint 2)

**F1 · Als Unternehmer will ich meine Daten sichern und auf ein neues Gerät
übertragen.**

Höchste Priorität. Ohne Backup ist ein verlorenes Telefon der Verlust der
Buchhaltung – und die Aufbewahrungspflicht bleibt bestehen.

- [ ] Vollsicherung als verschlüsseltes ZIP (Datenbank + Belegfotos)
- [ ] Wiederherstellung mit Vorschau, was eingelesen wird
- [ ] Warnung, wenn seit der letzten Sicherung mehr als 30 Tage vergangen sind
- [ ] Kein automatischer Cloud-Upload ohne ausdrückliche Zustimmung

**F2 · Als Unternehmer will ich den Betrag nicht abtippen müssen.**

- [ ] Betrag, Datum und Händler aus dem Belegfoto vorschlagen (On-Device-OCR)
- [ ] Vorschläge sind immer korrigierbar, nie automatisch übernommen
- [ ] Läuft offline – ein Beleg darf das Gerät nicht verlassen

**F3 · Als Unternehmer will ich wiederkehrende Belege nicht jedes Mal neu
erfassen.**

- [ ] Beleg als Vorlage speichern
- [ ] Vorlage mit einem Tipp als neuen Beleg anlegen

**F4 · Als Unternehmer will ich eine Storno- oder Gutschriftsrechnung erstellen.**

- [ ] Storno erzeugt eine neue Rechnung mit negativem Betrag und Verweis
- [ ] Ursprungsrechnung wird als storniert markiert, bleibt aber erhalten

**F5 · Als Unternehmer will ich sehen, welche Rechnungen offen und überfällig
sind, und eine Zahlungserinnerung schicken.**

- [ ] Filter „offen“ und „überfällig“ in der Rechnungsliste
- [ ] Zahlungserinnerung als PDF aus der bestehenden Rechnung

---

## Später (Sprint 3+)

**G1 · E-Rechnung.** In Deutschland gilt seit 1.1.2025 die Empfangspflicht für
B2B-Rechnungen, die Versandpflicht folgt gestaffelt bis 2028. In Österreich ist
das Format `ebInterface` bzw. Peppol gegenüber Bundesstellen Pflicht. Das wird
kein Nice-to-have bleiben.

- [ ] Ausgangsrechnung als XRechnung/ZUGFeRD (DE) exportieren
- [ ] ebInterface-Export (AT)
- [ ] Eingehende XRechnung einlesen und als Beleg anlegen

**G2 · Bankabgleich.** Kontoumsätze importieren (CAMT/CSV) und Belegen zuordnen.

**G3 · Cloud-Sync.** Mehrere Geräte, ein Datenbestand. Erst wenn F1 steht – ein
Sync ohne funktionierendes Backup verdoppelt nur das Risiko. Ende-zu-Ende
verschlüsselt, DSGVO-Auftragsverarbeitungsvertrag nötig.

**G4 · Kilometergeld und Diäten.** Fahrtenbuch mit den amtlichen Sätzen
(AT: amtliches Kilometergeld, DE: Pauschale je Kilometer).

**G5 · Abschreibungen (AfA).** Anlagenverzeichnis mit Nutzungsdauer und
linearer Abschreibung; Geringwertige Wirtschaftsgüter separat.

**G6 · Mehrere Nummernkreise.** Getrennte Kreise pro Jahr oder Geschäftsbereich.

**G7 · Weitere Länder.** Struktur ist vorbereitet (`TaxProfile`); Schweiz wäre
der naheliegende nächste Kandidat, braucht aber CHF und damit Mehrwährungsfähigkeit.

---

## Ausdrücklich nicht geplant

- **Registrierkasse nach RKSV (AT).** Signatureinrichtung, DEP, Belegprüfung und
  Jahresbelegmeldung sind ein eigenes Produkt mit Zertifizierungsaufwand. Die App
  sagt an mehreren Stellen deutlich, dass sie das nicht ist.
- **Lohnverrechnung.** Eigene Domäne, eigene Haftung.
- **Doppelte Buchführung mit Bilanz.** Zielgruppe sind Einnahmen-Ausgaben-Rechner.
- **Steuererklärungen automatisch übermitteln.** Die App liefert
  Bemessungsgrundlagen; die Erklärung bleibt beim Unternehmer und seiner Kanzlei.
