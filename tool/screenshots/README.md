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

# Erklärvideo-Aufnahmen (Variante B)

Bildschirmaufnahmen für das Erklärvideo (Übergabe Marketing 2026-10-30,
Antwort in `docs/maerkte/Antwort_Entwicklung_Erklaervideo.md` Abschnitt 5),
ebenfalls als Widget-Test ohne Emulator: `test/screenshots/erklaervideo_test.dart`.
Ein Skript bedient die App wie eine Person – langsam, je Tipp ein sichtbarer
Kreis (~0,3 s), vor und nach jedem Schritt ~1 s Ruhe – und schreibt jedes
Bild mit festem Zeitschritt (33 ms, 30 fps), Hochformat 1080×2340
(Pixelverhältnis 2,625). Oben eine schlichte Statusleiste „9:41“, voller
Akku; sie und der Tippkreis entstehen nur in der Aufnahme.

Daten: erfundene Musterfirma „Grafikdesign Muster“, Wien, Kleinunternehmerin
(österreichische Demodaten `DemoDataset`, P-R56), aber in einer
**beschreibbaren** Datenbank – Speichern funktioniert, kein Demo-Band, kein
Wasserzeichen. Pro über `FakeStoreBilling` (außer A1: Erststart ohne Abo).

Aufnahmen: A1 Erststart, A2 Beleg scannen und auslesen, A3 slowenischer
Beleg, A4 Beleg in USD mit „Kurs abrufen“, A6 Vertrag scannen und Rate
buchen, A7 Übersicht und Zahl ändert sich, A8 Saldenliste, A9 Angebot →
Rechnung → PDF (ZUGFeRD), A10 Kennzahlen fürs Finanzamt (E1a), A11 Archiv.
A5 (Teilen aus einer anderen App) fehlt: die fremde App und das
Teilen-Blatt des Systems lassen sich ohne echtes Gerät nicht zeigen.

Simuliert (für ehrliche Einblendungen):

- **Kamera/Scanner:** der Systemscanner liefert ein im Test gezeichnetes
  Musterbild; die Kameraansicht selbst fehlt.
- **Texterkennung:** der Kanal liefert den Text, der auf dem Musterbild
  steht; das Auslesen (`ReceiptTextParser`, Vertrags-Kurzübersicht) läuft
  echt.
- **„Kurs abrufen“:** erfundene EZB-Kurse liegen schon im lokalen Speicher,
  es geht nichts ins Netz.
- **PDF-Ansicht:** Seiten rastert `pdftoppm` statt des Geräts.
- **Tastatur:** erscheint nicht; Text wird Zeichen für Zeichen eingesetzt.
- Zeichen ohne Glyphe in Roboto (z. B. „⋮“, „→“) erscheinen als Kästchen;
  das Gerät hat dafür Ersatzschriften.

## In GitHub Actions

1. Actions → „Erklärvideo-Aufnahmen“ → „Run workflow“ (optional nur
   einzelne Aufnahmen, z. B. `A1,A7`).
2. Nach dem Lauf das Artefakt `erklaervideo` laden (eine ZIP-Datei mit
   `erklaer_A1.mp4` …; H.264, yuv420p, 30 fps, ohne Ton).

## Lokal

Voraussetzung: `pdftoppm` (Paket `poppler-utils`), für MP4 `ffmpeg`.

```bash
ERKLAERVIDEO=1 ERKLAERVIDEO_NUR=A1 flutter test --tags screenshots test/screenshots/erklaervideo_test.dart
ffmpeg -framerate 30 -i build/erklaervideo/A1/frame_%05d.png -c:v libx264 -pix_fmt yuv420p -an erklaer_A1.mp4
```

Ausgabe: `build/erklaervideo/<Aufnahme>/frame_00000.png` …. Ohne
`ERKLAERVIDEO=1` wird der Test übersprungen; im normalen `flutter test`
läuft er nicht. Eine Aufnahme braucht etwa 1–3 Minuten.
