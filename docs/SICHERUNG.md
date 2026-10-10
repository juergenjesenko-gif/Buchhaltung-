# Zusatzsicherung auf die lokale SSD

**Stand:** 2026-10-10

GitHub ist die Hauptablage. Diese Prozedur legt **zusätzlich** eine vollständige
Kopie von Code und allen Dokumenten auf eine SSD am eigenen Rechner — für den
Fall, dass das GitHub-Konto gesperrt, gelöscht oder nicht erreichbar ist.

## Was gesichert wird

Das ganze Repository mit allen Branches, Tags und der vollständigen Historie:
Code, `docs/` (Lastenheft, Spezifikation, Handbuch, Release Notes …), Tests,
CI-Konfiguration. **Nicht** enthalten sind Signierschlüssel (`*.jks`,
`key.properties`) — die liegen bewusst nie im Repository und brauchen eine
eigene, getrennte Sicherung (siehe `RELEASE_PLAYBOOK.md`).

Auf der SSD entsteht:

```
<Ziel>\Buchhaltung\
├── spiegel.git\                          vollständiger Spiegel, bei jedem Lauf aktualisiert
├── buendel\
│   ├── Buchhaltung_2026-10-10_1800.bundle      eine Datei = komplettes Repository
│   └── Buchhaltung_2026-10-10_1800.bundle.sha256  Prüfsumme
└── sicherung.log                         ein Eintrag je Lauf, OK oder FEHLER
```

Die letzten 30 Bündel bleiben erhalten, ältere werden entfernt.

## Einmalige Einrichtung

Voraussetzung: [Git](https://git-scm.com) ist installiert, und der Rechner ist
bei GitHub angemeldet (das Repository ist privat). Am einfachsten über den Git
Credential Manager, der bei Git für Windows dabei ist: beim ersten Lauf öffnet
sich das GitHub-Anmeldefenster.

### Windows

1. `tool\sicherung\sicherung.ps1` aus dem Repository auf den Rechner kopieren,
   z. B. nach `C:\Tools\sicherung.ps1`.
2. Einmal von Hand ausführen (SSD als Laufwerk `D:` angenommen):
   ```powershell
   powershell -ExecutionPolicy Bypass -File C:\Tools\sicherung.ps1 -Ziel "D:\Sicherung"
   ```
3. Täglich um 18:00 automatisch, in einer PowerShell:
   ```powershell
   $aktion = New-ScheduledTaskAction -Execute "powershell.exe" `
     -Argument '-NoProfile -ExecutionPolicy Bypass -File C:\Tools\sicherung.ps1 -Ziel "D:\Sicherung"'
   $ausloeser = New-ScheduledTaskTrigger -Daily -At 18:00
   $einstellung = New-ScheduledTaskSettingsSet -StartWhenAvailable
   Register-ScheduledTask -TaskName "Buchhaltung Sicherung" -Action $aktion `
     -Trigger $ausloeser -Settings $einstellung
   ```
   `StartWhenAvailable` holt einen verpassten Lauf nach, wenn der Rechner um
   18:00 aus war.

### macOS

1. `tool/sicherung/sicherung.sh` kopieren, z. B. nach `~/Tools/`, und
   ausführbar machen: `chmod +x ~/Tools/sicherung.sh`
2. Einmal von Hand: `~/Tools/sicherung.sh /Volumes/SSD/Sicherung`
3. Täglich um 18:00 per `crontab -e`:
   ```
   0 18 * * * $HOME/Tools/sicherung.sh /Volumes/SSD/Sicherung
   ```

## Kontrolle

Einmal pro Woche einen Blick in `sicherung.log`: die letzte Zeile muss `OK`
lauten und das Datum von heute oder gestern tragen. Ein `FEHLER` heißt meist:
SSD nicht angesteckt oder GitHub-Anmeldung abgelaufen.

## Wiederherstellen

Aus einem Bündel, ohne GitHub:

```bash
git clone Buchhaltung_2026-10-10_1800.bundle Buchhaltung -b claude/agile-accounting-app-mobile-wa5j3h
```

Prüfsumme vorher vergleichen: unter Windows
`Get-FileHash <Datei> -Algorithm SHA256`, unter macOS `shasum -a 256 <Datei>`,
mit dem Inhalt der `.sha256`-Datei.

## Prüfstand

| Skript | Getestet |
|---|---|
| `sicherung.sh` | Linux, 2026-10-10: Erstlauf, Folgelauf, Rotation, Wiederherstellung aus Bündel |
| `sicherung.ps1` | **Nicht ausgeführt** — in der Entwicklungsumgebung gibt es kein Windows. Erster Lauf von Hand und Blick ins Protokoll, siehe Spezifikation Abschnitt 14, P-D8 |
