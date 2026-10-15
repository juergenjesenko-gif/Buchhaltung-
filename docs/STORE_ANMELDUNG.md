# Anmeldung bei Google Play und Apple – Formularvorlage

**Stand:** 2026-10-13 · Schritt 3–6 aus `STORE_READINESS.md`. Feldnamen und Abläufe
sind aus öffentlichen Quellen zusammengestellt, nicht live in den Konsolen geprüft;
was die Konsole tatsächlich verlangt, kann abweichen (Prüfpunkte P-R22, P-R23 in
`SPECIFICATION.md` Abschnitt 14).

## Wichtigster Befund vorab

**Apple nimmt ein Einzelunternehmen (auch e.U.) nicht als Organisation auf.**
Laut Apple muss ein Unternehmen eine eigene Rechtsperson sein (Kapitalgesellschaft,
LLC u. ä.). Einzelunternehmen melden sich als **Einzelperson** an; dafür braucht es
**keine D-U-N-S-Nummer**. Folge: Im App Store steht als Verkäufer der persönliche
Name **„Jürgen Jesenko“**, nicht „Spirits by JeNiBarb e.U.“. Nach einer späteren
Umwandlung in eine GmbH lässt sich das Konto auf die GmbH migrieren.
Quelle: [Apple Account Help – D-U-N-S](https://developer.apple.com/support/D-U-N-S/).

**Google Play** kennt Konten für „Privatperson“ und „Organisation“. Ob ein im
Firmenbuch eingetragenes e.U. als Organisation durchgeht, ist nicht gesichert
(P-R22). Unterschied:

| | Privatperson | Organisation |
|---|---|---|
| D-U-N-S | nicht nötig | nötig |
| Vor dem ersten Produktionsrelease | geschlossener Test mit mindestens 12 Testerinnen über 14 Tage | entfällt |
| Im Store angezeigt | Name aus der Verifizierung | Firmenname |
| Gebühr | 25 USD einmalig | 25 USD einmalig |

**Empfehlung:** Google als **Organisation** versuchen (D-U-N-S beantragen, dauert
bis 30 Tage). Lehnt Google ab, Konto als Privatperson anlegen und den 14-Tage-Test
mit 12 Testerinnen einplanen – die Beta mit der Zielgruppe (P-D27) deckt das ohnehin ab.

## Reihenfolge

1. Gemeinsame Stammdaten unten prüfen (einmal, gilt für alle Formulare)
2. ~~D-U-N-S-Nummer beantragen~~ erledigt: **301138760** (Apple-Mail 2026-10-15)
3. Apple Developer Program als Einzelperson – erledigt 2026-10-15 (Bestellung W1795202513, 99 €)
4. Google Play Console – Gebühr bezahlt 2026-10-15 (25 USD), Verifizierung läuft

## Gemeinsame Stammdaten

Bitte jede Zeile prüfen. Alles muss **zeichengenau** mit Firmenbuch und
Impressum übereinstimmen – Abweichungen sind der häufigste Grund für Ablehnungen.

| Feld | Wert | Quelle | Prüfen |
|---|---|---|---|
| Rechtlicher Name (Firma) | Spirits by JeNiBarb e.U. | Firmen-ABC/Firmenbuch | ☐ |
| Inhaber | Jürgen Jesenko | Firmen-ABC | ☐ Vorname/Nachname wie im Ausweis |
| Rechtsform | Eingetragenes Einzelunternehmen (e.U.) | Firmenbuch | ☐ |
| Firmenbuchnummer | FN 643550 y, Landesgericht Klagenfurt | Firmen-ABC | ☐ |
| UID | ATU81604346 | Firmen-ABC | ☐ |
| Anschrift | Sankt Leonhard bei Siebenbrünn 96, 9587 Arnoldstein, Österreich | Firmen-ABC | ☐ |
| Telefon | +43 660 3124252 | Auftraggeberin | ☐ muss erreichbar sein (Verifizierungsanruf/SMS) |
| E-Mail geschäftlich | office@jenibarb.com | Impressum | ☐ Postfach existiert und wird gelesen? |
| Website | https://jenibarb.com | Auftraggeberin | ☐ Seite erreichbar; Impressum dort sinnvoll |
| Gründungsdatum der Rechtsform | 01.01.2025 | Firmen-ABC | ☐ |
| Tätigkeit | Einzelhandel; Entwicklung und Vertrieb von Software | Firmenbuch/Impressum | ☐ |
| Mitarbeiterzahl | 1 | – | ☐ |

## Formular 1: D-U-N-S-Nummer (Dun & Bradstreet)

**So beantragst du sie (kostenlos, über Apples Suchwerkzeug):**

1. [D-U-N-S-Suche von Apple öffnen](https://developer.apple.com/enroll/duns-lookup/)
   und mit der Firmen-Apple-ID (office@jenibarb.com) anmelden.
2. Die Felder mit den Werten aus der Tabelle unten ausfüllen (Englisch,
   zeichengenau) und auf **Check** tippen.
3. **Wird die Firma gefunden:** die angezeigte 9-stellige Nummer notieren –
   fertig. (Österreichische Firmenbuchfirmen haben oft schon eine.)
4. **Wird sie nicht gefunden:** **Submit** wählen. Dun & Bradstreet legt die
   Nummer kostenlos an und meldet sich per E-Mail, meist innerhalb von 5
   Werktagen, manchmal bis 30 Tage. Eventuell ruft D&B zur Bestätigung an
   (+43 660 3124252).
5. Die Nummer an Claude schicken – sie wird hier eingetragen und für das
   Google-Play-Konto verwendet.

Keinen kostenpflichtigen „Express“-Dienst von D&B buchen. Für Apple selbst
brauchst du die Nummer nicht (Anmeldung als Einzelperson, siehe oben).

| Feld | Eintrag |
|---|---|
| Legal Business Name | Spirits by JeNiBarb e.U. |
| Headquarters Address | Sankt Leonhard bei Siebenbrünn 96, 9587 Arnoldstein, Austria |
| Mailing Address | wie oben |
| Phone | +43 660 3124252 |
| Contact (Name, Titel) | Jürgen Jesenko, Inhaber (Owner) |
| Contact E-Mail | office@jenibarb.com |
| Legal Structure | Sole Proprietorship (e.U.) |
| Registration Number | FN 643550 y |
| VAT | ATU81604346 |
| Business Activity | Retail; software development and distribution |
| Employees | 1 |
| Year Started | 2025 |

## Formular 2: Apple Developer Program (Einzelperson)

- **Wo:** https://developer.apple.com/programs/enroll/ → mit Apple-ID anmelden →
  „Enroll as an individual“. Am einfachsten in der **Apple-Developer-App** auf
  iPhone oder Mac (Identität per Ausweis-Scan).
- **Voraussetzung:** Apple-ID mit Zwei-Faktor-Authentifizierung, auf dich
  persönlich ausgestellt (Empfehlung: eigene Apple-ID mit office@jenibarb.com,
  nicht die private).
- **Kosten:** 99 USD pro Jahr. Danach **App Store Small Business Program**
  beantragen (15 % statt 30 % Provision, in App Store Connect).

| Feld | Eintrag |
|---|---|
| Entity type | Individual / Sole Proprietor |
| Legal name | Jürgen Jesenko (wie im Ausweis) |
| Address | Sankt Leonhard bei Siebenbrünn 96, 9587 Arnoldstein, Austria |
| Phone | +43 660 3124252 |
| E-Mail (Apple-ID) | office@jenibarb.com (empfohlen) |

Später in App Store Connect (nach Freischaltung): Steuerformular **W-8BEN**
(Einzelperson, Österreich, DBA AT–USA), Bankverbindung, Vereinbarung „Paid
Apps“, **Trader-Status nach DSA**: „Ich bin Händler“ mit Anschrift, Telefon,
E-Mail wie oben (erscheinen öffentlich im EU-App-Store).

## Formular 3: Google Play Console

- **Wo:** https://play.google.com/console/signup → mit Google-Konto anmelden
  (Empfehlung: eigenes Konto für die Firma, nicht das private).
- **Kosten:** 25 USD einmalig.
- **Ablauf:** Kontotyp wählen → Angaben → Zahlungsprofil (Google Payments) →
  Identitäts-/Unternehmensverifizierung (Ausweis, ggf. Firmenbuchauszug) →
  Gebühr.

| Feld | Eintrag (Organisation) |
|---|---|
| Account type | Organization |
| Organization name | Spirits by JeNiBarb e.U. |
| Organization type | Company / Business |
| Organization size | 1 |
| Organization address | Sankt Leonhard bei Siebenbrünn 96, 9587 Arnoldstein, Austria |
| Organization phone | +43 660 3124252 |
| Organization website | https://jenibarb.com |
| D-U-N-S number | 301138760 (erhalten 2026-10-15) |
| Developer name (öffentlich) | Spirits by JeNiBarb (entschieden 2026-10-13) |
| Contact name | Jürgen Jesenko |
| Contact e-mail (privat, für Google) | office@jenibarb.com |
| Contact phone (privat, für Google) | +43 660 3124252 |
| Developer e-mail (öffentlich im Store) | office@jenibarb.com |
| Developer phone (öffentlich im Store) | +43 660 3124252 |
| Apps that you plan to publish | 1 · Kategorie Finanzen/Business · Buchhaltung für Einzelunternehmen, keine Finanzdienstleistung |

Danach im Zahlungsprofil: Bankverbindung, Steuerangaben (UID ATU81604346), und
unter „Trader-Status“ (EU, DSA) „Händler“ mit denselben öffentlichen Angaben.

## Formular 4: Abos anlegen (ab App-Version 0.14.0)

Die App erwartet genau diese **Produkt-IDs** (Spezifikation FA-13.3, Prüfpunkt
P-D30). Tippfehler = Abo wird nicht gefunden.

| Produkt-ID | Tarif | Zeitraum | Preis inkl. USt (Lastenheft 5.10) | Test |
|---|---|---|---|---|
| `basis_monat` | Basis | 1 Monat | 14,90 € | – |
| `basis_jahr` | Basis | 1 Jahr | 142,90 € | – |
| `pro_monat` | Pro | 1 Monat | 24,90 € | 14 Tage gratis |
| `pro_jahr` | Pro | 1 Jahr | 238,90 € | 14 Tage gratis |

Rabattpreise (12,90 € / 19,90 €) **nicht** als Standardpreis eintragen, nur
später als befristetes Angebot (P-R2).

### Google Play

1. Zahlungsprofil fertig? Bank und Steuer prüfen:
   [payments.google.com](https://payments.google.com/gp/w/home/settings).
2. Einen Build **mit Abo** (0.14.0 oder neuer, Store-Build mit
   `LICENSING=true`) in den internen Test hochladen – Google erlaubt Abos erst,
   wenn ein Build mit Abrechnung hochgeladen ist:
   [Play Console](https://play.google.com/console/developers) → App → Testen →
   Interner Test.
3. App → **Monetarisieren → Abos** → „Abo erstellen“: Produkt-ID wie oben,
   Name „JeNi bucht Basis“ bzw. „JeNi bucht Pro“.
4. Je Abo einen **Basis-Tarif** anlegen: „Automatische Verlängerung“, Zeitraum
   Monat bzw. Jahr (bei Google: ein Produkt je Zeile der Tabelle, je ein
   Basis-Tarif), Preis für Österreich und Deutschland eintragen, aktivieren.
5. Bei `pro_monat` und `pro_jahr`: **Angebot hinzufügen** → Berechtigung
   „Neukunden“ → Phase „Kostenloser Testzeitraum“ 14 Tage → aktivieren.
6. Je Basis-Tarif **Kulanzzeitraum** (Grace Period) auf 7 Tage oder mehr
   stellen.
7. Testkonten eintragen: Play Console → **Einstellungen → Lizenztests** →
   deine Google-Adresse hinzufügen (Testkäufe kosten dann nichts).

### Apple App Store

1. **Vertrag für kostenpflichtige Apps** annehmen, Bank- und Steuerdaten
   eintragen: [App Store Connect → Business](https://appstoreconnect.apple.com/business).
2. [App Store Connect → Apps](https://appstoreconnect.apple.com/apps) → App →
   **Monetarisierung → Abonnements** → Abogruppe „JeNi bucht“ anlegen.
3. In dieser **einen** Gruppe die vier Abos mit den Produkt-IDs oben anlegen;
   Rangfolge: Pro (Stufe 1) über Basis (Stufe 2) – dann wechselt Apple ohne
   Doppelabo.
4. Je Abo Preis für Österreich und Deutschland wählen (Preisstufe nächst
   14,90 € usw.), Anzeigename und Beschreibung auf Deutsch, Prüfungs-Screenshot
   der Abo-Seite der App.
5. Bei beiden Pro-Abos **Einführungsangebot** → „Kostenlos“ → 2 Wochen.
6. In der Abogruppe **Kulanzzeitraum für Abrechnung** (Billing Grace Period)
   einschalten.
7. Sandbox-Testkonto anlegen:
   [Benutzer und Zugriff → Sandbox](https://appstoreconnect.apple.com/access/users/sandbox).

Danach die Testkäufe nach Prüfpunkt **P-D4** durchgehen.

## Was du vorher entscheiden solltest

Entschieden am 2026-10-13:

1. Öffentlicher Entwicklername bei Google: **Spirits by JeNiBarb**.
2. Apple-ID und Google-Konto der Firma laufen auf **office@jenibarb.com** und existieren.
3. Das Postfach office@jenibarb.com existiert und wird gelesen.
