import 'package:buchhaltung/domain/company_profile.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/deadline_rule.dart';
import 'package:buchhaltung/domain/holidays.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/services/deadline_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const at = CompanyProfile(companyName: 'A', country: Country.at);
  const de = CompanyProfile(companyName: 'D', country: Country.de);

  DateTime dateOf(List<Deadline> list, String label) =>
      list.firstWhere((d) => d.label == label).date;

  group('Feiertage', () {
    test('Ostersonntag', () {
      expect(HolidayCalendar.easterSunday(2026), DateTime(2026, 4, 5));
      expect(HolidayCalendar.easterSunday(2027), DateTime(2027, 3, 28));
    });

    test('AT: Karfreitag und 24.12. zählen nach § 108 Abs 3 BAO nicht', () {
      const c = HolidayCalendar.austria;
      expect(c.isHoliday(DateTime(2026, 4, 3)), isTrue);
      expect(c.isHoliday(DateTime(2026, 12, 24)), isTrue);
      expect(c.isHoliday(DateTime(2026, 10, 26)), isTrue);
    });

    test('DE: Landesfeiertag nur im gewählten Bundesland', () {
      const c = HolidayCalendar.germany;
      expect(
        c.nextWorkday(DateTime(2027, 10, 31), state: 'NW'),
        DateTime(2027, 11, 2),
      );
      expect(
        c.nextWorkday(DateTime(2027, 10, 31), state: 'BE'),
        DateTime(2027, 11, 1),
      );
      expect(c.nextWorkday(DateTime(2027, 10, 31)), DateTime(2027, 11, 1));
      expect(c.isHoliday(DateTime(2026, 11, 18), state: 'SN'), isTrue);
    });
  });

  group('Österreich', () {
    test('ESt-Vorauszahlungen verschoben auf den nächsten Werktag', () {
      final list = DeadlineCalculator.forYear(
        profile: at,
        year: 2026,
        interval: VatReturnInterval.quarterly,
      );
      expect(dateOf(list, 'ESt-Vorauszahlung Q1/2026'), DateTime(2026, 2, 16));
      expect(dateOf(list, 'ESt-Vorauszahlung Q2/2026'), DateTime(2026, 5, 15));
      expect(dateOf(list, 'ESt-Vorauszahlung Q3/2026'), DateTime(2026, 8, 17));
      expect(dateOf(list, 'ESt-Vorauszahlung Q4/2026'), DateTime(2026, 11, 16));
      expect(
        dateOf(list, 'ESt-/USt-Erklärung (FinanzOnline) 2026'),
        DateTime(2027, 6, 30),
      );
    });

    test('Kleinunternehmerin: keine UVA, SVS als „ca.“', () {
      final list = DeadlineCalculator.forYear(
        profile: at,
        year: 2026,
        interval: VatReturnInterval.quarterly,
      );
      expect(list.where((d) => d.label.startsWith('UVA')), isEmpty);
      final svs = list.firstWhere((d) => d.label == 'SVS-Beitrag Q4/2026');
      expect(svs.date, DateTime(2026, 11, 30));
      expect(svs.approximate, isTrue);
    });

    test('UVA: 15. des zweitfolgenden Monats', () {
      final regular = at.copyWith(isSmallBusiness: false);
      final quarterly = DeadlineCalculator.forYear(
        profile: regular,
        year: 2026,
        interval: VatReturnInterval.quarterly,
      );
      expect(dateOf(quarterly, 'UVA Q3/2026'), DateTime(2026, 11, 16));
      final monthly = DeadlineCalculator.forYear(
        profile: regular,
        year: 2026,
        interval: VatReturnInterval.monthly,
      );
      expect(dateOf(monthly, 'UVA Oktober 2026'), DateTime(2026, 12, 15));
    });

    test('nächste vier Termine ab 14.10.2026', () {
      final overview = DeadlineCalculator.upcoming(
        profile: at,
        today: DateTime(2026, 10, 14),
        interval: VatReturnInterval.quarterly,
      );
      expect(overview.upcoming.map((d) => d.date), [
        DateTime(2026, 11, 16),
        DateTime(2026, 11, 30),
        DateTime(2027, 2, 15),
        DateTime(2027, 2, 28),
      ]);
      expect(overview.upcoming.first.daysFrom(DateTime(2026, 10, 14)), 33);
      expect(overview.advisorNote, isNull);
    });

    test('mit Steuerberatung: Erklärung „laut Kanzlei“', () {
      final overview = DeadlineCalculator.upcoming(
        profile: at.copyWith(hasTaxAdvisor: true),
        today: DateTime(2026, 10, 14),
        interval: VatReturnInterval.quarterly,
      );
      expect(overview.advisorNote, contains('laut Kanzlei'));
      expect(
        overview.upcoming.where((d) => d.label.contains('Erklärung')),
        isEmpty,
      );
    });

    test('Vorschlag Rhythmus aus Vorjahresumsatz (100.000 €)', () {
      expect(
        DeadlineCalculator.suggestInterval(
          TaxProfile.austria,
          previousYearTurnover: const Money(10000001),
        ),
        VatReturnInterval.monthly,
      );
      expect(
        DeadlineCalculator.suggestInterval(
          TaxProfile.austria,
          previousYearTurnover: const Money(10000000),
        ),
        VatReturnInterval.quarterly,
      );
      expect(
        DeadlineCalculator.suggestInterval(TaxProfile.austria),
        VatReturnInterval.quarterly,
      );
    });
  });

  group('Deutschland', () {
    test('Erklärung 2026 am 02.08.2027 (31.07. ist Samstag)', () {
      final list = DeadlineCalculator.forYear(
        profile: de,
        year: 2026,
        interval: VatReturnInterval.quarterly,
      );
      expect(dateOf(list, 'Steuererklärungen 2026'), DateTime(2027, 8, 2));
      expect(dateOf(list, 'ESt-Vorauszahlung Q1/2026'), DateTime(2026, 3, 10));
    });

    test('UStVA 10. nach Zeitraum, Dauerfristverlängerung +1 Monat', () {
      final regular = de.copyWith(isSmallBusiness: false);
      final plain = DeadlineCalculator.forYear(
        profile: regular,
        year: 2026,
        interval: VatReturnInterval.quarterly,
      );
      expect(dateOf(plain, 'UStVA Q3/2026'), DateTime(2026, 10, 12));
      final extended = DeadlineCalculator.forYear(
        profile: regular.copyWith(vatPermanentExtension: true),
        year: 2026,
        interval: VatReturnInterval.quarterly,
      );
      expect(dateOf(extended, 'UStVA Q3/2026'), DateTime(2026, 11, 10));
    });

    test('ZM am 25. nach Meldezeitraum, ohne Dauerfristverlängerung', () {
      final list = DeadlineCalculator.forYear(
        profile: de.copyWith(filesEcsl: true, vatPermanentExtension: true),
        year: 2026,
        interval: VatReturnInterval.quarterly,
      );
      expect(dateOf(list, 'ZM Q3/2026'), DateTime(2026, 10, 26));
    });

    test('keine SVS in Deutschland', () {
      final list = DeadlineCalculator.forYear(
        profile: de,
        year: 2026,
        interval: VatReturnInterval.quarterly,
      );
      expect(list.where((d) => d.label.startsWith('SVS')), isEmpty);
    });

    test('Vorschlag Rhythmus aus Vorjahressteuer (9.000 €)', () {
      expect(
        DeadlineCalculator.suggestInterval(
          TaxProfile.germany,
          previousYearVat: const Money(900001),
        ),
        VatReturnInterval.monthly,
      );
    });
  });
}
