// Erzeugt die Beispielrechnungen für die Prüfmappe Steuerberater mit dem
// echten PDF-Generator der App (`InvoicePdf`). Kein Teil der Testsuite:
// liegt bewusst nicht unter test/ und läuft nur auf ausdrücklichen Aufruf:
//
//   flutter test docs/pruefmappen/beispiele_erzeugen_test.dart
import 'dart:io';

import 'package:buchhaltung/domain/company_profile.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/customer.dart';
import 'package:buchhaltung/domain/invoice.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/services/invoice_pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _ziel = 'docs/pruefmappen/beispiele';

CompanyProfile _profil(Country land, {required bool klein}) => CompanyProfile(
  companyName: land == Country.at ? 'Muster e.U.' : 'Muster Design',
  ownerName: 'Maria Muster',
  country: land,
  street: land == Country.at ? 'Hauptstraße 1' : 'Lindenweg 3',
  postalCode: land == Country.at ? '9020' : '80331',
  city: land == Country.at ? 'Klagenfurt' : 'München',
  email: 'office@muster.example',
  taxNumber: land == Country.at ? '12-345/6789' : '143/123/45678',
  vatId: klein ? '' : (land == Country.at ? 'ATU12345678' : 'DE123456789'),
  iban: 'AT61 1904 3002 3457 3201',
  bic: 'BKAUATWW',
  bankName: 'Musterbank',
  isSmallBusiness: klein,
);

Customer _kunde(Country land) => Customer(
  id: 1,
  name: 'Beispiel GmbH',
  street: land == Country.at ? 'Ringstraße 42' : 'Marienplatz 8',
  postalCode: land == Country.at ? '1010' : '80331',
  city: land == Country.at ? 'Wien' : 'München',
  country: land,
  vatId: land == Country.at ? 'ATU87654321' : 'DE987654321',
);

Invoice _rechnung({required bool klein}) => Invoice(
  id: 1,
  number: 'RE-2026-0001',
  issueDate: DateTime(2026, 10, 1),
  deliveryDate: DateTime(2026, 9, 30),
  dueDate: DateTime(2026, 10, 15),
  customerId: 1,
  isSmallBusiness: klein,
  notes: '',
  status: InvoiceStatus.issued,
  items: [
    InvoiceItem(
      position: 1,
      description: 'Beratung und Konzeption',
      quantityMilli: 2500,
      unit: 'Std',
      unitPrice: const Money(8000),
      vatPermille: klein ? 0 : 200,
    ),
    InvoiceItem(
      position: 2,
      description: 'Fachbuch',
      quantityMilli: 1000,
      unit: 'Stk',
      unitPrice: const Money(3490),
      vatPermille: klein ? 0 : 100,
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('de'));

  final faelle = {
    'Rechnung_AT_Regelbesteuerung.pdf': (Country.at, false),
    'Rechnung_AT_Kleinunternehmer.pdf': (Country.at, true),
    'Rechnung_DE_Kleinunternehmer.pdf': (Country.de, true),
  };

  for (final MapEntry(key: datei, value: (land, klein)) in faelle.entries) {
    test(datei, () async {
      final bytes = await InvoicePdf(
        invoice: _rechnung(klein: klein),
        customer: _kunde(land),
        profile: _profil(land, klein: klein),
      ).build();
      Directory(_ziel).createSync(recursive: true);
      File('$_ziel/$datei').writeAsBytesSync(bytes);
    });
  }
}
