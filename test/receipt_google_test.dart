import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/services/receipt_scan/ocr_text.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_scan_prefill.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_text_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gerätetest 2026-10-15: Gmail-Beleg von Google, abfotografiert vom
/// Bildschirm (OCR-ähnlicher Text).
const _googleBeleg = '''
Google
October 15, 2026 at 11:34:40 AM PDT
ITEM QUANTITY PRICE
Developer Registration Fee 1 \$25.00
Tax \$0.00
Total \$25.00
Payment method Visa ••••2887
Order number PDS.0521-0535-4746-90536
''';

void main() {
  final profile = TaxProfile.austria;
  final r = ReceiptTextParser(
    profile,
    now: DateTime(2026, 10, 15, 21),
  ).parse(OcrDocument.fromText(_googleBeleg));

  test('Google-Beleg: Betrag, Währung, Datum, Lieferant', () {
    expect(r.gross?.value.cents, 2500);
    expect(r.currency.value, 'USD');
    expect(r.currency.confidence, greaterThanOrEqualTo(60));
    expect(r.date?.value, DateTime(2026, 10, 15));
    expect(r.merchant?.value, 'Google');
  });

  test('Google-Beleg: als Fremdwährung vorbelegt, als Vorschlag markiert', () {
    final p = ReceiptScanPrefill.from(
      r,
      direction: BookingDirection.expense,
      profile: profile,
      inputVatDeductible: false,
    );
    expect(p.currency, 'USD');
    expect(p.originalGross?.cents, 2500);
    expect(p.gross, isNull);
    expect(p.counterparty, 'Google');
    expect(p.hints.join(), isNot(contains('unklar')));
    expect(p.hints.join(), contains('Vorschlag'));
    expect(p.hints.join(), isNot(contains('Vorsteuerabzug')));
  });

  test('Mit Vorsteuerabzug bleibt der Hinweis ohne Steuerausweis', () {
    final eur = ReceiptTextParser(
      profile,
      now: DateTime(2026, 10, 15, 21),
    ).parse(OcrDocument.fromText('Kartenzahlung\nSumme EUR 12,00'));
    final p = ReceiptScanPrefill.from(
      eur,
      direction: BookingDirection.expense,
      profile: profile,
    );
    expect(p.hints.join(), contains('Vorsteuerabzug'));
    final klein = ReceiptScanPrefill.from(
      eur,
      direction: BookingDirection.expense,
      profile: profile,
      inputVatDeductible: false,
    );
    expect(klein.hints.join(), isNot(contains('Vorsteuerabzug')));
  });

  test('Bekannter Anbieter irgendwo im Text wird Lieferant', () {
    final v = ReceiptTextParser(profile, now: DateTime(2026, 10, 15)).parse(
      OcrDocument.fromText(
        'Your receipt\nThanks for your purchase from Apple\nTotal \$9.99',
      ),
    );
    expect(v.merchant?.value, 'Apple');
  });

  test(r'„$“ ohne US-Merkmale bleibt unklar', () {
    final t = ReceiptTextParser(
      profile,
      now: DateTime(2026, 10, 15),
    ).parse(OcrDocument.fromText('Fare \$):\n1415'));
    expect(t.currency.confidence, lessThan(60));
  });
}
