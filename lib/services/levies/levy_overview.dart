import '../../core/formatting.dart';
import '../../data/repositories.dart';
import '../../domain/company_profile.dart';
import '../../domain/deadline_rule.dart';
import '../../domain/levy_rules.dart';
import '../../domain/money.dart';
import '../deadline_calculator.dart';
import 'levy_estimator.dart';

/// Nächster Zahlungstermin einer Abgabe (FA-19.5), Betrag falls bekannt.
class LevyPayment {
  const LevyPayment(this.deadline, this.amount);
  final Deadline deadline;
  final Money? amount;
}

/// Lädt die Zahlen für „Abgaben & Rücklagen“ (FA-19.2 bis FA-19.5).
class LevyOverview {
  const LevyOverview({
    required this.estimate,
    required this.settings,
    required this.payments,
  });

  final LevyEstimate estimate;
  final LevySettings settings;
  final List<LevyPayment> payments;

  /// Termin-Bezeichnungen der Abgaben in `TaxProfile.deadlineRules`.
  static const prepaymentLabel = 'ESt-Vorauszahlung';

  static Future<LevyOverview> load({
    required Repositories repos,
    required CompanyProfile profile,
    required DateTime today,
  }) async {
    final tax = profile.taxProfile;
    final rules = tax.levies;
    final settings = await repos.levySettings.load();
    final year = Period.year(today.year);
    final inputVat = !profile.isSmallBusiness;
    final totals = await repos.receipts.totals(
      from: year.from,
      to: today,
      inputVatDeductible: inputVat,
      depreciation: tax.depreciation,
      entertainment: tax.entertainment,
      nonDeductibleKinds: rules.nonDeductibleKinds,
    );
    final quarter = Period.quarter(today.year, (today.month - 1) ~/ 3 + 1);
    final vat = profile.isSmallBusiness
        ? null
        : await repos.receipts.totals(
            from: quarter.from,
            to: quarter.to,
            inputVatDeductible: inputVat,
          );
    final paid = await repos.receipts.levyPayments(from: year.from, to: today);
    final estimate = LevyEstimator.estimate(
      rules,
      LevyInput(
        year: today.year,
        monthsElapsed: today.month,
        profitToDate: totals.profit,
        turnoverToDate: totals.incomeGross,
        socialInsurancePaid:
            paid[LevyKind.socialInsurance] ?? const Money.zero(),
        incomeTaxPaid: paid[LevyKind.incomeTax] ?? const Money.zero(),
        tradeTaxPaid: paid[LevyKind.tradeTax] ?? const Money.zero(),
        openVat: vat?.vatPayable ?? const Money.zero(),
        foundingYear: profile.foundingYear,
        federalState: profile.federalState,
        legalFormFreelancer: profile.legalForm == LegalForm.freelancer,
      ),
      settings,
    );
    final due = [
      for (final y in [today.year, today.year + 1])
        ...DeadlineCalculator.forYear(
          profile: profile,
          year: y,
          interval: VatReturnInterval.quarterly,
        ),
    ];
    final svsLabel = rules.socialInsurance?.dueLabel;
    final payments = [
      for (final d in due)
        if ((d.label.startsWith(prepaymentLabel) ||
                (svsLabel != null && d.label.startsWith(svsLabel))) &&
            d.daysFrom(today) >= 0)
          LevyPayment(
            d,
            d.label.startsWith(prepaymentLabel) &&
                    !settings.incomeTaxPrepaymentQuarter.isZero
                ? settings.incomeTaxPrepaymentQuarter
                : null,
          ),
    ]..sort((a, b) => a.deadline.date.compareTo(b.deadline.date));
    return LevyOverview(
      estimate: estimate,
      settings: settings,
      payments: payments.take(4).toList(),
    );
  }
}
