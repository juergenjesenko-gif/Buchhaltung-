# Release-Playbook

Weg von diesem Repository in den App Store und den Google Play Store.

## Vor dem allerersten Upload: Bundle-ID festlegen

Aktuell steht überall `at.jesenko.buchhaltung`. **Diese ID ist nach dem ersten
Store-Upload unveränderlich** – bei Apple und bei Google. Eine Änderung später
bedeutet eine neue App ohne Bewertungen und ohne bestehende Nutzer.

Entscheide sie also jetzt, idealerweise als umgekehrte Domain, die dir gehört.
Zu ändern an drei Stellen:

```bash
# 1. Android
android/app/build.gradle.kts          # namespace UND applicationId
# 2. iOS
ios/Runner.xcodeproj/project.pbxproj  # PRODUCT_BUNDLE_IDENTIFIER (3 Vorkommen:
                                      # Debug, Release, Profile)
# 3. Release-Workflow
.github/workflows/release.yml         # packageName im Play-Upload-Schritt
```

Am einfachsten neu generieren lassen und die Änderungen übernehmen:

```bash
flutter create --org com.deine-domain --project-name buchhaltung \
  --platforms=android,ios .
```

## Versionierung

`pubspec.yaml` trägt `version: <Name>+<Buildnummer>`, zum Beispiel `0.1.0+1`.

- **Versionsname** (`0.1.0`) ist das, was der Nutzer im Store sieht
- **Buildnummer** (`+1`) muss bei **jedem** Upload steigen und darf **nie**
  zurückgehen. Beide Stores lehnen einen Upload mit bereits verwendeter
  Buildnummer ab.

Der Release-Workflow setzt die Buildnummer aus `github.run_number` – monoton
steigend und übersteht Reruns. Lokal:

```bash
flutter build appbundle --release --build-name=0.2.0 --build-number=17
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
6. Backlog F1 (Backup) umsetzen – vor dem öffentlichen Release, nicht danach
7. Geschlossener Test mit echten Nutzern, mindestens einen Monatsabschluss lang
8. Produktion

## Was noch fehlt

- App-Icon: aktuell das Flutter-Standardicon. `flutter_launcher_icons` ins
  Projekt und ein 1024×1024-Icon liefern.
- Launch-Screen: aktuell der Standard.
- `ios/ExportOptions.plist`: `teamID` eintragen.
- Store-Upload in `.github/workflows/release.yml`: einkommentieren, sobald die
  erste Version manuell veröffentlicht ist.
