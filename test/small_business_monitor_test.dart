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
        currentYearComplete: true,
      );

  SmallBusinessAssessment assessDe(int euro, {int previousEuro = 0}) =>
      SmallBusinessMonitor.assess(
        taxProfile: TaxProfile.germany,
        isSmallBusiness: true,
        currentYearTurnover: Money.fromEuro(euro),
        previousYearTurnover: Money.fromEuro(previousEuro),
        currentYearComplete: true,
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

    test(
      'knapp darüber gilt die harte Grenze, die Toleranz nur als Warnung',
      () {
        // Entscheidung des Auftraggebers vom 2026-10-10: zur Sicherheit harte
        // Grenze, Toleranz nur als Hinweis an die Steuerberatung.
        final result = assessAt(56000);
        expect(result.status, SmallBusinessStatus.exceeded);
        expect(result.message, contains('Toleranz'));
        expect(result.message, contains('Steuerberatung'));
      },
    );

    test('auch an der Toleranzgrenze gilt die harte Grenze', () {
      expect(assessAt(60500).status, SmallBusinessStatus.exceeded);
    });

    test('über der Toleranz fällt die Befreiung sofort weg', () {
      final result = assessAt(60501);
      expect(result.status, SmallBusinessStatus.exceeded);
      expect(result.headroom.isNegative, isTrue);
    });

    test(
      'zu hoher Vorjahresumsatz beendet die Regelung für das ganze Jahr',
      () {
        // O-1: auch in Österreich zählt das Vorjahr, ohne Toleranz.
        final result = assessAt(10000, previousEuro: 55001);
        expect(result.status, SmallBusinessStatus.exceeded);
        expect(result.message, contains('Vorjahresumsatz'));
      },
    );

    test('genau 55.000 im Vorjahr ist noch zulässig', () {
      expect(
        assessAt(10000, previousEuro: 55000).status,
        SmallBusinessStatus.ok,
      );
    });

    test('Toleranz gilt nicht für das Vorjahr', () {
      expect(
        assessAt(10000, previousEuro: 60000).status,
        SmallBusinessStatus.exceeded,
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
      // Deutschland hat keine Toleranzregel – kein Hinweis darauf.
      expect(result.message, isNot(contains('Toleranz')));
    });
  });

  group('Regelbesteuerung', () {
    test('wird nicht bewertet', () {
      final result = SmallBusinessMonitor.assess(
        taxProfile: TaxProfile.austria,
        isSmallBusiness: false,
        currentYearTurnover: Money.fromEuro(500000),
        previousYearTurnover: null,
        currentYearComplete: false,
      );
      expect(result.status, SmallBusinessStatus.notApplicable);
      expect(result.needsAttention, isFalse);
    });
  });

  group('Unvollständige Umsatzangaben (O-19)', () {
    SmallBusinessAssessment assess(
      TaxProfile profile, {
      required int currentEuro,
      int? previousEuro,
      bool currentComplete = true,
    }) => SmallBusinessMonitor.assess(
      taxProfile: profile,
      isSmallBusiness: true,
      currentYearTurnover: Money.fromEuro(currentEuro),
      previousYearTurnover: previousEuro == null
          ? null
          : Money.fromEuro(previousEuro),
      currentYearComplete: currentComplete,
    );

    test('Deutschland: fehlender Vorjahresumsatz ist kein "ok"', () {
      // Genau der Fehler O-19: ein neuer Nutzer mit 30.000 € Vorjahresumsatz
      // hatte keine Belege aus dem Vorjahr und bekam eine grüne Ampel.
      final result = assess(TaxProfile.germany, currentEuro: 5000);
      expect(result.status, SmallBusinessStatus.incomplete);
      expect(result.needsAttention, isTrue);
      expect(result.message, contains('Vorjahres'));
    });

    test('Deutschland: mit erfasstem Vorjahresumsatz greift die Grenze', () {
      final result = assess(
        TaxProfile.germany,
        currentEuro: 5000,
        previousEuro: 30000,
      );
      expect(result.status, SmallBusinessStatus.exceeded);
    });

    test('ein erfasster Vorjahresumsatz von 0 € ist vollständig', () {
      // Leer und 0 sind verschieden: wer im Vorjahr gegründet hat, trägt 0 ein.
      final result = assess(
        TaxProfile.germany,
        currentEuro: 5000,
        previousEuro: 0,
      );
      expect(result.status, SmallBusinessStatus.ok);
    });

    test('Überschreitung gilt auch bei unvollständigen Zahlen', () {
      // Mehr Umsatz als erfasst kann es nicht weniger machen.
      final result = assess(
        TaxProfile.germany,
        currentEuro: 100001,
        currentComplete: false,
      );
      expect(result.status, SmallBusinessStatus.exceeded);
    });

    test('unvollständiges laufendes Jahr ist kein "ok"', () {
      final result = assess(
        TaxProfile.austria,
        currentEuro: 10000,
        previousEuro: 0,
        currentComplete: false,
      );
      expect(result.status, SmallBusinessStatus.incomplete);
      expect(result.message, contains('vor Beginn der Erfassung'));
    });

    test('Österreich: fehlender Vorjahresumsatz ist kein "ok"', () {
      final result = assess(TaxProfile.austria, currentEuro: 10000);
      expect(result.status, SmallBusinessStatus.incomplete);
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
