# Arbeitsanweisungen für dieses Repository

Buchhaltungsapp für Einzelunternehmen und Kleinunternehmer in Österreich und
Deutschland. Flutter, Android und iOS, offline-first.

## Oberstes Gesetz: Drei unabhängige Prüfinstanzen

Festgelegt vom Auftraggeber am 2026-10-10. Geht allen anderen Regeln vor.

Jede fachliche, rechtliche oder technische Frage, die nicht allein der
Auftraggeber entscheidet, wird von **drei unabhängigen Prüfinstanzen** bearbeitet:

| Instanz | Zuständig für |
|---|---|
| **Rechtsanwalt** | IT-, Datenschutz-, Wettbewerbs-, Verbraucher- und Markenrecht AT/DE, Store-Vorgaben |
| **Steuerberater** | Umsatz- und Ertragsteuer AT/DE, Grenzwerte, Fristen, Rechnungspflichtangaben |
| **Softwareentwickler** | Code, Architektur, Sicherheit, Store-Release, Aufwand |

Vorgehen:

1. Jede Instanz **recherchiert selbstständig** (eigener Agent), übernimmt Aussagen
   aus Code und Dokumenten nicht ungeprüft und liefert je Frage: Antwort,
   Quellen, Sicherheit und ob eine Prüfung in der realen Welt nötig ist.
2. Die Ergebnisse werden **strukturiert eingearbeitet**: gesicherte Befunde in
   Code und Dokumente, nach den übrigen Regeln dieser Datei.
3. Alles, was eine echte Fachperson, ein Amt oder ein echtes Gerät bestätigen
   muss, steht **ausschließlich in einer Sektion**: `docs/SPECIFICATION.md`
   Abschnitt 14 „Prüfung in der realen Welt". Nirgendwo sonst werden solche
   Prüfpunkte verstreut; andere Stellen verweisen nur auf die ID dort.
4. Danach wird **selbstständig weitergearbeitet**. Dem Auftraggeber werden nur
   Entscheidungen vorgelegt, die wirklich seine sind, Schritt für Schritt.

Eine Prüfinstanz ersetzt keine echte Rechts- oder Steuerberatung. Sie bereitet
sie vor, damit die echte Prüfung kurz, gezielt und billig wird.

## Die wichtigste Regel: Dokumentation ist Teil der Änderung

`docs/SPECIFICATION.md` und `docs/BENUTZERHANDBUCH.md` werden **im selben Commit**
mitgeführt wie der Code. Nicht danach, nicht „wenn Zeit ist". Eine Spezifikation,
die dem Code nachläuft, ist schlimmer als keine, weil ihr jemand glaubt.

### Wann was anzupassen ist

| Änderung am Code | SPECIFICATION.md | BENUTZERHANDBUCH.md |
|---|---|---|
| Neue oder geänderte Funktion | ja, Abschnitt 5 | ja, wenn der Nutzer sie sieht |
| Steuersatz, Umsatzgrenze, Frist | ja, Abschnitte 3 und 12 | ja, wenn im Handbuch genannt |
| Datenbankschema | ja, Abschnitte 4 und 12 | nein |
| Neuer Bildschirm | ja, Abschnitt 7 | ja |
| Neues Exportformat | ja, Abschnitt 8 | ja, Abschnitt 9 |
| Neue Fehlermeldung im Formular | nein | ja, Abschnitt 13 |
| Bekannte Grenze beseitigt | ja, Abschnitt 11 | ja, Abschnitt 14 |
| Reines Refactoring ohne Verhaltensänderung | nein | nein |

Bei jeder Änderung an der Spezifikation: **Zeile in der Änderungshistorie
(Abschnitt 13) ergänzen und die Dokumentversion erhöhen.**

### Der Mechanismus, der das erzwingt

`test/specification_sync_test.dart` liest den `spec.*`-Block aus Abschnitt 12 der
Spezifikation und vergleicht **jeden** Wert mit dem Code. Der Test schlägt in
beide Richtungen fehl:

- Wert im Code geändert, Spezifikation nicht → rot
- Wert in der Spezifikation dokumentiert, aber von keiner Prüfung erfasst → rot

Wer einen neuen Kennwert in die Spezifikation schreibt, ergänzt also auch die
Prüfung. Wer einen Wert im Code ändert, merkt es beim nächsten `flutter test`.

### Datenschutz mitführen

Eine Änderung, die Daten vom Gerät wegüberträgt, ist erst fertig, wenn sie im
selben Commit in drei Stellen eingetragen ist: Datenflusstabelle in
`docs/LASTENHEFT.md` Abschnitt 5.19, `docs/PRIVACY.md` und die
Store-Datensicherheitsangaben in `docs/STORE_LISTING.md` (Lastenheft L-19.5).

## Release Notes und Nachverfolgbarkeit

Jede ausgelieferte Version – auch ein Testbuild – hat einen Eintrag in
`docs/RELEASE_NOTES.md`, geschrieben **im selben Commit**, der `version` in
`pubspec.yaml` erhöht. Pflichtfelder: Art, Commit, Branch, Dokumentstände,
Datenbankschema, Prüfung; Änderungen jeweils mit Anforderungs-ID und Commit.
`test/release_notes_test.dart` erzwingt das. Nach dem Build wird der Commit als
`v<Version>` getaggt.

Änderungen zwischen zwei Versionen sammeln sich im Abschnitt *Unveröffentlicht*:
jeder Commit mit Verhaltensänderung trägt dort eine Zeile ein.

## Zusatzsicherung

Code und Dokumente werden zusätzlich zu GitHub regelmäßig auf die lokale SSD
des Auftraggebers gesichert: `tool/sicherung/`, Anleitung in
`docs/SICHERUNG.md`. Wer die Repository-Struktur oder den Branchnamen ändert,
prüft, dass die Sicherung weiter läuft.

## Fachliche Grundregeln

Diese sind nicht verhandelbar. Ausführlich in `docs/SPECIFICATION.md` Abschnitt 3.

1. **Geld ist `int`.** Alle Beträge laufen über `Money` (ganzzahlige Cent). Es
   gibt keinen `double`-Betrag in dieser Codebasis, auch nicht zur Anzeige.
2. **`net + vat == gross`** gilt ausnahmslos. Die Steuer ist die Restgröße, damit
   der eingegebene Betrag exakt erhalten bleibt.
3. **Steuersätze in Promille**, Mengen in Tausendsteln.
4. **Umsatzsteuer wird je Rechnungsposition gerundet**, nicht auf der Summe.
5. **Länderunterschiede nur in `TaxProfile`** (`lib/domain/country.dart`). Ein
   `if (country == Country.at)` in einem Widget verletzt die Abstraktion.
6. **Migrationen sind unveränderlich.** Nie eine ausgelieferte Migration ändern,
   nur eine neue ergänzen.
7. **Gestellte Rechnungen sind schreibgeschützt.** Stammdaten werden bei
   Rechnungslegung als JSON eingefroren.
8. **Jeder Grenzwert trägt seine Fundstelle** als Kommentar im Code. Eine Zahl
   ohne Rechtsverweis ist in einem Jahr nicht mehr überprüfbar.

## Architektur

```
lib/domain/     Fachliche Typen, importieren KEIN material.dart
lib/services/   Fachlogik, importieren KEIN material.dart
lib/data/       SQLite-Schema und Repositories
lib/features/   Ein Ordner je Bildschirm
lib/core/       Formatierung, Zeiträume
lib/widgets/    Gemeinsame UI-Bausteine
```

Zustand: ein einzelner `ChangeNotifier` (`AppState`) über `InheritedNotifier`.
Kein State-Management-Paket. Jede Abhängigkeit weniger ist eine, die vor einem
Store-Release nicht aktualisiert werden muss.

Rechnen gehört nicht in Widgets. Wenn ein Widget einen Betrag ausrechnet, gehört
die Berechnung nach `lib/services`.

## Definition of Done

```bash
flutter analyze                                    # ohne Befund
dart format --output=none --set-exit-if-changed lib test
flutter test                                       # alles grün
```

Zusätzlich:

- Neue Fachlogik hat Tests
- Spezifikation und Handbuch sind angepasst (siehe oben)
- Auf einem echten Gerät angesehen, nicht nur im Emulator

## Umgebungshinweise

- **Flutter-SDK** liegt bei Bedarf unter `/opt/flutter`, sonst über
  `flutter --version` prüfen.
- **Android-SDK ist im Entwicklungscontainer nicht installierbar**:
  `dl.google.com` ist per Netzwerk-Policy gesperrt. `flutter build apk` schlägt
  hier fehl. Das ist kein Codefehler. Die Plattform-Builds verifiziert
  `.github/workflows/ci.yml`; iOS braucht ohnehin macOS.
- **Niemals** `android/key.properties`, `*.jks` oder `*.keystore` committen.
  Stehen in `.gitignore`.

## Entwicklungsbranch

Entwicklung läuft auf `claude/agile-accounting-app-mobile-wa5j3h`. Kein Push auf
andere Branches ohne ausdrückliche Freigabe. Kein Pull Request, solange keiner
angefragt wurde.

## Sprache

Code, Kommentare, Commit-Nachrichten und Dokumentation auf **Deutsch** – die
Domäne ist deutschsprachiges Steuerrecht, und die Begriffe lassen sich nicht
sinnvoll übersetzen. Bezeichner in Dart bleiben englisch, wo es dem üblichen
Flutter-Stil entspricht (`isSmallBusiness`, `vatPermille`), Fachbegriffe ohne
gute Übersetzung deutsch (`Kleinunternehmer`).
