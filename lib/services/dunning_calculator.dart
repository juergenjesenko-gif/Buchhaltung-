import '../domain/dunning.dart';
import '../domain/money.dart';

/// Ein Zinsabschnitt mit gleichbleibendem Satz.
class InterestPeriod {
  const InterestPeriod({
    required this.from,
    required this.to,
    required this.days,
    required this.rateBp,
  });

  /// Erster und letzter Zinstag (beide einschließlich).
  final DateTime from;
  final DateTime to;
  final int days;
  final int rateBp;
}

/// Ergebnis einer Zinsberechnung.
class InterestResult {
  const InterestResult(this.periods, this.amount);

  final List<InterestPeriod> periods;
  final Money amount;

  static const none = InterestResult([], Money.zero());
}

/// Anrechnung einer Zahlung (§ 1416 ABGB, § 367 BGB): zuerst Kosten, dann
/// Zinsen, dann Hauptforderung.
typedef PaymentAllocation = ({Money costs, Money interest, Money principal});

/// Rechenkern des Mahnwesens (L-3.27 bis L-3.30). Ganzzahlig, ohne `double`.
class DunningCalculator {
  const DunningCalculator._();

  /// Vorschlag für die neue Zahlungsfrist in Tagen (L-3.29).
  static const defaultPeriodDays = 14;

  /// Vorschlag für Mahnkosten je Mahnung (Entscheidung der Auftraggeberin
  /// 2026-10-14); die Zahlungserinnerung ist kostenlos. Bei Verbrauchern nur
  /// angemessene, tatsächliche Kosten (§ 1333 Abs 2 ABGB, § 280 BGB; P-R32).
  static const defaultFee = Money(1000);

  /// Mahnkosten-Vorschlag für die Stufe [level].
  static Money suggestedFee(int level, Money profileFee) =>
      level <= 1 ? const Money.zero() : profileFee;

  /// Verzugszinsen auf [principal] für die Tage nach [dueDate] bis
  /// einschließlich [until], act/365, abschnittsweise je Halbjahr, wenn sich
  /// der Satz mit dem Basiszinssatz ändert. [overrideRateBp] ersetzt den
  /// gesetzlichen Satz für alle Abschnitte. Je Abschnitt kaufmännisch auf
  /// Cent gerundet (half-up).
  static InterestResult interest({
    required Money principal,
    required DateTime dueDate,
    required DateTime until,
    required DunningRules rules,
    required bool business,
    int? overrideRateBp,
  }) {
    final start = _day(dueDate).add(const Duration(days: 1));
    final end = _day(until);
    if (end.isBefore(start) || principal.cents <= 0) return InterestResult.none;
    final periods = <InterestPeriod>[];
    var cursor = start;
    final splits =
        overrideRateBp == null && rules.variesByHalfYear(business: business);
    while (!cursor.isAfter(end)) {
      var periodEnd = end;
      if (splits) {
        // Letzter Tag des Halbjahrs: 30.6. bzw. 31.12.
        final halfYearEnd = DateTime(
          cursor.year,
          cursor.month <= 6 ? 7 : 13,
          0,
        );
        if (halfYearEnd.isBefore(periodEnd)) periodEnd = halfYearEnd;
      }
      final days = _daysBetween(cursor, periodEnd) + 1;
      periods.add(
        InterestPeriod(
          from: cursor,
          to: periodEnd,
          days: days,
          rateBp:
              overrideRateBp ??
              rules.statutoryRateBp(business: business, date: cursor),
        ),
      );
      cursor = DateTime(periodEnd.year, periodEnd.month, periodEnd.day + 1);
    }
    var cents = 0;
    for (final p in periods) {
      // Betrag × Satz (Basispunkte) × Tage / (10.000 × 365)
      cents += divideRounded(principal.cents * p.rateBp * p.days, 3650000);
    }
    return InterestResult(periods, Money(cents));
  }

  /// Rechnet eine Zahlung an (§ 1416 ABGB, § 367 BGB). Was über die
  /// Gesamtforderung hinausgeht, bleibt unberücksichtigt.
  static PaymentAllocation allocatePayment({
    required Money received,
    required Money costs,
    required Money interest,
    required Money principal,
  }) {
    var rest = received.cents;
    int take(int amount) {
      final part = rest < amount ? rest : amount;
      rest -= part;
      return part < 0 ? 0 : part;
    }

    final c = take(costs.cents);
    final i = take(interest.cents);
    final p = take(principal.cents);
    return (costs: Money(c), interest: Money(i), principal: Money(p));
  }

  /// Zinssatz in Basispunkten als Text: 1073 → „10,73 %“.
  static String rateText(int bp) {
    final whole = bp ~/ 100;
    final frac = (bp % 100).toString().padLeft(2, '0');
    return frac == '00' ? '$whole %' : '$whole,$frac %';
  }

  /// Eingabe „10,73“ in Basispunkte; ungültig: `null`.
  static int? parseRate(String input) {
    final parsed = Money.tryParse(input.replaceAll('%', ''));
    if (parsed == null || parsed.isNegative) return null;
    return parsed.cents;
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static int _daysBetween(DateTime a, DateTime b) => DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}
