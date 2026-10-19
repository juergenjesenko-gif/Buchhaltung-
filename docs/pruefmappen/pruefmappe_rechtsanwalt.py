"""Erzeugt docs/pruefmappen/Pruefmappe_Rechtsanwalt.pdf.

Aufruf aus dem Repository-Wurzelverzeichnis:
  python3 docs/pruefmappen/pruefmappe_rechtsanwalt.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pruefmappe_gemeinsam import *  # noqa: E402,F403
from reportlab.platypus import PageBreak  # noqa: E402

TITEL = 'Prüfmappe Rechtsberatung'
THEMEN = [
    ('Nutzungsbedingungen (AGB/EULA) und Haftung', ['P-L1', 'P-L2', 'P-L4', 'P-L5', 'P-L6', 'P-L11', 'P-R4', 'P-R11', 'P-R15', 'P-R20', 'P-R24', 'P-V6', 'P-R8']),
    ('Datenschutzerklärung und Datenflüsse', ['P-R6', 'P-L9', 'P-R14', 'P-R18', 'P-R19', 'P-R35', 'P-R36', 'P-R42', 'P-U4', 'P-L12', 'P-V7', 'P-K3', 'P-L14', 'P-L15', 'P-M3', 'P-M6', 'P-R44', 'P-R46', 'P-R47', 'P-R48']),
    ('Impressum, Anbieterangaben, Menü „Rechtliches“', ['P-R1', 'P-R10', 'P-L7', 'P-L8', 'P-L20', 'P-R45']),
    ('Abo, Test, Promo-Code, Preisangaben (§ 312k, § 309 Nr. 9 BGB)', ['P-R12', 'P-R37', 'P-R57', 'P-R38', 'P-R17', 'P-R2', 'P-L10']),
    ('Werbung, Instagram, Store-Texte, Store-Konten', ['P-R40', 'P-R43', 'P-R13', 'P-R16', 'P-R22', 'P-R23', 'P-R3']),
    ('Rechnungs-, Angebots- und Mahntexte (Sie-Form an Kundinnen)', ['P-R30', 'P-R31', 'P-R32', 'P-R33', 'P-R34', 'P-R39']),
    ('Abgrenzung Steuerberatung, KI', ['P-R5', 'P-R41', 'P-R25', 'P-R26', 'P-R9', 'P-L16', 'P-L17', 'P-V8']),
    ('Demo mit Musterdaten: Wasserzeichen, erfundene Namen', ['P-R55', 'P-R56']),
    ('Marke und Lizenzen', ['P-R7', 'P-L18', 'P-L19']),
]
NICHT_ANWALT = {'P-L3', 'P-L13'}  # Steuerberatung bzw. Gerätetest
MIN_JE_PUNKT = 8
STETS = {'P-R7'}  # eigene Markenrecherche: anwaltliche Einschätzung trotzdem erbeten

alle = pruefpunkte()
zugeordnet = {i for _, ids in THEMEN for i in ids}
fehlend = [i for i, p in alle.items() if (i.startswith('P-R') or i.startswith('P-L'))
           and offen(p) and i not in zugeordnet and i not in NICHT_ANWALT]
if fehlend:
    sys.exit(f'Nicht zugeordnete Rechts-Prüfpunkte: {fehlend}')
themen = [(t, [alle[i] for i in ids if i in alle and (offen(alle[i]) or i in STETS)]) for t, ids in THEMEN]
themen = [(t, p) for t, p in themen if p]
anzahl = sum(len(p) for _, p in themen)
INTERN = {i for i in intern_geprueft() if i.startswith(('P-R', 'P-L'))}
MIN_JE_STICHPROBE = 2
stunden = (anzahl * MIN_JE_PUNKT + len(INTERN) * MIN_JE_STICHPROBE) / 60

ZUSATZ = {
    'P-R7': 'Genügt die eigene Recherche ohne Befund, oder raten Sie zu einer Anmeldung (AT/EUIPO) bzw. einer Ähnlichkeitsrecherche?',
    'P-R4': 'Ist der Hinweis „keine Steuerberatung“ samt Haftungsbegrenzung (Anhang, Nutzungsbedingungen) so wirksam?',
}

s = []
s.append(Paragraph(TITEL, h1))
s.append(Paragraph('JeNi bucht – Buchhaltungs-App für Einzelunternehmen und Kleinunternehmer in Österreich und Deutschland', h3))
s.append(Paragraph(f'Stand {STAND} · Auftraggeber: {KONTAKT}', sm))
s.append(Spacer(1, 8))
s.append(Paragraph('Zweck dieser Mappe', h2))
s.append(Paragraph(
    'Die App steht vor dem Store-Start in Österreich und Deutschland. Alle Rechtstexte (Nutzungsbedingungen, '
    'Datenschutzerklärung, Impressum, Abo- und Werbetexte, Texte auf Rechnungen und Mahnungen) sind '
    '<b>Entwürfe einer internen Prüfinstanz, nicht anwaltlich geprüft</b>. Diese Mappe bündelt jede offene '
    'Rechtsfrage mit dem, was die App heute tut, damit Sie kurz mit <b>bestätigt / nicht bestätigt / nur mit '
    'Änderung</b> antworten und, wo nötig, einen Formulierungsvorschlag machen können. '
    'Die zu prüfenden Texte stehen im Wortlaut im Anhang.', b))
s.append(Paragraph('Das Produkt und die Anbieterin', h2))
s.append(Paragraph(
    'Smartphone-App (Android, iPhone), offline, alle Daten auf dem Gerät der Nutzerin; der Anbieter betreibt '
    'keinen Server. Vertrieb ausschließlich über Google Play und den App Store als Abo (Basis/Pro, monatlich '
    'oder jährlich, 14 Tage Pro kostenlos testen, Promo-Code „2 Monate gratis“). Zielgruppe: Einzelunternehmerinnen '
    'und Kleinunternehmer, B2B, teils auch Verbraucherinnen. Anbieter: Spirits by JeNiBarb e.U. '
    '(Einzelunternehmen, FN 643550 y, LG Klagenfurt), Österreich.', b))
s.append(Paragraph('Bitte um ein Fixpreisangebot', h2))
s.append(Paragraph(
    f'Die Mappe enthält <b>{anzahl} Prüfpunkte</b> in {len(themen)} Themen; die Texte stehen im Anhang. '
    f'Unsere Schätzung: etwa {MIN_JE_PUNKT} Minuten je Punkt plus Durchsicht der Texte, zusammen rund '
    f'<b>{stunden + 3:.0f} Stunden</b> (darin {len(INTERN)} intern geprüfte Punkte im Anhang F zur Stichprobe, '
    f'etwa {MIN_JE_STICHPROBE} Minuten je Punkt). Wir bitten um ein <b>Fixpreisangebot</b>, gern getrennt nach '
    '„vor Store-Start“ (Benötigt vor: Release, erster Upload, Store-Start, Werbung) und „später“ (Stufe B/C), '
    'mit Kennzeichnung der Punkte, die Sie ablehnen oder weiterverweisen.', b))
s.append(Paragraph('Übersicht', h2))
s.append(tabelle([['Thema', 'Punkte', 'IDs']] +
                 [[t, str(len(p)), ', '.join(x['id'] for x in p)] for t, p in themen],
                 [70, 14, 90]))
s.append(Paragraph('Anhang: A Nutzungsbedingungen · B Datenschutzerklärung (Entwurf und gültige PRIVACY.md) · '
                   'C Impressum · D Store-Texte, Werbe-Negativliste, Instagram-Text · E Texte in der App '
                   '(Rechtliches, Abo-Seite, Rechnung/Mahnung in Sie-Form) · F intern geprüfte Punkte zur Stichprobe.', sm))
s.append(PageBreak())

for i, (thema, punkte) in enumerate(themen, 1):
    s.append(Paragraph(f'{i}. {thema}', h2))
    for p in punkte:
        s.append(punkt_block(p, ZUSATZ.get(p['id'], '')))

for buchst, pfad, titel in [
    ('A', 'docs/legal/NUTZUNGSBEDINGUNGEN.md', 'Anhang A – Nutzungsbedingungen (Entwurf)'),
    ('B1', 'docs/legal/DATENSCHUTZ.md', 'Anhang B1 – Datenschutzerklärung (Entwurf)'),
    ('B2', 'docs/PRIVACY.md', 'Anhang B2 – PRIVACY.md (derzeit verlinkte Fassung)'),
    ('C', 'docs/legal/IMPRESSUM.md', 'Anhang C – Impressum (Entwurf)'),
    ('D', 'docs/STORE_LISTING.md', 'Anhang D – Store-Texte, Datensicherheitsangaben, Instagram-Werbung'),
]:
    s.append(PageBreak())
    markdown_anhang(pfad, s, titel)

s.append(PageBreak())
s.append(Paragraph('Anhang E – Texte in der App', h2))
code_anhang('lib/domain/legal_texts.dart', s, titel='E1 – Menü „Rechtliches“, Hinweis „keine Steuerberatung“')
code_anhang('lib/features/licensing/subscription_screen.dart', s, 120, 300, titel='E2 – Abo-Seite (Pflichttext, Test, Kündigung)')
code_anhang('lib/features/licensing/license_notice.dart', s, titel='E3 – Hinweise zum Abo-Stand')
code_anhang('lib/services/invoice_texts.dart', s, titel='E4 – Texte auf Rechnung, Angebot, Mahnung (Sie-Form)')
code_anhang('lib/services/dunning_service.dart', s, 116, 145, titel='E5 – Zahlungserinnerung/Mahnung, Mahnkostenhinweis')
code_anhang('lib/domain/country.dart', s, 465, 475, titel='E6 – Verbraucherhinweis § 286 Abs. 3 BGB')

s.append(PageBreak())
anhang_intern(s, INTERN, 'Anhang F – Intern geprüfte Punkte (zur Stichprobe)')

ziel = 'docs/pruefmappen/Pruefmappe_Rechtsanwalt.pdf'
baue(ziel, TITEL, s)
print(f'{ziel}: {anzahl} Prüfpunkte')
