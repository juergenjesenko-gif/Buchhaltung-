# Markteintritt Frankreich – Entscheidungsvorlage „JeNi bucht“

Stand 2026-10-26 · Prüfinstanzen: Steuerberater FR, Rechtsanwalt FR/EU, Softwareentwickler
Sicherheit: **hoch** = mehrere übereinstimmende Quellen · **mittel** = eine Quelle oder nicht amtlich · **niedrig** = Gedächtnis, noch nicht online geprüft.
Ersetzt keine Beratung durch ein französisches *expert-comptable*.

## Kurzfassung

1. Der Markt ist groß: rund 2,7 Mio. Kleinstunternehmer (*micro-entrepreneurs*), davon etwa die Hälfte mit Umsatz. (Quelle: URSSAF; Sicherheit mittel)
2. Ab dem **1. 9. 2027** müssen auch sie **elektronische Rechnungen über eine Plattformagréée (PA)** ausstellen. Das Empfangen ist schon seit dem 1. 9. 2026 Pflicht. (Sicherheit hoch)
3. Eine reine Offline-App ohne Anbindung an eine PA ist ab September 2027 in Frankreich **nicht mehr verkaufsfähig**.
4. **Empfehlung:** Den Start nicht vor einer funktionierenden PA-Anbindung über eine API planen, Zielfenster **Frühjahr 2027**. Aufwand etwa **10–14 Wochen**. Davor zuerst AT/DE stabilisieren.

---

## 1. Zielgruppe und Buchführungspflichten

- **Régime micro-social:** Die Sozialabgaben werden als Prozentsatz vom Umsatz berechnet und monatlich oder vierteljährlich bei der URSSAF gemeldet. **Micro-fiscal:** Die Einkommensteuer wird pauschal nach Abzug eines festen Prozentsatzes berechnet (*abattement*: 71 % Handel, 50 % Dienstleistung BIC, 34 % BNC). Wahlweise gibt es den *versement libératoire*. (Sicherheit hoch, aus Fachwissen)
- **Umsatzgrenzen micro:** 188 700 € für Handel und Beherbergung, 77 700 € für Dienstleistungen (Werte 2023–2025, seither unverändert). (Sicherheit mittel, vor dem Start auf service-public.fr prüfen)
- **Pflichtbücher:** Der *livre des recettes* ist ein chronologisches Einnahmenbuch mit Datum, Kunde, Betrag, Zahlungsart und Belegnummer. Das *registre des achats* ist nur bei Handel oder Beherbergung Pflicht. Belege müssen 10 Jahre aufbewahrt werden. Eine Bilanz oder ein FEC ist nicht nötig.
- **Was die App schon kann:** Die chronologische Erfassung von Einnahmen und Ausgaben mit Beleg passt zum *livre des recettes*, ebenso Rechnungsstellung, Nummernkreis, schreibgeschützte gestellte Rechnungen und Belegfoto. **Es fehlen:** französische Spalten und Begriffe, Zahlungsart als Pflichtfeld, Export des *livre des recettes* als PDF/CSV und ein Rechner für die URSSAF-Umsatzmeldung.

## 2. Umsatzsteuer (TVA)

**Franchise en base (art. 293 B CGI):**

- Die Loi de finances 2025 wollte eine einheitliche Grenze von **25 000 €** einführen. Diese Regel wurde 2025 ausgesetzt und **nicht umgesetzt**.
- Die Loi n° 2025-1044 vom 3. 11. 2025 hat die bisherigen Grenzen **dauerhaft festgeschrieben**:
  - Handel: 85 000 € (Toleranzgrenze 93 500 €)
  - Dienstleistungen: 37 500 € (Toleranzgrenze 41 250 €)
- Auch das PLF 2026 sah 37 500 € vor (für Bauleistungen 25 000 €). Laut LegiFiscal haben die Abgeordneten die Anhebung abgelehnt.
- Für 2027 ist **keine Änderung beschlossen**. Sicherheit: **mittel**, den endgültigen Text der LF 2026 auf Légifrance prüfen.
- Quellen: [LegiFiscal Promulgation](https://www.legifiscal.fr/actualites-fiscales/4317-promulgation-loi-stabilisant-seuils-franchise-base-tva.html), [LegiFiscal PLF 2026](https://www.legifiscal.fr/actualites-fiscales/4273-plf-2026-franchise-base-tva-37500-btp.html), [Bpifrance Création](https://bpifrance-creation.fr/entrepreneur/actualites/plf-2026-franchise-base-tva-annoncee-a-37-500-eu)

**Rechnungspflichtangaben (art. 242 nonies A, annexe II CGI):**

- Datum und fortlaufende Nummer
- Name und Adresse beider Parteien
- **SIREN/SIRET** des Ausstellers
- Menge, Bezeichnung, Einzelpreis, Leistungsdatum
- Zahlungsfrist und Verzugszinssatz
- **Pauschale Mahnkostenentschädigung von 40 €** (nur B2B)
- Skontobedingungen oder „pas d'escompte“
- Bei franchise der Satz **„TVA non applicable, art. 293 B du CGI“**
- Zusätzlich für micro: „EI“ oder „Entrepreneur individuel“ beim Namen
- **Neu für E-Rechnungen ab 2026/27:** SIREN des Kunden, Lieferadresse, Art der Leistung (Waren/Dienstleistung/gemischt) und Hinweis auf die Option „TVA sur les débits“

Sicherheit: mittel bis hoch.

- **Sanktionen:** 15 € je fehlerhafter Rechnung, höchstens ¼ des Rechnungsbetrags (art. 1737 CGI). Bei Nichtnutzung der E-Rechnung laut LF 2026 **50 € je Rechnung** und **500 € je fehlendem E-Reporting**. Sicherheit mittel, die Quellen widersprechen sich.
- **Nummerierung:** einmalig, chronologisch, lückenlos. Mehrere Serien, zum Beispiel je Jahr, sind erlaubt. Das ist heute schon im App-Konzept so.

## 3. E-Rechnungspflicht und Plattform agréée (PA)

**Einfach erklärt:**

- Eine Rechnung zwischen zwei französischen Unternehmen (B2B) darf künftig **nicht mehr als PDF per E-Mail** verschickt werden. Sie muss über eine **Plateforme Agréée (PA, früher „PDP“)** laufen, eine vom Staat zugelassene Rechnungspost.
- Die PA des Absenders schickt die Rechnung an die PA des Empfängers. Welche PA ein Kunde hat, steht im **Annuaire**, dem zentralen Verzeichnis des Staates (PPF).
- Der **PPF** ist keine kostenlose Ausstellplattform mehr. Er führt nur das Verzeichnis und sammelt die Steuerdaten.

**Ablauf:**

1. **Émission:** Die App erzeugt die Rechnung und übergibt sie an die PA.
2. Die PA prüft das Format, schlägt im Annuaire nach und stellt die Rechnung der PA des Empfängers zu.
3. **Statuts (Lebenszyklus):** déposée → reçue → mise à disposition → approuvée/refusée → **encaissée**. Den Status „encaissée“ meldet der Aussteller bei Dienstleistungen selbst.
4. Die PA übermittelt die Rechnungsdaten an den Fiskus.
5. **E-Reporting:** Auch **B2C- und Auslandsumsätze** sowie Zahlungsdaten werden über die PA als Summenmeldung gemeldet.

**Zeitplan** (Sicherheit hoch):

| Ab | Wer | Pflicht |
|---|---|---|
| 1. 9. 2026 | **alle**, auch micro in franchise | E-Rechnungen **empfangen** (PA wählen) |
| 1. 9. 2026 | Großunternehmen, ETI | ausstellen und E-Reporting |
| **1. 9. 2027** | **PME und micro** | ausstellen und E-Reporting |

**Formate:** Factur-X (PDF/A-3 mit eingebettetem CII-XML, Profil mindestens EN16931), UBL 2.1 oder UN/CEFACT CII. Die App kann für DE bereits ZUGFeRD erzeugen, und das ist technisch **dasselbe wie Factur-X**. Für FR ist das ein großer Vorteil, aber die zusätzlichen französischen Pflichtfelder (BT-Erweiterungen der AFNOR XP Z12-012) müssen ergänzt werden.

**Zugelassene Plattformen:** Die offizielle Liste wurde am 22. 1. 2026 veröffentlicht. Laut Presse gibt es rund **149 PA**.
Quellen: [WebLex](https://www.weblex.fr/weblex-actualite/facturation-electronique-publication-de-la-liste-des-plateformes-agreees), [Presse-Citron](https://www.presse-citron.net/facturation-electronique-entre-vigueur-aujourdhui-voici-149-plateformes-agreees-france/), [impots.gouv.fr – Facturation électronique](https://www.impots.gouv.fr/professionnel/je-passe-la-facturation-electronique)

**Optionen für eine Offline-App:**

| Option | Was | Aufwand | Bewertung |
|---|---|---|---|
| **(a) API-Partner** | Die App sendet Factur-X über die API einer PA (weiße oder graue Marke) und holt Status und Eingangsrechnungen. Kandidaten: [Iopole](https://www.iopole.com) (API-first für Software-Hersteller, Preis auf Anfrage), [Super PDP](https://www.superpdp.tax) (seit 05/2026 produktiv, günstig/kostenlos beworben), [B2Brouter](https://www.b2brouter.net/fr/) (API, weiße/graue Marke). Öffentliche Preise gibt es nicht. Üblich sind Gebühren pro Rechnung, geschätzt 0,05–0,30 €. | 6–8 Wochen | **empfohlen** |
| **(b) eigene PA der Nutzerin** | Die App exportiert Factur-X, die Nutzerin lädt die Datei in ihre PA hoch (z. B. die Gratisangebote der Bank). | 2 Wochen | Einfache Übergangslösung, aber **mehrere Schritte je Rechnung**. Verstößt gegen das Leitprinzip und ist kein echtes Verkaufsargument. |
| **(c) selbst PA werden** | Zulassung durch die DGFiP, ISO 27001, SecNumCloud-ähnliche Auflagen, Server, Peppol-Zugangspunkt, Audit | über 12 Monate, sechsstellige Kosten | **nein**. Widerspricht „kein Server“. |

**Folge für die Architektur:** Option (a) bedeutet, dass Rechnungsdaten das Gerät verlassen. Das muss in LASTENHEFT 5.19, PRIVACY und STORE_LISTING eingetragen werden. Nötig sind ein Auftragsverarbeitungsvertrag (AVV, Art. 28 DSGVO) mit der PA und eine Online-Pflicht nur für das Versenden: Erfassen bleibt offline, die Rechnung wird in eine Warteschlange gestellt und gesendet, sobald Netz da ist. Der Empfang von Rechnungen braucht Abruf (Polling) oder Push.

Quellen PA/API: [Codeur – Guide éditeurs](https://www.codeur.com/blog/guide-facturation-electronique-editeurs-logiciel/), [comparatif Iopole](https://www.comparatif-facture-electronique.fr/iopole-facturation-electronique-avis/), [Digitiz SuperPDP](https://digitiz.fr/superpdp/). Sicherheit für die Preise: **niedrig**, Angebote einholen.

## 4. Weitere Pflichten

- **NF525 / logiciel de caisse:** gilt nur für Kassensoftware, die Zahlungen von **Privatkunden** erfasst (art. 286-I-3° bis CGI). Unternehmen in franchise sind laut BOFiP ausgenommen. Ein reines Rechnungs- und Buchhaltungsprogramm ist keine Kasse. Solange die App keine Barzahlungen von Endkunden erfasst: **nicht nötig**. Sicherheit mittel.
- **FEC** (*fichier des écritures comptables*): nur bei Buchführung mit Bilanz Pflicht, für micro **nicht relevant**. Als späteres Pro-Merkmal denkbar.
- **Loi Toubon:** Oberfläche, AGB, Datenschutzerklärung, Store-Text und Rechnungen müssen auf **Französisch** vorliegen. Eine vollständige Lokalisierung ist Pflicht.
- **Abos / Verbraucherrecht:** Seit dem 1. 6. 2023 gilt die **Kündigung in 3 Klicks** (*résiliation en trois clics*, art. L215-1-1 Code de la consommation). Bei Store-Abos erfolgt die Kündigung über Apple/Google, ein Link „Résilier“ in der App ist trotzdem empfohlen. Bei Verträgen mit Gewerbetreibenden muss der Status geprüft werden.
- **CNIL / DSGVO:** keine Meldepflicht. Datenschutzerklärung auf Französisch, Auftragsverarbeitungsvertrag mit der PA. Datenverarbeitung in der EU ist bei Steuerdaten faktisch Erwartung.
- **App Store:** Die früher verlangte **französische Verschlüsselungserklärung (ANSSI)** ist nur bei proprietärer Kryptografie nötig. Wer nur die Standardverschlüsselung von iOS (HTTPS) verwendet, ist ausgenommen. In App Store Connect die Exportfrage korrekt beantworten. Sicherheit mittel.
- **Google Play:** keine FR-Besonderheit bekannt. Preise in € inkl. TVA 20 %.

## 5. Konkurrenz

Die Preise stammen aus der Erinnerung, Stand etwa 2025/26. **Sicherheit niedrig**, vor der Preisentscheidung prüfen.

| Anbieter | Link | Preis/Monat (ca.) | Plattform | PA-Status |
|---|---|---|---|---|
| Indy | https://www.indy.fr | Gratis-Basis, ca. 12–22 € | Web + App | über Partner-PA |
| Abby | https://abby.fr | Gratis, ca. 9–15 € | Web + App | angekündigt/PA-Partner |
| Freebe | https://www.freebe.me | ca. 10–20 € | Web + App | Partner |
| Tiime | https://www.tiime.fr | Gratis-Basis | Web + App | eigene PA (zugelassen) |
| Henrri | https://www.henrri.com | gratis | Web | Partner |
| Shine | https://www.shine.fr | ab ca. 8 € (Bank) | App + Web | PA-Anbindung |
| Qonto | https://qonto.com/fr/invoicing | ab ca. 9 € (Bank) | App + Web | PA-Anbindung |
| Pennylane | https://www.pennylane.com/fr | ab ca. 14 € | Web | eigene PA (zugelassen) |
| Evoliz | https://www.evoliz.com | ab ca. 10 € | Web | eigene PA |
| Facture.net | https://www.facture.net | gratis | Web | Partner |

**Befund:** Der Markt ist dicht und hat viele **Gratisangebote**, vor allem von Banken. 12,90 € bzw. 17,90 € liegen am oberen Rand für micro. Mögliche Unterscheidungsmerkmale: Offline-Belegfoto, Einhandbedienung, kein Konto bei einer Bank nötig.

## 6. Aufwand und Entscheidung

**Was gebaut werden muss** (grobe Schätzung des Softwareentwicklers):

| Paket | Wochen |
|---|---|
| `TaxProfile` FR (franchise, Grenzen, Sätze 20/10/5,5/2,1 %, Pflichtangaben, Mentions) | 2 |
| Französische Lokalisierung (UI, Handbuch, Store, AGB, Datenschutz) | 2–3 |
| Factur-X-Profil FR (AFNOR-Felder, SIREN-Prüfung) | 1–2 |
| PA-Anbindung (Senden, Status, Empfang, E-Reporting, Warteschlange offline) | 4–6 |
| *Livre des recettes*-Export, URSSAF-Umsatzhilfe | 1 |
| **Summe** | **ca. 10–14 Wochen** plus Test |

**Risiken:**

1. PA-Kosten pro Rechnung schmälern die Marge.
2. Abhängigkeit von einem PA-Partner.
3. Starke Gratiskonkurrenz.
4. Die Regeln ändern sich laufend (jährliche Finanzgesetze).
5. Erstmals verlassen Daten das Gerät.

**Empfehlung:**

1. Jetzt **nichts bauen**, nur Angebote von 2–3 PAs einholen (Iopole, Super PDP, B2Brouter).
2. Ab Anfang 2027 das FR-Paket umsetzen und **vor dem 1. 9. 2027** mit PA-Anbindung starten. Das ist der Zeitpunkt, an dem micro-entrepreneurs aktiv wechseln.
3. Ohne PA-Vertrag **kein** FR-Start. Option (b) nur als Übergang.

**Vorschläge für Prüfpunkte in der realen Welt** (zur Übernahme in SPECIFICATION Abschnitt 14, entscheidet die Hauptsitzung):

- FR-1: Gelten die franchise-Grenzen laut endgültiger LF 2026/2027 weiter? (expert-comptable)
- FR-2: Vollständige Pflichtangaben für die E-Rechnung micro ab 2027 inkl. Kategorie und Kunden-SIREN. (expert-comptable)
- FR-3: Höhe der Sanktionen 15 € oder 50 € je Rechnung, 500 € je fehlendem E-Reporting. (expert-comptable)
- FR-4: NF525 nicht anwendbar bei Rechnungs-App mit erfassten Barzahlungen? (expert-comptable/avocat)
- FR-5: AVV mit der PA und Rolle der App (*solution compatible*) – Haftung. (avocat)
- FR-6: Preise und Vertragsbedingungen der PA-API. (Angebote)
- FR-7: Ist eine Verschlüsselungserklärung für den App Store FR nötig? (Apple-Konto prüfen)
