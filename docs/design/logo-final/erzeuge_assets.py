"""Erzeugt alle Logo- und Symbol-Dateien aus app-icon.svg und
hauptlogo-willkommen.png (DESIGN_SPEC 10a). Aufruf aus dem Repo-Wurzelordner:

    python3 docs/design/logo-final/erzeuge_assets.py

Braucht cairosvg und Pillow. Nach Lieferung der Originale der Designerin
nur app-icon.svg bzw. das Hauptlogo ersetzen und neu erzeugen.
"""
import io
import json
import os

import cairosvg
from PIL import Image, ImageDraw

SRC = 'docs/design/logo-final'
NAVY = (11, 58, 103)
HELL = (234, 242, 255)
RES = 'android/app/src/main/res'
IOS = 'ios/Runner/Assets.xcassets'


def svg(width):
    text = open(f'{SRC}/app-icon.svg', encoding='utf-8').read()
    png = cairosvg.svg2png(bytestring=text.encode(), output_width=width,
                           output_height=width)
    return Image.open(io.BytesIO(png)).convert('RGB')


def glyph_alpha(size):
    """Weiße Glyphe als Alphamaske (Navy-Details werden durchsichtig)."""
    im = svg(size).convert('L')
    lo = 0.299 * NAVY[0] + 0.587 * NAVY[1] + 0.114 * NAVY[2]
    return im.point(lambda v: max(0, min(255, round((v - lo) * 255 / (255 - lo)))))


def glyph_on(canvas, content, color=(255, 255, 255)):
    """Glyphe (Inhalt 618/1024 des SVG) auf content px skaliert, zentriert."""
    full = round(content * 1024 / 618)
    a = glyph_alpha(full * 2).resize((full, full), Image.LANCZOS)
    layer = Image.new('RGBA', (canvas, canvas), color + (0,))
    solid = Image.new('RGBA', (full, full), color + (255,))
    solid.putalpha(a)
    # Glyphenmitte im SVG liegt bei (512, 512).
    layer.alpha_composite(solid, ((canvas - full) // 2, (canvas - full) // 2))
    return layer


def rounded(size, radius_ratio=0.22):
    big = svg(size * 2).convert('RGBA')
    mask = Image.new('L', (size * 2, size * 2), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size * 2 - 1, size * 2 - 1), radius=round(size * 2 * radius_ratio), fill=255)
    big.putalpha(mask)
    return big.resize((size, size), Image.LANCZOS)


def main():
    # Android: klassische Symbole (abgerundet, transparent außen)
    dens = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
    for d, f in dens.items():
        os.makedirs(f'{RES}/mipmap-{d}', exist_ok=True)
        rounded(round(48 * f)).save(f'{RES}/mipmap-{d}/ic_launcher.png')
        # Adaptiv: Vordergrund 108 dp, Glyphe 50 dp (sichere Zone 66 dp)
        fg = glyph_on(round(108 * f), round(50 * f))
        fg.save(f'{RES}/mipmap-{d}/ic_launcher_foreground.png')
        mono = glyph_on(round(108 * f), round(50 * f), (0, 0, 0))
        mono.save(f'{RES}/mipmap-{d}/ic_launcher_monochrome.png')
        # Startbildschirm: Symbol 96 dp
        rounded(round(96 * f)).save(f'{RES}/mipmap-{d}/launch_image.png')
    # Store-/Designer-Exporte
    glyph_on(432, 200).save(f'{SRC}/android-adaptiv-vordergrund-432.png')
    Image.new('RGB', (432, 432), NAVY).save(f'{SRC}/android-adaptiv-hintergrund-432.png')
    glyph_on(432, 200, (0, 0, 0)).save(f'{SRC}/android-einfarbig-432.png')
    svg(512).save(f'{SRC}/play-store-512.png')
    # iOS: ohne Alpha, volle Fläche (iOS rundet selbst)
    contents = json.load(open(f'{IOS}/AppIcon.appiconset/Contents.json'))
    for img in contents['images']:
        pts = float(img['size'].split('x')[0])
        px = round(pts * int(img['scale'][0]))
        svg(px).save(f'{IOS}/AppIcon.appiconset/{img["filename"]}')
    # iOS-Startbildschirm: Symbol 120 pt
    for s, name in [(1, 'LaunchImage.png'), (2, 'LaunchImage@2x.png'), (3, 'LaunchImage@3x.png')]:
        rounded(120 * s).save(f'{IOS}/LaunchImage.imageset/{name}')
    # Splash nach Blatt: 1152 px, Hellblau, Symbol mittig
    sp = Image.new('RGBA', (1152, 1152), HELL + (255,))
    ic = rounded(480)
    sp.alpha_composite(ic, (336, 336))
    sp.convert('RGB').save(f'{SRC}/splash-1152.png')

    # Hauptlogo Willkommensseite: Rand weg, weiß -> transparent
    src = Image.open(f'{SRC}/hauptlogo-willkommen.png').convert('RGB')
    gray = src.convert('L')
    a = gray.point(lambda v: max(0, min(255, round((250 - v) * 255 / (250 - 50)))))
    box = a.point(lambda v: 255 if v > 24 else 0).getbbox()
    pad = 8
    box = (max(0, box[0] - pad), max(0, box[1] - pad),
           min(src.width, box[2] + pad), min(src.height, box[3] + pad))
    a = a.crop(box)
    os.makedirs('assets/brand/2.0x', exist_ok=True)
    os.makedirs('assets/brand/3.0x', exist_ok=True)
    for color, name in [(NAVY, 'logo.png'), (HELL, 'logo_dark.png')]:
        im = Image.new('RGBA', a.size, color + (255,))
        im.putalpha(a)
        for scale, folder in [(1, 'assets/brand'), (2, 'assets/brand/2.0x'), (3, 'assets/brand/3.0x')]:
            w = 280 * scale
            h = round(a.height * w / a.width)
            im.resize((w, h), Image.LANCZOS).save(f'{folder}/{name}', optimize=True)
    print('Seitenverhältnis Hauptlogo', a.width, a.height)


if __name__ == '__main__':
    main()
