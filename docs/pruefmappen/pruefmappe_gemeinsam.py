"""Gemeinsame Bausteine der Prüfmappen (Steuerberater, Rechtsanwalt).

Die Prüfpunkte werden bei jedem Lauf frisch aus docs/SPECIFICATION.md
Abschnitt 14 gelesen – die Mappe kann der Spezifikation nicht nachlaufen.
Aufruf aus dem Repository-Wurzelverzeichnis, siehe die beiden Skripte.
"""
import html
import re
from datetime import date

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (KeepTogether, Paragraph, Preformatted,
                                SimpleDocTemplate, Spacer, Table, TableStyle)

F = 'assets/fonts/'
pdfmetrics.registerFont(TTFont('WS', F + 'WorkSans-Regular.ttf'))
pdfmetrics.registerFont(TTFont('WSB', F + 'WorkSans-Bold.ttf'))
pdfmetrics.registerFontFamily('WS', normal='WS', bold='WSB', italic='WS', boldItalic='WSB')
try:  # Monoschrift mit Umlauten und Pfeilen für Textauszüge
    pdfmetrics.registerFont(TTFont('MONO', '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'))
    MONO = 'MONO'
except Exception:  # pragma: no cover
    MONO = 'Courier'

P = colors.HexColor('#12524E')
O = colors.HexColor('#F2A541')
GRAU = colors.HexColor('#444444')
h1 = ParagraphStyle('h1', fontName='WSB', fontSize=20, leading=24, textColor=P, spaceAfter=6)
h2 = ParagraphStyle('h2', fontName='WSB', fontSize=13, leading=17, textColor=P, spaceBefore=10, spaceAfter=5)
h3 = ParagraphStyle('h3', fontName='WSB', fontSize=10.5, leading=14, textColor=P, spaceBefore=6, spaceAfter=3)
b = ParagraphStyle('b', fontName='WS', fontSize=9.5, leading=13.5, spaceAfter=3)
sm = ParagraphStyle('sm', fontName='WS', fontSize=8.5, leading=11.5, textColor=GRAU)
cell = ParagraphStyle('c', fontName='WS', fontSize=8.5, leading=11)
cellb = ParagraphStyle('cb', fontName='WSB', fontSize=8.5, leading=11)
mono = ParagraphStyle('m', fontName=MONO, fontSize=7, leading=8.6)

KONTAKT = ('Jürgen Jesenko, Spirits by JeNiBarb e.U., Sankt Leonhard bei Siebenbrünn 96, '
           '9587 Arnoldstein, Österreich · office@jenibarb.com · +43 660 3124252')
STAND = date.today().strftime('%d.%m.%Y')


def inline(text):
    """Markdown-Zeile in reportlab-Absatzmarkup."""
    t = html.escape(text.strip(), quote=False)
    t = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', t)
    t = re.sub(r'~~(.+?)~~', r'\1', t)
    t = re.sub(r'`([^`]+)`', r'<font name="%s" size="8">\1</font>' % MONO, t)
    t = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'\1', t)
    return t


def pruefpunkte(spec='docs/SPECIFICATION.md'):
    """Alle Zeilen der Tabellen in Abschnitt 14: id -> dict."""
    text = open(spec, encoding='utf-8').read()
    teil = text[text.index('## 14. Prüfung in der realen Welt'):]
    out = {}
    for zeile in teil.splitlines():
        m = re.match(r'^\| (P-[A-Z]+\d+) \|', zeile)
        if not m:
            continue
        spalten = [s.strip() for s in zeile.strip().strip('|').split(' | ')]
        if len(spalten) < 5:
            continue
        pid, frage, vorbefund, vor, status = spalten[:5]
        out[pid] = dict(id=pid, frage=frage, vorbefund=vorbefund, vor=vor, status=status)
    return out


def offen(p):
    s = p['status'].lower()
    return not (s.startswith('erledigt') or s.startswith('bestätigt') or s.startswith('widerlegt'))


def _seite(canvas, doc, titel):
    canvas.saveState()
    canvas.setFont('WS', 7.5)
    canvas.setFillColor(GRAU)
    canvas.drawString(18 * mm, 10 * mm, f'{titel} · Stand {STAND} · JeNi bucht')
    canvas.drawRightString(A4[0] - 18 * mm, 10 * mm, f'Seite {doc.page}')
    canvas.setStrokeColor(O)
    canvas.setLineWidth(2)
    canvas.line(18 * mm, A4[1] - 12 * mm, A4[0] - 18 * mm, A4[1] - 12 * mm)
    canvas.restoreState()


def baue(pfad, titel, story):
    doc = SimpleDocTemplate(pfad, pagesize=A4, leftMargin=18 * mm, rightMargin=18 * mm,
                            topMargin=18 * mm, bottomMargin=18 * mm, title=titel,
                            author='Spirits by JeNiBarb e.U.')
    doc.build(story, onFirstPage=lambda c, d: _seite(c, d, titel),
              onLaterPages=lambda c, d: _seite(c, d, titel))


def tabelle(rows, widths, kopf=True):
    data = [[Paragraph(str(c), cellb if (kopf and i == 0) else cell) for c in r]
            for i, r in enumerate(rows)]
    t = Table(data, colWidths=[w * mm for w in widths], repeatRows=1 if kopf else 0)
    st = [('GRID', (0, 0), (-1, -1), 0.4, colors.HexColor('#BBBBBB')),
          ('VALIGN', (0, 0), (-1, -1), 'TOP'),
          ('LEFTPADDING', (0, 0), (-1, -1), 4), ('RIGHTPADDING', (0, 0), (-1, -1), 4)]
    if kopf:
        st.append(('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#E7F0EF')))
    t.setStyle(TableStyle(st))
    return t


def punkt_block(p, frage_zusatz=''):
    """Ein Prüfpunkt: Frage, was die App heute tut, Antwortfeld."""
    kopf = Table([[Paragraph(f'<b>{p["id"]}</b>', ParagraphStyle('k', parent=cellb, textColor=colors.white)),
                   Paragraph(f'benötigt vor: {inline(p["vor"])} · Status: {inline(p["status"])}',
                             ParagraphStyle('k2', parent=cell, textColor=colors.white))]],
                 colWidths=[22 * mm, 152 * mm])
    kopf.setStyle(TableStyle([('BACKGROUND', (0, 0), (-1, -1), P),
                              ('VALIGN', (0, 0), (-1, -1), 'MIDDLE')]))
    vb = p['vorbefund'] if p['vorbefund'] not in ('—', '-', '') else 'kein Vorbefund; noch nicht umgesetzt bzw. nicht entschieden'
    rows = [
        ['Frage', inline(p['frage']) + (f'<br/><b>{frage_zusatz}</b>' if frage_zusatz else '')],
        ['Was die App heute tut / Vorbefund (mit verwendeter Fundstelle)', inline(vb)],
        ['Antwort', 'Bestätigt ______ &nbsp;&nbsp; Nicht bestätigt ______ &nbsp;&nbsp; '
                    'Nur mit Änderung ______<br/><br/>Begründung / richtige Fundstelle / '
                    'Korrektur:<br/><br/><br/><br/>'],
    ]
    t = tabelle(rows, [40, 134], kopf=False)
    t.setStyle(TableStyle([('BACKGROUND', (0, 0), (0, -1), colors.HexColor('#F3F6F6')),
                           ('BACKGROUND', (1, 2), (1, 2), colors.HexColor('#FFF8EC'))]))
    return KeepTogether([kopf, t, Spacer(1, 7)])


def markdown_anhang(pfad, story, titel=None):
    """Markdown-Datei einfach gesetzt (Überschriften, Absätze, Listen, Tabellen)."""
    story.append(Paragraph(titel or pfad, h2))
    story.append(Paragraph(f'Quelle: <font name="{MONO}" size="8">{pfad}</font> (Wortlaut unverändert)', sm))
    absatz = []

    def flush():
        if absatz:
            story.append(Paragraph(inline(' '.join(absatz)), b))
            absatz.clear()

    for zeile in open(pfad, encoding='utf-8').read().splitlines():
        s = zeile.strip()
        if not s:
            flush()
            continue
        if s.startswith('#'):
            flush()
            story.append(Paragraph(inline(s.lstrip('#')), h3))
        elif s.startswith('|'):
            flush()
            if re.match(r'^\|[\s\-:|]+\|$', s):
                continue
            story.append(Paragraph(' · '.join(inline(c) for c in s.strip('|').split('|')), sm))
        elif re.match(r'^([-*]|\d+\.)\s', s):
            flush()
            story.append(Paragraph('• ' + inline(re.sub(r'^([-*]|\d+\.)\s', '', s)), b))
        elif s.startswith('>'):
            flush()
            story.append(Paragraph(inline(s.lstrip('> ')), sm))
        else:
            absatz.append(s)
    flush()


def code_anhang(pfad, story, von=1, bis=None, titel=None):
    zeilen = open(pfad, encoding='utf-8').read().splitlines()
    bis = bis or len(zeilen)
    story.append(Paragraph(titel or pfad, h3))
    story.append(Paragraph(f'Quelle: <font name="{MONO}" size="8">{pfad}</font>, Zeilen {von}–{bis} '
                           '(Programmtext; maßgeblich sind die Texte in Anführungszeichen)', sm))
    story.append(Preformatted('\n'.join(zeilen[von - 1:bis]), mono, maxLineLength=118))
    story.append(Spacer(1, 6))
