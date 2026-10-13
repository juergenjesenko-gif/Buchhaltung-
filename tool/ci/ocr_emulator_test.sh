#!/usr/bin/env bash
# Belegerkennung im Release-Build (R8) auf dem Emulator prüfen.
# Aufruf aus .github/workflows/ci.yml (Job android-ocr-emulator) bei laufendem
# Emulator; lokal genauso mit gestartetem x86_64-Emulator.
set -euo pipefail
flutter build apk --release --target-platform android-x64 \
  -t integration_test/receipt_ocr_release.dart
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb logcat -c
adb shell am start -W -n at.jesenko.buchhaltung/.MainActivity
for _ in $(seq 1 90); do
  if adb logcat -d | grep -q 'OCR-SELBSTTEST ERGEBNIS'; then break; fi
  sleep 2
done
adb logcat -d | grep -E 'OCR-SELBSTTEST|AndroidRuntime|FATAL' || true
adb logcat -d | grep -q 'OCR-SELBSTTEST ERGEBNIS OK'
