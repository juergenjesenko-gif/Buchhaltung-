import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/services/receipt_scan/ocr_text.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_text_parser.dart';
import 'package:flutter_test/flutter_test.dart';

// Gmail-Ausdruck eines Square-Belegs (Rückmeldung Auftraggeber 2026-10-25):
// erkannt wurde „Google“ statt des Händlers.
const _squareMail = '''
Receipt from Ubatuba Acai Sherman Oaks #cTpd
1 message
Ubatuba Acai Sherman Oaks <messenger@messaging.squareup.com> Sat, 24 Oct 2026 at 12:11
Reply to: Ubatuba Acai Sherman Oaks via Square
To: max.muster@gmail.com
Ubatuba Acai Sherman Oaks
View web receipt
\$91.00 #cTpd
Oct 24 2026 at 12:11 PM
Create Your Own Bowl \$16.00
Purchase Subtotal \$81.00
Tip \$10.00
Total \$91.00
Google Pay
© 2026 Square Privacy Policy
''';

ReceiptScanResult _parse(String text) => ReceiptTextParser(
  TaxProfile.austria,
  now: DateTime(2026, 10, 25),
).parse(OcrDocument.fromText(text));

void main() {
  test('E-Mail-Beleg: Händler aus „Receipt from …“, nicht Google/Square', () {
    final r = _parse(_squareMail);
    expect(r.merchant?.value, 'Ubatuba Acai Sherman Oaks');
    expect(r.gross?.value.cents, 9100);
  });

  test('Betreffmuster deutsch und englisch', () {
    expect(
      ReceiptTextParser.mailReceiptMerchant([
        'Ihre Rechnung von Musterladen GmbH',
      ]),
      'Musterladen GmbH',
    );
    expect(
      ReceiptTextParser.mailReceiptMerchant([
        'Fwd: Your receipt from Café Blau #12',
      ]),
      'Café Blau',
    );
    expect(
      ReceiptTextParser.mailReceiptMerchant(['BILLA AG', 'Filiale 12']),
      isNull,
    );
  });
}
