/// Geldbeträge werden **immer** als ganzzahlige Cent gespeichert und gerechnet.
///
/// Fließkommazahlen sind in der Buchhaltung unbrauchbar: `0.1 + 0.2 != 0.3`.
/// Ein einziger falsch gerundeter Cent macht eine Umsatzsteuervoranmeldung
/// unplausibel, deshalb gibt es in dieser App keinen `double`-Betrag.
class Money implements Comparable<Money> {
  const Money(this.cents);

  const Money.zero() : cents = 0;

  /// Erzeugt einen Betrag aus Euro als Dezimalzahl. Nur für Testdaten und für
  /// die Umwandlung von Benutzereingaben gedacht – niemals für Zwischenergebnisse.
  factory Money.fromEuro(num euro) => Money((euro * 100).round());

  /// Parst eine Benutzereingabe im deutschen Format ("1.234,56" oder "1234,56").
  /// Gibt `null` zurück, wenn die Eingabe kein gültiger Betrag ist.
  static Money? tryParse(String input) {
    final cleaned = input.trim().replaceAll('€', '').replaceAll(' ', '');
    if (cleaned.isEmpty) return null;

    // Deutsche Schreibweise: Punkt ist Tausendertrenner, Komma ist Dezimaltrenner.
    // Enthält die Eingabe beides, gewinnt das zuletzt stehende Zeichen als Dezimaltrenner.
    final lastComma = cleaned.lastIndexOf(',');
    final lastDot = cleaned.lastIndexOf('.');
    String normalized;
    if (lastComma >= 0 && lastComma > lastDot) {
      normalized = cleaned.replaceAll('.', '').replaceAll(',', '.');
    } else if (lastDot >= 0 && lastDot > lastComma) {
      normalized = cleaned.replaceAll(',', '');
    } else {
      normalized = cleaned.replaceAll(',', '').replaceAll('.', '');
    }

    final value = double.tryParse(normalized);
    if (value == null) return null;
    return Money((value * 100).round());
  }

  final int cents;

  Money operator +(Money other) => Money(cents + other.cents);
  Money operator -(Money other) => Money(cents - other.cents);
  Money operator -() => Money(-cents);

  /// Multiplikation mit einer Menge. Rundet kaufmännisch auf ganze Cent.
  Money times(num factor) => Money((cents * factor).round());

  bool get isZero => cents == 0;
  bool get isNegative => cents < 0;
  Money get abs => Money(cents.abs());

  double get asEuro => cents / 100;

  @override
  int compareTo(Money other) => cents.compareTo(other.cents);

  bool operator <(Money other) => cents < other.cents;
  bool operator <=(Money other) => cents <= other.cents;
  bool operator >(Money other) => cents > other.cents;
  bool operator >=(Money other) => cents >= other.cents;

  @override
  bool operator ==(Object other) => other is Money && other.cents == cents;

  @override
  int get hashCode => cents.hashCode;

  @override
  String toString() => '${(cents / 100).toStringAsFixed(2)} EUR';
}

extension MoneyIterable on Iterable<Money> {
  Money get sum => fold(const Money.zero(), (a, b) => a + b);
}
