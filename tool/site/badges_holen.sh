#!/usr/bin/env bash
# Holt die offiziellen Store-Badges unverändert (Markenrichtlinien Google Play
# und Apple). Läuft im GitHub-Runner (.github/workflows/medien_holen.yml,
# Eingabe skript=badges_holen.sh), weil die Entwicklungsumgebung beide Hosts
# nicht erreicht.
set -euo pipefail
S=docs/site/img/badges
mkdir -p $S
g(){ curl -fsSL --retry 3 -o "$S/$2" "https://play.google.com/intl/en_us/badges/static/images/badges/$1"; }
a(){ curl -fsSL --retry 3 -o "$S/$2" "https://toolbox.marketingtools.apple.com/api/v2/badges/download-on-the-app-store/black/$1" || echo "Apple-Badge $1 nicht erreichbar"; }
g de_badge_web_generic.png google-play-de.png
g en_badge_web_generic.png google-play-en.png
g fr_badge_web_generic.png google-play-fr.png
a de-de app-store-de.svg
a en-gb app-store-en.svg
a fr-fr app-store-fr.svg
file $S/*
