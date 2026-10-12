# Store-Reife – Checkliste bis zur Einreichung

**Stand:** 2026-10-12 · Grundlage: Prüfinstanzen Softwareentwickler, Rechtsanwalt,
Steuerberater vom 2026-10-12. Store-Regeln aus Fachwissen, nicht live in den
Konsolen geprüft; reale Prüfpunkte stehen in `SPECIFICATION.md` Abschnitt 14.

Anforderungen dazu: Lastenheft 5.10 (Abonnement), 5.22 (Lizenz und Bezahlung),
5.17 (Recht). Ablauf von Build und Signierung: `RELEASE_PLAYBOOK.md`.

## Reihenfolge

| # | Schritt | Wer | Dauer | Status |
|---|---|---|---|---|
| 1 | **Rechtsform festlegen** (O-26): Einzelunternehmen oder GmbH – bestimmt Kontoinhaber, Store-Name, Steuer | Auftraggeber mit Steuerberatung | – | offen |
| 2 | **Öffentliche Händleradresse und Telefon** (DSA „Trader“-Angaben, erscheinen im EU-Store; Postfach reicht nicht) | Auftraggeber | – | offen (P-R10) |
| 3 | **D-U-N-S-Nummer** beantragen (kostenlos) | Auftraggeber | 1–4 Wochen | offen |
| 4 | **Google Play Organisationskonto** (25 USD einmalig) – erspart den Pflichttest mit 12 Testern über 14 Tage, den private Konten brauchen | Auftraggeber | Tage bis Wochen | offen |
| 5 | **Apple Developer Program als Organisation** (99 USD/Jahr); Small Business Program anmelden (15 % Provision) | Auftraggeber | Tage bis Wochen | offen |
| 6 | **UID-Nummer** des Anbieters, Steuerformulare (W-8BEN bzw. W-8BEN-E, DBA AT-USA 0 %), Bankdaten in beiden Konsolen | Auftraggeber mit Steuerberatung | – | offen (P-S11, P-S13) |
| 7 | **Markenrecherche und -anmeldung** (O-25), dann Domain und Produktseite (L-17.12) | Markenanwältin | Wochen | offen (P-R7) |
| 8 | **Rechtstexte**: Impressum, Datenschutzerklärung, Nutzungsbedingungen als eigene EULA (auch bei Apple hinterlegt), Support-Kontakt | Anwältin | – | offen (P-L1, P-R11) |
| 9 | Technik Store-Reife (unten) | Entwicklung | 7–12 PT | offen |
| 10 | Lizenzmanager und Abo-Seite (Lastenheft 5.22) | Entwicklung | 10–13 PT | offen |
| 11 | Formulare: Data Safety, App Privacy Labels, Altersfreigabe (IARC/Apple, Ergebnis voraussichtlich ab 0/4+), Zielgruppe 18+, Finanz-App-Deklaration („Buchhaltungswerkzeug, keine Finanzdienstleistung“), Export Compliance | Entwicklung, Anwältin | 1–2 PT | offen (P-R14, P-D9) |
| 12 | Store-Texte und Screenshots gegen die Negativliste prüfen (`STORE_LISTING.md`) | Anwältin | – | offen (P-R13) |
| 13 | Interner Test (Play), TestFlight, Sandbox-Käufe auf echten Geräten | Auftraggeber, Entwicklung | 2–3 PT | offen |
| 14 | Einreichung | – | Prüfung 1–7 Tage | – |

Gesamtaufwand Entwicklung etwa **26–34 Personentage**, plus 2–6 Wochen Wartezeit
für Konten und Prüfungen. Schritte 1–8 laufen parallel zur Entwicklung.

## Technik: Endzustand für die Einreichung

| Punkt | Heute | Ziel |
|---|---|---|
| Android-Format | APK aus der CI | **AAB** aus eigenem Release-Workflow (Tag `v*`), signiert mit Upload-Key; Play App Signing |
| Signierung | Debug- bzw. Testschlüssel | Release-Workflow bricht ab, wenn kein Upload-Key da ist |
| targetSdk | Flutter-Vorgabe | fest eingetragen, aktueller Play-Stichtag (2026 voraussichtlich API 36) |
| iOS-Build | ohne Signierung | Fastlane (`match`, `pilot`) auf macOS-Runner, Upload nach TestFlight |
| Privacy Manifest | fehlt | `ios/Runner/PrivacyInfo.xcprivacy` mit den Required-Reason-APIs |
| Export Compliance | `ITSAppUsesNonExemptEncryption = false` | **klären**: die App verschlüsselt selbst (AES-256, Argon2id). Voraussichtlich Standardverfahren, ausgenommen; Frankreich ggf. Erklärung (P-D9) |
| Store-Metadaten | `docs/STORE_LISTING.md` | zusätzlich `fastlane/metadata/{android,ios}/de-DE`, abgeglichen mit STORE_LISTING |
| Crash-Berichte | keine | **kein Crash-SDK**; Absturzstatistik der Stores plus freiwilliger Fehlerbericht per E-Mail |
| Lokalisierung | Texte im Code | Sprachdateien (L-13.8), Store-Einträge nur DE/AT |
| Unfertiges | – | nicht ausliefern statt verstecken (Apple 2.1); Stufen über Build-Schalter |
| Rechtliches in der App | Bestätigungen (FA-1.10) | Menü „Rechtliches“: Impressum, Datenschutz, Nutzungsbedingungen, Support, „keine Steuerberatung“ – auch offline |
| Prüferzugang | – | kein Login nötig; Hinweis in den Review Notes, Lizenztester eintragen |

## Was bewusst nicht gemacht wird

- **Kein Direktverkauf und keine DMA-Alternativen** in Stufe A und B: Ersparnis
  gegenüber 15 % Provision gering, dafür eigener Zahlungsdienstleister,
  Rechnungen, Widerrufsbelehrung, Kündigungsbutton, OSS und ein Lizenzserver
  (Bruch mit O-29).
- **Kein RevenueCat** oder anderes Abrechnungs-SDK: Kauf- und Geräte-IDs flössen
  in die USA.
- **Keine Werbung mit Vorsteuerabzug** aus der Store-Quittung, solange P-S12
  offen ist.
