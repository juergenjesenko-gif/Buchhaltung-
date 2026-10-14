import 'package:buchhaltung/core/formatting.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/fiscal_year.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final names = TaxProfile.austria.monthNames;

  test('Kalenderjahr: Jahr = Kalenderjahr', () {
    const fy = FiscalYear(1);
    final p = fy.periodFor(DateTime(2026, 10, 14));
    expect(p.from, DateTime(2026, 1, 1));
    expect(p.to, DateTime(2026, 12, 31));
    expect(fy.label(2026, names), '2026');
  });

  test('April bis März, benannt nach dem Endjahr (§ 2 Abs 5 EStG)', () {
    const fy = FiscalYear(4);
    final p = fy.periodFor(DateTime(2026, 10, 14));
    expect(p.year, 2027);
    expect(p.from, DateTime(2026, 4, 1));
    expect(p.to, DateTime(2027, 3, 31));
    expect(fy.yearOf(DateTime(2026, 3, 31)), 2026);
    expect(fy.label(2027, names), 'April 2026 – März 2027');
    expect(
      fy.label(2027, TaxProfile.germany.monthNames),
      'April 2026 – März 2027',
    );
    expect(FiscalYear(2).label(2027, names), 'Februar 2026 – Jänner 2027');
    expect(
      FiscalYear(2).label(2027, TaxProfile.germany.monthNames),
      'Februar 2026 – Januar 2027',
    );
  });

  test('Period.fiscalYear liefert die Grenzen für Auswertung und Export', () {
    final p = Period.fiscalYear(const FiscalYear(7), 2027, names);
    expect(p.from, DateTime(2026, 7, 1));
    expect(p.to, DateTime(2027, 6, 30));
  });
}
