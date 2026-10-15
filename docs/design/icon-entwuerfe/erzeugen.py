"""Erzeugt SVGs und PNG-Vorschauen der App-Symbol-Entwürfe. Aufruf: python3 erzeugen.py"""
import io, os, cairosvg
from PIL import Image, ImageDraw
D = os.path.dirname(os.path.abspath(__file__))
H = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108" width="108" height="108">'
E = [
 ("1-beleg-haken", "#12524E",
  '<path d="M36 26h36v52l-6-4-6 4-6-4-6 4-6-4-6 4z" fill="#FFF8EE"/>'
  '<path d="M43 37h22M43 45h22M43 53h12" stroke="#9DB7B3" stroke-width="4" stroke-linecap="round"/>'
  '<circle cx="68" cy="68" r="13" fill="#F2A541"/>'
  '<path d="M62 68l4.5 4.5 8-9" fill="none" stroke="#12524E" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round"/>'),
 ("2-j-ausloeser", "#4A2545",
  '<circle cx="54" cy="54" r="30" fill="none" stroke="#FFFFFF" stroke-width="5"/>'
  '<circle cx="54" cy="54" r="22" fill="#FF8A6B"/>'
  '<path d="M60 41v15a8 8 0 0 1-16 0" fill="none" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round"/>'),
 ("3-beleg-herz", "#FFF1E6",
  '<path d="M34 28a6 6 0 0 1 6-6h28a6 6 0 0 1 6 6v36a6 6 0 0 1-6 6H50l-12 10v-10a6 6 0 0 1-4-6z" fill="#C8553D"/>'
  '<path d="M54 60c-9-6-14-10.5-14-16a7 7 0 0 1 14-2 7 7 0 0 1 14 2c0 5.5-5 10-14 16z" fill="#FFF1E6"/>'),
 ("4-notizbuch-haken", "#3E6B48",
  '<rect x="32" y="24" width="44" height="60" rx="5" fill="#FBF3E4"/>'
  '<rect x="32" y="24" width="10" height="60" rx="3" fill="#E0A526"/>'
  '<path d="M49 55l7 7 13-15" fill="none" stroke="#3E6B48" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>'),
]
def png(svg, s): return Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode(), output_width=s, output_height=s))).convert("RGBA")
ios = {}
for name, bg, fg in E:
    p = os.path.join(D, name); os.makedirs(p, exist_ok=True)
    files = {"vordergrund.svg": H+fg+'</svg>',
             "hintergrund.svg": H+f'<rect width="108" height="108" fill="{bg}"/></svg>',
             # iOS: vollflächig, ohne Transparenz, Motiv etwas größer (Ausschnitt 12..96)
             "ios.svg": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="12 12 84 84" width="1024" height="1024">'
                        f'<rect x="0" y="0" width="108" height="108" fill="{bg}"/>'+fg+'</svg>'}
    for f, c in files.items(): open(os.path.join(p, f), "w").write(c+"\n")
    im = png(files["ios.svg"], 1024).convert("RGB"); im.save(os.path.join(p, "vorschau-1024.png"))
    ios[name] = (files, im)
# Übersicht: Zeilen = Entwürfe; Spalten = hell/dunkel x Kreis/Squircle x 192/96/48
def mask(s, kind):
    m = Image.new("L", (s*4, s*4), 0); d = ImageDraw.Draw(m)
    (d.ellipse if kind == "kreis" else lambda b, fill: d.rounded_rectangle(b, radius=int(s*4*.3), fill=fill))((0, 0, s*4-1, s*4-1), fill=255)
    return m.resize((s, s), Image.LANCZOS)
sizes, pad = [192, 96, 48], 24
cell = sum(sizes)+pad*4
W, Hh = cell*4, (192+pad*2)*len(E)
out = Image.new("RGB", (W, Hh))
for ci, (theme, kind) in enumerate([(t, k) for t in ("#F5F5F5", "#1C1B1F") for k in ("kreis", "squircle")]):
    ImageDraw.Draw(out).rectangle((ci*cell, 0, (ci+1)*cell, Hh), fill=theme)
    for ri, (name, bg, fg) in enumerate(E):
        x = ci*cell+pad
        for s in sizes:
            # Android: Vordergrund + Hintergrund auf 108 dp, Maske zeigt die mittleren 72 dp
            svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="18 18 72 72">'+f'<rect width="108" height="108" fill="{bg}"/>'+fg+'</svg>'
            out.paste(png(svg, s), (x, ri*(192+pad*2)+pad+(192-s)//2), mask(s, kind)); x += s+pad
out.save(os.path.join(D, "uebersicht.png"))
