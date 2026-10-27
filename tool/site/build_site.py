#!/usr/bin/env python3
"""Erzeugt die öffentliche Website unter docs/site/.

index.html ist die Produktseite (Ziel des Instagram-Bio-Links), übernommen aus
tool/site/produktseite.html. support.html, datenschutz.html, impressum.html und
nutzungsbedingungen.html entstehen aus docs/legal/*.md (dieselben Dateien, die
die App unter „Rechtliches“ zeigt). Ohne Abhängigkeiten, nur Standardbibliothek.

    python3 tool/site/build_site.py

Regeln (docs/LAUNCH.md, Abschnitt „Website“):
- Länderabschnitte <!-- nur AT --> … <!-- /nur --> und <!-- nur DE --> werden
  zu zwei beschrifteten Abschnitten „Österreich“ und „Deutschland“.
- Offene Platzhalter {{…}} werden sichtbar markiert, nie ersetzt oder erfunden.
- Keine externen Ressourcen, kein Skript, kein Tracking.
"""

from __future__ import annotations

import html
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LEGAL = ROOT / "docs" / "legal"
OUT = ROOT / "docs" / "site"

PAGES = [
    ("datenschutz.html", "DATENSCHUTZ.md", "Datenschutz"),
    ("impressum.html", "IMPRESSUM.md", "Impressum"),
    ("nutzungsbedingungen.html", "NUTZUNGSBEDINGUNGEN.md", "Nutzungsbedingungen"),
]
COUNTRY = {"AT": "Österreich", "DE": "Deutschland"}

placeholders: list[tuple[str, str]] = []


def inline(text: str, source: str) -> str:
    """Inline-Markdown: Code, fett, kursiv, Links, Platzhalter."""
    out = html.escape(text, quote=False)

    def ph(m: re.Match[str]) -> str:
        placeholders.append((source, m.group(1)))
        return (
            '<mark class="offen" title="Platzhalter, vor Veröffentlichung '
            'ersetzen">OFFEN: ' + m.group(1) + "</mark>"
        )

    out = re.sub(r"\{\{(.+?)\}\}", ph, out)
    out = re.sub(r"`([^`]+)`", r"<code>\1</code>", out)
    out = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", out)
    out = re.sub(r"(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])", r"<em>\1</em>", out)
    out = re.sub(
        r"\[([^\]]+)\]\(([^)\s]+)\)",
        lambda m: f'<a href="{link(m.group(2))}">{m.group(1)}</a>',
        out,
    )
    out = re.sub(
        r"(?<![\"=>/])\b(https?://[^\s<)]+)",
        r'<a href="\1">\1</a>',
        out,
    )
    out = re.sub(
        r"(?<![\w.:/>])(www\.[a-z0-9.-]+\.[a-z]{2,}(?:/[^\s<)]*)?)",
        r'<a href="https://\1">\1</a>',
        out,
    )
    out = re.sub(
        r"(?<![\w.>:])([\w.+-]+@[\w-]+\.[\w.]+\w)",
        r'<a href="mailto:\1">\1</a>',
        out,
    )
    return out


def link(target: str) -> str:
    for page, md, _ in PAGES:
        if target.endswith(md):
            return page
    return target


def table(rows: list[str], source: str) -> str:
    cells = [[c.strip() for c in r.strip().strip("|").split("|")] for r in rows]
    head, body = cells[0], [r for r in cells[2:]]
    parts = ['<div class="tabelle"><table>', "<thead><tr>"]
    parts += [f'<th scope="col">{inline(c, source)}</th>' for c in head]
    parts.append("</tr></thead><tbody>")
    for r in body:
        parts.append("<tr>" + "".join(f"<td>{inline(c, source)}</td>" for c in r) + "</tr>")
    parts.append("</tbody></table></div>")
    return "".join(parts)


def blocks(lines: list[str], source: str) -> str:
    """Block-Markdown ohne Länderkommentare."""
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        s = line.strip()
        if not s:
            i += 1
            continue
        m = re.match(r"^(#{1,4})\s+(.*)$", s)
        if m:
            level = min(len(m.group(1)) + 0, 4)
            out.append(f"<h{level}>{inline(m.group(2), source)}</h{level}>")
            i += 1
            continue
        if s.startswith("|"):
            rows = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                rows.append(lines[i])
                i += 1
            out.append(table(rows, source))
            continue
        if s.startswith(">"):
            quote = []
            while i < len(lines) and lines[i].strip().startswith(">"):
                quote.append(lines[i].strip()[1:].lstrip())
                i += 1
            out.append('<aside class="hinweis">' + blocks(quote, source) + "</aside>")
            continue
        lm = re.match(r"^(\s*)([-*]|\d+\.)\s+(.*)$", line)
        if lm:
            ordered = lm.group(2)[0].isdigit()
            items: list[str] = []
            while i < len(lines):
                m2 = re.match(r"^(\s*)([-*]|\d+\.)\s+(.*)$", lines[i])
                if m2 and (m2.group(2)[0].isdigit()) == ordered:
                    items.append(m2.group(3))
                elif lines[i].startswith("  ") and lines[i].strip() and items:
                    items[-1] += " " + lines[i].strip()
                else:
                    break
                i += 1
            tag = "ol" if ordered else "ul"
            out.append(f"<{tag}>" + "".join(f"<li>{inline(t, source)}</li>" for t in items) + f"</{tag}>")
            continue
        para = []
        while i < len(lines):
            t = lines[i].strip()
            if not t or t.startswith(("#", "|", ">")) or re.match(r"^([-*]|\d+\.)\s", t):
                break
            para.append(t)
            i += 1
        out.append("<p>" + inline(" ".join(para), source) + "</p>")
    return "\n".join(out)


def convert(md: str, source: str) -> str:
    """Teilt in normale Abschnitte und Länderabschnitte auf."""
    out: list[str] = []
    buf: list[str] = []
    lines = md.splitlines()
    i = 0
    while i < len(lines):
        m = re.match(r"^\s*<!--\s*nur\s+(AT|DE)\s*-->\s*$", lines[i])
        if not m:
            buf.append(lines[i])
            i += 1
            continue
        out.append(blocks(buf, source))
        buf = []
        variants: list[tuple[str, list[str]]] = []
        while i < len(lines):
            m = re.match(r"^\s*<!--\s*nur\s+(AT|DE)\s*-->\s*$", lines[i])
            if not m:
                break
            land, body = m.group(1), []
            i += 1
            while i < len(lines) and not re.match(r"^\s*<!--\s*/nur\s*-->", lines[i]):
                body.append(lines[i])
                i += 1
            i += 1  # Endkommentar
            variants.append((land, body))
            while i < len(lines) and not lines[i].strip():
                i += 1
        out.append('<div class="laender">')
        for land, body in variants:
            out.append(
                f'<section class="land" aria-label="Gilt in {COUNTRY[land]}">'
                f'<p class="land-titel">Gilt in {COUNTRY[land]}</p>'
                + blocks(body, source)
                + "</section>"
            )
        out.append("</div>")
    out.append(blocks(buf, source))
    return "\n".join(x for x in out if x)


NAV = [("index.html", "Startseite"), ("support.html", "Support"),
       ("datenschutz.html", "Datenschutz"), ("impressum.html", "Impressum"), ("nutzungsbedingungen.html", "Nutzungsbedingungen")]


def page(file: str, title: str, body: str) -> str:
    nav = "".join(
        f'<a href="{f}"' + (' aria-current="page"' if f == file else "") + f">{t}</a>"
        for f, t in NAV
    )
    return f"""<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="index, follow">
<title>{title} · JeNi bucht</title>
<meta name="description" content="{title} von JeNi bucht, der Buchhaltungs-App für Selbstständige in Österreich und Deutschland.">
<link rel="canonical" href="https://jenibucht.com/{file}">
<link rel="icon" href="favicon.ico" sizes="any">
<link rel="icon" type="image/png" sizes="32x32" href="favicon-32.png">
<link rel="icon" type="image/png" sizes="192x192" href="icon-192.png">
<link rel="apple-touch-icon" href="apple-touch-icon.png">
<link rel="stylesheet" href="style.css">
</head>
<body>
<a class="skip" href="#inhalt">Zum Inhalt</a>
<header><p class="marke">JeNi bucht</p><nav aria-label="Seiten">{nav}</nav></header>
<main id="inhalt">
{body}
</main>
<footer><p>Spirits by JeNiBarb e.U. · <a href="mailto:office@jenibarb.com">office@jenibarb.com</a> ·
Diese Seite verwendet keine Cookies, kein Tracking und keine externen Ressourcen.</p>
<p>Erzeugt aus <code>docs/legal/</code> mit <code>tool/site/build_site.py</code>.</p></footer>
</body>
</html>
"""


INDEX = """<h1>JeNi bucht – Support und Kontakt</h1>
<p>JeNi bucht ist eine Buchhaltungs-App für Einzelunternehmen und
Kleinunternehmer in Österreich und Deutschland (Android und iPhone). Deine
Daten bleiben auf deinem Gerät: kein Nutzerkonto, kein Server, keine Werbung.</p>

<h2>Hilfe bekommen</h2>
<ol>
<li>In der App: Fragezeichen oben rechts tippen – die Hilfe ist nach Themen gegliedert.</li>
<li>In der App unter <strong>Rechtliches → Support</strong> – das füllt eine E-Mail vor, du schickst sie selbst ab.</li>
<li>Oder direkt schreiben: <a href="mailto:office@jenibarb.com?subject=JeNi%20bucht%20Support">office@jenibarb.com</a>.</li>
</ol>
<p>Bitte schick uns <strong>keine</strong> Belege, Rechnungen oder Kennwörter, wenn es nicht nötig ist.</p>

<h2>Abo</h2>
<ul>
<li>Abos (Basis, Pro) laufen ausschließlich über Google Play bzw. den App Store.</li>
<li>Kündigen: Android – Play Store → Profil → Zahlungen und Abos → Abos.
iPhone – Einstellungen → dein Name → Abonnements.</li>
<li>Erstattung: über den jeweiligen Store (<a href="https://support.google.com/googleplay/answer/2479637">Google Play</a>,
<a href="https://reportaproblem.apple.com">Apple</a>).</li>
<li>Ohne Abo bleiben deine Daten auf dem Gerät lesbar und exportierbar.</li>
</ul>

<h2>Daten löschen</h2>
<p>Alle Daten liegen nur auf deinem Gerät. Löschen: App deinstallieren. Eigene
Sicherungsdateien in deinem Cloud-Ordner löschst du dort selbst. Bei uns
liegen nur E-Mails, die du uns geschrieben hast; Löschung auf Anfrage an
<a href="mailto:office@jenibarb.com">office@jenibarb.com</a>.</p>

<h2>Wichtig</h2>
<p>JeNi bucht unterstützt bei der Buchhaltung, ist aber <strong>keine
Steuerberatung</strong> und keine Registrierkasse nach RKSV.</p>
"""

CSS = """:root{--bg:#fdfcfa;--fg:#1d1d1b;--muted:#5b5b57;--line:#d9d6cf;--accent:#0f5c4c;--mark:#ffe08a;--card:#f3f1ec}
@media (prefers-color-scheme:dark){:root{--bg:#141413;--fg:#ecebe6;--muted:#b0aea6;--line:#3a3935;--accent:#6fd1b8;--mark:#7a5c00;--card:#1f1e1c}}
*{box-sizing:border-box}
html{-webkit-text-size-adjust:100%}
body{margin:0;background:var(--bg);color:var(--fg);font:1.0625rem/1.6 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
header,main,footer{max-width:46rem;margin:0 auto;padding:0 16px}
header{padding-top:16px;border-bottom:1px solid var(--line)}
.marke{font-weight:700;font-size:1.25rem;margin:0 0 8px}
nav{display:flex;flex-wrap:wrap;gap:4px 8px;padding-bottom:8px}
nav a{display:inline-flex;align-items:center;min-height:48px;padding:0 12px;border-radius:8px;color:var(--accent);text-decoration:none;font-weight:600}
nav a[aria-current=page]{background:var(--card);color:var(--fg)}
a{color:var(--accent);overflow-wrap:anywhere}
a:focus-visible{outline:3px solid var(--accent);outline-offset:2px}
h1{font-size:1.6rem;line-height:1.25;margin:24px 0 12px}
h2{font-size:1.25rem;margin:28px 0 8px}
h3,h4{font-size:1.05rem;margin:20px 0 6px}
.hinweis{border-left:4px solid var(--accent);background:var(--card);padding:4px 16px;margin:16px 0}
mark.offen{background:var(--mark);color:inherit;padding:0 4px;border-radius:4px;font-weight:600}
.laender{display:grid;gap:12px;margin:12px 0}
@media (min-width:640px){.laender{grid-template-columns:1fr 1fr}}
.land{border:1px solid var(--line);border-radius:8px;padding:4px 16px}
.land-titel{font-weight:700;margin:8px 0 0}
.tabelle{overflow-x:auto;margin:12px 0}
table{border-collapse:collapse;width:100%;font-size:.95rem}
th,td{border:1px solid var(--line);padding:8px;text-align:left;vertical-align:top}
th{background:var(--card)}
code{font-size:.9em;overflow-wrap:anywhere}
footer{border-top:1px solid var(--line);margin-top:32px;padding-bottom:24px;color:var(--muted);font-size:.9rem}
.skip{position:absolute;left:-9999px}.skip:focus{left:16px;top:8px;background:var(--bg);padding:8px}
"""


# Store-Links: erst auf True stellen, wenn die App in BEIDEN Stores öffentlich
# ist – vorher liefern die Links für Besucher eine Fehlerseite.
STORES_LIVE = False
APP_STORE_URL = "https://apps.apple.com/at/app/id6824914122"
PLAY_URL = "https://play.google.com/store/apps/details?id=at.jenibarb.jenibucht"


def produktseite(html: str) -> str:
    """Produktseite: Store-Knöpfe (wenn live) und FAQ als strukturierte Daten."""
    if STORES_LIVE:
        html = re.sub(
            r"<!-- STORES:START.*?<!-- STORES:END -->",
            f'<a class="btn btn-ghost" href="{APP_STORE_URL}">Laden im App Store</a>\n'
            f'      <a class="btn btn-ghost" href="{PLAY_URL}">Jetzt bei Google Play</a>',
            html,
            flags=re.S,
        )
        html = html.replace("Bald im App Store und bei Google Play", "Jetzt im App Store und bei Google Play")
    # FAQ aus den <details>-Blöcken als FAQPage, damit Suche und Seite nie auseinanderlaufen.
    fragen = re.findall(r"<details><summary>(.*?)</summary><p>(.*?)</p></details>", html, re.S)
    if fragen:
        def text(x: str) -> str:
            return re.sub(r"<[^>]+>", "", x).replace("&nbsp;", " ").replace("&amp;", "&")
        faq = {
            "@context": "https://schema.org",
            "@type": "FAQPage",
            "mainEntity": [
                {"@type": "Question", "name": text(q),
                 "acceptedAnswer": {"@type": "Answer", "text": text(a)}}
                for q, a in fragen
            ],
        }
        html = html.replace(
            "</head>",
            '<script type="application/ld+json">' + json.dumps(faq, ensure_ascii=False) + "</script>\n</head>",
            1,
        )
    return html


# Sprachversionen (docs/maerkte/Marketing_Mehrsprachig.md Abschnitt 8)
HREFLANG = (
    '<link rel="alternate" hreflang="de" href="https://jenibucht.com/">\n'
    '<link rel="alternate" hreflang="en" href="https://jenibucht.com/en/">\n'
    '<link rel="alternate" hreflang="x-default" href="https://jenibucht.com/">\n'
)


def sprachumschalter(aktuell: str, prefix: str) -> str:
    """Umschalter DE | EN in der Kopfnavigation, jeder Eintrag ≥ 48 px hoch (nav a)."""
    ziele = [("de", "DE", prefix or "./", "Deutsch"), ("en", "EN", (prefix + "en/") if prefix == "" else "./", "English")]
    teile = []
    for code, kurz, href, name in ziele:
        cur = ' aria-current="true"' if code == aktuell else ""
        teile.append(f'<a style="min-width:48px;justify-content:center" href="{href}" hreflang="{code}" lang="{code}" aria-label="{name}"{cur}>{kurz}</a>')
    return '<span class="lang" style="display:inline-flex;align-items:center">' + '<span aria-hidden="true">|</span>'.join(teile) + "</span>"


def mehrsprachig(html: str, sprache: str) -> str:
    html = html.replace('<link rel="canonical"', HREFLANG + '<link rel="canonical"', 1)
    if sprache == "de":
        html = html.replace('    <a href="impressum.html">Impressum</a>\n  </nav>',
                            '    <a href="impressum.html">Impressum</a>\n    ' + sprachumschalter("de", "") + "\n  </nav>", 1)
    else:
        html = html.replace("<!-- LANG:SWITCH -->", sprachumschalter("en", "../"), 1)
    return html


def produktseite_en(de: str) -> str:
    """Englische Produktseite: CSS der deutschen Seite übernehmen, Pfade für /en/ anpassen."""
    style = re.search(r"<style>.*?</style>", de, re.S).group(0).replace('url("fonts/', 'url("../fonts/')
    en = (ROOT / "tool" / "site" / "produktseite_en.html").read_text(encoding="utf-8")
    en = en.replace("<!-- STYLE:DE -->", style, 1)
    return mehrsprachig(produktseite(en), "en")


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "style.css").write_text(CSS, encoding="utf-8")
    # Produktseite (Ziel des Instagram-Bio-Links) wird unverändert übernommen;
    # Schriften und Bilder dazu liegen fest in docs/site/fonts und docs/site/img.
    de = (ROOT / "tool" / "site" / "produktseite.html").read_text(encoding="utf-8")
    (OUT / "index.html").write_text(mehrsprachig(produktseite(de), "de"), encoding="utf-8")
    (OUT / "en").mkdir(exist_ok=True)
    (OUT / "en" / "index.html").write_text(produktseite_en(de), encoding="utf-8")
    (OUT / "support.html").write_text(page("support.html", "Support", INDEX), encoding="utf-8")
    for file, md, title in PAGES:
        src = (LEGAL / md).read_text(encoding="utf-8")
        (OUT / file).write_text(page(file, title, convert(src, md)), encoding="utf-8")
    (OUT / ".nojekyll").write_text("", encoding="utf-8")
    # Suchmaschinen: robots.txt und Sitemap mit allen Seiten.
    seiten = ["", "en/", "support.html"] + [f for f, _, _ in PAGES]
    (OUT / "robots.txt").write_text(
        "User-agent: *\nAllow: /\nSitemap: https://jenibucht.com/sitemap.xml\n",
        encoding="utf-8",
    )
    (OUT / "sitemap.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        + "".join(f"  <url><loc>https://jenibucht.com/{f}</loc></url>\n" for f in seiten)
        + "</urlset>\n",
        encoding="utf-8",
    )
    if placeholders:
        print(f"{len(placeholders)} offene Platzhalter (sichtbar markiert):")
        for src, name in placeholders:
            print(f"  {src}: {{{{{name[:70]}}}}}")
    print(f"Geschrieben nach {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
