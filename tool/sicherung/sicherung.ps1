# Zusatzsicherung des Repositorys auf eine lokale SSD (Windows).
#
# Legt beim ersten Lauf einen vollständigen Spiegel an (alle Branches, Tags,
# Historie) und aktualisiert ihn danach. Zusätzlich entsteht bei jedem Lauf ein
# datiertes, in sich geschlossenes Bündel (.bundle), das sich ohne GitHub
# wiederherstellen lässt. Ältere Bündel werden nach $Behalten Läufen entfernt.
#
# Aufruf:  powershell -ExecutionPolicy Bypass -File sicherung.ps1 -Ziel "D:\Sicherung"
# Ablauf und Wiederherstellung: docs/SICHERUNG.md

param(
    [Parameter(Mandatory = $true)] [string] $Ziel,
    [string] $Quelle = "https://github.com/juergenjesenko-gif/Buchhaltung-.git",
    [int] $Behalten = 30
)

$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $Ziel | Out-Null
$Ziel = (Resolve-Path $Ziel).Path
$stempel = Get-Date -Format "yyyy-MM-dd_HHmm"
$basis = Join-Path $Ziel "Buchhaltung"
$spiegel = Join-Path $basis "spiegel.git"
$buendel = Join-Path $basis "buendel"
$protokoll = Join-Path $basis "sicherung.log"

New-Item -ItemType Directory -Force -Path $basis, $buendel | Out-Null

function Log($text) {
    $zeile = "$(Get-Date -Format s)  $text"
    Write-Host $zeile
    Add-Content -Path $protokoll -Value $zeile -Encoding UTF8
}

try {
    if (Test-Path $spiegel) {
        git -C $spiegel remote update --prune
        if ($LASTEXITCODE -ne 0) { throw "Aktualisieren des Spiegels fehlgeschlagen" }
    } else {
        git clone --mirror $Quelle $spiegel
        if ($LASTEXITCODE -ne 0) { throw "Erstes Klonen fehlgeschlagen" }
    }

    $datei = Join-Path $buendel "Buchhaltung_$stempel.bundle"
    git -C $spiegel bundle create $datei --all
    if ($LASTEXITCODE -ne 0) { throw "Bündel konnte nicht erstellt werden" }
    git -C $spiegel bundle verify $datei | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Bündel ist nicht lesbar: $datei" }

    $hash = (Get-FileHash $datei -Algorithm SHA256).Hash
    Set-Content -Path "$datei.sha256" -Value "$hash  $(Split-Path $datei -Leaf)" -Encoding ASCII

    Get-ChildItem $buendel -Filter "*.bundle" | Sort-Object Name -Descending |
        Select-Object -Skip $Behalten | ForEach-Object {
            Remove-Item $_.FullName, "$($_.FullName).sha256" -ErrorAction SilentlyContinue
        }

    $kopf = git -C $spiegel log -1 --format="%h %ad %s" --date=short claude/agile-accounting-app-mobile-wa5j3h
    Log "OK  $datei  SHA256 $hash  Stand: $kopf"
} catch {
    Log "FEHLER  $($_.Exception.Message)"
    exit 1
}
