# Übergabe an Marketing: App-Store-Produktseite (Header und Suchansicht)

Stand 2026-10-29 · von Entwicklung (Claude Code) an Claude-Projekt „JeNi bucht“

## Worum es geht

App Store Connect bietet seit Kurzem unter **Product Page Information →
Header and Search Results** zwei neue Flächen:

| Fläche | Wo sichtbar | Was wir brauchen |
|---|---|---|
| **Header** | ganz oben auf der App-Store-Seite von JeNi bucht | ein Bild oder ein kurzes Video im Markenstil |
| **Search Results** | Darstellung in der App-Store-Suche | Auswahl und Reihenfolge der ersten Screenshots |

Beides ist optional. Es soll mit dem **nächsten iOS-Update** hochgeladen
werden, nicht mit 0.39.4 (die ist in Prüfung und wird nicht mehr geändert).

**Maße, Formate und Dateigrößen** zeigt Apple erst im Upload-Feld an. Der
Auftraggeber schickt davon einen Screenshot nach. Bis dahin bitte nur das
Konzept und die Entwürfe erstellen, noch keine fertigen Exporte.

## Header – Briefing

- **Ziel:** in einer Sekunde klar machen, was die App tut. Kernbotschaft:
  „Beleg scannen. Zack, gebucht.“ (wie auf jenibucht.com).
- **Motiv:** JeNi mit Smartphone, ein Beleg wird fotografiert. Oder die App
  im Gerät mit Übersicht und Ampel (Screens unter `docs/site/img/app/`).
- **Text im Bild:** höchstens 5 Wörter, auf Deutsch (für AT/DE). Englisch
  und Französisch bekommen später eigene Fassungen mit eigenem Text im Bild
  (Regel aus `docs/maerkte/Marketing_Mehrsprachig.md`).
- **KI-Kennzeichnung:** JeNi ist eine KI-generierte Kunstfigur. Wenn sie im
  Header vorkommt, gilt dieselbe Kennzeichnung wie auf Instagram.
- **Daten im Bild:** nur erfundene Demo-Daten (P-R56), keine echten Namen,
  UID-Nummern oder Händler.

## Suchansicht – Vorschlag Reihenfolge

Die ersten Screenshots entscheiden in der Suche über den Klick. Vorschlag
nach `docs/STORE_LISTING.md` („Screenshot-Reihenfolge“):

1. Übersicht mit Zahlen und Kleinunternehmer-Ampel
2. Beleg bearbeiten mit Foto und „erkannt – bitte prüfen“
3. Rechnungs-PDF bzw. E-Rechnung

Je Screenshot eine Überschrift, höchstens fünf Wörter.

## Pflichtregeln (nicht verhandelbar)

Werbe-Negativliste aus `docs/STORE_LISTING.md` gilt, insbesondere **nicht**:

- „finanzamtssicher“, „rechtssicher“, „100 % korrekt“
- „GoBD-zertifiziert/-konform“, „zertifiziert“, „geprüft“
- „ersetzt den Steuerberater“, „Steuerberatung“
- „immer aktuell“, „garantiert aktuell“
- „kostenlos“ ohne Folgepreis; keine Streich- oder „statt“-Preise
- Mitbewerber namentlich

Preise und Abo-Angaben gehören **nicht** in den Header (Apple zeigt sie
selbst an).

## Lieferung zurück an die Entwicklung

1. Header: Entwurf als PNG/JPG (bzw. MP4), Dateiname
   `appstore_header_de_v1.png`
2. Liste der drei Screenshots für die Suchansicht in der gewünschten
   Reihenfolge mit Überschriften
3. Kurze Notiz, ob JeNi vorkommt (für die KI-Kennzeichnung)

Die Entwicklung prüft gegen die Negativliste (Prüfinstanzen Rechtsanwalt und
UX) und lädt mit dem nächsten Update hoch.
