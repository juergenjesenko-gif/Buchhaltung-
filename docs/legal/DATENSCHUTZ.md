# Datenschutzerklärung für die App „{{APP_NAME}}“ und die Produktseite

> **ENTWURF – nicht anwaltlich geprüft.** Stand 2026-10-12, Fassung
> 2026-10-12-entwurf. Grundlage: `docs/PRIVACY.md` und Lastenheft 5.19.
> Beschreibt nur Funktionen, die im Code tatsächlich vorhanden sind; mit dem
> Abo (L-22, Paket `in_app_purchase`) und einer KI-Funktion (L-21) ist sie
> **vor** deren Auslieferung zu ergänzen.

## 1. Das Wichtigste in Kürze

- Deine Buchhaltungsdaten bleiben **auf deinem Gerät**. Wir betreiben keinen
  Server, haben kein Nutzerkonto und sehen deine Daten nicht.
- Keine Werbung, kein Tracking, keine Analyse- oder Absturz-Software Dritter.
- Daten verlassen das Gerät nur, wenn du es auslöst oder einschaltest:
  Teilen, Sicherung, UID-Prüfung über VIES.
- Mit uns in Kontakt kommst du nur, wenn du uns schreibst (Support) – dann
  verarbeiten wir deine Nachricht.

## 2. Wer ist verantwortlich?

{{ANBIETER_NAME}}, Einzelunternehmen „Spirits by Jenny Barb“
{{ANSCHRIFT}}, Österreich
E-Mail: {{EMAIL}} · Telefon: {{TELEFON}}

Eine Datenschutzbeauftragte ist nicht bestellt; dazu besteht keine Pflicht
(Art. 37 DSGVO). Datenschutzanfragen bitte an {{EMAIL}}.

## 3. Wer ist wofür verantwortlich? (Rollen)

| Daten | Verantwortlich | Unsere Rolle |
|---|---|---|
| Deine Buchhaltung in der App (Belege, Rechnungen, Kunden, Firmendaten) | **du** als Unternehmerin – auch für Daten deiner Kundinnen und Kunden | keine: wir liefern nur die Software und haben keinen Zugriff |
| Sicherungen in deinem Cloud-Speicher (iCloud, Google Drive …) | du; der Cloud-Dienst nach seinen Bedingungen | keine |
| UID-Prüfung über VIES | du (Abfrage) und die EU-Kommission (Betrieb von VIES) | keine |
| Kauf eines Abos | Apple bzw. Google als eigene Verantwortliche | wir erhalten nur, was der Store uns meldet (siehe 6) |
| Support-Anfragen an uns, Besuch der Produktseite | **wir** | Verantwortliche |

## 4. Verarbeitung in der App auf deinem Gerät

**Welche Daten:** was du eingibst – Firmendaten (Name, Anschrift, Kontakt,
Steuernummer, UID, Bankverbindung), Belege samt Foto, Kundendaten (Name,
Anschrift, UID, E-Mail, Notiz), Rechnungen, Änderungsprotokoll sowie deine
Bestätigung des Hinweises „Keine Steuerberatung“ mit Zeitpunkt und Fassung.

**Wo:** in einer Datenbank und in Bilddateien im privaten Speicher der App.
Schlüssel für die automatische Sicherung liegen im Schlüsselbund (iOS) bzw.
Keystore (Android). Die Android-Systemsicherung und die
Gerät-zu-Gerät-Übertragung sind für die App abgeschaltet.

**Berechtigungen:** Kamera (Belege fotografieren), Fotobibliothek lesen
(vorhandene Fotos hinzufügen), Fotobibliothek schreiben (Rechnung ablegen). Die
App fragt erst, wenn du die Funktion nutzt; ablehnen schränkt nur diese
Funktion ein.

**Hinweis für dich als Unternehmerin:** Für die Daten deiner Kundinnen und
Kunden giltst du als Verantwortliche. Rechtsgrundlage ist in der Regel die
Vertragserfüllung und die steuerliche Aufbewahrungspflicht (Art. 6 Abs 1 lit b
und c DSGVO; § 132 BAO, § 147 AO).

## 5. Wann Daten dein Gerät verlassen

| Vorgang | Wohin | Welche Daten | Wann |
|---|---|---|---|
| Rechnung oder Export teilen | Ziel, das du im Teilen-Dialog wählst | PDF, CSV | nur auf Tippen |
| Sicherung von Hand | Ziel, das du wählst | mit deinem Kennwort verschlüsselte Datei (AES-256-GCM) | nur auf Tippen |
| Automatische Sicherung | einmal gewählter Ordner, z. B. iCloud Drive, Google Drive | verschlüsselte Datei; Upload durch Betriebssystem bzw. Cloud-Dienst | nur wenn eingeschaltet (Standard: aus) |
| UID-Prüfung | VIES der Europäischen Kommission, direkt vom Gerät | geprüfte UID, deine eigene UID, technisch deine IP-Adresse | auf Tippen oder wöchentlich, wenn eingeschaltet (Standard: aus) |

Wir erhalten in keinem dieser Fälle Daten oder Schlüssel. Ab Übergabe gelten
die Bedingungen des jeweiligen Dienstes. Manche Cloud-Dienste speichern auch
außerhalb der EU; das wählst du mit dem Dienst.

## 6. Abonnement über Google Play und App Store

*(Gilt ab Einführung des Abos, L-22; derzeit noch nicht in der App.)*
Kauf, Bezahlung, Rechnung und Erstattung wickeln Apple bzw. Google als eigene
Verantwortliche ab; es gelten deren Datenschutzerklärungen. Die App prüft auf
deinem Gerät den vom Store signierten Kaufbeleg (Produkt, Ablaufdatum). Wir
erhalten vom Store nur zusammengefasste Verkaufs- und Auszahlungsberichte und
anonyme Absturzstatistiken der Stores, keine Buchhaltungsdaten. Name oder
E-Mail von Käuferinnen erhalten wir grundsätzlich nicht.

## 7. Wenn du uns schreibst (Support)

Wir verarbeiten deine E-Mail-Adresse, deinen Namen und den Inhalt deiner
Nachricht, um deine Anfrage zu beantworten (Art. 6 Abs 1 lit b bzw. f DSGVO;
berechtigtes Interesse: Kundenbetreuung). Schick uns bitte keine
Buchhaltungsdaten oder Sicherungen, wenn es nicht nötig ist. Ein freiwilliger
Fehlerbericht wird nur gesendet, wenn du ihn selbst per E-Mail abschickst.
E-Mail-Anbieter: {{EMAIL_PROVIDER}} (Auftragsverarbeiter, Sitz {{SITZ}}).
Löschung: 3 Jahre nach Abschluss der Anfrage; soweit geschäftliche Unterlagen
betroffen sind, nach Ablauf der Aufbewahrungsfrist (§ 132 BAO: 7 Jahre).

## 8. Produktseite {{DOMAIN}}

Ohne Cookies, ohne Tracking, ohne eingebundene Schriften oder Skripte Dritter.
Der Hosting-Anbieter {{HOSTER}} verarbeitet beim Aufruf technisch die
IP-Adresse, Zeit, aufgerufene Seite und Browserangaben in Server-Protokollen
(Art. 6 Abs 1 lit f DSGVO; Interesse: sicherer Betrieb). Speicherdauer:
{{TAGE}} Tage. Auftragsverarbeitungsvertrag mit dem Hoster besteht.
{{Bei Hosting außerhalb der EU, z. B. GitHub Pages: Übermittlung in die USA
auf Grundlage des EU-US Data Privacy Framework (Art. 45 DSGVO) angeben.}}

## 9. Künstliche Intelligenz

Die App enthält derzeit **keine** KI-Funktion und überträgt keine Daten an
KI-Anbieter. Wird eine solche Funktion eingeführt, ist sie freiwillig, wird
vorher erklärt und diese Erklärung wird zuvor ergänzt.

## 10. Deine Rechte

Du hast das Recht auf Auskunft, Berichtigung, Löschung, Einschränkung,
Datenübertragbarkeit und Widerspruch (Art. 15–21 DSGVO) sowie auf Widerruf
einer Einwilligung mit Wirkung für die Zukunft. Zu Daten auf deinem Gerät
können wir keine Auskunft geben, weil wir sie nicht haben – du hast dort selbst
vollen Zugriff, Export und Löschung. Wende dich an {{EMAIL}}.

Beschwerde: Österreichische Datenschutzbehörde, Barichgasse 40–42, 1030 Wien,
www.dsb.gv.at – oder die Aufsichtsbehörde deines Wohnorts bzw. Arbeitsplatzes.

## 11. Speicherdauer auf deinem Gerät

Bis du die Daten löschst oder die App deinstallierst (dann unwiderruflich).
Beachte deine Aufbewahrungspflicht (Österreich 7 Jahre, § 132 BAO;
Deutschland bis zu 8 bzw. 10 Jahre, § 147 AO) und sichere regelmäßig.

## 12. Keine automatisierten Entscheidungen

Es gibt keine automatisierte Entscheidungsfindung oder Profilbildung nach
Art. 22 DSGVO. Bereitstellung der Daten ist freiwillig; ohne Eingaben kann die
App ihre Funktion nicht erfüllen.

## 13. Änderungen

Ändert sich die App datenschutzrelevant, passen wir diese Erklärung an; die
aktuelle Fassung findest du in der App unter „Rechtliches“ und auf
{{DOMAIN}}/datenschutz.
