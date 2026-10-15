import '../domain/invoice.dart';
import '../domain/money.dart';
import 'vat_calculator.dart';

/// Eine Zusatzzeile der Rechnung je Steuersatz: anteiliger Gesamtrabatt
/// (negativ) oder Versandkosten. Die Umsatzsteuer ist je Zeile gerundet
/// (GR-5), `net + vat == gross` gilt je Zeile (GR-2).
class RateLine {
  const RateLine({required this.vatPermille, required this.net});

  final int vatPermille;
  final Money net;

  Money vatFor({required bool isSmallBusiness}) => isSmallBusiness
      ? const Money.zero()
      : VatCalculator.fromNet(net, vatPermille).vat;
}

/// Entgelt und Steuer eines Steuersatzes.
typedef RateSum = ({Money net, Money vat});

/// Rechnungssummen mit Positionsrabatt, Gesamtrabatt, Versandkosten und
/// Skonto (Lastenheft L-3.21 bis L-3.24, Spezifikation GR-12).
///
/// Ablauf:
/// 1. Je Position: Betrag = Menge × Einzelpreis, abzüglich Positionsrabatt
///    (Prozent in Promille oder Betrag in Cent) – ergibt das Entgelt.
/// 2. Gesamtrabatt: Prozent auf die Summe der Entgelte oder fester Betrag,
///    anteilig nach Entgelt je Steuersatz auf Rabattzeilen je Satz verteilt.
///    Der Restcent geht nach dem größten Rest, bei Gleichstand an den höheren
///    Satz – deterministisch.
/// 3. Versandkosten folgen der Hauptleistung: ein Satz → dieser Satz;
///    mehrere Sätze → anteilig nach Entgelt (nach Rabatt) je Satz, eine
///    Teilzeile je Satz. Wahlweise ein fester Satz.
/// 4. Umsatzsteuer wird je Position und je Zusatzzeile gerundet, nie auf der
///    Summe (GR-5).
///
/// Bei Kleinunternehmern gibt es nur den Schlüssel 0 und keine Steuer.
class InvoiceTotals {
  InvoiceTotals._({
    required this.isSmallBusiness,
    required this.itemsNet,
    required this.itemNetByRate,
    required this.discount,
    required this.discountLines,
    required this.shippingLines,
    required this.breakdown,
  });

  /// Summen einer Rechnung. Eine Stornorechnung (L-3.7) trägt dieselben
  /// Positionen wie die Originalrechnung; ihre Summen sind exakt die
  /// negierten Summen des Originals – je Steuersatz, ohne neue Rundung.
  factory InvoiceTotals.of(Invoice invoice) {
    final totals = InvoiceTotals.compute(
      items: invoice.items,
      isSmallBusiness: invoice.isSmallBusiness,
      discountPermille: invoice.discountPermille,
      discountAmount: invoice.discountAmount,
      shipping: invoice.shipping,
      shippingVatPermille: invoice.shippingVatPermille,
    );
    return invoice.isCancellation ? totals.negated() : totals;
  }

  /// Alle Beträge mit umgekehrtem Vorzeichen (Stornorechnung, L-3.7).
  /// Weil nur das Vorzeichen wechselt, gilt `net + vat == gross` je Satz
  /// weiter, und Original plus Storno ergeben je Satz genau null.
  InvoiceTotals negated() => InvoiceTotals._(
    isSmallBusiness: isSmallBusiness,
    itemsNet: -itemsNet,
    itemNetByRate: {for (final e in itemNetByRate.entries) e.key: -e.value},
    discount: -discount,
    discountLines: [
      for (final l in discountLines)
        RateLine(vatPermille: l.vatPermille, net: -l.net),
    ],
    shippingLines: [
      for (final l in shippingLines)
        RateLine(vatPermille: l.vatPermille, net: -l.net),
    ],
    breakdown: {
      for (final e in breakdown.entries)
        e.key: (net: -e.value.net, vat: -e.value.vat),
    },
  );

  factory InvoiceTotals.compute({
    required List<InvoiceItem> items,
    required bool isSmallBusiness,
    int discountPermille = 0,
    Money discountAmount = const Money.zero(),
    Money shipping = const Money.zero(),
    int? shippingVatPermille,
  }) {
    int rateOf(int permille) => isSmallBusiness ? 0 : permille;

    final itemNet = <int, int>{};
    final itemVat = <int, int>{};
    for (final item in items) {
      final rate = rateOf(item.vatPermille);
      itemNet[rate] = (itemNet[rate] ?? 0) + item.net.cents;
      itemVat[rate] =
          (itemVat[rate] ?? 0) + (isSmallBusiness ? 0 : item.vat.cents);
    }
    final itemsNet = itemNet.values.fold(0, (a, b) => a + b);

    // Gesamtrabatt.
    var discount = 0;
    if (discountPermille > 0) {
      discount = divideRounded(itemsNet * discountPermille, 1000);
    } else if (discountAmount.cents > 0) {
      discount = discountAmount.cents;
    }
    if (discount > itemsNet) discount = itemsNet < 0 ? 0 : itemsNet;
    final discountShares = allocate(-discount, itemNet);
    final discountLines = [
      for (final rate in _descending(discountShares.keys))
        if (discountShares[rate] != 0)
          RateLine(vatPermille: rate, net: Money(discountShares[rate]!)),
    ];

    // Versandkosten.
    final shippingLines = <RateLine>[];
    if (shipping.cents != 0) {
      if (shippingVatPermille != null || itemNet.isEmpty) {
        shippingLines.add(
          RateLine(
            vatPermille: rateOf(shippingVatPermille ?? 0),
            net: shipping,
          ),
        );
      } else {
        final afterDiscount = {
          for (final rate in itemNet.keys)
            rate: itemNet[rate]! + (discountShares[rate] ?? 0),
        };
        var shares = allocate(shipping.cents, afterDiscount);
        if (shares.isEmpty) {
          shares = {_descending(itemNet.keys).first: shipping.cents};
        }
        for (final rate in _descending(shares.keys)) {
          if (shares[rate] == 0) continue;
          shippingLines.add(
            RateLine(vatPermille: rate, net: Money(shares[rate]!)),
          );
        }
      }
    }

    // Summen je Steuersatz.
    final net = <int, int>{...itemNet};
    final vat = <int, int>{...itemVat};
    for (final line in [...discountLines, ...shippingLines]) {
      net[line.vatPermille] = (net[line.vatPermille] ?? 0) + line.net.cents;
      vat[line.vatPermille] =
          (vat[line.vatPermille] ?? 0) +
          line.vatFor(isSmallBusiness: isSmallBusiness).cents;
    }
    final breakdown = <int, RateSum>{
      for (final rate in _descending(net.keys))
        rate: (net: Money(net[rate]!), vat: Money(vat[rate] ?? 0)),
    };
    if (breakdown.isEmpty && isSmallBusiness) {
      breakdown[0] = (net: const Money.zero(), vat: const Money.zero());
    }

    return InvoiceTotals._(
      isSmallBusiness: isSmallBusiness,
      itemsNet: Money(itemsNet),
      itemNetByRate: {
        for (final rate in _descending(itemNet.keys))
          rate: Money(itemNet[rate]!),
      },
      discount: Money(discount),
      discountLines: discountLines,
      shippingLines: shippingLines,
      breakdown: breakdown,
    );
  }

  final bool isSmallBusiness;

  /// Summe der Positionen nach Positionsrabatt, vor Gesamtrabatt.
  final Money itemsNet;
  final Map<int, Money> itemNetByRate;

  /// Gesamtrabatt als positiver Betrag.
  final Money discount;
  final List<RateLine> discountLines;
  final List<RateLine> shippingLines;

  /// Entgelt und Steuer je Satz, absteigend nach Satz – so auf der Rechnung
  /// auszuweisen und als Einnahme je Satz zu buchen.
  final Map<int, RateSum> breakdown;

  Money get shipping => shippingLines.map((l) => l.net).sum;
  Money get net => breakdown.values.map((s) => s.net).sum;
  Money get vat => breakdown.values.map((s) => s.vat).sum;
  Money get gross => net + vat;

  /// Bruttobetrag je Satz.
  Map<int, Money> get grossByRate => {
    for (final e in breakdown.entries) e.key: e.value.net + e.value.vat,
  };

  /// Skontobetrag auf den Bruttobetrag, kaufmännisch gerundet (L-3.23).
  Money skontoAmount(int skontoPermille) => skontoPermille <= 0
      ? const Money.zero()
      : Money(divideRounded(gross.cents * skontoPermille, 1000));

  /// Verteilt einen Skontoabzug anteilig nach Brutto je Satz (Restcent nach
  /// größtem Rest) und teilt jeden Anteil in Entgelt und Steuer
  /// (`VatCalculator.fromGross`). So mindert sich je Satz das Entgelt und
  /// die Umsatzsteuer (§ 16 UStG AT, § 17 UStG DE).
  Map<int, RateSum> skontoSplit(Money skonto) {
    if (skonto.isZero) return const {};
    final shares = allocate(skonto.cents, {
      for (final e in grossByRate.entries) e.key: e.value.cents,
    });
    return {
      for (final rate in _descending(shares.keys))
        rate: () {
          final portion = Money(shares[rate]!);
          if (isSmallBusiness) {
            return (net: portion, vat: const Money.zero());
          }
          final split = VatCalculator.fromGross(portion, rate);
          return (net: split.net, vat: split.vat);
        }(),
    };
  }

  /// Entgelt und Steuer je Satz nach Abzug eines Skontos – das, was bei
  /// Zahlung als Einnahme gebucht wird.
  Map<int, RateSum> breakdownAfterSkonto(Money skonto) {
    final split = skontoSplit(skonto);
    return {
      for (final e in breakdown.entries)
        e.key: (
          net: e.value.net - (split[e.key]?.net ?? const Money.zero()),
          vat: e.value.vat - (split[e.key]?.vat ?? const Money.zero()),
        ),
    };
  }

  /// Verteilt [total] Cent anteilig nach [weights] (nur positive Gewichte).
  /// Ganzzahlig: Jeder Schlüssel erhält den abgerundeten Anteil, die
  /// restlichen Cent gehen einzeln an die größten Reste; bei Gleichstand an
  /// den höheren Schlüssel. Die Summe der Anteile ist exakt [total].
  static Map<int, int> allocate(int total, Map<int, int> weights) {
    final keys = _descending(
      weights.keys.where((k) => weights[k]! > 0),
    ).toList();
    if (keys.isEmpty || total == 0) return {for (final k in keys) k: 0};
    final sumWeights = keys.fold(0, (a, k) => a + weights[k]!);
    final magnitude = total.abs();
    final base = <int, int>{};
    final remainder = <int, int>{};
    var assigned = 0;
    for (final k in keys) {
      final product = magnitude * weights[k]!;
      base[k] = product ~/ sumWeights;
      remainder[k] = product % sumWeights;
      assigned += base[k]!;
    }
    final order = [...keys]
      ..sort((a, b) {
        final byRemainder = remainder[b]!.compareTo(remainder[a]!);
        return byRemainder != 0 ? byRemainder : b.compareTo(a);
      });
    for (var i = 0; i < magnitude - assigned; i++) {
      base[order[i % order.length]] = base[order[i % order.length]]! + 1;
    }
    return {for (final k in keys) k: total < 0 ? -base[k]! : base[k]!};
  }

  static Iterable<int> _descending(Iterable<int> keys) =>
      keys.toSet().toList()..sort((a, b) => b.compareTo(a));
}
