# Die Android-Version testen

Drei Wege, sortiert nach Aufwand. Wenn du nur die App auf deinem Telefon sehen
willst, nimm Weg 1 – der braucht auf deinem Rechner gar nichts.

---

## Weg 1: APK aus der CI herunterladen

Bei jedem Push baut GitHub Actions ein installierbares APK. Du brauchst nur ein
Android-Telefon und einen Browser.

### 1. APK herunterladen

1. Öffne **[Actions](https://github.com/juergenjesenko-gif/Buchhaltung-/actions)**
   im Repository
2. Klick auf den obersten Lauf mit grünem Häkchen
3. Ganz unten unter **Artifacts** liegt **`test-apk`** – anklicken, ZIP wird
   heruntergeladen
4. ZIP entpacken. Darin zwei Dateien:
   - **`app-arm64-v8a-release.apk`** ← die nimm. Passt auf jedes Telefon ab etwa 2017.
   - `app-armeabi-v7a-release.apk` – nur für sehr alte Geräte

> Am bequemsten machst du das direkt am Telefon: Actions-Seite im Handy-Browser
> öffnen, Artefakt herunterladen, entpacken (die Dateien-App von Android kann
> das), APK antippen.

Artefakte werden nach 14 Tagen automatisch gelöscht. Danach einfach den neuesten
Lauf nehmen oder einen leeren Commit pushen.

### 2. Installieren

Android blockiert Apps aus unbekannten Quellen erst einmal – das ist eine
Sicherheitsfunktion, kein Fehler.

1. APK im Dateimanager antippen
2. Android fragt: *„Aus dieser Quelle dürfen keine Apps installiert werden"* →
   **Einstellungen** antippen
3. Bei der Dateimanager- bzw. Browser-App **„Apps installieren erlauben"**
   aktivieren
4. Zurück und Installation bestätigen
5. Play Protect meldet unter Umständen eine unbekannte App → **Trotzdem
   installieren**

Danach findest du **Buchhaltung** im App-Menü.

### Was du beim Testen wissen solltest

- Das APK ist mit **Debug-Schlüsseln signiert**. Auf dem Telefon merkst du das
  nicht; bei Google Play einreichen kannst du es nicht. Das ist Absicht – siehe
  [`RELEASE_PLAYBOOK.md`](RELEASE_PLAYBOOK.md).
- Es ist ein **Release-Build**: volle Geschwindigkeit, kein Debug-Banner, R8
  aktiv. Was du siehst, entspricht dem späteren Verhalten.
- **Es gibt noch kein Backup.** Wenn du testest und die App später neu
  installierst, sind die Testdaten weg. Nimm für Tests erfundene Daten.
- Eine Neuinstallation über ein vorhandenes APK behält die Daten. Willst du das
  Onboarding erneut sehen, deinstalliere die App vorher.

---

## Weg 2: Lokal mit Flutter entwickeln und testen

Wenn du selbst am Code arbeiten oder Änderungen sofort sehen willst.

### Einmalig einrichten

1. **Flutter SDK** installieren: <https://docs.flutter.dev/get-started/install>
   Version 3.47 oder neuer.
2. **Android Studio** installieren. Es bringt das Android SDK mit, das Flutter
   zum Bauen braucht. Beim ersten Start durch den Setup-Assistenten gehen.
3. Prüfen, ob alles steht:
   ```bash
   flutter doctor
   ```
   Die Zeilen *Flutter* und *Android toolchain* brauchen ein Häkchen. Xcode und
   Chrome kannst du ignorieren, solange du nur Android testest.

### Auf einem echten Telefon

Ein echtes Gerät ist dem Emulator vorzuziehen – vor allem, weil die Kamera für
die Belegerfassung im Emulator nur eine Attrappe ist.

1. Am Telefon **Entwickleroptionen** freischalten: *Einstellungen → Über das
   Telefon → siebenmal auf die Build-Nummer tippen*
2. In den Entwickleroptionen **USB-Debugging** einschalten
3. Per USB anschließen, am Telefon den Zugriff erlauben
4. Im Projektverzeichnis:
   ```bash
   flutter devices          # Telefon muss auftauchen
   flutter run              # baut und startet
   ```

Während `flutter run` läuft:

| Taste | Wirkung |
|---|---|
| `r` | Hot Reload – Änderung sofort sichtbar, Zustand bleibt |
| `R` | Hot Restart – App startet neu, Zustand weg |
| `q` | Beenden |

Für einen realistischen Geschwindigkeitseindruck:
```bash
flutter run --release
```

### Im Emulator

```bash
flutter emulators                          # verfügbare Emulatoren
flutter emulators --launch <name>          # starten
flutter run
```

Der Emulator genügt für Formulare, Berechnungen und die Rechnungs-PDF. Für die
Belegerfassung mit Kamera nimm ein echtes Gerät.

### APK selbst bauen

```bash
flutter build apk --release --split-per-abi
# -> build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Auf ein angeschlossenes Telefon schieben:
```bash
flutter install
```

---

## Weg 3: Verteilung an Testnutzer

Sobald andere Leute testen sollen, ist das Herumschicken von APKs unpraktisch.
Zwei Möglichkeiten:

**Firebase App Distribution** – kostenlos, Tester bekommen eine Einladung per
Mail und Updates automatisch. Kein Google-Play-Konto nötig. Für eine
Handvoll Tester der einfachste Weg.

**Google Play, interner Test** – Tester installieren aus dem Play Store, du
testest gleichzeitig den echten Veröffentlichungsweg. Braucht ein
Entwicklerkonto (25 $ einmalig) samt Identitätsprüfung und einen mit deinem
eigenen Upload-Key signierten Build. Siehe
[`RELEASE_PLAYBOOK.md`](RELEASE_PLAYBOOK.md).

---

## Was du beim ersten Durchgang prüfen solltest

Ein Vorschlag für einen sinnvollen Testlauf – er deckt jede Funktion aus Sprint 1
ab und dauert etwa zehn Minuten:

1. **Onboarding** – Firma anlegen, Land Österreich, Kleinunternehmer **an**,
   Anschrift vollständig, IBAN eintragen
2. **Ausgabe erfassen** – Beleg fotografieren, `12,50` eintippen, prüfen dass die
   USt-Aufschlüsselung erscheint, Beschreibung setzen, speichern
3. **Einnahme erfassen** – über das grüne Symbol, z. B. `1.200,00`
4. **Übersicht** – stimmen Einnahmen, Ausgaben, Ergebnis? Erscheint die
   Kleinunternehmer-Ampel?
5. **Beleg suchen** – im Bereich Belege nach der Beschreibung suchen
6. **Kunde anlegen** mit vollständiger Anschrift
7. **Rechnung schreiben** – zwei Positionen, eine mit Menge `1,5`. Prüfen, dass
   die Checkliste greift, wenn du das Leistungsdatum entfernst.
8. **Rechnung ausstellen** und **PDF teilen** – im PDF prüfen: fortlaufende
   Nummer, beide Anschriften, Leistungsdatum, und dass **keine
   Umsatzsteuerspalte** erscheint, dafür der Kleinunternehmer-Hinweis
9. **Auf „bezahlt" setzen**
10. **Export** – Monat wählen, Belegliste-CSV teilen, in einer Tabellenkalkulation
    öffnen: stimmen Umlaute und Beträge?
11. **Stammdaten ändern** – Kleinunternehmer **aus**, UID eintragen. Neue
    Rechnung schreiben: jetzt muss die Umsatzsteuer erscheinen. Die alte Rechnung
    muss unverändert bleiben.
12. **Land auf Deutschland** umstellen – Steuersätze müssen auf 19/7/0 wechseln,
    das Feld muss „USt-IdNr." heißen

Was dabei auffällt, gehört ins Backlog. Wenn etwas rechnerisch falsch ist,
schreib den genauen Betrag und den Steuersatz dazu – damit lässt sich ein Test
schreiben, der den Fehler festnagelt.

---

## Automatisierte Tests

Ohne Telefon, in Sekunden:

```bash
flutter test           # 109 Tests
flutter analyze        # statische Analyse
```

Was die Tests abdecken: Umsatzsteuerrechnung über alle Sätze und tausende
Beträge, Rechnungsnummern, Grenzwertüberwachung für beide Länder, alle
Exportformate byteweise, PDF-Erzeugung, und der Abgleich der Spezifikation mit
dem Code.

Was sie **nicht** abdecken: die Oberfläche. Es gibt noch keine Widget-Tests. Ob
ein Knopf am richtigen Platz sitzt und ob sich die App gut anfühlt, findest du
nur auf einem echten Gerät heraus.
