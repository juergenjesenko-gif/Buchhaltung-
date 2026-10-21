# Store-Reife – Checkliste bis zur Einreichung

**Stand:** 2026-10-21 (App 0.39.1; Schritte zum Start in `LAUNCH.md`) · Grundlage: Prüfinstanzen Softwareentwickler, Rechtsanwalt,
Steuerberater vom 2026-10-12. Store-Regeln aus Fachwissen, nicht live in den
Konsolen geprüft; reale Prüfpunkte stehen in `SPECIFICATION.md` Abschnitt 14.

Anforderungen dazu: Lastenheft 5.10 (Abonnement), 5.22 (Lizenz und Bezahlung),
5.17 (Recht). Ablauf von Build und Signierung: `RELEASE_PLAYBOOK.md`.

## Reihenfolge

| # | Schritt | Wer | Dauer | Status |
|---|---|---|---|---|
| 1 | **Rechtsform festlegen** (O-26): Einzelunternehmen oder GmbH – bestimmt Kontoinhaber, Store-Name, Steuer | Auftraggeber mit Steuerberatung | – | entschieden: Spirits by JeNiBarb e.U., FN 643550 y, ATU81604346; später GmbH |
| 2 | **Öffentliche Händleradresse und Telefon** (DSA „Trader“-Angaben, erscheinen im EU-Store; Postfach reicht nicht) | Auftraggeber | – | festgelegt: Anschrift Arnoldstein, Telefon +43 660 3124252 (P-R10) |
| 3 | **D-U-N-S-Nummer** beantragen (kostenlos; nur für Google-Organisationskonto nötig, Formular in `STORE_ANMELDUNG.md`) | Auftraggeber | 1–4 Wochen | erledigt: 301138760 (2026-10-15) |
| 4 | **Google Play Organisationskonto** (25 USD einmalig) – erspart den Pflichttest mit 12 Testern über 14 Tage, den private Konten brauchen | Auftraggeber | Tage bis Wochen | erledigt: Organisationskonto aktiv, interner Test läuft (2026-10-21) |
| 5 | **Apple Developer Program als Einzelperson** (99 USD/Jahr; ein e.U. gilt bei Apple nicht als Organisation, P-R23, Formular in `STORE_ANMELDUNG.md`); Small Business Program anmelden (15 % Provision) | Auftraggeber | Tage bis Wochen | erledigt: Einzelkonto Team 544URFBCH5, TestFlight läuft; Small Business Program offen (LAUNCH 3.1) |
| 6 | **UID-Nummer** des Anbieters, Steuerformulare (W-8BEN bzw. W-8BEN-E, DBA AT-USA 0 %), Bankdaten in beiden Konsolen | Auftraggeber mit Steuerberatung | – | offen, Schritte in LAUNCH 2.1/3.1 (P-S11, P-S13) |
| 7 | **Markenrecherche und -anmeldung** (O-25), dann Domain und Produktseite (L-17.12) | Markenanwältin | Wochen | Recherche ohne Befund, Name „JeNi bucht“ festgelegt 2026-10-15 (P-R7 erledigt); Markenanmeldung offen; Produktseite gebaut (`docs/site/`), Veröffentlichung offen (P-D59) |
| 8 | **Rechtstexte**: Impressum, Datenschutzerklärung, Nutzungsbedingungen als eigene EULA (auch bei Apple hinterlegt), Support-Kontakt | Anwältin | – | Entwürfe in `docs/legal/`, Platzhalter und Prüfung offen, Datenschutz veraltet (P-L1, P-L4–L11, P-R11, P-R68) |
| 9 | Technik Store-Reife (unten) | Entwicklung | 7–12 PT | weitgehend erledigt, siehe Tabelle unten |
| 10 | Lizenzmanager und Abo-Seite (Lastenheft 5.22) | Entwicklung | 10–13 PT | gebaut (seit 0.14.0, `lib/services/licensing/`, Build-Schalter `LICENSING`); Store-Produkte noch nicht angelegt (P-D30) |
| 11 | Formulare: Data Safety, App Privacy Labels, Altersfreigabe (IARC/Apple, Ergebnis voraussichtlich ab 0/4+), Zielgruppe 18+, Finanz-App-Deklaration („Buchhaltungswerkzeug, keine Finanzdienstleistung“), Export Compliance | Entwicklung, Anwältin | 1–2 PT | Antworten vorbereitet in LAUNCH 2.3–2.5, 3.4, 3.5; in den Konsolen offen (P-R14, P-D9, P-D60) |
| 12 | Store-Texte und Screenshots gegen die Negativliste prüfen (`STORE_LISTING.md`) | Anwältin | – | Texte auf 0.39.x abgeglichen und Limits geprüft 2026-10-21; Anwältin offen (P-R13) |
| 13 | Interner Test (Play), TestFlight, Sandbox-Käufe auf echten Geräten | Auftraggeber, Entwicklung | 2–3 PT | interner Test (Play) und TestFlight laufen mit Testbuild ohne Abo; Sandbox-Käufe offen (P-D4) |
| 13a | **Haftpflicht abschließen** (O-26, P-R8): Vermögensschaden- und Produkthaftpflicht; verschoben bis Launch (Entscheidung 2026-10-15) | Auftraggeberin mit Versicherungsmaklerin | – | verschoben bis Launch – jetzt fällig (LAUNCH Ampel 12) |
| 13b | **Bundle-ID für den Store festlegen** (O-33, Vorschlag `at.jenibarb.jenibucht`); ein Wechsel nach der ersten Einreichung ist nicht mehr möglich | Auftraggeberin, Entwicklung | 0,5 PT | erledigt: `at.jenibarb.jenibucht` seit 0.26.0 (2026-10-19) |
| 14 | Einreichung | – | Prüfung 1–7 Tage | offen, Ampel in LAUNCH Abschnitt 0 |

Gesamtaufwand Entwicklung etwa **26–34 Personentage**, plus 2–6 Wochen Wartezeit
für Konten und Prüfungen. Schritte 1–8 laufen parallel zur Entwicklung.

## Technik: Endzustand für die Einreichung

| Punkt | Heute | Ziel |
|---|---|---|
| Android-Format | erledigt: `release.yml` baut signiertes AAB und lädt es als Entwurf in den gewählten Track (Eingaben `track`, `abo`, `version`) | **AAB** aus dem Release-Workflow, signiert mit Upload-Key; Play App Signing |
| Signierung | Upload-Key über Secrets (P-B16) | Release-Workflow bricht ab, wenn kein Upload-Key da ist |
| targetSdk | `flutter.targetSdkVersion` – ≥ 36 im AAB bestätigen (P-D6) | fest eingetragen, aktueller Play-Stichtag (2026 voraussichtlich API 36) |
| iOS-Build | `release.yml` signiert die IPA und lädt nach TestFlight (statt Fastlane) | Fastlane (`match`, `pilot`) auf macOS-Runner, Upload nach TestFlight |
| Privacy Manifest | vorhanden (`ios/Runner/PrivacyInfo.xcprivacy`, seit 0.16.0), Abgleich P-D5 | `ios/Runner/PrivacyInfo.xcprivacy` mit den Required-Reason-APIs |
| Export Compliance | `ITSAppUsesNonExemptEncryption = false` | **klären**: die App verschlüsselt selbst (AES-256, Argon2id). Voraussichtlich Standardverfahren, ausgenommen; Frankreich ggf. Erklärung (P-D9) |
| Store-Metadaten | `docs/STORE_LISTING.md` | zusätzlich `fastlane/metadata/{android,ios}/de-DE`, abgeglichen mit STORE_LISTING |
| Crash-Berichte | keine | **kein Crash-SDK**; Absturzstatistik der Stores plus freiwilliger Fehlerbericht per E-Mail |
| Lokalisierung | Texte im Code | Sprachdateien (L-13.8), Store-Einträge nur DE/AT |
| Unfertiges | – | nicht ausliefern statt verstecken (Apple 2.1); Stufen über Build-Schalter |
| Rechtliches in der App | seit 0.13.0 Menü „Rechtliches“ (FA-11.4, FA-11.5): Impressum, Datenschutz, Nutzungsbedingungen, Support, „keine Steuerberatung“, Lizenzen, offline; Texte noch Entwurf | Texte final (P-L1), Entwurfsvermerk aus (P-L20), Datenschutzerklärung unter öffentlicher URL |
| App-Symbol | Flutter-Standardsymbol (RELEASE_PLAYBOOK „Was noch fehlt“) | eigenes Symbol nach Markenentscheidung (O-25) |
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
