import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/services/receipt_scan/ocr_text.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_text_parser.dart';
import 'package:flutter_test/flutter_test.dart';

// US-Kioskbeleg (Rückmeldung Auftraggeber 2026-10-27): die Trinkgeld-Tabelle
// „20%: $2.79“ wurde als Steuersatz gelesen, „YOUR ORDER #“ als Händler.
const _usKiosk = '''YOUR ORDER #
2057
DEVIL & ANGEL DESSERT
1157 GALLERIA WAY
GLENDALE, CA 91204
(818) 322-0045
KIOSK-TAKE-OUT-KIOSK
INV# 202610260205700 10/26/2026
GUESTS: 1 07:30 PM
TERMINAL: 2 CLERK:KIOSK
QT DESCRIPTION PRICE
1 Original Açaí Bowl \$13.95
* No Honey
SUBTOTAL: \$13.95
TAX: \$0.00
TIP: \$2.00
TOTAL: \$15.95
MASTER XXXX9327: \$15.95
AUTH AMOUNT: \$13.95 TIP AMOUNT: \$2.00
CHANGE: \$0.00
TIP GUIDE:
15%: \$2.09
18%: \$2.51
20%: \$2.79
CUSTOMER COPY''';

void main() {
  test('US-Beleg: Trinkgeld-Tabelle ist kein Steuersatz, Händler aus Kopf', () {
    final r = ReceiptTextParser(
      TaxProfile.austria,
      now: DateTime(2026, 10, 27),
    ).parse(OcrDocument.fromText(_usKiosk));
    expect(r.vatLines, isEmpty);
    expect(r.gross?.value.cents, 1595);
    expect(r.currency?.value, 'USD');
    expect(r.merchant?.value, 'DEVIL & ANGEL DESSERT');
    expect(r.date?.value, DateTime(2026, 10, 26));
  });

  test('withoutTipGuide schneidet nur ab der Überschrift ab', () {
    expect(ReceiptTextParser.withoutTipGuide(['A', 'TIP GUIDE:', '15%: 1']), [
      'A',
    ]);
    expect(ReceiptTextParser.withoutTipGuide(['A', 'B']), ['A', 'B']);
  });
}
