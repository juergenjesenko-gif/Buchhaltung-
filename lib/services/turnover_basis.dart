import '../domain/money.dart';

/// Umsatz eines Kalenderjahres als Grundlage der Kleinunternehmer-Überwachung,
/// zusammen mit der Aussage, ob er vollständig ist.
class YearTurnover {
  const YearTurnover({
    required this.amount,
    required this.isComplete,
    this.opening,
    this.backfilled = const Money.zero(),
    this.estimatedRest = const Money.zero(),
    this.confirmedComplete = false,
  });

  final Money amount;

  /// `false`, wenn die App das Jahr nicht vollständig kennt: die Erfassung hat
  /// nach dem 1. Jänner begonnen und für den Zeitraum davor fehlt ein
  /// Eröffnungswert. Ein unvollständiger Umsatz darf nie zu einer Entwarnung
  /// führen.
  final bool isComplete;

  /// Eröffnungswert (geschätzter Umsatz vor App-Start), `null` wenn keiner
  /// zählt (nicht erfasst oder Jahr voll erfasst).
  final Money? opening;

  /// Nachgetragene Einnahmen des Jahres mit Datum vor dem Erfassungsbeginn
  /// (FA-4.16).
  final Money backfilled;

  /// Teil des Eröffnungswerts, der noch als Schätzung in [amount] steckt:
  /// `max(0, opening − backfilled)`, 0 nach Bestätigung „vollständig“.
  final Money estimatedRest;

  /// Die Anwenderin hat bestätigt, dass alle Rechnungen vor dem App-Start
  /// nachgetragen sind; die Schätzung zählt dann nicht mehr.
  final bool confirmedComplete;
}

/// Setzt den Jahresumsatz aus erfassten Belegen und Eröffnungswerten zusammen.
///
/// Hintergrund (Lastenheft L-16.1, L-16.2, L-16.11, O-19): Wer die App mitten
/// im Jahr beginnt, hat für die Zeit davor keine Belege. Früher wurde dieser
/// Zeitraum stillschweigend als null gezählt – und die Grenzwertampel stand auf
/// Grün, obwohl die Kleinunternehmergrenze längst überschritten sein konnte.
///
/// Nachtragen (FA-4.16): Trägt die Anwenderin Einnahmen mit Datum vor dem
/// Erfassungsbeginn nach, ersetzen sie die Schätzung Euro für Euro. Ohne diese
/// Verrechnung zählten sie doppelt (Beleg + Eröffnungswert).
class TurnoverBasis {
  const TurnoverBasis._();

  /// [fromReceipts] ist die Summe aller in der App erfassten Einnahmen des
  /// Jahres, auch der nachgetragenen. [backfilled] ist davon der Teil mit
  /// Datum vor [trackingStart]. [opening] ist der vom Nutzer erfasste Umsatz
  /// des Jahres *vor* Beginn der Erfassung, `null` wenn nicht erfasst.
  /// [trackingStart] ist der Tag, ab dem die App die Buchhaltung führt, `null`
  /// wenn unbekannt. [confirmedComplete]: alle Rechnungen vor dem App-Start
  /// sind nachgetragen, die Schätzung entfällt.
  static YearTurnover forYear({
    required int year,
    required Money fromReceipts,
    required Money? opening,
    required DateTime? trackingStart,
    Money backfilled = const Money.zero(),
    bool confirmedComplete = false,
  }) {
    final firstDay = DateTime(year, 1, 1);
    final trackedFullYear =
        trackingStart != null && !_dayOf(trackingStart).isAfter(firstDay);

    // Hat die App das ganze Jahr mitgezählt, sind die Belege die Wahrheit.
    // Ein dennoch vorhandener Eröffnungswert würde den Umsatz doppelt zählen.
    if (trackedFullYear) {
      return YearTurnover(amount: fromReceipts, isComplete: true);
    }

    final rest = estimatedRest(
      opening: opening,
      backfilled: backfilled,
      confirmedComplete: confirmedComplete,
    );
    return YearTurnover(
      amount: fromReceipts + rest,
      isComplete: opening != null || confirmedComplete,
      opening: opening,
      backfilled: backfilled,
      estimatedRest: rest,
      confirmedComplete: confirmedComplete,
    );
  }

  /// Noch geschätzter Rest: `max(0, opening − backfilled)`; 0 ohne
  /// Eröffnungswert oder nach Bestätigung „vollständig“.
  static Money estimatedRest({
    required Money? opening,
    required Money backfilled,
    required bool confirmedComplete,
  }) {
    if (opening == null || confirmedComplete) return const Money.zero();
    final rest = opening - backfilled;
    return rest.isNegative ? const Money.zero() : rest;
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

/// Stand des Nachtragens über alle Jahre vor dem App-Start (FA-4.16), für die
/// Karte auf der Übersicht.
class BackfillStatus {
  const BackfillStatus({
    required this.trackingStart,
    required this.years,
    this.currentYearRest = const Money.zero(),
  });

  /// Aus den Jahresumsätzen ableiten; das erste ist das laufende Jahr.
  factory BackfillStatus.of({
    required DateTime? trackingStart,
    required List<YearTurnover> years,
  }) => BackfillStatus(
    trackingStart: trackingStart,
    years: [
      for (final y in years)
        if (y.opening != null) y,
    ],
    currentYearRest: years.isEmpty
        ? const Money.zero()
        : years.first.estimatedRest,
  );

  final DateTime? trackingStart;

  /// Geschätzter Rest, der im Umsatz des laufenden Jahres steckt („davon
  /// € X geschätzt vor App-Start“).
  final Money currentYearRest;

  /// Jahre mit Eröffnungswert.
  final List<YearTurnover> years;

  Money get estimate =>
      years.fold(const Money.zero(), (sum, y) => sum + y.opening!);

  Money get backfilled =>
      years.fold(const Money.zero(), (sum, y) => sum + y.backfilled);

  Money get rest =>
      years.fold(const Money.zero(), (sum, y) => sum + y.estimatedRest);

  bool get confirmed =>
      years.isNotEmpty && years.every((y) => y.confirmedComplete);

  /// Knopf „Rechnungen vor dem App-Start nachtragen“.
  bool get canBackfill => trackingStart != null && !rest.isZero && !confirmed;

  /// Frage „Sind alle Rechnungen … erfasst?“: es wurde schon etwas
  /// nachgetragen, die Schätzung ist aber noch nicht ersetzt.
  bool get asksComplete => canBackfill && !backfilled.isZero;

  /// Hinweis „Schätzung ersetzt durch nachgetragene Rechnungen“.
  bool get replacedByBackfill =>
      years.isNotEmpty && !confirmed && !backfilled.isZero && rest.isZero;
}
