# Marketing mehrsprachig – Regeln für Website, Instagram und TikTok

Stand: 2026-10-27 · Gilt für den Marketing-Chat „JeNi bucht“ und für die Entwicklung.
Entscheidungen: `docs/MAERKTE.md`. Rechtliche Prüfpunkte nur in `docs/SPECIFICATION.md` Abschnitt 14 (P-R80, P-UK-04, P-UK-05, P-FR-01).

## 1. Wer spricht welche Sprache

| Kanal | Deutsch (AT/DE) | Englisch (UK, später IE/US) | Französisch (FR) |
|---|---|---|---|
| Produktname | **JeNi bucht** | **JeNi books** | **JeNi books** |
| Website | jenibucht.com | jenibucht.com/en/ | jenibucht.com/fr/ |
| Weiterleitung | – | jenibooks.com → /en/ | jenibooks.com → /fr/ (später, nach Browsersprache) |
| Instagram | @jeni.bucht | @jeni.books.app | – (kein Kanal) |
| TikTok | @jeni.bucht | @jeni.books.app | – (kein Kanal) |
| App/Store | Deutsch | Englisch (en-GB zuerst) | Französisch |

**Schreibweise:** immer „JeNi bucht“ bzw. „JeNi books“ – J und N groß, „bucht“/„books“ klein. Nie „Jeni“, „JENI“, „JeNi Books“.

**Französisch** gibt es nur auf Website und in der App. Social Media bleibt Deutsch und Englisch – eine dritte Sprache ist nicht zu stemmen.

## 2. Grundregel für Bilder und Videos: einmal produzieren, Sprache getrennt

Ab sofort gilt für jedes neue Bild und Video:

1. **Kein Text im Bild/Video eingebrannt** – außer dem KI-Hinweis (siehe 4).
2. **Untertitel als eigene Datei** je Sprache (WebVTT `.vtt`), nicht ins Video gerendert.
3. **Überschriften/Zitate auf Bildern** als eigene Ebene (Canva-Textebene), damit pro Sprache nur der Text getauscht und neu exportiert wird.
4. **Voiceover** mit derselben KI-Stimme in DE und EN (Skript in beiden Sprachen); FR nur, falls das Video auf die französische Website soll.
5. **Szene, Schnitt, Musik sind sprachneutral** – nur Text und Stimme ändern sich.

### Bestehende Medien (Stand 2026-10-25)

Die 10 Reels und Rollenbilder auf der Website haben **deutsche Texte eingebrannt** („Wohin mit dem Kassenbon?“). Für `/en/` und `/fr/`:

- Aus den Projektdateien **ohne Textebene neu exportieren**, Texte als Untertitel bzw. neue Textebene in EN/FR.
- Wo das nicht geht: Video neu rendern mit übersetztem Text.
- Bis dahin auf `/en/` und `/fr/` nur Videos zeigen, deren Text nicht deutsch ist – oder ohne Videos starten.

## 3. Dateinamen (Übergabe an die Entwicklung)

```
video/reel_<thema>.mp4            Video ohne Text (eine Datei für alle Sprachen)
video/reel_<thema>.de.vtt         Untertitel deutsch
video/reel_<thema>.en.vtt         Untertitel englisch
video/reel_<thema>.fr.vtt         Untertitel französisch (nur Website)
video/reel_<thema>.webp           Vorschaubild ohne Text
img/social/<motiv>_<sprache>.png  Bild mit Text je Sprache, z. B. elektrikerin_1_en.png
```

Sprachkürzel: `de`, `en`, `fr`. Format Video 1080×1920 MP4 (H.264), Bild 1080×1350 oder 1080×1920. Die Entwicklung verkleinert und bindet selbst ein – keine Links auf fremde Speicher (CDN), Dateien direkt übergeben.

## 4. Pflichthinweise je Sprache (KI-Figur, erfundene Rollen)

In jedem Bild/Video mit JeNi **eingeblendet** (das einzige eingebrannte Textelement) und in der Bildunterschrift:

| Sprache | Einblendung | Bildunterschrift / Website |
|---|---|---|
| DE | „KI-Figur · Rolle erfunden“ | „JeNi ist eine KI-Figur, ihre Berufsrollen sind erfunden. Bilder und Videos mit KI erstellt.“ |
| EN | „AI character · fictional role“ | “JeNi is an AI character; her job roles are fictional. Images and videos made with AI.” |
| FR | „Personnage IA · rôle fictif“ | « JeNi est un personnage créé par IA ; ses métiers sont fictifs. Images et vidéos générées par IA. » |

Zusätzlich das KI-Label der Plattform (Meta „KI-Info“, TikTok „AI-generated“) setzen. Werbung als Werbung kennzeichnen, wie im deutschen Kanal. Ob das für UK (ASA/CAP) genügt: P-R80 / P-UK-04.

## 5. Was in englischen und französischen Texten NICHT stehen darf

Gleiche Negativliste wie `docs/STORE_LISTING.md` „Werbe-Negativliste“, zusätzlich:

| Nicht verwenden | Warum |
|---|---|
| „MTD-ready“, „HMRC-recognised“, „HMRC approved“ | erst nach Eintrag in HMRCs Softwareliste (P-UK-01) |
| „does your tax return“, „replaces your accountant“, „tax advice“ | keine Steuerberatung |
| „compliant with e-invoicing“, „conforme facturation électronique 2027“ | erst mit Plattform-Vertrag und Prüfung (P-FR-01) |
| „available in the UK / disponible en France“ | erst wenn die App dort im Store ist |
| „free“ / „gratuit“ ohne Folgepreis | wie DE: immer mit Preis nach dem Test |
| US-Steuerbegriffe („Schedule C ready“) | USA wird nicht aktiv beworben |

Bis die UK-Version fertig ist, zeigt @jeni.books.app **Marke und Alltag** (Belege fotografieren, Ordnung), **keine UK-Funktionen**.

## 6. Länder-Details in Texten und Bildern

| | UK | IE | US | FR |
|---|---|---|---|---|
| Englisch | britisch (receipt, colour, organise) | britisch | später amerikanisch | – |
| Währung | £ | € | $ | € |
| Datum | 27/10/2026 | 27/10/2026 | 10/27/2026 | 27/10/2026 |
| Begriffe | self-employed, sole trader, Self Assessment | sole trader | freelancer | micro-entrepreneur, auto-entrepreneur |
| Musterbelege im Bild | britische Belege (VAT, £) | – | – | französische Belege (TVA, €) |

Ein Musterbeleg mit „USt 20 %“ gehört nicht auf `/en/` oder `/fr/`.

## 7. Ablauf je neuem Beitrag (Checkliste)

1. Szene/Bild ohne Text erstellen.
2. Skript DE + EN schreiben (FR nur für Website-Videos).
3. Voiceover DE + EN mit derselben Stimme.
4. Untertitel `.de.vtt` / `.en.vtt` erzeugen (Plattform-Auto-Untertitel nur als Notlösung).
5. Für Instagram/TikTok: je Sprache exportieren mit eingebranntem KI-Hinweis der jeweiligen Sprache, Caption in der jeweiligen Sprache.
6. Negativliste (Abschnitt 5) gegen Caption und Einblendung prüfen.
7. Website-Material nach Abschnitt 3 benennen und der Entwicklung übergeben.

Ziel: höchstens 1–1,5 Stunden Mehraufwand pro Woche für die zweite Sprache.

## 8. Website-Umsetzung (Entwicklung)

- `tool/site/build_site.py` erzeugt aus je einer Textdatei pro Sprache `/`, `/en/`, `/fr/`; Bilder/Videos gemeinsam, Untertitel über `<track>`.
- `hreflang` (de, en, fr, x-default) und Sprachumschalter DE | EN | FR.
- Rechtstexte (Impressum, Datenschutz, Nutzungsbedingungen) je Sprache; FR-Texte rechtlich prüfen (P-FR-01).
- jenibooks.com: 301-Weiterleitung beim Hoster.
