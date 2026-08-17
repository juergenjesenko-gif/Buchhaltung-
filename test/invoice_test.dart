import 'package:buchhaltung/domain/invoice.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  InvoiceItem item({
    required int priceCents,
    int quantityMilli = 1000,
    int vatPermille = 200,
    String description = 'Leistung',
    int position = 1,
  }) => InvoiceItem(
    position: position,
    description: description,
    quantityMilli: quantityMilli,
    unitPrice: Money(priceCents),
    vatPermille: vatPermille,
  );

  Invoice invoice(List<InvoiceItem> items, {bool smallBusiness = false}) =>
      Invoice(
        number: 'RE-2026-0001',
        issueDate: DateTime(2026, 3, 1),
        customerId: 1,
        items: items,
        isSmallBusiness: smallBusiness,
      );

  group('InvoiceItem', () {
    test('rechnet Menge mal Einzelpreis', () {
      expect(
        item(priceCents: 5000, quantityMilli: 3000).net,
        const Money(15000),
      );
    });

    test('rechnet mit Teilmengen exakt', () {
      // 1,5 Stunden zu 80,00 € = 120,00 €
      expect(
        item(priceCents: 8000, quantityMilli: 1500).net,
        const Money(12000),
      );
      // 0,25 Stunden zu 99,99 € = 25,00 € (24,9975 kaufmännisch gerundet)
      expect(item(priceCents: 9999, quantityMilli: 250).net, const Money(2500));
    });

    test('rundet die Steuer je Position', () {
      final line = item(priceCents: 333, vatPermille: 200);
      expect(line.net, const Money(333));
      expect(line.vat, const Money(67));
      expect(line.gross, const Money(400));
    });

    test('meldet die Menge als Dezimalzahl', () {
      expect(item(priceCents: 100, quantityMilli: 1500).quantity, 1.5);
    });
  });

  group('Summen', () {
    test('summiert Netto, Steuer und Brutto', () {
      final result = invoice([
        item(priceCents: 10000, position: 1),
        item(priceCents: 5000, position: 2),
      ]);
      expect(result.netTotal, const Money(15000));
      expect(result.vatTotal, const Money(3000));
      expect(result.grossTotal, const Money(18000));
    });

    test('summiert über verschiedene Steuersätze', () {
      final result = invoice([
        item(priceCents: 10000, vatPermille: 200, position: 1),
        item(priceCents: 10000, vatPermille: 100, position: 2),
      ]);
      expect(result.netTotal, const Money(20000));
      expect(result.vatTotal, const Money(3000)); // 2000 + 1000
    });

    test(
      'die Summe der Positionssteuern entspricht der ausgewiesenen Steuer',
      () {
        // Wichtig für die Rechnung: der ausgewiesene Steuerbetrag muss die Summe
        // der Positionen sein, nicht eine separat gerundete Gesamtrechnung.
        final items = [
          for (var i = 1; i <= 7; i++) item(priceCents: 333, position: i),
        ];
        final result = invoice(items);
        final sumOfLines = items.map((line) => line.vat).sum;
        expect(result.vatTotal, sumOfLines);
        expect(result.grossTotal, result.netTotal + result.vatTotal);
      },
    );
  });

  group('Kleinunternehmer', () {
    test('weist keine Umsatzsteuer aus', () {
      final result = invoice([item(priceCents: 10000)], smallBusiness: true);
      expect(result.vatTotal, const Money.zero());
      expect(result.grossTotal, const Money(10000));
      expect(result.netTotal, const Money(10000));
    });

    test('zeigt die Aufteilung als einen steuerfreien Block', () {
      final result = invoice([item(priceCents: 10000)], smallBusiness: true);
      expect(result.vatBreakdown.keys, [0]);
      expect(result.vatBreakdown[0]!.vat, const Money.zero());
      expect(result.vatBreakdown[0]!.net, const Money(10000));
    });
  });

  group('vatBreakdown', () {
    test('gruppiert Positionen nach Steuersatz', () {
      final result = invoice([
        item(priceCents: 10000, vatPermille: 200, position: 1),
        item(priceCents: 5000, vatPermille: 200, position: 2),
        item(priceCents: 10000, vatPermille: 100, position: 3),
      ]);

      expect(result.vatBreakdown.length, 2);
      expect(result.vatBreakdown[200]!.net, const Money(15000));
      expect(result.vatBreakdown[200]!.vat, const Money(3000));
      expect(result.vatBreakdown[100]!.net, const Money(10000));
      expect(result.vatBreakdown[100]!.vat, const Money(1000));
    });
  });

  group('Status', () {
    test('nur Entwürfe sind änderbar', () {
      expect(InvoiceStatus.draft.isLocked, isFalse);
      expect(InvoiceStatus.issued.isLocked, isTrue);
      expect(InvoiceStatus.paid.isLocked, isTrue);
      expect(InvoiceStatus.cancelled.isLocked, isTrue);
    });

    test(
      'eine gestellte Rechnung mit vergangener Fälligkeit ist überfällig',
      () {
        final overdue = Invoice(
          number: 'RE-1',
          issueDate: DateTime(2026, 1, 1),
          dueDate: DateTime(2026, 1, 15),
          customerId: 1,
          items: const [],
          status: InvoiceStatus.issued,
        );
        expect(overdue.isOverdue, isTrue);
      },
    );

    test('ein Entwurf ist nie überfällig', () {
      final draft = Invoice(
        number: 'ENTWURF',
        issueDate: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 1, 15),
        customerId: 1,
        items: const [],
      );
      expect(draft.isOverdue, isFalse);
    });

    test('eine bezahlte Rechnung ist nicht überfällig', () {
      final paid = Invoice(
        number: 'RE-1',
        issueDate: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 1, 15),
        customerId: 1,
        items: const [],
        status: InvoiceStatus.paid,
      );
      expect(paid.isOverdue, isFalse);
    });
  });
}
