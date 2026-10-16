# Release-Playbook

Weg von diesem Repository in den App Store und den Google Play Store.

## Vor dem allerersten Upload: Bundle-ID wechseln

Entschieden (Lastenheft O-33, 2026-10-15): Store-Kennung
`at.jenibarb.jenibucht`. Bis zur ersten Einreichung bleibt
`at.jesenko.buchhaltung`, damit Testgeräte ohne Neuinstallation aktualisieren.
**Die Kennung ist nach dem ersten Store-Upload unveränderlich.**

Auslöser: unmittelbar vor der ersten Einreichung, in einem eigenen Commit.

1. Auf den Testgeräten eine Datensicherung anlegen (neue Kennung = neue App).
2. `tool/release/bundle_id_wechsel.sh` im Repository-Wurzelordner ausführen.
   Es ändert Android `applicationId`/`namespace`, verschiebt das Kotlin-Paket,
   setzt iOS `PRODUCT_BUNDLE_IDENTIFIER` und den Play-`packageName` in
   `release.yml`. Der iCloud-Container `iCloud.<Bundle-ID>` folgt von selbst.
3. Die ausgegebenen Restfundstellen in der Doku nachführen, `flutter analyze`,
   `flutter test`.
4. Im Apple Developer Portal App-ID und iCloud-Container für die neue Kennung
   anlegen (P-B13), in der Play Console die App mit der neuen Kennung.

## Secrets für den Release-Workflow

`.github/workflows/release.yml` wird von Hand gestartet (Actions → Release →
Run workflow). Secrets anlegen unter
<https://github.com/juergenjesenko-gif/Buchhaltung-/settings/secrets/actions>:

| Secret | Inhalt | Pflicht |
|---|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 upload-keystore.jks` | Android |
| `ANDROID_STORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS` | Kennwörter und Alias des Upload-Schlüssels | Android |
| `PLAY_SERVICE_ACCOUNT_JSON` | JSON des Play-Dienstkontos | optional: ohne Secret kein automatischer Upload |
| `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect → Benutzer und Zugriff → Integrationen → API-Schlüssel (Rolle Admin) | iOS signiert |
| `APP_STORE_CONNECT_KEY_BASE64` | `base64 -i AuthKey_<ID>.p8` | iOS signiert |
| `APPLE_TEAM_ID` | Membership Details im Developer Portal | iOS signiert |

Ergebnis: Android `JeNi-bucht-<Version>-build-<Nr>.aab` als ungezipptes
Artefakt, bei vorhandenem Dienstkonto zusätzlich als **Entwurf** im gewählten
Play-Track (der erste Upload muss von Hand erfolgen). iOS mit allen vier
Apple-Secrets: signierte IPA (Xcode-Cloud-Signierung über den API-Schlüssel,
kein Zertifikat im Repository) und Upload zu TestFlight; ohne Secrets ein
unsigniertes Archiv zur Kontrolle, dass der Store-Build kompiliert.
Keystore, `.p8` und `key.properties` werden nie committet.

## Versionierung

`pubspec.yaml` trägt `version: <Name>+<Buildnummer>`, zum Beispiel `0.1.0+1`.

- **Versionsname** (`0.1.0`) ist das, was der Nutzer im Store sieht. Schema (Entscheidung Auftraggeberin 2026-10-12): `0.x.y` bis zum Store-Start, `1.0.0` ist die erste Store-Version; zweite Stelle bei neuen Funktionen, dritte bei reinen Fehlerbehebungen
- **Buildnummer** (`+1`) muss bei **jedem** Upload steigen und darf **nie**
  zurückgehen. Beide Stores lehnen einen Upload mit bereits verwendeter
  Buildnummer ab.

Auch jeder Testbuild der CI trägt seit 2026-10-12 `--build-number=github.run_number`; das Artefakt ist ungezippt die arm64-APK `JeNi-bucht-<Version>-build-<Nummer>.apk`. Testbuilds bekommen seit 2026-10-14 **keinen Git-Tag** mehr; die Release Notes nennen den Commit-Hash direkt (Entscheidung Auftraggeber). Für Store-Releases ab 1.0.0 kann ein Tag über GitHub Releases gesetzt werden. Die CI kann Tags nicht setzen: GitHub verweigert dem CI-Token Tags auf Commits mit Workflow-Änderungen (fehlende `workflows`-Berechtigung, Versuch vom 2026-10-12), und die Entwicklungsumgebung darf nur auf den Entwicklungsbranch pushen. Der Release-Workflow setzt die Buildnummer aus `github.run_number` – monoton
steigend und übersteht Reruns. Lokal:

```bash
flutter build appbundle --release --build-name=0.2.0 --build-number=17
```

### Testschlüssel für Test-APKs

Die CI signiert Test-APKs mit einem eigenen **Testschlüssel** aus den Secrets
`TEST_KEYSTORE_BASE64`, `TEST_KEYSTORE_PASSWORD`, `TEST_KEY_ALIAS` (angelegt
2026-10-12, SHA-256 `2B:99:5A:26:…:D6:21`, gültig 10 Jahre). Er ist **nicht**
der Upload-Schlüssel für Google Play und darf dafür nie verwendet werden; der
Store-Release bekommt einen eigenen Schlüssel und einen eigenen Workflow.

### Release Notes

Vor jedem Build, der das Haus verlässt (Testbuild, TestFlight, interner Track,
Store), wird in `docs/RELEASE_NOTES.md` ein Eintrag angelegt: Abschnitt
*Unveröffentlicht* übernehmen, Pflichtfelder ausfüllen, `version` in
`pubspec.yaml` im selben Commit erhöhen. Setzt die CI eine abweichende
Buildnummer (`github.run_number`), wird sie im Feld *Prüfung* mit Link zum
CI-Lauf vermerkt. Testbuilds bekommen keinen Git-Tag (Entscheidung Auftraggeber
2026-10-14), der Eintrag nennt den Commit-Hash. Nur für Store-Releases ab 1.0.0
nach dem Build, z. B. über GitHub Releases:

```bash
git tag -a v1.0.0+N -m "Release 1.0.0+N, siehe docs/RELEASE_NOTES.md"
git push origin v1.0.0+N
```

## Android: Google Play

### Einmalig: Upload-Keystore

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Dann `android/key.properties` anlegen (steht in `.gitignore`, kommt **nie** ins
Repository):

```properties
storePassword=<dein Store-Passwort>
keyPassword=<dein Key-Passwort>
keyAlias=upload
storeFile=/absoluter/pfad/zu/upload-keystore.jks
```

> **Den Keystore und die Passwörter sichern.** Bei Verlust kann man ohne
> Play-App-Signing-Reset keine Updates mehr veröffentlichen. Ein Passwortmanager
> und eine Offline-Kopie sind hier keine Übervorsicht.

Für CI: `base64 -w0 ~/upload-keystore.jks` und als Secret
`ANDROID_KEYSTORE_BASE64` ablegen, dazu `ANDROID_STORE_PASSWORD`,
`ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`.

### Bauen

```bash
flutter build appbundle --release
# -> build/app/outputs/bundle/release/app-release.aab
```

Google Play verlangt ein **App Bundle** (.aab), kein APK.

### Play Console – Checkliste

- [ ] Entwicklerkonto (25 $ einmalig)
- [ ] **Identitätsprüfung** – seit 2023 Pflicht, dauert Tage bis Wochen. Früh anfangen.
- [ ] App anlegen, Sprache Deutsch, Kategorie *Finanzen*
- [ ] **Datensicherheitsformular**: Die App sammelt keine Daten und überträgt
      keine. Auto-Backup ist deaktiviert (`data_extraction_rules.xml`) – die
      Angabe „keine Datenübertragung" ist damit korrekt und belegbar.
- [ ] Datenschutzerklärung als **öffentliche URL** – Pflichtfeld, auch bei einer
      App, die nichts sendet. Vorlage: `docs/PRIVACY.md`
- [ ] Zielgruppe: keine Kinder
- [ ] Inhaltsbewertung (Fragebogen)
- [ ] Store-Einträge: siehe `docs/STORE_LISTING.md`
- [ ] Grafiken: Icon 512×512, Feature-Grafik 1024×500, mindestens 2 Screenshots
      pro Formfaktor
- [ ] **Erst internen Test**, dann geschlossener Test, dann Produktion. Der erste
      Upload muss manuell erfolgen; die API akzeptiert ihn nicht.

## iOS: App Store

### Voraussetzungen

- Apple Developer Program (99 $/Jahr)
- macOS mit Xcode – **iOS-Builds gehen nicht unter Linux.** Wenn du keinen Mac
  hast, macht der `macos-latest`-Runner in GitHub Actions das für dich.

### Bauen

```bash
flutter build ipa --release
# -> build/ios/ipa/*.ipa
# Danach: Transporter-App oder
xcrun altool --upload-app -t ios -f build/ios/ipa/buchhaltung.ipa \
  --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
```

`ios/ExportOptions.plist` liegt im Repository und muss auf dein Team angepasst
werden (`teamID`).

### App Store Connect – Checkliste

- [ ] App-ID im Developer-Portal registrieren
- [ ] App in App Store Connect anlegen (Bundle-ID muss übereinstimmen)
- [ ] **Berechtigungstexte** sind gesetzt (`Info.plist`:
      `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`). Ohne
      aussagekräftige Begründung folgt Ablehnung – „wird benötigt" genügt nicht.
- [ ] `ITSAppUsesNonExemptEncryption = false` ist gesetzt (die App nutzt keine
      eigene Verschlüsselung), das erspart die Exportgenehmigung
- [ ] Datenschutzerklärung-URL
- [ ] **App-Datenschutz-Angaben** („App Privacy"): keine Datenerhebung
- [ ] Screenshots: 6,7" iPhone und 6,5" iPhone sind Pflicht, iPad wenn du iPad
      unterstützt
- [ ] Erst über **TestFlight** verteilen, dann zur Prüfung einreichen

### Womit die Prüfung bei Finanz-Apps gern hängt

1. **Fehlende oder schwache Berechtigungstexte.** Erledigt, siehe oben.
2. **Guideline 2.1 – Vollständigkeit.** Die App muss ohne Konto sofort benutzbar
      sein. Ist sie: kein Login, kein Server.
3. **Kein Hinweis auf Datenverlust.** Eine Buchhaltungsapp ohne Backup, die das
      nicht sagt, ist ein Ablehnungsgrund. Die Einstellungen sagen es; nach
      Umsetzung von Backlog F1 ist der Punkt erledigt.
4. **Steuerliche Zusicherungen.** Nirgends behaupten, die App erfülle
      Aufzeichnungspflichten oder ersetze eine Steuerberatung. Der Hinweistext in
      den Einstellungen ist genau dafür da.

## Reihenfolge, die sich bewährt hat

1. Bundle-ID endgültig festlegen (siehe oben) – **bevor** irgendetwas hochgeladen wird
2. Beide Entwicklerkonten anlegen, Identitätsprüfung bei Google starten
3. Datenschutzerklärung veröffentlichen (GitHub Pages genügt)
4. Icon und Screenshots erstellen
5. Android intern testen → iOS über TestFlight testen
6. ~~Backlog F1 (Backup) umsetzen~~ – erledigt seit 0.2.0 (manuelle und automatische Sicherung)
7. Geschlossener Test mit echten Nutzern, mindestens einen Monatsabschluss lang
8. Produktion

## Was noch fehlt

- App-Icon: aktuell das Flutter-Standardicon. `flutter_launcher_icons` ins
  Projekt und ein 1024×1024-Icon liefern.
- Launch-Screen: aktuell der Standard.
- `ios/ExportOptions.plist`: `teamID` eintragen.
- Store-Upload in `.github/workflows/release.yml`: einkommentieren, sobald die
  erste Version manuell veröffentlicht ist.
