# Rechtstexte – Übersicht

> Alle Texte sind **ENTWÜRFE der Prüfinstanz „Rechtsanwalt“, nicht anwaltlich
> geprüft** (L-17.11). Prüfpunkte stehen ausschließlich in
> `docs/SPECIFICATION.md` Abschnitt 14 (P-L…).

| Datei | Zweck | Rechtsgrundlage | Fassung | Status |
|---|---|---|---|---|
| [IMPRESSUM.md](IMPRESSUM.md) | Anbieterkennzeichnung Produktseite, App „Rechtliches“, DSA-Händlerangaben | § 5 ECG, § 14 UGB, § 25 MedienG, Art. 30 DSA | 2026-10-12-entwurf | Entwurf, Platzhalter offen |
| [DATENSCHUTZ.md](DATENSCHUTZ.md) | Datenschutzerklärung App und Produktseite (Store-Pflicht-URL) | Art. 13 DSGVO | 2026-10-12-entwurf | Entwurf; ersetzt nach Prüfung `docs/PRIVACY.md` |
| [NUTZUNGSBEDINGUNGEN.md](NUTZUNGSBEDINGUNGEN.md) | Eigene EULA für Google Play und Apple | ABGB, KSchG, VGG, BGB §§ 305 ff., 327 ff., Apple-Lizenzvertragsvorgaben | 2026-10-12-entwurf (= `LegalText.terms.version`) | Entwurf |

## Platzhalter

`{{APP_NAME}} Spirits by JeNiBarb e.U. (Inhaber: Jürgen Jesenko) Sankt Leonhard bei Siebenbrünn 96, 9587 Arnoldstein, Österreich ATU81604346 FN 643550 y, Landesgericht Klagenfurt +43 660 3124252
office@jenibarb.com {{GEWERBE}} Bezirkshauptmannschaft Villach-Land Kärnten
{{FACHGRUPPE}} {{DOMAIN}} {{HOSTER}} {{TAGE}} {{EMAIL_PROVIDER}} Arnoldstein
Klagenfurt {{BETRAG}} {{14}}`

## Stand des Codes, auf dem die Texte beruhen (2026-10-12)

- Netzwerk nur VIES (`lib/services/vat_id/vies_client.dart`), Teilen, Sicherung.
- **Kein** `in_app_purchase` im `pubspec.yaml`: Abo-Abschnitte beschreiben L-22
  vorausschauend und sind in DATENSCHUTZ.md als „noch nicht in der App“
  gekennzeichnet.
- **Keine** KI-Anbindung (kein Treffer für anthropic/claude in `lib/`); L-21
  ist nur angekündigt.

## Offene Punkte

1. Entscheidung Verbraucherschlichtung (Impressum).
2. Haftungshöchstbetrag B2B und Rügefrist (Nutzungsbedingungen 8.2, 9.3).
3. Firmenbucheintrag ja/nein; Gewerbe-Wortlaut.
4. Hoster der Produktseite und E-Mail-Anbieter samt AVV.
5. Vor Einführung Abo/KI: DATENSCHUTZ.md 6 und 9 ergänzen, Fassung erhöhen,
   `LegalText.terms.version` anheben (Bestätigung neu einholen, L-17.4).
6. Anwaltliche Prüfung aller drei Texte (L-17.11).
