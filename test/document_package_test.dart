import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:buchhaltung/domain/contract.dart';
import 'package:buchhaltung/domain/invoice.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/services/export/document_package.dart';
import 'package:flutter_test/flutter_test.dart';

Receipt _receipt(int id, String partner, int cents) => Receipt(
  id: id,
  date: DateTime(2026, 3, 4),
  direction: BookingDirection.expense,
  description: 'Büromaterial',
  counterparty: partner,
  net: Money(cents),
  vat: const Money.zero(),
  gross: Money(cents),
  vatPermille: 0,
);

Invoice _invoice(int id, String number) => Invoice(
  id: id,
  number: number,
  issueDate: DateTime(2026, 5, 6),
  customerId: 7,
  status: InvoiceStatus.issued,
  items: const [
    InvoiceItem(
      position: 1,
      description: 'Beratung',
      quantityMilli: 1000,
      unit: 'Std',
      unitPrice: Money(10000),
      vatPermille: 200,
    ),
  ],
);

final _bytes = Uint8List.fromList([1, 2, 3]);

void main() {
  test('sprechende Dateinamen: Datum_Partner_Betrag', () {
    final r = _receipt(1, 'Müller & Söhne GmbH', 1250);
    expect(
      DocumentPackage.receiptFileName(
        ReceiptFile(receipt: r, page: 1, extension: 'JPG', bytes: _bytes),
      ),
      'Belege/2026-03-04_Mueller-Soehne-GmbH_12,50EUR.jpg',
    );
    expect(
      DocumentPackage.receiptFileName(
        ReceiptFile(receipt: r, page: 2, extension: 'jpg', bytes: _bytes),
      ),
      endsWith('_S2.jpg'),
    );
    expect(
      DocumentPackage.receiptFileName(
        ReceiptFile(receipt: r, extension: 'pdf', bytes: _bytes),
      ),
      endsWith('_Original.pdf'),
    );
    expect(DocumentPackage.safe('  '), 'unbenannt');
    expect(
      DocumentPackage.invoiceFileName(_invoice(3, 'RE/2026/001'), 'Kunde AG'),
      'Rechnungen/2026-05-06_RE-2026-001_Kunde-AG_120,00EUR.pdf',
    );
  });

  test('gleiche Namen werden durchnummeriert', () {
    final used = <String>{};
    expect(DocumentPackage.unique('a/b.jpg', used), 'a/b.jpg');
    expect(DocumentPackage.unique('a/b.jpg', used), 'a/b (2).jpg');
  });

  test('ZIP mit Belegen, Rechnungen und zwei CSV-Übersichten', () {
    final r1 = _receipt(1, 'Billa', 1250);
    final r2 = _receipt(2, 'Billa', 1250);
    final zip = DocumentPackage.receiptsAndInvoices(
      receipts: [r1, r2],
      receiptFiles: [
        ReceiptFile(receipt: r1, page: 1, extension: 'jpg', bytes: _bytes),
        ReceiptFile(receipt: r2, page: 1, extension: 'jpg', bytes: _bytes),
      ],
      invoices: [_invoice(3, 'RE-1')],
      customerNames: {7: 'Kunde AG'},
      invoicePdfs: {3: _bytes},
    );
    final archive = ZipDecoder().decodeBytes(zip);
    final names = archive.files.map((f) => f.name).toSet();
    expect(names, {
      'Belege/2026-03-04_Billa_12,50EUR.jpg',
      'Belege/2026-03-04_Billa_12,50EUR (2).jpg',
      'Rechnungen/2026-05-06_RE-1_Kunde-AG_120,00EUR.pdf',
      DocumentPackage.receiptsCsvName,
      DocumentPackage.invoicesCsvName,
    });
    String text(String name) =>
        utf8.decode(archive.findFile(name)!.content as List<int>);
    final belege = text(DocumentPackage.receiptsCsvName);
    expect(belege, contains('Billa_12,50EUR (2).jpg'));
    expect(belege.split('\r\n').where((l) => l.isNotEmpty), hasLength(3));
    final rechnungen = text(DocumentPackage.invoicesCsvName);
    expect(rechnungen, contains('RE-1;2026-05-06;Kunde AG'));
    expect(rechnungen, contains('100,00;20,00;120,00'));
  });

  test('Verträge: CSV mit Fristen, Seiten und Original je Ordner', () {
    final c = Contract(
      type: ContractType.rent,
      title: 'Büro',
      partner: 'Huber',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2028, 12, 31),
      noticeValue: 3,
      pages: const ['belege/a.jpg', 'belege/fehlt.jpg'],
      originalPath: 'belege/o.pdf',
    );
    final zip = DocumentPackage.contracts(
      [c],
      {'belege/a.jpg': _bytes, 'belege/o.pdf': _bytes},
    );
    final archive = ZipDecoder().decodeBytes(zip);
    expect(archive.files.map((f) => f.name).toSet(), {
      'Vertraege/Buero_Huber/Seite_1.jpg',
      'Vertraege/Buero_Huber/Original.pdf',
      'vertraege.csv',
    });
    final csv = utf8.decode(
      archive.findFile('vertraege.csv')!.content as List<int>,
    );
    expect(csv, contains('Kündigen bis'));
    expect(csv, contains('2028-09-30'));
  });
}
