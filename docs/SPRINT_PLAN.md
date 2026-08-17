# Sprintplan und Arbeitsweise

## Rahmen

- **Sprintlänge:** 2 Wochen
- **Team:** Einzelentwickler mit KI-Unterstützung
- **Sprintziel:** immer ein Satz, immer aus Nutzersicht formuliert
- **Backlog:** `docs/BACKLOG.md`, priorisiert – oben steht, was als Nächstes dran ist

## Definition of Ready

Eine Story darf erst in einen Sprint, wenn:

- [ ] sie aus Nutzersicht formuliert ist („Als … will ich … damit …")
- [ ] Akzeptanzkriterien überprüfbar sind, nicht „soll gut funktionieren"
- [ ] bei steuerlichem Bezug die Rechtsgrundlage für AT **und** DE geklärt ist
- [ ] klar ist, ob sie Datenbankmigration braucht

## Definition of Done

- [ ] `flutter analyze` ohne Befund
- [ ] `dart format` ohne Änderung
- [ ] `flutter test` grün, neue Fachlogik hat Tests
- [ ] Fachlogik ist ohne UI testbar (kein Rechnen in Widgets)
- [ ] Beträge laufen über `Money`, niemals über `double`
- [ ] Länderunterschiede stecken in `TaxProfile`, nicht in `if (country == …)`
      irgendwo im UI
- [ ] Schemaänderungen als neue Migration in `AppDatabase._migrations`, nie durch
      Ändern einer bestehenden
- [ ] Auf einem echten Gerät angesehen (nicht nur im Emulator)
- [ ] Doku angepasst, wenn sich Verhalten oder Rechtslage ändert

## Sprint 1 – abgeschlossen

**Ziel:** Ein Einzelunternehmer in Österreich oder Deutschland kann Belege
erfassen, seine Zahlen sehen, eine rechtskonforme Rechnung schreiben und die
Daten an die Kanzlei geben.

Geliefert: Epics A bis E aus dem Backlog. 94 Tests, Analyse ohne Befund, CI für
Android und iOS eingerichtet.

**Was gut lief:** Die Entscheidung, Geld als Integer-Cent zu modellieren, hat sich
sofort ausgezahlt. Der Test, der über 2.000 Beträge × 6 Steuersätze prüft, dass
`netto + ust == brutto` gilt, hätte mit `double` nie durchgelaufen.

**Was offen blieb:** Kein Backup. Das ist für eine Buchhaltungsapp eine echte
Lücke, nicht nur ein fehlendes Feature – deshalb steht F1 in Sprint 2 an erster
Stelle und **vor** dem öffentlichen Store-Release.

**Was in dieser Umgebung nicht verifiziert werden konnte:** Der Android-APK-Build.
`dl.google.com` ist im Entwicklungscontainer per Netzwerk-Policy gesperrt, das
Android SDK ließ sich nicht installieren. Analyse, Formatprüfung und Tests laufen
lokal; die echten Plattform-Builds macht die CI (`.github/workflows/ci.yml`) beim
ersten Push. Der iOS-Build braucht ohnehin macOS.

## Sprint 2 – als Nächstes

**Ziel:** Ein Nutzer kann seine Buchhaltung sichern und auf ein neues Gerät
übertragen, und muss Beträge nicht mehr abtippen.

| Story | Umfang | Warum jetzt |
|---|---|---|
| F1 Backup & Wiederherstellung | groß | Ohne Backup ist ein verlorenes Telefon der Verlust der Buchhaltung – bei laufender Aufbewahrungspflicht |
| F2 Belegerkennung (OCR) | groß | Der größte Zeitfresser im Alltag; muss auf dem Gerät laufen |
| F4 Storno- und Gutschriftsrechnung | mittel | Eine gestellte Rechnung ist gesperrt – ohne Storno gibt es derzeit keinen Korrekturweg |
| F5 Offene Posten & Zahlungserinnerung | mittel | Direkt monetarisierbarer Nutzen |
| F3 Belegvorlagen | klein | Günstig umzusetzen, spürbare Erleichterung |

Bewusst **nicht** in Sprint 2: Cloud-Sync. Ein Sync ohne funktionierendes Backup
verdoppelt nur das Risiko.

## Sprint 3 – grobe Richtung

E-Rechnung (G1). In Deutschland gilt die Empfangspflicht seit 1.1.2025, die
Versandpflicht kommt gestaffelt bis 2028. Für B2B-Nutzer wird ein PDF nicht mehr
genügen.

## Technische Leitlinien

**Geld ist `int`.** `Money` speichert Cent. Es gibt keinen `double`-Betrag in
dieser Codebasis, auch nicht „nur zur Anzeige".

**Länderunterschiede an einer Stelle.** Alles Landesspezifische steht in
`TaxProfile` in `lib/domain/country.dart`. Wer ein `if (country == Country.at)` in
einem Widget schreibt, hat die Abstraktion umgangen.

**Fachlogik ohne Flutter.** `lib/domain` und `lib/services` importieren kein
`material.dart`. Das hält sie testbar und macht die Tests schnell.

**Migrationen sind unveränderlich.** Eine bereits ausgelieferte Migration wird
nie geändert, nur eine neue ergänzt. Sonst haben installierte Apps ein anderes
Schema als neu installierte.

**Rechtliche Annahmen werden dokumentiert.** Jeder Grenzwert und jeder Steuersatz
im Code trägt seine Fundstelle als Kommentar und steht in
`docs/COMPLIANCE_AT_DE.md`. Eine Zahl ohne Fundstelle ist in einem Jahr nicht mehr
überprüfbar.
