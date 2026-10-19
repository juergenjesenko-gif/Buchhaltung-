# App auf dem eigenen iPhone testen (mit Xcode, ohne TestFlight)

**Stand:** 2026-10-15 · Für die Zeit, bis das Apple Developer Program freigeschaltet
ist. Danach kommt TestFlight (Installation per Link, 90 Tage gültig).

**Einschränkungen dieses Wegs:** kostenlos mit deiner Apple-ID, aber die App läuft
nur **7 Tage** und muss dann neu aufgespielt werden (Schritte 9–11 wiederholen).
iCloud-Funktionen sind so nicht nutzbar. Alles andere funktioniert.

Zeitbedarf beim ersten Mal: etwa 60–90 Minuten (vor allem Downloads).
Danach je Update etwa 5 Minuten.

## Einmalig: Werkzeuge installieren

1. **Xcode** aus dem Mac App Store installieren:
   [Xcode im App Store](https://apps.apple.com/at/app/xcode/id497799835)
   (ca. 10 GB). Danach Xcode einmal öffnen und die Zusatzkomponenten
   („Install“) bestätigen; bei der Frage nach Plattformen **iOS** anhaken.
2. **Terminal** öffnen (Spotlight: ⌘ + Leertaste, „Terminal“) und
   **Homebrew** installieren – den Befehl von [brew.sh](https://brew.sh)
   kopieren, einfügen, Enter, Mac-Passwort eingeben.
3. Flutter und CocoaPods installieren (eine Zeile, Enter):
   ```
   brew install --cask flutter && brew install cocoapods
   ```
4. Prüfen (eine Zeile):
   ```
   flutter doctor
   ```
   Bei „Xcode“ sollte ein grünes Häkchen stehen. Fehlt etwas, die
   vorgeschlagenen Befehle ausführen.

## Einmalig: App holen

5. Projekt herunterladen (eine Zeile; GitHub fragt beim ersten Mal nach der
   Anmeldung – im Browser bestätigen):
   ```
   cd ~ && git clone -b claude/agile-accounting-app-mobile-wa5j3h https://github.com/juergenjesenko-gif/Buchhaltung-.git Buchhaltung && cd Buchhaltung && flutter pub get
   ```

## Einmalig: iPhone vorbereiten

6. iPhone mit dem Kabel an den Mac anschließen, auf dem iPhone
   **„Diesem Computer vertrauen“** bestätigen.
7. Auf dem iPhone: **Einstellungen → Datenschutz & Sicherheit →
   Entwicklermodus** einschalten, iPhone neu starten, nach dem Neustart
   „Einschalten“ bestätigen.

## Einmalig: Signierung in Xcode

8. Im Terminal:
   ```
   open ios/Runner.xcworkspace
   ```
   In Xcode links ganz oben **Runner** anklicken → Reiter **Signing &
   Capabilities** →
   - **Team:** „Add an Account…“ → mit deiner Apple-ID anmelden → dann
     „Jürgen Jesenko (Personal Team)“ wählen.
   - **Bundle Identifier:** auf `at.jenibarb.jenibucht.test` ändern
     (die kostenlose Signierung braucht eine eigene Kennung).
   - Steht unter „Signing“ ein roter Fehler zu einer Fähigkeit
     (z. B. „iCloud“), diese Zeile mit dem Minus entfernen – sie geht mit
     dem kostenlosen Weg nicht. Diese Änderung **nicht** committen.

## Jedes Mal: App aufs iPhone spielen

9. Im Terminal im Ordner `Buchhaltung` den neuesten Stand holen:
   ```
   git pull && flutter pub get
   ```
10. App bauen und installieren (iPhone angeschlossen und entsperrt):
    ```
    flutter run --release
    ```
    Beim ersten Mal fragt der Mac nach dem Schlüsselbund-Passwort
    (= Mac-Passwort) – „Immer erlauben“.
11. Nur beim ersten Mal: Startet die App nicht („Nicht vertrauenswürdiger
    Entwickler“), auf dem iPhone **Einstellungen → Allgemein → VPN und
    Geräteverwaltung → deine Apple-ID → Vertrauen**. Dann App antippen.

Danach kannst du das Kabel abziehen; die App bleibt 7 Tage nutzbar.

## Wenn etwas nicht klappt

- **„No devices found“**: iPhone entsperren, Kabel neu stecken, Schritt 6/7 prüfen.
- **Fehler mit „pod install“**: im Terminal `cd ios && pod install && cd ..`,
  dann Schritt 10 wiederholen.
- **„Failed to register bundle identifier“**: in Schritt 8 eine andere Kennung
  wählen, z. B. `at.jenibarb.jenibucht.test2`.
- Alles andere: Screenshot des Fehlers an Claude schicken.

Was du auf dem iPhone besonders prüfen solltest: Face ID bei der App-Sperre,
Kamera und Belegerkennung (Apple-Texterkennung), Kassen-QR, „Öffnen in …“ aus
Mail/Dateien, Termin-Box, Einhandbedienung. Prüfpunkte: P-D17, P-U5, P-X1 in
`SPECIFICATION.md` Abschnitt 14.
