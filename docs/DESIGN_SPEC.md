# Designspezifikation

**Version 1.6 · Stand 2026-10-19 · Produktname „JeNi bucht“**

Zweck: Grundlage, gegen die eine KI (oder ein Mensch) **mehrere unterschiedliche
Designvarianten** entwickeln kann, die alle fachlich und rechtlich korrekt
bleiben. Jede Regel ist entweder

- **FEST** – nicht verhandelbar, gilt für jede Variante, oder
- **FREI** – Gestaltungsspielraum, je Variante unterschiedlich.

Dieses Dokument legt kein Verhalten fest. Verhalten steht in
[`SPECIFICATION.md`](SPECIFICATION.md), Anforderungen in
[`LASTENHEFT.md`](LASTENHEFT.md). Bei Widerspruch gelten diese beiden. Name und
Marke sind offen (Lastenheft O-25, Spezifikation 14 P-R7): **kein finales Logo,
kein finaler Name in einer Variante**, nur Platzhalter.

---

## Inhalt

1. [Markenkern und Tonalität](#1-markenkern-und-tonalität)
2. [Design-Tokens](#2-design-tokens)
3. [Fachlich gebundene Farben und Zeichen](#3-fachlich-gebundene-farben-und-zeichen)
4. [Typografie](#4-typografie)
5. [Layout und Raster](#5-layout-und-raster)
6. [Komponentenkatalog](#6-komponentenkatalog)
7. [Schlüsselbildschirme](#7-schlüsselbildschirme)
8. [Barrierefreiheit und Lokalisierung](#8-barrierefreiheit-und-lokalisierung)
9. [Rechnungs-PDF](#9-rechnungs-pdf)
10. [Technische Umsetzung](#10-technische-umsetzung)
11. [Briefing-Vorlage und Bewertungsraster](#11-briefing-vorlage-und-bewertungsraster)
12. [Offene Punkte](#12-offene-punkte)
13. [Änderungshistorie](#13-änderungshistorie)

---

## 0. Zielgruppe in einem Satz

Frau zwischen 20 und 60, durchschnittliche Ausbildung, Einzelunternehmerin mit
kleinem Webshop oder Dienstleistung, wenig Technikverständnis, schnell
überfordert, arbeitet vor allem am Telefon, hat Angst, etwas falsch zu machen
(Lastenheft Abschnitt 3, „Leitbild des typischen Nutzers“). Daraus folgt für
**jede** Variante:

- ein Schritt pro Bildschirm, eine Hauptaktion pro Bildschirm,
- Alltagssprache zuerst, Fachbegriff nur als Erklärung dahinter,
- keine Sackgassen: jeder Zustand hat einen sichtbaren nächsten Schritt,
- Ruhe statt Alarm: Warnungen sind klar, aber nicht bedrohlich,
- Bedienung mit einer Hand, bei Sonnenlicht und mit unsauberen Fingern
  (Lastenheft U-4).

---

## 1. Markenkern und Tonalität

### FEST

| ID | Regel |
|---|---|
| D-1.1 | **Markenkern:** verlässlich, ruhig, freundlich, ehrlich. Die App nimmt Angst, sie erzeugt keine. Kein Gamification-Druck, keine Countdown-Dringlichkeit, keine Schuldzuweisung. |
| D-1.2 | **Ansprache:** Die App und das Benutzerhandbuch verwenden durchgängig **„du“** (entschieden von der Auftraggeberin am 2026-10-12) (z. B. „Erfasse deinen ersten Beleg“). Eine Variante bleibt **innerhalb sich** einheitlich; keine Variante wechselt auf „Sie“. **Dokumente an Kundinnen und Kunden** (Rechnung, Zahlungserinnerung, Mahnung, Begleittext) stehen dagegen fest in der **Sie-Form**, ohne Umschaltung (entschieden 2026-10-14). Rechtstexte (Nutzungsbedingungen, Datenschutz) dürfen in der Form bleiben, die die Anwältin vorgibt. |
| D-1.3 | **Fehlermeldungen sagen, was zu tun ist** („Bitte gib einen Betrag ein, zum Beispiel 12,50“), nie nur, was falsch ist („Ungültige Eingabe“). |
| D-1.4 | **Hinweis „Keine Steuerberatung“** bleibt dort sichtbar, wo er heute steht (Bestätigungen, Einstellungen, erzeugte Auswertungen im Dokument selbst, Lastenheft L-17.1, L-17.6). Eine Variante darf ihn gestalten, nicht verkleinern bis zur Unlesbarkeit, nicht entfernen. |
| D-1.5 | **Fachbegriffe bleiben korrekt:** Rechnung, Storno, Umsatzsteuer, Vorsteuer, Kleinunternehmerregelung, UID/USt-IdNr. dürfen erklärt, aber nicht durch falsche Synonyme ersetzt werden („Steuer zurück“ statt Vorsteuer ist falsch). Österreichische und deutsche Begriffe kommen aus `TaxProfile`, nicht aus dem Design. |

**Verbotene Formulierungen** (in App, Screenshots, Onboarding, Leerzuständen;
übernommen aus der Werbe-Negativliste in [`STORE_LISTING.md`](STORE_LISTING.md),
Lastenheft L-22.20):

- „finanzamtssicher“, „rechtssicher“, „100 % korrekt“, „fehlerfrei“
- „GoBD-zertifiziert“, „GoBD-konform“, „zertifiziert“, „geprüft“
- „ersetzt den Steuerberater“, „Steuerberatung“ (außer im Satz „keine Steuerberatung“), „Steuerexperte in der Tasche“
- „immer aktuell“, „garantiert aktuell“
- „kostenlos“ ohne Folgepreis
- „Finanzamt“, „ELSTER“, „FinanzOnline“ als Teil von Name oder Logo
- Versprechen über Ergebnisse: „spart Steuern“, „nie wieder Ärger mit dem Finanzamt“, „du kannst nichts falsch machen“

### FREI

- Grad der Wärme (sachlich-freundlich bis herzlich), Einsatz von Humor in
  Leerzuständen (kein Humor in Warnungen und Fehlern).
- Illustrationen und Bildsprache in Leerzuständen und Onboarding.
- Mikrotexte, sofern D-1.3 bis D-1.5 gelten und die Länge Abschnitt 8 einhält.

---

## 2. Design-Tokens

### FEST: Namen und Rollen

Jede Variante definiert **alle** Tokens dieser Tabelle, für **Hell- und
Dunkelmodus**. Die Rolle ist festgelegt, der Wert frei.

| Token | Rolle | Mindestanforderung |
|---|---|---|
| `color.primary` | Hauptaktion, aktive Navigation | Text darauf (`color.onPrimary`) ≥ 4,5:1 |
| `color.onPrimary` | Text/Icon auf Primär | – |
| `color.secondary` | Nebenaktionen, Chips | Text darauf ≥ 4,5:1 |
| `color.surface` | Hintergrund von Flächen | – |
| `color.onSurface` | Fließtext | ≥ 4,5:1 auf `surface` |
| `color.onSurfaceVariant` | Nebentext, Beschriftungen | ≥ 4,5:1 auf `surface` |
| `color.outline` | Rahmen von Eingabefeldern | ≥ 3:1 auf `surface` |
| `color.outlineVariant` | dekorative Trennlinien | keine (rein dekorativ) |
| `color.income` | Einnahme | ≥ 4,5:1 auf `surface`, immer mit Vorzeichen/Icon |
| `color.expense` | Ausgabe | ≥ 4,5:1 auf `surface`, immer mit Vorzeichen/Icon |
| `color.success` | Ampel „ok“, abgeschlossen | ≥ 3:1 als Fläche/Icon, ≥ 4,5:1 als Text |
| `color.warning` | Ampel „Grenze naht“, Hinweise | wie `success` |
| `color.error` | Ampel „überschritten“, Fehler | wie `success` |
| `color.info` | Ampel „unvollständig“, neutrale Hinweise | wie `success`; **nicht** grün |
| `color.locked` | gestellte, schreibgeschützte Rechnung | wie `success` |
| `color.cancelled` | Storno | wie `success` |
| `spacing.xs / s / m / l / xl` | Abstände (Vorschlag 4/8/16/24/32 dp) | Raster 4 dp; Bildschirmrand ≥ 16 dp (compact) |
| `radius.s / m / l` | Ecken von Feldern, Karten, Dialogen | – |
| `type.display / headline / title / body / label / amount` | Schriftrollen | siehe Abschnitt 4 |
| `elevation.0 / 1 / 2` | Ebenen | Ebenen nie nur über Schatten unterscheiden, zusätzlich Fläche oder Rahmen |
| `motion.short / medium` + `motion.easing` | Übergänge | ≤ 300 ms; bei reduzierter Bewegung 0 ms (Abschnitt 8) |
| `touch.min` | Mindest-Touchfläche | **48 dp**, nicht veränderbar |

Kontrast: **WCAG 2.2 AA** – Text 4,5:1, großer Text (≥ 18 pt bzw. 14 pt fett)
3:1, Bedienelemente, Fokusrahmen und informationstragende Grafik 3:1
(Erfolgskriterien 1.4.3, 1.4.11). Jede Variante liefert eine Kontrasttabelle.
Wegen Lastenheft U-4 (Sonnenlicht) wird für `onSurface` und `amount` **7:1**
empfohlen.

### FREI

Alle Werte: Grundton, Seed-Farbe oder handverlesene Palette, Rundungen, Dichte
innerhalb der Mindestmaße, Schatten oder flach, Bewegungskurven.

Ist-Stand (Variante „Basis“ in `lib/theme.dart`): Seed `#1B4965`
(ruhiges Blau), `income #1B7F5A`, `expense #B3261E`, `warning #B26A00`,
Kartenradius 14, Buttonradius 10, Buttonhöhe 48.

---

## 3. Fachlich gebundene Farben und Zeichen

### FEST

Farbe ist **nie** der einzige Informationsträger (Lastenheft NF-6). Jeder
Zustand hat **Text + Icon + Farbe**; der Text allein muss ihn eindeutig machen.

| Zustand | Quelle im Code | Pflicht-Text (sinngemäß) | Pflicht-Icon (Bedeutung) | Farbrolle |
|---|---|---|---|---|
| Ampel: nicht zutreffend | `SmallBusinessStatus.notApplicable` | „Kleinunternehmerregelung nicht gewählt“ | neutral/Info | `info` oder neutral |
| Ampel: ok | `SmallBusinessStatus.ok` | Abstand zur Grenze in € | Haken | `success` |
| Ampel: Grenze naht (> 80 %) | `SmallBusinessStatus.approaching` | „Grenze bald erreicht“ + Restbetrag | Warndreieck | `warning` |
| Ampel: überschritten | `SmallBusinessStatus.exceeded` | „Grenze überschritten – ab sofort Umsatzsteuer ausweisen“ | Fehler/Stopp | `error` |
| Ampel: unvollständig | `SmallBusinessStatus.incomplete` | „Angaben fehlen“ + Aktion zum Ergänzen | Fragezeichen/Info | `info` – **nie grün**, nie wie „ok“ (O-19, RK-17) |
| Rechnung Entwurf | `InvoiceStatus.draft` | „Entwurf“ | Stift | neutral |
| Rechnung gestellt | `InvoiceStatus.issued` (`isLocked`) | „Gestellt“ + Hinweis „kann nicht mehr geändert werden, nur storniert“ | Schloss | `locked` |
| Rechnung bezahlt | `InvoiceStatus.paid` | „Bezahlt“ | Haken | `success` |
| Rechnung/Beleg storniert | `InvoiceStatus.cancelled`, Beleg-Storno | „Storniert“ | Durchgestrichen/Storno | `cancelled`; Betrag zusätzlich durchgestrichen **oder** mit „storniert“ beschriftet |
| Einnahme / Ausgabe | `AppTheme.amountColor` | Vorzeichen „+“ / „−“ | Pfeil oder Kategorie-Icon | `income` / `expense` |
| Warnung im Formular | `NoticeBanner` | Satz mit nächster Aktion | Warndreieck | `warning` |
| Fehler | Formularvalidierung | Satz mit nächster Aktion (D-1.3) | Fehler | `error` |

Weitere Regeln:

- Die Ampel ist **eine Aussage, keine Prognose**: kein Fortschrittsbalken, der
  „voll“ wie ein Erfolg wirkt; keine Konfetti- oder Belohnungsanimation.
- Gesperrte Inhalte sehen **lesbar** aus (kein ausgegrautes Unlesbares),
  Bearbeitungselemente sind entfernt, nicht nur deaktiviert.
- Rot ist reserviert für `error` und `expense`; eine Variante darf Rot nicht
  als Primärfarbe verwenden.

### FREI

Konkrete Icons (Material Symbols oder gleichwertige frei lizenzierte), Form der
Statusanzeige (Chip, Badge, Banner, Zeile), Farbtöne innerhalb der Kontrastregeln.

---

## 4. Typografie

### FEST

| ID | Regel |
|---|---|
| D-4.1 | Schrift ist **Systemschrift** (Roboto/SF Pro) oder eine Schrift unter **SIL Open Font License** bzw. vergleichbar freier Lizenz, im Repository mitgeliefert (kein Laden zur Laufzeit, offline-first, keine Datenübertragung an Google Fonts). Lizenzdatei liegt bei. |
| D-4.2 | **Dynamische Schriftgröße bis 200 %** ohne abgeschnittenen Text, ohne überlappende Elemente; Layout darf umbrechen oder scrollen. Kein `textScaler` fest auf 1,0. |
| D-4.3 | **Beträge mit Tabellenziffern** (`FontFeature.tabularFigures()`), rechtsbündig in Listen, damit Kommas untereinander stehen. Rolle `type.amount`. |
| D-4.4 | Geld wird **nur** über `Fmt` aus `lib/core/formatting.dart` formatiert (Locale `de_AT` bzw. `de_DE` aus dem Land des Profils, Symbol €). Kein eigenes Format in der Variante, keine `double`-Werte (CLAUDE.md Regel 1). |
| D-4.5 | Fließtext mindestens 14 sp, Beschriftungen mindestens 12 sp; Zeilenhöhe ≥ 1,4 für Fließtext. |
| D-4.6 | Keine Schrift, die Umlaute, ß, € oder das typografische Minus nicht vollständig enthält. |

### FREI

Schriftfamilie im Rahmen von D-4.1, Gewichte, Größenstufen, Laufweite, Groß-
oder Kleinschreibung von Überschriften (keine durchgehenden Versalien in
Fließtext).

---

## 5. Layout und Raster

### FEST

| Fensterklasse (Material 3) | Breite | Navigation | Muster |
|---|---|---|---|
| compact | < 600 dp | `NavigationBar` unten, 4 Ziele | eine Spalte |
| medium | 600–839 dp | `NavigationRail` links | eine Spalte, breitere Karten oder zwei Spalten in der Übersicht |
| expanded | ≥ 840 dp | `NavigationRail` (ausgeklappt erlaubt) | **Liste-Detail** für Belege und Rechnungen |

- Gilt für Smartphone und Tablet, **hoch und quer**. Kein Inhalt geht im
  Querformat verloren; Tastatur verdeckt nie das aktive Feld.
- Die **vier Navigationsziele** sind fest: Übersicht, Belege, Rechnungen,
  Export (Spezifikation 7). Einstellungen über ein Zahnrad in der Übersicht.
  Reihenfolge und Beschriftung nur mit Spezifikationsänderung.
- **Touchfläche ≥ 48 × 48 dp** für alles Bedienbare, Abstand zwischen
  Zielen ≥ 8 dp.
- Hauptaktion eines Bildschirms in Daumenreichweite (unten oder FAB).
- Inhalt maximal ca. 640 dp breit für Formulare auf großen Geräten (lesbare
  Zeilenlänge).

**Status: umgesetzt** (2026-10-12, Spezifikation 5.7, FA-9.1 bis FA-9.5):
`WindowSizeClass` in `lib/core/window_size.dart`, `NavigationRail` ab medium
(expanded ausgeklappt), Liste-Detail ab expanded für Belege, Rechnungen und
Kunden, Formulare höchstens 640 dp. Gerätetest offen: Spezifikation 14
P-D19, P-D20.

### FREI

Abstände im 4-dp-Raster, Kartenstil oder Listenstil, Kopfbereiche, Position von
Sekundäraktionen, Dichte (innerhalb der Mindestmaße).

---

## 5a. Einhandbedienung (UX-Prüfinstanz)

Entschieden von der Auftraggeberin am 2026-10-14: **keine Einstellung für Links-
oder Rechtshänder**, stattdessen **symmetrische Gestaltung**, die mit beiden
Daumen gleich gut funktioniert. Grundlage: Prüfbericht der UX-Instanz
(Material Design 3 und Apple HIG sehen keine Händigkeits-Option vor; etwa ein
Drittel der Einhandnutzung erfolgt mit links; die Mitte unten ist für beide
Hände am besten erreichbar; Android-Einhandmodus und iOS-Reachability gibt es
systemseitig). Hauptaktion auf der Übersicht ist **ein zentrierter, großer
Knopf „Beleg fotografieren“**; Einnahme/Ausgabe wird im Formular gewählt.

**FEST – Prüfregel, die die UX-Instanz bei jeder Oberflächenänderung abarbeitet:**

1. Primäraktion unten im Daumenbereich, volle Breite oder zentriert, ≥ 56 dp hoch.
2. Jede Zielfläche ≥ 48 × 48 dp, Abstand ≥ 8 dp; kein `VisualDensity.compact` bei Aktionen.
3. Zerstörende Aktion (Löschen, Stornieren) nie neben Speichern, Teilen oder Hilfe: Abstand ≥ 24 dp oder eigener Bereich am Formularende, Fehlerfarbe, Bestätigung oder „Rückgängig“.
4. Nichts Wichtiges nur oben in der AppBar; oben bleiben Zurück, Titel, Hilfe.
5. Mit offener Tastatur bleibt die Primäraktion sichtbar und das aktive Feld unverdeckt.
6. Dialoge: Abbrechen links, Aktion rechts als Verb; zerstörend in Fehlerfarbe; mehr als drei Optionen als Bottom-Sheet.
7. Keine abgeschnittenen Chip-Reihen auf 360 dp Breite – umbrechen statt seitlich scrollen.
8. Kernaufgaben in höchstens: Beleg erfassen 4 Tipps, Rechnung bezahlt markieren 2, mahnen 3. Mehr Schritte nur begründet.
9. Für beide Hände nutzbar: kein Element nur in einer oberen Ecke; Hauptknopf zentriert oder als Leiste.
10. Optionale Felder (Rabatt, Skonto, Versand) eingeklappt, Laientexte ohne Fachkürzel.
11. Geprüft auf 360 × 640 und 412 × 915 dp, Schrift 200 %, Dunkelmodus.
12. Widget-Test prüft Mindestgröße (≥ 48 dp) und Lage der Primäraktion (unteres Drittel).
13. **Aufnahmeknopf** (Entscheidung Auftraggeberin 2026-10-16): Beleg fotografieren ist die wichtigste Funktion und muss blind mit dem Daumen gehen. Runder Knopf `CaptureButton` (`lib/widgets/capture_button.dart`), Kreis 76 dp (≥ 72 dp), Kamerasymbol, Beschriftung „Beleg“ darunter, Semantik „Beleg fotografieren“; immer **unten in der Mitte** an derselben Stelle: Übersicht und Belegliste (`centerFloat` über der Navigationsleiste), im Belegformular mittig über „Beleg speichern“ (Beschriftung „Seite“ bzw. „Rückseite?“, mit offener Tastatur ausgeblendet). Auf Übersicht und Belegliste liegen links „Foto“ (Galerie) und rechts „Datei“ (PDF, E-Rechnung, Bild) als kleinere runde Knöpfe (Kreis 56 dp, Symbol, Beschriftung darunter) spiegelgleich neben „Beleg“, je 48 dp Abstand zum Hauptknopf, `CaptureBar` (Entscheidung Auftraggeberin 2026-10-16, 1.4); der Hauptknopf bleibt mittig und am größten. Nebenaktionen („Foto auswählen“) im Formular unverändert kleiner. Zerstörende Aktionen bleiben am Formularende (Regel 3). Widget-Test prüft Kreis ≥ 72 dp und Mitte ± 2 dp auf 360 und 412 dp.
14. **Schwebende Leisten weichen beim Scrollen aus** (Rückmeldung zu 0.30.0): Die Aufnahmeleiste der Übersicht gleitet beim Scrollen nach unten weg und kommt nach 5 s ohne Scrollen bzw. ganz oben sofort zurück (`ScrollHidingBar`). Nie während ein Finger auf ihr liegt; ausgeblendet keine Tipps; mit Screenreader immer sichtbar. Trefferflächen bleiben unverändert.
15. **Nebenoptionen statt Pflichtfragen:** Was nur wenige brauchen (z. B. Mithelfer-Gerät koppeln), steht als 48-dp-Textknopf mit „?“ im ersten Schritt – keine zusätzliche Frage für alle.

## 6. Komponentenkatalog

Vorhandene Bausteine (Stand Code 0.1.0). Jede Variante gestaltet **alle**
Zustände.

| Baustein | Datei | Zweck | Pflichtzustände |
|---|---|---|---|
| `SectionCard` | `lib/widgets/common.dart` | Abschnitt mit Titel und Inhalt | normal, leer, laden |
| `LabeledValue` | `lib/widgets/common.dart` | Beschriftung + Wert (oft Betrag) | normal, hervorgehoben, Betrag positiv/negativ |
| `MoneyField` | `lib/widgets/common.dart` | Betragseingabe (Cent intern) | leer, gefüllt, Fokus, Fehler, deaktiviert/gesperrt |
| `EmptyState` | `lib/widgets/common.dart` | Leerzustand mit Erklärung und Aktion | mit Aktion, ohne Aktion |
| `NoticeBanner` | `lib/widgets/common.dart` | Hinweis/Warnung im Bildschirm | info, warnung, fehler, mit/ohne Aktion |
| `PasswordField` | `lib/widgets/common.dart` | Kennwort mit Sichtbar-Schalter | leer, verdeckt, sichtbar, Fehler |
| `VatCheckStatus` | `lib/widgets/vat_check_status.dart` | Ergebnis der UID-Prüfung (VIES) | ungeprüft, prüft (laden), gültig, ungültig, Dienst nicht erreichbar (**offline**) |
| `NavigationBar` | `lib/features/home/home_shell.dart` | Hauptnavigation | aktiv, inaktiv, Fokus |
| Material-Standard | – | `FilledButton`, `TextField`, `ListTile`, `Card`, `Dialog`, `SnackBar`, `Chip` | normal, gedrückt, Fokus, deaktiviert, Fehler |

Querschnittszustände für jeden Bildschirm:

| Zustand | FEST |
|---|---|
| **leer** | `EmptyState` mit Satz, was hier entsteht, und genau einer Aktion |
| **laden** | Fortschrittsanzeige mit Text, wenn > 1 s; keine leeren Flächen ohne Erklärung |
| **Fehler** | Satz mit Ursache in Alltagssprache + nächster Schritt; Daten bleiben sichtbar |
| **gesperrt** | Schloss + Text (Abschnitt 3); Inhalt lesbar, Aktion „Stornieren“ statt „Bearbeiten“ |
| **offline** | App ist offline voll nutzbar; nur Funktionen mit Netz (UID-Prüfung, Teilen) zeigen „Keine Verbindung – später erneut versuchen“, nie einen Fehler für die Buchhaltung selbst |

---

## 7. Schlüsselbildschirme

Pflichtinhalte je Bildschirm (Quelle Spezifikation Abschnitt 7). Eine Variante
darf anordnen und gewichten, aber **nichts weglassen**.

| Bildschirm | Pflichtinhalte | Hauptaktion |
|---|---|---|
| Ersteinrichtung (`setup_wizard`) | Willkommensseite mit Logo (`assets/brand/logo.png`, austauschbar), Titel, Versprechen, „Los geht's“, „Erst ansehen (Demo)“, Wiederherstellen, Gerät koppeln mit „?“; Schritte mit „Schritt n von 5“ und Balken, Zurück, „Später hinzufügen“ (48 dp, 12 dp über dem Hauptknopf) | Hauptknopf unten volle Breite 56 dp |
| Bestätigungen (`consent_screen`) | Hinweis „keine Steuerberatung“ mit **eigenem Häkchen**, nichts vorausgewählt; Nutzungsbedingungen und Datenschutz mit Links auf die Volltexte und Annahme über den beschrifteten Knopf (Prüfinstanz Rechtsanwalt 2026-10-19) | Akzeptieren und weiter (56 dp) |
| Stammdaten (`company_setup_screen`) | Land AT/DE, Firmenname, Anschrift, Kleinunternehmer ja/nein, UID/Steuernummer, Firmenlogo (optional), Eröffnungswerte | Speichern; Schritte einzeln, Fortschritt sichtbar |
| Sperrbildschirm (`lock_screen`) | Entsperren per Gerätesicherung | Entsperren |
| Übersicht (`dashboard_screen`) | Kassabuch/Saldo, Umsatzsteuer des Zeitraums, **Grenzwertampel mit allen 5 Zuständen**, Verlauf, Stand der letzten geprüften Sicherung (L-7.9), Zahnrad zu Einstellungen | Aufnahmeleiste „Foto“ – „Beleg“ – „Datei“ (5a Regel 13) |
| Belegliste (`receipt_list_screen`) | Suche, Filter (inkl. „Storniert“), Einnahme/Ausgabe unterscheidbar, Datum, Betrag | Aufnahmeleiste „Foto“ – „Beleg“ – „Datei“ (5a Regel 13) |
| Beleg bearbeiten (`receipt_edit_screen`) | Foto/Seiten, Betrag, Steuersatz, Kategorie, Zahlungsart, Kommentare (nur anhängbar), Storno-Ansicht nur lesen | Speichern |
| Rechnungsliste (`invoice_list_screen`) | Nummer, Kunde, Betrag, **Status mit Text+Icon**, PDF teilen | Neue Rechnung |
| Rechnung bearbeiten (`invoice_edit_screen`) | Kunde, Positionen (Menge, Preis, Steuersatz je Position), Summen netto/USt/brutto, Hinweise zu fehlenden Pflichtangaben | **Ausstellen** mit Bestätigung, dass danach nicht mehr änderbar |
| Kunde bearbeiten (`customer_edit_screen`) | Name, Anschrift, UID mit `VatCheckStatus` | Speichern |
| Datensicherung (`backup_screen`) | Sicherung erstellen/teilen, Wiederherstellen **mit Vorschau**, Wiederherstellungscode-Hinweise (L-22.25) | Sicherung erstellen |
| Export (`export_screen`) | Zeitraum, Vorschau, Format; Hinweis „keine Steuerberatung“ im erzeugten Dokument | Exportieren |
| Einstellungen (`settings_screen`) | Stammdaten, Kategorien, Rechtsrahmen, Hinweise, Rechtstexte | – |

Für den Variantenvergleich sind **Pflicht-Screenshots**: Übersicht (Ampel
„ok“ und „unvollständig“), Belegliste (gefüllt und leer), Rechnung bearbeiten,
Rechnungsliste mit allen vier Status, Bestätigungen – jeweils hell und dunkel,
compact und expanded, einmal mit 200 % Schrift.

---

## 8. Barrierefreiheit und Lokalisierung

### FEST

| ID | Regel |
|---|---|
| D-8.1 | Jedes Icon ohne sichtbaren Text hat ein `Semantics`-Label bzw. `tooltip`. Beträge werden vollständig vorgelesen („minus zwölf Euro fünfzig“, nicht „Strich zwölf Komma fünf null“) – Label aus `Fmt` ableiten. |
| D-8.2 | Status (Ampel, Rechnungsstatus) wird als Text vorgelesen, nicht als Farbe. |
| D-8.3 | Logische Fokusreihenfolge, sichtbarer Fokusrahmen (≥ 3:1), Bedienung per externer Tastatur und Schaltersteuerung möglich. |
| D-8.4 | **Reduzierte Bewegung:** `MediaQuery.disableAnimations` bzw. Systemeinstellung respektieren – Übergänge auf 0 ms oder Überblenden; keine Parallaxe, kein Autoplay. |
| D-8.5 | Fehler werden mit `Semantics(liveRegion: true)` angekündigt. |
| D-8.6 | Bestätigungsdialoge für unumkehrbare Aktionen (Ausstellen, Stornieren, Wiederherstellen) nennen die Folge im Text. |
| D-8.7 | Textlängen: Layout verträgt **+40 %** längere Texte ohne Abschneiden (Puffer für lange deutsche Komposita und spätere Sprachen); Umbruch statt Ellipse bei Status- und Fehlertexten. |
| D-8.8 | Keine Texte in Bildern. Alle Texte in Dart-Strings, damit sie übersetzbar bleiben. |
| D-8.9 | Datum, Zahl und Währung ausschließlich über `Fmt` (de-AT / de-DE). |

Rechtlicher Rahmen: BFSG/BaFG voraussichtlich nicht anwendbar (Lastenheft
O-21, Spezifikation 14 P-R3); die Grundbarrierefreiheit NF-6 gilt trotzdem.

### FREI

Zusätzliche Hilfen (z. B. Erklär-Tooltips, Vorlesehilfen), Kontrastmodus als
Zusatz.

---

## 9. Rechnungs-PDF

Erzeugt in `lib/services/invoice_pdf.dart` (Ist-Stand: Helvetica, Akzent
`#1B4965`, Grauton `#5A6B78`).

### FEST

- **Pflichtangaben** nach § 11 UStG (AT) bzw. § 14 Abs. 4 UStG (DE) werden
  vollständig und gut lesbar ausgegeben; welche, entscheidet
  `lib/services/invoice_requirements.dart` und `TaxProfile`, nicht das Design.
  Dazu gehören u. a. Name und Anschrift von Leistendem und Empfänger,
  Ausstellungsdatum, fortlaufende Rechnungsnummer, Menge und Bezeichnung,
  Leistungszeitpunkt, Entgelt je Steuersatz, Steuersatz und Steuerbetrag bzw.
  Hinweis auf die Steuerbefreiung (Kleinunternehmer), UID je nach Fall.
- Das **Logo ergänzt Name und Anschrift, ersetzt sie nie** (Lastenheft L-1.9);
  es wird bei der Ausstellung eingefroren.
- **Gestellte Rechnungen werden nie neu gestaltet:** ein neues Theme wirkt nur
  auf künftige Rechnungen (CLAUDE.md Regel 7). Eingefrorene Daten bleiben
  unverändert.
- Schrift mindestens 9 pt für Pflichtangaben, Schwarz oder ≥ 7:1 auf Weiß;
  druckbar in Schwarzweiß ohne Informationsverlust.
- Schrift muss Umlaute, ß und € enthalten und eingebettet sein (siehe
  Spezifikation 14 P-D2).
- Format A4, Ränder druckerfest (≥ 15 mm).

### FREI

Akzentfarbe, Linien, Position und Größe des Logos, Schriftfamilie (Lizenz nach
D-4.1), Kopf- und Fußgestaltung, Gewichtung der Summenzeile. Ob das PDF dem App-
Theme folgt oder eine eigene Akzentfarbe aus den Stammdaten übernimmt, ist eine
Variantenentscheidung.

---

## 10. Technische Umsetzung

### FEST

| ID | Regel |
|---|---|
| D-10.1 | Alle Gestaltung über `ThemeData` und eine `ThemeExtension<AppTokens>` (Fach- und Statusfarben, Abstände, Radien, `type.amount`, Bewegung). |
| D-10.2 | **Keine Farbwerte in Widgets** (`Color(0x…)`, `Colors.red` in `lib/features/` oder `lib/widgets/` sind Fehler). Widgets lesen `Theme.of(context)` bzw. `Theme.of(context).extension<AppTokens>()`. |
| D-10.3 | **Keine Länderlogik im Theme** (CLAUDE.md Regel 5) und **keine Rechenlogik** im Theme. |
| D-10.4 | **Keine neuen Pakete** ohne schriftliche Begründung (Zweck, Lizenz, Pflegezustand, Größe, Datenübertragung). Insbesondere kein `google_fonts` mit Laufzeit-Download. |
| D-10.5 | Eine Variante ist **eine Datei** `lib/core/theme/<variante>.dart`, die `ThemeData light`, `ThemeData dark` und die `AppTokens`-Werte liefert. Schriftdateien unter `assets/fonts/<variante>/` mit Lizenz. |
| D-10.6 | Auswahl der Variante an genau einer Stelle (`lib/main.dart`); Varianten nicht zur Laufzeit für Endnutzerinnen umschaltbar, solange das nicht spezifiziert ist. |
| D-10.7 | Definition of Done aus CLAUDE.md gilt: `flutter analyze`, `dart format`, `flutter test` grün; Golden- bzw. Widget-Tests für Kontrast der Statusfarben empfohlen. |
| D-10.8 | Wird eine Variante produktiv übernommen, sind Spezifikation, Handbuch (Screenshots) und Release Notes im selben Commit anzupassen. |

Skizze:

```dart
// lib/core/theme/<variante>.dart
import 'package:flutter/material.dart';
import 'app_tokens.dart';

class SonnigTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final tokens = b == Brightness.light ? AppTokens.sonnigLight : AppTokens.sonnigDark;
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF…), brightness: b);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: [tokens],
      // filledButtonTheme, cardTheme, inputDecorationTheme … aus tokens
    );
  }
}
```

`AppTokens` (`lib/core/theme/app_tokens.dart`, entsteht mit der ersten Variante; heute gibt es nur `lib/theme.dart`) ist gemeinsam für alle
Varianten und enthält die Felder aus Abschnitt 2 mit `copyWith`/`lerp`. Die
heutige `lib/theme.dart` wird beim ersten Variantenbau zur Variante „Basis“
überführt (Refactoring ohne Verhaltensänderung).

---

## 11. Briefing-Vorlage und Bewertungsraster

### Briefing (kopierfertig)

```text
Du entwirfst eine Designvariante für eine Flutter-Buchhaltungsapp (Android/iOS,
offline) für Einzelunternehmerinnen in Österreich und Deutschland.

EINGABEN
- Verbindlich: docs/DESIGN_SPEC.md (alle FEST-Regeln), docs/SPECIFICATION.md
  Abschnitt 7, lib/theme.dart, lib/widgets/, lib/core/formatting.dart,
  docs/STORE_LISTING.md (Werbe-Negativliste).
- Variantenname: <NAME>
- Stimmung in drei Wörtern: <z. B. warm, klar, erwachsen>
- Abgrenzung zu bestehenden Varianten: <...>
- Name und Logo der App sind NICHT festgelegt: nur Platzhalter „App-Name“ und
  ein neutrales Platzhalter-Zeichen verwenden.

ZIELGRUPPE
Frau 20–60, durchschnittliche Bildung, kleiner Webshop oder Dienstleistung,
wenig Technikverständnis, schnell überfordert, Angst vor Fehlern, nutzt fast nur
das Telefon. Ein Schritt pro Bildschirm, Alltagssprache, keine Sackgassen.

HARTE GRENZEN
- Alle Tokens aus Abschnitt 2 für hell und dunkel; WCAG 2.2 AA (4,5:1 Text,
  3:1 UI) mit Kontrasttabelle belegen.
- Status nie nur über Farbe (Abschnitt 3); Ampel „unvollständig“ nie grün.
- Schrift: System oder OFL, mitgeliefert; Beträge tabular; 200 % Schrift.
- Touch ≥ 48 dp; Breakpoints 600/840 dp; 4 Navigationsziele unverändert.
- Keine Farbwerte in Widgets, keine neuen Pakete, keine Fach- oder Länderlogik.
- Keine Formulierung aus der Verbotsliste in Abschnitt 1. Keine Rechts- oder
  Steuerversprechen.
- Pflichtangaben im Rechnungs-PDF unverändert vollständig.

AUSGABE
1. Kurzbeschreibung der Idee (max. 5 Sätze) und Begründung für die Zielgruppe.
2. Token-Tabelle (Name | Wert hell | Wert dunkel | Kontrastwert | Bezug).
3. Datei lib/core/theme/<name>.dart (lauffähig, flutter analyze ohne Befund).
4. Ggf. Schriftdateien + Lizenz unter assets/fonts/<name>/ und pubspec-Eintrag.
5. Screenshots der Pflichtbildschirme aus Abschnitt 7 (hell/dunkel,
   compact/expanded, 200 % Schrift).
6. Selbstbewertung nach dem Bewertungsraster, mit Abweichungen und offenen
   Fragen. Nichts ändern außerhalb von lib/core/theme/, assets/fonts/ und
   pubspec.yaml (Assets).
```

### Bewertungsraster

Ausschlusskriterien (eines verfehlt → Variante ungültig):

- [ ] Alle Tokens hell und dunkel definiert, Kontraste AA nachgewiesen
- [ ] Kein Status nur über Farbe; Ampel „unvollständig“ von „ok“ unterscheidbar
- [ ] 200 % Schrift ohne Abschneiden auf allen Pflichtbildschirmen
- [ ] Touchflächen ≥ 48 dp
- [ ] Keine verbotene Formulierung, Hinweis „keine Steuerberatung“ sichtbar
- [ ] Keine Farbwerte in Widgets, keine neuen Pakete ohne Begründung
- [ ] Rechnungs-PDF mit allen Pflichtangaben, schwarzweiß lesbar
- [ ] Kein finaler Name, kein finales Logo
- [ ] `flutter analyze` und `flutter test` grün

Vergleichskriterien (je 1–5 Punkte):

| Kriterium | Frage |
|---|---|
| Ruhe | Wirkt der Bildschirm aufgeräumt, nimmt er Angst? |
| Klarheit der Hauptaktion | Ist in 3 s klar, was als Nächstes zu tun ist? |
| Statusverständnis | Versteht eine Testperson Ampel und Rechnungsstatus ohne Erklärung? |
| Lesbarkeit draußen | Kontrast und Größe bei Sonnenlicht (U-4) |
| Beträge | Schnell erfassbar, Kommas untereinander, Vorzeichen klar |
| Tablet / quer | Nutzt die Fläche sinnvoll (Rail, Liste-Detail)? |
| Dunkelmodus | Gleichwertig, nicht nur invertiert |
| Eigenständigkeit | Unterscheidbar von generischem Material-Standard und Mitbewerbern |
| Umsetzungsaufwand | Nur Theme-Datei oder Eingriffe in Widgets nötig? |
| Markentauglichkeit | Trägt die Variante einen späteren Namen und ein Logo? |

---

## 12. Offene Punkte

| Punkt | Stand | Verweis |
|---|---|---|
| Produktname und Marke | entschieden 2026-10-15: „JeNi bucht“, Markenrecherche ohne Befund | Lastenheft O-25, Spezifikation 14 **P-R7** |
| Logo | erst nach Namensentscheidung; bis dahin nur Platzhalter | folgt aus O-25 / P-R7 |
| Ansprache du / Sie | „du“ – entschieden 2026-10-12 | erledigt |
| Store-Screenshots je Variante | vor jeder Einreichung prüfen | Spezifikation 14 **P-R13** |
| Barrierefreiheitspflicht | voraussichtlich nicht anwendbar | Spezifikation 14 **P-R3** |
| Umlaute im PDF mit gewählter Schrift | nicht verifiziert | Spezifikation 14 **P-D2**, **P-D13** |

Weitere Prüfpunkte für die reale Welt (Gerätetest der Varianten, Test mit der
Zielgruppe, Lizenzprüfung von Schriften und Icons) sind **noch nicht** in
Spezifikation Abschnitt 14 angelegt; sie werden dort ergänzt, sobald der
Auftraggeber sie freigibt, und hier nur per ID verwiesen.

---

## 13. Änderungshistorie

| Version | Datum | Änderung |
|---|---|---|
| 1.6 | 2026-10-19 | Abschnitt 5a Regeln 14 und 15: Aufnahmeleiste weicht beim Scrollen aus; Nebenoptionen statt Pflichtfragen (Mithelfer-Koppeln in Schritt 2). Willkommensseite: Titel größer, Funktionszeilen einzeilig auf 360 dp. PDF-Betrachter: Papier immer weiß. |
| 1.5 | 2026-10-19 | Abschnitt 7: Ersteinrichtung als Schrittfolge (Willkommensseite, Schritte 1–5), Bestätigungen mit einem Häkchen und beschriftetem Knopf; Stammdaten nur noch zum Bearbeiten. |
| 1.4 | 2026-10-16 | Abschnitt 5a Regel 13: „Foto“ und „Datei“ (56 dp, 48 dp Abstand, spiegelgleich) neben dem Aufnahmeknopf auf Übersicht und Belegliste. |
| 1.3 | 2026-10-16 | Abschnitt 5a Regel 13: runder Aufnahmeknopf „Beleg“ (≥ 72 dp) unten in der Mitte auf Übersicht, Belegliste und im Belegformular. |
| 1.2 | 2026-10-14 | Abschnitt 5a Einhandbedienung: Prüfregel der UX-Instanz, keine Händigkeits-Einstellung, zentrierter Hauptknopf. |
| 1.1 | 2026-10-12 | Abschnitt 5: Status „umgesetzt“ für Breitenklassen, NavigationRail, Liste-Detail und Formularbreite. |
| 1.0 | 2026-10-12 | Erste Fassung: feste Regeln und Gestaltungsspielraum für Designvarianten, Briefing-Vorlage, Bewertungsraster. |
