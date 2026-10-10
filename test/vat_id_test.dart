import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/vat_check_repository.dart';
import 'package:buchhaltung/domain/company_profile.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/customer.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/services/invoice_requirements.dart';
import 'package:buchhaltung/services/vat_id/vat_check_service.dart';
import 'package:buchhaltung/services/vat_id/vat_id_format.dart';
import 'package:buchhaltung/services/vat_id/vies_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  group('Formatprüfung offline', () {
    test('akzeptiert gültige Prüfziffern AT und DE', () {
      // Beispielnummer aus den BMF-Unterlagen bzw. öffentlich bekannte Nummern.
      expect(VatIdFormat.check('ATU13585627'), isNull);
      expect(VatIdFormat.check('atu 1358 5627'), isNull);
      expect(VatIdFormat.check('DE136695976'), isNull);
      expect(VatIdFormat.check('DE 811.569.869'), isNull);
    });

    test('erkennt Tippfehler über die Prüfziffer', () {
      expect(VatIdFormat.check('ATU13585628'), contains('Prüfziffer'));
      expect(VatIdFormat.check('DE136695977'), contains('Prüfziffer'));
    });

    test('erkennt falsches Format und fremde Länder', () {
      expect(VatIdFormat.check('AT13585627'), contains('ATU'));
      expect(VatIdFormat.check('DE1234'), contains('9 Ziffern'));
      expect(VatIdFormat.check('US123456789'), contains('EU-Ländercode'));
      expect(VatIdFormat.check(''), isNull);
    });
  });

  group('VIES-Antwort', () {
    final at = DateTime(2026, 10, 10);

    test('gültig mit Abfragenummer, Platzhalter werden entfernt', () {
      final check = ViesClient.parse('DE136695976', {
        'valid': true,
        'name': '---',
        'address': '---',
        'requestIdentifier': 'WAPIAAAAZ1',
      }, at);
      expect(check.result, VatCheckResult.valid);
      expect(check.name, isEmpty);
      expect(check.requestIdentifier, 'WAPIAAAAZ1');
    });

    test('ungültig', () {
      final check = ViesClient.parse('ATU13585627', {'valid': false}, at);
      expect(check.result, VatCheckResult.invalid);
    });

    test('Ausfall eines Mitgliedstaats ist nicht ungültig', () {
      final check = ViesClient.parse('DE136695976', {
        'actionSucceed': false,
        'errorWrappers': [
          {'error': 'MS_UNAVAILABLE'},
        ],
      }, at);
      expect(check.result, VatCheckResult.unavailable);
      expect(check.errorCode, 'MS_UNAVAILABLE');
    });

    test('Netzfehler ergibt nicht prüfbar', () async {
      final client = ViesClient(
        transport: (_) async => throw Exception('offline'),
      );
      final check = await client.check('ATU13585627');
      expect(check.result, VatCheckResult.unavailable);
    });

    test('Formatfehler verlässt das Gerät nicht', () async {
      var sent = false;
      final client = ViesClient(
        transport: (_) async {
          sent = true;
          return {'valid': true};
        },
      );
      final check = await client.check('ATU13585628');
      expect(check.result, VatCheckResult.formatError);
      expect(sent, isFalse);
    });

    test('eigene UID wird als Anfragende mitgeschickt', () async {
      Map<String, Object?>? body;
      final client = ViesClient(
        transport: (b) async {
          body = b;
          return {'valid': true};
        },
      );
      await client.check('DE136695976', requesterVatId: 'ATU13585627');
      expect(body!['countryCode'], 'DE');
      expect(body!['vatNumber'], '136695976');
      expect(body!['requesterMemberStateCode'], 'AT');
      expect(body!['requesterNumber'], 'U13585627');
    });
  });

  group('Wöchentliche Prüfung', () {
    Future<Database> openDb() => databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: AppDatabase.createSchema,
        singleInstance: false,
      ),
    );

    test(
      'prüft eigene UID und aktive Kunden, protokolliert, merkt sich den Lauf',
      () async {
        final db = await openDb();
        await db.insert('company_profile', {'id': 1, 'company_name': 'Test'});
        final active = await db.insert('customers', {
          'name': 'Aktiv',
          'vat_id': 'DE136695976',
        });
        await db.insert('customers', {
          'name': 'Inaktiv',
          'vat_id': 'DE811569869',
        });
        await db.insert('invoices', {
          'number': 'RE-1',
          'issue_date': '2026-09-01',
          'customer_id': active,
          'status': 'issued',
          'created_at': '2026-09-01T00:00:00',
        });
        final asked = <String>[];
        final repo = VatCheckRepository(db);
        final service = VatCheckService(
          repo,
          client: ViesClient(
            transport: (b) async {
              asked.add('${b['countryCode']}${b['vatNumber']}');
              return {'valid': true, 'requestIdentifier': 'X1'};
            },
          ),
        );
        const profile = CompanyProfile(
          companyName: 'Test',
          country: Country.at,
          vatId: 'ATU13585627',
          vatCheckEnabled: true,
        );
        final now = DateTime(2026, 10, 10);

        final checked = await service.runIfDue(
          profile,
          now: now,
          pause: Duration.zero,
        );
        expect(checked, 2);
        expect(asked, ['ATU13585627', 'DE136695976']);
        expect((await repo.latest('DE136695976'))!.requestIdentifier, 'X1');
        expect(await repo.latest('DE811569869'), isNull);
        final row = await db.query('company_profile');
        expect(row.first['vat_check_last_run'], startsWith('2026-10-10'));

        // Innerhalb von 7 Tagen nicht erneut.
        final again = profile.copyWith(vatCheckLastRun: now);
        expect(
          await service.runIfDue(
            again,
            now: now.add(const Duration(days: 6)),
            pause: Duration.zero,
          ),
          0,
        );
        await db.close();
      },
    );

    test('ohne Opt-in wird nie automatisch geprüft', () {
      const profile = CompanyProfile(
        companyName: 'Test',
        country: Country.at,
        vatId: 'ATU13585627',
      );
      expect(profile.vatCheckDue(DateTime(2026, 10, 10)), isFalse);
    });
  });

  group('Pflichtangaben', () {
    const customer = Customer(name: 'Kunde');

    test('Österreich: über 10.000 € brutto mit Steuer UID beider Seiten', () {
      const profile = CompanyProfile(companyName: 'Test', country: Country.at);
      expect(
        InvoiceRequirements.missing(
          profile: profile,
          customer: customer,
          gross: Money.fromEuro(10000),
          isSmallBusiness: false,
        ),
        isEmpty,
      );
      expect(
        InvoiceRequirements.missing(
          profile: profile,
          customer: customer,
          gross: Money.fromEuro(10001),
          isSmallBusiness: false,
        ),
        hasLength(2),
      );
      expect(
        InvoiceRequirements.missing(
          profile: profile,
          customer: customer,
          gross: Money.fromEuro(20000),
          isSmallBusiness: true,
        ),
        isEmpty,
      );
    });

    test('Deutschland: Steuernummer oder USt-IdNr. auf jeder Rechnung', () {
      const profile = CompanyProfile(
        companyName: 'Test',
        country: Country.de,
        street: 'Weg 1',
        postalCode: '10115',
        city: 'Berlin',
      );
      expect(profile.missingInvoiceFields, hasLength(1));
      expect(
        profile.copyWith(taxNumber: '1234567890').canIssueInvoices,
        isTrue,
      );
    });

    test('Österreich: ohne Steuernummer und UID rechnungsfähig', () {
      const profile = CompanyProfile(
        companyName: 'Test',
        country: Country.at,
        street: 'Gasse 1',
        postalCode: '1010',
        city: 'Wien',
      );
      expect(profile.canIssueInvoices, isTrue);
      // Regelbesteuerung verlangt keine UID mehr pauschal.
      expect(profile.copyWith(isSmallBusiness: false).canIssueInvoices, isTrue);
    });

    test('Firmenbuchnummer verlangt das Gericht', () {
      const profile = CompanyProfile(
        companyName: 'Test',
        country: Country.at,
        street: 'Gasse 1',
        postalCode: '1010',
        city: 'Wien',
        registerNumber: 'FN 123456a',
      );
      expect(profile.missingInvoiceFields, ['Firmenbuchgericht']);
      expect(
        profile.copyWith(registerCourt: 'Handelsgericht Wien').canIssueInvoices,
        isTrue,
      );
    });
  });
}
