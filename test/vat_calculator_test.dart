import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/services/vat_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fromGross', () {
    test('rechnet 20 % aus einem Bruttobetrag heraus (Österreich)', () {
      final split = VatCalculator.fromGross(const Money(12000), 200);
      expect(split.net, const Money(10000));
      expect(split.vat, const Money(2000));
      expect(split.gross, const Money(12000));
    });

    test('rechnet 19 % aus einem Bruttobetrag heraus (Deutschland)', () {
      final split = VatCalculator.fromGross(const Money(11900), 190);
      expect(split.net, const Money(10000));
      expect(split.vat, const Money(1900));
    });

    test(
      'behält den Bruttobetrag exakt, auch wenn die Division nicht aufgeht',
      () {
        // 10,00 € brutto bei 20 %: netto 8,3333… – die Steuer nimmt den Rest auf.
        final split = VatCalculator.fromGross(const Money(1000), 200);
        expect(split.gross, const Money(1000));
        expect(split.net, const Money(833));
        expect(split.vat, const Money(167));
        expect(split.isConsistent, isTrue);
      },
    );

    test('liefert bei 0 % netto gleich brutto', () {
      final split = VatCalculator.fromGross(const Money(5000), 0);
      expect(split.net, const Money(5000));
      expect(split.vat, const Money.zero());
    });

    test('hält netto + ust == brutto über alle Sätze und viele Beträge', () {
      // Der wichtigste Test der App: es darf keinen Betrag geben, bei dem die
      // Summe nicht aufgeht.
      for (final permille in [0, 70, 100, 130, 190, 200]) {
        for (var cents = 1; cents <= 2000; cents++) {
          final split = VatCalculator.fromGross(Money(cents), permille);
          expect(
            split.isConsistent,
            isTrue,
            reason: 'Inkonsistent bei $cents Cent und $permille Promille',
          );
          expect(split.gross.cents, cents);
        }
      }
    });
  });

  group('fromNet', () {
    test('schlägt die Steuer auf', () {
      final split = VatCalculator.fromNet(const Money(10000), 200);
      expect(split.vat, const Money(2000));
      expect(split.gross, const Money(12000));
    });

    test('rundet die Steuer kaufmännisch', () {
      // 3,33 € netto bei 20 % = 0,666 € Steuer -> 0,67 €
      final split = VatCalculator.fromNet(const Money(333), 200);
      expect(split.vat, const Money(67));
      expect(split.gross, const Money(400));
    });

    test('hält netto + ust == brutto über alle Sätze und viele Beträge', () {
      for (final permille in [0, 70, 100, 130, 190, 200]) {
        for (var cents = 1; cents <= 2000; cents++) {
          final split = VatCalculator.fromNet(Money(cents), permille);
          expect(split.isConsistent, isTrue);
          expect(split.net.cents, cents);
        }
      }
    });
  });

  group('exempt', () {
    test('setzt keine Steuer an', () {
      final split = VatCalculator.exempt(const Money(9999));
      expect(split.net, const Money(9999));
      expect(split.gross, const Money(9999));
      expect(split.vat, const Money.zero());
      expect(split.permille, 0);
    });
  });

  group('Steuersätze der Länderprofile', () {
    test('Österreich kennt 20, 13, 10 und 0 Prozent', () {
      expect(TaxProfile.austria.vatRates.map((r) => r.permille).toList(), [
        200,
        130,
        100,
        0,
      ]);
      expect(TaxProfile.austria.defaultVatRate.permille, 200);
    });

    test('Deutschland kennt 19, 7 und 0 Prozent', () {
      expect(TaxProfile.germany.vatRates.map((r) => r.permille).toList(), [
        190,
        70,
        0,
      ]);
      expect(TaxProfile.germany.defaultVatRate.permille, 190);
    });

    test('findet einen Satz über seinen Promillewert', () {
      expect(TaxProfile.austria.rateByPermille(130)?.permille, 130);
      expect(TaxProfile.germany.rateByPermille(130), isNull);
    });
  });
}
