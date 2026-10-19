import 'dart:convert';

import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/domain/company_profile.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/customer.dart';
import 'package:buchhaltung/domain/invoice.dart';
import 'package:buchhaltung/services/invoice_seller.dart';
import 'package:buchhaltung/services/invoice_texts.dart';
import 'package:buchhaltung/services/vat_id/eu_sme_id_format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// EU-KU-Nummer mit Suffix „EX“ (FA-18.10, Art 284 Abs 3 MwStSystRL).
void main() {
  setUpAll(sqfliteFfiInit);

  group('Format', () {
    test('AT: ATU + 8 Ziffern mit Prüfziffer + EX', () {
      expect(EuSmeIdFormat.check('ATU12345675EX', home: Country.at), isNull);
      expect(EuSmeIdFormat.check('atu 1234 5675 ex', home: Country.at), isNull);
      expect(EuSmeIdFormat.check('ATU12345675', home: Country.at), isNotNull);
      expect(EuSmeIdFormat.check('ATU12345678EX', home: Country.at), isNotNull);
      expect(EuSmeIdFormat.check('DE136695976EX', home: Country.at), isNotNull);
    });

    test('DE: DE + 9 Ziffern mit Prüfziffer + EX', () {
      expect(EuSmeIdFormat.check('DE136695976EX', home: Country.de), isNull);
      expect(EuSmeIdFormat.check('DE136695976', home: Country.de), isNotNull);
      expect(EuSmeIdFormat.check('DE136695977EX', home: Country.de), isNotNull);
    });

    test('leer ist erlaubt (Nummer beantragt)', () {
      expect(EuSmeIdFormat.check('', home: Country.de), isNull);
    });
  });

  group('Rechnung', () {
    const profile = CompanyProfile(
      companyName: 'Anna e.U.',
      country: Country.at,
      vatId: 'ATU12345675',
      euSmeId: 'ATU12345675EX',
    );
    Invoice invoice({bool small = true}) => Invoice(
      number: 'RE-1',
      issueDate: DateTime(2026, 10, 19),
      customerId: 1,
      items: const [],
      isSmallBusiness: small,
      status: InvoiceStatus.issued,
      sellerSnapshot: jsonEncode(profile.toMap()),
    );

    test('nur an Kunden im anderen Mitgliedstaat, nur Kleinunternehmer', () {
      const de = Customer(id: 1, name: 'Kunde DE', country: Country.de);
      const at = Customer(id: 2, name: 'Kunde AT', country: Country.at);
      expect(InvoiceTexts.showsEuSmeId(profile, invoice(), de), isTrue);
      expect(InvoiceTexts.showsEuSmeId(profile, invoice(), at), isFalse);
      expect(
        InvoiceTexts.showsEuSmeId(profile, invoice(small: false), de),
        isFalse,
      );
      expect(
        InvoiceTexts.showsEuSmeId(profile.copyWith(euSmeId: ''), invoice(), de),
        isFalse,
      );
    });

    test('getrennt von der UID und mit der Rechnung eingefroren', () {
      final frozen = InvoiceSeller.profileFor(
        invoice(),
        profile.copyWith(euSmeId: 'ATU99999999EX'),
      );
      expect(frozen.euSmeId, 'ATU12345675EX');
      expect(frozen.vatId, 'ATU12345675');
    });
  });

  test('Migration 27 → 28 ergänzt company_profile.eu_sme_id', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 27,
        onCreate: AppDatabase.createSchema,
        singleInstance: false,
      ),
    );
    await AppDatabase.upgradeSchema(db, 27, 28);
    final cols = [
      for (final r in await db.rawQuery('PRAGMA table_info(company_profile)'))
        r['name'] as String,
    ];
    expect(cols, contains('eu_sme_id'));
    await db.close();
  });
}
