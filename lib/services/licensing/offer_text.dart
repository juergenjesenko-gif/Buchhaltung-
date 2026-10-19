/// Preisphasen eines Store-Angebots und der Text dazu für die Abo-Seite
/// (FA-13.15, Entscheidung Auftraggeber 2026-10-19, Lastenheft 14a).
///
/// Alle Preise kommen formatiert aus dem Store (Google `formattedPrice`,
/// Apple `introductoryPrice`), nie aus dem Code (L-22.7). Diese Datei setzt
/// sie nur zu einem Satz zusammen; reines Dart, damit es ohne Store testbar
/// ist.
library;

/// Einheit eines Abrechnungszeitraums.
enum PeriodUnit { day, week, month, year }

/// Eine Preisphase: Test (gratis), Einführungspreis oder Grundpreis.
class OfferPhase {
  const OfferPhase({
    required this.price,
    required this.free,
    required this.unit,
    this.periodCount = 1,
    this.cycles = 0,
    this.upFront = false,
  });

  /// Vom Store formatierter Preis je Zeitraum, z. B. „6,90 €“.
  final String price;

  /// Kostenlose Phase (Test oder Promo-Code).
  final bool free;

  final PeriodUnit unit;

  /// Länge eines Zeitraums in [unit], z. B. 14 bei `P14D`.
  final int periodCount;

  /// Anzahl der Zeiträume; 0 = unbegrenzt (Grundpreis).
  final int cycles;

  /// Apple „Pay up front“: [price] gilt einmal für die ganze Phase.
  final bool upFront;

  /// Gesamtlänge der Phase in Tagen bzw. Monaten (für Text „im ersten Jahr“).
  int get _total => periodCount * (cycles == 0 ? 1 : cycles);

  /// Liest eine ISO-8601-Dauer von Google Play (`P1M`, `P1Y`, `P2W`,
  /// `P14D`). Unbekannt → `null`.
  static ({int count, PeriodUnit unit})? parseIso(String iso) {
    final m = RegExp(r'^P(\d+)([DWMY])$').firstMatch(iso.trim());
    if (m == null) return null;
    final unit = switch (m.group(2)) {
      'D' => PeriodUnit.day,
      'W' => PeriodUnit.week,
      'M' => PeriodUnit.month,
      _ => PeriodUnit.year,
    };
    return (count: int.parse(m.group(1)!), unit: unit);
  }
}

/// Baut die Preistexte aus den Phasen. Befund Prüfinstanz Rechtsanwalt
/// (P-R58): Einführungspreis, späterer Preis, Abrechnungszeitraum,
/// automatische Verlängerung und Testende müssen gleich sichtbar sein
/// (§ 1 und § 3 PAngV, § 5a UWG, § 312j Abs 2 BGB).
abstract final class OfferText {
  /// Apple meldet den Einführungspreis als Dezimaltext („6.9“); daraus wird
  /// „6,90 €“. Ohne `double`, Geld bleibt Text bzw. ganzzahlig (Grundregel 1).
  static String decimalPrice(String decimal, String symbol) {
    final m = RegExp(r'^(\d+)(?:[.,](\d*))?$').firstMatch(decimal.trim());
    if (m == null) return '$decimal $symbol'.trim();
    final cents = '${m.group(2) ?? ''}00'.substring(0, 2);
    return '${m.group(1)},$cents $symbol'.trim();
  }

  static String _unitName(PeriodUnit u, int n) => switch (u) {
    PeriodUnit.day => n == 1 ? 'Tag' : 'Tage',
    PeriodUnit.week => n == 1 ? 'Woche' : 'Wochen',
    PeriodUnit.month => n == 1 ? 'Monat' : 'Monate',
    PeriodUnit.year => n == 1 ? 'Jahr' : 'Jahre',
  };

  /// „14 Tage“, „2 Monate“; Wochen werden zu Tagen (Google `P2W`).
  static String _length(PeriodUnit unit, int n) =>
      unit == PeriodUnit.week ? '${n * 7} Tage' : '$n ${_unitName(unit, n)}';

  static String _per(OfferPhase p) => p.periodCount == 1
      ? '${p.price}/${_unitName(p.unit, 1)}'
      : '${p.price} je ${_length(p.unit, p.periodCount)}';

  /// Dauer einer bezahlten Einführungsphase: genau 12 Monate oder 1 Jahr
  /// heißt „im ersten Jahr“.
  static String _during(OfferPhase p) {
    final months = switch (p.unit) {
      PeriodUnit.month => p._total,
      PeriodUnit.year => p._total * 12,
      _ => null,
    };
    if (months == 12) return 'im ersten Jahr';
    return 'für ${_length(p.unit, p._total)}';
  }

  static OfferPhase? _base(List<OfferPhase> phases) =>
      phases.isEmpty || phases.last.cycles != 0 ? null : phases.last;

  /// Kurzer Preis für die Kopfzeile, z. B. „6,90 €/Monat im ersten Jahr,
  /// danach 12,90 €/Monat“. Ohne Phasen [fallback] („12,90 € pro Monat“).
  static String priceLine(List<OfferPhase> phases, String fallback) {
    final base = _base(phases);
    if (base == null) return fallback;
    final intro = [
      for (final p in phases)
        if (!p.free && !identical(p, base)) p,
    ];
    if (intro.isEmpty) return _per(base);
    final i = intro.first;
    final first = i.upFront
        ? '${i.price} ${_during(i)}'
        : '${_per(i)} ${_during(i)}';
    return '$first, danach ${_per(base)}';
  }

  /// Ganzer Satz, z. B. „14 Tage gratis, dann 6,90 €/Monat im ersten Jahr,
  /// danach 12,90 €/Monat. Verlängert sich automatisch, jederzeit im Store
  /// kündbar.“ `null`, wenn der Store keine Phasen geliefert hat – dann gilt
  /// der bisherige Text mit dem Grundpreis.
  static String? summary(List<OfferPhase> phases) {
    final base = _base(phases);
    if (base == null) return null;
    final parts = <String>[];
    for (final p in phases) {
      if (identical(p, base)) continue;
      if (p.free) {
        parts.add('${_length(p.unit, p._total)} gratis');
      } else {
        parts.add(
          p.upFront ? '${p.price} ${_during(p)}' : '${_per(p)} ${_during(p)}',
        );
      }
    }
    final buf = StringBuffer();
    if (parts.isEmpty) {
      buf.write(_per(base));
    } else {
      buf.write(parts.first);
      for (final p in parts.skip(1)) {
        buf.write(', dann $p');
      }
      buf.write(', danach ${_per(base)}');
    }
    buf.write('. Verlängert sich automatisch, jederzeit im Store kündbar.');
    return buf.toString();
  }
}

/// Zweiter Instagram-Code (Entscheidung Auftraggeber 2026-10-19, O-46;
/// läuft parallel zu `JENIBUCHT2M`, Instagram bewirbt [proCode]):
/// 20 % auf das Jahresabo im ersten Jahr. Apple: Angebotscode
/// (benutzerdefiniert, „Pay up front“ 1 Jahr), je Produkt ein Code:
/// [code] auf `basis_jahr`, [proCode] auf `pro_jahr`. Google Play kennt für Abos
/// nur Promo-Codes mit Gratisphase; der Rabatt läuft dort als vom Entwickler
/// bestimmtes Angebot mit dem Tag [androidOfferTag], das die App erst nach
/// Eingabe des Codes anzeigt (ohne Server, also nicht geheim; P-R59).
abstract final class DiscountPromo {
  static const code = 'JENIBUCHT20';
  static const proCode = 'JENIBUCHT20PRO';
  static const percent = 20;
  static const androidOfferTag = 'jenibucht20';

  /// Android: beide Codes schalten dasselbe Angebots-Tag frei.
  static bool matches(String input) {
    final c = input.trim().toUpperCase();
    return c == code || c == proCode;
  }
}
