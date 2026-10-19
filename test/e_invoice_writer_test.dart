import 'dart:io';

import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/domain/company_profile.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/customer.dart';
import 'package:buchhaltung/domain/invoice.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/services/e_invoice/e_invoice_output.dart';
import 'package:buchhaltung/services/e_invoice/e_invoice_writer.dart';
import 'package:buchhaltung/services/invoice_pdf.dart';
import 'package:buchhaltung/services/receipt_scan/e_invoice_parser.dart';
import 'package:buchhaltung/services/receipt_scan/pdf_embedded_files.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xml/xml.dart';

/// E-Rechnung erstellen (FA-5.49): XSD-gültig (Factur-X 1.09 EN 16931 für
/// CII, ebInterface 6.1), Rundreise über den vorhandenen Parser, ZUGFeRD-PDF
/// mit eingebetteter XML. Die Schemadateien liegen in
/// `test/fixtures/e_invoice_schemas/`: Factur-X 1.09.2 EN 16931 (FNFE-MPE /
/// FeRD, = ZUGFeRD 2.4, CII D22B-Teilmenge; aus dem PyPI-Paket `factur-x`
/// 7.7) und ebInterface 6.1 (AUSTRIAPRO, aus `com.helger:ph-ebinterface`
/// 8.1.1). Beide frei verwendbar (P-R64).
///
/// Mit `EINVOICE_SAMPLES_DIR=<Ordner>` schreibt der Test die Muster auch auf
/// die Platte – für die Prüfung mit KoSIT-Validator bzw. Mustang (P-D56).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('de'));

  final xmllint = Process.runSync('which', ['xmllint']).exitCode == 0;
  final samplesDir = Platform.environment['EINVOICE_SAMPLES_DIR'];

  CompanyProfile seller({
    Country country = Country.de,
    bool small = false,
    String vatId = 'DE123456789',
  }) => CompanyProfile(
    companyName: 'Muster Handel',
    country: country,
    ownerName: 'Mia Muster',
    street: 'Musterweg 7',
    postalCode: country == Country.de ? '80331' : '1010',
    city: country == Country.de ? 'München' : 'Wien',
    email: 'post@muster-handel.example',
    phone: '+49 89 1234567',
    taxNumber: '143/123/45678',
    vatId: vatId,
    isSmallBusiness: small,
    iban: country == Country.de
        ? 'DE02120300000000202051'
        : 'AT611904300234573201',
    bic: country == Country.de ? 'BYLADEM1001' : 'BKAUATWW',
    invoiceNumberPattern: 'RE-{YYYY}-{NNNN}',
  );

  Customer buyer({
    Country country = Country.de,
    String reference = '',
    String supplier = '',
  }) => Customer(
    name: 'Beispiel Werkstatt GmbH',
    street: 'Industriestraße 12',
    postalCode: country == Country.de ? '90402' : '4020',
    city: country == Country.de ? 'Nürnberg' : 'Linz',
    country: country,
    email: 'rechnung@beispiel.example',
    vatId: country == Country.de ? 'DE987654321' : 'ATU12345678',
    isBusiness: true,
    buyerReference: reference,
    supplierNumber: supplier,
  );

  InvoiceItem item(
    String text,
    int qtyMilli,
    int unitCents,
    int permille, {
    String unit = 'Stk',
    int discountPermille = 0,
  }) => InvoiceItem(
    position: 0,
    description: text,
    quantityMilli: qtyMilli,
    unitPrice: Money(unitCents),
    vatPermille: permille,
    unit: unit,
    discountPermille: discountPermille,
  );

  final issued = DateTime(2026, 10, 19);

  Invoice invoice({
    required List<InvoiceItem> items,
    bool small = false,
    int discountPermille = 0,
    Money shipping = const Money.zero(),
    int skontoDays = 0,
    int skontoPermille = 0,
  }) => Invoice(
    number: 'RE-2026-0042',
    issueDate: issued,
    deliveryDate: DateTime(2026, 10, 15),
    dueDate: DateTime(2026, 11, 2),
    customerId: 1,
    items: items,
    status: InvoiceStatus.issued,
    isSmallBusiness: small,
    discountPermille: discountPermille,
    shipping: shipping,
    skontoDays: skontoDays,
    skontoPermille: skontoPermille,
  );

  Invoice storno(Invoice original) => Invoice(
    number: 'RE-2026-0043',
    issueDate: DateTime(2026, 10, 20),
    deliveryDate: original.deliveryDate,
    customerId: 1,
    items: original.items,
    status: InvoiceStatus.issued,
    isSmallBusiness: original.isSmallBusiness,
    discountPermille: original.discountPermille,
    shipping: original.shipping,
    cancelsInvoiceId: 1,
    cancelsNumber: original.number,
    cancelsIssueDate: original.issueDate,
    cancelReason: 'Falsche Menge',
  );

  final kleinunternehmer = EInvoiceInput(
    invoice: invoice(
      small: true,
      items: [
        item('Beratung', 3500, 8000, 0, unit: 'Std'),
        item('Montageset Regal', 2000, 4500, 0),
      ],
    ),
    seller: seller(small: true, vatId: ''),
    buyer: buyer(reference: '04011000-12345-67'),
  );

  final regel = EInvoiceInput(
    invoice: invoice(
      items: [
        item('Regalsystem', 1000, 120000, 190, discountPermille: 50),
        item('Fachbuch Lager', 3000, 2990, 70),
        item('Montage', 2500, 6500, 190, unit: 'Std'),
      ],
      discountPermille: 30,
      shipping: const Money(1990),
      skontoDays: 7,
      skontoPermille: 20,
    ),
    seller: seller(),
    buyer: buyer(reference: '04011000-12345-67'),
  );

  final regelAt = EInvoiceInput(
    invoice: invoice(
      items: [
        item('Lagerregal Montage', 3000, 120000, 200),
        item('Fachbuch', 1000, 2990, 100),
        item('Tagesmenü Schulung', 4000, 1450, 100),
      ],
      skontoDays: 10,
      skontoPermille: 30,
    ),
    seller: seller(country: Country.at, vatId: 'ATU00000000'),
    buyer: buyer(
      country: Country.at,
      reference: '4500012345',
      supplier: '0000123456',
    ),
  );

  final cases = <String, EInvoiceInput>{
    'kleinunternehmer_de': kleinunternehmer,
    'regel_de_mehrere_saetze_rabatt_skonto': regel,
    'storno_regel_de': EInvoiceInput(
      invoice: storno(regel.invoice),
      seller: regel.seller,
      buyer: regel.buyer,
    ),
    'storno_kleinunternehmer_de': EInvoiceInput(
      invoice: storno(kleinunternehmer.invoice),
      seller: kleinunternehmer.seller,
      buyer: kleinunternehmer.buyer,
    ),
    'regel_at': regelAt,
  };

  void validate(String xml, String xsd, String name) {
    if (!xmllint) {
      markTestSkipped('xmllint fehlt – XSD-Prüfung nur in der CI');
      return;
    }
    final dir = Directory.systemTemp.createTempSync('einv');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/$name.xml')..writeAsStringSync(xml);
    final result = Process.runSync('xmllint', [
      '--noout',
      '--schema',
      xsd,
      file.path,
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}\n$xml');
  }

  void writeSample(String name, List<int> bytes) {
    if (samplesDir == null) return;
    Directory(samplesDir).createSync(recursive: true);
    File('$samplesDir/$name').writeAsBytesSync(bytes);
  }

  void expectSameTotals(EInvoice parsed, EInvoiceInput input) {
    final totals = input.totals;
    expect(parsed.gross, totals.gross);
    expect(parsed.isCreditNote, input.isCreditNote);
    expect(parsed.number, input.invoice.number);
    expect(parsed.currency, 'EUR');
    final byRate = {
      for (final l in parsed.vatLines) l.permille: (net: l.net, vat: l.vat),
    };
    expect(byRate.keys.toSet(), totals.breakdown.keys.toSet());
    for (final e in totals.breakdown.entries) {
      expect(byRate[e.key]!.net, e.value.net, reason: 'Satz ${e.key}');
      expect(byRate[e.key]!.vat, e.value.vat, reason: 'Satz ${e.key}');
      // GR-2 je Satz.
      expect(
        byRate[e.key]!.net + byRate[e.key]!.vat,
        e.value.net + e.value.vat,
      );
    }
  }

  const ciiXsd =
      'test/fixtures/e_invoice_schemas/facturx_en16931/Factur-X_EN16931.xsd';
  const ebiXsd =
      'test/fixtures/e_invoice_schemas/ebinterface/ebinterface-6.1.xsd';

  group('CII (ZUGFeRD EN 16931 / XRechnung 3.0)', () {
    for (final entry in cases.entries) {
      for (final xr in [false, true]) {
        final label = '${entry.key}${xr ? '_xrechnung' : '_zugferd'}';
        test('$label: XSD-gültig, Rundreise mit gleichen Summen', () {
          final xml = EInvoiceWriter.cii(entry.value, xrechnung: xr);
          validate(xml, ciiXsd, label);
          writeSample('$label.xml', xml.codeUnits);
          final parsed = EInvoiceParser.parse(xml)!;
          expect(parsed.format, contains('CII'));
          expectSameTotals(parsed, entry.value);
          if (entry.value.seller.iban.isNotEmpty) {
            expect(parsed.iban, entry.value.seller.iban);
          }
        });
      }
    }

    test('Kleinunternehmer: Kategorie E mit Befreiungsgrund, keine Steuer', () {
      final xml = XmlDocument.parse(EInvoiceWriter.cii(kleinunternehmer));
      final codes = xml
          .findAllElements('ram:CategoryCode')
          .map((e) => e.innerText)
          .toSet();
      expect(codes, {'E'});
      expect(
        xml.findAllElements('ram:ExemptionReason').single.innerText,
        'Steuerbefreiung nach § 19 UStG (Kleinunternehmer).',
      );
      expect(
        xml.findAllElements('ram:TaxTotalAmount').single.innerText,
        '0.00',
      );
      // Ohne UID: Steuernummer als FC und als Verkäuferkennung (BR-CO-26).
      final ids = xml
          .findAllElements('ram:SellerTradeParty')
          .single
          .findElements('ram:SpecifiedTaxRegistration');
      expect(ids.single.innerText.trim(), '143/123/45678');
    });

    test('Regelbesteuerung: S mit 19 und 7, Rabatt und Versand als '
        'Zu-/Abschlag je Satz, Positionsrabatt, Skonto maschinenlesbar', () {
      final xml = XmlDocument.parse(EInvoiceWriter.cii(regel, xrechnung: true));
      final rates = xml
          .findAllElements('ram:ApplicableHeaderTradeSettlement')
          .single
          .findElements('ram:ApplicableTradeTax')
          .map((e) => e.getElement('ram:RateApplicablePercent')!.innerText)
          .toList();
      expect(rates, ['19', '7']);
      final indicators = xml
          .findAllElements('ram:SpecifiedTradeAllowanceCharge')
          .map(
            (e) => e
                .getElement('ram:ChargeIndicator')!
                .getElement('udt:Indicator')!
                .innerText,
          )
          .toList();
      // Positionsrabatt + Rabatt je Satz (2) + Versand je Satz (2).
      expect(indicators.where((i) => i == 'false'), hasLength(3));
      expect(indicators.where((i) => i == 'true'), hasLength(2));
      final terms = xml.findAllElements('ram:Description').single.innerText;
      expect(terms, contains('#SKONTO#TAGE=7#PROZENT=2.00#'));
      expect(
        xml.findAllElements('ram:BuyerReference').single.innerText,
        '04011000-12345-67',
      );
      expect(
        xml.findAllElements('ram:ID').first.innerText,
        EInvoiceWriter.businessProcess,
      );
      // Summenregeln EN 16931 (BR-CO-10, BR-CO-13, BR-CO-15).
      final summation = xml
          .findAllElements(
            'ram:SpecifiedTradeSettlementHeaderMonetarySummation',
          )
          .single;
      String sum(String n) => summation.getElement('ram:$n')!.innerText;
      int cents(String n) => (double.parse(sum(n)) * 100).round();
      expect(
        cents('TaxBasisTotalAmount'),
        cents('LineTotalAmount') -
            cents('AllowanceTotalAmount') +
            cents('ChargeTotalAmount'),
      );
      expect(
        cents('GrandTotalAmount'),
        cents('TaxBasisTotalAmount') + cents('TaxTotalAmount'),
      );
    });

    test('Storno: Art 381, positive Beträge, Bezug auf die Rechnung', () {
      final input = cases['storno_regel_de']!;
      final xml = XmlDocument.parse(EInvoiceWriter.cii(input));
      expect(xml.findAllElements('ram:TypeCode').first.innerText, '381');
      expect(
        double.parse(
          xml.findAllElements('ram:GrandTotalAmount').single.innerText,
        ),
        greaterThan(0),
      );
      expect(
        xml
            .findAllElements('ram:InvoiceReferencedDocument')
            .single
            .getElement('ram:IssuerAssignedID')!
            .innerText,
        'RE-2026-0042',
      );
      // Die gespeicherte Stornorechnung hat negative Summen; die E-Rechnung
      // trägt sie mit Art 381 positiv.
      expect(input.invoice.grossTotal, -input.totals.gross);
    });
  });

  group('ebInterface 6.1', () {
    for (final entry in cases.entries) {
      test('${entry.key}: XSD-gültig, Rundreise mit gleichen Summen', () {
        final xml = EInvoiceWriter.ebInterface(entry.value);
        validate(xml, ebiXsd, '${entry.key}_ebi');
        writeSample('${entry.key}_ebinterface.xml', xml.codeUnits);
        final parsed = EInvoiceParser.parse(xml)!;
        expect(parsed.format, 'ebInterface');
        expectSameTotals(parsed, entry.value);
      });
    }

    test('Bund AT: Auftragsreferenz und Lieferantennummer', () {
      final xml = XmlDocument.parse(EInvoiceWriter.ebInterface(regelAt));
      expect(xml.findAllElements('OrderID').single.innerText, '4500012345');
      expect(
        xml.findAllElements('InvoiceRecipientsBillerID').single.innerText,
        '0000123456',
      );
    });
  });

  test('Migration 29 → 30: Kundin mit Leitweg-ID, Lieferantennummer, '
      'Format; alte Kundinnen bleiben ZUGFeRD', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 29,
        onCreate: AppDatabase.createSchema,
        singleInstance: false,
      ),
    );
    await db.insert('customers', {'name': 'Alt'});
    await AppDatabase.upgradeSchema(db, 29, 30);
    final old = Customer.fromMap((await db.query('customers')).single);
    expect(old.eInvoiceFormat, EInvoiceFormat.zugferd);
    expect(old.buyerReference, '');
    final neu = buyer(
      reference: '991-01234-56',
      supplier: '4711',
    ).copyWith(eInvoiceFormat: EInvoiceFormat.xrechnung);
    final id = await db.insert('customers', neu.toMap());
    final back = Customer.fromMap(
      (await db.query('customers', where: 'id = ?', whereArgs: [id])).single,
    );
    expect(back.eInvoiceFormat, EInvoiceFormat.xrechnung);
    expect(back.buyerReference, '991-01234-56');
    expect(back.supplierNumber, '4711');
    await db.close();
  });

  group('Pflichtangaben je Format', () {
    test('XRechnung verlangt Leitweg-ID, E-Mail, Telefon, IBAN', () {
      final input = EInvoiceInput(
        invoice: regel.invoice,
        seller: CompanyProfile(
          companyName: 'Muster Handel',
          country: Country.de,
          street: 'Musterweg 7',
          postalCode: '80331',
          city: 'München',
          vatId: 'DE123456789',
        ),
        buyer: const Customer(
          name: 'Stadt Beispiel',
          postalCode: '90402',
          city: 'Nürnberg',
          country: Country.de,
        ),
      );
      expect(EInvoiceCheck.missing(EInvoiceFormat.zugferd, input), isEmpty);
      final xr = EInvoiceCheck.missing(EInvoiceFormat.xrechnung, input);
      expect(xr, contains('Leitweg-ID der Kundin'));
      expect(xr, contains('E-Mail-Adresse der Kundin'));
      expect(xr, contains('Deine Telefonnummer in den Stammdaten'));
      expect(xr, contains('Deine IBAN in den Stammdaten'));
      final ebi = EInvoiceCheck.missing(EInvoiceFormat.ebInterface, input);
      expect(ebi, contains('Auftragsreferenz der Kundin'));
      expect(ebi, contains('Deine Lieferantennummer bei der Kundin'));
    });

    test('Mengeneinheiten nach UN/ECE Rec. 20', () {
      expect(EInvoiceWriter.unitCode('Stk'), 'C62');
      expect(EInvoiceWriter.unitCode('Std'), 'HUR');
      expect(EInvoiceWriter.unitCode('kg'), 'KGM');
      expect(EInvoiceWriter.unitCode('pausch.'), 'LS');
      expect(EInvoiceWriter.unitCode('Kiste'), 'C62');
    });
  });

  group('Ausgabe beim Ansehen', () {
    test('Standard: ZUGFeRD eingebettet, Hinweis, kein XML', () {
      final out = EInvoiceOutput.prepare(
        input: regel,
        format: EInvoiceFormat.zugferd,
        allowed: true,
        demo: false,
      );
      expect(out.facturX, isNotNull);
      expect(out.xml, isNull);
      expect(out.notice, EInvoiceOutput.zugferdNotice);
    });

    test('Behörde DE: XRechnung zum Senden, PDF trotzdem mit ZUGFeRD', () {
      final out = EInvoiceOutput.prepare(
        input: regel,
        format: EInvoiceFormat.xrechnung,
        allowed: true,
        demo: false,
      );
      expect(out.xml!.fileName, 'XRechnung_RE-2026-0042.xml');
      expect(out.xml!.content, contains(EInvoiceWriter.guidelineXRechnung));
      expect(out.facturX, isNotNull);
    });

    test('Fehlende Angaben: kein XML, Hinweis nennt sie', () {
      final input = EInvoiceInput(
        invoice: regel.invoice,
        seller: regel.seller,
        buyer: regel.buyer.copyWith(buyerReference: ''),
      );
      final out = EInvoiceOutput.prepare(
        input: input,
        format: EInvoiceFormat.xrechnung,
        allowed: true,
        demo: false,
      );
      expect(out.xml, isNull);
      expect(out.facturX, isNull);
      expect(out.notice, contains('Leitweg-ID der Kundin'));
    });

    test('Ohne Pro nur Hinweis, in der Demo nichts', () {
      final noPro = EInvoiceOutput.prepare(
        input: regel,
        format: EInvoiceFormat.zugferd,
        allowed: false,
        demo: false,
      );
      expect(noPro.facturX, isNull);
      expect(noPro.notice, EInvoiceOutput.proNotice);
      final demo = EInvoiceOutput.prepare(
        input: regel,
        format: EInvoiceFormat.zugferd,
        allowed: true,
        demo: true,
      );
      expect(demo.facturX, isNull);
      expect(demo.notice, isNull);
    });
  });

  group('ZUGFeRD-PDF', () {
    for (final name in [
      'kleinunternehmer_de',
      'regel_de_mehrere_saetze_rabatt_skonto',
      'storno_regel_de',
    ]) {
      test('$name: PDF/A-3 trägt factur-x.xml, Rundreise gleich', () async {
        final input = cases[name]!;
        final xml = EInvoiceWriter.cii(input);
        final pdf = await InvoicePdf(
          invoice: input.invoice,
          customer: input.buyer,
          profile: input.seller,
          facturX: xml,
        ).build();
        writeSample('$name.pdf', pdf);
        final text = String.fromCharCodes(pdf);
        expect(text, contains('/AFRelationship/Alternative'));
        expect(text, contains('factur-x.xml'));
        expect(text, contains('/OutputIntents'));
        expect(text, contains('<pdfaid:part>3</pdfaid:part>'));
        expect(text, contains('EN 16931'));
        final embedded = PdfEmbeddedFiles.xml(pdf);
        expect(embedded, hasLength(1));
        expectSameTotals(EInvoiceParser.parse(embedded.single)!, input);
      });
    }

    test('Ohne E-Rechnung bleibt das PDF wie bisher', () async {
      final pdf = await InvoicePdf(
        invoice: regel.invoice,
        customer: regel.buyer,
        profile: regel.seller,
      ).build();
      expect(String.fromCharCodes(pdf), isNot(contains('factur-x.xml')));
      expect(PdfEmbeddedFiles.xml(pdf), isEmpty);
    });
  });
}
