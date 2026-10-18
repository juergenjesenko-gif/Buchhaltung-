"""Erzeugt docs/Laenderanalyse.pdf aus docs/LAENDERANALYSE.md (Work Sans).

Aufruf im Repository-Wurzelordner: python3 docs/laenderanalyse_pdf.py
"""
import re
from reportlab.lib.pagesizes import A4, landscape
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib import colors
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

F = 'assets/fonts/'
pdfmetrics.registerFont(TTFont('WS', F + 'WorkSans-Regular.ttf'))
pdfmetrics.registerFont(TTFont('WSB', F + 'WorkSans-Bold.ttf'))
pdfmetrics.registerFontFamily('WS', normal='WS', bold='WSB', italic='WS', boldItalic='WSB')
P = colors.HexColor('#12524E')
h1 = ParagraphStyle('h1', fontName='WSB', fontSize=20, leading=24, textColor=P, spaceAfter=6)
h2 = ParagraphStyle('h2', fontName='WSB', fontSize=13, leading=16, textColor=P, spaceBefore=10, spaceAfter=4)
h3 = ParagraphStyle('h3', fontName='WSB', fontSize=11, leading=14, textColor=P, spaceBefore=8, spaceAfter=3)
b = ParagraphStyle('b', fontName='WS', fontSize=9.5, leading=13.5, spaceAfter=4)
cell = ParagraphStyle('c', fontName='WS', fontSize=7.5, leading=9.5)
cellb = ParagraphStyle('cb', fontName='WSB', fontSize=7.5, leading=9.5)


def inline(t):
    t = t.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
    t = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', t)
    t = re.sub(r'\*(.+?)\*', r'\1', t)
    t = re.sub(r'`(.+?)`', r'\1', t)
    t = re.sub(r'\[(.+?)\]\((.+?)\)', r'\1', t)
    return t


def tabelle(rows, breite):
    n = len(rows[0])
    data = [[Paragraph(inline(c), cellb if i == 0 else cell) for c in r] for i, r in enumerate(rows)]
    t = Table(data, colWidths=[breite / n] * n, repeatRows=1)
    t.setStyle(TableStyle([('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#E7F0EF')),
                           ('GRID', (0, 0), (-1, -1), 0.4, colors.HexColor('#BBBBBB')),
                           ('VALIGN', (0, 0), (-1, -1), 'TOP'),
                           ('LEFTPADDING', (0, 0), (-1, -1), 3), ('RIGHTPADDING', (0, 0), (-1, -1), 3)]))
    return t


def main():
    seite = landscape(A4)
    breite = seite[0] - 30 * mm
    story, rows, absatz = [], [], []

    def flush():
        nonlocal rows, absatz
        if rows:
            story.append(tabelle(rows, breite)); story.append(Spacer(1, 4)); rows = []
        if absatz:
            story.append(Paragraph(inline(' '.join(absatz)), b)); absatz = []

    for z in open('docs/LAENDERANALYSE.md', encoding='utf-8').read().splitlines():
        s = z.strip()
        if s.startswith('|'):
            if absatz:
                story.append(Paragraph(inline(' '.join(absatz)), b)); absatz = []
            if re.match(r'^\|[-| ]+\|$', s):
                continue
            rows.append([c.strip() for c in s.strip('|').split('|')])
            continue
        if not s:
            flush(); continue
        if s.startswith('#'):
            flush()
            lvl = len(s) - len(s.lstrip('#'))
            story.append(Paragraph(inline(s.lstrip('#').strip()), {1: h1, 2: h2}.get(lvl, h3)))
        elif s.startswith('>'):
            absatz.append(s.lstrip('> '))
        elif re.match(r'^(\d+\.|-) ', s):
            flush(); absatz.append('• ' + re.sub(r'^(\d+\.|-) ', '', s) if s.startswith('-') else s)
        else:
            absatz.append(s)
    flush()

    def fuss(c, d):
        c.saveState(); c.setFont('WS', 7.5); c.setFillColor(colors.grey)
        c.drawString(15 * mm, 8 * mm, 'JeNi bucht · Länderanalyse · Stand 2026-10-18 · interne Prüfung, keine Beratung')
        c.drawRightString(seite[0] - 15 * mm, 8 * mm, f'Seite {d.page}'); c.restoreState()

    SimpleDocTemplate('docs/Laenderanalyse.pdf', pagesize=seite, leftMargin=15 * mm, rightMargin=15 * mm,
                      topMargin=14 * mm, bottomMargin=14 * mm, title='Länderanalyse – JeNi bucht',
                      author='JeNi bucht').build(story, onFirstPage=fuss, onLaterPages=fuss)


if __name__ == '__main__':
    main()
