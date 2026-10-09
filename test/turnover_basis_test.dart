import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/services/turnover_basis.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const receipts = Money(1000000); // 10.000 € aus erfassten Belegen

  group('forYear', () {
    test('Erfassung ab 1. Jänner: Belege sind vollständig', () {
      final result = TurnoverBasis.forYear(
        year: 2026,
        fromReceipts: receipts,
        opening: null,
        trackingStart: DateTime(2026, 1, 1),
      );
      expect(result.amount, receipts);
      expect(result.isComplete, isTrue);
    });

    test('Erfassung schon im Vorjahr begonnen: vollständig', () {
      final result = TurnoverBasis.forYear(
        year: 2026,
        fromReceipts: receipts,
        opening: null,
        trackingStart: DateTime(2025, 8, 17),
      );
      expect(result.isComplete, isTrue);
    });

    test('Einstieg im Oktober ohne Eröffnungswert: unvollständig', () {
      final result = TurnoverBasis.forYear(
        year: 2026,
        fromReceipts: receipts,
        opening: null,
        trackingStart: DateTime(2026, 10, 9),
      );
      expect(result.amount, receipts);
      expect(result.isComplete, isFalse);
    });

    test('Einstieg im Oktober mit Eröffnungswert: Summe, vollständig', () {
      final result = TurnoverBasis.forYear(
        year: 2026,
        fromReceipts: receipts,
        opening: const Money(2500000),
        trackingStart: DateTime(2026, 10, 9),
      );
      expect(result.amount, const Money(3500000));
      expect(result.isComplete, isTrue);
    });

    test('Vorjahr eines Neueinsteigers: nur der Eröffnungswert', () {
      final result = TurnoverBasis.forYear(
        year: 2025,
        fromReceipts: const Money.zero(),
        opening: const Money(3000000),
        trackingStart: DateTime(2026, 10, 9),
      );
      expect(result.amount, const Money(3000000));
      expect(result.isComplete, isTrue);
    });

    test('Eröffnungswert 0 € zählt als vollständige Angabe', () {
      final result = TurnoverBasis.forYear(
        year: 2025,
        fromReceipts: const Money.zero(),
        opening: const Money.zero(),
        trackingStart: DateTime(2026, 10, 9),
      );
      expect(result.isComplete, isTrue);
    });

    test('voll erfasstes Jahr ignoriert einen Eröffnungswert', () {
      // Sonst würde der Umsatz doppelt gezählt.
      final result = TurnoverBasis.forYear(
        year: 2026,
        fromReceipts: receipts,
        opening: const Money(500000),
        trackingStart: DateTime(2026, 1, 1),
      );
      expect(result.amount, receipts);
    });

    test(
      'unbekannter Erfassungsbeginn: nie vollständig ohne Eröffnungswert',
      () {
        final result = TurnoverBasis.forYear(
          year: 2026,
          fromReceipts: receipts,
          opening: null,
          trackingStart: null,
        );
        expect(result.isComplete, isFalse);
      },
    );

    test('Uhrzeit des Erfassungsbeginns spielt keine Rolle', () {
      final result = TurnoverBasis.forYear(
        year: 2026,
        fromReceipts: receipts,
        opening: null,
        trackingStart: DateTime(2026, 1, 1, 23, 59),
      );
      expect(result.isComplete, isTrue);
    });
  });

  group('needsOpening', () {
    test(
      'Einstieg im Oktober braucht Werte für Vorjahr und laufendes Jahr',
      () {
        final start = DateTime(2026, 10, 9);
        expect(
          TurnoverBasis.needsOpening(year: 2025, trackingStart: start),
          isTrue,
        );
        expect(
          TurnoverBasis.needsOpening(year: 2026, trackingStart: start),
          isTrue,
        );
      },
    );

    test('Einstieg am 1. Jänner braucht nur das Vorjahr', () {
      final start = DateTime(2026, 1, 1);
      expect(
        TurnoverBasis.needsOpening(year: 2025, trackingStart: start),
        isTrue,
      );
      expect(
        TurnoverBasis.needsOpening(year: 2026, trackingStart: start),
        isFalse,
      );
    });
  });
}
