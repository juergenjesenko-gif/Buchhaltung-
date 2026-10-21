# Store-Screenshots (P-D34)

Widget-Test ohne Emulator: deutsche Demo (`DemoDatasetDe`), helle Oberfläche,
echte Schriften (Roboto, Material Icons aus dem Flutter-SDK, Work Sans aus
`assets/fonts`), ohne Demo-Band und ohne Statusleiste.

Größen: `play_phone` 1080×1920, `play_tablet` 1600×2560, `appstore_6_9`
1320×2868, `appstore_ipad_13` 2064×2752. Bildschirme: 1 Übersicht, 2 Beleg,
3 Rechnungs-PDF, 4 Belegliste, 5 Export, 6 Verträge, 7 Abo.

## In GitHub Actions

1. Actions → „Store-Screenshots“ → „Run workflow“.
2. Nach dem Lauf das Artefakt `store-screenshots` laden (eine ZIP-Datei).

## Lokal

Voraussetzung: `pdftoppm` (Paket `poppler-utils`).

```bash
SCREENSHOTS=1 flutter test --tags screenshots test/screenshots/store_screenshots_test.dart
```

Ausgabe: `build/screenshots/<store>/<nr>_<name>.png`. Ohne `SCREENSHOTS=1`
wird der Test übersprungen; im normalen `flutter test` läuft er nicht.
