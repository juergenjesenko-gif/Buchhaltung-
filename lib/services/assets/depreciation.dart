/// AfA-Plan je Wirtschaftsgut (Spezifikation GR-15, FA-15.3 bis FA-15.6).
///
/// Rundung: kumuliert abgerundet. Nach `k` von `n` Zeiteinheiten (Monate bzw.
/// Halbjahre) sind `AK × k ~/ n` Cent abgeschrieben; die Jahres-AfA ist die
/// Differenz zweier Stände. Damit ist jede Jahres-AfA ganzzahlig, die Summe
/// ist exakt die Anschaffungskosten und das letzte Jahr trägt den Rest.
library;

import '../../domain/fixed_asset.dart';
import '../../domain/money.dart';

enum AfaKind {
  /// Planmäßige Jahres-AfA, gebucht am 31.12.
  regular,

  /// Sofortabschreibung GWG, gebucht am Anschaffungstag.
  gwg,

  /// Jahresteil des Sammelpostens, gebucht am 31.12.
  pool,

  /// Restbuchwert beim Ausscheiden, gebucht am Tag des Ausscheidens.
  disposal,
}

/// Eine Abschreibungsbuchung.
class AfaEntry {
  const AfaEntry(this.bookedOn, this.amount, this.kind);

  final DateTime bookedOn;
  final Money amount;
  final AfaKind kind;
}

/// Eine Zeile des Anlagenverzeichnisses je Jahr.
class AfaYear {
  const AfaYear({
    required this.year,
    required this.opening,
    required this.afa,
    required this.disposalValue,
  });

  final int year;

  /// Buchwert am 1.1. (im Anschaffungsjahr: Anschaffungskosten).
  final Money opening;

  /// Planmäßige AfA bzw. GWG/Sammelposten im Jahr.
  final Money afa;

  /// Restbuchwert beim Ausscheiden in diesem Jahr.
  final Money disposalValue;

  Money get closing => opening - afa - disposalValue;
}

class Depreciation {
  Depreciation._();

  /// Alle Buchungen eines Wirtschaftsguts in zeitlicher Reihenfolge.
  static List<AfaEntry> entries(FixedAsset asset, DepreciationRules rules) {
    final cost = asset.cost.cents;
    final start = asset.acquiredOn;
    if (cost <= 0) return const [];
    switch (asset.method) {
      case DepreciationMethod.gwg:
        return [AfaEntry(start, asset.cost, AfaKind.gwg)];
      case DepreciationMethod.pool:
        // § 6 Abs 2a EStG: je ein Fünftel im Jahr der Bildung und den vier
        // Folgejahren; Ausscheiden ändert den Sammelposten nicht.
        final out = <AfaEntry>[];
        var done = 0;
        for (var k = 1; k <= 5; k++) {
          final cum = cost * k ~/ 5;
          out.add(
            AfaEntry(
              DateTime(start.year + k - 1, 12, 31),
              Money(cum - done),
              AfaKind.pool,
            ),
          );
          done = cum;
        }
        return out;
      case DepreciationMethod.linear:
        return _linear(asset, rules);
    }
  }

  static List<AfaEntry> _linear(FixedAsset asset, DepreciationRules rules) {
    final cost = asset.cost.cents;
    final start = asset.acquiredOn;
    final years = asset.usefulLifeYears < 1 ? 1 : asset.usefulLifeYears;
    final monthly = rules.timing == DepreciationTiming.monthly;
    final perYear = monthly ? 12 : 2;
    final total = years * perYear;
    // Erste Periode: DE ab Anschaffungsmonat (§ 7 Abs 1 Satz 4 EStG);
    // AT ganze AfA bei Inbetriebnahme im ersten Halbjahr, sonst halbe
    // (§ 7 Abs 2 EStG). Nutzungsdauer 1 Jahr (DE Computer, BMF 22.02.2022):
    // volle AfA im Anschaffungsjahr (P-S59).
    var firstUnits = monthly
        ? 12 - start.month + 1
        : (start.month <= 6 ? 2 : 1);
    if (monthly && years == 1) firstUnits = total;

    final out = <AfaEntry>[];
    var units = 0;
    var done = 0;
    var year = start.year;
    final disposed = asset.disposedOn;
    while (done < cost) {
      var step = year == start.year ? firstUnits : perYear;
      if (disposed != null && year == disposed.year) {
        // Jahr des Ausscheidens: DE AfA bis einschließlich Monat des
        // Ausscheidens (R 7.4 Abs 8 EStR), AT keine Jahres-AfA – der
        // Restbuchwert geht als Ganzes ab (P-S59).
        step = monthly
            ? (year == start.year
                  ? disposed.month - start.month + 1
                  : disposed.month)
            : 0;
        if (monthly && years == 1 && year == start.year) step = total;
      }
      units = (units + step).clamp(0, total);
      final cum = cost * units ~/ total;
      if (cum > done) {
        out.add(
          AfaEntry(DateTime(year, 12, 31), Money(cum - done), AfaKind.regular),
        );
        done = cum;
      }
      if (disposed != null && year == disposed.year) {
        if (done < cost) {
          out.add(AfaEntry(disposed, Money(cost - done), AfaKind.disposal));
        }
        // Planmäßige AfA im Ausscheidensjahr am Tag des Ausscheidens.
        for (var i = 0; i < out.length; i++) {
          final e = out[i];
          if (e.kind == AfaKind.regular && e.bookedOn.year == disposed.year) {
            out[i] = AfaEntry(disposed, e.amount, e.kind);
          }
        }
        break;
      }
      year++;
    }
    return out;
  }

  /// Anlagenverzeichnis-Zeilen je Jahr bis einschließlich [untilYear].
  static List<AfaYear> plan(
    FixedAsset asset,
    DepreciationRules rules, {
    int? untilYear,
  }) {
    final all = entries(asset, rules);
    if (all.isEmpty) return const [];
    final last = all.last.bookedOn.year;
    final end = untilYear == null || untilYear > last ? last : untilYear;
    final out = <AfaYear>[];
    var book = asset.cost;
    for (var y = asset.acquiredOn.year; y <= end; y++) {
      var afa = const Money.zero();
      var disp = const Money.zero();
      for (final e in all) {
        if (e.bookedOn.year != y) continue;
        if (e.kind == AfaKind.disposal) {
          disp += e.amount;
        } else {
          afa += e.amount;
        }
      }
      final row = AfaYear(
        year: y,
        opening: book,
        afa: afa,
        disposalValue: disp,
      );
      out.add(row);
      book = row.closing;
    }
    return out;
  }

  /// Summe der Abschreibungen aller [assets] mit Buchungstag in [from]–[to].
  static Money between(
    Iterable<FixedAsset> assets,
    DepreciationRules rules,
    DateTime from,
    DateTime to,
  ) {
    var sum = const Money.zero();
    final f = DateTime(from.year, from.month, from.day);
    final t = DateTime(to.year, to.month, to.day);
    for (final a in assets) {
      for (final e in entries(a, rules)) {
        if (!e.bookedOn.isBefore(f) && !e.bookedOn.isAfter(t)) {
          sum += e.amount;
        }
      }
    }
    return sum;
  }

  /// Buchwert am Stichtag [on] (nach allen Buchungen bis einschließlich).
  static Money bookValue(
    FixedAsset asset,
    DepreciationRules rules,
    DateTime on,
  ) {
    if (asset.acquiredOn.isAfter(on)) return const Money.zero();
    var value = asset.cost;
    for (final e in entries(asset, rules)) {
      if (!e.bookedOn.isAfter(on)) value -= e.amount;
    }
    return value;
  }

  /// Vorschlag der Abschreibungsart nach Betrag (FA-15.2).
  static DepreciationMethod suggestMethod(
    Money cost,
    Money netCost,
    DepreciationRules rules,
  ) {
    final measured = rules.gwgLimitIsNet ? netCost : cost;
    if (measured <= rules.gwgLimit) return DepreciationMethod.gwg;
    return DepreciationMethod.linear;
  }

  /// Liegt die Ausgabe über der GWG-Grenze, muss sie aktiviert und ins
  /// Anlagenverzeichnis (FA-13.2: Hinweis ohne Pro auf Ausgabebelegen).
  static bool exceedsGwg(Money cost, Money netCost, DepreciationRules rules) =>
      (rules.gwgLimitIsNet ? netCost : cost) > rules.gwgLimit;

  /// Fehlermeldung, wenn die Wahl unzulässig ist, sonst `null`.
  static String? validate(
    FixedAsset asset,
    Money netCost,
    DepreciationRules rules,
  ) {
    final measured = rules.gwgLimitIsNet ? netCost : asset.cost;
    if (asset.method == DepreciationMethod.gwg && measured > rules.gwgLimit) {
      return 'Sofort abschreiben geht nur bis ${_euro(rules.gwgLimit)} '
          '(${rules.gwgLegalRef}).';
    }
    if (asset.method == DepreciationMethod.pool) {
      final range = rules.poolRange;
      if (range == null) return 'Einen Sammelposten gibt es hier nicht.';
      if (netCost < range.$1 || netCost > range.$2) {
        return 'Sammelposten nur von ${_euro(range.$1)} bis '
            '${_euro(range.$2)} netto (§ 6 Abs 2a EStG).';
      }
    }
    final cls = rules.classFor(asset.categoryKey);
    if (asset.method == DepreciationMethod.linear &&
        cls.minYears != null &&
        asset.usefulLifeYears < cls.minYears!) {
      return 'Mindestens ${cls.minYears} Jahre (${cls.legalRef}).';
    }
    if (asset.usefulLifeYears < 1 || asset.usefulLifeYears > 50) {
      return 'Nutzungsdauer 1 bis 50 Jahre.';
    }
    return null;
  }

  static String _euro(Money m) {
    final e = m.cents ~/ 100;
    final c = m.cents % 100;
    final euros = e.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (x) => '${x[1]}.',
    );
    return c == 0 ? '$euros €' : '$euros,${c.toString().padLeft(2, '0')} €';
  }
}
