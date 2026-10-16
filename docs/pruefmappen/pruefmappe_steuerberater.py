"""Erzeugt docs/pruefmappen/Pruefmappe_Steuerberater.pdf.

Aufruf aus dem Repository-Wurzelverzeichnis:
  flutter test docs/pruefmappen/beispiele_erzeugen_test.dart   # Beispielrechnungen
  for f in docs/pruefmappen/beispiele/*.pdf; do pdftoppm -png -r 70 -singlefile "$f" "${f%.pdf}"; done
  python3 docs/pruefmappen/pruefmappe_steuerberater.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pruefmappe_gemeinsam import *  # noqa: E402,F403
from reportlab.platypus import Image, PageBreak  # noqa: E402

TITEL = 'Prüfmappe Steuerberatung'
THEMEN = [
    ('Kleinunternehmer AT/DE', ['P-S1', 'P-S2', 'P-S8', 'P-S25', 'P-S47']),
    ('Umsatzsteuer: Sätze, Vorsteuer, Kassenbelege', ['P-S4', 'P-S28', 'P-S27', 'P-S29', 'P-S30', 'P-S46', 'P-S49', 'P-S50', 'P-S42']),
    ('Rechnungspflichtangaben', ['P-S9', 'P-U3', 'P-U2', 'P-S6', 'P-S40', 'P-S41', 'P-S43', 'P-M1']),
    ('Storno und Rechnungskorrektur', ['P-S56']),
    ('Mahnwesen', ['P-S44', 'P-S45']),
    ('Fremdwährung', ['P-S23', 'P-S24', 'P-S26']),
    ('Plattformimporte, Reverse Charge, OSS', ['P-S51', 'P-S52', 'P-S53', 'P-S54', 'P-S55']),
    ('Aufbewahrung, GoBD/BAO, Verfahrensdokumentation', ['P-S5', 'P-S63', 'P-S10', 'P-S15', 'P-S16', 'P-S31', 'P-M2', 'P-K4', 'P-L3', 'P-S17']),
    ('Export DATEV / BMD', ['P-S48']),
    ('Meldungen ans Finanzamt: Kennzahlen UVA/UStVA, E1a, Anlage EÜR', ['P-S57', 'P-S58']),
    ('Anlagen, AfA, Saldenliste, vorläufiger Jahresabschluss', ['P-S59', 'P-S60', 'P-S61', 'P-S62']),
    ('Fristen-Box und Wirtschaftsjahr', ['P-S7', 'P-S33', 'P-S34', 'P-S32']),
    ('Einnahmen-Ausgaben-Rechnung', ['P-S3', 'P-S35', 'P-S18']),
    ('Abo-Erlöse des Anbieters (eigene Steuerfragen der Auftraggeberin)', ['P-S11', 'P-S12', 'P-S13', 'P-S14', 'P-S19', 'P-S20', 'P-S21', 'P-S22', 'P-V5']),
]
MIN_JE_PUNKT = 6

alle = pruefpunkte()
# Jeder offene steuerliche Punkt muss einem Thema zugeordnet sein.
zugeordnet = {i for _, ids in THEMEN for i in ids}
fehlend = [i for i, p in alle.items() if i.startswith('P-S') and offen(p) and i not in zugeordnet]
if fehlend:
    sys.exit(f'Nicht zugeordnete Steuer-Prüfpunkte: {fehlend}')
themen = [(t, [alle[i] for i in ids if i in alle and offen(alle[i])]) for t, ids in THEMEN]
anzahl = sum(len(p) for _, p in themen)
stunden = anzahl * MIN_JE_PUNKT / 60

s = []
s.append(Paragraph(TITEL, h1))
s.append(Paragraph('JeNi bucht – Buchhaltungs-App für Einzelunternehmen und Kleinunternehmer in Österreich und Deutschland', h3))
s.append(Paragraph(f'Stand {STAND} · Auftraggeber: {KONTAKT}', sm))
s.append(Spacer(1, 8))
s.append(Paragraph('Zweck dieser Mappe', h2))
s.append(Paragraph(
    'Die App ist fertig programmiert und vor dem Store-Start. Alle steuerlichen Regeln, die sie anwendet, '
    'sind in der Spezifikation festgehalten und wurden von einer internen Prüfinstanz vorgeprüft. '
    '<b>Eine Vorprüfung ist keine Bestätigung.</b> Diese Mappe bündelt jede offene steuerliche Frage so, '
    'dass Sie sie kurz mit <b>bestätigt / nicht bestätigt / nur mit Änderung</b> beantworten und, wo nötig, '
    'die richtige Fundstelle nennen können. Es geht nicht um eine laufende Beratung, sondern um eine '
    'einmalige Durchsicht.', b))
s.append(Paragraph('Das Produkt', h2))
s.append(Paragraph(
    'Smartphone-App (Android, iPhone), offline, alle Daten auf dem Gerät der Nutzerin. Belege fotografieren '
    'und erkennen, Rechnungen und Angebote schreiben (PDF), Storno und Korrektur, Zahlungserinnerung und '
    'Mahnung mit Verzugszinsen, Kleinunternehmer-Grenzwertüberwachung, Fremdwährung, Import von '
    'Amazon/PayPal/Shopify/Stripe-Berichten, Export für die Steuerberatung (DATEV-Buchungsstapel, '
    'BMD, CSV, USt-Zusammenfassung), Termin-Box für UVA/ESt/SVS. Zielgruppe: Einnahmen-Ausgaben-Rechnerinnen. '
    'Vertrieb als Abo über Google Play und den App Store.', b))
s.append(Paragraph('Bitte um ein Fixpreisangebot', h2))
s.append(Paragraph(
    f'Die Mappe enthält <b>{anzahl} Prüfpunkte</b> in {len(themen)} Themen. Unsere Schätzung: '
    f'etwa {MIN_JE_PUNKT} Minuten je Punkt, zusammen rund <b>{stunden:.0f} Stunden</b>. '
    'Wir bitten um ein <b>Fixpreisangebot</b> für die Durchsicht und das Ausfüllen der Antwortfelder, '
    'gern getrennt nach Österreich und Deutschland und mit Kennzeichnung, welche Punkte Sie '
    'ablehnen oder an eine Kollegin verweisen. Der letzte Themenblock betrifft die Steuern der '
    'Auftraggeberin selbst (Abo-Erlöse über die Stores) und kann gesondert angeboten werden.', b))
s.append(Paragraph('So ist jeder Punkt aufgebaut', h2))
s.append(Paragraph('<b>ID</b> (Verweis in unserer Spezifikation, Abschnitt 14) · <b>Frage</b> · '
                   '<b>Was die App heute tut</b> mit der Fundstelle, auf die wir uns stützen · <b>Antwortfeld</b>. '
                   'Beispielausgaben der App (Rechnungs-PDFs) stehen im Anhang A. Die Antworten tragen wir mit '
                   'Datum und Ihrem Namen als „bestätigt“ oder „widerlegt“ in die Spezifikation ein.', b))
s.append(Paragraph('Übersicht', h2))
s.append(tabelle([['Thema', 'Punkte', 'IDs']] +
                 [[t, str(len(p)), ', '.join(x['id'] for x in p)] for t, p in themen],
                 [70, 14, 90]))
s.append(PageBreak())

for i, (thema, punkte) in enumerate(themen, 1):
    if not punkte:
        continue
    s.append(Paragraph(f'{i}. {thema}', h2))
    if thema.startswith('Rechnungspflicht') or thema.startswith('Kleinunternehmer'):
        s.append(Paragraph('Beispielausgabe: siehe Anhang A (mit dem PDF-Generator der App erzeugt).', sm))
    for p in punkte:
        s.append(punkt_block(p))

s.append(PageBreak())
s.append(Paragraph('Anhang A – Beispielrechnungen aus der App', h2))
s.append(Paragraph('Erzeugt mit dem PDF-Generator der App (<font name="%s" size="8">InvoicePdf</font>) über '
                   '<font name="%s" size="8">docs/pruefmappen/beispiele_erzeugen_test.dart</font>. Die PDF-Dateien '
                   'liegen in <font name="%s" size="8">docs/pruefmappen/beispiele/</font> und gehen mit dieser '
                   'Mappe mit. Erfundene Muster-Daten.' % (MONO, MONO, MONO), sm))
for name, text in [
    ('Rechnung_AT_Regelbesteuerung', 'AT, Regelbesteuerung, 20 % und 10 %, Empfänger mit UID'),
    ('Rechnung_AT_Kleinunternehmer', 'AT, Kleinunternehmer (§ 6 Abs 1 Z 27 UStG)'),
    ('Rechnung_DE_Kleinunternehmer', 'DE, Kleinunternehmer (§ 19 UStG)'),
]:
    png = f'docs/pruefmappen/beispiele/{name}.png'
    s.append(Paragraph(text, h3))
    if os.path.exists(png):
        s.append(Image(png, width=120 * mm, height=120 * mm * 1.4142))
    s.append(PageBreak())

s.append(Paragraph('Anhang B – Steuerliche Kennwerte im Code (Auszug TaxProfile)', h2))
s.append(Paragraph('Länderunterschiede stehen in der App an genau einer Stelle. Der Auszug zeigt Steuersätze, '
                   'Grenzwerte, Pflichthinweise und Fundstellen, wie sie die App verwendet.', sm))
code_anhang('lib/domain/country.dart', s)

ziel = 'docs/pruefmappen/Pruefmappe_Steuerberater.pdf'
baue(ziel, TITEL, s)
print(f'{ziel}: {anzahl} Prüfpunkte')
