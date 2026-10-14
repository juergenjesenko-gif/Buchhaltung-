import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/dunning.dart';
import 'package:buchhaltung/domain/invoice.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/services/dunning_calculator.dart';
import 'package:buchhaltung/services/dunning_service.dart';
import 'package:buchhaltung/services/invoice_texts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Gerätetest 0.6.0: neue Frist nach Erinnerung/Mahnung, Symbol mit Stufe,
/// Sie-Form in Kundendokumenten, Erinnerung kostenlos vorbelegt.
void main() {
  setUpAll(() => initializeDateFormatting('de'));

  final invoice = Invoice(
    id: 1,
    number: 'RE-2026-0002',
    issueDate: DateTime(2026, 9, 1),
    dueDate: DateTime(2026, 9, 15),
    customerId: 1,
    status: InvoiceStatus.issued,
    isSmallBusiness: true,
    items: [
      InvoiceItem(
        position: 1,
        description: 'Beratung',
        quantityMilli: 1000,
        unitPrice: const Money(180000),
        vatPermille: 0,
      ),
    ],
  );

  DunningNotice notice({int level = 1, DateTime? cancelledAt}) => DunningNotice(
    invoiceId: 1,
    level: level,
    issuedOn: DateTime(2026, 10, 1),
    newDueDate: DateTime(2026, 10, 15),
    principal: const Money(180000),
    fee: const Money.zero(),
    feesTotal: const Money.zero(),
    interest: const Money.zero(),
    interestRateBp: 0,
    flatFee: const Money.zero(),
    text: '',
    cancelledAt: cancelledAt,
  );

  group('neue Frist', () {
    test('ohne Schreiben zählt die Fälligkeit der Rechnung', () {
      expect(
        DunningService.needsReminder(invoice, null, DateTime(2026, 9, 15)),
        isFalse,
      );
      expect(
        DunningService.needsReminder(invoice, null, DateTime(2026, 9, 16)),
        isTrue,
      );
    });

    test('nach der Erinnerung erst wieder nach deren Frist', () {
      final n = notice();
      expect(
        DunningService.effectiveDueDate(invoice, n),
        DateTime(2026, 10, 15),
      );
      expect(
        DunningService.needsReminder(invoice, n, DateTime(2026, 10, 15, 18)),
        isFalse,
      );
      expect(
        DunningService.needsReminder(invoice, n, DateTime(2026, 10, 16)),
        isTrue,
      );
    });

    test('storniertes Schreiben setzt keine Frist', () {
      final n = notice(cancelledAt: DateTime(2026, 10, 2));
      expect(DunningService.effectiveDueDate(invoice, n), invoice.dueDate);
    });

    test('bezahlte Rechnung braucht keine Erinnerung', () {
      expect(
        DunningService.needsReminder(
          invoice.copyWith(status: InvoiceStatus.paid),
          null,
          DateTime(2027),
        ),
        isFalse,
      );
    });

    test('Frist steht im Schreiben', () {
      final draft = DunningService.compose(
        invoice: invoice,
        previous: const [],
        rules: TaxProfile.austria.dunning,
        business: false,
        issuedOn: DateTime(2026, 10, 1),
        newDueDate: DateTime(2026, 10, 15),
        fee: const Money.zero(),
        withInterest: false,
        withFlatFee: false,
      );
      expect(draft.notice.text, contains('15.10.2026'));
    });
  });

  test('Symbol: Erinnert, 1. Mahnung, 2. Mahnung', () {
    expect(dunningBadge(1), 'Erinnert');
    expect(dunningBadge(2), '1. Mahnung');
    expect(dunningBadge(3), '2. Mahnung');
  });

  test('Zahlungserinnerung ist kostenlos vorbelegt, Mahnung mit Gebühr', () {
    expect(DunningCalculator.suggestedFee(1, const Money(1000)), Money.zero());
    expect(DunningCalculator.suggestedFee(2, const Money(1000)), Money(1000));
  });

  test('Kundendokumente in Sie-Form', () {
    final text = DunningService.bodyText(invoice: invoice, notice: notice());
    expect(text, contains('Bitte überweisen Sie'));
    expect(text, contains('Falls Sie bereits bezahlt haben'));
    expect(text, isNot(contains(' du ')));
    expect(InvoiceTexts.transferRequest('X'), contains('überweisen Sie'));
    expect(InvoiceTexts.shareInvoice('X'), contains('finden Sie'));
  });

  test('Hinweis bei Leistungsdatum nach Rechnungsdatum', () {
    expect(
      InvoiceTexts.deliveryAfterIssueHint(
        DateTime(2026, 9, 1),
        DateTime(2026, 10, 14),
      ),
      contains('stimmt das?'),
    );
    expect(
      InvoiceTexts.deliveryAfterIssueHint(
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 1, 15),
      ),
      isNull,
    );
  });
}
