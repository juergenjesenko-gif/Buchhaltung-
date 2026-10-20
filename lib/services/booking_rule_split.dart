/// Aufteilung einer Ausgabe nach Buchungsregel (FA-20.3).
///
/// Wie bei der Bewirtung (FA-2.60): der betriebliche Teil wird je Beleg
/// kaufmännisch auf Cent gerundet, der Privatanteil ist die Restgröße, beide
/// ergeben exakt den Aufwand (GR-2 sinngemäß). Die Vorsteuer wird je
/// Steuersatzzeile aufgeteilt (GR-4 sinngemäß); unter der Mindestnutzung
/// ([MixedUseRules.minBusinessPermilleForInputVat]) entfällt sie ganz, und
/// ihr betrieblicher Teil wird Aufwand.
library;

import '../domain/booking_rule.dart';
import '../domain/country.dart';
import '../domain/money.dart';

/// Kaufmännisch gerundeter Anteil, spiegelbildlich für negative Beträge.
Money sharePermille(Money amount, int permille) {
  final cents = amount.cents;
  final rounded = (cents.abs() * permille + 500) ~/ 1000;
  return Money(cents < 0 ? -rounded : rounded);
}

/// Eine Steuersatzzeile eines Belegs.
typedef VatLineAmounts = ({int permille, Money net, Money vat, Money gross});

class BookingRuleSplit {
  const BookingRuleSplit({
    required this.base,
    required this.business,
    required this.privatePart,
    required this.inputVatRemovedByRate,
    required this.vatAsExpense,
  });

  /// Teilt einen Beleg mit seinen Steuersatzzeilen [lines] nach [rule] auf.
  /// Ohne Vorsteuerabzug ([inputVatDeductible] `false`, Kleinunternehmer)
  /// ist der Aufwand brutto und es gibt keine Vorsteuer.
  factory BookingRuleSplit.of({
    required List<VatLineAmounts> lines,
    required int businessPermille,
    required bool inputVatDeductible,
    required MixedUseRules rules,
  }) {
    var base = const Money.zero();
    var business = const Money.zero();
    var vatAsExpense = const Money.zero();
    final removed = <int, Money>{};
    final vatAllowed = businessPermille >= rules.minBusinessPermilleForInputVat;
    for (final l in lines) {
      final lineBase = inputVatDeductible ? l.net : l.gross;
      base += lineBase;
      business += sharePermille(lineBase, businessPermille);
      if (!inputVatDeductible) continue;
      final vatBusiness = sharePermille(l.vat, businessPermille);
      final deductible = vatAllowed ? vatBusiness : const Money.zero();
      final cut = l.vat - deductible;
      if (!cut.isZero) {
        removed[l.permille] = (removed[l.permille] ?? const Money.zero()) + cut;
      }
      if (!vatAllowed) vatAsExpense += vatBusiness;
    }
    return BookingRuleSplit(
      base: base,
      business: business,
      privatePart: base - business,
      inputVatRemovedByRate: removed,
      vatAsExpense: vatAsExpense,
    );
  }

  /// Aufwand des Belegs (netto, beim Kleinunternehmer brutto).
  final Money base;

  /// Betriebliche Ausgabe aus [base].
  final Money business;

  /// Privatanteil = [base] − [business]; kein Aufwand.
  final Money privatePart;

  /// Nicht abziehbare Vorsteuer je Steuersatz (Privatanteil bzw. alles
  /// unter der Mindestnutzung).
  final Map<int, Money> inputVatRemovedByRate;

  /// Betrieblicher Teil der nicht abziehbaren Vorsteuer: wird Aufwand.
  final Money vatAsExpense;

  Money get inputVatRemoved =>
      inputVatRemovedByRate.values.fold(const Money.zero(), (a, b) => a + b);
}

/// Erste passende Regel (die zuerst angelegte gewinnt), außer die Buchung
/// ist von ihr ausgenommen.
BookingRule? matchingRule(
  Iterable<BookingRule> rules,
  BookingFacts facts, {
  Set<int> excludedRuleIds = const {},
}) {
  final sorted = rules.toList()
    ..sort((a, b) => (a.id ?? 1 << 30).compareTo(b.id ?? 1 << 30));
  for (final r in sorted) {
    if (r.id != null && excludedRuleIds.contains(r.id)) continue;
    if (r.matches(facts)) return r;
  }
  return null;
}

/// Summen einer Regel im Zeitraum (für Berichte, FA-20.5).
class BookingRuleSums {
  BookingRuleSums(this.rule);

  final BookingRule rule;
  int count = 0;
  int excludedCount = 0;
  Money base = const Money.zero();
  Money business = const Money.zero();
  Money privatePart = const Money.zero();
  Money inputVatRemoved = const Money.zero();
  Money vatAsExpense = const Money.zero();

  void add(BookingRuleSplit s) {
    count++;
    base += s.base;
    business += s.business;
    privatePart += s.privatePart;
    inputVatRemoved += s.inputVatRemoved;
    vatAsExpense += s.vatAsExpense;
  }
}
