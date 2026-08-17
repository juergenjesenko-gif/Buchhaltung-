# Steuerlicher Rahmen Österreich und Deutschland

Diese Datei dokumentiert, welche rechtlichen Annahmen im Code stecken, wo sie
stehen und wo die App bewusst an ihre Grenze kommt.

> **Stand der Recherche: 2025/2026.** Steuerrecht ändert sich, teils rückwirkend.
> Alle Werte sind in `lib/domain/country.dart` an einer Stelle gebündelt, damit
> eine Änderung eine Zeile ist und keine Suche durch die Codebasis. Diese Datei
> ersetzt keine steuerliche Beratung.

## Wo die Werte im Code stehen

`lib/domain/country.dart` enthält zwei `TaxProfile`-Konstanten – `TaxProfile.austria`
und `TaxProfile.germany`. Jede Änderung des Steuerrechts betrifft ausschließlich
diese Datei; die Tests in `test/vat_calculator_test.dart` und
`test/small_business_monitor_test.dart` prüfen die Werte gegen die dokumentierte
Rechtslage.

## Umsatzsteuersätze

| | Österreich | Deutschland |
|---|---|---|
| Normal-/Regelsteuersatz | 20 % | 19 % |
| Ermäßigt | 10 % (Lebensmittel, Bücher, Personenbeförderung, Wohnraummiete) | 7 % (Lebensmittel, Bücher) |
| Zweiter ermäßigter Satz | 13 % (Wein ab Hof, Kunstgegenstände, lebende Tiere, Kultur) | – |
| Steuerfrei | 0 % | 0 % |

Der Sonderfall 13 % ist eine österreichische Besonderheit, die in Deutschland
keine Entsprechung hat – deshalb ist die Satzliste länderabhängig und nicht
gemeinsam.

## Kleinunternehmerregelung

Hier unterscheiden sich die beiden Rechtsordnungen so deutlich, dass eine
gemeinsame Implementierung nur falsch sein könnte.

### Österreich – § 6 Abs 1 Z 27 UStG (Fassung ab 1.1.2025)

- Umsatzgrenze **55.000 €** im laufenden Kalenderjahr
- **Toleranz von 10 %**: bis 60.500 € bleibt die Befreiung bis zum Jahresende
  bestehen, entfällt aber ab dem Folgejahr
- Über 60.500 € entfällt die Befreiung **sofort** – ab dem Umsatz, der die
  Toleranz reißt, ist Umsatzsteuer auszuweisen
- Es gibt **keine** gesonderte Vorjahresgrenze

### Deutschland – § 19 UStG (Fassung ab 1.1.2025)

- Vorjahresumsatz höchstens **25.000 €**
- Laufender Umsatz höchstens **100.000 €**
- **Keine Toleranzregel**: wird die Grenze im laufenden Jahr überschritten, ist
  ab diesem Umsatz Umsatzsteuer auszuweisen
- Lag der Vorjahresumsatz über 25.000 €, gilt die Regelung im ganzen laufenden
  Jahr nicht – unabhängig davon, wie niedrig der laufende Umsatz ist

Implementiert in `lib/services/small_business_monitor.dart`. Die Ampel warnt ab
80 % Ausnutzung; dieser Schwellwert ist eine Produktentscheidung, keine
gesetzliche Vorgabe.

## Pflichtangaben auf der Rechnung

Rechtsgrundlage: **§ 11 UStG** (Österreich), **§ 14 UStG** (Deutschland). Die
Anforderungen deckt `lib/services/invoice_pdf.dart` ab:

- Name und vollständige Anschrift des Ausstellers
- Name und vollständige Anschrift des Empfängers
- Steuernummer bzw. UID/USt-IdNr. des Ausstellers
- Ausstellungsdatum
- Fortlaufende Rechnungsnummer (einmalig)
- Menge und handelsübliche Bezeichnung der Lieferung/Leistung
- **Liefer- bzw. Leistungsdatum** – der am häufigsten vergessene Punkt; fehlt er,
  verliert der Empfänger den Vorsteuerabzug. Die App macht ihn zum Pflichtfeld.
- Entgelt aufgeschlüsselt nach Steuersätzen
- Anzuwendender Steuersatz und Steuerbetrag
- Bei Steuerbefreiung: Hinweis auf den Grund der Befreiung

### Kleinbetragsrechnung

Bis zu diesem Bruttobetrag genügen reduzierte Angaben:

| Österreich | Deutschland |
|---|---|
| 400 € (§ 11 Abs 6 UStG) | 250 € (§ 33 UStDV) |

Die App weist auf die Grenze hin, erzeugt aber immer eine vollständige Rechnung –
zu viele Angaben sind nie ein Mangel.

### Hinweistext bei Kleinunternehmern

Wer die Kleinunternehmerregelung nutzt, **darf keine Umsatzsteuer ausweisen** und
**muss** den Grund der Befreiung angeben. Die App setzt den Text automatisch:

- Österreich: *„Umsatzsteuerbefreit – Kleinunternehmer gemäß § 6 Abs 1 Z 27 UStG."*
- Deutschland: *„Gemäß § 19 UStG wird keine Umsatzsteuer berechnet (Kleinunternehmer)."*

Wird trotzdem Umsatzsteuer ausgewiesen, schuldet man sie dem Finanzamt – auch
wenn man sie nie einnehmen durfte. Deshalb blendet die App die Steuerspalte für
Kleinunternehmer vollständig aus, statt sie nur auf 0 zu setzen.

## Aufbewahrungsfristen

| | Österreich | Deutschland |
|---|---|---|
| Buchungsbelege | 7 Jahre (§ 132 BAO) | 8 Jahre (§ 147 AO, ab 2025 von 10 auf 8 verkürzt) |
| Bücher, Jahresabschlüsse | 7 Jahre | 10 Jahre |

Die Fristen bestimmen in der App die Jahresauswahl in der Belegliste. Wichtiger
ist die praktische Folge: **die App speichert nur lokal.** Ein verlorenes Telefon
bedeutet verlorene Belege – die Aufbewahrungspflicht bleibt trotzdem. Deshalb ist
die verschlüsselte Sicherung (Backlog F1) der oberste Punkt für Sprint 2, und die
App weist bei jedem Beleg auf die Frist hin.

## Unveränderbarkeit und Nachvollziehbarkeit

**§ 131 BAO** (Österreich) und die **GoBD** (Deutschland) verlangen, dass
Buchungen nachvollziehbar und nicht unerkennbar veränderbar sind.

Was die App dafür tut:

- Tabelle `audit_log` protokolliert Anlegen, Ändern und Löschen von Belegen und
  Rechnungen mit Zeitstempel
- Gestellte Rechnungen sind schreibgeschützt; Korrekturen laufen über Storno
- Aussteller- und Empfängerdaten werden bei Rechnungslegung als JSON eingefroren,
  damit späteres Ändern der Stammdaten alte Rechnungen nicht verfälscht
- Rechnungsnummern sind in der Datenbank eindeutig (UNIQUE INDEX)

**Wo die App an ihre Grenze kommt, offen benannt:** ein Gerät, auf dem der Nutzer
selbst die Datenbank in der Hand hat, erfüllt keine revisionssichere Archivierung.
Das `audit_log` schafft Nachvollziehbarkeit im Alltag, ist aber keine
manipulationssichere Protokollierung im Sinne einer Verfahrensdokumentation. Für
eine Betriebsprüfung ist die App die **Vorerfassung**; die revisionssichere
Aufbewahrung findet in der Buchhaltung der Kanzlei statt. Die App sagt das in den
Einstellungen auch dem Nutzer.

## Registrierkassenpflicht Österreich – ausdrücklich nicht abgedeckt

Nach **RKSV** besteht Registrierkassenpflicht ab 15.000 € Jahresumsatz **und**
7.500 € Barumsätzen. Dazu gehören Signaturerstellungseinheit, Datenerfassungs-
protokoll, Belegprüfung über die BMF-App, Startbeleg und Jahresbelegmeldung.

**Diese App ist keine Registrierkasse und erfüllt die RKSV nicht.** Sie sagt das
in den Einstellungen unmissverständlich. Wer barvereinnahmende Umsätze über den
Grenzen hat, braucht zusätzlich eine registrierkassenpflichtige Lösung. Das
nachzubauen wäre ein eigenes Produkt mit Zertifizierungsaufwand – siehe
`docs/BACKLOG.md`, Abschnitt „Ausdrücklich nicht geplant".

## E-Rechnung – kommt, ist noch nicht gebaut

- **Deutschland:** Seit 1.1.2025 müssen Unternehmen strukturierte E-Rechnungen
  (XRechnung/ZUGFeRD nach EN 16931) **empfangen** können. Die Versandpflicht
  greift gestaffelt bis 2028.
- **Österreich:** Gegenüber Bundesstellen ist `ebInterface` bzw. Peppol Pflicht.

Die App erzeugt aktuell PDF. Für B2B-Rechnungen wird das mittelfristig nicht
genügen – Backlog G1. Ein PDF ist ausdrücklich **keine** E-Rechnung im Sinne der
Richtlinie.

## Kontenrahmen im Export

`lib/services/export/exporters.dart` verwendet SKR03-Konten und mappt sie für
Österreich auf den Einheitskontenrahmen. Beide Zuordnungen sind **Vorschläge**.
Jede Kanzlei bucht anders, deshalb ist die Kontonummer je Kategorie in den
Einstellungen überschreibbar, und die Export-Seite sagt dem Nutzer, dass er die
Zuordnung einmalig mit seiner Kanzlei abstimmen soll.

Der DATEV-Export schreibt Berater- und Mandantennummer als `0` in den Header – die
App kennt sie nicht. Das ist der übliche Weg: die Kanzlei ordnet den Stapel beim
Import ihrem Mandanten zu.

## Umsatzsteuervoranmeldung

Die App liefert **Bemessungsgrundlagen**, keine Meldung. Der Export
„Umsatzsteuer-Zusammenfassung" enthält steuerpflichtige Umsätze je Satz,
Vorsteuer je Satz und die daraus folgende Zahllast oder das Guthaben.

Bewusst **keine** automatische Übermittlung an FinanzOnline oder ELSTER: die UVA
ist eine Steuererklärung, für die der Unternehmer haftet. Eine App, die sie ohne
Prüfung abschickt, verlagert das Risiko an die falsche Stelle.
