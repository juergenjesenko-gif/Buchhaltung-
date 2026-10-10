import '../domain/money.dart';

/// Ergebnis einer Umsatzsteuerberechnung. Es gilt immer `net + vat == gross`,
/// ohne Ausnahme – das ist die zentrale Invariante der ganzen App.
class VatSplit {
  const VatSplit({
    required this.net,
    required this.vat,
    required this.gross,
    required this.permille,
  });

  final Money net;
  final Money vat;
  final Money gross;
  final int permille;

  bool get isConsistent => net + vat == gross;
}

/// Umsatzsteuerberechnung auf ganzen Cent.
///
/// Die Restgröße ist immer die Umsatzsteuer bzw. der Nettobetrag – nie der vom
/// Nutzer eingegebene Wert. Wer brutto eingibt, bekommt exakt seinen
/// Bruttobetrag zurück; wer netto eingibt, exakt seinen Nettobetrag.
class VatCalculator {
  const VatCalculator._();

  /// Aus einem Nettobetrag. `vat = round(net × permille / 1000)`.
  static VatSplit fromNet(Money net, int permille) {
    final vat = Money(_divideRounded(net.cents * permille, 1000));
    return VatSplit(net: net, vat: vat, gross: net + vat, permille: permille);
  }

  /// Aus einem Bruttobetrag – der übliche Fall beim Abtippen eines Belegs.
  ///
  /// Der Nettobetrag wird herausgerechnet und die Steuer als Differenz
  /// gebildet. Dadurch bleibt der Bruttobetrag exakt der eingegebene Wert,
  /// auch wenn die Division nicht aufgeht.
  static VatSplit fromGross(Money gross, int permille) {
    final net = Money(_divideRounded(gross.cents * 1000, 1000 + permille));
    return VatSplit(
      net: net,
      vat: gross - net,
      gross: gross,
      permille: permille,
    );
  }

  /// Ganzzahlige Division mit kaufmännischer Rundung (halbe Cent von der Null
  /// weg), ohne Umweg über `double`.
  static int _divideRounded(int numerator, int denominator) {
    final magnitude = (2 * numerator.abs() + denominator) ~/ (2 * denominator);
    return numerator < 0 ? -magnitude : magnitude;
  }

  /// Für Kleinunternehmer und steuerfreie Umsätze: keine Steuer, netto = brutto.
  static VatSplit exempt(Money amount) => VatSplit(
    net: amount,
    vat: const Money.zero(),
    gross: amount,
    permille: 0,
  );
}
