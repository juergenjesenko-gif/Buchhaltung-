import '../domain/country.dart';
import '../domain/money.dart';

/// Ampelstatus der Kleinunternehmerregelung.
enum SmallBusinessStatus {
  /// Regelung wird nicht in Anspruch genommen.
  notApplicable,

  /// Deutlich unter der Grenze.
  ok,

  /// Über 80 % der Grenze – ab hier sollte man planen.
  approaching,

  /// Grenze überschritten, aber noch in der Toleranz (nur Österreich).
  /// Die Befreiung gilt bis Jahresende weiter, fällt aber im Folgejahr weg.
  withinTolerance,

  /// Grenze endgültig überschritten – ab sofort ist Umsatzsteuer auszuweisen.
  exceeded,
}

class SmallBusinessAssessment {
  const SmallBusinessAssessment({
    required this.status,
    required this.currentYearTurnover,
    required this.limit,
    required this.headroom,
    required this.message,
  });

  final SmallBusinessStatus status;
  final Money currentYearTurnover;
  final Money limit;

  /// Verbleibender Umsatz bis zur Grenze. Negativ, wenn bereits überschritten.
  final Money headroom;

  final String message;

  /// Ausnutzung der Grenze in Prozent, gedeckelt bei 999 für die Anzeige.
  double get utilizationPercent {
    if (limit.cents <= 0) return 0;
    final value = currentYearTurnover.cents / limit.cents * 100;
    return value > 999 ? 999 : value;
  }

  bool get needsAttention =>
      status == SmallBusinessStatus.approaching ||
      status == SmallBusinessStatus.withinTolerance ||
      status == SmallBusinessStatus.exceeded;
}

/// Überwacht die Umsatzgrenzen der Kleinunternehmerregelung.
///
/// Die Regeln unterscheiden sich zwischen den Ländern deutlich:
///
/// **Österreich** (§ 6 Abs 1 Z 27 UStG, Fassung ab 2025): eine Grenze von
/// 55.000 EUR für das laufende Jahr. Wird sie um nicht mehr als 10 %
/// überschritten, bleibt die Befreiung bis Jahresende bestehen; darüber fällt
/// sie sofort weg.
///
/// **Deutschland** (§ 19 UStG, Fassung ab 2025): zwei Grenzen. Der Vorjahres-
/// umsatz darf 25.000 EUR nicht überschritten haben, der laufende Umsatz nicht
/// 100.000 EUR. Eine Toleranz gibt es nicht – ab dem Umsatz, der die Grenze
/// reißt, ist Umsatzsteuer auszuweisen.
class SmallBusinessMonitor {
  const SmallBusinessMonitor._();

  /// Ab diesem Ausnutzungsgrad wird gewarnt.
  static const _warnThreshold = 0.8;

  static SmallBusinessAssessment assess({
    required TaxProfile taxProfile,
    required bool isSmallBusiness,
    required Money currentYearTurnover,
    Money previousYearTurnover = const Money.zero(),
  }) {
    final limit = taxProfile.currentYearTurnoverLimit;

    if (!isSmallBusiness) {
      return SmallBusinessAssessment(
        status: SmallBusinessStatus.notApplicable,
        currentYearTurnover: currentYearTurnover,
        limit: limit,
        headroom: const Money.zero(),
        message:
            'Regelbesteuerung – die Kleinunternehmergrenze ist nicht relevant.',
      );
    }

    final headroom = limit - currentYearTurnover;

    // Deutschland: die Vorjahresgrenze entscheidet vorab über das ganze Jahr.
    final previousLimit = taxProfile.previousYearTurnoverLimit;
    if (previousLimit != null && previousYearTurnover > previousLimit) {
      return SmallBusinessAssessment(
        status: SmallBusinessStatus.exceeded,
        currentYearTurnover: currentYearTurnover,
        limit: limit,
        headroom: headroom,
        message:
            'Der Vorjahresumsatz lag über ${_euro(previousLimit)}. '
            'Die Kleinunternehmerregelung gilt in diesem Jahr nicht '
            '(${taxProfile.smallBusinessLegalRef}).',
      );
    }

    final tolerance = taxProfile.toleranceLimit;

    if (tolerance != null && currentYearTurnover > tolerance) {
      return SmallBusinessAssessment(
        status: SmallBusinessStatus.exceeded,
        currentYearTurnover: currentYearTurnover,
        limit: limit,
        headroom: headroom,
        message:
            'Die Toleranzgrenze von ${_euro(tolerance)} ist überschritten. '
            'Die Steuerbefreiung fällt sofort weg – ab jetzt ist Umsatzsteuer auszuweisen.',
      );
    }

    if (currentYearTurnover > limit) {
      if (tolerance != null) {
        return SmallBusinessAssessment(
          status: SmallBusinessStatus.withinTolerance,
          currentYearTurnover: currentYearTurnover,
          limit: limit,
          headroom: headroom,
          message:
              'Die Grenze von ${_euro(limit)} ist überschritten, die 10-%-Toleranz '
              'bis ${_euro(tolerance)} greift aber noch. Die Befreiung gilt bis Jahresende, '
              'ab dem Folgejahr nicht mehr.',
        );
      }
      return SmallBusinessAssessment(
        status: SmallBusinessStatus.exceeded,
        currentYearTurnover: currentYearTurnover,
        limit: limit,
        headroom: headroom,
        message:
            'Die Grenze von ${_euro(limit)} ist überschritten. '
            'Ab dem Umsatz, der die Grenze reißt, ist Umsatzsteuer auszuweisen '
            '(${taxProfile.smallBusinessLegalRef}).',
      );
    }

    if (limit.cents > 0 &&
        currentYearTurnover.cents >= limit.cents * _warnThreshold) {
      return SmallBusinessAssessment(
        status: SmallBusinessStatus.approaching,
        currentYearTurnover: currentYearTurnover,
        limit: limit,
        headroom: headroom,
        message:
            'Noch ${_euro(headroom)} bis zur Grenze von ${_euro(limit)}. '
            'Jetzt ist ein guter Zeitpunkt, den Wechsel zur Regelbesteuerung zu planen.',
      );
    }

    return SmallBusinessAssessment(
      status: SmallBusinessStatus.ok,
      currentYearTurnover: currentYearTurnover,
      limit: limit,
      headroom: headroom,
      message: 'Noch ${_euro(headroom)} bis zur Grenze von ${_euro(limit)}.',
    );
  }

  static String _euro(Money money) {
    final euro = money.cents ~/ 100;
    final cents = (money.cents % 100).abs();
    final digits = euro.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    final sign = money.isNegative ? '-' : '';
    return '$sign$buffer,${cents.toString().padLeft(2, '0')} €';
  }
}
