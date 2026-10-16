#!/usr/bin/env bash
# Wechsel der technischen Kennung auf die Store-Kennung (Lastenheft O-33).
#
# NICHT vorher ausführen. Auslöser: unmittelbar vor der ersten
# Store-Einreichung (Entscheidung Auftraggeberin 2026-10-15). Danach müssen
# Testgeräte neu installieren (vorher Datensicherung, FA-7.x), und die Kennung
# ist nach der ersten Einreichung nicht mehr änderbar.
#
# Ändert:
#   Android  applicationId, namespace, Kotlin-Paket (Ordner + package-Zeilen)
#   iOS      PRODUCT_BUNDLE_IDENTIFIER (Runner und RunnerTests); der
#            iCloud-Container iCloud.$(PRODUCT_BUNDLE_IDENTIFIER) folgt von
#            selbst (Runner.entitlements), muss aber im Apple Developer Portal
#            neu angelegt werden (P-B13).
#   Workflow packageName im Play-Upload von .github/workflows/release.yml
#
# Aufruf aus dem Repository-Wurzelordner:  tool/release/bundle_id_wechsel.sh
# Danach: flutter analyze && flutter test, Spezifikation/Lastenheft/
# STORE_LISTING nachführen (alte Kennung suchen: git grep at.jesenko.buchhaltung).
set -euo pipefail

ALT="${ALT:-at.jesenko.buchhaltung}"
NEU="${NEU:-at.jenibarb.jenibucht}"
ALT_PFAD="${ALT//./\/}"
NEU_PFAD="${NEU//./\/}"
KT=android/app/src/main/kotlin

[ -f pubspec.yaml ] || { echo "Bitte im Repository-Wurzelordner aufrufen." >&2; exit 1; }
[ -d "$KT/$ALT_PFAD" ] || { echo "Kotlin-Paket $ALT nicht gefunden – schon gewechselt?" >&2; exit 1; }

# Android: Gradle (Groovy oder Kotlin DSL)
for f in android/app/build.gradle android/app/build.gradle.kts; do
  [ -f "$f" ] && sed -i.bak "s/\"$ALT\"/\"$NEU\"/g" "$f" && rm -f "$f.bak"
done

# Android: Kotlin-Quellen verschieben und package-Zeilen anpassen
mkdir -p "$KT/$NEU_PFAD"
git mv "$KT/$ALT_PFAD"/* "$KT/$NEU_PFAD"/
find "$KT/$NEU_PFAD" -name '*.kt' -exec sed -i.bak "s/^package $ALT\$/package $NEU/" {} \; -exec rm -f {}.bak \;
# leere alte Ordner entfernen
find "$KT" -type d -empty -delete

# Manifest und Ressourcen: vollqualifizierte Verweise auf die alte Kennung
{ grep -rl "$ALT" android/app/src 2>/dev/null || true; } | while read -r f; do
  sed -i.bak "s/$ALT/$NEU/g" "$f" && rm -f "$f.bak"
done

# iOS: Bundle-ID (auch RunnerTests mit Suffix)
sed -i.bak "s/PRODUCT_BUNDLE_IDENTIFIER = $ALT/PRODUCT_BUNDLE_IDENTIFIER = $NEU/g" \
  ios/Runner.xcodeproj/project.pbxproj && rm -f ios/Runner.xcodeproj/project.pbxproj.bak

# Release-Workflow: Play-Paketname
sed -i.bak "s/packageName: $ALT/packageName: $NEU/g" .github/workflows/release.yml \
  && rm -f .github/workflows/release.yml.bak

echo "Kennung gewechselt: $ALT -> $NEU"
echo "Verbleibende Fundstellen der alten Kennung (Doku, Tests):"
git grep -n "$ALT" -- . ':!tool/release/bundle_id_wechsel.sh' || true
