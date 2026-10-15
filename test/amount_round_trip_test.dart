import 'package:buchhaltung/core/formatting.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:flutter_test/flutter_test.dart';

/// Vorbelegte Formularfelder (Rechnung bearbeiten, Korrekturentwurf, Beleg,
/// Versand, Skonto, Rabatt) zeigen Fmt.amount bzw. Fmt.quantity und werden mit
/// Money.tryParse zurückgelesen. Gerätetest 0.13.0: „1 900,00“ mit geschütztem
/// Leerzeichen ergab null und die Position 0 €.
void main() {
  for (final country in Country.values) {
    group('Rundlauf Fmt → Money.tryParse (${country.name})', () {
      setUp(() => Fmt.setCountry(country));
      tearDown(() => Fmt.setCountry(Country.at));

      for (final cents in [190000, 123456789, 99, 0, 100000000]) {
        test('Betrag $cents Cent', () {
          final text = Fmt.amount(Money(cents));
          expect(Money.tryParse(text), Money(cents), reason: text);
        });
      }

      for (final milli in [1000, 1500, 1234500, 2000000]) {
        test('Menge $milli', () {
          final text = Fmt.quantity(milli);
          // Mengenfeld: Money parst „1,5“ zu 150 Cent = 1500 Tausendstel.
          expect(Money.tryParse(text)!.cents * 10, milli, reason: text);
        });
      }
    });
  }

  test('alle Leerraumzeichen als Tausendertrenner', () {
    for (final sep in [' ', ' ', ' ', ' ', '\t']) {
      expect(Money.tryParse('1${sep}900,00'), const Money(190000));
      expect(
        Money.tryParse('1${sep}234${sep}567,89 €'),
        const Money(123456789),
      );
    }
  });
}
