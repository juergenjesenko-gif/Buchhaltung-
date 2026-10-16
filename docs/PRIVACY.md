# Datenschutzerklärung

> **Vorlage.** Beide Stores verlangen eine Datenschutzerklärung unter einer
> öffentlich erreichbaren URL – auch bei einer App, die keine Daten überträgt.
> Vor der Veröffentlichung sind die mit `<…>` markierten Stellen zu ersetzen.
> GitHub Pages genügt als Hosting. Bei kommerzieller Nutzung ist eine
> anwaltliche Prüfung sinnvoll; diese Vorlage ist keine Rechtsberatung.

**Stand:** <Datum>

## Verantwortlicher

```
Spirits by JeNiBarb e.U.
Sankt Leonhard bei Siebenbrünn 96
9587 Arnoldstein
Österreich
E-Mail: office@jenibarb.com
```

## Kurzfassung

Die App **JeNi bucht** verarbeitet deine Daten auf deinem Gerät. Der Anbieter
betreibt keinen Server und erhält keine deiner Daten. Es gibt keine
Nutzerkonten, keine Analyse-Werkzeuge und keine Werbung. Daten verlassen das
Gerät nur in den unten genannten Fällen, die du selbst auslöst oder einschaltest.

## Welche Daten die App verarbeitet

Alle Daten gibst du selbst ein oder erzeugst sie durch die Nutzung:

- **Unternehmensdaten:** Firmenname, Inhaber, Anschrift, Kontaktdaten,
  Steuernummer, UID/USt-IdNr., Bankverbindung
- **Belege:** Datum, Betrag, Umsatzsteuersatz, Beschreibung, Geschäftspartner,
  Kategorie, Zahlungsart, Notiz sowie das Belegfoto
- **Kundendaten:** Name, Anschrift, UID, E-Mail-Adresse, Notiz
- **Rechnungen:** Nummer, Datum, Positionen, Beträge, Status, Zahlungserinnerungen
  und Mahnungen
- **Übernommene Dateien:** PDF- und E-Rechnungen, die du an die App teilst, als
  unveränderte Originaldatei mit Prüfsumme
- **Berichte von Verkaufsplattformen** (Amazon, PayPal, Shopify, Stripe), die du
  an die App teilst: übernommen werden nur Monatssummen und Transaktionsnummern;
  Namen, Anschriften, E-Mail-Adressen und Telefonnummern deiner Käuferinnen und
  Käufer verwirft die App beim Einlesen

## Wo diese Daten liegen

In einer SQLite-Datenbank und in Bilddateien im privaten Verzeichnis der App auf
deinem Gerät. Andere Apps haben darauf keinen Zugriff.

Die App überträgt **keine** dieser Daten an den Anbieter oder an Dritte. Sie
enthält keine Analyse-Bibliothek, kein Crash-Reporting und keine Werbe-SDKs. Die
App baut von sich aus **keine Netzwerkverbindungen** auf – mit einer Ausnahme,
die du selbst einschaltest:

**UID-Prüfung über VIES:** Tippst du bei einer UID-Nummer auf „Jetzt prüfen",
oder hast du die wöchentliche Prüfung eingeschaltet, sendet die App die
UID-Nummer (und deine eigene UID als Anfragende) direkt an das
Mehrwertsteuer-Informationsaustauschsystem VIES der Europäischen Kommission.
Dabei wird technisch auch deine IP-Adresse übertragen. Zweck ist die Prüfung der
Gültigkeit, wie sie das Umsatzsteuerrecht verlangt (Art. 6 Abs. 1 lit. c DSGVO).
Verantwortlich für diese Abfrage bist du; die Kommission verarbeitet die Daten
nach ihren eigenen Datenschutzbestimmungen. Der Anbieter der App erhält dabei
nichts. Die wöchentliche Prüfung ist standardmäßig aus und jederzeit
abschaltbar.

**Wechselkurse von der EZB:** Tippst du bei einem Beleg in fremder Währung auf
„Kurs abrufen", lädt die App eine öffentliche Kursdatei direkt von der
Europäischen Zentralbank (ecb.europa.eu). Dabei werden technisch nur deine
IP-Adresse und übliche Verbindungsdaten übertragen – **keine Belegdaten, keine
Beträge, nicht einmal die Währung**. Die Kurse werden auf dem Gerät gespeichert
und danach offline genutzt. Ohne Tippen findet kein Abruf statt; einen Kurs
kannst du immer auch von Hand eintragen. Rechtsgrundlage: Art. 6 Abs. 1 lit. b
und f DSGVO (Funktion auf deinen Wunsch). Der Anbieter der App erhält dabei
nichts. Die EZB verarbeitet die Verbindungsdaten nach ihren eigenen
Datenschutzbestimmungen.

**Datensicherung:** Auf deinen Wunsch erstellt die App eine mit deinem Kennwort
verschlüsselte Sicherungsdatei (AES-256-GCM). Wohin sie geht, bestimmst du im
Teilen-Dialog, etwa in deinen eigenen Cloud-Speicher; dort gelten die
Bedingungen dieses Dienstes. Der Anbieter erhält weder die Datei noch das
Kennwort und kann die Sicherung nicht öffnen.

**Automatische Sicherung:** Schaltest du sie ein, schreibt die App die
verschlüsselte Sicherung regelmäßig in einen Ordner, den du einmal gewählt
hast (z. B. in iCloud Drive oder Google Drive). Die Übertragung in die Cloud
übernimmt das Betriebssystem bzw. der jeweilige Dienst unter dessen
Bedingungen; viele speichern außerhalb der EU. Der Schlüssel liegt nur auf
deinem Gerät (Schlüsselbund bzw. Keystore, nicht synchronisiert); du erhältst
einen Wiederherstellungscode. Der Anbieter erhält weder Datei noch Schlüssel.
Die Funktion ist standardmäßig aus.

**iCloud (iPhone und iPad):** Ist iCloud angemeldet, legt die automatische
Sicherung die verschlüsselte Datei im App-eigenen Ordner „JeNi bucht“ in
deinem iCloud Drive ab (in der Dateien-App sichtbar). Empfänger ist Apple als
Anbieter deines iCloud-Kontos, unter dessen Bedingungen und mit Servern auch
außerhalb der EU. Apple sieht nur Dateiname, Größe und Zeitpunkt; der
Schlüssel wird nie über den iCloud-Schlüsselbund synchronisiert. Abschalten
jederzeit unter Einstellungen → Datensicherung.

**Lernen je Lieferant:** Die App merkt sich beim Speichern eines Belegs Name,
Kategorie, Steuersatz, Währung und Zahlungsart je Lieferant, um sie beim
nächsten Beleg vorzuschlagen. Das bleibt in der Datenbank auf deinem Gerät
(und in deiner verschlüsselten Sicherung); es wird nichts übertragen.

**App-Sperre:** Schaltest du sie ein, speichert die App nur einen gesalzenen
Hash deiner PIN (Argon2id) im Schlüsselbund bzw. Keystore des Geräts, nie die
PIN selbst und nie in einer Sicherung. Fingerabdruck und Face ID wertet das
Betriebssystem aus; die App erhält **keine biometrischen Daten**, nur die
Rückmeldung „erkannt" oder „nicht erkannt". Dabei werden keine Daten
übertragen. Die Funktion ist standardmäßig aus.

Die automatische Sicherung von Android (Google Drive) und die
Gerät-zu-Gerät-Übertragung sind für diese App **deaktiviert**
(`data_extraction_rules.xml`), damit deine Buchhaltungsdaten nicht ohne dein
Zutun in eine Cloud gelangen.

## Wann Daten das Gerät verlassen

Nur in diesen Fällen, die du auslöst oder einschaltest:

- **Rechnung als PDF teilen** – du wählst im Systemdialog selbst das Ziel
  (E-Mail, Messenger, Cloud-Ordner)
- **Export für die Steuerberatung** – gleiches Prinzip
- **U30-Datei für FinanzOnline** (Österreich) – gleiches Prinzip; die Datei
  enthält Steuernummer, Zeitraum und Kennzahlen der Voranmeldung. Hochladen
  machst du selbst; die App verbindet sich nicht mit dem Finanzamt
- **Datensicherung von Hand** – verschlüsselte Datei, Ziel wählst du im
  Teilen-Dialog
- **Automatische Sicherung** (standardmäßig aus) – verschlüsselte Datei in einen
  Ordner, den du einmal gewählt hast, z. B. Google Drive, oder auf dem iPhone
  in den Ordner „JeNi bucht“ in deinem iCloud Drive (Apple)
- **UID-Prüfung über VIES** – auf Tippen, oder wöchentlich, wenn du es
  eingeschaltet hast: UID-Nummern gehen an die EU-Kommission
- **Kurs abrufen** – nur auf Tippen bei einem Beleg in fremder Währung: die App
  lädt die Referenzkurse der Europäischen Zentralbank
- **Rechnung über einen QR-Link laden** – nur auf Tippen „Laden“: die App ruft
  die Adresse aus dem QR-Code beim Server der angezeigten Domain ab (betrieben
  vom Rechnungsaussteller). Dieser erfährt die Adresse – sie kann eine
  Rechnungs- oder Kundennummer enthalten –, deine IP-Adresse und technische
  Verbindungsdaten. Daten aus der App werden nicht gesendet. „Im Browser
  öffnen“ übergibt die Adresse an deinen Browser
- **Abo über Google Play bzw. den App Store** – beim Start der App und bei
  „Kauf wiederherstellen“ fragt die App über die Store-Schnittstelle des
  Geräts (Google Play Billing bzw. StoreKit) nach deinen aktiven Abos; beim
  Kauf öffnet das Kaufblatt des Stores. Die App übergibt dabei nur die
  Produktkennungen (z. B. `pro_monat`). Löst du einen **Promo-Code** ein,
  geht der Code an Apple (im Einlöseblatt des App Store) bzw. an Google
  (über die Adresse play.google.com/redeem). Store-Konto, Zahlungsdaten und
  Kaufbelege verarbeiten Apple bzw. Google als eigene Verantwortliche nach
  ihren Datenschutzerklärungen; der Anbieter erhält nur zusammengefasste
  Verkaufs- und Auszahlungsberichte ohne Namen oder E-Mail. Auf dem Gerät
  speichert die App nur Abostufe, Zeitpunkt der letzten Bestätigung und
  Testbeginn – im Schlüsselbund bzw. Keystore, nicht in der Sicherung

**Hinweis zur Belegerkennung:** Fotografierte Belege werden auf deinem Gerät
ausgelesen (Datum, Betrag, Steuersatz, Lieferant, UID, Rechnungsnummer).
Foto und erkannter Text verlassen das Gerät dafür **nicht**; die Erkennung
funktioniert auch im Flugmodus. Unter **iOS** nutzt die App die
Texterkennung von Apple (Vision), die nichts überträgt. Unter **Android**
nutzt sie die in die App eingebundene Bibliothek Google ML Kit (Text- und
QR-Code-Erkennung, beide fest in der App enthalten). Diese sendet
nach Angaben von Google **Nutzungs- und Diagnosedaten** (etwa Gerätetyp,
App-Version, Leistung und Fehler der Erkennung) an Google – **keine Fotos und
keinen erkannten Text**. Ein offizielles Abschalten bietet Google nicht an;
du kannst die Erkennung in den Einstellungen („Belege auslesen“) ganz
ausschalten. Empfänger ist Google; Umfang und Rechtsgrundlage werden noch
fachlich geprüft (Prüfpunkte P-R19, P-D21 der Spezifikation) und vor
Veröffentlichung hier verbindlich beschrieben.

**Hinweis zum Diktieren:** Die App enthält keine Spracherkennung und überträgt
keine Sprache. Wer Kommentare über das Mikrofon der Systemtastatur diktiert,
nutzt die Diktierfunktion des Geräts; je nach Tastatur und Einstellung sendet
sie die Sprache an Google bzw. Apple. Das liegt außerhalb der App; maßgeblich
ist die Datenschutzerklärung des Tastaturanbieters.

In allen Fällen bestimmst du, wohin die Daten gehen; der Anbieter erhält nichts. Ab diesem Zeitpunkt gilt die
Datenschutzerklärung des jeweiligen Dienstes.

## Berechtigungen und wozu sie dienen

| Berechtigung | Zweck |
|---|---|
| Kamera | Belege abfotografieren |
| Fotobibliothek (lesen) | Bereits vorhandene Belegfotos hinzufügen |
| Fotobibliothek (schreiben) | Eine erstellte Rechnung in der Fotobibliothek ablegen |
| Face ID / Biometrie | Nur bei eingeschalteter App-Sperre: Entsperren; die Auswertung erfolgt durch das System |

Die App fragt jede Berechtigung erst dann ab, wenn du die zugehörige Funktion
nutzt. Verweigerte Berechtigungen schränken nur diese Funktion ein.

## Rechtsgrundlage

Für die Verarbeitung auf deinem Gerät ist der Anbieter nicht Verantwortlicher im
Sinne der DSGVO, da er keinen Zugriff auf die Daten hat. Verarbeitest du in der
App personenbezogene Daten Dritter – etwa Kundenanschriften –, bist **du** dafür
der Verantwortliche.

## Speicherdauer und Löschung

Die Daten bleiben so lange auf dem Gerät, bis du sie löschst. Belege löschst du
einzeln in der App; das Löschen wird im Änderungsprotokoll vermerkt.
Deinstallieren der App entfernt alle Daten unwiderruflich.

**Wichtig:** Steuerliche Aufbewahrungsfristen (Österreich 7 Jahre nach § 132 BAO,
Deutschland 8 Jahre für Buchungsbelege nach § 147 AO) gelten unabhängig von der
App. Sichere deine Daten daher regelmäßig über die Exportfunktion.

## Deine Rechte

Da der Anbieter keine deiner Daten verarbeitet, kann er zu ihnen weder Auskunft
geben noch sie löschen – du hast durch die App selbst vollen Zugriff. Für Fragen
zur App erreichst du uns unter der oben genannten Adresse.

## Änderungen

Ändert sich die Funktionsweise der App in datenschutzrelevanter Weise, wird diese
Erklärung angepasst und das Datum oben aktualisiert.
