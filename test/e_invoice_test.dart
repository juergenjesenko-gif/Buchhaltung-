// E-Rechnungen (L-27.5, L-27.6): XRechnung UBL und CII aus der
// KoSIT-Testsuite, ebInterface 6.1, ZUGFeRD-PDF mit eingebettetem XML.
import 'dart:io';

import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/services/receipt_scan/document_import.dart';
import 'package:buchhaltung/services/receipt_scan/e_invoice_parser.dart';
import 'package:buchhaltung/services/receipt_scan/pdf_embedded_files.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_code_prefill.dart';
import 'package:flutter_test/flutter_test.dart';

String fixture(String name) =>
    File('test/fixtures/einvoice/$name').readAsStringSync();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('XRechnung UBL (KoSIT 01.01a)', () {
    final inv = EInvoiceParser.parse(fixture('01.01a-INVOICE_ubl.xml'))!;
    expect(inv.format, 'XRechnung/UBL');
    expect(inv.number, '123456XX');
    expect(inv.date, DateTime(2016, 4, 4));
    expect(inv.seller, '[Seller name]');
    expect(inv.sellerVatId, 'DE123456789');
    expect(inv.gross, const Money(33690));
    expect(inv.vatLines.single.permille, 70);
    expect(inv.vatLines.single.net, const Money(31486));
    expect(inv.vatLines.single.vat, const Money(2204));
    expect(inv.iban, 'DE79000000001234567890');
  });

  test('XRechnung CII (KoSIT 01.01a)', () {
    final inv = EInvoiceParser.parse(fixture('01.01a-INVOICE_uncefact.xml'))!;
    expect(inv.format, contains('CII'));
    expect(inv.number, '123456XX');
    expect(inv.date, DateTime(2016, 4, 4));
    expect(inv.seller, '[Seller name]');
    expect(inv.sellerVatId, 'DE123456789');
    expect(inv.gross, const Money(33690));
    expect(inv.vatLines.single.permille, 70);
  });

  test('ebInterface 6.1 mit zwei Sätzen', () {
    final inv = EInvoiceParser.parse(fixture('ebinterface_6p1.xml'))!;
    expect(inv.format, 'ebInterface');
    expect(inv.number, '2026-0815');
    expect(inv.seller, 'Muster Installationen GmbH');
    expect(inv.sellerVatId, 'ATU13585627');
    expect(inv.gross, const Money(17500));
    expect(inv.vatLines.map((l) => l.permille), [200, 100]);
    expect(inv.iban, 'AT611904300234573201');

    final p = ReceiptCodePrefill.fromEInvoice(
      inv,
      profile: TaxProfile.austria,
      direction: BookingDirection.expense,
    );
    expect(p.gross, const Money(17500));
    expect(p.vatParts.map((v) => (v.permille, v.gross.cents)).toSet(), {
      (200, 12000),
      (100, 5500),
    });
    expect(p.counterparty, 'Muster Installationen GmbH');
    expect(p.note, 'IBAN AT611904300234573201');
    expect(p.codeSource, 'E-Rechnung');
  });

  test('deutsche E-Rechnung im AT-Profil: 0 % bei Ausgabe', () {
    final inv = EInvoiceParser.parse(fixture('01.01a-INVOICE_ubl.xml'))!;
    final p = ReceiptCodePrefill.fromEInvoice(
      inv,
      profile: TaxProfile.austria,
      direction: BookingDirection.expense,
    );
    expect(p.vatPermille, 0);
    expect(p.gross, const Money(33690));
  });

  test('ZUGFeRD: XML aus der PDF', () async {
    final bytes = File(
      'test/fixtures/einvoice/zugferd_synthetisch.pdf',
    ).readAsBytesSync();
    final xml = PdfEmbeddedFiles.xml(bytes);
    expect(xml, hasLength(1));
    expect(EInvoiceParser.parse(xml.single)!.number, '123456XX');

    final doc = await const DocumentImporter().import(
      File('test/fixtures/einvoice/zugferd_synthetisch.pdf'),
    );
    expect(doc.mime, 'application/pdf');
    expect(doc.eInvoice?.gross, const Money(33690));
    expect(doc.sha256, hasLength(64));
  });

  test('kein XXE, kein fremdes XML', () {
    expect(
      EInvoiceParser.parse(
        '<?xml version="1.0"?><!DOCTYPE x [<!ENTITY e SYSTEM "file:///etc/passwd">]><x>&e;</x>',
      ),
      isNull,
    );
    expect(EInvoiceParser.parse('<Invoice><ID>1</ID></Invoice>'), isNull);
    expect(EInvoiceParser.parse('kein xml'), isNull);
  });
}
