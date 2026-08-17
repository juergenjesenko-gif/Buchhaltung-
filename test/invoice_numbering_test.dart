import 'package:buchhaltung/services/invoice_numbering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final date = DateTime(2026, 3, 7);

  group('format', () {
    test('füllt die laufende Nummer auf die Breite des Platzhalters auf', () {
      expect(
        InvoiceNumbering.format(
          pattern: 'RE-{YYYY}-{NNNN}',
          sequence: 7,
          date: date,
        ),
        'RE-2026-0007',
      );
      expect(
        InvoiceNumbering.format(pattern: '{NN}', sequence: 5, date: date),
        '05',
      );
    });

    test('ersetzt Jahr und Monat', () {
      expect(
        InvoiceNumbering.format(
          pattern: '{YYYY}{MM}-{NNN}',
          sequence: 12,
          date: date,
        ),
        '202603-012',
      );
      expect(
        InvoiceNumbering.format(pattern: '{YY}/{N}', sequence: 3, date: date),
        '26/3',
      );
    });

    test('verwechselt {N} nicht mit dem Anfang von {NNNN}', () {
      // Würde die kurze Gruppe zuerst ersetzt, käme "RE-1NNN" heraus.
      expect(
        InvoiceNumbering.format(pattern: 'RE-{NNNN}', sequence: 1, date: date),
        'RE-0001',
      );
    });

    test('schneidet eine zu große Nummer nicht ab', () {
      expect(
        InvoiceNumbering.format(pattern: '{NN}', sequence: 12345, date: date),
        '12345',
      );
    });

    test('kommt ohne Platzhalter für das Jahr aus', () {
      expect(
        InvoiceNumbering.format(pattern: 'A{NNNNNN}', sequence: 42, date: date),
        'A000042',
      );
    });
  });

  group('isValidPattern', () {
    test('verlangt eine laufende Nummer', () {
      expect(InvoiceNumbering.isValidPattern('RE-{YYYY}-{NNNN}'), isTrue);
      expect(InvoiceNumbering.isValidPattern('{N}'), isTrue);
      // Ohne laufende Nummer trüge jede Rechnung dieselbe Nummer.
      expect(InvoiceNumbering.isValidPattern('RE-{YYYY}'), isFalse);
      expect(InvoiceNumbering.isValidPattern('Rechnung'), isFalse);
      expect(InvoiceNumbering.isValidPattern(''), isFalse);
      expect(InvoiceNumbering.isValidPattern('   '), isFalse);
    });
  });

  group('preview', () {
    test('zeigt eine Beispielnummer', () {
      expect(
        InvoiceNumbering.preview('RE-{YYYY}-{NNNN}', date),
        'RE-2026-0001',
      );
    });

    test('meldet ein ungültiges Muster', () {
      expect(InvoiceNumbering.preview('RE-{YYYY}', date), 'Ungültiges Muster');
    });
  });
}
