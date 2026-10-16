import '../domain/company_profile.dart';
import '../domain/country.dart';
import '../domain/deadline_rule.dart';
import '../domain/money.dart';

/// Hinweis unter der Termin-Box (L-25.7). Formulierung real zu prüfen:
/// Spezifikation 14, P-R24.
const deadlineDisclaimer =
    'Berechnete Termine zur Orientierung, ohne Gewähr. Maßgeblich sind '
    'Bescheid, Finanzamt bzw. deine Steuerberatung.';

/// Ein berechneter Termin (Lastenheft L-25).
class Deadline {
  const Deadline({
    required this.date,
    required this.label,
    required this.legalRef,
    this.approximate = false,
  });

  final DateTime date;
  final String label;
  final String legalRef;

  /// Nur ungefähr („ca.“), siehe [DeadlineRule.approximate].
  final bool approximate;

  /// Tage von [today] bis zum Termin.
  int daysFrom(DateTime today) => DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
}

/// Ergebnis für die Termin-Box der Übersicht.
class DeadlineOverview {
  const DeadlineOverview({required this.upcoming, this.advisorNote});

  final List<Deadline> upcoming;

  /// „Steuererklärungen 2026: Frist laut Kanzlei“, wenn eine Steuerberatung
  /// hinterlegt ist; sonst `null`.
  final String? advisorNote;
}

/// Berechnet Steuer- und Abgabetermine aus den Regeln im `TaxProfile`.
///
/// Reines Dart ohne Flutter; keine Länder-ifs – alles Länderspezifische steht
/// in `TaxProfile.deadlineRules` und `TaxProfile.holidayCalendar`.
/// Stufe 1: nur Anzeige, keine Benachrichtigungen.
class DeadlineCalculator {
  const DeadlineCalculator._();

  /// So viele Termine zeigt die Übersicht (`spec.deadline_box_count`).
  static const boxCount = 4;

  /// Voranmeldungszeitraum: die Einstellung im Profil, bei `auto` der
  /// Vorschlag aus dem Vorjahr. [previousYearTurnover] und
  /// [previousYearVat] sind die Vorjahreswerte, `null` wenn unbekannt
  /// (dann vierteljährlich).
  static VatReturnInterval effectiveInterval({
    required CompanyProfile profile,
    Money? previousYearTurnover,
    Money? previousYearVat,
  }) {
    if (profile.vatReturnInterval != VatReturnInterval.auto) {
      return profile.vatReturnInterval;
    }
    return suggestInterval(
      profile.taxProfile,
      previousYearTurnover: previousYearTurnover,
      previousYearVat: previousYearVat,
    );
  }

  /// Vorschlag aus dem Vorjahr (AT § 21 Abs 2 UStG, DE § 18 Abs 2 UStG).
  static VatReturnInterval suggestInterval(
    TaxProfile tax, {
    Money? previousYearTurnover,
    Money? previousYearVat,
  }) {
    final value = switch (tax.vatIntervalBasis) {
      VatIntervalBasis.previousYearTurnover => previousYearTurnover,
      VatIntervalBasis.previousYearVat => previousYearVat,
    };
    if (value == null) return VatReturnInterval.quarterly;
    return value.cents > tax.monthlyVatReturnThreshold.cents
        ? VatReturnInterval.monthly
        : VatReturnInterval.quarterly;
  }

  /// Alle Termine ab [today] (einschließlich), aufsteigend, höchstens
  /// [count].
  static DeadlineOverview upcoming({
    required CompanyProfile profile,
    required DateTime today,
    required VatReturnInterval interval,
    int count = boxCount,
    List<Deadline> extra = const [],
  }) {
    final tax = profile.taxProfile;
    final day = DateTime(today.year, today.month, today.day);
    final all = <Deadline>[];
    for (var year = day.year - 1; year <= day.year + 1; year++) {
      all.addAll(forYear(profile: profile, year: year, interval: interval));
    }
    // Vertragstermine (FA-16.4) laufen in derselben Box.
    all.addAll(extra);
    final upcoming = all.where((d) => !d.date.isBefore(day)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final annual = tax.deadlineRules.any(
      (r) => r.condition == DeadlineCondition.annualReturn,
    );
    final yearForNote = day.month <= 6 ? day.year - 1 : day.year;
    return DeadlineOverview(
      upcoming: upcoming.take(count).toList(),
      advisorNote: profile.hasTaxAdvisor && annual
          ? 'Steuererklärungen $yearForNote: Frist laut Kanzlei'
          : null,
    );
  }

  /// Alle Termine, die zu Zeiträumen des Kalenderjahres [year] gehören
  /// (Voranmeldung, Vorauszahlung) bzw. die Erklärung für [year].
  static List<Deadline> forYear({
    required CompanyProfile profile,
    required int year,
    required VatReturnInterval interval,
  }) {
    final tax = profile.taxProfile;
    final monthly = interval == VatReturnInterval.monthly;
    final result = <Deadline>[];

    DateTime shift(DateTime date, DeadlineRule rule) => rule.approximate
        ? date
        : tax.holidayCalendar.nextWorkday(date, state: profile.federalState);

    for (final rule in tax.deadlineRules) {
      if (!_applies(rule.condition, profile)) continue;
      switch (rule.schedule) {
        case AfterPeriod(
          :final dueDay,
          :final monthsAfter,
          :final extensionMonths,
        ):
          final step = monthly ? 1 : 3;
          final extra =
              rule.condition == DeadlineCondition.notSmallBusiness &&
                  profile.vatPermanentExtension &&
                  tax.hasPermanentExtension
              ? extensionMonths
              : 0;
          for (var start = 1; start <= 12; start += step) {
            final endMonth = start + step - 1;
            final dueMonth = endMonth + monthsAfter + extra;
            final raw = dueDay == 0
                ? DateTime(year, dueMonth + 1, 0)
                : DateTime(year, dueMonth, dueDay);
            final period = monthly
                ? '${tax.monthNames[start - 1]} $year'
                : 'Q${(start + 2) ~/ 3}/$year';
            result.add(
              Deadline(
                date: shift(raw, rule),
                label: '${rule.label} $period',
                legalRef: rule.legalRef,
                approximate: rule.approximate,
              ),
            );
          }
        case FixedDates(:final monthDays):
          var quarter = 1;
          for (final (month, d) in monthDays) {
            final raw = d == 0
                ? DateTime(year, month + 1, 0)
                : DateTime(year, month, d);
            result.add(
              Deadline(
                date: shift(raw, rule),
                label: '${rule.label} Q${quarter++}/$year',
                legalRef: rule.legalRef,
                approximate: rule.approximate,
              ),
            );
          }
        case FollowingYear(:final month, :final day):
          result.add(
            Deadline(
              date: shift(DateTime(year + 1, month, day), rule),
              label: '${rule.label} $year',
              legalRef: rule.legalRef,
              approximate: rule.approximate,
            ),
          );
      }
    }
    return result;
  }

  static bool _applies(DeadlineCondition condition, CompanyProfile p) =>
      switch (condition) {
        DeadlineCondition.always => true,
        DeadlineCondition.notSmallBusiness => !p.isSmallBusiness,
        DeadlineCondition.filesEcsl => p.filesEcsl,
        DeadlineCondition.socialInsurance =>
          p.taxProfile.asksSocialInsurance && p.svsInsured,
        DeadlineCondition.annualReturn => !p.hasTaxAdvisor,
      };
}
