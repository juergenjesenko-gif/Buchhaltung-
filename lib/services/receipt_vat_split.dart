import '../domain/money.dart';
import '../domain/receipt.dart';
import 'vat_calculator.dart';

/// Ein Teil eines Belegs vor der Berechnung: Steuersatz und Bruttobetrag,
/// so wie er auf dem Beleg steht.
typedef VatPart = ({int permille, Money gross});

/// Aufteilung eines Belegs nach Steuersätzen (L-2.27), z. B. Speisen 10 %
/// und Getränke 20 % auf einem Bewirtungsbeleg oder 10 %/20 % beim
/// Supermarkteinkauf.
///
/// Eingegeben wird je Satz der **Bruttobetrag**; Netto und Steuer werden je
/// Teil herausgerechnet, die Steuer ist die Restgröße (GR-2). Die Summe der
/// Teile muss den Belegbetrag exakt ergeben. Rein fachlich, ohne Oberfläche.
class ReceiptVatSplit {
  const ReceiptVatSplit._();

  /// Zeilen aus den Teilen, je Teil `net + vat == gross`.
  static List<ReceiptVatLine> lines(List<VatPart> parts) => [
    for (final part in parts)
      _line(VatCalculator.fromGross(part.gross, part.permille)),
  ];

  static ReceiptVatLine _line(VatSplit split) => ReceiptVatLine(
    vatPermille: split.permille,
    net: split.net,
    vat: split.vat,
    gross: split.gross,
  );

  /// Vorschlag für den letzten Teil: Belegbetrag minus alle anderen Teile.
  static Money remainder(Money total, Iterable<Money> others) =>
      total - others.sum;

  /// Differenz Summe der Teile minus Belegbetrag; `Money.zero()` = stimmt.
  static Money difference(Money total, Iterable<Money> parts) =>
      parts.sum - total;

  /// Kopfwerte eines Belegs aus seinen Zeilen: Summen und der Satz der Zeile
  /// mit dem größten Bruttobetrag (bei Gleichstand die erste).
  static ({Money net, Money vat, Money gross, int permille}) header(
    List<ReceiptVatLine> lines,
  ) {
    assert(lines.isNotEmpty);
    var dominant = lines.first;
    for (final line in lines.skip(1)) {
      if (line.gross > dominant.gross) dominant = line;
    }
    return (
      net: lines.map((l) => l.net).sum,
      vat: lines.map((l) => l.vat).sum,
      gross: lines.map((l) => l.gross).sum,
      permille: dominant.vatPermille,
    );
  }

  /// Fasst Teile mit gleichem Satz zusammen (Reihenfolge des ersten
  /// Auftretens) und lässt leere Teile weg. Zwei Zeilen mit demselben Satz
  /// wären in jeder Auswertung ohnehin eine.
  static List<VatPart> normalize(List<VatPart> parts) {
    final byRate = <int, Money>{};
    for (final part in parts) {
      if (part.gross.isZero) continue;
      byRate[part.permille] =
          (byRate[part.permille] ?? const Money.zero()) + part.gross;
    }
    return [
      for (final entry in byRate.entries)
        (permille: entry.key, gross: entry.value),
    ];
  }
}
