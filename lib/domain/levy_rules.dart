import 'money.dart';

/// Regeln für die Schätzung „Abgaben & Rücklagen“ (FA-19.x, Lastenheft
/// 5.31). Nur Einzelunternehmen; Lohnabgaben gehören zur Ausbaustufe
/// „Premium Plus“ (Lastenheft 5.32).
///
/// Sätze in Basispunkten (1/100 %), Beträge in Cent (GR-1, GR-3). Jede Zahl
/// trägt ihre Fundstelle (GR-12). Die Werte sind eine **Schätzung** und
/// ersetzen keine Steuerberatung; offene Punkte: Spezifikation 14 (P-S78 ff.).
class LevyRules {
  const LevyRules({
    required this.incomeTaxByYear,
    required this.incomeTaxLegalRef,
    required this.socialInsuranceIsBusinessExpense,
    this.profitAllowance,
    this.socialInsurance,
    this.surcharges,
    this.tradeTax,
    required this.socialInsuranceLabel,
    required this.payrollHint,
  });

  /// Tarif je Veranlagungsjahr; für ein Jahr ohne eigenen Eintrag gilt der
  /// jüngste ältere (bzw. der älteste vorhandene).
  final Map<int, IncomeTaxTariff> incomeTaxByYear;
  final String incomeTaxLegalRef;

  /// AT: SVS-Beiträge sind Betriebsausgabe (§ 4 Abs 4 Z 1 lit a EStG 1988).
  /// DE: Kranken-/Pflegeversicherung der Unternehmerin ist Sonderausgabe
  /// (§ 10 Abs 1 Nr 3 EStG), keine Betriebsausgabe.
  final bool socialInsuranceIsBusinessExpense;

  /// AT Grundfreibetrag des Gewinnfreibetrags (§ 10 Abs 1 Z 1 EStG 1988).
  final ProfitAllowance? profitAllowance;

  /// AT GSVG-Beiträge; DE: `null` (Betrag nach Bescheid eingegeben).
  final SocialInsuranceRules? socialInsurance;

  /// DE Solidaritätszuschlag und Kirchensteuer.
  final GermanSurcharges? surcharges;

  /// DE Gewerbesteuer für Gewerbetreibende.
  final TradeTaxRules? tradeTax;

  final String socialInsuranceLabel;

  /// Hinweis auf Lohnabgaben, die nur mit Dienstnehmern anfallen.
  final String payrollHint;

  /// Kategorie-Kennungen, deren Buchungen den Gewinn nicht mindern
  /// (Einnahmen-Ausgaben-Rechnung): Einkommensteuer ist privat (AT § 20 Abs
  /// 1 Z 6 EStG 1988, DE § 12 Nr 3 EStG), Gewerbesteuer nicht abziehbar
  /// (§ 4 Abs 5b EStG), Kranken-/Pflegeversicherung in DE Sonderausgabe.
  Set<String> get nonDeductibleKinds => {
    LevyKind.incomeTax,
    LevyKind.tradeTax,
    if (!socialInsuranceIsBusinessExpense) LevyKind.socialInsurance,
  };

  IncomeTaxTariff tariffFor(int year) {
    final years = incomeTaxByYear.keys.toList()..sort();
    var chosen = years.first;
    for (final y in years) {
      if (y <= year) chosen = y;
    }
    return incomeTaxByYear[chosen]!;
  }
}

/// Kennungen der Abgabenkategorien (`categories.kind`, Schema 29).
abstract final class LevyKind {
  static const socialInsurance = 'socialInsurance';
  static const incomeTax = 'incomeTax';
  static const tradeTax = 'tradeTax';
  static const all = {socialInsurance, incomeTax, tradeTax};
}

/// Einkommensteuertarif.
sealed class IncomeTaxTariff {
  const IncomeTaxTariff();

  /// Steuer auf das zu versteuernde Einkommen [taxable].
  Money taxOn(Money taxable);
}

/// Stufentarif (AT § 33 Abs 1 EStG 1988): je Stufe ein Grenzsteuersatz.
class BracketTariff extends IncomeTaxTariff {
  const BracketTariff(this.brackets);

  /// Obergrenze (Cent, `null` = unbegrenzt) und Satz in Basispunkten.
  final List<(Money? upTo, int bp)> brackets;

  @override
  Money taxOn(Money taxable) {
    if (taxable.cents <= 0) return const Money.zero();
    // Summe in Cent × Basispunkte, erst am Ende auf Cent gerundet.
    var scaled = 0;
    var lower = 0;
    for (final (upTo, bp) in brackets) {
      final top = upTo == null
          ? taxable.cents
          : (taxable.cents < upTo.cents ? taxable.cents : upTo.cents);
      if (top > lower) scaled += (top - lower) * bp;
      if (upTo == null || taxable.cents <= upTo.cents) break;
      lower = upTo.cents;
    }
    return Money((scaled + 5000) ~/ 10000);
  }
}

/// Formeltarif nach § 32a Abs 1 EStG (DE), Grundtabelle. Rechnet exakt in
/// ganzen Zahlen: zvE auf volle Euro abgerundet, Steuer auf volle Euro
/// abgerundet.
class GermanFormulaTariff extends IncomeTaxTariff {
  const GermanFormulaTariff({
    required this.basicAllowance,
    required this.zone2Top,
    required this.zone2Factor,
    required this.zone3Top,
    required this.zone3Factor,
    required this.zone3Constant,
    required this.zone4Top,
    required this.zone4Constant,
    required this.zone5Constant,
  });

  /// Grundfreibetrag in Euro.
  final int basicAllowance;

  /// Obergrenze Zone 2 in Euro; Faktor in Hundertsteln (914,51 → 91451).
  final int zone2Top;
  final int zone2Factor;
  final int zone3Top;
  final int zone3Factor;

  /// Konstante Zone 3 in Cent (1.034,87 € → 103487).
  final int zone3Constant;
  final int zone4Top;

  /// Abzug Zone 4 (42 %) und Zone 5 (45 %) in Cent.
  final int zone4Constant;
  final int zone5Constant;

  @override
  Money taxOn(Money taxable) {
    final x = taxable.cents ~/ 100; // volle Euro, abgerundet
    if (x <= basicAllowance) return const Money.zero();
    int euros;
    if (x <= zone2Top) {
      // (a·y + 1.400)·y, y = (x − GFB)/10.000
      final d = x - basicAllowance;
      euros = (zone2Factor * d * d + 1400 * d * 1000000) ~/ 10000000000;
    } else if (x <= zone3Top) {
      // (b·z + 2.397)·z + c, z = (x − Zone-2-Grenze)/10.000
      final d = x - zone2Top;
      euros =
          (zone3Factor * d * d +
              2397 * d * 1000000 +
              zone3Constant * 100000000) ~/
          10000000000;
    } else if (x <= zone4Top) {
      euros = (42 * x - zone4Constant) ~/ 100;
    } else {
      euros = (45 * x - zone5Constant) ~/ 100;
    }
    return Money(euros * 100);
  }
}

/// AT Gewinnfreibetrag, nur Grundfreibetrag (ohne Investition).
class ProfitAllowance {
  const ProfitAllowance({
    required this.rateBp,
    required this.maxBase,
    required this.legalRef,
  });

  final int rateBp;
  final Money maxBase;
  final String legalRef;

  Money of(Money profit) {
    if (profit.cents <= 0) return const Money.zero();
    final base = profit < maxBase ? profit : maxBase;
    return Money((base.cents * rateBp + 5000) ~/ 10000);
  }
}

/// AT Pflichtversicherung nach GSVG.
class SocialInsuranceRules {
  const SocialInsuranceRules({
    required this.pensionBp,
    required this.healthBp,
    required this.provisionBp,
    required this.accidentMonthly,
    required this.minBaseYear,
    required this.maxBaseYear,
    required this.exemptionTurnoverLimit,
    required this.exemptionIncomeLimit,
    required this.provisionalYears,
    required this.dueLabel,
    required this.legalRef,
  });

  final int pensionBp;
  final int healthBp;
  final int provisionBp;
  final Money accidentMonthly;
  final Money minBaseYear;
  final Money maxBaseYear;

  /// Kleinunternehmer-Ausnahme von KV/PV (§ 4 Abs 1 Z 7 GSVG, Antrag).
  final Money exemptionTurnoverLimit;
  final Money exemptionIncomeLimit;

  /// Jahre mit vorläufiger Beitragsgrundlage = Mindestbeitragsgrundlage
  /// (§ 25a Abs 1 GSVG); danach Nachbemessung.
  final int provisionalYears;
  final String dueLabel;
  final String legalRef;
}

/// DE Solidaritätszuschlag (SolZG 1995) und Kirchensteuer (KiStG der Länder).
class GermanSurcharges {
  const GermanSurcharges({
    required this.soliBp,
    required this.soliExemptionTax,
    required this.soliPhaseInBp,
    required this.churchBpDefault,
    required this.churchBpByState,
  });

  final int soliBp;

  /// Freigrenze: bis zu dieser Einkommensteuer kein Zuschlag (Einzel).
  final Money soliExemptionTax;

  /// Milderungszone: höchstens dieser Anteil des übersteigenden Betrags.
  final int soliPhaseInBp;
  final int churchBpDefault;
  final Map<String, int> churchBpByState;

  int churchBpFor(String state) => churchBpByState[state] ?? churchBpDefault;

  Money soliOn(Money incomeTax) {
    if (incomeTax <= soliExemptionTax) return const Money.zero();
    final full = incomeTax.cents * soliBp ~/ 10000;
    final phased =
        (incomeTax.cents - soliExemptionTax.cents) * soliPhaseInBp ~/ 10000;
    return Money(full < phased ? full : phased);
  }
}

/// DE Gewerbesteuer (GewStG) und Anrechnung (§ 35 EStG).
class TradeTaxRules {
  const TradeTaxRules({
    required this.allowance,
    required this.baseRateBp,
    required this.defaultMultiplierPercent,
    required this.creditFactorPermille,
  });

  /// Freibetrag natürliche Personen (§ 11 Abs 1 Satz 3 Nr 1 GewStG).
  final Money allowance;

  /// Steuermesszahl (§ 11 Abs 2 GewStG).
  final int baseRateBp;

  /// Hebesatz-Vorschlag; tatsächlich: Gemeinde (§ 16 GewStG).
  final int defaultMultiplierPercent;

  /// Anrechnungsfaktor auf die Einkommensteuer (§ 35 Abs 1 EStG): 4,0.
  final int creditFactorPermille;

  /// Steuermessbetrag: Gewerbeertrag auf volle 100 € abgerundet
  /// (§ 11 Abs 1 Satz 3 GewStG), minus Freibetrag, × Messzahl.
  Money baseAmount(Money profit) {
    final rounded = profit.cents <= 0 ? 0 : profit.cents ~/ 10000 * 10000;
    final rest = rounded - allowance.cents;
    if (rest <= 0) return const Money.zero();
    return Money(rest * baseRateBp ~/ 10000);
  }
}
