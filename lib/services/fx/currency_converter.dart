import '../../domain/exchange_rate.dart';
import '../../domain/money.dart';

/// Umrechnung fremder Währung in Euro, ausschließlich mit Ganzzahlen.
///
/// Beträge in fremder Währung stehen wie Euro in Hundertsteln der Einheit
/// (`Money.cents`), auch bei Währungen ohne Nachkommastellen (JPY 1.500 =
/// `150000`). Kurse sind Einheiten je Euro × [exchangeRateScale].
class CurrencyConverter {
  const CurrencyConverter._();

  /// Euro-Betrag zu [original] beim Kurs [rateMicros], kaufmännisch auf
  /// Cent gerundet (half-up, symmetrisch für negative Beträge).
  ///
  /// `euroCent = original × 10^6 / rateMicros`.
  static Money toEuro(Money original, int rateMicros) {
    if (rateMicros <= 0) {
      throw ArgumentError.value(rateMicros, 'rateMicros', 'muss > 0 sein');
    }
    return Money(divideHalfUp(original.cents * exchangeRateScale, rateMicros));
  }

  /// Ganzzahlige Division mit kaufmännischer Rundung (0,5 vom Null weg).
  static int divideHalfUp(int numerator, int denominator) {
    if (denominator <= 0) throw ArgumentError('Nenner muss > 0 sein');
    final negative = numerator < 0;
    final n = numerator.abs();
    final q = (2 * n + denominator) ~/ (2 * denominator);
    return negative ? -q : q;
  }

  /// Mittel mehrerer Tageskurse, auf 10^-6 half-up gerundet; `null` bei
  /// leerer Liste. Grundlage des „EZB-Monatsmittels“.
  static int? average(List<int> rateMicros) {
    if (rateMicros.isEmpty) return null;
    final sum = rateMicros.fold<int>(0, (a, b) => a + b);
    return divideHalfUp(sum, rateMicros.length);
  }

  /// Liest einen Kurs wie `1,0823` oder `161.25` exakt als Ganzzahl × 10^6.
  /// `null` bei ungültiger Eingabe, mehr als sechs Nachkommastellen oder
  /// einem Kurs ≤ 0.
  static int? parseRate(String input) {
    final s = input.trim().replaceAll(' ', '').replaceAll(',', '.');
    final match = RegExp(r'^(\d{1,9})(?:\.(\d{1,6}))?$').firstMatch(s);
    if (match == null) return null;
    final whole = int.parse(match.group(1)!);
    final frac = (match.group(2) ?? '').padRight(6, '0');
    final value = whole * exchangeRateScale + int.parse(frac);
    return value > 0 ? value : null;
  }

  /// Kurs mit sechs Nachkommastellen und Dezimalkomma, z. B. `1,082300`.
  static String formatRate(int rateMicros) {
    final whole = rateMicros ~/ exchangeRateScale;
    final frac = (rateMicros % exchangeRateScale).toString().padLeft(6, '0');
    return '$whole,$frac';
  }
}
