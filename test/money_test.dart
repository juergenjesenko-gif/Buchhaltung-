import 'package:buchhaltung/domain/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money.tryParse', () {
    test('liest deutsches Format mit Komma', () {
      expect(Money.tryParse('1234,56'), const Money(123456));
      expect(Money.tryParse('0,99'), const Money(99));
    });

    test('liest deutsches Format mit Tausenderpunkt', () {
      expect(Money.tryParse('1.234,56'), const Money(123456));
      expect(Money.tryParse('1.000.000,00'), const Money(100000000));
    });

    test('liest englisches Format mit Punkt als Dezimaltrenner', () {
      expect(Money.tryParse('1234.56'), const Money(123456));
      expect(Money.tryParse('1,234.56'), const Money(123456));
    });

    test('behandelt einen einzelnen Punkt als Dezimaltrenner', () {
      // "12.50" ist praktisch immer als zwölf-fünfzig gemeint, nicht als 1250.
      expect(Money.tryParse('12.50'), const Money(1250));
    });

    test('ignoriert Eurozeichen und Leerzeichen', () {
      expect(Money.tryParse(' 42,00 € '), const Money(4200));
    });

    test('liest ganze Zahlen ohne Dezimalstellen', () {
      expect(Money.tryParse('50'), const Money(5000));
    });

    test('liest negative Beträge', () {
      expect(Money.tryParse('-12,34'), const Money(-1234));
    });

    test('gibt null bei unbrauchbarer Eingabe', () {
      expect(Money.tryParse(''), isNull);
      expect(Money.tryParse('   '), isNull);
      expect(Money.tryParse('abc'), isNull);
    });
  });

  group('Arithmetik', () {
    test('addiert und subtrahiert ohne Rundungsfehler', () {
      // Der Klassiker, an dem Fließkommazahlen scheitern: 0,1 + 0,2 == 0,3
      final result = Money.fromEuro(0.1) + Money.fromEuro(0.2);
      expect(result, Money.fromEuro(0.3));
      expect(result.cents, 30);
    });

    test('summiert eine Liste', () {
      final amounts = [const Money(1999), const Money(550), const Money(1)];
      expect(amounts.sum, const Money(2550));
    });

    test('summiert eine leere Liste zu null', () {
      expect(<Money>[].sum, const Money.zero());
    });

    test('multipliziert kaufmännisch gerundet', () {
      // 3 × 3,33 € = 9,99 €
      expect(const Money(333).times(3), const Money(999));
      expect(const Money(100).times(1.5), const Money(150));
      // 0,03 € × 1,5 = 0,045 € – wird auf ganze Cent aufgerundet
      expect(const Money(3).times(1.5), const Money(5));
      // 0,03 € × 0,5 = 0,015 € – ebenfalls aufgerundet, nie abgeschnitten
      expect(const Money(3).times(0.5), const Money(2));
    });

    test('vergleicht Beträge', () {
      expect(const Money(100) > const Money(99), isTrue);
      expect(const Money(100) <= const Money(100), isTrue);
      expect(const Money(-1).isNegative, isTrue);
      expect(const Money(-500).abs, const Money(500));
    });
  });
}
