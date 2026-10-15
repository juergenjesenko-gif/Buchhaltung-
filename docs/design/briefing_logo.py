from reportlab.lib.pagesizes import A4
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image, PageBreak
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib import colors
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
F='assets/fonts/'
pdfmetrics.registerFont(TTFont('WS',F+'WorkSans-Regular.ttf'))
pdfmetrics.registerFont(TTFont('WSB',F+'WorkSans-Bold.ttf'))
P=colors.HexColor('#12524E'); O=colors.HexColor('#F2A541')
h1=ParagraphStyle('h1',fontName='WSB',fontSize=20,leading=24,textColor=P,spaceAfter=4)
h2=ParagraphStyle('h2',fontName='WSB',fontSize=12.5,leading=16,textColor=P,spaceBefore=10,spaceAfter=4)
b=ParagraphStyle('b',fontName='WS',fontSize=9.5,leading=13.5)
sm=ParagraphStyle('sm',fontName='WS',fontSize=8.5,leading=11.5,textColor=colors.HexColor('#444444'))
cell=ParagraphStyle('c',fontName='WS',fontSize=8.5,leading=11)
cellb=ParagraphStyle('cb',fontName='WSB',fontSize=8.5,leading=11)
def T(rows,widths):
    data=[[Paragraph(str(c),cellb if i==0 else cell) for c in r] for i,r in enumerate(rows)]
    t=Table(data,colWidths=[w*mm for w in widths],repeatRows=1)
    t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),colors.HexColor('#E7F0EF')),('GRID',(0,0),(-1,-1),0.4,colors.HexColor('#BBBBBB')),('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),4),('RIGHTPADDING',(0,0),(-1,-1),4)]))
    return t
s=[]
s.append(Paragraph('JeNi bucht – Briefing Logo und App-Symbol',h1))
s.append(Paragraph('Kurzspezifikation für Designagenturen · Stand 15.10.2026 · Auftraggeberin: Spirits by JeNiBarb e.U., Sankt Leonhard bei Siebenbrünn 96, 9587 Arnoldstein, Österreich · office@jenibarb.com',sm))
s.append(Spacer(1,6))
s.append(Paragraph('1. Das Produkt',h2))
s.append(Paragraph('<b>JeNi bucht</b> ist eine Buchhaltungs-App für Smartphone und Tablet (Android und iPhone) für Einzelunternehmerinnen und Kleinunternehmer in Österreich und Deutschland. Kernfunktion: einen Beleg überall fotografieren – im Supermarkt, an der Tankstelle, im Auto – und die App liest Betrag, Datum und Steuersatz selbst aus. Dazu Rechnungen schreiben, Mahnungen, Umsatzsteuer, Export an die Steuerberatung. Alle Daten bleiben auf dem Gerät der Nutzerin (kein Anbieter-Server). Vertrieb über Google Play und den Apple App Store als Abo (14 Tage kostenlos testen, danach Basis oder Pro).',b))
s.append(Paragraph('2. Zielgruppe und Tonalität',h2))
s.append(Paragraph('Vorwiegend Frauen zwischen 20 und 60 Jahren, durchschnittliche Bildung, mit kleinem Webshop oder Dienstleistung, wenig Technikverständnis, schnell von Buchhaltung überfordert. Das Logo soll <b>warm, freundlich, vertrauenswürdig und modern</b> wirken – nicht wie eine Bank, nicht wie ein Behördenformular, nicht verspielt-kindlich. Botschaft: „Buchhaltung ist einfach und nebenbei erledigt.“',b))
s.append(Paragraph('3. Name und Schreibweise',h2))
s.append(Paragraph('Der Name lautet exakt <b>„JeNi bucht“</b> (großes J, kleines e, großes N, kleines i, Leerzeichen, „bucht“ klein). Eine Markenrecherche zum Namen ist abgeschlossen. Das Bildzeichen wird vor dem Store-Start nochmals auf Verwechslungsgefahr geprüft.',b))
s.append(Paragraph('4. Was geliefert werden soll',h2))
s.append(T([
 ['Nr.','Lieferung','Inhalt'],
 ['A','Bildzeichen (App-Symbol)','Ohne Schrift, erkennbar ab 48 × 48 px. Ggf. Monogramm „J“ erlaubt. Mit Varianten für Android und iOS (siehe Abschnitt 5).'],
 ['B','Wortmarke','„JeNi bucht“ als Schriftzug; Schrift frei nutzbar für App, Web und Druck (Lizenz angeben, bevorzugt SIL OFL).'],
 ['C','Logo (Bildzeichen + Wortmarke)','Horizontal und gestapelt; je Positiv auf hellem und Negativ auf dunklem Grund; einfarbig schwarz und weiß.'],
 ['D','Farbsystem','Primär-, Akzent- und Neutralfarben als HEX und RGB, mit Kontrastangabe (WCAG 2.2 AA: Text 4,5:1, Grafik 3:1). Funktioniert im Hell- und Dunkelmodus.'],
 ['E','Kurzer Styleguide (PDF, 2–4 Seiten)','Schutzzone, Mindestgröße, falsche Anwendungen, Farbwerte, Schrift.'],
],[10,45,115]))
s.append(Paragraph('5. Technische Anforderungen App-Symbol',h2))
s.append(T([
 ['Plattform / Verwendung','Format','Maße und Regeln'],
 ['Android adaptives Symbol – Vordergrund','SVG (bevorzugt) und PNG 432 × 432 px, transparent','Fläche 108 × 108 dp; Motiv vollständig in der sicheren Zone Ø 66 dp (Mitte), da Android auf Kreis, Squircle oder Quadrat zuschneidet und leicht animiert.'],
 ['Android adaptives Symbol – Hintergrund','SVG und PNG 432 × 432 px, deckend','Fläche oder einfache Form, ohne Motivteile am Rand.'],
 ['Android einfarbiges Symbol (Themen-Symbole ab Android 13)','SVG, eine Farbe, transparent','Gleiche sichere Zone; reine Silhouette des Motivs.'],
 ['Google Play Store-Symbol','PNG 512 × 512 px, 32 Bit, max. 1 MB','Vollflächig, ohne eigene Rundung oder Schatten (Google rundet selbst).'],
 ['Google Play Vorstellungsgrafik','PNG oder JPG 1024 × 500 px','Bildzeichen + Wortmarke, ruhiger Hintergrund; wichtige Inhalte mittig.'],
 ['iOS App-Symbol','PNG 1024 × 1024 px, sRGB, <b>ohne Transparenz</b>','Quadratisch, <b>keine eigenen abgerundeten Ecken</b> (iOS maskiert selbst), keine Ränder, kein Text.'],
 ['iOS Dunkel- und Tönungsvariante (ab iOS 18)','PNG 1024 × 1024 px','Dunkel: Motiv auf transparentem bzw. dunklem Grund; getönt: Graustufen-Motiv.'],
 ['Startbildschirm (Splash)','SVG und PNG 1152 × 1152 px','Android 12+: Symbol Ø 160 dp in 240 dp Fläche, ohne Hintergrund; eine Hintergrundfarbe für Hell und Dunkel angeben.'],
 ['Rechnungs-PDF und Web','SVG und PNG mit 2× / 3× Auflösung','Logo C horizontal, mindestens 600 px breit.'],
],[45,45,80]))
s.append(Paragraph('Alle Vektordateien bitte als SVG (sauber, ohne eingebettete Rasterbilder) und als bearbeitbare Quelldatei (Figma, AI oder vergleichbar). Farben in sRGB. Für Druck zusätzlich PDF mit CMYK-Werten.',b))
s.append(Paragraph('6. Was das Logo nicht sein soll',h2))
s.append(Paragraph('• keine Euro-Münze oder Geldscheine als Hauptmotiv · • kein Blau/Türkis im Stil von Banken und bekannten Finanz-Apps · • keine Ähnlichkeit zu bestehenden Buchhaltungs- oder Banking-Apps (z. B. Lexoffice, sevDesk, Wise, Revolut) · • keine Kamera-App-Anmutung · • keine Dating-/Messenger-Anmutung (Herz, Sprechblase) · • keine feinen Details, die bei 48 px verschwinden.',b))
s.append(Paragraph('7. Rechte und Ablauf',h2))
s.append(Paragraph('• Übertragung der ausschließlichen, zeitlich und räumlich unbeschränkten Nutzungsrechte inkl. Bearbeitung und Markenanmeldung (Wort-/Bildmarke) an die Auftraggeberin. · • Bestätigung, dass keine fremden Rechte verletzt werden und keine Stock- oder KI-Elemente mit eingeschränkter Lizenz enthalten sind. · • Bitte im Angebot nennen: Anzahl Erstentwürfe (Vorschlag 3), Korrekturschleifen (Vorschlag 2), Lieferzeit, Festpreis netto. · • Abnahme erfolgt nach Ansicht auf echten Android- und iPhone-Geräten.',b))
s.append(Spacer(1,6))
s.append(Paragraph('Kontakt: Jürgen Jesenko · office@jenibarb.com · +43 660 3124252',sm))
SimpleDocTemplate('docs/design/Briefing_Logo_JeNi_bucht.pdf',pagesize=A4,leftMargin=18*mm,rightMargin=18*mm,topMargin=16*mm,bottomMargin=16*mm,title='JeNi bucht – Briefing Logo',author='Spirits by JeNiBarb e.U.').build(s)
