# Benutzerhandbuch – JeNi bucht

**Für App-Version 0.21.1** · Stand 2026-10-16

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

### Hilfe in der App

Rechts oben auf jedem Hauptbildschirm und im Beleg- und Rechnungsformular
findest du ein **Fragezeichen**. Es öffnet die Hilfe: Tippe in das Feld
**„Frag mich etwas …“** ein paar Wörter, etwa *Beleg löschen*, *Rückseite*
oder *Kleinunternehmergrenze*. Die App sucht in diesem Handbuch – ohne
Internet – und zeigt passende Abschnitte mit einem kurzen Auszug. Ein Tipp
öffnet den Abschnitt zum Lesen. Aus dem Belegformular geöffnet stehen
Beleg-Themen vorn.

Findet die Hilfe nichts, tippe auf **E-Mail an den Support**. Deine Mail-App
öffnet sich mit der Adresse office@jenibarb.com und einem Betreff samt
App-Version. Es wird nichts angehängt; du schreibst und schickst selbst.

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

1. In der **Übersicht** unten in der Mitte auf den großen runden Knopf
   **Beleg** (Kamerasymbol) tippen –
   der **Dokumentenscanner** deines Telefons öffnet sich sofort: er findet
   den Beleg, schneidet ihn gerade zu und macht ihn gut lesbar; mehrere Seiten
   nimmst du gleich hintereinander auf, mit **Fertig** bzw. **Speichern**
   geht es zurück. Danach hellt die App das Papier auf, verstärkt die
   Schrift (farblose Kassenbons werden grau) und liest Betrag, Datum und
   Händler aus – wie bei einem Foto. Ohne Scanner (z. B. Telefon ohne Google-Dienste) öffnet
   sich einfach die Kamera. Der Knopf liegt mittig, damit du ihn mit dem
   rechten wie dem linken Daumen erreichst. Ob **Einnahme** oder **Ausgabe**,
   wählst du oben im Formular (vorbelegt: Ausgabe). Alternativ im Bereich
   **Belege**: derselbe runde Knopf an derselben Stelle.
2. **Bruttobetrag** eintippen – also die Zahl, die auf dem Beleg steht, inklusive
   Umsatzsteuer. Netto und Steuer rechnet die App sofort darunter aus.
3. **Umsatzsteuersatz** prüfen. Die App wählt deinen Standardsatz vor.
   Stehen auf dem Beleg **mehrere Steuersätze** (z. B. im Restaurant Speisen
   10 % und Getränke 20 %, im Supermarkt 10 % und 20 %), siehe unten
   „Beleg mit mehreren Steuersätzen“.
4. Im Formular liegt der runde Knopf **Seite** mittig über **Beleg
   speichern** – damit fotografierst du weitere Seiten; ein vorhandenes Foto
   holst du mit **Foto auswählen** bzw. **Seite wählen** – so oft du brauchst. Vor dem Speichern kannst du Seiten mit den
   Pfeilen umsortieren; zum Löschen tippst du die Seite an und wählst
   **Seite löschen**. Ist die Rückseite
   beschrieben, fotografiere sie mit – bei nur einer Seite erinnert dich der
   runde Knopf mit der Beschriftung **Rückseite?** daran.
5. **Beschreibung** eintragen – Pflichtfeld. „Bürostuhl" ist gut, „Rechnung"
   nützt dir in zwei Jahren nichts.
6. Optional: Datum (mit **Heute** / **Gestern** ein Tipp), Lieferant bzw. Kunde, Kategorie, Zahlungsart, Notiz und
   ein **Kommentar** (siehe unten)
7. Unten auf den großen Knopf **„Vollständig – Beleg speichern (2 Seiten)"**
   tippen. Damit bestätigst du zugleich, dass alle Seiten samt beschriebener
   Rückseiten erfasst sind – ein eigenes Häkchen gibt es nicht. Der Knopf
   bleibt sichtbar, auch wenn die Tastatur offen ist. Ohne neue Fotos heißt er
   einfach **Beleg speichern** bzw. **Änderungen speichern**.

### Beleg mit mehreren Steuersätzen

1. Bruttobetrag des ganzen Belegs eintragen.
2. Auf **Weiteren Steuersatz hinzufügen** tippen. Es erscheinen zwei Teile:
   der erste trägt zunächst den ganzen Betrag, der zweite den Rest.
3. Im ersten Teil den Satz wählen und den **Bruttobetrag dieses Satzes**
   eintippen, so wie er auf dem Beleg steht (z. B. Speisen 33,00 €). Der
   letzte Teil rechnet sich selbst aus (Rest, z. B. Getränke 14,40 €).
4. Für einen dritten Satz noch einmal **Weiteren Steuersatz hinzufügen**.
   Mit dem Minus-Symbol entfernst du einen Teil.

Unter jedem Teil stehen Netto und Steuer. Gespeichert wird nur, wenn die Teile
genau den Belegbetrag ergeben – sonst zeigt die App, wie viel fehlt oder zu
viel ist. Liest die App einen Beleg mit mehreren Sätzen aus, ist die Aufteilung
schon vorbelegt – bitte prüfen.

**Bewirtung:** Wähl die Kategorie **Bewirtung** (bei Restaurantbelegen schlägt
die App sie meist schon vor). Dann zählt die App automatisch nur den
abziehbaren Teil als Betriebsausgabe: in Österreich 50 % (Bewirtung mit
Werbezweck), in Deutschland 70 %. Die Vorsteuer ziehst du voll ab. Bist du
Kleinunternehmer, gilt der Anteil vom Bruttobetrag. Den nicht abziehbaren Teil
siehst du in der Übersicht, in den Kennzahlen, der Saldenliste, dem
Jahresabschluss und im Export.

In Deutschland zeigt das Formular zusätzlich **Anlass** und **Teilnehmer**.
Das Finanzamt verlangt diese Angaben für den Bewirtungsnachweis; trag sie am
besten gleich ein. Speichern kannst du auch ohne sie.

### Belege automatisch auslesen

Sobald du einen neuen Beleg fotografierst oder ein Foto wählst, liest die App
ihn **auf deinem Telefon** aus – bei mehreren Seiten alle Seiten. Sie trägt
ein, was sie findet: **Belegdatum, Bruttobetrag, Umsatzsteuersatz,
Lieferant, Rechnungsnummer und UID des Ausstellers**. Solche Felder sind mit
**„erkannt – bitte prüfen“** markiert.

- **Prüf die markierten Felder** mit dem Beleg. Gebucht wird erst, wenn du auf
  **Beleg speichern** tippst – vorher ist nichts verbucht.
- Was die App nicht sicher erkennt, lässt sie leer.
- **Beschreibung und Kategorie** schlägt die App vor, z. B. „SPAR –
  Lebensmittel (Baguette, Biomilch)“ mit Kategorie *Sonstige Ausgaben* oder
  „Marktgemeinde Treffen – Maut“ mit *Kfz-Kosten*. Eine Beschreibung, die du
  schon getippt hast, überschreibt sie nicht. Ohne Vorschlag steht ein neuer
  Beleg auf *Sonstige Ausgaben*.
- **Die App lernt je Lieferant.** Speicherst du einen Beleg, merkt sie sich
  den Namen, wie du ihn eingetragen hast, dazu Kategorie, Steuersatz, Währung
  und Zahlungsart. Beim nächsten Beleg desselben Lieferanten (gleiche UID oder
  gleicher Name, auch wenn das Foto ihn etwas anders liest) stehen sie schon
  drin – Partner, Kategorie und Zahlungsart mit **„wie beim letzten Mal“**.
  Einen Steuersatz, der lesbar auf dem Beleg steht, nimmt die App vom Beleg.
  Korrigierst du etwas, gilt beim nächsten Mal deine Korrektur. Das bleibt auf
  deinem Telefon.
- **Fremdsprachige Belege** (z. B. Slowenien „Skupaj“, „DDV“, Kroatien
  „Ukupno“, „PDV“, Italien „Totale“, „IVA“, Ungarn „Összesen“, „ÁFA“,
  Tschechien „Celkem“, „DPH“, Polen „Razem“, Frankreich „TVA“, Niederlande
  „BTW“, Skandinavien „I alt“, „Summa“, „MOMS“, „MVA“) werden ebenfalls
  ausgelesen.
- **Beleg ohne Steuersatz** (z. B. nur der Kartenbeleg): die App erfindet
  keinen Satz, stellt **0 %** ein und weist darauf hin, dass du ohne
  Steuerausweis keine Vorsteuer abziehen kannst. Für den Abzug fordere beim
  Aussteller eine Rechnung mit Steuersatz an.
- **4,9 % für Grundnahrungsmittel** (Österreich, ab 1. Juli 2026): die App
  kennt den Satz und bietet ihn für Belege ab diesem Tag an. Bei einem
  früheren Datum erscheint er nicht in der Auswahl.
- **Erneut auslesen** unter den Fotos startet die Erkennung noch einmal, z. B.
  nachdem du eine weitere Seite ergänzt hast. Achtung: bereits eingetragene
  Werte werden dabei durch die erkannten ersetzt.
- **Mehrere Steuersätze** (z. B. Hotel mit Übernachtung und Frühstück): die
  App belegt die Aufteilung je Satz vor (siehe „Beleg mit mehreren
  Steuersätzen“). Bitte die Beträge prüfen.
- **Fremde Währung** (z. B. eine Rechnung in US-Dollar) bei Ausgaben: die App
  schaltet auf „Beleg in fremder Währung“ und trägt den Betrag laut Beleg ein.
  Den Kurs holst du mit **Kurs abrufen** (siehe *Belege in fremder Währung*).
- **Ausländische Umsatzsteuer** (z. B. Tankbeleg aus Dänemark mit 25 % MOMS,
  Hotel in Deutschland mit 19 %): die App erkennt sie, stellt aber **0 %**
  ein und zeigt den Hinweis „nicht als Vorsteuer abziehbar“. Der Beleg wird
  brutto als Ausgabe erfasst. Zurück bekommst du ausländische Umsatzsteuer
  nur über das EU-Erstattungsverfahren (Österreich: FinanzOnline,
  Deutschland: BZSt; bis 30.09. des Folgejahres) – als Kleinunternehmer gar
  nicht.
- **Währung unklar**: steht auf dem Beleg nur „$“ oder „kr“, trägt die App den
  Betrag nicht ein, sondern nennt ihn im Hinweis. Wähle „Beleg in fremder
  Währung“ und trag Währung und Betrag selbst ein. Sieht der Beleg klar
  amerikanisch aus (z. B. „$25.00“, „Total“, „October 15, 2026“), schlägt die
  App **USD** vor und füllt „Beleg in fremder Währung“ schon aus – prüfen,
  **Kurs abrufen**, fertig.
- **Lieferant**: neben der ersten Zeile erkennt die App bekannte Anbieter wie
  Google, Apple, Amazon, Microsoft oder Adobe überall auf dem Beleg.
- **Ohne Steuerausweis** (z. B. Kartenbeleg) stellt die App 0 % ein. Den
  Hinweis „kein Vorsteuerabzug“ siehst du nur, wenn du Vorsteuer abziehen
  darfst – als Kleinunternehmer nicht.
- Steht nur der **Steuerbetrag** auf dem Beleg (z. B. „inkl. MwSt. € 16,50“
  bei € 99,00), rechnet die App den Satz daraus (hier 20 %).
- Bist du **Kleinunternehmer**, übernimmt die App den erkannten Steuersatz und
  erinnert dich, dass die Vorsteuer für dich nicht abziehbar ist.
- Das Foto selbst wird nie verändert. Im Änderungsprotokoll steht, was erkannt
  und was von dir bestätigt wurde.
- Ausschalten: Einstellungen → **Belege auslesen**.

Datenschutz: Foto und Text verlassen dein Telefon dafür nicht, die Erkennung
läuft auch im Flugmodus. Unter Android sendet die eingebaute Erkennung von
Google (ML Kit) allerdings Nutzungs- und Diagnosedaten ohne Fotos und Text an
Google; unter iOS überträgt die Apple-Erkennung nichts.

### Kassen-QR und Zahlungs-QR

Viele Kassenbons tragen einen **QR-Code** – in Österreich seit 2017 auf jedem
Bon einer Registrierkasse, in Deutschland bei Kassen mit TSE. Die App liest
ihn **auf demselben Foto** mit, du musst nichts extra tun.

- **Betrag, Datum und Steuersätze** kommen dann aus dem QR-Code statt aus dem
  Text. Diese Felder tragen den Vermerk **„vom Kassen-QR“**. Sie sind von der
  Kasse signiert und daher zuverlässiger als die Texterkennung.
- **Mehrere Sätze** (z. B. Lebensmittel 10 % und Haushaltswaren 20 %) belegt
  die App als Aufteilung vor.
- **4,9 %** (Österreich ab 1. Juli 2026): der QR-Code unterscheidet nicht
  zwischen 4,9 % und 19 %. Steht der Satz lesbar auf dem Bon, nimmt die App
  ihn von dort; sonst bittet sie dich, den Satz zu wählen.
- **Händler**: der QR-Code enthält keinen Namen. Die App nimmt ihn vom Bon und
  merkt sich beim Speichern, zu welcher Kasse er gehört. Beim nächsten Bon
  derselben Kasse steht dein Name schon drin.
- **Zahlungs-QR** („GiroCode“, z. B. auf Handwerkerrechnungen): Empfänger,
  Betrag, IBAN und Verwendungszweck werden übernommen; IBAN und Referenz
  stehen in der Notiz. Zahlen musst du weiterhin in deiner Banking-App.
- Das **Foto bleibt der Beleg**. Der QR-Code ist nur eine Lesehilfe.

### Beleg aus einer anderen App teilen

Ein Foto in der Galerie, ein Bild aus einer Mail oder einem Messenger:
**Teilen → Buchhaltung**. Die App öffnet sofort „Ausgabe erfassen“ mit dem
Bild als Seite und liest es aus. Du prüfst und tippst auf Speichern.
Am iPhone heißt es **Teilen → In Buchhaltung öffnen** bzw. „Kopieren nach“.

### PDF-Rechnungen und E-Rechnungen

Rechnung als PDF aus der Mail, dem Kundenportal oder dem Download-Ordner:
**Teilen → Buchhaltung**.

- **E-Rechnung** (ZUGFeRD, Factur-X, XRechnung, ebInterface): die App liest
  die maschinenlesbaren Daten – Lieferant, UID, Rechnungsnummer, Datum,
  Beträge je Steuersatz und IBAN. Die Felder tragen **„aus der E-Rechnung“**.
  Das ist die genaueste Art, eine Rechnung zu erfassen.
- **Gewöhnliche PDF**: die App zeigt die Seiten als Bild und liest sie wie ein
  Foto aus (bis zu 5 Seiten).
- **XML-Datei** allein (z. B. XRechnung von einer Behörde): wird genauso
  übernommen, nur ohne Seitenbild.
- Die **Originaldatei** bewahrt die App unverändert auf, mit Prüfsumme
  (SHA-256). Im Beleg steht „Original aufbewahrt“. Sie ist in jeder
  Datensicherung enthalten, und die Belegliste für die Kanzlei nennt sie in
  der Spalte „Originaldatei“.
- Verlässt du das Formular ohne Speichern, wird die Kopie wieder gelöscht.

Alles läuft auf deinem Telefon; die Datei wird nirgends hochgeladen.

### Rechnung über einen QR-Link laden

Manche Rechnungen und Bons tragen einen QR-Code mit einer Webadresse
(„Rechnung online abrufen“). Erkennt die App so einen Code auf dem Foto,
erscheint unten ein Streifen: **„QR-Code: Rechnung laden von“** und groß die
**Domain**, z. B. *rechnung.energie-beispiel.at*.

1. Prüf die Domain: Kennst du den Absender?
2. Tipp auf **Laden**. Erst jetzt verbindet sich die App mit diesem Server.
3. Kommt eine PDF- oder E-Rechnung zurück, übernimmt die App sie wie eine
   geteilte Datei (siehe oben).

- Leitet der Server auf eine **andere Domain** weiter, lädt die App nicht,
  sondern zeigt die neue Domain im Streifen. Erst ein erneuter Tipp lädt.
- Verlangt die Seite ein **Login** oder ist sie eine normale Webseite, tipp
  auf **Im Browser öffnen**. In der App gibst du nie ein Passwort ein.
- Nur sichere Adressen (https), nur PDF oder XML, höchstens 20 MB.
- Mit **×** schließt du den Streifen.

Datenschutz: Der Server des Rechnungsausstellers erfährt die Adresse aus dem
QR-Code und deine IP-Adresse – sonst nichts aus der App.

### Verkäufe von Amazon, PayPal, Shopify und Stripe übernehmen

Du verkaufst über eine Plattform? Statt jeden Verkauf einzeln zu erfassen,
lädst du den **Standardbericht** herunter und teilst ihn an die App:

1. Bericht herunterladen (Links unten).
2. In der Download-Meldung, in **Dateien** oder im Download-Ordner:
   **Teilen → Buchhaltung** bzw. **Öffnen mit → Buchhaltung**
   (iPhone: **Teilen → In Buchhaltung öffnen**).
3. Die App erkennt das Format selbst und zeigt **je Monat eine Zeile**, z. B.
   „März 2026: 42 Verkäufe 1.230,00 €, Gebühren 210,00 € (Reverse Charge),
   Auszahlung 1.020,00 €“.
4. Unten auf **Übernehmen** tippen. Fertig.

**Wo du die Berichte findest** (Links öffnen direkt die Berichtsseite; vorher
anmelden):

- **Amazon – Transaktionsbericht** (empfohlen):
  [Seller Central → Berichte → Zahlungen → Datumsbereichsberichte](https://sellercentral.amazon.de/payments/reports/custom/request)
  → „Bericht erstellen“ → *Transaktion*, Zeitraum wählen → Herunterladen (CSV).
  Spaltennamen auf Deutsch, Englisch, Französisch, Italienisch oder Spanisch
  sind alle in Ordnung.
- **Amazon – Abrechnung (Flatfile V2)**, alternativ:
  [Seller Central → Berichte → Zahlungen → Alle Abrechnungen](https://sellercentral.amazon.de/payments/allstatements/index.html)
  → bei der Abrechnung „Flatfile V2 herunterladen“. Verwende **nur einen** der
  beiden Amazon-Berichte für denselben Monat; sonst warnt die App vor doppelten
  Umsätzen.
- **Amazon – Gebührenrechnungen** (eigener Beleg, siehe unten):
  [Seller Central → Steuerdokumente → Gebührenrechnungen](https://sellercentral.amazon.de/tax/seller-fee-invoices).
- **PayPal**:
  [Aktivitäten → Berichte → Aktivitätendownload](https://www.paypal.com/reports/dlog)
  → Format *CSV*, Zeitraum wählen → Bericht erstellen → Herunterladen.
- **Shopify**:
  [Finanzen → Auszahlungen](https://admin.shopify.com/payments/payouts)
  → *Transaktionen exportieren*; oder
  [Bestellungen](https://admin.shopify.com/orders) → *Exportieren* (CSV).
- **Stripe**:
  [Saldo → Exportieren](https://dashboard.stripe.com/balance)
  → *Saldo-Transaktionen* (CSV).

**Wie die App bucht** (Bruttoprinzip):

- **Verkäufe** abzüglich Erstattungen → eine Einnahme je Monat
  („Amazon März 2026: 42 Verkäufe“). Als Kleinunternehmer ohne
  Umsatzsteuer; sonst mit der Steuer laut Bericht oder, wenn der Bericht keine
  nennt, zum Normalsatz herausgerechnet.
- **Gebühren** und **Werbung** → je eine Ausgabe je Monat, mit dem Anbieter als
  Geschäftspartner. Amazon (Luxemburg), Stripe und Shopify (Irland) rechnen
  ohne österreichische bzw. deutsche Umsatzsteuer ab: **Reverse Charge** – die
  Steuer schuldest du selbst. **Das gilt auch für Kleinunternehmer**, nur ohne
  Vorsteuerabzug; du brauchst dafür eine UID bzw. USt-IdNr. PayPal-Gebühren
  sind ein steuerfreier Finanzumsatz.
- Die **Auszahlung** auf dein Bankkonto ist nur ein Geldtransfer und wird
  nicht gebucht.
- Schon übernommene Zeilen erkennt die App und **überspringt sie still** – du
  kannst also überlappende Zeiträume teilen.
- Nur Euro-Beträge; Marktplätze in anderer Währung (z. B. amazon.co.uk) zählt
  die App mit, übernimmt sie aber nicht.

**Hinweise, die erscheinen können:**

- **OSS:** Verkaufst du im Jahr für mehr als 10.000 € an Privatpersonen in
  andere EU-Länder, gilt dort deren Umsatzsteuer (One-Stop-Shop). Mit der
  Steuerberatung klären.
- **Versand durch Amazon:** Lagert Amazon deine Ware in anderen Ländern
  (Pan-EU), brauchst du dort meist eine Steuerregistrierung.

**Gebührenrechnung als Beleg:** Amazon stellt die Gebühren monatlich in
Rechnung. Diese PDF bleibt ein eigener Beleg: in der Zusammenfassung auf
**Gebührenrechnungen öffnen** tippen, PDF herunterladen und an die App teilen.

**Datenschutz:** Namen, Adressen, E-Mail-Adressen und Telefonnummern deiner
Käufer übernimmt die App nie. Die Datei wird auf deinem Telefon gelesen und
nirgends hochgeladen.

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
| `1 234,56` | 1.234,56 € |
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
- **Jahr** wählst du mit dem ersten Chip in der Filterzeile; die Chips brechen
  auf schmalen Telefonen in eine zweite Zeile um
- Die Liste ist nach Monaten gruppiert, unter der Filterzeile steht der Saldo
  deiner aktuellen Auswahl

Ein Beleg mit Foto trägt ein Bildsymbol – so siehst du auf einen Blick, wo ein
Nachweis fehlt.

Mit dem Filter **Storniert** siehst du stornierte Belege. Du kannst sie öffnen
und lesen und ihnen Kommentare anhängen, aber nicht mehr ändern.

### Beleg ändern oder stornieren

Beleg antippen, ändern, speichern. Einen falschen Beleg stornierst du ganz
unten im Formular im rot umrandeten Bereich **Beleg stornieren** – weit weg vom
Speichern-Knopf; die App fragt nach. Genauso löschst du einen Kunden unten im
Kundenformular. Der Beleg verschwindet aus
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
Umsätzen quartalsweise abzugeben ist. „Jahr“ ist dein Wirtschaftsjahr; hast du
in den Stammdaten einen anderen ersten Monat als Jänner gewählt, heißen die
Knöpfe „Dieses WJ (2027)“ und „Letztes WJ (2026)“.

**Einnahmen, Ausgaben, Ergebnis** – jeweils netto. Netto, weil die
Umsatzsteuer für dich ein durchlaufender Posten ist und nicht zu deinem Gewinn
gehört. **Als Kleinunternehmer** zählen deine Ausgaben **brutto** („Ausgaben
(brutto)“): du kannst keine Vorsteuer abziehen, also ist die Steuer auf dem
Beleg für dich Aufwand.

**Umsatzsteuer** (nur bei Regelbesteuerung):
- Umsatz je Steuersatz
- Umsatzsteuer, die du eingenommen hast
- Vorsteuer, die du gezahlt hast
- **Reverse Charge** (z. B. Amazon-Gebühren): Steuer und Vorsteuer mit den
  Kennzahlen deiner Voranmeldung – Österreich Kz 057 und Kz 066, Deutschland
  Kz 46 (Bemessungsgrundlage), Kz 47 und Kz 67
- **Zahllast** (du zahlst) oder **Guthaben** (du bekommst)

Als Kleinunternehmer siehst du hier stattdessen einen Hinweis, warum keine
Umsatzsteuer anfällt. Hast du Leistungen mit **Reverse Charge** (z. B.
Amazon-Gebühren), zeigt die Karte die Steuer, die du trotzdem schuldest, und
die Kennzahlen dafür – ohne Vorsteuer.

**Letzte 6 Monate** – zwei Balken je Monat, grün für Einnahmen, rot für Ausgaben.
Auch eine kleine Ausgabe neben einer großen Einnahme bleibt als kurzer Balken
sichtbar.

**Letzte Belege** – die fünf neuesten zum direkten Antippen.

**Nächste Termine** (ganz unten) – die nächsten vier Steuertermine: Voranmeldung (nur bei
Regelbesteuerung), Zusammenfassende Meldung (wenn eingeschaltet),
Einkommensteuer-Vorauszahlungen, Steuererklärung und in Österreich die
SVS-Beiträge (als „ca.“, das genaue Datum steht auf deiner Vorschreibung).
Fällt ein Termin auf ein Wochenende oder einen Feiertag, zeigt die App den
nächsten Werktag. Tippe auf einen Termin, um die Rechtsgrundlage zu sehen. Mit
Steuerberatung steht bei der Steuererklärung „Frist laut Kanzlei“. Die Termine
sind berechnet, zur Orientierung und ohne Gewähr – maßgeblich sind Bescheid,
Finanzamt bzw. deine Steuerberatung.

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

1. Bereich **Rechnungen** → unten in der Mitte **Neue Rechnung**
2. **Empfänger** → *Wählen*. Noch kein Kunde da? Im Auswahlfenster unten auf
   *Neuen Kunden anlegen*.
3. **Zeitraum** prüfen:
   - *Rechnungsdatum* – heute
   - *Liefer-/Leistungsdatum* – **Pflichtangabe.** Wann hast du geliefert oder
     geleistet? Fehlt sie, ist die Rechnung formal mangelhaft, und dein Kunde
     verliert den Vorsteuerabzug.
   - *Fällig am* – aus deinem Zahlungsziel vorbelegt
4. **Positionen** erfassen: Bezeichnung, Menge, Einheit, Einzelpreis **netto**,
   Steuersatz. Weitere Position mit **Position hinzufügen** unter der letzten
   Position; entfernen mit dem Papierkorb neben dem Betrag.
5. Optional **Rabatt, Versand, Skonto** (siehe unten)
6. **Summe** kontrollieren
7. Optional **Anmerkungen** – erscheinen unter den Positionen
8. Unten **Entwurf** speichern oder **Rechnung ausstellen**. Die Leiste bleibt
   auch bei offener Tastatur sichtbar. Nach dem Ausstellen steht dort
   **PDF senden** – ein Tipp, und der Teilen-Dialog öffnet sich.

### Rabatt, Versandkosten und Skonto

Alles davon ist optional und bleibt eingeklappt, bis du es brauchst.

- **Rabatt auf eine Position:** unter der Position *Rabatt hinzufügen*. Wähle
  oben **%** oder **€** und gib den Wert ein. Der Rabatt mindert nur diese
  Position; auf dem PDF steht er unter der Bezeichnung.
- **Rabatt auf die ganze Rechnung:** in der Karte *Rabatt, Versand, Skonto*.
  Hast du Positionen mit verschiedenen Steuersätzen (z. B. 20 % und 10 %),
  verteilt die App den Rabatt anteilig auf die Sätze – so verlangt es das
  Steuerrecht. Beispiel: 100 € zu 20 % und 50 € zu 10 %, 10 % Rabatt → 90 €
  plus 18 € USt und 45 € plus 4,50 € USt, zusammen 157,50 €.
- **Versandkosten:** *Versandkosten hinzufügen*, Betrag netto. Die Umsatzsteuer
  richtet sich automatisch nach den Waren; bei mehreren Steuersätzen teilt die
  App die Versandkosten anteilig auf. Wenn deine Steuerberatung etwas anderes
  sagt, kannst du einen festen Satz wählen.
- **Skonto:** Schalter *Skonto anbieten*, dann Prozent und Tage, z. B. 2 %
  innerhalb 10 Tagen. Auf der Rechnung steht ein festes Datum und der Betrag:
  „Zahlbar bis 28.10.2026 ohne Abzug. Bei Zahlung bis 24.10.2026 2 % Skonto
  (= 3,50 €).“ Einen Vorschlag für neue Rechnungen trägst du in den
  Stammdaten unter *Rechnungen* ein.

### Entwurf oder Ausstellen?

**Entwurf** kannst du beliebig ändern und wieder löschen. Er hat noch **keine**
Rechnungsnummer.

**Ausstellen** vergibt die endgültige, fortlaufende Nummer und **sperrt** die
Rechnung. Danach lässt sich inhaltlich nichts mehr ändern – das ist gesetzlich so
gewollt. Korrekturen laufen über eine **Stornorechnung** – siehe „Rechnung
korrigieren oder stornieren“.

**Beenden** unten links speichert deine Änderungen als Entwurf und bringt dich
zur Liste zurück. Dasselbe passiert, wenn du mit dem Pfeil oder der
Zurück-Geste gehst – nichts geht verloren. Fehlt noch etwas, das ein Entwurf
braucht (zum Beispiel der Kunde), fragt die App einmal nach: **Weiter
bearbeiten** oder **Verwerfen**.

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

Direkt nach dem Ausstellen mit **PDF senden** unten im Formular. Nach dem
Senden bleibt die Rechnung offen; mit **Beenden** daneben geht es zurück zur
Liste. Oder später in
der Rechnungsliste auf der Karte mit **PDF senden**. Eine neue Rechnung beginnst
du unten in der Mitte mit **Neue Rechnung**. Rechnung und Mahnung sprechen
deine Kunden mit **Sie** an; € und Gedankenstrich erscheinen im PDF richtig.
Liegt das Leistungsdatum nach dem Rechnungsdatum, fragt das Formular dezent
nach („stimmt das?“) – speichern kannst du trotzdem. Die App erzeugt das PDF und öffnet den
Teilen-Dialog deines Telefons: E-Mail, Messenger, Cloud-Ordner – du entscheidest.

### Status pflegen

Offene Rechnungen haben auf der Karte den Knopf **Bezahlt**. **Korrigieren**,
**Stornieren** (rot) und **Entwurf löschen** (rot) stehen im Dreipunkt-Menü
unten auf der Karte.

| Status | Bedeutung |
|---|---|
| **Entwurf** | Noch nicht gestellt, änderbar, löschbar |
| **Offen** | Gestellt, Zahlung ausstehend |
| **Überfällig** | Gestellt, Fälligkeit (bzw. nach einer Mahnung deren neue Frist) verstrichen – wird rot |
| **Bezahlt** | Erledigt – die App bucht den Betrag als Einnahme |
| **Storniert** | Durch eine Stornorechnung aufgehoben, bleibt aber unverändert erhalten; auf der Karte steht „storniert durch …“ |
| **Storno** | Die Stornorechnung selbst: eigene Nummer, Betrag mit Minus, „Storno zu …“ |

Oben in der Liste steht die Summe aller gestellten, noch nicht bezahlten
Rechnungen.

**Bezahlt:** Die App fragt nach dem Tag des Zahlungseingangs
(vorbelegt mit heute, antippen zum Ändern) und bucht die Rechnung an diesem Tag
als Einnahme – in Übersicht, Kleinunternehmergrenze und Export. Eine offene
Rechnung zählt noch nicht als Einnahme, denn in der Einnahmen-Ausgaben-Rechnung
zählt der Tag, an dem das Geld eingeht. **Erfasse die Zahlung nicht zusätzlich
als Einnahmebeleg**, sonst zählt sie doppelt. Rechnungen, die du vor dieser
Version als bezahlt markiert hast, bucht die App beim Start einmal nach.

**Mit Skonto bezahlt?** Hat die Rechnung Skonto, fragt die App das gleich mit –
vorbelegt mit *Ja*, solange die Skontofrist läuft. Bei *Ja* bucht sie den um das
Skonto geminderten Betrag als Einnahme, je Steuersatz anteilig; damit sinkt auch
deine Umsatzsteuer im Monat der Zahlung automatisch. Die Rechnung selbst bleibt
unverändert. Als Kleinunternehmer sinkt nur die Einnahme.

### Rechnung korrigieren oder stornieren

Eine gestellte Rechnung darfst du nicht ändern. Stattdessen erstellt die App
eine **Stornorechnung**: ein eigenes Dokument mit der nächsten Rechnungsnummer,
das die alte Rechnung mit Minusbeträgen aufhebt. Die alte Rechnung bleibt
unverändert und ist danach als storniert markiert.

**Korrigieren** – wenn sich etwas an der Rechnung ändern soll (Betrag,
Adresse, Position):

1. Auf der Rechnungskarte **⋮ → Korrigieren** tippen.
2. Grund antippen (vorgeschlagen: „Fehler in der Rechnung“) oder selbst
   schreiben.
3. **Stornieren und neu schreiben** tippen.
4. Die App öffnet sofort eine Kopie als neuen Entwurf. Korrigieren und
   **Rechnung ausstellen**.
5. Beide PDFs an den Kunden senden: unten erscheint dafür **PDF senden** für
   die Stornorechnung, die neue Rechnung sendest du wie gewohnt.

**Stornieren** – wenn die Rechnung ganz wegfällt: **⋮ → Stornieren**, Grund
wählen, **Stornorechnung erstellen**, dann **PDF senden**.

**War die Rechnung schon bezahlt?** Dann fragt die App nach dem Tag der
Rückzahlung (vorbelegt heute) und bucht an diesem Tag den damals eingenommenen
Betrag als Minus-Einnahme – deine Einnahmen und deine Umsatzsteuer sinken in
diesem Monat. Überweise den Betrag an deinen Kunden zurück. War die Rechnung
noch offen, bucht die App nichts, denn es ist ja kein Geld geflossen.
Laufende Mahnungen zur Rechnung storniert die App mit.

Die Stornorechnung nennt Nummer und Datum der ursprünglichen Rechnung, den
Grund und dieselben Steuersätze wie das Original. Sie heißt bewusst nicht
„Gutschrift“ – das wäre steuerlich etwas anderes.

### Erinnern und mahnen

Ist eine Rechnung überfällig, steht oben in der Liste „… überfällig –
mahnen?“, und auf der Karte erscheint **Erinnern** (beim ersten Mal) bzw.
**Mahnen**. Ein Tipp öffnet die Vorschau:

- **Stufe:** zuerst eine freundliche *Zahlungserinnerung*, danach *1. Mahnung*,
  *2. Mahnung* und so weiter – so oft du willst.
- **Neue Zahlungsfrist:** vorgeschlagen in 14 Tagen, antippen zum Ändern.
- **Mahnkosten:** Die Zahlungserinnerung ist kostenlos, ab der 1. Mahnung
  schlägt die App 10,00 € vor. Bei **Privatkunden** siehst du den Hinweis:
  „Bei Privatkunden sind nur angemessene, tatsächlich entstandene Mahnkosten
  zulässig – 10 € können zu hoch sein.“ Den Betrag bestimmst du.
- **Verzugszinsen** (optional): Die App schlägt den gesetzlichen Satz vor –
  Österreich 4 % bei Privatkunden, bei Unternehmen Basiszinssatz plus 9,2
  Prozentpunkte; Deutschland Basiszinssatz plus 5 bzw. 9 Prozentpunkte – und
  rechnet taggenau ab dem Tag nach der Fälligkeit. Den Satz kannst du ändern.
- **Pauschale 40 €:** nur bei Unternehmen, auf Wunsch.

Mit **… erstellen und senden** entsteht das PDF und der Teilen-Dialog öffnet
sich. Das Schreiben ist danach unveränderlich; war es ein Versehen, stornierst
du es in derselben Vorschau mit einer kurzen Begründung. Mahnkosten, Zinsen
und Pauschale stehen auf dem Schreiben als „nicht umsatzsteuerbar“.

**Unternehmen oder Privatkunde?** Im Kunden gibt es den Schalter
**Unternehmen**. Er schaltet sich automatisch ein, wenn du eine UID einträgst.
Davon hängen Zinssatz, Pauschale und der Hinweis zu den Mahnkosten ab. In
Deutschland steht auf Rechnungen an Privatkunden außerdem automatisch der
Hinweis, dass sie nach 30 Tagen auch ohne Mahnung in Verzug kommen
(§ 286 Abs. 3 BGB).

**Bezahlt nach einer Mahnung:** Die App fragt „Mahnkosten und Zinsen
mitbezahlt?“. Bei *Ja* bucht sie diese getrennt als Einnahme ohne
Umsatzsteuer. Teilzahlungen kann die App noch nicht abbilden.

**Nach dem Erinnern oder Mahnen:** Die Rechnung trägt in der Liste ein Symbol,
z. B. **Erinnert · Frist 28.10.2026** oder **1. Mahnung · Frist …**. Antippen
zeigt den ganzen Mahnverlauf. „Überfällig“ und der Knopf **Mahnen** erscheinen
erst wieder, wenn diese neue Frist abgelaufen ist.

Standardwerte (Mahnkosten, Frist, Zinsen, Pauschale) stellst du in den
Stammdaten unter *Rechnungen → Mahnungen* ein.

### Was auf dem PDF steht

Die App setzt alle Pflichtangaben nach § 11 UStG (Österreich) bzw. § 14 UStG
(Deutschland): beide Anschriften, deine Steuernummer bzw. UID, Rechnungsdatum,
fortlaufende Nummer, Positionen mit Menge und Bezeichnung, Leistungsdatum,
Entgelt je Steuersatz und den Steuerbetrag.

Als Kleinunternehmer fehlt die Steuerspalte vollständig, dafür erscheint der
gesetzliche Befreiungshinweis.

Rabatte und Versandkosten stehen unter den Positionen, bei mehreren
Steuersätzen je Satz getrennt; darunter das Entgelt und die Steuer je Satz.

**Deine AGB:** Trägst du in den Stammdaten unter *Rechnungen* die Adresse
deiner Verkaufsbedingungen ein, steht auf neuen Rechnungen: „Es gelten unsere
Verkaufsbedingungen, abrufbar unter …, soweit sie vereinbart wurden.“ Wichtig:
Der Verweis auf der Rechnung allein macht deine AGB nicht wirksam – binde sie
schon im Angebot bzw. bei der Bestellung ein. Bereits ausgestellte Rechnungen
behalten den Stand vom Ausstellen.

**Firmenlogo:** In den Stammdaten unter **Rechnungen → Logo wählen** suchst du
ein Bild aus deiner Fotobibliothek aus (am besten PNG oder JPEG). Die App
verkleinert es und setzt es oben rechts auf das PDF – zusätzlich zu Name und
Anschrift, nie stattdessen. **Entfernen** nimmt es von künftigen Rechnungen.
Bereits ausgestellte Rechnungen behalten das Logo, das beim Ausstellen galt;
Entwürfe zeigen immer das aktuelle.

Das Logo kannst du schon bei der Einrichtung wählen, ohne Abo. **Gedruckt wird
es mit Pro und im 14-Tage-Test.** Mit Basis steht in den Stammdaten
„Logo (Pro) – wird mit Basis nicht gedruckt“: Neue Rechnungen und Angebote
kommen dann ohne Logo, das Bild bleibt aber gespeichert und ist mit Pro sofort
wieder da.

### Angebote

Unter **Rechnungen → Angebote** schreibst du ein Angebot fast wie eine
Rechnung:

1. **Neues Angebot** tippen.
2. Kunde wählen, Positionen eintragen oder mit **Aus Artikeln und
   Vorschlägen** übernehmen. „Gültig bis“ ist 30 Tage vorbelegt.
3. **PDF senden** – das Angebot gilt danach als *Gesendet*. Ohne Pro kannst
   du das PDF speichern oder drucken und selbst weitergeben.
4. Sagt die Kundin zu: **Zur Rechnung machen**. Es öffnet sich ein
   Rechnungsentwurf mit allen Positionen; prüfen und ausstellen.

Ein Angebot bucht nichts: Es erscheint nicht im Kassabuch, nicht in der
Umsatzsteuer und nicht bei der Kleinunternehmergrenze. Es hat eine eigene
Nummer (AN-2026-0001 …), unabhängig von deinen Rechnungsnummern. Lehnt die
Kundin ab, tippe **Kundin hat abgelehnt**. Nach „Gültig bis“ steht es als
*Abgelaufen* in der Liste. Ein angenommenes Angebot lässt sich nicht mehr
ändern; **Rechnung öffnen** bringt dich zum Entwurf.

### Artikel

Unter **Rechnungen → Artikel** legst du Waren und Leistungen an, die du öfter
verrechnest: Bezeichnung, Preis netto, Einheit, Steuersatz, auf Wunsch
Artikelnummer und kurze Beschreibung. In Rechnung und Angebot holst du sie mit
**Aus Artikeln und Vorschlägen** – ein Tipp, fertig. Dort stehen auch
Positionen, die du früher schon verwendet hast, ganz ohne Artikel anzulegen.
Alles bleibt in der Position änderbar, und freie Positionen gehen immer.
Löschst du einen Artikel, bleiben deine Rechnungen unverändert.

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

1. **Jahr** wählen (bei abweichendem Wirtschaftsjahr „WJ 2027“ usw.)
2. Optional **eingrenzen** auf Quartal oder Monat – Quartale und Monate sind
   immer Kalenderzeiträume, wie bei der Umsatzsteuer
3. **Vorschau** prüfen: Anzahl der Belege und Summen. Wenn hier 0 Belege stehen,
   wäre die Datei leer – der Export ist dann gesperrt.
4. **Format** antippen → Teilen-Dialog

### Die Formate

| Format | Wann |
|---|---|
| **Belegliste (CSV)** | Spalte „Originaldatei“: Name und Prüfsumme einer übernommenen PDF- oder E-Rechnung. Der sichere Standard. Öffnet in Excel, Numbers und jedem Buchhaltungsprogramm. Nimm den, wenn du nicht weißt, womit deine Kanzlei arbeitet. Bei Bewirtung mit Spalten „Nicht abziehbar“, „Anlass“ und „Teilnehmer“. Enthält auch die Seitenzahl, alle Kommentare mit Zeitpunkt und bei Fremdwährung Währung, Originalbetrag, Kurs, Kursquelle, Kursdatum und Bankbetrag. |
| *Hinweis Fremdwährung* | DATEV und BMD erhalten nur den Euro-Betrag; Originalbetrag und Kurs findet deine Kanzlei in der Belegliste. |
| **DATEV-Buchungsstapel** | Nur bei Land Deutschland. Für DATEV-Kanzleien. Der jüngste Kommentar steht gekürzt im Buchungstext (wie auch bei BMD). |
| **BMD-Buchungssätze** | Nur bei Land Österreich. Für BMD NTCS. |
| **Umsatzsteuer-Zusammenfassung** | Die Zahlen für die Umsatzsteuervoranmeldung: Bemessungsgrundlagen je Satz, Vorsteuer, Zahllast. |

### Für das Finanzamt

Ganz oben im Bereich **Export** liegt die Karte **Für das Finanzamt**. Dort
stehen die Zahlen so, wie das Formular sie verlangt – mit Kennzahl (Kz).

1. **Jahr** und **Quartal** oder **Monat** wählen. Vorgewählt ist das zuletzt
   abgeschlossene Quartal.
2. Eine Zeile **antippen** – der Betrag ist kopiert, ohne Tausenderpunkt und
   mit Komma. Im Formular einfügen.
3. **Österreich:** Unten **U30-Datei teilen** (Pro) erzeugt die
   Umsatzsteuervoranmeldung als Datei. In FinanzOnline unter
   **Eingaben → Übermittlungen → Upload** hochladen und das Protokoll prüfen.
   Dafür muss im Firmenprofil die Steuernummer mit Finanzamtsnummer stehen
   (9 Ziffern, z. B. `12 345/6789`).
4. **Deutschland:** In **Mein ELSTER** die Umsatzsteuer-Voranmeldung öffnen
   und die Kennzahlen einfügen. Kz 81 und 86 sind in **vollen Euro** – die
   App lässt die Cent schon weg. ELSTER rechnet die Steuer selbst; ein paar
   Cent Abweichung sind normal.

**Kleinunternehmer** brauchen keine Voranmeldung – die App sagt das und zeigt
nur die Jahreszahlen. Ausnahme: Reverse Charge (z. B. Amazon-Gebühren); dann
gibt es eine Voranmeldung mit der Steuer daraus.

Unten stehen die **Jahreszahlen** für die Einkommensteuer: in Österreich
Beilage **E1a** (Kz 9040), in Deutschland **Anlage EÜR** (Kz 111 bzw. 112,
140, 185). Die Ausgaben verteilst du im Formular nach Art auf die Zeilen.

Die App schickt nichts selbst ans Finanzamt. Die Meldung gibst du ab – im
Zweifel frag deine Steuerberatung.

### Anlagen und Jahresabschluss

Was du länger als ein Jahr nutzt und mehr kostet als die GWG-Grenze (Österreich
1.000 €, Deutschland 800 € netto), schreibst du über mehrere Jahre ab.

Anlagen anlegen, ändern und ausscheiden gibt es mit **Pro**. Ohne Pro zählt die
Ausgabe voll als Ausgabe; liegt sie über der Grenze, steht am Beleg
**Als Investition erfassen (Pro)** mit dem Hinweis, dass du sie aktivieren und
ins Anlagenverzeichnis aufnehmen musst – frag dann deine Steuerberatung.
Anlagen, die du schon hast, bleiben in jedem Abo sichtbar, ihr
Anlagenverzeichnis kannst du immer exportieren, und ihre Abschreibung läuft
weiter.

1. Die Ausgabe wie immer fotografieren und speichern.
2. Beleg öffnen → **Als Investition erfassen** (Pro).
3. **Art** wählen – die App schlägt die Nutzungsdauer vor (z. B. Computer in
   Österreich 3 Jahre, in Deutschland 1 Jahr; PKW in Österreich mindestens
   8 Jahre). Unter der Grenze ist **Geringwertig – sofort abschreiben**
   vorgewählt.
4. **Speichern**. Den AfA-Plan siehst du gleich darunter.

Eine andere Nutzungsdauer geht – dann schreib kurz dazu, warum. Kleinunternehmer
tragen den Betrag **brutto** ein, alle anderen netto. Die Vorsteuer aus dem Beleg
bleibt wie gewohnt in der UVA.

Die Anschaffung zählt **nicht** als Ausgabe im Ergebnis; stattdessen zählt die
Abschreibung (AfA) jedes Jahr am 31.12. In der Übersicht steht dann „davon
Investitionen“ und „Abschreibung (AfA)“.

**Kaputt, verloren, verkauft?** Anlage öffnen → **Ausscheiden**, Grund und
Datum wählen, kurz kommentieren. Der Restwert wird an diesem Tag abgeschrieben.
Bei **Verkauft** trägst du den Erlös ein; die App bucht ihn als Einnahme.

**Berichte:** Export → **Anlagen und Jahresabschluss**. Jahr wählen, optional
einen Kommentar an deine Steuerberatung schreiben, dann:

- **Anlagenverzeichnis** – Pflicht, in jedem Abo für alle erfassten Anlagen
- **Saldenliste** (Pro) – Summen je Kategorie
- **Vorläufiger Jahresabschluss** (Pro) – ein ZIP mit PDF, Belegliste und
  Buchungsexport zum Weiterschicken. Alles ist als **VORLÄUFIG** markiert;
  fertig macht ihn deine Kanzlei.

**Leasing** ist keine Anlage: Raten buchst du einfach als Ausgabe.

### Verträge

Miete, Pacht, Leasing, Versicherung, Darlehen, Dienstbarkeit: Export →
**Verträge** → **Vertrag ablegen**.

1. **Seiten scannen** (Dokumentenscanner, mehrere Seiten auf einmal) oder **Aus Galerie**. Ein PDF aus einer
   Mail teilst du einfach an JeNi bucht – oben im Belegformular steht dann
   „Ist das ein Vertrag?“; ein Tipp legt ihn ins Vertragsarchiv.
2. Art, Bezeichnung, Partner, Beginn, Ende, Kündigungsfrist, Rate eintragen.
3. **Speichern.**

Mit Pro liest **Text erkennen und Kurzübersicht** den Vertrag auf deinem
Telefon und zeigt gefundene Daten, Beträge und Fristen mit **Seite und Zeile**.
Ein Tipp übernimmt den Wert. Das ist nur ein Auszug aus deinem Vertrag, keine
rechtliche Prüfung – im Zweifel gilt der Vertragstext.

Die Übersicht erinnert in der Termin-Box an **Kündigen bis**, **Vertragsende**
und **Indexanpassung**. Im Vertrag siehst du je Rate „gebucht ✓“, eine
Abweichung oder „kein Beleg“; **Rate buchen (Vorschlag)** legt die Ausgabe
nach deiner Bestätigung an.

Verträge musst du aufbewahren: die App zeigt, bis wann, und warnt vor dem
Löschen. **Leasing** buchst du als Ausgabe – keine Anlage.

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

**Stammdaten** – dein Firmenprofil ändern. Unten im Abschnitt
**Wirtschaftsjahr und Termine**:

- **Erster Monat Wirtschaftsjahr** – normalerweise Jänner. Einen anderen Monat
  darfst du nur wählen, wenn dein Unternehmen im Firmenbuch (AT) bzw.
  Handelsregister (DE) eingetragen ist und das Finanzamt zugestimmt hat; die
  App fragt einmal nach. Umsatzsteuer und Kleinunternehmergrenze bleiben
  trotzdem beim Kalenderjahr.
- **Bundesland** (nur Deutschland) – für Landesfeiertage bei Fristen
- **UVA- bzw. UStVA-Rhythmus** (nur Regelbesteuerung) – die App schlägt ihn aus
  dem Vorjahr vor; ändere ihn, wenn dein Finanzamt etwas anderes festgelegt hat
- **Dauerfristverlängerung** (nur Deutschland), **Zusammenfassende Meldung**,
  **Steuerberatung**, **SVS-Beiträge** (nur Österreich)

**Fremdwährung** – Schalter „Tageskurs vom Finanzamt genehmigt“. Standardmäßig
aus; dann rechnet die App mit dem Monatskurs. Nur einschalten, wenn dir das
Finanzamt den Tageskurs genehmigt hat.

**Kategorien** – Kategorien ansehen, eigene anlegen und löschen. Die
vorgegebenen 17 Kategorien tragen ein Schlosssymbol und bleiben erhalten. Beim
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

**Rechtliches** – Impressum, Datenschutzerklärung und Nutzungsbedingungen zum
Nachlesen, auch ohne Internet; dazu der Hinweis „Keine Steuerberatung“, die
Support-Adresse (öffnet deine Mail-App) und die Open-Source-Lizenzen. In
dieser Testversion stehen die Rechtstexte noch als **Entwurf** gekennzeichnet.

**Wichtiger Hinweis** – die rechtliche Abgrenzung. Bitte einmal lesen.

### Abo: Basis und Pro

Die App gibt es im Abo, abgeschlossen über **Google Play** bzw. den **App
Store**. Ein Konto bei uns brauchst du nicht; das Abo hängt an deinem
Store-Konto. Du findest alles unter **Einstellungen → Abo**.

- **Basis** – alles, was eine ordentliche Buchhaltung braucht: Belege,
  Rechnungen, Kassabuch, Kunden, Übersicht, Kleinunternehmer-Ampel, Export,
  Sicherung.
- **Pro** – zusätzlich:
  - **Belegerkennung**: Betrag, Datum und Händler kommen aus dem Foto. Ohne
    Pro tippst du sie selbst ein; beim Beleg steht **Automatisch auslesen (Pro)**.
  - **Import** aus Amazon, PayPal, Shopify, Stripe und das Auslesen von
    E-Rechnungen (ZUGFeRD, XRechnung, ebInterface). Ohne Pro bleibt die
    E-Rechnung als Datei am Beleg.
  - **PDF senden** mit einem Tipp: Rechnung, Stornorechnung,
    Zahlungserinnerung und Mahnung mit Betreff und Text.
  - **Logo** auf Rechnungen und Angeboten (wählen geht in jedem Abo).
  - **Kurs abrufen** bei Fremdwährung (eintippen geht immer).
  - Später: direkte Übermittlung ans Finanzamt (UVA).
- Knöpfe mit **(Pro)** öffnen ohne Pro die Abo-Seite. Bei **PDF senden**
  kommt danach trotzdem das Teilen-Blatt: Dort kannst du das PDF
  **speichern oder drucken** und selbst an die Kundin schicken. So erreicht
  jede Rechnung und Stornorechnung auch mit Basis ihre Empfängerin.
- **14 Tage kostenlos testen:** Beim ersten Abo kannst du Pro 14 Tage gratis
  nutzen. Der Test startet im Store und **geht danach in das Abo über**, wenn
  du nicht vorher kündigst. Drei Tage vor dem Ende erinnert dich die Übersicht.
- **Promo-Code einlösen** (z. B. aus Instagram): Einstellungen → Abo →
  **Promo-Code einlösen**.
  1. iPhone: Apple öffnet ein Fenster; Code eintippen, bestätigen.
  2. Android: Code eintippen, **Einlösen**; Google Play öffnet sich, dort
     bestätigen.
  3. Zurück in der App ist Pro aktiv. Mit **JENIBUCHT2M** nutzt du Pro zwei
     Monate gratis; danach läuft das Abo zum angezeigten Preis weiter, wenn du
     nicht vorher kündigst. Die Übersicht erinnert dich drei Tage vorher.
- **Preise** zeigt die Abo-Seite so, wie der Store sie meldet, inklusive
  Umsatzsteuer, monatlich oder jährlich.
- **Kündigen:** Tippe auf **Abo verwalten oder kündigen** – das öffnet die
  Abo-Einstellungen von Google Play bzw. Apple. Kündige spätestens 24 Stunden
  vor Ablauf.
- **Neues Telefon oder neu installiert?** Tippe auf **Kauf wiederherstellen**.
  Melde dich dafür im Store mit demselben Konto an wie beim Kauf.
- **Ohne Internet** gilt dein Abo weiter, bis zu 45 Tage ab der letzten
  Bestätigung durch den Store. Nach etwa einem Monat bittet dich die
  Übersicht, die App einmal mit Internet zu öffnen.

**Endet dein Abo, verlierst du nichts.** Endet Pro, arbeitest du mit Basis
weiter, falls du Basis hast. Endet jedes Abo, wechselt die App in **Nur
lesen**: Du kannst alles ansehen, Belege und Entwürfe ändern, drucken,
exportieren, sichern und wiederherstellen – nur neue Belege und Rechnungen
brauchen wieder ein Abo. Das ist wichtig, weil du deine Unterlagen sieben
(AT) bzw. acht (DE) Jahre aufbewahren musst.

In dieser Testversion ist die Abo-Prüfung ausgeschaltet; alle Funktionen sind
frei, die Abo-Seite zeigt „Testversion“.

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
in Google Drive, auf dem iPhone direkt in dein iCloud Drive. Das ist
**standardmäßig aus**.

1. **Einstellungen → Datensicherung → Automatische Sicherung → Einrichten**
2. Die Erklärung lesen und **Ordner wählen**. Auf dem iPhone mit iCloud heißt
   der Knopf **In iCloud sichern**: die App legt die Sicherung ohne Ordnerwahl
   in iCloud Drive im Ordner **„JeNi bucht“** ab (in der Dateien-App
   sichtbar). Ohne iCloud wählst du einen Ordner; mit **Ordner ändern** auch
   später.
3. Tippe auf **Druckblatt teilen**. Die App erstellt ein PDF mit deinem
   **Wiederherstellungscode** (13 Blöcke zu 4 Zeichen) und einem QR-Code.
   Drucke es aus oder speichere es in deinem Passwortmanager – **getrennt von
   deinem Handy**. Die App zeigt den Code sonst nirgends an und behält keine
   Kopie. Ohne ihn kann niemand eine automatische Sicherung auf einem anderen
   Gerät öffnen, auch du nicht.
4. Zur Kontrolle fragt die App nach zwei Blöcken vom Druckblatt, zum Beispiel
   „Block 3“ und „Block 9“. Tippe sie ab (groß oder klein ist egal) und dann
   **Code ist aufbewahrt**.

Danach sichert die App nach jeder Änderung höchstens einmal am Tag, wenn du sie
öffnest. Jede Sicherung wird nach dem Speichern zur Probe wieder geöffnet; erst
dann gilt sie als gelungen. Klappt etwas nicht – Ordner nicht erreichbar,
Zugriff entzogen –, siehst du es auf der Übersicht.

Im Ordner bleiben die letzten 7 Sicherungen, je Monat eine für ein Jahr und
**je Jahr eine dauerhaft** – damit du über die Aufbewahrungsfrist hinweg
zurückgreifen kannst. Andere Dateien im Ordner fasst die App nicht an.

**Sicherung prüfen** öffnet die jüngste Sicherung zur Probe, ohne etwas zu
ändern. Mach das ab und zu, mindestens einmal im Jahr.

**Wiederherstellen** zeigt alle automatischen Sicherungen im Ordner, die
neueste oben. Tipp auf eine: auf demselben Gerät braucht es keinen Code, auf
einem neuen Gerät den Wiederherstellungscode. Danach siehst du die Vorschau
und bestätigst.

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

**Was passiert mit meinen Daten, wenn ich das Abo kündige?**
Nichts geht verloren. Die App wechselt in *Nur lesen*: ansehen, exportieren,
sichern und wiederherstellen gehen weiter, nur neue Buchungen nicht.

**Bekomme ich für das Abo eine Rechnung?**
Ja, vom Store: Verkäufer sind Google bzw. Apple. Die Quittung findest du in
deinem Store-Konto.

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
Eine gestellte Rechnung darf nicht geändert werden. Tippe auf der Karte
auf **⋮ → Korrigieren**: die App erstellt die Stornorechnung und öffnet gleich
eine Kopie zum Ausbessern (Kapitel 7, „Rechnung korrigieren oder
stornieren“).

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

**„Store nicht erreichbar. Dein Abo gilt weiter.“** — die App konnte Google
Play bzw. den App Store nicht fragen, meist ohne Internet. Dein Abo gilt
trotzdem weiter. Später mit Internet noch einmal **Kauf wiederherstellen**
tippen.

**„Kein aktives Abo in diesem Store-Konto gefunden.“** — im Store ist ein
anderes Konto angemeldet als beim Kauf, oder das Abo ist abgelaufen. Im Store
das richtige Konto wählen und erneut **Kauf wiederherstellen** tippen. Deine
Daten bleiben in jedem Fall lesbar und exportierbar.

**„Neue Buchungen brauchen ein Abo.“** — die App ist im Modus *Nur lesen*. Die
Abo-Seite öffnet sich, deine Eingaben bleiben im Formular stehen. Nach dem
Abschluss tippst du auf Zurück und speicherst wie gewohnt.

**„Bitte kurz begründen, warum die Dauer abweicht“** — du hast eine andere
Nutzungsdauer als vorgeschlagen eingetragen. Ein Satz genügt, z. B. „wird im
Schichtbetrieb genutzt“; er steht im Anlagenverzeichnis.

**„Sofort abschreiben geht nur bis …“** — der Betrag liegt über der GWG-Grenze.
Wähle **Linear über die Nutzungsdauer** (in Deutschland bis 1.000 € netto auch
**Sammelposten**).

**„Aufbewahrungspflicht bis …“ beim Löschen eines Vertrags** — der Vertrag
muss noch aufbewahrt werden. Tippe **Behalten**, außer du hast ihn sicher
anderswo archiviert.

**„Ausscheiden buchen“ ist grau** — der Kommentar fehlt. Schreib kurz, was
passiert ist.

**„U30-Datei teilen“ ist grau** — darüber steht der Grund: Die Steuernummer
im Firmenprofil hat keine 9 Ziffern mit Finanzamtsnummer, oder es gibt Umsätze
ohne eindeutige Kennzahl (z. B. 0 % als Regelbesteuerte, Ausfuhr,
EU-Lieferung) bzw. negative Beträge. Steuernummer ergänzen; sonst die Zahlen
antippen, kopieren und in FinanzOnline selbst eintragen – im Zweifel mit deiner
Kanzlei.

**„Stornieren und neu schreiben“ bzw. „Stornorechnung erstellen“ ist grau** —
das Feld *Grund* ist leer. Tippe einen der Vorschläge an oder schreib einen
kurzen Grund; er steht auf der Stornorechnung.

**„Beide Blöcke müssen stimmen.“** — beim Einrichten der automatischen
Sicherung passt ein abgetippter Block nicht zum Druckblatt. Achte auf die
Blocknummer; 0 und O, 1 und I, 8 und B darfst du verwechseln. Hast du das
Druckblatt nicht mehr, tippe auf **Druckblatt noch einmal teilen**.

**„Bitte eine E-Mail-Adresse wie name@beispiel.at eingeben"** — im Profil oder
beim Kunden steht eine E-Mail-Adresse ohne @ oder ohne Domain (z. B. `.at`).
Tippfehler korrigieren oder das Feld leer lassen. Die App prüft nur die Form,
sie schickt keine Bestätigungsmail; du kannst die Adresse jederzeit ändern.

**„Bitte eine Telefonnummer mit 6 bis 20 Ziffern eingeben, z. B. +43 660
1234567"** — erlaubt sind Ziffern, ein `+` am Anfang, Leerzeichen sowie `/`,
`(`, `)` und `-`. Buchstaben oder zu kurze Nummern werden abgelehnt. Auch hier
gibt es keine SMS-Bestätigung.

**„Format nicht erkannt. Unterstützt: Amazon, PayPal, Shopify, Stripe …"** —
die geteilte CSV- oder Textdatei ist kein bekannter Plattformbericht. Prüf,
ob du den richtigen Bericht heruntergeladen hast (Kapitel 4, „Verkäufe von
Amazon, PayPal, Shopify und Stripe übernehmen“), und teile die Datei
unverändert, ohne sie vorher in einer Tabellenkalkulation zu speichern.


**„Auf dem Foto wurde nichts erkannt – bitte von Hand erfassen."** — das Foto
ist unscharf, zu dunkel oder schräg. Neu fotografieren und „Erneut auslesen",
oder die Felder selbst ausfüllen.

**„Der Beleg konnte nicht ausgelesen werden …"** — die Erkennung ist auf
diesem Gerät fehlgeschlagen. Der Beleg lässt sich trotzdem von Hand erfassen.

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
- **E-Rechnungen nur empfangen.** Eingehende E-Rechnungen (XRechnung,
  ZUGFeRD, ebInterface) übernimmt die App. Deine eigenen Rechnungen sind ein
  PDF, keine strukturierte E-Rechnung. Für Geschäftskunden in Deutschland wird
  das mittelfristig wichtig.
- **Storno nur für die ganze Rechnung.** Einzelne Positionen oder einen
  Teilbetrag zurücknehmen geht noch nicht; nimm dafür **Korrigieren**.
- **Die Belegerkennung merkt sich keine Beschreibungen und keine
  Aufteilung nach Steuersätzen.** Gelernt werden je Lieferant nur Name,
  Kategorie, Steuersatz, Währung und Zahlungsart.
- **Bewirtung nur mit dem Regelsatz.** Die App kürzt jede Ausgabe der
  Kategorie Bewirtung um den gesetzlichen Regelsatz (AT 50 %, DE 70 %).
  Bewirtung ohne Werbezweck (in Österreich gar nicht abziehbar) oder
  unangemessen hohe Beträge erkennt sie nicht – das klärt deine Kanzlei.
- **Keine Lohnverrechnung, keine Bilanz, keine doppelte Buchführung.** Der
  vorläufige Jahresabschluss ist eine Einnahmen-Ausgaben-Rechnung zur Übergabe
  an deine Kanzlei. Gebäude, degressive AfA, Investitionsfreibetrag und
  Investitionsabzugsbetrag kann die App nicht.
- **Keine automatische Übermittlung** an FinanzOnline oder ELSTER. Die App
  liefert die Kennzahlen zum Kopieren und in Österreich die U30-Datei zum
  Hochladen; abgeben machst du oder deine Kanzlei. Eine Zusammenfassende
  Meldung erstellt die App nicht.
- **Keine Erinnerung an Termine.** Die Termin-Box zeigt sie nur an;
  Benachrichtigungen sind geplant. Teilzahlungen auf Rechnungen kann die App
  noch nicht buchen – auch nicht nach einer Mahnung.
- **Keine Synchronisierung** zwischen Geräten
- **Plattformberichte nur über Teilen.** Eine Dateiauswahl in der App gibt
  es noch nicht, und eine direkte Verbindung zu Amazon & Co. ist nicht
  geplant, solange die App ohne Server auskommt. Fremdwährungen aus
  Plattformberichten übernimmt die App nicht.

### Und der wichtigste Satz

Diese App unterstützt dich bei der Buchhaltung. Sie ist **keine
Steuerberatung**. Für die Richtigkeit deiner Buchhaltung und deiner
Steuererklärungen bist du selbst verantwortlich. Bei Zweifeln frag deine
Steuerberatung – das kostet weniger als eine Korrektur nach einer Prüfung.
