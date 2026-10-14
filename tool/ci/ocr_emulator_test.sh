#!/usr/bin/env bash
# Belegerkennung im Release-Build (R8) auf dem Emulator prüfen und das rohe
# OCR-Ergebnis aller Fotos in test/fixtures/belege/ nach
# test/fixtures/belege/ocr/<foto>.json schreiben (CI-Artefakt; zusätzlich als
# gzip+Base64 im Job-Log zwischen OCR-SELBSTTEST JSON-Zeilen).
# Aufruf aus .github/workflows/ci.yml (Job android-ocr-emulator) bei laufendem
# Emulator; lokal genauso mit gestartetem x86_64-Emulator.
set -euo pipefail
# Korpusfotos nur für diesen Build als Assets einbinden (nicht einchecken).
cp pubspec.yaml pubspec.yaml.orig
trap 'mv -f pubspec.yaml.orig pubspec.yaml' EXIT
python3 - <<'PY'
s = open('pubspec.yaml').read()
# Vorhandenen assets-Block ergänzen (Handbuch, FA-11.2), sonst neu anlegen.
if '\n  assets:\n' in s:
    s = s.replace('\n  assets:\n', '\n  assets:\n    - test/fixtures/belege/\n', 1)
else:
    s = s.replace('  uses-material-design: true', '  uses-material-design: true\n  assets:\n    - test/fixtures/belege/', 1)
open('pubspec.yaml', 'w').write(s)
PY
grep -A3 'uses-material-design' pubspec.yaml
flutter build apk --release --target-platform android-x64 \
  -t integration_test/receipt_ocr_release.dart
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb logcat -G 16M || true
adb logcat -c
adb shell am start -W -n at.jesenko.buchhaltung/.MainActivity
for _ in $(seq 1 300); do
  if adb logcat -d | grep -q 'OCR-SELBSTTEST ERGEBNIS'; then break; fi
  sleep 2
done
adb logcat -d -v raw -s flutter > ocr-log.txt || true
grep -vE 'OCR-SELBSTTEST JSON' ocr-log.txt | tail -n 80 || true
grep -E 'OCR-SELBSTTEST JSON' ocr-log.txt || true
mkdir -p test/fixtures/belege/ocr
python3 - <<'PY'
import base64, gzip, re, collections
parts = collections.defaultdict(dict)
for line in open('ocr-log.txt', encoding='utf-8', errors='replace'):
    m = re.search(r'OCR-SELBSTTEST JSON (\S+) (\d+)/(\d+) (\S+)', line)
    if m:
        parts[m.group(1)][int(m.group(2))] = (int(m.group(3)), m.group(4))
for name, chunks in parts.items():
    total = next(iter(chunks.values()))[0]
    if len(chunks) != total:
        print(f'UNVOLLSTÄNDIG {name}: {len(chunks)}/{total}')
        continue
    data = gzip.decompress(base64.b64decode(''.join(chunks[i][1] for i in range(1, total + 1))))
    open(f'test/fixtures/belege/ocr/{name}.json', 'wb').write(data)
    print(f'geschrieben {name}.json')
PY
grep -q 'OCR-SELBSTTEST ERGEBNIS OK' ocr-log.txt
