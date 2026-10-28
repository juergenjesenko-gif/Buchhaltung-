import 'package:buchhaltung/core/formatting.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/currency.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hauswährung aus dem Land (Umbauplan AP2): AT und DE führen Euro, die
/// Fremdwährungslogik vergleicht gegen die Hauswährung statt fest gegen EUR.
void main() {
  tearDown(() => Fmt.setCountry(Country.at));

  test('AT und DE: Hauswährung Euro', () {
    for (final c in Country.values) {
      expect(c.taxProfile.currency, Currency.eur, reason: c.code);
    }
    Fmt.setCountry(Country.de);
    expect(Currency.home, Currency.eur);
  });

  test('Fremdwährung gegenüber der Hauswährung', () {
    Currency.home = Currency.eur;
    expect(Currency.isForeign('EUR'), isFalse);
    expect(Currency.isForeign('eur'), isFalse);
    expect(Currency.isForeign('USD'), isTrue);
    expect(Currency.isForeign(''), isFalse);
    Currency.home = Currency.gbp;
    expect(Currency.isForeign('EUR'), isTrue);
    expect(Currency.isForeign('GBP'), isFalse);
  });
}
