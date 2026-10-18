import '../domain/company_profile.dart';
import '../domain/country.dart';
import '../domain/deadline_rule.dart';
import '../domain/money.dart';
import '../domain/tax_registration.dart';

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
  /// [count]. [registrations] sind die weiteren Steuerländer (FA-18.5).
  static DeadlineOverview upcoming({
    required CompanyProfile profile,
    required DateTime today,
    required VatReturnInterval interval,
    int count = boxCount,
    List<Deadline> extra = const [],
    List<TaxRegistration> registrations = const [],
  }) {
    final tax = profile.taxProfile;
    final day = DateTime(today.year, today.month, today.day);
    final all = <Deadline>[];
    for (var year = day.year - 1; year <= day.year + 1; year++) {
      all.addAll(
        forYear(
          profile: profile,
          year: year,
          interval: interval,
          registrations: registrations,
        ),
      );
      for (final r in registrations) {
        all.addAll(forRegistration(registration: r, year: year));
      }
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
    List<TaxRegistration> registrations = const [],
  }) {
    final tax = profile.taxProfile;
    final monthly = interval == VatReturnInterval.monthly;
    final result = <Deadline>[];
    final euSmallBusiness = registrations.any(
      (r) =>
          r.scheme == VatScheme.euSmallBusiness &&
          r.overlaps(DateTime(year), DateTime(year, 12, 31)),
    );

    for (final rule in tax.deadlineRules) {
      final applies = switch (rule.condition) {
        DeadlineCondition.always => true,
        DeadlineCondition.notSmallBusiness => !profile.isSmallBusiness,
        DeadlineCondition.filesEcsl => profile.filesEcsl,
        DeadlineCondition.socialInsurance =>
          tax.asksSocialInsurance && profile.svsInsured,
        DeadlineCondition.annualReturn => !profile.hasTaxAdvisor,
        DeadlineCondition.oss => profile.ossParticipant,
        DeadlineCondition.euSmallBusinessReport => euSmallBusiness,
        DeadlineCondition.registrationReturn ||
        DeadlineCondition.registrationAnnual => false,
      };
      if (!applies) continue;
      result.addAll(
        _expand(
          rule: rule,
          tax: tax,
          year: year,
          monthly: monthly,
          extension:
              rule.condition == DeadlineCondition.notSmallBusiness &&
              profile.vatPermanentExtension &&
              tax.hasPermanentExtension,
          state: profile.federalState,
        ),
      );
    }
    return result;
  }

  /// Umsatzsteuertermine einer weiteren Registrierung im Jahr [year]
  /// (FA-18.5): Regeln aus `TaxProfile.registrationDeadlineRules` des
  /// Registrierungslandes, Feiertage dieses Landes (bundesweit), Länderkürzel
  /// vor der Bezeichnung. Nur Zeiträume innerhalb von Beginn/Ende.
  static List<Deadline> forRegistration({
    required TaxRegistration registration,
    required int year,
  }) {
    final r = registration;
    final tax = r.taxProfile;
    if (r.scheme != VatScheme.standard || r.interval == FilingInterval.none) {
      return const [];
    }
    final result = <Deadline>[];
    for (final rule in tax.registrationDeadlineRules) {
      final periodic = rule.condition == DeadlineCondition.registrationReturn;
      if (periodic &&
          r.interval != FilingInterval.monthly &&
          r.interval != FilingInterval.quarterly) {
        continue;
      }
      if (!periodic && rule.condition != DeadlineCondition.registrationAnnual) {
        continue;
      }
      result.addAll(
        _expand(
          rule: rule,
          tax: tax,
          year: year,
          monthly: r.interval == FilingInterval.monthly,
          extension:
              periodic && r.permanentExtension && tax.hasPermanentExtension,
          state: '',
          prefix: '${r.shortLabel} · ',
          inPeriod: r.overlaps,
        ),
      );
    }
    return result;
  }

  static List<Deadline> _expand({
    required DeadlineRule rule,
    required TaxProfile tax,
    required int year,
    required bool monthly,
    required bool extension,
    required String state,
    String prefix = '',
    bool Function(DateTime from, DateTime to)? inPeriod,
  }) {
    DateTime shift(DateTime date) => rule.approximate
        ? date
        : tax.holidayCalendar.nextWorkday(date, state: state);
    Deadline make(DateTime raw, String label) => Deadline(
      date: shift(raw),
      label: '$prefix$label',
      legalRef: rule.legalRef,
      approximate: rule.approximate,
    );
    final result = <Deadline>[];
    switch (rule.schedule) {
      case AfterPeriod(
        :final dueDay,
        :final monthsAfter,
        :final extensionMonths,
        :final quarterly,
      ):
        final byMonth = monthly && !quarterly;
        final step = byMonth ? 1 : 3;
        final extra = extension ? extensionMonths : 0;
        for (var start = 1; start <= 12; start += step) {
          final endMonth = start + step - 1;
          if (inPeriod != null &&
              !inPeriod(
                DateTime(year, start),
                DateTime(year, endMonth + 1, 0),
              )) {
            continue;
          }
          final dueMonth = endMonth + monthsAfter + extra;
          final raw = dueDay == 0
              ? DateTime(year, dueMonth + 1, 0)
              : DateTime(year, dueMonth, dueDay);
          final period = byMonth
              ? '${tax.monthNames[start - 1]} $year'
              : 'Q${(start + 2) ~/ 3}/$year';
          result.add(make(raw, '${rule.label} $period'));
        }
      case FixedDates(:final monthDays):
        var quarter = 1;
        for (final (month, d) in monthDays) {
          final raw = d == 0
              ? DateTime(year, month + 1, 0)
              : DateTime(year, month, d);
          result.add(make(raw, '${rule.label} Q${quarter++}/$year'));
        }
      case FollowingYear(:final month, :final day):
        if (inPeriod != null &&
            !inPeriod(DateTime(year), DateTime(year, 12, 31))) {
          break;
        }
        result.add(make(DateTime(year + 1, month, day), '${rule.label} $year'));
    }
    return result;
  }
}
