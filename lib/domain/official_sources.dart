import 'country.dart';

/// Amtliche Quellen für Gesetzestexte und Grenzwerte (Google-Play-Vorgabe
/// „Missing Source Link for Government Information“, Ablehnung 2026-10-24).
/// Dieselbe Liste steht in `docs/STORE_LISTING.md` Abschnitt „QUELLEN
/// (AMTLICHE INFORMATIONEN)“. Prüfung der Adressen: Spezifikation 14, P-R70.
class OfficialSource {
  const OfficialSource(this.country, this.label, this.url);

  final Country country;
  final String label;
  final String url;

  /// Pflichthinweis: kein Angebot einer Behörde.
  static const disclaimer =
      'JeNi bucht ist kein Angebot einer Behörde und mit keiner Behörde '
      'verbunden. Gesetzestexte und Grenzwerte stammen aus diesen '
      'offiziellen Quellen:';

  static const _ris =
      'https://www.ris.bka.gv.at/NormDokument.wxe?Abfrage=Bundesnormen'
      '&Gesetzesnummer=10004873';

  /// UStG 1994, § 11 (Rechnungsangaben).
  static const risUstgAt11 = '$_ris&Paragraf=11';

  /// UStG 1994, § 6 (Abs 1 Z 27 Kleinunternehmer).
  static const risUstgAt6 = '$_ris&Paragraf=6';

  /// UStG 1980, § 14 (Rechnungsangaben).
  static const giiUstgDe14 =
      'https://www.gesetze-im-internet.de/ustg_1980/__14.html';

  /// UStG 1980, § 19 (Kleinunternehmer).
  static const giiUstgDe19 =
      'https://www.gesetze-im-internet.de/ustg_1980/__19.html';

  static const all = [
    OfficialSource(
      Country.at,
      'Österreich – Umsatzsteuergesetz',
      'https://www.ris.bka.gv.at',
    ),
    OfficialSource(
      Country.at,
      'Österreich – Finanzministerium',
      'https://www.bmf.gv.at',
    ),
    OfficialSource(
      Country.at,
      'Österreich – E-Rechnung an den Bund',
      'https://www.erb.gv.at',
    ),
    OfficialSource(
      Country.de,
      'Deutschland – Umsatzsteuergesetz',
      'https://www.gesetze-im-internet.de/ustg_1980/',
    ),
    OfficialSource(
      Country.de,
      'Deutschland – Bundesfinanzministerium',
      'https://www.bundesfinanzministerium.de',
    ),
    OfficialSource(
      Country.de,
      'Deutschland – E-Rechnung (XRechnung)',
      'https://www.e-rechnung-bund.de',
    ),
  ];

  static List<OfficialSource> forCountry(Country c) => [
    for (final s in all)
      if (s.country == c) s,
  ];
}
