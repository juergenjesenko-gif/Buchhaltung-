/// Wirtschaftsjahr der Gewinnermittlung (Lastenheft L-24).
///
/// Das Wirtschaftsjahr beginnt am Ersten des Monats [startMonth] und dauert
/// zwölf Monate. Es wird nach dem Kalenderjahr bezeichnet, in dem es endet:
/// AT § 2 Abs 5 EStG 1988, DE § 4a Abs 2 Nr 2 EStG.
///
/// Gilt nur für die Gewinnermittlung (Kassabuch-Jahr, Einnahmen-Ausgaben-
/// Rechnung, Exporte). Umsatzsteuer, Voranmeldung und Kleinunternehmergrenze
/// bleiben immer beim Kalenderjahr (AT § 20 Abs 1 UStG 1994, DE § 16 Abs 1
/// UStG; Kleinunternehmer AT § 6 Abs 1 Z 27 UStG, DE § 19 Abs 1 UStG).
class FiscalYear {
  const FiscalYear(this.startMonth)
    : assert(startMonth >= 1 && startMonth <= 12);

  /// 1 = Jänner = Kalenderjahr.
  final int startMonth;

  bool get isCalendarYear => startMonth == 1;

  /// Kalenderjahr, in dem das Wirtschaftsjahr endet, das [date] enthält.
  int yearOf(DateTime date) =>
      isCalendarYear || date.month < startMonth ? date.year : date.year + 1;

  /// Erster Tag des Wirtschaftsjahres, das im Kalenderjahr [endYear] endet.
  DateTime startOf(int endYear) =>
      DateTime(isCalendarYear ? endYear : endYear - 1, startMonth, 1);

  /// Letzter Tag des Wirtschaftsjahres, das im Kalenderjahr [endYear] endet.
  DateTime endOf(int endYear) =>
      DateTime(startOf(endYear).year, startMonth + 12, 0);

  /// Erster und letzter Tag des Wirtschaftsjahres, das [date] enthält.
  ({DateTime from, DateTime to, int year}) periodFor(DateTime date) {
    final year = yearOf(date);
    return (from: startOf(year), to: endOf(year), year: year);
  }

  /// „2026“ beim Kalenderjahr, sonst „April 2026 – März 2027“.
  /// [monthNames] aus dem `TaxProfile` (AT „Jänner“, DE „Januar“).
  String label(int endYear, List<String> monthNames) {
    if (isCalendarYear) return '$endYear';
    final from = startOf(endYear);
    final to = endOf(endYear);
    return '${monthNames[from.month - 1]} ${from.year} – '
        '${monthNames[to.month - 1]} ${to.year}';
  }

  /// Kurzform für Auswahlchips: „WJ 2027“ bzw. „2026“.
  String shortLabel(int endYear) => isCalendarYear ? '$endYear' : 'WJ $endYear';
}
