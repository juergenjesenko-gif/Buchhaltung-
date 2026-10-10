#!/usr/bin/env bash
# Zusatzsicherung des Repositorys auf eine lokale SSD (macOS/Linux).
# Gegenstück zu sicherung.ps1; Ablauf und Wiederherstellung: docs/SICHERUNG.md
#
# Aufruf:  ./sicherung.sh /Volumes/SSD/Sicherung
set -euo pipefail

ZIEL="${1:?Zielordner auf der SSD angeben}"
mkdir -p "$ZIEL"
ZIEL="$(cd "$ZIEL" && pwd)"
QUELLE="${QUELLE:-https://github.com/juergenjesenko-gif/Buchhaltung-.git}"
BEHALTEN="${BEHALTEN:-30}"
STEMPEL="$(date +%Y-%m-%d_%H%M)"
BASIS="$ZIEL/Buchhaltung"
SPIEGEL="$BASIS/spiegel.git"
BUENDEL="$BASIS/buendel"
PROTOKOLL="$BASIS/sicherung.log"

mkdir -p "$BUENDEL"
log() { echo "$(date +%Y-%m-%dT%H:%M:%S)  $*" | tee -a "$PROTOKOLL"; }
trap 'log "FEHLER  in Zeile $LINENO"' ERR

if [ -d "$SPIEGEL" ]; then
  git -C "$SPIEGEL" remote update --prune
else
  git clone --mirror "$QUELLE" "$SPIEGEL"
fi

DATEI="$BUENDEL/Buchhaltung_$STEMPEL.bundle"
git -C "$SPIEGEL" bundle create "$DATEI" --all
git -C "$SPIEGEL" bundle verify "$DATEI" >/dev/null
( cd "$BUENDEL" && shasum -a 256 "$(basename "$DATEI")" > "$(basename "$DATEI").sha256" )

ls -1 "$BUENDEL"/*.bundle | sort -r | tail -n +"$((BEHALTEN + 1))" | while read -r alt; do
  rm -f "$alt" "$alt.sha256"
done

KOPF="$(git -C "$SPIEGEL" log -1 --format='%h %ad %s' --date=short claude/agile-accounting-app-mobile-wa5j3h)"
log "OK  $DATEI  Stand: $KOPF"
