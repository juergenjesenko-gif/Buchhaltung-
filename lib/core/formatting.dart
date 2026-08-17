import 'package:intl/intl.dart';

import '../domain/country.dart';
import '../domain/money.dart';

/// Zentrale Formatierung. Beträge und Datumsangaben sollen in der ganzen App
/// identisch aussehen – und zwar so, wie es ein Steuerberater erwartet.
class Fmt {
  Fmt._();

  static String _locale = 'de_AT';

  /// Setzt das Locale anhand des Firmensitzes. Die Unterschiede sind klein
  /// (Trennzeichen, Position des Eurozeichens), fallen aber auf.
  static void setCountry(Country country) {
    _locale = country == Country.de ? 'de_DE' : 'de_AT';
  }

  static NumberFormat get _currency =>
      NumberFormat.currency(locale: _locale, symbol: '€');
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
  static String date(DateTime value) =>
      DateFormat('dd.MM.yyyy', _locale).format(value);

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

  /// "20 %" bzw. "10,7 %"
  static String vatRate(int permille) => permille % 10 == 0
      ? '${permille ~/ 10} %'
      : '${(permille / 10).toStringAsFixed(1)} %';
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

  final DateTime from;
  final DateTime to;
  final String label;

  bool contains(DateTime date) =>
      !date.isBefore(from) && !date.isAfter(to.add(const Duration(days: 1)));
}
