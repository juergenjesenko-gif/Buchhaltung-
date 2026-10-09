import '../domain/money.dart';

/// Umsatz eines Kalenderjahres als Grundlage der Kleinunternehmer-Überwachung,
/// zusammen mit der Aussage, ob er vollständig ist.
class YearTurnover {
  const YearTurnover({required this.amount, required this.isComplete});

  final Money amount;

  /// `false`, wenn die App das Jahr nicht vollständig kennt: die Erfassung hat
  /// nach dem 1. Jänner begonnen und für den Zeitraum davor fehlt ein
  /// Eröffnungswert. Ein unvollständiger Umsatz darf nie zu einer Entwarnung
  /// führen.
  final bool isComplete;
}

/// Setzt den Jahresumsatz aus erfassten Belegen und Eröffnungswerten zusammen.
///
/// Hintergrund (Lastenheft L-16.1, L-16.2, L-16.11, O-19): Wer die App mitten
/// im Jahr beginnt, hat für die Zeit davor keine Belege. Früher wurde dieser
/// Zeitraum stillschweigend als null gezählt – und die Grenzwertampel stand auf
/// Grün, obwohl die Kleinunternehmergrenze längst überschritten sein konnte.
class TurnoverBasis {
  const TurnoverBasis._();

  /// [fromReceipts] ist die Summe der in der App erfassten Einnahmen des Jahres.
  /// [opening] ist der vom Nutzer erfasste Umsatz des Jahres *vor* Beginn der
  /// Erfassung, `null` wenn nicht erfasst. [trackingStart] ist der Tag, ab dem
  /// die App die Buchhaltung führt, `null` wenn unbekannt.
  static YearTurnover forYear({
    required int year,
    required Money fromReceipts,
    required Money? opening,
    required DateTime? trackingStart,
  }) {
    final firstDay = DateTime(year, 1, 1);
    final trackedFullYear =
        trackingStart != null && !_dayOf(trackingStart).isAfter(firstDay);

    // Hat die App das ganze Jahr mitgezählt, sind die Belege die Wahrheit.
    // Ein dennoch vorhandener Eröffnungswert würde den Umsatz doppelt zählen.
    if (trackedFullYear) {
      return YearTurnover(amount: fromReceipts, isComplete: true);
    }

    return YearTurnover(
      amount: fromReceipts + (opening ?? const Money.zero()),
      isComplete: opening != null,
    );
  }

  /// Braucht dieses Jahr einen Eröffnungswert, damit es vollständig ist?
  static bool needsOpening({
    required int year,
    required DateTime? trackingStart,
  }) =>
      trackingStart == null ||
      _dayOf(trackingStart).isAfter(DateTime(year, 1, 1));

  static DateTime _dayOf(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
