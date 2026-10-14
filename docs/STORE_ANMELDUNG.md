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
2. D-U-N-S-Nummer beantragen (nur für Google Organisation)
3. Apple Developer Program als Einzelperson
4. Google Play Console (nach Erhalt der D-U-N-S-Nummer)

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

- **Wo:** über Apple nicht nötig. Für Google direkt bei Dun & Bradstreet Austria
  (dnb.com → „D-U-N-S Number“ → Österreich) oder die Suche auf
  https://developer.apple.com/enroll/duns-lookup/ (zeigt, ob schon eine Nummer
  existiert – österreichische Firmenbuchfirmen haben oft schon eine).
- **Kosten:** kostenlos (nicht den kostenpflichtigen Expressdienst wählen).
- **Dauer:** bis 30 Tage.

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
| D-U-N-S number | (nach Erhalt) |
| Developer name (öffentlich) | Spirits by JeNiBarb (entschieden 2026-10-13) |
| Contact name | Jürgen Jesenko |
| Contact e-mail (privat, für Google) | office@jenibarb.com |
| Contact phone (privat, für Google) | +43 660 3124252 |
| Developer e-mail (öffentlich im Store) | office@jenibarb.com |
| Developer phone (öffentlich im Store) | +43 660 3124252 |
| Apps that you plan to publish | 1 · Kategorie Finanzen/Business · Buchhaltung für Einzelunternehmen, keine Finanzdienstleistung |

Danach im Zahlungsprofil: Bankverbindung, Steuerangaben (UID ATU81604346), und
unter „Trader-Status“ (EU, DSA) „Händler“ mit denselben öffentlichen Angaben.

## Was du vorher entscheiden solltest

Entschieden am 2026-10-13:

1. Öffentlicher Entwicklername bei Google: **Spirits by JeNiBarb**.
2. Apple-ID und Google-Konto der Firma laufen auf **office@jenibarb.com** und existieren.
3. Das Postfach office@jenibarb.com existiert und wird gelesen.
