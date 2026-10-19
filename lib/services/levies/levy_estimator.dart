import '../../core/formatting.dart';
import '../../domain/levy_rules.dart';
import '../../domain/money.dart';

/// Angaben der Nutzerin für die Schätzung (Tabelle `levy_settings`, Schema 29).
class LevySettings {
  const LevySettings({
    this.incomeTaxPrepaymentQuarter = const Money.zero(),
    this.socialInsuranceExempt = false,
    this.churchTax = false,
    this.freelancer,
    this.tradeTaxMultiplierPercent,
    this.healthInsuranceMonthly = const Money.zero(),
  });

  /// Vierteljährliche Einkommensteuer-Vorauszahlung laut Bescheid.
  final Money incomeTaxPrepaymentQuarter;

  /// AT: Kleinunternehmer-Ausnahme von KV/PV beantragt (§ 4 Abs 1 Z 7 GSVG).
  final bool socialInsuranceExempt;

  /// DE: kirchensteuerpflichtig.
  final bool churchTax;

  /// DE: Freiberuflerin (keine Gewerbesteuer). `null` = aus der Rechtsform.
  final bool? freelancer;

  /// DE: Hebesatz der Gemeinde; `null` = Vorschlag 400 %.
  final int? tradeTaxMultiplierPercent;

  /// DE: Kranken- und Pflegeversicherung monatlich laut Beitragsbescheid.
  final Money healthInsuranceMonthly;

  LevySettings copyWith({
    Money? incomeTaxPrepaymentQuarter,
    bool? socialInsuranceExempt,
    bool? churchTax,
    bool? freelancer,
    int? tradeTaxMultiplierPercent,
    Money? healthInsuranceMonthly,
  }) => LevySettings(
    incomeTaxPrepaymentQuarter:
        incomeTaxPrepaymentQuarter ?? this.incomeTaxPrepaymentQuarter,
    socialInsuranceExempt: socialInsuranceExempt ?? this.socialInsuranceExempt,
    churchTax: churchTax ?? this.churchTax,
    freelancer: freelancer ?? this.freelancer,
    tradeTaxMultiplierPercent:
        tradeTaxMultiplierPercent ?? this.tradeTaxMultiplierPercent,
    healthInsuranceMonthly:
        healthInsuranceMonthly ?? this.healthInsuranceMonthly,
  );

  Map<String, String> toMap() => {
    'income_tax_prepayment_quarter': '${incomeTaxPrepaymentQuarter.cents}',
    'social_insurance_exempt': socialInsuranceExempt ? '1' : '0',
    'church_tax': churchTax ? '1' : '0',
    if (freelancer != null) 'freelancer': freelancer! ? '1' : '0',
    if (tradeTaxMultiplierPercent != null)
      'trade_tax_multiplier': '$tradeTaxMultiplierPercent',
    'health_insurance_monthly': '${healthInsuranceMonthly.cents}',
  };

  static LevySettings fromMap(Map<String, String> m) {
    int? n(String k) => int.tryParse(m[k] ?? '');
    return LevySettings(
      incomeTaxPrepaymentQuarter: Money(
        n('income_tax_prepayment_quarter') ?? 0,
      ),
      socialInsuranceExempt: m['social_insurance_exempt'] == '1',
      churchTax: m['church_tax'] == '1',
      freelancer: m.containsKey('freelancer') ? m['freelancer'] == '1' : null,
      tradeTaxMultiplierPercent: n('trade_tax_multiplier'),
      healthInsuranceMonthly: Money(n('health_insurance_monthly') ?? 0),
    );
  }
}

/// Gebuchte Zahlen des laufenden Jahres bis heute.
class LevyInput {
  const LevyInput({
    required this.year,
    required this.monthsElapsed,
    required this.profitToDate,
    required this.turnoverToDate,
    this.socialInsurancePaid = const Money.zero(),
    this.incomeTaxPaid = const Money.zero(),
    this.tradeTaxPaid = const Money.zero(),
    this.openVat = const Money.zero(),
    this.foundingYear,
    this.federalState = '',
    this.legalFormFreelancer = false,
  });

  final int year;

  /// 1 bis 12: Monate des Jahres, auf die sich die Zahlen beziehen.
  final int monthsElapsed;

  /// Gewinn der Einnahmen-Ausgaben-Rechnung bis heute (ohne nicht abziehbare
  /// Abgaben, `LevyRules.nonDeductibleKinds`).
  final Money profitToDate;
  final Money turnoverToDate;
  final Money socialInsurancePaid;
  final Money incomeTaxPaid;
  final Money tradeTaxPaid;

  /// Umsatzsteuer-Zahllast des laufenden Voranmeldungszeitraums.
  final Money openVat;
  final int? foundingYear;
  final String federalState;
  final bool legalFormFreelancer;
}

/// Eine Abgabe im Jahr: geschätzt, bezahlt, offen.
class LevyLine {
  const LevyLine({
    required this.key,
    required this.label,
    required this.year,
    this.paid = const Money.zero(),
    required this.legalRef,
    this.note,
  });

  final String key;
  final String label;
  final Money year;
  final Money paid;
  final String legalRef;
  final String? note;

  Money get open => year > paid ? year - paid : const Money.zero();
}

class LevyEstimate {
  const LevyEstimate({
    required this.lines,
    required this.projectedProfit,
    required this.taxableIncome,
    required this.remainingMonths,
    this.hints = const [],
  });

  final List<LevyLine> lines;

  /// Hochgerechneter Jahresgewinn vor Sozialversicherung (AT) bzw. Gewinn.
  final Money projectedProfit;
  final Money taxableIncome;
  final int remainingMonths;
  final List<String> hints;

  Money get totalYear => lines.map((l) => l.year).sum;
  Money get totalPaid => lines.map((l) => l.paid).sum;
  Money get totalOpen => lines.map((l) => l.open).sum;

  /// Empfohlene monatliche Rücklage: offene Summe auf die restlichen Monate
  /// (einschließlich des laufenden) verteilt, auf volle Euro aufgerundet.
  Money get monthlyReserve {
    final perMonth =
        totalOpen.cents ~/ remainingMonths +
        (totalOpen.cents % remainingMonths == 0 ? 0 : 1);
    return Money((perMonth + 99) ~/ 100 * 100);
  }
}

/// Schätzung „Abgaben & Rücklagen“ (FA-19.2). Länderunterschiede nur über
/// [LevyRules] aus dem `TaxProfile` (GR-5).
///
/// Vereinfachungen (Spezifikation 11): Einzelveranlagung, keine anderen
/// Einkünfte, keine Absetz- oder Sonderausgabenbeträge außer den genannten,
/// Hochrechnung des bisherigen Gewinns linear auf zwölf Monate.
abstract final class LevyEstimator {
  static const disclaimer = 'Schätzung – ersetzt keine Steuerberatung';

  static Money _project(Money toDate, int months) =>
      Money(toDate.cents * 12 ~/ months);

  static LevyEstimate estimate(
    LevyRules rules,
    LevyInput input,
    LevySettings settings,
  ) {
    final months = input.monthsElapsed.clamp(1, 12);
    final lines = <LevyLine>[];
    final hints = <String>[];
    final tariff = rules.tariffFor(input.year);
    final si = rules.socialInsurance;

    late Money taxable;
    late Money projected;
    if (si != null) {
      // AT: Beitragsgrundlage = Einkünfte + vorgeschriebene SV-Beiträge
      // (Hinzurechnung § 25 Abs 2 Z 2 GSVG) = Gewinn vor SVS.
      projected = _project(
        input.profitToDate + input.socialInsurancePaid,
        months,
      );
      final turnover = _project(input.turnoverToDate, months);
      final svs = socialInsurance(
        si,
        profitBeforeSvs: projected,
        exempt: settings.socialInsuranceExempt,
      );
      final provisional =
          input.foundingYear != null &&
          input.year - input.foundingYear! < si.provisionalYears;
      String? note;
      if (provisional) {
        final pre = socialInsurance(
          si,
          profitBeforeSvs: si.minBaseYear,
          exempt: settings.socialInsuranceExempt,
        );
        final later = svs - pre;
        if (later > const Money.zero()) {
          note =
              'Vorläufig vorgeschrieben ${Fmt.money(pre)}; Nachbemessung '
              'später ca. ${Fmt.money(later)} – zurücklegen.';
        }
      }
      if (!settings.socialInsuranceExempt &&
          turnover <= si.exemptionTurnoverLimit &&
          projected <= si.exemptionIncomeLimit) {
        hints.add(
          'Ausnahme von Kranken- und Pensionsversicherung als '
          'Kleinunternehmerin ist möglich (Antrag bei der SVS, § 4 Abs 1 '
          'Z 7 GSVG).',
        );
      }
      lines.add(
        LevyLine(
          key: 'socialInsurance',
          label: rules.socialInsuranceLabel,
          year: svs,
          paid: input.socialInsurancePaid,
          legalRef: si.legalRef,
          note: note,
        ),
      );
      final profit = projected - svs;
      final allowance = rules.profitAllowance?.of(profit) ?? const Money.zero();
      taxable = profit - allowance;
      final est = tariff.taxOn(taxable);
      lines.add(
        LevyLine(
          key: 'incomeTax',
          label: 'Einkommensteuer',
          year: est,
          paid: input.incomeTaxPaid,
          legalRef: rules.incomeTaxLegalRef,
          note: allowance.isZero
              ? null
              : 'Gewinnfreibetrag ${Fmt.money(allowance)} abgezogen '
                    '(${rules.profitAllowance!.legalRef}).',
        ),
      );
    } else {
      projected = _project(input.profitToDate, months);
      final health = Money(settings.healthInsuranceMonthly.cents * 12);
      if (!health.isZero) {
        lines.add(
          LevyLine(
            key: 'socialInsurance',
            label: rules.socialInsuranceLabel,
            year: health,
            paid: input.socialInsurancePaid,
            legalRef: '§ 240 SGB V',
            note: 'Monatsbetrag laut Beitragsbescheid × 12.',
          ),
        );
      }
      final freelancer = settings.freelancer ?? input.legalFormFreelancer;
      final tt = rules.tradeTax;
      var credit = const Money.zero();
      if (tt != null && !freelancer) {
        final base = tt.baseAmount(projected);
        final multiplier =
            settings.tradeTaxMultiplierPercent ?? tt.defaultMultiplierPercent;
        final tradeTax = Money(base.cents * multiplier ~/ 100);
        credit = Money(base.cents * tt.creditFactorPermille ~/ 1000);
        if (credit > tradeTax) credit = tradeTax;
        lines.add(
          LevyLine(
            key: 'tradeTax',
            label: 'Gewerbesteuer',
            year: tradeTax,
            paid: input.tradeTaxPaid,
            legalRef: '§ 11 GewStG',
            note:
                'Hebesatz $multiplier %, Freibetrag '
                '${Fmt.money(tt.allowance)}.',
          ),
        );
      }
      // Kranken-/Pflegeversicherung vereinfachend voll als Vorsorgeaufwand
      // (§ 10 Abs 1 Nr 3 EStG), Sonderausgaben-Pauschbetrag nicht angesetzt.
      taxable = projected - health;
      var est = tariff.taxOn(taxable);
      if (credit > est) credit = est;
      est = est - credit;
      lines.add(
        LevyLine(
          key: 'incomeTax',
          label: 'Einkommensteuer',
          year: est,
          paid: input.incomeTaxPaid,
          legalRef: rules.incomeTaxLegalRef,
          note: credit.isZero
              ? null
              : 'Gewerbesteuer angerechnet ${Fmt.money(credit)} (§ 35 EStG).',
        ),
      );
      final sur = rules.surcharges;
      if (sur != null) {
        final soli = sur.soliOn(est);
        if (!soli.isZero) {
          lines.add(
            LevyLine(
              key: 'soli',
              label: 'Solidaritätszuschlag',
              year: soli,
              legalRef: '§ 4 SolZG 1995',
            ),
          );
        }
        if (settings.churchTax) {
          final bp = sur.churchBpFor(input.federalState);
          lines.add(
            LevyLine(
              key: 'churchTax',
              label: 'Kirchensteuer (${bp ~/ 100} %)',
              year: Money(est.cents * bp ~/ 10000),
              legalRef: 'KiStG des Landes',
            ),
          );
        }
      }
    }
    if (!input.openVat.isZero && !input.openVat.isNegative) {
      lines.add(
        LevyLine(
          key: 'vat',
          label: 'Umsatzsteuer laufender Zeitraum',
          year: input.openVat,
          legalRef: 'Zahllast der Voranmeldung',
        ),
      );
    }
    hints.add(rules.payrollHint);
    return LevyEstimate(
      lines: lines,
      projectedProfit: projected,
      taxableIncome: taxable.isNegative ? const Money.zero() : taxable,
      remainingMonths: 13 - months,
      hints: hints,
    );
  }

  /// AT GSVG-Jahresbeitrag: PV, KV, Selbständigenvorsorge auf die
  /// Beitragsgrundlage zwischen Mindest- und Höchstgrundlage, UV fix.
  static Money socialInsurance(
    SocialInsuranceRules si, {
    required Money profitBeforeSvs,
    bool exempt = false,
  }) {
    var base = profitBeforeSvs;
    if (base < si.minBaseYear) base = si.minBaseYear;
    if (base > si.maxBaseYear) base = si.maxBaseYear;
    final accident = Money(si.accidentMonthly.cents * 12);
    if (exempt) return accident;
    Money part(int bp) => Money((base.cents * bp + 5000) ~/ 10000);
    return part(si.pensionBp) +
        part(si.healthBp) +
        part(si.provisionBp) +
        accident;
  }
}
