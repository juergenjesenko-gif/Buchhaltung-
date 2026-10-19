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

  /// Grenze endgültig überschritten – ab sofort ist Umsatzsteuer auszuweisen.
  exceeded,

  /// Für eine Aussage fehlen Umsatzangaben: der Vorjahresumsatz oder der Umsatz
  /// dieses Jahres vor Beginn der Erfassung. Bewusst kein „ok" – eine
  /// Entwarnung auf unvollständiger Grundlage war genau der Fehler O-19.
  incomplete,
}

class SmallBusinessAssessment {
  const SmallBusinessAssessment({
    required this.status,
    required this.currentYearTurnover,
    required this.limit,
    required this.headroom,
    required this.message,
    this.nextYearLimit,
    this.limitsNote = '',
  });

  final SmallBusinessStatus status;
  final Money currentYearTurnover;
  final Money limit;

  /// Verbleibender Umsatz bis zur Grenze. Negativ, wenn bereits überschritten.
  final Money headroom;

  final String message;

  /// Grenze, deren Überschreiten im laufenden Jahr erst das **nächste** Jahr
  /// kostet (DE: 25.000 € nach § 19 Abs 1 UStG). `null`, wenn sie mit
  /// [limit] zusammenfällt (AT: 55.000 € für beide Jahre).
  final Money? nextYearLimit;

  /// Kurzer Hinweis auf die Grenzen des Landes, z. B. „§ 19 UStG:
  /// 25.000 € Vorjahr · 100.000 € laufendes Jahr“.
  final String limitsNote;

  /// Grenze, an der der Balken gemessen wird: solange die Vorjahresgrenze
  /// für das nächste Jahr noch nicht gerissen ist, diese (DE), sonst [limit].
  Money get displayLimit {
    final next = nextYearLimit;
    if (next != null && currentYearTurnover <= next) return next;
    return limit;
  }

  /// Ausnutzung der Grenze in Prozent, gedeckelt bei 999 für die Anzeige.
  double get utilizationPercent {
    final shown = displayLimit;
    if (shown.cents <= 0) return 0;
    final value = currentYearTurnover.cents / shown.cents * 100;
    return value > 999 ? 999 : value;
  }

  bool get needsAttention =>
      status == SmallBusinessStatus.approaching ||
      status == SmallBusinessStatus.exceeded ||
      status == SmallBusinessStatus.incomplete;
}

/// Überwacht die Umsatzgrenzen der Kleinunternehmerregelung.
///
/// Die Regeln unterscheiden sich zwischen den Ländern deutlich:
///
/// **Österreich** (§ 6 Abs 1 Z 27 UStG, Fassung ab 2025): der Vorjahresumsatz
/// darf 55.000 EUR nicht überschritten haben. Im laufenden Jahr gilt dieselbe
/// Grenze; wird sie um nicht mehr als 10 % überschritten, bleibt die Befreiung
/// bis Jahresende bestehen, darüber fällt sie sofort weg.
///
/// **Deutschland** (§ 19 UStG, Fassung ab 2025): zwei Grenzen. Der Vorjahres-
/// umsatz darf 25.000 EUR nicht überschritten haben, der laufende Umsatz nicht
/// 100.000 EUR. Eine Toleranz gibt es nicht – ab dem Umsatz, der die Grenze
/// reißt, ist Umsatzsteuer auszuweisen.
class SmallBusinessMonitor {
  const SmallBusinessMonitor._();

  /// Ab diesem Ausnutzungsgrad wird gewarnt. Keine gesetzliche Vorgabe, sondern
  /// eine Produktentscheidung – öffentlich, damit docs/SPECIFICATION.md und
  /// test/specification_sync_test.dart denselben Wert prüfen können.
  static const warnThreshold = 0.8;

  /// [previousYearTurnover] ist `null`, wenn der Vorjahresumsatz unbekannt ist.
  /// Es gibt bewusst keinen Standardwert: ein stillschweigend angenommener
  /// Vorjahresumsatz von null war die Ursache von O-19.
  ///
  /// [currentYearComplete] ist `false`, wenn für den Teil des laufenden Jahres
  /// vor Beginn der Erfassung kein Umsatz bekannt ist.
  static SmallBusinessAssessment assess({
    required TaxProfile taxProfile,
    required bool isSmallBusiness,
    required Money currentYearTurnover,
    required Money? previousYearTurnover,
    required bool currentYearComplete,
    bool isFoundingYear = false,
  }) {
    final base = _assess(
      taxProfile: taxProfile,
      isSmallBusiness: isSmallBusiness,
      currentYearTurnover: currentYearTurnover,
      previousYearTurnover: previousYearTurnover,
      currentYearComplete: currentYearComplete,
      isFoundingYear: isFoundingYear,
    );
    final previousLimit = taxProfile.previousYearTurnoverLimit;
    // Zweite Grenze nur, wenn sie von der laufenden abweicht (DE ab 2025:
    // 25.000 € Vorjahr, 100.000 € laufend, § 19 Abs 1 UStG). Im
    // Gründungsjahr ist die laufende Grenze schon 25.000 €.
    final next = previousLimit != null && previousLimit != base.limit
        ? previousLimit
        : null;
    final note = previousLimit == null
        ? '${taxProfile.smallBusinessLegalRef}: ${_euro(base.limit)}'
        : previousLimit == taxProfile.currentYearTurnoverLimit
        ? '${taxProfile.smallBusinessLegalRef}: ${_euro(base.limit)} im '
              'Vorjahr und im laufenden Jahr'
              '${taxProfile.toleranceLimit == null ? '' : ', Toleranz bis ${_euro(taxProfile.toleranceLimit!)}'}'
        : isFoundingYear
        ? '${taxProfile.smallBusinessLegalRef}: ${_euro(base.limit)} im '
              'Gründungsjahr'
        : '${taxProfile.smallBusinessLegalRef}: ${_euro(previousLimit)} '
              'Vorjahr · ${_euro(taxProfile.currentYearTurnoverLimit)} '
              'laufendes Jahr';
    if (base.status == SmallBusinessStatus.notApplicable) return base;
    var status = base.status;
    var message = base.message;
    if (next != null &&
        (status == SmallBusinessStatus.ok ||
            status == SmallBusinessStatus.approaching)) {
      if (currentYearTurnover > next) {
        status = SmallBusinessStatus.approaching;
        message =
            'Der Umsatz liegt über ${_euro(next)}. In diesem Jahr bleibt die '
            'Kleinunternehmerregelung bis ${_euro(base.limit)}, ab dem '
            'nächsten Jahr gilt die Regelbesteuerung '
            '(${taxProfile.smallBusinessLegalRef}). Jetzt planen.';
      } else if (currentYearTurnover.cents >= next.cents * warnThreshold) {
        status = SmallBusinessStatus.approaching;
        message =
            'Noch ${_euro(next - currentYearTurnover)} bis ${_euro(next)}. '
            'Darüber gilt ab dem nächsten Jahr die Regelbesteuerung '
            '(${taxProfile.smallBusinessLegalRef}).';
      } else {
        status = SmallBusinessStatus.ok;
        message =
            'Noch ${_euro(next - currentYearTurnover)} bis ${_euro(next)} – '
            'darüber gilt ab dem nächsten Jahr die Regelbesteuerung. In '
            'diesem Jahr endet die Regelung erst über ${_euro(base.limit)}.';
      }
    }
    return SmallBusinessAssessment(
      status: status,
      currentYearTurnover: base.currentYearTurnover,
      limit: base.limit,
      headroom: base.headroom,
      message: message,
      nextYearLimit: next,
      limitsNote: note,
    );
  }

  static SmallBusinessAssessment _assess({
    required TaxProfile taxProfile,
    required bool isSmallBusiness,
    required Money currentYearTurnover,
    required Money? previousYearTurnover,
    required bool currentYearComplete,
    required bool isFoundingYear,
  }) {
    // Im Gründungsjahr gibt es kein Vorjahr; manche Länder setzen eine
    // niedrigere Grenze (DE, § 19 Abs 1 UStG).
    final limit = isFoundingYear
        ? taxProfile.foundingYearTurnoverLimit ??
              taxProfile.currentYearTurnoverLimit
        : taxProfile.currentYearTurnoverLimit;

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

    // Die Vorjahresgrenze entscheidet vorab über das ganze Jahr.
    final previousLimit = isFoundingYear
        ? null
        : taxProfile.previousYearTurnoverLimit;
    if (previousLimit != null &&
        previousYearTurnover != null &&
        previousYearTurnover > previousLimit) {
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
      // Zur Sicherheit gilt die harte Grenze (Entscheidung des Auftraggebers
      // vom 2026-10-10): ob die Toleranz greift, hängt von Umständen ab, die
      // die App nicht kennt. Sie warnt nur und verweist an die Steuerberatung.
      if (tolerance != null) {
        return SmallBusinessAssessment(
          status: SmallBusinessStatus.exceeded,
          currentYearTurnover: currentYearTurnover,
          limit: limit,
          headroom: headroom,
          message:
              'Die Grenze von ${_euro(limit)} ist überschritten. Zur Sicherheit '
              'rechnet die App mit der harten Grenze: Weise ab jetzt '
              'Umsatzsteuer aus. Möglicherweise greift eine Toleranz bis '
              '${_euro(tolerance)} – ob sie für dich gilt, kann nur deine '
              'Steuerberatung beurteilen. Bitte vor der nächsten Rechnung '
              'nachfragen (${taxProfile.smallBusinessLegalRef}).',
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

    // Ab hier würde die Ampel beruhigen. Das darf sie nur auf vollständiger
    // Grundlage. Eine Überschreitung oben gilt dagegen auch bei unvollständigen
    // Zahlen – mehr Umsatz als erfasst kann es nicht weniger machen.
    if (previousLimit != null && previousYearTurnover == null) {
      return SmallBusinessAssessment(
        status: SmallBusinessStatus.incomplete,
        currentYearTurnover: currentYearTurnover,
        limit: limit,
        headroom: headroom,
        message:
            'Der Umsatz des Vorjahres fehlt. Er entscheidet darüber, ob die '
            'Kleinunternehmerregelung in diesem Jahr überhaupt gilt '
            '(${taxProfile.smallBusinessLegalRef}). Bitte in den Stammdaten ergänzen.',
      );
    }

    if (!currentYearComplete) {
      return SmallBusinessAssessment(
        status: SmallBusinessStatus.incomplete,
        currentYearTurnover: currentYearTurnover,
        limit: limit,
        headroom: headroom,
        message:
            'Der Umsatz dieses Jahres vor Beginn der Erfassung fehlt. Ohne ihn '
            'ist der Abstand zur Grenze nicht bekannt. Bitte in den Stammdaten ergänzen.',
      );
    }

    if (limit.cents > 0 &&
        currentYearTurnover.cents >= limit.cents * warnThreshold) {
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
