/// Abzugsbeschränkung für Bewirtung (FA-2.60, Lastenheft 14a).
///
/// Der abziehbare Teil wird je Beleg kaufmännisch auf Cent gerundet, der
/// nicht abziehbare Teil ist die Restgröße: beide ergeben immer exakt den
/// Aufwand des Belegs (GR-2 sinngemäß). Summen über mehrere Belege sind die
/// Summe der Belegwerte, nie ein neu gerundeter Anteil der Gesamtsumme.
library;

import '../domain/country.dart';
import '../domain/money.dart';

/// Aufteilung eines Bewirtungsaufwands.
class EntertainmentSplit {
  const EntertainmentSplit({
    required this.deductible,
    required this.nonDeductible,
  });

  /// Teilt [expense] (netto bzw. beim Kleinunternehmer brutto) nach
  /// [rules] auf. Negative Beträge (Gutschriften) werden spiegelbildlich
  /// gerundet.
  factory EntertainmentSplit.of(Money expense, EntertainmentRules rules) {
    final cents = expense.cents;
    final scaled = cents.abs() * rules.deductiblePermille;
    // Kaufmännisch runden: ab 0,5 Cent auf.
    final rounded = (scaled + 500) ~/ 1000;
    final deductible = cents < 0 ? -rounded : rounded;
    return EntertainmentSplit(
      deductible: Money(deductible),
      nonDeductible: Money(cents - deductible),
    );
  }

  final Money deductible;
  final Money nonDeductible;

  Money get total => deductible + nonDeductible;
}
