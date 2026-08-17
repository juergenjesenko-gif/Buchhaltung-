# Datenschutzerklärung

> **Vorlage.** Beide Stores verlangen eine Datenschutzerklärung unter einer
> öffentlich erreichbaren URL – auch bei einer App, die keine Daten überträgt.
> Vor der Veröffentlichung sind die mit `<…>` markierten Stellen zu ersetzen.
> GitHub Pages genügt als Hosting. Bei kommerzieller Nutzung ist eine
> anwaltliche Prüfung sinnvoll; diese Vorlage ist keine Rechtsberatung.

**Stand:** <Datum>

## Verantwortlicher

```
<Name>
<Straße und Hausnummer>
<PLZ Ort>
<Land>
E-Mail: <E-Mail-Adresse>
```

## Kurzfassung

Die App **Buchhaltung** verarbeitet alle Daten ausschließlich auf deinem Gerät.
Es gibt keinen Server, an den Daten gesendet werden. Es gibt keine Nutzerkonten,
keine Analyse-Werkzeuge, keine Werbung und keine Weitergabe an Dritte.

## Welche Daten die App verarbeitet

Alle Daten gibst du selbst ein oder erzeugst sie durch die Nutzung:

- **Unternehmensdaten:** Firmenname, Inhaber, Anschrift, Kontaktdaten,
  Steuernummer, UID/USt-IdNr., Bankverbindung
- **Belege:** Datum, Betrag, Umsatzsteuersatz, Beschreibung, Geschäftspartner,
  Kategorie, Zahlungsart, Notiz sowie das Belegfoto
- **Kundendaten:** Name, Anschrift, UID, E-Mail-Adresse, Notiz
- **Rechnungen:** Nummer, Datum, Positionen, Beträge, Status

## Wo diese Daten liegen

In einer SQLite-Datenbank und in Bilddateien im privaten Verzeichnis der App auf
deinem Gerät. Andere Apps haben darauf keinen Zugriff.

Die App überträgt **keine** dieser Daten an den Anbieter oder an Dritte. Sie
enthält keine Analyse-Bibliothek, kein Crash-Reporting und keine Werbe-SDKs. Die
App baut von sich aus **keine Netzwerkverbindungen** auf.

Die automatische Sicherung von Android (Google Drive) und die
Gerät-zu-Gerät-Übertragung sind für diese App **deaktiviert**
(`data_extraction_rules.xml`), damit deine Buchhaltungsdaten nicht ohne dein
Zutun in eine Cloud gelangen.

## Wann Daten das Gerät verlassen

Nur dann, wenn du es aktiv auslöst:

- **Rechnung als PDF teilen** – du wählst im Systemdialog selbst das Ziel
  (E-Mail, Messenger, Cloud-Ordner)
- **Export für die Steuerberatung** – gleiches Prinzip

In beiden Fällen bestimmst du, wohin die Datei geht. Ab diesem Zeitpunkt gilt die
Datenschutzerklärung des jeweiligen Dienstes.

## Berechtigungen und wozu sie dienen

| Berechtigung | Zweck |
|---|---|
| Kamera | Belege abfotografieren |
| Fotobibliothek (lesen) | Bereits vorhandene Belegfotos hinzufügen |
| Fotobibliothek (schreiben) | Eine erstellte Rechnung in der Fotobibliothek ablegen |

Die App fragt jede Berechtigung erst dann ab, wenn du die zugehörige Funktion
nutzt. Verweigerte Berechtigungen schränken nur diese Funktion ein.

## Rechtsgrundlage

Für die Verarbeitung auf deinem Gerät ist der Anbieter nicht Verantwortlicher im
Sinne der DSGVO, da er keinen Zugriff auf die Daten hat. Verarbeitest du in der
App personenbezogene Daten Dritter – etwa Kundenanschriften –, bist **du** dafür
der Verantwortliche.

## Speicherdauer und Löschung

Die Daten bleiben so lange auf dem Gerät, bis du sie löschst. Belege löschst du
einzeln in der App; das Löschen wird im Änderungsprotokoll vermerkt.
Deinstallieren der App entfernt alle Daten unwiderruflich.

**Wichtig:** Steuerliche Aufbewahrungsfristen (Österreich 7 Jahre nach § 132 BAO,
Deutschland 8 Jahre für Buchungsbelege nach § 147 AO) gelten unabhängig von der
App. Sichere deine Daten daher regelmäßig über die Exportfunktion.

## Deine Rechte

Da der Anbieter keine deiner Daten verarbeitet, kann er zu ihnen weder Auskunft
geben noch sie löschen – du hast durch die App selbst vollen Zugriff. Für Fragen
zur App erreichst du uns unter der oben genannten Adresse.

## Änderungen

Ändert sich die Funktionsweise der App in datenschutzrelevanter Weise, wird diese
Erklärung angepasst und das Datum oben aktualisiert.
