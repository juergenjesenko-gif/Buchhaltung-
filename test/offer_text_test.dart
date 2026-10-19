import 'package:buchhaltung/services/licensing/offer_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const trial = OfferPhase(
    price: 'Kostenlos',
    free: true,
    unit: PeriodUnit.day,
    periodCount: 14,
    cycles: 1,
  );
  const introMonth = OfferPhase(
    price: '6,90 €',
    free: false,
    unit: PeriodUnit.month,
    cycles: 12,
  );
  const baseMonth = OfferPhase(
    price: '12,90 €',
    free: false,
    unit: PeriodUnit.month,
  );

  group('FA-13.15 Preistext aus Store-Phasen', () {
    test('Test, Einführungspreis, Grundpreis', () {
      expect(
        OfferText.summary([trial, introMonth, baseMonth]),
        '14 Tage gratis, dann 6,90 €/Monat im ersten Jahr, danach '
        '12,90 €/Monat. Verlängert sich automatisch, jederzeit im Store '
        'kündbar.',
      );
      expect(
        OfferText.priceLine([trial, introMonth, baseMonth], 'x'),
        '6,90 €/Monat im ersten Jahr, danach 12,90 €/Monat',
      );
    });

    test('Jahresabo: ein Zyklus P1Y heißt „im ersten Jahr“', () {
      const intro = OfferPhase(
        price: '69,00 €',
        free: false,
        unit: PeriodUnit.year,
        cycles: 1,
      );
      const base = OfferPhase(
        price: '129,00 €',
        free: false,
        unit: PeriodUnit.year,
      );
      expect(
        OfferText.priceLine([intro, base], 'x'),
        '69,00 €/Jahr im ersten Jahr, danach 129,00 €/Jahr',
      );
    });

    test('Apple „Pay up front“ nennt den Einmalpreis', () {
      const intro = OfferPhase(
        price: '55,20 €',
        free: false,
        unit: PeriodUnit.year,
        cycles: 1,
        upFront: true,
      );
      const base = OfferPhase(
        price: '129,00 €',
        free: false,
        unit: PeriodUnit.year,
      );
      expect(
        OfferText.priceLine([intro, base], 'x'),
        '55,20 € im ersten Jahr, danach 129,00 €/Jahr',
      );
    });

    test('nur Test; Wochen werden Tage; kurze Einführung', () {
      const weeks = OfferPhase(
        price: '',
        free: true,
        unit: PeriodUnit.week,
        periodCount: 2,
        cycles: 1,
      );
      expect(
        OfferText.summary([weeks, baseMonth]),
        startsWith('14 Tage gratis, danach 12,90 €/Monat.'),
      );
      const three = OfferPhase(
        price: '6,90 €',
        free: false,
        unit: PeriodUnit.month,
        cycles: 3,
      );
      expect(
        OfferText.priceLine([three, baseMonth], 'x'),
        '6,90 €/Monat für 3 Monate, danach 12,90 €/Monat',
      );
    });

    test('ohne Phasen: Ersatztext bzw. null', () {
      expect(
        OfferText.priceLine(const [], '12,90 € pro Monat'),
        '12,90 € pro Monat',
      );
      expect(OfferText.summary(const []), isNull);
      expect(OfferText.summary(const [trial]), isNull);
    });

    test('ISO-Dauer von Google und Apple-Dezimalpreis', () {
      expect(OfferPhase.parseIso('P14D'), (count: 14, unit: PeriodUnit.day));
      expect(OfferPhase.parseIso('P1Y'), (count: 1, unit: PeriodUnit.year));
      expect(OfferPhase.parseIso('X'), isNull);
      expect(OfferText.decimalPrice('6.9', '€'), '6,90 €');
      expect(OfferText.decimalPrice('69', '€'), '69,00 €');
      expect(OfferText.decimalPrice('103.20', '€'), '103,20 €');
    });

    test('20-%-Code', () {
      expect(DiscountPromo.matches(' jenibucht20 '), isTrue);
      expect(DiscountPromo.matches('JENIBUCHT2M'), isFalse);
      expect(DiscountPromo.matches('jenibucht20pro'), isTrue);
    });

    test('iOS (O-45): 14 Tage gratis, danach Grundpreis ohne Jahrespreis', () {
      const phases = [
        OfferPhase(
          price: '0,00 €',
          free: true,
          unit: PeriodUnit.day,
          periodCount: 14,
          cycles: 1,
        ),
        OfferPhase(price: '12,90 €', free: false, unit: PeriodUnit.month),
      ];
      expect(OfferText.priceLine(phases, 'x'), '12,90 €/Monat');
      expect(
        OfferText.summary(phases),
        '14 Tage gratis, danach 12,90 €/Monat. Verlängert sich automatisch, '
        'jederzeit im Store kündbar.',
      );
    });
  });
}
