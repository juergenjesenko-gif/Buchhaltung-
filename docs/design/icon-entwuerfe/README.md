# App-Symbol „JeNi bucht“ – Entwürfe (2026-10-15)

Vier Entwürfe, je Ordner `vordergrund.svg` + `hintergrund.svg` (Android adaptive
icon, 108 dp, Motiv innerhalb der sicheren Zone Ø 66 dp), `ios.svg`
(1024 × 1024, vollflächig, keine Transparenz, keine eigenen Rundungen) und
`vorschau-1024.png`. `uebersicht.png`: alle Entwürfe in 192/96/48 px, Kreis- und
Squircle-Maske, auf hellem und dunklem Grund. Neu erzeugen: `python3 erzeugen.py`
(braucht `cairosvg`, `Pillow`). Kein Text außer Monogramm „J“ in Entwurf 2.

| # | Idee | Farben (Hex) | Kontrast | Stärken | Schwächen |
|---|---|---|---|---|---|
| 1 Beleg + Haken | Kassenbon mit Zackenkante, oranger Haken-Knopf | Grund `#12524E` Petrol, Bon `#FFF8EE`, Zeilen `#9DB7B3`, Haken `#F2A541` | Bon/Grund 8,5:1; Orange/Grund 4,4:1 | sofort „Beleg erledigt“, bei 48 px klar, warm durch Orange | Beleg-Motiv ist im Genre verbreitet; Textzeilen bei 48 px nur angedeutet |
| 2 „J“ + Auslöser | Kamera-Auslöser (Ring + Knopf) mit „J“ | Grund `#4A2545` Aubergine, Ring `#FFFFFF`, Knopf `#FF8A6B` Koralle | Ring/Grund 12,8:1; Koralle/Grund 5,5:1; Weiß/Koralle 2,3:1 (nur Form, „J“ ist groß) | eigenständig, persönlich, zeigt Kernfunktion Fotografieren | wirkt eher wie Kamera-App, Bezug zu Buchhaltung fehlt; „J“ auf Koralle schwächer |
| 3 Beleg + Herz | Sprechblasen-Beleg mit Herz | Grund `#FFF1E6` Creme, Form `#C8553D` Terrakotta | 3,9:1 | am wärmsten und persönlichsten, sehr einfach | auf hellem Startbildschirm verschwindet der Rand; Herz + Sprechblase erinnert an Dating-/Messenger-Apps, wenig „vertrauenswürdig“ |
| 4 Notizbuch + Haken | Kassabuch mit Rücken, großer Haken | Grund `#3E6B48` Salbeigrün, Buch `#FBF3E4`, Rücken `#E0A526` Senf | Buch/Grund 5,6:1; Senf/Grund 2,8:1 (Zierde) | ruhig, ordentlich, bei 48 px am robustesten | Grün + Haken ähnelt Aufgaben-Apps; weniger eigen |

Abgrenzung: keine Euro-Münze, kein Säulen-/Bankgebäude, kein Text-Logo; Farbwelten
weichen vom Blau/Türkis typischer Finanz-Apps (Lexoffice, sevDesk, Wise, Revolut)
ab. Eine Markenrecherche ist damit nicht ersetzt.

**Empfehlung: Entwurf 1 (Beleg + Haken).** Er sagt ohne Erklärung, was die App
tut, bleibt bei 48 px in beiden Masken eindeutig, wirkt durch Petrol + Orange warm
und zugleich seriös. Ausbaumöglichkeit: das „J“ aus Entwurf 2 dezent als
Monogramm auf den Bon statt der Zeilen setzen. Endgültige Freigabe: Auftraggeber;
Sichtprüfung auf echtem Gerät steht noch aus.
