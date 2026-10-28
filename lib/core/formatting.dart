import '../domain/fiscal_year.dart';
import 'package:intl/intl.dart';

import '../domain/country.dart';
import '../domain/money.dart';
import '../domain/currency.dart';

/// Zentrale Formatierung. Beträge und Datumsangaben sollen in der ganzen App
/// identisch aussehen – und zwar so, wie es ein Steuerberater erwartet.
class Fmt {
  Fmt._();

  static String _locale = 'de_AT';
  static String _symbol = '€';

  /// Aktuelles Format-Locale, z. B. `de_AT` oder `en_GB`.
  static String get locale => _locale;

  /// Setzt das Locale anhand des Firmensitzes. Die Unterschiede sind klein
  /// (Trennzeichen, Position des Eurozeichens), fallen aber auf.
  static void setCountry(Country country) {
    Currency.home = country.taxProfile.currency;
    configure(
      locale: country == Country.de ? 'de_DE' : 'de_AT',
      symbol: Currency.home.symbol,
    );
  }

  /// Format-Locale (Sprache und Land, z. B. `en_GB`) und Währungszeichen
  /// (Umbauplan AP1, `docs/maerkte/Umbauplan_Laender.md`). Das Locale muss
  /// mit `initializeDateFormatting` geladen sein.
  static void configure({required String locale, String symbol = '€'}) {
    _locale = locale;
    _symbol = symbol;
  }

  static bool get _german => _locale.startsWith('de');

  static NumberFormat get _currency =>
      NumberFormat.currency(locale: _locale, symbol: _symbol);
  static NumberFormat get _decimal => NumberFormat('#,##0.00', _locale);

  /// "1.234,56 €"
  static String money(Money value) => _currency.format(value.asEuro);

  /// Ohne Währungszeichen – für Tabellen und Exporte in der Anzeige.
  static String amount(Money value) => _decimal.format(value.asEuro);

  /// Vorzeichenbehaftet mit explizitem Plus, für Salden.
  static String signedMoney(Money value) {
    final formatted = money(value.abs);
    if (value.isZero) return formatted;
    return value.isNegative ? '−$formatted' : '+$formatted';
  }

  /// "16.08.2026"
  /// Wartezeit, z. B. „45 s" oder „2 min 05 s".
  static String duration(Duration value) {
    final s = value.isNegative ? 0 : (value.inMilliseconds + 999) ~/ 1000;
    if (s < 60) return '$s s';
    final rest = (s % 60).toString().padLeft(2, '0');
    return '${s ~/ 60} min $rest s';
  }

  /// Deutsch „16.08.2026“, sonst das Kurzformat des Locales
  /// (en_GB „16/08/2026“, en_US „8/16/2026“).
  static String date(DateTime value) => _german
      ? DateFormat('dd.MM.yyyy', _locale).format(value)
      : DateFormat.yMd(_locale).format(value);

  /// Datum mit Uhrzeit, z. B. für Kommentare: „12.10.2026, 14:05“.
  static String dateTime(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${date(value)}, ${two(value.hour)}:${two(value.minute)}';
  }

  /// "August 2026"
  static String monthYear(DateTime value) =>
      DateFormat('MMMM yyyy', _locale).format(value);

  /// "Aug 26"
  static String shortMonth(DateTime value) =>
      DateFormat('MMM yy', _locale).format(value);

  /// Datum im ISO-Format – das erwarten alle Exportformate.
  static String isoDate(DateTime value) =>
      value.toIso8601String().substring(0, 10);

  /// Menge ohne unnötige Nachkommastellen: "2" statt "2,000", aber "1,5".
  static String quantity(int quantityMilli) {
    if (quantityMilli % 1000 == 0) return (quantityMilli ~/ 1000).toString();
    return NumberFormat('#,##0.###', _locale).format(quantityMilli / 1000);
  }

  /// "20 %" bzw. "10,7 %"; englisch "20%" bzw. "13.5%".
  static String vatRate(int permille) {
    final number = permille % 10 == 0
        ? '${permille ~/ 10}'
        : NumberFormat('0.0', _locale).format(permille / 10);
    return _german ? '$number %' : '$number%';
  }
}

/// Erster und letzter Tag eines Monats bzw. Jahres – überall dort gebraucht,
/// wo ein Zeitraum ausgewertet wird.
class Period {
  const Period(this.from, this.to, this.label);

  factory Period.month(DateTime anchor) {
    final from = DateTime(anchor.year, anchor.month, 1);
    final to = DateTime(anchor.year, anchor.month + 1, 0);
    return Period(from, to, Fmt.monthYear(anchor));
  }

  factory Period.quarter(int year, int quarter) {
    final startMonth = (quarter - 1) * 3 + 1;
    return Period(
      DateTime(year, startMonth, 1),
      DateTime(year, startMonth + 3, 0),
      'Q$quarter $year',
    );
  }

  factory Period.year(int year) =>
      Period(DateTime(year, 1, 1), DateTime(year, 12, 31), year.toString());

  /// Wirtschaftsjahr der Gewinnermittlung, das im Kalenderjahr [endYear]
  /// endet (L-24). Beim Kalenderjahr identisch mit [Period.year].
  factory Period.fiscalYear(
    FiscalYear fiscalYear,
    int endYear,
    List<String> monthNames,
  ) => Period(
    fiscalYear.startOf(endYear),
    fiscalYear.endOf(endYear),
    fiscalYear.label(endYear, monthNames),
  );

  final DateTime from;
  final DateTime to;
  final String label;

  bool contains(DateTime date) =>
      !date.isBefore(from) && !date.isAfter(to.add(const Duration(days: 1)));
}
