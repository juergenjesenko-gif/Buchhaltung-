# Launch – Google Play und App Store

**Stand:** 2026-10-22 · App 0.39.1 · Spezifikation 2.10 · Märkte: Österreich, Deutschland

Ein Dokument, von oben nach unten abarbeiten. Prüfinstanzen Softwareentwickler,
Rechtsanwalt, Steuerberater und UX haben die Schritte am 2026-10-21 gemeinsam
zusammengestellt; Feldnamen der Konsolen aus öffentlichen Hilfeseiten (Quellen
am Ende), **nicht live in den Konsolen geprüft**. Weicht eine Konsole ab, gilt
die Konsole, und der Punkt kommt nach `SPECIFICATION.md` Abschnitt 14.

Reale Prüfpunkte stehen nur dort; hier steht jeweils die ID (P-…).

Details zu den Abo-Produkten: `STORE_ANMELDUNG.md` Formular 4. Texte:
`STORE_LISTING.md`. Build: `RELEASE_PLAYBOOK.md`.

> Links in die Konsolen öffnen in der Claude-App am besten so: **Im Fenster
> der Claude-App ⋮ → In Chrome öffnen**. Die Konsolen brauchen die Anmeldung
> mit office@jenibarb.com.

---

## 0. Ampel: blockiert den Start

🔴 = ohne das keine Einreichung · 🟡 = vor Einreichung erledigen, geht schnell ·
🟢 = erledigt

| # | Punkt | Ampel | Wer | Verweis |
|---|---|---|---|---|
| 1 | **Platzhalter `{{…}}` in den Rechtstexten**: ersetzt 2026-10-23 (Gewerbe „Handel mit Waren aller Art“, Kammer WK Kärnten, Bundessparte Handel; Rügefrist 14 Tage; Mindesthaftung 250 €). UBIT und IT-Gewerbe stehen erst nach der Anmeldung im Impressum (Punkt 17) | 🟢 | Auftraggeber | P-L8, P-L9, P-L4, P-R1 |
| 2 | **Datenschutzerklärung** um ML Kit, Dokumentenscanner, EZB-Kurs, Link-QR, Mithelfer-Mailweg, Serversuche und Diktat ergänzt (Fassung 2026-10-24); stimmt mit den Store-Formularen überein. Rechtliche Einordnung für die Anwältin: P-R78 | 🟢 | – | P-R68, P-R78 |
| 3 | **Öffentliche URL** für Datenschutz und Support (beide Stores Pflicht) – online unter jenibucht.com seit 2026-10-22 | 🟢 | Auftraggeberin | Abschnitt 1, **P-D59** |
| 4 | **Rechtstexte anwaltlich geprüft**, Entwurfsvermerk entfernt | 🔴 | Anwältin | P-L1, P-L4–P-L6, P-L10, P-R11, P-R67, P-L20 |
| 5 | **Abo-Produkte** in beiden Konsolen angelegt und aktiv; Apple: Gruppe und vier Abos mit Version 0.39.2 eingereicht 2026-10-23 | 🟢 | Auftraggeberin | Abschnitte 2.1, 3.1, P-D30 |
| 6 | **Bank, Steuer, Vertrag kostenpflichtige Apps** (Apple), Zahlungsprofil (Google) | 🟢 | Auftraggeberin mit Steuerberatung | P-S11, P-S13 |
| 7 | **Sandbox-Testkäufe** mit Build `abo=true` auf echten Geräten – iPhone (TestFlight, Build 26) Abo-Kauf erfolgreich 2026-10-23; Android nach Freigabe des geschlossenen Tests | 🟡 | Auftraggeberin | P-D4, P-D31, P-D46, P-D47, P-D55 |
| 8 | **Screenshots** (separate Automatik): Play 2–8 × 1080×1920 + Feature-Grafik 1024×500; Apple verlangt in der neuen Konsole iPhone 1206×2622 (6,3", aus 1320×2868 verkleinert) und iPad 13" 2064×2752 – hochgeladen 2026-10-22/23 | 🟢 | Automatik | P-D34, `STORE_LISTING.md` |
| 9 | **App-Symbol** endgültig (512×512 Play, 1024×1024 Apple ohne Alpha) | 🟡 | Entwicklung | RELEASE_PLAYBOOK „Was noch fehlt“ |
| 10 | **Store-Texte** gegen Negativliste und UWG geprüft | 🟡 | Anwältin | P-R13, P-R60, P-R62 |
| 11 | **Abo-Seite und Test-Wortlaut** rechtlich bestätigt | 🟡 | Anwältin | P-R12, P-R37, P-R38, P-R57 |
| 12 | **Haftpflicht** (Vermögensschaden/Produkthaftung) – verschoben bis Launch, jetzt fällig | 🟡 | Auftraggeberin | P-R8 |
| 13 | **Export-Compliance** iOS bestätigt | 🟡 | Entwicklung | P-D9 |
| 14 | **Altersfreigabe-Fragebogen Apple (neue Fassung)** und Google-Finanzfunktionen-Deklaration – erledigt 2026-10-22 (Apple 4+, Google PEGI/USK eingereicht, Finanzfunktionen keine, Werbe-ID nein) | 🟢 | Auftraggeberin | **P-D60** |
| 15 | targetSdk ≥ 36 (Play-Pflicht für neue Apps ab 31.08.2026) im AAB bestätigt | 🟡 | Entwicklung | P-D6, P-D10 |
| 16 | Konten Google (Organisation) und Apple (Einzelperson), D-U-N-S, Bundle-ID `at.jenibarb.jenibucht`, interner Test und TestFlight | 🟢 | – | `STORE_READINESS.md` |
| 17 | **IT-Gewerbe anmelden**: „Dienstleistungen in der automatischen Datenverarbeitung und Informationstechnik“ (freies Gewerbe, GISA). Erst danach stimmt die Fachgruppe UBIT im Impressum; das Handelsgewerbe deckt die Herstellung von Software wohl nicht | 🔴 | Auftraggeber | **P-R70** |
| 19 | **Einreichung**: Google geschlossener Test (Alpha) mit Store-Eintrag zur Prüfung 2026-10-22; Apple Version 0.39.2 (Build 26) mit Abos zur Prüfung 2026-10-23, Freigabe **manuell** – Release erst, wenn die roten Punkte 1, 2, 4 und 17 erledigt sind | 🟡 | Auftraggeber | – |
| 18 | **Vor der ersten Instagram-Werbung**: KI-Kennzeichnung je Beitrag (Einblendung, Caption, Meta-Label), Hinweis bei der ersten KI-Antwort, Bildrückwärtssuche der KI-Figur, Produktseite im Instagram-Browser getestet | 🔴 | Auftraggeber | P-R71, P-R72, P-R75, P-R76, P-R77, P-X32, `STORE_LISTING.md` „Instagram-Auftritt“ |

---

## 1. Website: Produktseite, Datenschutz, Support, Impressum (beide Stores)

Die Rechtsseiten entstehen aus `docs/legal/*.md` – dieselben Texte wie in der
App. Die Startseite ist die Produktseite (Ziel des Instagram-Bio-Links), Quelle
`tool/site/produktseite.html`:

```bash
python3 tool/site/build_site.py
```

Ergebnis in `docs/site/`: `index.html` (Produktseite), `support.html`,
`datenschutz.html`, `impressum.html`, `nutzungsbedingungen.html`, `style.css`;
fest abgelegt `fonts/` (WOFF2 mit OFL-Lizenzen, P-L21) und `img/` (Logo,
KI-Szene). Ohne Cookies, Skripte, Schriften oder Bilder von außen. Länderteile erscheinen als zwei
Kästen „Gilt in Österreich“ / „Gilt in Deutschland“. Offene Platzhalter
stehen gelb als „OFFEN: …“ da – **so nicht veröffentlichen** (Ampel 1).

**Weg A (entschieden 2026-10-22): eigene Domain jenibucht.com.** Den ganzen
Inhalt von `docs/site/` (Dateien und die Ordner `fonts/`, `img/`) direkt ins
Hauptverzeichnis der Domain hochladen, Zugriff nur über https. Die E-Mail
bleibt office@jenibarb.com. Adressen dann:

```
Datenschutz-URL:  https://jenibucht.com/datenschutz.html
Support-URL:      https://jenibucht.com/support.html
Marketing-URL:    https://jenibucht.com/
Instagram-Bio:    https://jenibucht.com/  und  https://jenibucht.com/impressum.html
Nutzungsbed.:     https://jenibucht.com/nutzungsbedingungen.html
```

Hoster: **helloly GmbH**, Linz (Paket Webhosting SMART, Server
cloud25.helloly.hosting in Österreich, gebucht 2026-10-22). In der
Datenschutzerklärung eingetragen; Speicherdauer der Server-Protokolle
höchstens 30 Tage laut Datenschutzerklärung von helloly – **vor dem
Hochladen** den Auftragsverarbeitungsvertrag bei helloly anfordern und die
30 Tage für den eigenen Webspace bestätigen lassen (P-R74). Hochladen:
helloly-Kundenbereich → Paket → „in cPanel einloggen“ → Dateimanager →
`public_html` → ZIP der Website hochladen → „Extract“.

**Weg B: GitHub Pages** (Hoster GitHub Inc., USA – in der Datenschutzerklärung
Abschnitt 8 die Übermittlung angeben, P-L9). Der Workflow
`.github/workflows/pages.yml` veröffentlicht nur `docs/site/`, nie den Rest
von `docs/` (dort stehen Telefonnummer, Prüfmappen, Spezifikation).

1. [Pages-Einstellung öffnen](https://github.com/juergenjesenko-gif/Buchhaltung-/settings/pages)
   → **Source: GitHub Actions**. (Bei einem privaten Repository braucht Pages
   ein bezahltes GitHub-Konto.)
2. [Umgebung github-pages](https://github.com/juergenjesenko-gif/Buchhaltung-/settings/environments)
   → **github-pages** → Deployment branches → **Add deployment branch rule** →
   `claude/agile-accounting-app-mobile-wa5j3h` (sonst darf nur `main`
   veröffentlichen).
3. [Workflow „Website“ starten](https://github.com/juergenjesenko-gif/Buchhaltung-/actions/workflows/pages.yml)
   → **Run workflow** → Branch wie oben.
4. Adressen:

```
Datenschutz-URL:  https://juergenjesenko-gif.github.io/Buchhaltung-/datenschutz.html
Support-URL:      https://juergenjesenko-gif.github.io/Buchhaltung-/support.html
Marketing-URL:    https://juergenjesenko-gif.github.io/Buchhaltung-/
```

**Nicht** „Deploy from a branch → /docs“ wählen: das veröffentlicht alle
Projektdokumente.

Prüfen nach dem Hochladen: P-D59 (erreichbar ohne Login, keine externen
Aufrufe), P-X31 (am Handy einhändig lesbar).

---

## 2. Google Play

Konsole: [Play Console – App-Liste](https://play.google.com/console/developers)
→ **JeNi bucht** öffnen. Alle Schritte unten gehen von dort aus.

### 2.1 Abo-Produkte anlegen

Voraussetzung: ein Build mit Abrechnung ist hochgeladen (Schritt 2.7 einmal
mit `track=internal`, `abo=true`) und das
[Zahlungsprofil](https://payments.google.com/gp/w/home/settings) hat Bank und
Steuer (UID ATU81604346).

1. **Monetarisieren mit Play → Produkte → Abos → Abo erstellen**. Viermal:

   | Produkt-ID | Name |
   |---|---|
   | `basis_monat` | JeNi bucht Basis monatlich |
   | `basis_jahr` | JeNi bucht Basis jährlich |
   | `pro_monat` | JeNi bucht Pro monatlich |
   | `pro_jahr` | JeNi bucht Pro jährlich |

   IDs **genau so** (Code: `LicensePolicy.products`). Später nicht änderbar.
2. Je Abo **Basis-Tarif hinzufügen**: ID `monat` bzw. `jahr`, **Automatische
   Verlängerung**, Zeitraum 1 Monat bzw. 1 Jahr, Kulanzzeitraum **7 Tage**
   (oder länger), Wiederherstellung an.
3. **Preise festlegen** → nur Österreich und Deutschland → **Grundpreis**
   (= ab dem zweiten Jahr, inkl. USt):

   ```
   basis_monat  12,90 €     basis_jahr  129,00 €
   pro_monat    17,90 €     pro_jahr    179,00 €
   ```
   Google rechnet bei Eingabe eines Preises in andere Länder um – alle
   anderen Länder abwählen. Basis-Tarif **aktivieren**.
4. Je Abo **Angebot hinzufügen** (Einführung, ganz automatisch):
   - Angebots-ID `erstes-jahr`
   - Berechtigung **Neukundenakquisition → Hat noch nie ein Abo dieser App gehabt**
   - Phase 1: **Kostenloser Testzeitraum, 14 Tage**
   - Phase 2: **Einführungspreis**

     ```
     basis_monat  wiederkehrend 12 × 1 Monat à 6,90 €
     basis_jahr   einmalig 1 Jahr 69,00 €
     pro_monat    wiederkehrend 12 × 1 Monat à 12,90 €
     pro_jahr     einmalig 1 Jahr 129,00 €
     ```
   - kein Tag → **Aktivieren**.
5. Rabattcode 20 % (`JENIBUCHT20`, `JENIBUCHT20PRO`): bei `basis_jahr` und
   `pro_jahr` je ein Angebot `jenibucht20`, Berechtigung **Vom Entwickler
   festgelegt**, Phase Einführungspreis einmalig 1 Jahr **55,20 €** bzw.
   **103,20 €**, **Tag `jenibucht20`** (klein, genau so) → Aktivieren. Die App
   zeigt es nach Eingabe des Codes (P-R63).
6. 2 Monate gratis (`JENIBUCHT2M`): bei `pro_monat` Angebot `promo-2m`,
   **Vom Entwickler festgelegt**, Phase Kostenloser Testzeitraum **2 Monate** →
   Aktivieren. Dann **Monetarisieren → Promo-Codes → Benutzerdefinierter
   Code** `JENIBUCHT2M`, Produkt `pro_monat`, Angebot `promo-2m`, Limit z. B.
   1.000, Ablaufdatum der Kampagne (P-D32, P-D14).
7. **Einstellungen → Lizenztests** (in der App-Liste links unten
   [Einstellungen](https://play.google.com/console/developers)) → eigene
   Google-Adresse eintragen, Antwort „RESPOND_NORMALLY“.

`JENIBUCHTSTART*` gibt es auf Android **nicht** – dort kommt der Preis fürs
erste Jahr automatisch (O-45).

### 2.2 Store-Eintrag

**Wachstum → Store-Präsenz → Haupteintrag im Play Store**, Sprache
**Deutsch – de-DE** (AT erbt):

| Feld | Eintrag |
|---|---|
| App-Name (30) | `JeNi bucht` |
| Kurzbeschreibung (80) | aus `STORE_LISTING.md` „Kurzbeschreibung“ |
| Vollständige Beschreibung (4000) | aus `STORE_LISTING.md` „Vollständige Beschreibung“ |
| App-Symbol | 512×512 PNG |
| Feature-Grafik | 1024×500 |
| Screenshots Telefon | 2–8, 1080×1920, Reihenfolge `STORE_LISTING.md` |
| Tablet 7"/10" | empfohlen (1200×1920, 1600×2560) |

**Store-Einstellungen**: App · Kategorie **Finanzen** · Tags „Buchhaltung“,
„Rechnungen“ · E-Mail `office@jenibarb.com` · Telefon `+43 660 3124252` ·
Website = Support-URL aus Abschnitt 1.

### 2.3 App-Inhalte (Richtlinie → App-Inhalte)

Jeden Punkt der Liste beantworten:

| Formular | Antwort |
|---|---|
| Datenschutzerklärung | Datenschutz-URL aus Abschnitt 1 |
| App-Zugriff | **Alle Funktionen ohne besonderen Zugriff verfügbar** (kein Login; Demo über „Erst ansehen (Demo)“) |
| Werbung | **Nein, keine Werbung** |
| Einstufung (IARC) | siehe 2.4 |
| Zielgruppe | **18 und älter** · App spricht Kinder nicht an |
| Nachrichten-Apps | nein |
| Behörden-App | **Nein** |
| Gesundheits-Apps / Gesundheitsfunktionen | **Keine** |
| Finanzfunktionen | „Meine App bietet **keine** der aufgeführten Finanzfunktionen“ (keine Kredite, Zahlungen, Krypto, Bank, Anlage). Sonstiges: Buchhaltungswerkzeug, keine Finanzdienstleistung (P-D60) |
| Werbe-ID | **Nein** – App nutzt keine Werbe-ID (`AD_ID` nicht im Manifest, P-D60) |
| VPN, Standort im Hintergrund, Glücksspiel | nein |
| Datensicherheit | siehe 2.5 |
| Händlerstatus (DSA) | **Händler** – Spirits by JeNiBarb e.U., Sankt Leonhard bei Siebenbrünn 96, 9587 Arnoldstein, Österreich, +43 660 3124252, office@jenibarb.com, UID ATU81604346, FN 643550 y (P-R10) |
| Berechtigungen (Kamera, Mikrofon `RECORD_AUDIO`) | Kamera: Belege fotografieren. Mikrofon: Diktat, Erkennung nur auf dem Gerät |

### 2.4 Einstufung (IARC-Fragebogen)

E-Mail `office@jenibarb.com` · Kategorie **„Alle anderen App-Typen“
(Dienstprogramm, Produktivität …)**. Gewalt, Sexualität, Sprache, Drogen,
Alkohol, Glücksspiel, Horror: **nein**. Nutzer interagieren oder tauschen
Inhalte aus: **nein**. Teilt Standort: **nein**. Digitale Käufe: **ja**.
Ergebnis erwartet PEGI 3 / USK 0.

### 2.5 Datensicherheit (Data Safety)

Grundlage `STORE_LISTING.md` „Formularantworten“; muss mit der
Datenschutzerklärung übereinstimmen (Ampel 2, P-R68).

```
Erhebt oder teilt die App erforderliche Nutzerdaten?        Ja
Alle Daten bei der Übertragung verschlüsselt?               Ja
Möglichkeit, Löschung zu beantragen?                        Nein – Daten liegen
   nur auf dem Gerät; App deinstallieren löscht alles (Hinweis auf Support-URL)

Datentyp                         erhoben geteilt optional Zweck
Finanzinfos – Sonstige (UID/VIES)  nein    ja     ja      App-Funktionen
Finanzinfos – Kaufverlauf          ja      nein   nein    App-Funktionen
App-Info/-Leistung – Absturzprot.  nein    ja     nein    Analyse (ML Kit/Play-Dienste)
App-Info/-Leistung – Diagnose      nein    ja     nein    Analyse (ML Kit/Play-Dienste)
Fotos, Dateien, Audio, Standort, Kontakte, Nachrichten, Kennungen: nicht erhoben
```

Unsicher: P-R14, P-R19, P-R37, P-R42, P-R45, P-R47, P-U4, P-B8.

### 2.6 Länder und Preise

**Testen und veröffentlichen → Produktion → Länder/Regionen** → nur
**Österreich** und **Deutschland**. App ist **kostenlos** (Abos in der App).

### 2.7 Release-Build mit Lizenzprüfung

1. [Workflow „Release“ öffnen](https://github.com/juergenjesenko-gif/Buchhaltung-/actions/workflows/release.yml)
   → **Run workflow** → Branch `claude/agile-accounting-app-mobile-wa5j3h`:

   ```
   track:   production
   abo:     ✔ (an)
   version: (leer = aus pubspec.yaml)
   ```
2. Der Workflow lädt das AAB als **Entwurf** hoch (`status: draft`).
   Play Console → **Produktion → Release bearbeiten** → Versionshinweise:

   ```
   Erste Version von JeNi bucht für Österreich und Deutschland.
   ```
3. **Gestaffelter Rollout**: 20 % → **Überprüfung starten**. Nach 2–3 Tagen
   ohne Auffälligkeiten (Absturzstatistik in **Qualität → Android Vitals**)
   auf 50 %, dann 100 %.

Ein Organisationskonto braucht keinen geschlossenen Test mit 12 Personen
(P-D10). Prüfdauer meist 1–7 Tage.

---

## 3. App Store (iPhone, iPad)

Konsole: [App Store Connect – Apps](https://appstoreconnect.apple.com/apps)
→ **JeNi bucht**. Team 544URFBCH5, Verkäufer „Jürgen Jesenko“ (P-R23).

### 3.1 Verträge, Bank, Steuern (zuerst)

1. [Business](https://appstoreconnect.apple.com/business) → **Paid Apps
   Agreement** annehmen → Bankkonto → Steuerformular **W-8BEN** (Einzelperson,
   Österreich, Abkommen AT–USA Art. 12, 0 %) (P-S11, P-S13).
2. [Small Business Program](https://developer.apple.com/app-store/small-business-program/)
   beantragen (15 % Provision).
3. **Business → Digital Services Act** → **Ich bin Händler** mit Anschrift,
   Telefon, E-Mail wie in 2.3 (P-R10).

### 3.2 Abo-Produkte

1. App → **Monetarisierung → Abonnements** → Abogruppe **„JeNi bucht“**.
2. Vier Abos mit Referenzname = Produkt-ID: `basis_monat`, `basis_jahr`,
   `pro_monat`, `pro_jahr`. **Stufen:** Pro (1) über Basis (2).
3. Je Abo: Dauer 1 Monat / 1 Jahr, **Preis** nur AT und DE (andere Länder
   in der Verfügbarkeit abwählen):

   ```
   basis_monat  12,90 €     basis_jahr  129,00 €
   pro_monat    17,90 €     pro_jahr    179,00 €
   ```
   Lokalisierung Deutsch: Anzeigename „Basis monatlich“ usw., Beschreibung
   „Belege, Rechnungen, Export“ (Basis) bzw. „Alles aus Basis plus
   Belegerkennung, Import, Jahresabschluss“ (Pro). Prüfungs-Screenshot der
   Abo-Seite der App.
4. **Einführungsangebot** je Abo: AT, DE · **Kostenlos** · **2 Wochen** ·
   Start heute, kein Ende. Danach Grundpreis (Variante A, O-45).
5. **Angebotscodes** (Variante A plus Codes) – je Abo „Angebotscode
   erstellen“, Berechtigung **Neue Abonnenten**, „Introductory Offers“ **Yes, eligible customers can get both** (erst
   14 Tage gratis, dann Codepreis – wie bei Google Play; Entscheidung 2026-10-22), benutzerdefinierter Code:

   | Abo | Angebot | Code |
   |---|---|---|
   | `basis_monat` | Pay as you go, 12 × 1 Monat, 6,90 € | `JENIBUCHTSTART` |
   | `basis_jahr` | Pay up front, 1 Jahr, 69,00 € | `JENIBUCHTSTARTJAHR` |
   | `pro_monat` | Pay as you go, 12 × 1 Monat, 12,90 € | `JENIBUCHTSTARTPRO` |
   | `pro_jahr` | Pay up front, 1 Jahr, 129,00 € | `JENIBUCHTSTARTPROJAHR` |
   | `basis_jahr` | Pay up front, 1 Jahr, 55,20 € | `JENIBUCHT20` |
   | `pro_jahr` | Pay up front, 1 Jahr, 103,20 € | `JENIBUCHT20PRO` |
   | `pro_monat` | Kostenlos, 2 Monate | `JENIBUCHT2M` |

   Apple erlaubt einen benutzerdefinierten Code nur für ein Angebot; deshalb
   je Produkt eigene Codes. Einlösungen bis 25.000 je Code, Ablaufdatum der
   Kampagne. Ergebnis am Gerät: P-D55, P-D14.
6. Abogruppe → **Billing Grace Period** an (16 Tage).
7. [Sandbox-Konto](https://appstoreconnect.apple.com/access/users/sandbox)
   anlegen, damit testen (P-D4).

### 3.3 App-Informationen

**Allgemein → App-Informationen**:

| Feld | Eintrag |
|---|---|
| Name (30) | `JeNi bucht` |
| Untertitel (30) | `Belege, Rechnungen, Export` |
| Primäre Sprache | Deutsch |
| Kategorie | Primär **Finanzen**, sekundär **Wirtschaft** |
| Inhaltsrechte | enthält keine Inhalte Dritter |
| Altersfreigabe | siehe 3.5 |
| Lizenzvertrag (EULA) | **Eigene EULA**: Text von `nutzungsbedingungen.html` einfügen (P-L6, P-R11) |

**App-Datenschutz → Datenschutzrichtlinie-URL**: Datenschutz-URL aus Abschnitt 1.

### 3.4 App-Datenschutz (Privacy Nutrition Label)

```
Tracking:                              Nein
Datenerhebung:                         Ja
  Käufe – Kaufverlauf                  App-Funktionalität, nicht verknüpft, kein Tracking
  Finanzinfos – Andere Finanzinfos     App-Funktionalität, nicht verknüpft, kein Tracking
                                       (UID-Prüfung VIES)
Alles andere (Fotos, Audio, Kontakte, Standort, Diagnose, Kennungen): nicht erhoben
```

Vision, VisionKit, Spracherkennung auf dem Gerät und iCloud-Sicherung im
Konto der Nutzerin senden dem Anbieter nichts. Unsicher, ob Apple
„Kaufverlauf“ und VIES überhaupt als Erhebung sieht – vorsorglich angegeben
(P-R14, P-R37, P-U4, P-B9). `ios/Runner/PrivacyInfo.xcprivacy` muss dazu
passen (P-D5).

### 3.5 Altersfreigabe

Neuer Fragebogen (Stufen 4+, 9+, 13+, 16+, 18+, Pflicht seit 31.01.2026):
alle Inhalte **Keine**; Medizin/Wellness **Nein**; unbeschränkter Webzugriff
**Nein**; Nutzerinhalte/Chat **Nein**; Werbung **Nein**; KI-Assistent/Chatbot
**Nein**; In-App-Käufe **Ja**; Glücksspiel **Nein**. Erwartet **4+** (P-D60).

### 3.6 Version 0.39.x vorbereiten

**iOS-App → + Version** `0.39.1` (oder die gebaute Version):

| Feld | Eintrag |
|---|---|
| Werbetext (170) | aus `STORE_LISTING.md` „Werbetext“ |
| Beschreibung (4000) | aus `STORE_LISTING.md` „Vollständige Beschreibung“ |
| Keywords (100) | `buchhaltung,belege,rechnung,kassabuch,kleinunternehmer,umsatzsteuer,eür,datev,bmd` |
| Support-URL | aus Abschnitt 1 |
| Marketing-URL | aus Abschnitt 1 (optional) |
| Copyright | `2026 Spirits by JeNiBarb e.U.` |
| Screenshots | 6,9" 1320×2868 (3–10), iPad 13" 2064×2752 |
| In-App-Käufe | die vier Abos **zur Prüfung mit dieser Version** anhaken |

**Neue Version zum ersten Mal mit Abos: die Abos müssen mit der Version
eingereicht werden**, sonst lehnt Apple ab (Guideline 2.1).

### 3.7 Build mit Lizenzprüfung

1. [Workflow „Release“](https://github.com/juergenjesenko-gif/Buchhaltung-/actions/workflows/release.yml)
   → **Run workflow** (derselbe Lauf wie 2.7 genügt, `abo` an). Die IPA
   geht nach TestFlight.
2. Exportkonformität beim Build: `ITSAppUsesNonExemptEncryption = false`
   steht im Build, die Frage erscheint dann nicht. Begründung: AES-256/Argon2id
   nur zum Schutz der eigenen Daten der Nutzerin (Massenmarkt, ausgenommen);
   Frankreich ist kein Markt (P-D9).
3. Build in der Version unter **Build** auswählen.

### 3.8 Hinweise für die Prüfung (App Review Information)

Anmeldung erforderlich: **Nein**. Kontakt: Jürgen Jesenko,
+43 660 3124252, office@jenibarb.com. Notizen:

```
JeNi bucht is a bookkeeping app for sole traders in Austria and Germany
(German UI). No account and no server: all data stays on the device.

How to review without purchase:
1. On first launch tap "Erst ansehen (Demo)" and choose a country.
   The demo shows a fictitious sample company; nothing is saved.
2. Subscriptions: tap "Abo wählen – 14 Tage kostenlos". Four auto-renewable
   subscriptions in one group (Basis < Pro, monthly/yearly), 2-week free
   introductory offer. Prices and terms are loaded from StoreKit; links to
   Terms of Use (EULA) and Privacy Policy are on the subscription screen.
   "Kauf wiederherstellen" and "Abo verwalten" are on the same screen.
3. Promo codes are redeemed via Apple's offer code sheet
   (Abo -> "Promo-Code einlösen").

Network use only on user action: EU VIES VAT check, ECB exchange rates,
loading an invoice from a QR link, user's own mail server for helper devices.
No tracking, no ads, no analytics.

The app does not provide tax advice and is not a cash register.
```

### 3.9 Einreichen

Verfügbarkeit: **Preise und Verfügbarkeit** → App gratis → nur **Österreich**
und **Deutschland**. Freigabe: **Diese Version manuell freigeben** →
**Zur Prüfung hinzufügen → Einreichen**. Optional nach Freigabe **Phased
Release** (7 Tage gestaffelt, nur für Updates wirksam).

---

## 4. Nach der Freigabe

1. Apple-ID der App notieren (App-Informationen → Apple-ID) und an die
   Entwicklung geben: Einlöse-Link `https://apps.apple.com/redeem?ctx=offercodes&id=<Apple-ID>&code=JENIBUCHT2M`
   (P-D32) und Aktualisieren-Hinweis `id0000000000` im Code ersetzen (P-D57) –
   neue App-Version.
2. Auf einem fremden Gerät ohne Testkonto: Store-Eintrag, Preise, Test und
   Kündigungsweg ansehen (P-D46, P-D55).
3. Release Notes: Eintrag der gebauten Version mit Art „Store-Release“ und
   Commit-Hash (`RELEASE_NOTES.md`).
4. Instagram-Codes erst nach P-R40, P-R62, P-R63; Werbetexte in
   `STORE_LISTING.md`.
5. Erste Auszahlung verbuchen (P-S13), Umsatzsteuer zu den Store-Erlösen
   (Reverse Charge Irland, ZM, P-S11).
6. Absturzstatistik wöchentlich ansehen (Play Vitals, Xcode Organizer); kein
   Crash-SDK (L-22.19).

---

## Quellen (abgerufen 2026-10-21)

- Google Play – Zielplattform-Anforderung (API 36 für neue Apps ab 31.08.2026):
  https://developer.android.com/google/play/requirements/target-sdk
- Google Play – Finanzfunktionen-Deklaration:
  https://support.google.com/googleplay/android-developer/answer/13849271
- Google Play – Abos, Basis-Tarife und Angebote:
  https://support.google.com/googleplay/android-developer/answer/12154973
- Google Play – Datensicherheit:
  https://support.google.com/googleplay/android-developer/answer/10787469
- Apple – neue Altersfreigaben 13+/16+/18+ (Entwicklermitteilung 07/2025, Frist 31.01.2026):
  https://9to5mac.com/2025/07/24/apple-notifies-developers-of-new-app-store-age-rating-system/
- Apple – Angebotscodes und Einführungsangebote:
  https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-offer-codes
- Apple – App-Datenschutz: https://developer.apple.com/app-store/app-privacy-details/
- Apple – Exportkonformität:
  https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance
- Apple – DSA-Händlerstatus:
  https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements
- Apple App Review Guidelines 3.1.2 (Abos): https://developer.apple.com/app-store/review/guidelines/
