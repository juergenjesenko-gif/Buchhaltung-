import 'package:buchhaltung/core/formatting.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Formate je Locale und Währung (Umbauplan AP1, FA-1.20). AT/DE bleiben
/// unverändert; englische Locales für die späteren Länder UK, IE, US.
void main() {
  setUpAll(initializeDateFormatting);
  tearDown(() => Fmt.setCountry(Country.at));

  final betrag = Money(123456);
  final tag = DateTime(2026, 8, 16);

  test('AT und DE wie bisher', () {
    Fmt.setCountry(Country.at);
    // de_AT gruppiert Tausender mit geschütztem Leerzeichen (intl, unverändert).
    expect(Fmt.money(betrag), '€\u00a01\u00a0234,56');
    expect(Fmt.date(tag), '16.08.2026');
    expect(Fmt.vatRate(200), '20 %');
    expect(Fmt.vatRate(107), '10,7 %');
    Fmt.setCountry(Country.de);
    expect(Fmt.money(betrag), '1.234,56\u00a0€');
  });

  test('UK: Pfund, Tag/Monat/Jahr', () {
    Fmt.configure(locale: 'en_GB', symbol: '£');
    expect(Fmt.money(betrag), '£1,234.56');
    expect(Fmt.amount(betrag), '1,234.56');
    expect(Fmt.date(tag), '16/08/2026');
    expect(Fmt.vatRate(200), '20%');
  });

  test('Irland: Euro in englischer Schreibweise', () {
    Fmt.configure(locale: 'en_IE');
    expect(Fmt.money(betrag), '€1,234.56');
    expect(Fmt.vatRate(135), '13.5%');
  });

  test('USA: Dollar, Monat/Tag/Jahr', () {
    Fmt.configure(locale: 'en_US', symbol: r'$');
    expect(Fmt.money(betrag), r'$1,234.56');
    expect(Fmt.date(tag), '8/16/2026');
  });
}
