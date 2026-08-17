import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/services/small_business_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SmallBusinessAssessment assessAt(int euro, {int previousEuro = 0}) =>
      SmallBusinessMonitor.assess(
        taxProfile: TaxProfile.austria,
        isSmallBusiness: true,
        currentYearTurnover: Money.fromEuro(euro),
        previousYearTurnover: Money.fromEuro(previousEuro),
      );

  SmallBusinessAssessment assessDe(int euro, {int previousEuro = 0}) =>
      SmallBusinessMonitor.assess(
        taxProfile: TaxProfile.germany,
        isSmallBusiness: true,
        currentYearTurnover: Money.fromEuro(euro),
        previousYearTurnover: Money.fromEuro(previousEuro),
      );

  group('Österreich – 55.000 € mit 10 % Toleranz', () {
    test('deutlich unter der Grenze ist unauffällig', () {
      final result = assessAt(20000);
      expect(result.status, SmallBusinessStatus.ok);
      expect(result.needsAttention, isFalse);
      expect(result.headroom, Money.fromEuro(35000));
    });

    test('ab 80 Prozent wird gewarnt', () {
      // 80 % von 55.000 = 44.000
      expect(assessAt(43999).status, SmallBusinessStatus.ok);
      expect(assessAt(44000).status, SmallBusinessStatus.approaching);
      expect(assessAt(44000).needsAttention, isTrue);
    });

    test('genau auf der Grenze gilt noch als eingehalten', () {
      expect(assessAt(55000).status, SmallBusinessStatus.approaching);
    });

    test('knapp darüber greift die Toleranz', () {
      final result = assessAt(56000);
      expect(result.status, SmallBusinessStatus.withinTolerance);
      expect(result.message, contains('Toleranz'));
    });

    test('an der Toleranzgrenze gilt die Befreiung noch', () {
      expect(assessAt(60500).status, SmallBusinessStatus.withinTolerance);
    });

    test('über der Toleranz fällt die Befreiung sofort weg', () {
      final result = assessAt(60501);
      expect(result.status, SmallBusinessStatus.exceeded);
      expect(result.headroom.isNegative, isTrue);
    });

    test('der Vorjahresumsatz spielt in Österreich keine Rolle', () {
      // Österreich kennt keine Vorjahresgrenze – ein hohes Vorjahr allein
      // beendet die Befreiung nicht.
      expect(
        assessAt(10000, previousEuro: 90000).status,
        SmallBusinessStatus.ok,
      );
    });
  });

  group('Deutschland – 25.000 € Vorjahr, 100.000 € laufendes Jahr', () {
    test('unter beiden Grenzen ist unauffällig', () {
      expect(
        assessDe(30000, previousEuro: 20000).status,
        SmallBusinessStatus.ok,
      );
    });

    test(
      'zu hoher Vorjahresumsatz beendet die Regelung für das ganze Jahr',
      () {
        final result = assessDe(1000, previousEuro: 25001);
        expect(result.status, SmallBusinessStatus.exceeded);
        expect(result.message, contains('Vorjahresumsatz'));
      },
    );

    test('genau 25.000 im Vorjahr ist noch zulässig', () {
      expect(
        assessDe(1000, previousEuro: 25000).status,
        SmallBusinessStatus.ok,
      );
    });

    test('ab 80 Prozent der laufenden Grenze wird gewarnt', () {
      expect(assessDe(80000).status, SmallBusinessStatus.approaching);
    });

    test('über 100.000 fällt die Befreiung ohne Toleranz weg', () {
      final result = assessDe(100001);
      expect(result.status, SmallBusinessStatus.exceeded);
      // Deutschland hat keine Toleranzregel – der Status darf nie
      // withinTolerance sein.
      expect(result.status, isNot(SmallBusinessStatus.withinTolerance));
    });
  });

  group('Regelbesteuerung', () {
    test('wird nicht bewertet', () {
      final result = SmallBusinessMonitor.assess(
        taxProfile: TaxProfile.austria,
        isSmallBusiness: false,
        currentYearTurnover: Money.fromEuro(500000),
      );
      expect(result.status, SmallBusinessStatus.notApplicable);
      expect(result.needsAttention, isFalse);
    });
  });

  group('Anzeigewerte', () {
    test('rechnet die Ausnutzung in Prozent', () {
      expect(assessAt(27500).utilizationPercent, closeTo(50, 0.01));
      expect(assessAt(55000).utilizationPercent, closeTo(100, 0.01));
    });

    test('deckelt die Anzeige bei extremen Werten', () {
      expect(assessAt(100000000).utilizationPercent, 999);
    });
  });
}
