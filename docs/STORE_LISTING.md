# Store-Einträge

Textvorlagen für Google Play und den App Store. Deutsch, weil die Zielgruppe
Österreich und Deutschland ist.

## Name

Platzhalter **Buchhaltung** (30 Zeichen Limit bei Google Play). Arbeitstitel
„Jenny Bar“ bzw. „Jenni bucht“; der endgültige Name folgt erst nach der
Markenrecherche (Lastenheft O-2, O-25; Spezifikation 14, P-R7).

## Kurzbeschreibung (Google Play, max. 80 Zeichen)

```
Belege fotografieren, Rechnungen schreiben, Export für den Steuerberater.
```

## Untertitel (App Store, max. 30 Zeichen)

```
Belege, Rechnungen, Export
```

## Vollständige Beschreibung

```
Buchhaltung für Einzelunternehmer und Kleinunternehmer in Österreich und
Deutschland. Ohne Konto beim Anbieter, deine Daten bleiben auf dem Gerät.

BELEGE STATT SCHUHKARTON
Beleg abfotografieren – Betrag, Datum, Steuersatz und Händler schlägt die App
vor, auch aus dem QR-Code der Registrierkasse. Mehrere Steuersätze auf einem
Beleg, Belege in fremder Währung, PDF- und E-Rechnungen (XRechnung, ZUGFeRD,
ebInterface) per Teilen übernehmen. Alles bleibt durchsuchbar, nach Monaten
geordnet.

VERKÄUFE AUF PLATTFORMEN
Monatsberichte von Amazon, PayPal, Shopify und Stripe teilen – die App fasst
Verkäufe, Gebühren und Auszahlungen je Monat zusammen.

DEINE ZAHLEN JEDERZEIT
Einnahmen, Ausgaben und Ergebnis für Monat, Quartal oder Jahr. Umsatzsteuer je
Satz, Vorsteuer und die daraus folgende Zahllast auf einen Blick.

KLEINUNTERNEHMERGRENZE IM AUGE
Die App kennt die unterschiedlichen Regeln in Österreich (55.000 € mit
10-%-Toleranz) und Deutschland (25.000 € Vorjahr, 100.000 € laufendes Jahr) und
warnt rechtzeitig, bevor es eng wird.

RECHNUNGEN, DIE HALTEN
Kunden einmal anlegen, Positionen erfassen, fertig. Die App prüft die
Pflichtangaben nach § 11 UStG bzw. § 14 UStG mit – auch das Leistungsdatum, das
am häufigsten fehlt. Kleinunternehmer bekommen automatisch den vorgeschriebenen
Hinweistext statt einer Umsatzsteuerzeile. Rabatt, Skonto und Versandkosten,
Zahlungserinnerung und Mahnung. Als PDF direkt aus der App verschicken.

ÜBERGABE AN DIE KANZLEI
Belegliste als CSV, DATEV-Buchungsstapel für Deutschland, BMD-Format für
Österreich, dazu eine Umsatzsteuer-Zusammenfassung mit allen
Bemessungsgrundlagen. Zeitraum wählen, Vorschau prüfen, teilen.

DEINE DATEN BLEIBEN DEINE
Alles liegt auf deinem Gerät. Kein Server, kein Nutzerkonto, keine Werbung, keine
Analyse. Daten verlassen das Telefon nur, wenn du selbst teilst, sicherst, eine
UID-Nummer prüfen lässt, einen Wechselkurs abrufst oder eine Rechnung über
einen QR-Link lädst. App-Sperre mit PIN oder Fingerabdruck.

Hinweis: Diese App unterstützt bei der Buchhaltung, ist aber keine
Steuerberatung und keine Registrierkasse nach RKSV.
```

## Kategorie

Finanzen / Wirtschaft

## Suchbegriffe (App Store, max. 100 Zeichen)

```
buchhaltung,belege,rechnung,kassabuch,kleinunternehmer,umsatzsteuer,eür,datev,bmd
```

## Grafiken – was gebraucht wird

| Asset | Google Play | App Store |
|---|---|---|
| App-Icon | 512×512 PNG | 1024×1024 PNG, ohne Alphakanal |
| Feature-Grafik | 1024×500 | – |
| Screenshots Telefon | min. 2, 16:9 oder 9:16 | 6,7" und 6,5" je min. 3 |
| Screenshots Tablet | optional | nur bei iPad-Unterstützung |

### Screenshot-Reihenfolge

Die ersten zwei entscheiden über die Installation:

1. **Dashboard** mit gefüllten Zahlen und der Kleinunternehmer-Ampel
2. **Belegerfassung** mit Belegfoto und der Netto-/USt-Aufschlüsselung
3. **Rechnungs-PDF**
4. **Belegliste** mit Monatsgruppierung
5. **Export** mit Formatauswahl

Für die Aufnahmen realistische, aber erfundene Daten verwenden – keine echten
Kundennamen oder Beträge.

## Datensicherheit / App-Datenschutz

Die App enthält keine Analyse- oder Werbe-SDKs. **Eigene Netzwerkverbindungen**
sind die UID-Prüfung über VIES (auf Tippen oder nach Opt-in wöchentlich gehen
UID-Nummern direkt an die EU-Kommission, nicht an den Anbieter) und der
**EZB-Kursabruf** (nur auf Tippen „Kurs abrufen“: Download einer öffentlichen
Kursdatei von ecb.europa.eu; es werden keine Nutzerdaten gesendet, nur
IP-Adresse/Verbindungsdaten – kein „Teilen“ im Sinne von Google Data Safety
oder Apple Privacy Label, da keine Daten aus der App erhoben werden; P-R18). Google Data
Safety: „Finanzinformationen – andere“, geteilt mit Dritten, verschlüsselt
übertragen, für die App-Funktion, vom Nutzer ausgelöst. Apple: „Sonstige
Finanzinfos“, nicht verknüpft, App-Funktionalität (Prüfpunkt P-U4).
**Belegerkennung (nur Android):** die eingebundene Bibliothek Google ML Kit
(Text- und Barcode-Erkennung, gebündelt)
sendet Nutzungs- und Diagnosedaten an Google (keine Fotos, kein Text). Google
Data Safety daher zusätzlich: „App-Info und -Leistung – Absturzprotokolle /
Diagnosedaten“, **geteilt mit Google**, verschlüsselt übertragen, nicht
löschbar über die App, Zweck Analyse/App-Funktion – genaue Einordnung zu
prüfen (P-R19, P-D21). Apple: Vision überträgt nichts, keine Angabe nötig.
**Rechnung über Link-QR** (nur auf Tippen „Laden“): Abruf der Adresse aus
dem QR-Code beim Server des Rechnungsausstellers; gesendet werden nur Adresse,
IP-Adresse und Verbindungsdaten, keine Nutzerdaten aus der App. Wie beim
EZB-Abruf voraussichtlich keine „Erhebung“ im Sinne von Google Data Safety
bzw. Apple Privacy Label; Einordnung zu prüfen (P-R35).
Alles andere bleibt auf dem Gerät, und Androids Auto-Backup ist
per `data_extraction_rules.xml` deaktiviert. Die Datensicherung ist eine von
der Nutzerin ausgelöste, mit ihrem Kennwort verschlüsselte Datei, die sie selbst
über den Teilen-Dialog oder – automatisch nach Opt-in – in einem selbst
gewählten Ordner ablegt; sie erreicht weder den Anbieter noch einen
Partner und gilt daher nicht als Datenerhebung.

## Altersfreigabe

Ohne Einschränkung. Keine nutzergenerierten Inhalte, keine Interaktion zwischen
Nutzern. Heute keine Käufe; mit dem Abo (Lastenheft 5.22) In-App-Käufe angeben.

## Werbe-Negativliste

Vor jeder Änderung von Store-Text, Screenshots oder Produktseite prüfen
(Lastenheft L-22.20, Prüfpunkt P-R13). Nicht verwenden:

- „finanzamtssicher", „rechtssicher", „100 % korrekt"
- „GoBD-zertifiziert", „GoBD-konform", „zertifiziert", „geprüft" – es gibt kein staatliches Zertifikat
- „ersetzt den Steuerberater", „Steuerberatung", „Steuerexperte in der Tasche"
- „Vorsteuer abziehbar", „Rechnung mit UID" für die Abo-Zahlung (P-S12)
- „immer aktuell", „garantiert aktuell" (L-20.23)
- „kostenlos" ohne Folgepreis nach dem Test
- Streichpreise ohne den niedrigsten Preis der letzten 30 Tage (PAngV)
- Vergleiche mit namentlich genannten Mitbewerbern ohne Prüfung nach § 6 UWG
- „Finanzamt", „ELSTER", „FinanzOnline" als Teil des App-Namens

Pflicht im Store-Text: der Hinweis „Keine Steuerberatung – ersetzt keine
steuerliche Beratung".
