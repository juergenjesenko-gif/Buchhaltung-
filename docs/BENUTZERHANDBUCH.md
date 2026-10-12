# Benutzerhandbuch – Buchhaltung

**Für App-Version 0.2.0** · Stand 2026-10-12

Dieses Handbuch beschreibt die App aus Nutzersicht. Es wird bei jeder Änderung,
die du in der App siehst, mitgeführt – siehe [`CLAUDE.md`](../CLAUDE.md).

## Inhalt

1. [Was diese App für dich tut](#1-was-diese-app-für-dich-tut)
2. [Der erste Start](#2-der-erste-start)
3. [Die vier Bereiche](#3-die-vier-bereiche)
4. [Belege erfassen](#4-belege-erfassen)
5. [Deine Zahlen lesen](#5-deine-zahlen-lesen)
6. [Die Kleinunternehmergrenze](#6-die-kleinunternehmergrenze)
7. [Rechnungen schreiben](#7-rechnungen-schreiben)
8. [Kunden verwalten](#8-kunden-verwalten)
9. [Export an die Steuerberatung](#9-export-an-die-steuerberatung)
10. [Einstellungen](#10-einstellungen)
11. [Deine Daten und ihre Sicherung](#11-deine-daten-und-ihre-sicherung)
12. [Häufige Fragen](#12-häufige-fragen)
13. [Wenn etwas nicht geht](#13-wenn-etwas-nicht-geht)
14. [Was die App nicht kann](#14-was-die-app-nicht-kann)

---

## 1. Was diese App für dich tut

Du bist Einzelunternehmer oder Kleinunternehmer in Österreich oder Deutschland.
Die App hilft dir bei vier Dingen:

- **Belege erfassen**, indem du sie abfotografierst statt sie zu sammeln
- **Den Überblick behalten** über Einnahmen, Ausgaben und Umsatzsteuer
- **Rechnungen schreiben**, die alle Pflichtangaben enthalten
- **Daten übergeben** an deine Steuerberatung, in einem Format, das sie einlesen kann

Kein Konto, keine Anmeldung, kein Abo. Alles liegt auf deinem Telefon.

---

## 2. Der erste Start

Beim ersten Öffnen bestätigst du zwei Dinge, jedes mit eigenem Häkchen: dass
die App **keine Steuerberatung** ist, und die **Nutzungsbedingungen und den
Datenschutz**. Ändern sich diese Texte später wesentlich, fragt die App erneut.

Danach fragt die App nach deinem Unternehmen. Das ist notwendig,
nicht Neugier: ohne das Land kennt die App deine Steuersätze nicht, und ohne
Anschrift kann sie keine gültige Rechnung erzeugen.

### Was du eintragen solltest

**Unternehmen**
- **Firmenname** – Pflicht. So, wie er auf deinen Rechnungen stehen soll.
- **Inhaber:in** – falls der Firmenname nicht dein Name ist
- **Land** – Österreich oder Deutschland. Bestimmt Steuersätze, die Bezeichnung
  „UID-Nummer" bzw. „USt-IdNr." und die Gesetzesverweise auf deinen Rechnungen.
- **Rechtsform** – Einzelunternehmen, Freiberufler, GbR/GesbR oder GmbH

**Anschrift** – Straße, PLZ und Ort sind auf jeder Rechnung Pflichtangaben.
Trag sie gleich vollständig ein, dann musst du später nicht nachbessern.

**Steuer**
- **Kleinunternehmerregelung** – der wichtigste Schalter in der App. Siehe unten.
- **Steuernummer** – deine Nummer beim Finanzamt. Noch beantragt? Leer lassen
  und später nachtragen. In **Deutschland** braucht jede Rechnung Steuernummer
  **oder** USt-IdNr.; in **Österreich** steht die Steuernummer nicht auf der
  Rechnung.
- **UID-Nummer / USt-IdNr.** – freiwillig. Die App prüft beim Tippen, ob Format
  und Prüfziffer stimmen. In **Österreich** brauchst du sie für Rechnungen über
  10.000 € brutto mit Umsatzsteuer – dann auch die UID deines Kunden.
- **Jetzt prüfen** – fragt das EU-Prüfsystem VIES, ob die UID gültig ist. Dabei
  geht die Nummer an die EU-Kommission. „Nicht prüfbar" heißt nur, dass das
  System gerade nicht erreichbar war – nicht, dass die Nummer falsch ist.
- **UID-Nummern wöchentlich prüfen** – Schalter, standardmäßig aus. Eingeschaltet
  prüft die App deine UID und die deiner Kunden aus den letzten 12 Monaten
  einmal pro Woche (beim ersten Öffnen nach sieben Tagen) und vor jeder
  Rechnung an einen Kunden mit UID. Das Ergebnis wird mit der Rechnung
  gespeichert. Ist eine UID ungültig, warnt die App – ausstellen kannst du
  trotzdem.
- **Firmenbuchnummer / Handelsregisternummer** – nur wenn dein Unternehmen
  eingetragen ist (z. B. e.U. bzw. e.K.). Dann ist auch das Gericht Pflicht;
  beides steht auf jeder Rechnung.

**Bankverbindung** – IBAN, BIC und Bank erscheinen im Zahlungsblock deiner
Rechnungen. Ohne IBAN fehlt dieser Block.

**Gründungsjahr** — nur bei aktiver Kleinunternehmerregelung, freiwillig. Hast
du dein Unternehmen dieses Jahr gegründet, trag das Jahr ein: Dann fragt die App
nicht nach einem Vorjahresumsatz, und in Deutschland gilt im Gründungsjahr eine
Grenze von **25.000 €** statt 100.000 €.

**Umsatz vor Nutzung der App** — nur bei aktiver Kleinunternehmerregelung. Die
App kennt deine Umsätze erst ab dem Tag, an dem du sie einrichtest. Für die
Umsatzgrenze braucht sie aber auch das Vorjahr und — wenn du mitten im Jahr
startest — den Umsatz dieses Jahres bis dahin. Beides sind Pflichtfelder.
Hattest du noch keinen Umsatz, trag ausdrücklich **0** ein: ein leeres Feld
heißt für die App „unbekannt", nicht „null".

**Rechnungen**
- **Muster der Rechnungsnummer** – Standard ist `RE-{YYYY}-{NNNN}`, das ergibt
  `RE-2026-0001`. Mehr dazu in [Abschnitt 7](#7-rechnungen-schreiben).
- **Zahlungsziel** – in Tagen, Standard 14
- **Fußzeile** – lass sie leer, dann baut die App sie automatisch aus deinen
  Stammdaten

### Kleinunternehmer – ja oder nein?

Dieser Schalter verändert das Verhalten der App grundlegend.

**Schalter an (Kleinunternehmer):**
Deine Rechnungen enthalten **keine Umsatzsteuer**. Stattdessen erscheint
automatisch der gesetzlich vorgeschriebene Hinweis. Du darfst auch keine
Vorsteuer aus deinen Ausgaben abziehen. Die App überwacht deine Umsatzgrenze.

**Schalter aus (Regelbesteuerung):**
Deine Rechnungen weisen Umsatzsteuer aus, und du kannst Vorsteuer abziehen. Die
App zeigt dir deine Zahllast gegenüber dem Finanzamt.

> Wenn du nicht sicher bist, was für dich gilt: frag deine Steuerberatung. Der
> Schalter falsch gesetzt bedeutet falsche Rechnungen — und Umsatzsteuer, die
> du ausgewiesen hast, schuldest du dem Finanzamt, auch wenn du sie nie
> einnehmen durftest.

Du kannst die Angaben jederzeit ändern: **Übersicht → Zahnrad → Stammdaten**.
Bereits gestellte Rechnungen bleiben davon unberührt.

---

## 3. Die vier Bereiche

Unten in der App findest du vier Bereiche:

| Symbol | Bereich | Wofür |
|---|---|---|
| Kacheln | **Übersicht** | Deine Zahlen, die Grenzwertampel, die letzten Belege |
| Beleg | **Belege** | Alle Belege suchen, filtern, bearbeiten |
| Dokument | **Rechnungen** | Rechnungen schreiben, versenden, Status pflegen |
| Teilen | **Export** | Daten für die Steuerberatung |

Die **Einstellungen** erreichst du über das Zahnrad rechts oben in der Übersicht.

**Auf dem Tablet oder im Querformat** stehen die vier Bereiche nicht unten,
sondern als Leiste am linken Rand. Ist der Bildschirm breit genug (etwa ein
Tablet quer), siehst du bei Belegen, Rechnungen und Kunden links die Liste und
rechts den geöffneten Eintrag; nach dem Speichern bleibt die Liste stehen und
zeigt die Änderung. Eingabeformulare werden auf großen Bildschirmen nicht über
die ganze Breite gezogen, damit sie gut lesbar bleiben. Die App lässt sich in
jeder Richtung halten und auf dem iPad bzw. Android-Tablet neben einer anderen
App nutzen.

> **Tipp:** Speichere, bevor du das Tablet drehst oder die Fenstergröße
> änderst. Ein gerade geöffneter, noch nicht gespeicherter Eintrag rechts wird
> dabei sonst geschlossen.

---

## 4. Belege erfassen

Das ist die Funktion, die du täglich nutzt. Sie ist auf Geschwindigkeit gebaut.

### Einen Beleg erfassen

1. In der **Übersicht** unten rechts auf das Kamerasymbol tippen (für eine
   **Ausgabe**) oder auf das kleinere grüne Symbol darüber (für eine **Einnahme**).
   Alternativ im Bereich **Belege** auf das Plus.
2. **Bruttobetrag** eintippen – also die Zahl, die auf dem Beleg steht, inklusive
   Umsatzsteuer. Netto und Steuer rechnet die App sofort darunter aus.
3. **Umsatzsteuersatz** prüfen. Die App wählt deinen Standardsatz vor.
4. **Fotografieren** oder ein vorhandenes Foto **auswählen**. Hat der Beleg
   mehrere Seiten, tippe danach auf **Seite fotografieren** bzw. **Seite
   wählen** – so oft du brauchst. Vor dem Speichern kannst du Seiten mit den
   Pfeilen umsortieren oder mit dem Papierkorb löschen. Setze dann das Häkchen
   **„Alle Seiten inkl. beschriebener Rückseiten erfasst"** – ohne es speichert
   die App keine neuen Seiten.
5. **Beschreibung** eintragen – Pflichtfeld. „Bürostuhl" ist gut, „Rechnung"
   nützt dir in zwei Jahren nichts.
6. Optional: Datum, Lieferant bzw. Kunde, Kategorie, Zahlungsart, Notiz und
   ein **Kommentar** (siehe unten)
7. **Beleg speichern**

### Belege automatisch auslesen

Sobald du einen neuen Beleg fotografierst oder ein Foto wählst, liest die App
ihn **auf deinem Telefon** aus – bei mehreren Seiten alle Seiten. Sie trägt
ein, was sie findet: **Belegdatum, Bruttobetrag, Umsatzsteuersatz,
Lieferant, Rechnungsnummer und UID des Ausstellers**. Solche Felder sind mit
**„erkannt – bitte prüfen“** markiert.

- **Prüf die markierten Felder** mit dem Beleg. Gebucht wird erst, wenn du auf
  **Beleg speichern** tippst – vorher ist nichts verbucht.
- Was die App nicht sicher erkennt, lässt sie leer. Die Beschreibung trägst
  du immer selbst ein.
- **Erneut auslesen** unter den Fotos startet die Erkennung noch einmal, z. B.
  nachdem du eine weitere Seite ergänzt hast. Achtung: bereits eingetragene
  Werte werden dabei durch die erkannten ersetzt.
- **Mehrere Steuersätze** (z. B. Hotel mit Übernachtung und Frühstück): die
  App zeigt Brutto je Satz an und wählt den größten Anteil vor. Teile den
  Beleg bei Bedarf in zwei Buchungen auf.
- **Fremde Währung** (z. B. eine Rechnung in US-Dollar) bei Ausgaben: die App
  schaltet auf „Beleg in fremder Währung“ und trägt den Betrag laut Beleg ein.
  Den Kurs holst du mit **Kurs abrufen** (siehe *Belege in fremder Währung*).
- Das Foto selbst wird nie verändert. Im Änderungsprotokoll steht, was erkannt
  und was von dir bestätigt wurde.
- Ausschalten: Einstellungen → **Belege auslesen**.

Datenschutz: Foto und Text verlassen dein Telefon dafür nicht, die Erkennung
läuft auch im Flugmodus. Unter Android sendet die eingebaute Erkennung von
Google (ML Kit) allerdings Nutzungs- und Diagnosedaten ohne Fotos und Text an
Google; unter iOS überträgt die Apple-Erkennung nichts.

### Belege in fremder Währung

Nur bei **Ausgaben** (z. B. Software-Abo in US-Dollar). Deine eigenen
Rechnungen schreibst du immer in Euro.

1. Schalter **Beleg in fremder Währung** einschalten.
2. **Währung** (z. B. `USD`) und **Betrag laut Beleg** eintragen.
3. **Kurs abrufen** tippen. Die App lädt die Referenzkurse der Europäischen
   Zentralbank und bildet das Mittel aller Tageskurse im Monat des Belegs –
   angezeigt als „EZB-Monatsmittel – Näherung an BMF-Kurs“. Im laufenden Monat
   ist das Mittel vorläufig. Nur dieser Knopf baut eine Verbindung auf; die
   Kurse bleiben danach auf dem Gerät.
4. Die App zeigt den **umgerechneten Euro-Betrag**. Mit ihm rechnet sie
   Netto, Vorsteuer und Umsatzsteuer.
5. Optional **Tatsächlich abgebucht (EUR)** laut Kontoauszug eintragen. Dieser
   Betrag zählt für dein Ergebnis (Einnahmen-Ausgaben-Rechnung); die Vorsteuer
   bleibt beim umgerechneten Betrag. Die Differenz erscheint im Export als
   „Kursdifferenzen laut Bank“.

Der Kurs ist **Einheiten je 1 Euro** (z. B. `1,0823` US-Dollar). Du kannst ihn
jederzeit selbst eintragen, z. B. den amtlichen Kurs des Finanzministeriums;
wähle dann die Kursquelle „BMF-Monatskurs“ oder „Manuell“. Für die
Umsatzsteuer gilt grundsätzlich der Monatskurs. Einen **Tageskurs** bietet die
App nur an, wenn du in den Einstellungen **Tageskurs vom Finanzamt genehmigt**
eingeschaltet hast. EZB-Kurse sind Referenzkurse, ohne Gewähr – kläre mit
deiner Steuerberatung, welchen Kurs sie erwartet.

### Seiten eines gespeicherten Belegs

In der Belegansicht siehst du alle Seiten nebeneinander; Antippen vergrößert
eine Seite. Nach dem Speichern sind die Seiten fest: du kannst weitere
**anhängen** (z. B. eine nachgereichte Rückseite), aber keine löschen oder
umsortieren. So bleibt nachvollziehbar, was gebucht wurde.

### Kommentare zu Belegen

Im Abschnitt **Kommentare** notierst du, was zum Beleg gehört („Bewirtung mit
Kundin X", „Rückseite leer"). Bei einem gespeicherten Beleg tippst du den Text
ein und dann auf **Anhängen** – auch bei einem stornierten Beleg.

- Jeder Kommentar bekommt Datum und Uhrzeit des Geräts.
- Ein Kommentar lässt sich **nicht ändern und nicht löschen**. Hast du dich
  vertan, schreib einen neuen Kommentar mit der Korrektur. Das schützt dich:
  der gebuchte Beleg bleibt unverändert, und jede Ergänzung ist nachvollziehbar.
- **Diktieren:** Tippe in das Kommentarfeld und dann auf das Mikrofon deiner
  Tastatur. Die App selbst nimmt keine Sprache auf und sendet nichts. Je nach
  Gerät und Einstellung schickt aber die Tastatur (z. B. Gboard oder die
  Apple-Tastatur) deine Sprache zur Erkennung an Google bzw. Apple. Wenn du das
  nicht möchtest, schalte in den Tastatureinstellungen die Offline-Erkennung
  ein oder tippe.

### Betrag eingeben – was funktioniert

Alle diese Schreibweisen versteht die App:

| Eingabe | Ergebnis |
|---|---|
| `12,50` | 12,50 € |
| `1.234,56` | 1.234,56 € |
| `1234.56` | 1.234,56 € |
| `50` | 50,00 € |
| `42,00 €` | 42,00 € |

Negative Beträge und 0 werden abgelehnt. Ob es sich um Geld zu oder ab handelt,
steuerst du oben mit **Ausgabe / Einnahme**, nicht mit einem Minus.

### Warum brutto und nicht netto?

Weil auf dem Beleg der Bruttobetrag steht. Die App rechnet daraus netto und
Umsatzsteuer und zeigt dir beides an, damit du den Steuersatz kontrollieren
kannst. Die Summe geht dabei immer exakt auf: der Bruttobetrag bleibt genau der,
den du eingetippt hast.

### Belege wiederfinden

Im Bereich **Belege**:
- **Suchfeld** durchsucht Beschreibung, Geschäftspartner und Notiz
- **Alle / Einnahmen / Ausgaben** filtert
- **Jahr** wählst du rechts oben
- Die Liste ist nach Monaten gruppiert, unter der Filterzeile steht der Saldo
  deiner aktuellen Auswahl

Ein Beleg mit Foto trägt ein Bildsymbol – so siehst du auf einen Blick, wo ein
Nachweis fehlt.

Mit dem Filter **Storniert** siehst du stornierte Belege. Du kannst sie öffnen
und lesen und ihnen Kommentare anhängen, aber nicht mehr ändern.

### Beleg ändern oder stornieren

Beleg antippen, ändern, speichern. Einen falschen Beleg stornierst du über das
Papierkorbsymbol oben rechts; die App fragt nach. Der Beleg verschwindet aus
allen Listen und Auswertungen, wird aber **nicht gelöscht**: Belege musst du
sieben (Österreich) bzw. acht Jahre (Deutschland) aufbewahren, deshalb bleibt er
samt Foto gespeichert. Jede Änderung und jede Stornierung wird intern
protokolliert – das dient der Nachvollziehbarkeit deiner Buchhaltung.

> **Aufbewahrungsfrist:** In Österreich 7 Jahre, in Deutschland 8 Jahre für
> Buchungsbelege. Die Frist gilt unabhängig von der App. Lies dazu
> [Abschnitt 11](#11-deine-daten-und-ihre-sicherung).

---

## 5. Deine Zahlen lesen

Die **Übersicht** zeigt dir für einen wählbaren Zeitraum:

**Zeitraum wählen:** dieser Monat, letzter Monat, dieses Quartal, dieses Jahr,
letztes Jahr. Quartal ist dabei, weil die Umsatzsteuervoranmeldung bei kleineren
Umsätzen quartalsweise abzugeben ist.

**Einnahmen, Ausgaben, Ergebnis** – jeweils netto. Netto, weil die
Umsatzsteuer für dich ein durchlaufender Posten ist und nicht zu deinem Gewinn
gehört.

**Umsatzsteuer** (nur bei Regelbesteuerung):
- Umsatz je Steuersatz
- Umsatzsteuer, die du eingenommen hast
- Vorsteuer, die du gezahlt hast
- **Zahllast** (du zahlst) oder **Guthaben** (du bekommst)

Als Kleinunternehmer siehst du hier stattdessen einen Hinweis, warum keine
Umsatzsteuer anfällt.

**Letzte 6 Monate** – zwei Balken je Monat, grün für Einnahmen, rot für Ausgaben.

**Letzte Belege** – die fünf neuesten zum direkten Antippen.

Nach unten ziehen aktualisiert die Ansicht.

---

## 6. Die Kleinunternehmergrenze

Wenn du die Kleinunternehmerregelung nutzt, zeigt die Übersicht eine Ampel mit
deinem Jahresumsatz. Die Regeln sind in Österreich und Deutschland verschieden,
und die App kennt beide.

### Österreich

- Vorjahr höchstens **55.000 €** — ohne Toleranz
- Laufendes Jahr: Grenze **55.000 €**
- Gezählt wird **brutto**. Als Kleinunternehmerin weist du keine Umsatzsteuer
  aus, dann ist brutto gleich netto. Steht auf einer Rechnung doch
  Umsatzsteuer (versehentlich oder bei Lieferungen ins Ausland), zählt sie zur
  Grenze dazu
- **Über 55.000 € zeigt die App Rot.** Das Gesetz kennt eine Toleranz von
  10 % (bis 60.500 €), aber ob sie für dich gilt, hängt von Umständen ab, die
  die App nicht kennt. Deshalb rechnet sie zur Sicherheit mit der harten
  Grenze und sagt dir, dass du ab jetzt Umsatzsteuer ausweisen sollst. Frag
  vor der nächsten Rechnung deine Steuerberatung, ob die Toleranz bei dir
  greift
- War dein Vorjahr über 55.000 €, gilt die Regelung im ganzen laufenden Jahr
  nicht. Erst wenn ein ganzes Jahr unter 55.000 € geblieben ist, kannst du im
  Folgejahr wieder Kleinunternehmerin sein

### Deutschland

- Vorjahr höchstens **25.000 €**
- Laufendes Jahr höchstens **100.000 €**
- **Im Gründungsjahr** höchstens **25.000 €** – dafür gibt es kein Vorjahr
- **Keine Toleranz.** Reißt du die Grenze, ist ab diesem Umsatz Umsatzsteuer
  auszuweisen.
- War dein Vorjahr über 25.000 €, gilt die Regelung im ganzen laufenden Jahr
  nicht – auch wenn du dieses Jahr wenig umsetzt

### Was die Farben bedeuten

| Farbe | Bedeutung | Was du tun solltest |
|---|---|---|
| Blau, Häkchen | Deutlich unter der Grenze | Nichts |
| Orange, Pfeil nach oben | Über 80 % der Grenze | Mit der Steuerberatung über den Wechsel zur Regelbesteuerung sprechen |
| Rot, Ausrufezeichen | Grenze endgültig überschritten | Sofort handeln: ab jetzt musst du Umsatzsteuer ausweisen |
| Orange, Fragezeichen | **Angaben fehlen** — Vorjahresumsatz oder Umsatz vor dem Start unbekannt | Auf „Umsatz ergänzen" tippen. Bis dahin sagt die App bewusst nicht „alles in Ordnung" |

Unter der Ampel steht immer im Klartext, was der Status für dich bedeutet.

> Die Ampel ist eine Hilfe, keine verbindliche Auskunft. Maßgeblich ist der
> Umsatzbegriff des Umsatzsteuergesetzes, und der kann in Sonderfällen von der
> Summe deiner erfassten Einnahmen abweichen.

---

## 7. Rechnungen schreiben

### Eine Rechnung erstellen

1. Bereich **Rechnungen** → Plus
2. **Empfänger** → *Wählen*. Noch kein Kunde da? Im Auswahlfenster unten auf
   *Neuen Kunden anlegen*.
3. **Zeitraum** prüfen:
   - *Rechnungsdatum* – heute
   - *Liefer-/Leistungsdatum* – **Pflichtangabe.** Wann hast du geliefert oder
     geleistet? Fehlt sie, ist die Rechnung formal mangelhaft, und dein Kunde
     verliert den Vorsteuerabzug.
   - *Fällig am* – aus deinem Zahlungsziel vorbelegt
4. **Positionen** erfassen: Bezeichnung, Menge, Einheit, Einzelpreis **netto**,
   Steuersatz. Weitere Position über das Plus in der Kartenüberschrift.
5. **Summe** kontrollieren
6. Optional **Anmerkungen** – erscheinen unter den Positionen
7. **Als Entwurf** speichern oder **Rechnung ausstellen**

### Entwurf oder Ausstellen?

**Entwurf** kannst du beliebig ändern und wieder löschen. Er hat noch **keine**
Rechnungsnummer.

**Ausstellen** vergibt die endgültige, fortlaufende Nummer und **sperrt** die
Rechnung. Danach lässt sich inhaltlich nichts mehr ändern – das ist gesetzlich so
gewollt. Korrekturen laufen über eine Storno- oder Gutschriftsrechnung.

> **Hinweis:** Storno- und Gutschriftsrechnungen kann diese Version noch nicht.
> Wenn du eine gestellte Rechnung korrigieren musst, kannst du sie derzeit nur
> stornieren und eine neue schreiben; das Storno-Dokument musst du außerhalb der
> App erstellen. Die Funktion ist für die nächste Version geplant.

### Die Checkliste am Ende

Fehlt etwas, ist der Knopf *Rechnung ausstellen* gesperrt, und die App sagt dir
genau was: Kunde, vollständige Kundenanschrift, mindestens eine Position, eine
Bezeichnung je Position, das Leistungsdatum, oder fehlende eigene Stammdaten.

### Menge mit Kommastellen

Für Stundenabrechnungen: `1,5` für eineinhalb Stunden, `0,25` für eine
Viertelstunde. Die App rechnet exakt – 0,25 Std × 99,99 € ergibt 25,00 €.

### Rechnungsnummern

Das Muster stellst du in den Stammdaten ein. Verfügbare Platzhalter:

| Platzhalter | Bedeutung | Beispiel |
|---|---|---|
| `{YYYY}` | Jahr, vierstellig | 2026 |
| `{YY}` | Jahr, zweistellig | 26 |
| `{MM}` | Monat, zweistellig | 03 |
| `{N}` | Laufende Nummer | 7 |
| `{NN}` bis `{NNNNNN}` | Laufende Nummer mit Nullen aufgefüllt | `{NNNN}` → 0007 |

Beispiele:

| Muster | Ergebnis |
|---|---|
| `RE-{YYYY}-{NNNN}` | RE-2026-0007 |
| `{YYYY}{MM}-{NNN}` | 202603-007 |
| `R{YY}/{N}` | R26/7 |

Das Muster **muss** eine laufende Nummer enthalten, sonst trüge jede Rechnung
dieselbe Nummer. Die App lehnt ein Muster ohne `{N}` ab.

Der Zähler läuft weiter und springt nie zurück – auch nicht, wenn du deine
Stammdaten bearbeitest.

### Rechnung versenden

In der Rechnungsliste auf das PDF-Symbol. Die App erzeugt das PDF und öffnet den
Teilen-Dialog deines Telefons: E-Mail, Messenger, Cloud-Ordner – du entscheidest.

### Status pflegen

Über das Dreipunkt-Menü in der Rechnungskachel:

| Status | Bedeutung |
|---|---|
| **Entwurf** | Noch nicht gestellt, änderbar, löschbar |
| **Offen** | Gestellt, Zahlung ausstehend |
| **Überfällig** | Gestellt, Fälligkeit verstrichen – wird rot |
| **Bezahlt** | Erledigt |
| **Storniert** | Zurückgenommen, bleibt aber erhalten |

Oben in der Liste steht die Summe aller gestellten, noch nicht bezahlten
Rechnungen.

### Was auf dem PDF steht

Die App setzt alle Pflichtangaben nach § 11 UStG (Österreich) bzw. § 14 UStG
(Deutschland): beide Anschriften, deine Steuernummer bzw. UID, Rechnungsdatum,
fortlaufende Nummer, Positionen mit Menge und Bezeichnung, Leistungsdatum,
Entgelt je Steuersatz und den Steuerbetrag.

Als Kleinunternehmer fehlt die Steuerspalte vollständig, dafür erscheint der
gesetzliche Befreiungshinweis.

**Firmenlogo:** In den Stammdaten unter **Rechnungen → Logo wählen** suchst du
ein Bild aus deiner Fotobibliothek aus (am besten PNG oder JPEG). Die App
verkleinert es und setzt es oben rechts auf das PDF – zusätzlich zu Name und
Anschrift, nie stattdessen. **Entfernen** nimmt es von künftigen Rechnungen.
Bereits ausgestellte Rechnungen behalten das Logo, das beim Ausstellen galt;
Entwürfe zeigen immer das aktuelle.

---

## 8. Kunden verwalten

Bereich **Rechnungen** → Personensymbol rechts oben.

Für eine gültige Rechnung braucht ein Kunde **Name, Straße, PLZ und Ort**. Fehlt
etwas, zeigt die App ein Warndreieck neben dem Kunden.

Die **UID-Nummer** des Kunden brauchst du bei Geschäftskunden aus dem EU-Ausland,
weil dann das Reverse-Charge-Verfahren greift.

Ein Kunde, für den bereits Rechnungen existieren, lässt sich nicht löschen –
Rechnungen dürfen ihren Empfänger nicht verlieren.

---

## 9. Export an die Steuerberatung

Bereich **Export**.

1. **Jahr** wählen
2. Optional **eingrenzen** auf Quartal oder Monat
3. **Vorschau** prüfen: Anzahl der Belege und Summen. Wenn hier 0 Belege stehen,
   wäre die Datei leer – der Export ist dann gesperrt.
4. **Format** antippen → Teilen-Dialog

### Die Formate

| Format | Wann |
|---|---|
| **Belegliste (CSV)** | Der sichere Standard. Öffnet in Excel, Numbers und jedem Buchhaltungsprogramm. Nimm den, wenn du nicht weißt, womit deine Kanzlei arbeitet. Enthält auch die Seitenzahl, alle Kommentare mit Zeitpunkt und bei Fremdwährung Währung, Originalbetrag, Kurs, Kursquelle, Kursdatum und Bankbetrag. |
| *Hinweis Fremdwährung* | DATEV und BMD erhalten nur den Euro-Betrag; Originalbetrag und Kurs findet deine Kanzlei in der Belegliste. |
| **DATEV-Buchungsstapel** | Nur bei Land Deutschland. Für DATEV-Kanzleien. Der jüngste Kommentar steht gekürzt im Buchungstext (wie auch bei BMD). |
| **BMD-Buchungssätze** | Nur bei Land Österreich. Für BMD NTCS. |
| **Umsatzsteuer-Zusammenfassung** | Die Zahlen für die Umsatzsteuervoranmeldung: Bemessungsgrundlagen je Satz, Vorsteuer, Zahllast. |

### Was du mit deiner Kanzlei einmal klären solltest

Die Kontonummern und Steuercodes in den Exporten sind **Vorschläge** nach
gängigen Kontenrahmen. Jede Kanzlei bucht etwas anders. Schick beim ersten Mal
einen Probeexport und frag, ob die Zuordnung passt. Anpassen kannst du die
Kontonummer je Kategorie unter **Einstellungen → Kategorien**.

Beim DATEV-Export stehen Berater- und Mandantennummer auf `0`. Das ist normal –
deine Kanzlei ordnet den Stapel beim Import selbst zu.

---

## 10. Einstellungen

Übersicht → Zahnrad.

**Stammdaten** – dein Firmenprofil ändern

**Fremdwährung** – Schalter „Tageskurs vom Finanzamt genehmigt“. Standardmäßig
aus; dann rechnet die App mit dem Monatskurs. Nur einschalten, wenn dir das
Finanzamt den Tageskurs genehmigt hat.

**Kategorien** – Kategorien ansehen, eigene anlegen und löschen. Die
vorgegebenen 16 Kategorien tragen ein Schlosssymbol und bleiben erhalten. Beim
Anlegen kannst du eine Kontonummer für den Export mitgeben.

**Rechtlicher Rahmen** – die für dein Land geltenden Steuersätze, Rechtsverweise
und Fristen zum Nachschauen

**Belege auslesen** – schaltet das automatische Auslesen fotografierter
Belege ein oder aus (Standard: an), siehe Abschnitt 4

**Daten und Sicherung** – siehe nächster Abschnitt

**App-Sperre** – schützt die App mit einer PIN und, wenn dein Gerät es kann,
mit Fingerabdruck oder Face ID. Standardmäßig aus.

**Symbol auf Startbildschirm legen** – nur unter Android: legt das App-Symbol
auf deinen Startbildschirm. Android fragt dich dazu in einem eigenen Dialog
„Zum Startbildschirm hinzufügen“. Hast du die App nicht aus dem Play Store
installiert, fehlt das Symbol dort sonst. Die App bietet das nach dem ersten
Einrichten einmal von selbst an; sagst du „Nein danke“, fragt sie nicht
wieder.

*Einrichten:* Einstellungen → App-Sperre. Lies den Hinweis zur vergessenen PIN,
lege eine PIN mit 6 bis 8 Ziffern fest (zweimal; `000000` oder `123456` gehen
nicht), schalte auf Wunsch Fingerabdruck/Face ID ein und wähle, wann die App im
Hintergrund sperren soll: sofort, nach 1 Minute (Standard), 5 oder 15 Minuten.
Bestätige den Hinweis und tippe auf „App-Sperre einschalten". Hast du noch
keine Sicherung, warnt dich die App und bietet den Weg zur Datensicherung an –
lege bitte **vorher** eine an.

*Im Alltag:* Beim Start und nach der gewählten Zeit im Hintergrund fragt die
App nach Fingerabdruck/Face ID oder PIN. Im App-Umschalter ist der Inhalt
verdeckt. Nach fünf falschen PINs musst du 30 Sekunden warten, danach jeweils
doppelt so lange, höchstens eine Stunde. Daten werden dabei nie gelöscht.

*PIN ändern oder ausschalten:* Einstellungen → App-Sperre, mit der aktuellen
PIN. „PIN ändern" schaltet die Sperre aus; du legst danach gleich eine neue PIN
fest.

*PIN vergessen:* Niemand kann die PIN zurücksetzen, auch der Anbieter nicht –
es gibt kein Konto und keinen Server. Der Weg: App-Daten löschen (Android:
Einstellungen → Apps → Buchhaltung → Speicher → Daten löschen) oder die App
löschen und neu installieren, dann bei der Ersteinrichtung „Aus Sicherung
wiederherstellen" mit Kennwort bzw. Wiederherstellungscode. Was nach der
letzten Sicherung erfasst wurde, ist dabei verloren.

**Wichtiger Hinweis** – die rechtliche Abgrenzung. Bitte einmal lesen.

---

## 11. Deine Daten und ihre Sicherung

### Wo deine Daten liegen

Ausschließlich auf deinem Telefon, in einer Datenbank im privaten Bereich der
App. Andere Apps kommen nicht heran. Es gibt keinen Server, auf den etwas
hochgeladen wird.

Daten verlassen dein Telefon **nur**, wenn du selbst auf Teilen tippst – beim
Rechnungs-PDF, beim Export oder bei der Datensicherung.

### Datensicherung

Geht dein Telefon verloren oder kaputt, sind ohne Sicherung alle Belege weg –
die Aufbewahrungspflicht (7 Jahre in Österreich, 8 Jahre in Deutschland) gilt
trotzdem. Deshalb:

1. **Einstellungen → Datensicherung → Sicherung erstellen**
2. Ein **Kennwort** festlegen, mindestens 10 Zeichen, zweimal eingeben.
   **Schreib es dir auf.** Ohne Kennwort lässt sich die Sicherung nicht öffnen,
   und niemand kann es zurücksetzen – auch wir nicht.
3. Tippfehler im Kennwort? Mit dem **Auge-Symbol** am Feldrand machst du es
   sichtbar.
4. Im Teilen-Dialog einen Ort **außerhalb deines Telefons** wählen: iCloud
   Drive, Google Drive, „Auf Dateien speichern", eine E-Mail an dich selbst.

Die Datei heißt zum Beispiel `Sicherung_2026-10-10_1800.jbbackup`. Sie enthält
alle Daten und Belegfotos und ist verschlüsselt.

Hast du noch nie oder seit **30 Tagen** nicht gesichert, erinnert dich die
Übersicht daran – oder du richtest die automatische Sicherung ein.

### Automatisch sichern

Statt von Hand kann die App selbst sichern – in einen Ordner deiner Wahl, etwa
in iCloud Drive oder Google Drive. Das ist **standardmäßig aus**.

1. **Einstellungen → Datensicherung → Automatische Sicherung → Einrichten**
2. Die Erklärung lesen und **Ordner wählen**.
3. Die App zeigt dir einen **Wiederherstellungscode** (52 Zeichen). Schreib ihn
   ab oder speichere ihn im Passwortmanager – **getrennt von deinem Handy**. Er
   wird nur dieses eine Mal angezeigt. Ohne ihn kann niemand eine automatische
   Sicherung auf einem anderen Gerät öffnen, auch du nicht.

Danach sichert die App nach jeder Änderung höchstens einmal am Tag, wenn du sie
öffnest. Jede Sicherung wird nach dem Speichern zur Probe wieder geöffnet; erst
dann gilt sie als gelungen. Klappt etwas nicht – Ordner nicht erreichbar,
Zugriff entzogen –, siehst du es auf der Übersicht.

Im Ordner bleiben die letzten 7 Sicherungen, je Monat eine für ein Jahr und
**je Jahr eine dauerhaft** – damit du über die Aufbewahrungsfrist hinweg
zurückgreifen kannst. Andere Dateien im Ordner fasst die App nicht an.

**Sicherung prüfen** öffnet die jüngste Sicherung zur Probe, ohne etwas zu
ändern. Mach das ab und zu, mindestens einmal im Jahr.

Die Sicherung ersetzt nicht deine gesetzliche Aufbewahrungspflicht. Geht dein
Handy verloren, stell die Daten bald auf einem neuen Gerät wieder her.

### Auf einem neuen Telefon weitermachen

Beim ersten Start auf **„Aus einer Datensicherung wiederherstellen"** tippen
(oder später unter Einstellungen → Datensicherung). Datei auswählen, Kennwort
– bei einer automatischen Sicherung den Wiederherstellungscode – eingeben. Die App zeigt dir, was die Sicherung enthält – Unternehmen, Datum,
Anzahl der Belege, Rechnungen, Kunden und Fotos. Erst nach deiner Bestätigung
werden die Daten eingelesen. **Alles, was vorher auf dem Gerät war, wird dabei
ersetzt.**

---

## 12. Häufige Fragen

**Kann ich die App auf zwei Geräten nutzen?**
Nein. Jede Installation hat ihren eigenen Datenbestand, und es gibt keine
Synchronisierung.

**Hört die App beim Diktieren mit?**
Nein. Die App hat keine Spracherkennung. Diktieren ist eine Funktion deiner
Tastatur; ob sie die Sprache auf dem Gerät erkennt oder an Google bzw. Apple
sendet, legst du in den Tastatureinstellungen fest.

**Kostet die App etwas? Brauche ich ein Konto?**
Kein Konto, keine Anmeldung, keine Werbung, kein Tracking.

**Ich habe die Kleinunternehmerregelung falsch eingestellt. Was jetzt?**
Ändere den Schalter in den Stammdaten. Neue Belege und Rechnungen verhalten sich
danach richtig. **Bereits gestellte Rechnungen bleiben unverändert** – sie
behalten die Steuerbehandlung des Zeitpunkts, an dem du sie ausgestellt hast.
Falsche gestellte Rechnungen musst du deiner Kanzlei melden.

**Ich habe eine Rechnung ausgestellt und einen Fehler entdeckt.**
Eine gestellte Rechnung darf nicht geändert werden. Markiere sie als
*Storniert* und schreibe eine neue. Das Storno-Dokument für deinen Kunden musst
du in dieser Version noch außerhalb der App erstellen.

**Warum kann ich meinen Kunden nicht löschen?**
Weil Rechnungen an ihn existieren. Eine Rechnung ohne Empfänger wäre ungültig.

**Warum sieht die App in Deutschland anders aus als in Österreich?**
Weil das Steuerrecht anders ist: andere Steuersätze, andere Umsatzgrenzen, andere
Gesetzesverweise, andere Bezeichnung der Steuernummer. Die App richtet sich nach
dem Land in deinen Stammdaten.

**Kann ich mit Fremdwährungen arbeiten?**
Bei Ausgaben ja: die App rechnet mit Kurs in Euro um (siehe *Belege in fremder
Währung*). Deine eigenen Rechnungen sind immer in Euro.

**Ist mein Beleg mit dem Foto gültig?**
Ein Belegfoto ist grundsätzlich als Nachweis geeignet. Wichtig ist, dass es
lesbar ist und dauerhaft verfügbar bleibt – deshalb der Hinweis zur Sicherung.
Ob du das Papieroriginal zusätzlich behalten musst, klärst du am besten mit
deiner Steuerberatung.

---

## 13. Wenn etwas nicht geht


**„Auf dem Foto wurde nichts erkannt – bitte von Hand erfassen."** — das Foto
ist unscharf, zu dunkel oder schräg. Neu fotografieren und „Erneut auslesen",
oder die Felder selbst ausfüllen.

**„Auslesen nicht möglich: …"** — die Erkennung ist auf diesem Gerät
fehlgeschlagen. Der Beleg lässt sich trotzdem von Hand erfassen.

**„Kurs nicht abrufbar: …"** — keine Internetverbindung oder die EZB ist nicht
erreichbar. Später erneut tippen oder den Kurs von Hand eintragen.

**„Die EZB nennt für … keinen Kurs."** — die EZB veröffentlicht für diese
Währung keinen Referenzkurs. Kurs von Hand eintragen (z. B. laut Bank).

**„Bitte Originalbetrag und Kurs angeben."** / **„Kurs > 0, höchstens 6
Nachkommastellen"** — bei einem Beleg in fremder Währung fehlt der Betrag laut
Beleg oder der Kurs ist ungültig. Kurs als Einheiten je 1 Euro, z. B. `1,0823`.

**„Bitte zuerst den Währungscode eingeben, z. B. USD."** — vor „Kurs abrufen“
den dreistelligen Währungscode eintragen.

**„Der Sicherungsordner ist nicht erreichbar. Bitte den Ordner neu wählen."** —
der Ordner wurde gelöscht oder die App hat keinen Zugriff mehr. Unter
Datensicherung auf „Ordner ändern" tippen.

**„Kein Sicherungsschlüssel auf diesem Gerät"** — die automatische Sicherung
neu einrichten; du bekommst einen neuen Wiederherstellungscode.

**„Mindestens 10 Zeichen"** / **„Die Kennwörter stimmen nicht überein"** — beim
Kennwort der Datensicherung.

**„6 bis 8 Ziffern"**, **„Nicht nur dieselbe Ziffer"**, **„Keine einfache
Zahlenfolge"**, **„Stimmt nicht überein"** — beim Festlegen der PIN der
App-Sperre.

**„Zu viele Fehlversuche. Nächster Versuch in …"** — auf dem Sperrbildschirm
nach fünf falschen PINs. Warten; Fingerabdruck/Face ID funktioniert weiterhin.
PIN vergessen: siehe Abschnitt 10, App-Sperre.

**„Das Kennwort passt nicht zu dieser Sicherung, oder die Datei ist
beschädigt."** — Kennwort prüfen (Groß- und Kleinschreibung). Stimmt es, ist
die Datei beim Kopieren beschädigt worden; nimm eine andere Sicherung.

**„Keine Datensicherung dieser App."** — die gewählte Datei ist keine
`.jbbackup`-Datei.

**„Die Sicherung stammt aus einer neueren App-Version."** — erst die App
aktualisieren, dann wiederherstellen.
**„Bitte gib einen Betrag ein"** – die Eingabe ist keine Zahl. Erlaubt sind
Ziffern, Komma, Punkt und ein Minus.

**„Der Betrag darf nicht 0 sein"** – ein Beleg über 0 € ergibt keine Buchung.

**„Bitte positiv eingeben und oben Einnahme/Ausgabe wählen"** – die Richtung
steuert das Vorzeichen, nicht ein Minus im Betrag.

**„Bitte angeben – 0, wenn es keinen Umsatz gab"** — beim Umsatz vor Nutzung
der App. Ein leeres Feld ist für die App „unbekannt"; trag 0 ein, wenn es
keinen Umsatz gab.

**„Bitte ein Jahr bis … eingeben"** — beim Gründungsjahr. Erlaubt ist eine
Jahreszahl ab 1900 bis zum laufenden Jahr; leer lassen, wenn du nicht dieses
Jahr gegründet hast und es nicht angeben willst.

**„Eine Beschreibung ist Pflicht"** – ohne Bezeichnung ist der Beleg später nicht
nachvollziehbar. Ein Wort genügt.

**„Die Prüfziffer der UID stimmt nicht – bitte Tippfehler prüfen"** – die
Nummer hat das richtige Muster, aber eine Ziffer ist vermutlich vertippt.

**„Österreichische UID: ATU und 8 Ziffern"** / **„Deutsche USt-IdNr.: DE und 9
Ziffern"** / **„Die Nummer beginnt nicht mit einem EU-Ländercode"** – Format
prüfen; Leerzeichen und Punkte sind egal.

**„Mit Firmenbuchnummer ist auch das Gericht Pflicht"** – trag das
Firmenbuch- bzw. Registergericht ein oder lass die Nummer leer.

**„Eigene UID-Nummer (Rechnung über 10000 € brutto)"** – in Österreich braucht
eine Rechnung über 10.000 € mit Umsatzsteuer deine UID und die deines Kunden.

**„Das Muster braucht eine laufende Nummer, z. B. {NNNN}"** – siehe
[Rechnungsnummern](#rechnungsnummern).

**„Es fehlt noch: …"** beim Ausstellen – die Liste sagt dir genau, was fehlt.

**Der Knopf *Rechnung ausstellen* ist grau** – es fehlt noch eine Pflichtangabe.
Scroll nach unten, dort steht welche.

**Das Foto lässt sich nicht übernehmen** – prüfe in den Telefoneinstellungen, ob
die App auf Kamera und Fotos zugreifen darf.

**Der Export ist gesperrt** – im gewählten Zeitraum gibt es keine Belege. Prüfe
Jahr und Monat.

**Ein Belegfoto wird nicht mehr angezeigt** – das kann passieren, wenn das Foto
außerhalb der App gelöscht wurde. Die Buchung bleibt erhalten; du kannst ein
neues Foto hinzufügen.

---

## 14. Was die App nicht kann

Damit du nicht darauf wartest:

- **Keine Registrierkasse.** Die App erfüllt die österreichische
  Registrierkassensicherheitsverordnung nicht. Wer mehr als 15.000 € Umsatz und
  7.500 € Barumsätze im Jahr hat, braucht zusätzlich eine
  registrierkassenpflichtige Lösung.
- **Keine E-Rechnung.** Das PDF der App ist keine strukturierte E-Rechnung
  (XRechnung, ZUGFeRD, ebInterface). Für Geschäftskunden in Deutschland wird das
  mittelfristig wichtig.
- **Keine Storno-/Gutschriftsrechnung** – geplant
- **Belegerkennung mit einem Steuersatz je Beleg.** Die App liest Belege auf dem Gerät aus; bei mehreren Steuersätzen auf einem Beleg füllt sie den größten Anteil vor, aufteilen musst du von Hand.
- **Keine Lohnverrechnung, keine Bilanz, keine doppelte Buchführung**
- **Keine automatische Übermittlung** an FinanzOnline oder ELSTER. Die App
  liefert dir die Zahlen; die Erklärung machst du oder deine Kanzlei.
- **Keine Synchronisierung** zwischen Geräten

### Und der wichtigste Satz

Diese App unterstützt dich bei der Buchhaltung. Sie ist **keine
Steuerberatung**. Für die Richtigkeit deiner Buchhaltung und deiner
Steuererklärungen bist du selbst verantwortlich. Bei Zweifeln frag deine
Steuerberatung – das kostet weniger als eine Korrektur nach einer Prüfung.
