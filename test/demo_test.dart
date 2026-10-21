import 'dart:convert';
import 'dart:io';

import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/invoice.dart';
import 'package:buchhaltung/domain/legal_texts.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/features/demo/demo_screens.dart';
import 'package:buchhaltung/features/demo/demo_sheet.dart';
import 'package:buchhaltung/features/licensing/feature_gate.dart';
import 'package:buchhaltung/main.dart';
import 'package:buchhaltung/services/demo/demo_dataset.dart';
import 'package:buchhaltung/services/demo/demo_dataset_de.dart';
import 'package:buchhaltung/services/demo/demo_mode.dart';
import 'package:buchhaltung/services/demo/demo_session.dart';
import 'package:buchhaltung/services/invoice_pdf.dart';
import 'package:buchhaltung/services/invoice_seller.dart';
import 'package:buchhaltung/services/licensing/fake_store_billing.dart';
import 'package:buchhaltung/services/licensing/license_cache.dart';
import 'package:buchhaltung/services/licensing/license_manager.dart';
import 'package:buchhaltung/services/licensing/license_policy.dart';
import 'package:buchhaltung/services/share_service.dart';
import 'package:buchhaltung/services/small_business_monitor.dart';
import 'package:buchhaltung/services/turnover_basis.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Demo ohne Abo (FA-13.14, Entscheidung Auftraggeber 2026-10-19, O-42).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final today = DateTime(2026, 10, 19);
  late Directory docs;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('de');
  });

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('demo_test');
    demoDocumentsDir = () async => docs;
  });

  tearDown(() async {
    DemoMode.active = false;
    DemoMode.onBlocked = null;
    AppDatabase.instance.leaveDemo();
    if (await docs.exists()) await docs.delete(recursive: true);
  });

  Future<Database> realDb() => databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: AppDatabase.schemaVersion,
      onCreate: AppDatabase.createSchema,
      singleInstance: false,
    ),
  );

  Future<Database> demoDb({Country country = Country.at}) => DemoSession.open(
    documentsDir: docs,
    today: today,
    factory: databaseFactoryFfi,
    country: country,
  );

  group('Musterdaten', () {
    test('Firma, Kundschaft, Belege mit Bildern, Rechnungen, Mahnung, '
        'Storno, Angebote, Anlage, Verträge, zweites Steuerland', () async {
      final db = await demoDb();
      final repos = Repositories(db);
      final profile = (await repos.company.load())!;
      expect(profile.companyName, 'Muster Handel e.U.');
      expect(profile.isSmallBusiness, isTrue, reason: 'Kleinunternehmerin AT');
      expect(await repos.consents.missing(), isEmpty);
      expect((await repos.registrations.all()).single.country.code, 'DE');

      final receipts = await db.query('receipts', where: 'invoice_id IS NULL');
      expect(receipts.length, DemoDataset.receiptCount);
      // Rechnungszahlungen sind als Einnahmen gebucht.
      expect(
        (await db.query('receipts', where: 'invoice_id IS NOT NULL')),
        isNotEmpty,
      );
      final categories = {
        for (final c in await repos.categories.all()) c.id: c.name,
      };
      final used = {for (final r in receipts) categories[r['category_id']]};
      expect(
        used,
        containsAll([
          'Kfz-Kosten',
          'Material und Werkzeug',
          'Bewirtung',
          'Büromaterial',
          'Reisekosten',
        ]),
      );
      // Mehrere Steuersätze auf einem Beleg und fremde Währung.
      final lines = await db.rawQuery(
        'SELECT receipt_id, COUNT(*) AS n FROM receipt_vat_lines '
        'GROUP BY receipt_id HAVING n > 1',
      );
      expect(lines, isNotEmpty);
      expect(receipts.where((r) => r['currency'] == 'CHF'), hasLength(1));
      // Jeder Betrag: net + vat == gross (Grundregel 2).
      for (final r in receipts) {
        expect(
          (r['net_cents'] as int) + (r['vat_cents'] as int),
          r['gross_cents'],
        );
      }
      // Synthetische Belegbilder im eigenen Ordner, gültige PNGs.
      final images = Directory('${docs.path}/demo_belege').listSync();
      expect(images.length, greaterThanOrEqualTo(20));
      final png = (images.first as File).readAsBytesSync();
      expect(png.sublist(1, 4), utf8.encode('PNG'));

      final invoices = await db.query('invoices');
      final statuses = invoices.map((i) => i['status']).toList();
      expect(statuses, containsAll(['paid', 'issued', 'cancelled']));
      expect(statuses, contains('cancellation'));
      expect(await db.query('dunning_notices'), hasLength(1));
      expect(await db.query('offers'), hasLength(2));
      expect(await db.query('fixed_assets'), hasLength(1));
      expect(await db.query('contracts'), hasLength(4));
      await db.close();
    });

    test('Keine echten Marken, keine echten Fotos (P-R56)', () async {
      final db = await demoDb();
      const brands = [
        'omv',
        'shell',
        'bp',
        'eni',
        'jet',
        'aral',
        'hornbach',
        'obi',
        'bauhaus',
        'lagerhaus',
        'billa',
        'spar',
        'hofer',
        'lidl',
        'aldi',
        'rewe',
        'libro',
        'pagro',
        'mcdonald',
        'starbucks',
        'amazon',
        'mediamarkt',
        'saturn',
        'magenta',
        'telekom',
        'vodafone',
        'allianz',
        'uniqa',
        'generali',
        'hilton',
        'marriott',
        'ikea',
        'apple',
        'google',
      ];
      RegExp word(String b) => RegExp('\\b$b\\b');
      final deDb = await demoDb(country: Country.de);
      final rows = [
        ...await db.query('receipts'),
        ...await deDb.query('receipts'),
      ];
      await deDb.close();
      for (final r in rows) {
        final text = '${r['counterparty']} ${r['description']}'.toLowerCase();
        for (final b in brands) {
          expect(word(b).hasMatch(text), isFalse, reason: '$b in $text');
        }
      }
      for (final m in [...DemoDataset.merchants, ...DemoDatasetDe.merchants]) {
        for (final b in brands) {
          expect(word(b).hasMatch(m.toLowerCase()), isFalse, reason: m);
        }
      }
      // Kein Bild aus test/fixtures: alle Seiten liegen in demo_belege/.
      final pages = await db.query('receipt_pages');
      for (final p in pages) {
        expect(p['image_path'] as String, startsWith('demo_belege'));
      }
      await db.close();
    });
  });

  group('Musterdaten Deutschland', () {
    test(
      'Kleinunternehmerin § 19 UStG, Listen gefüllt, net + vat == gross',
      () async {
        final db = await demoDb(country: Country.de);
        final repos = Repositories(db);
        final profile = (await repos.company.load())!;
        expect(profile.companyName, DemoDatasetDe.companyName);
        expect(profile.country, Country.de);
        expect(profile.isSmallBusiness, isTrue);
        expect(await repos.registrations.all(), isEmpty);
        final receipts = await db.query(
          'receipts',
          where: 'invoice_id IS NULL',
        );
        expect(receipts.length, DemoDatasetDe.receiptCount);
        for (final r in receipts) {
          expect(
            (r['net_cents'] as int) + (r['vat_cents'] as int),
            r['gross_cents'],
          );
        }
        expect(await db.query('invoices'), hasLength(greaterThanOrEqualTo(6)));
        expect(await db.query('offers'), isNotEmpty);
        expect(await db.query('contracts'), isNotEmpty);
        // Store-Screenshots: keine Mahnung, höchstens eine offene Rechnung.
        expect(await db.query('dunning_notices'), isEmpty);
        expect(
          await db.query(
            'invoices',
            where: 'status = ?',
            whereArgs: [InvoiceStatus.issued.name],
          ),
          hasLength(lessThanOrEqualTo(1)),
        );
        final categories = {
          for (final c in await repos.categories.all()) c.id: c.name,
        };
        expect(
          receipts.map((r) => categories[r['category_id']]),
          contains('Einkommensteuer-Vorauszahlung'),
        );
        await db.close();
      },
    );

    // Store-Screenshots: Ergebnis grün, Grenze bei rund 63 % – an jedem Tag.
    for (final day in [
      DateTime(2026, 1, 1),
      DateTime(2026, 1, 15),
      DateTime(2026, 3, 1),
      DateTime(2026, 6, 30),
      DateTime(2026, 10, 21),
      DateTime(2026, 12, 31),
    ]) {
      test('Positives Bild und 60–66 % der Grenze am '
          '${day.day}.${day.month}.', () async {
        final db = await DemoSession.open(
          documentsDir: docs,
          today: day,
          factory: databaseFactoryFfi,
          country: Country.de,
        );
        final repos = Repositories(db);
        final profile = (await repos.company.load())!;
        final quarterStart = DateTime(day.year, (day.month - 1) ~/ 3 * 3 + 1);
        for (final from in [
          DateTime(day.year, day.month),
          quarterStart,
          DateTime(day.year),
        ]) {
          final t = await repos.receipts.totals(from: from, to: day);
          expect(
            t.incomeGross.cents,
            greaterThan(t.expenseGross.cents * 2),
            reason: 'ab $from',
          );
        }
        Future<YearTurnover> year(int y) async => TurnoverBasis.forYear(
          year: y,
          fromReceipts: await repos.receipts.turnoverForYear(
            y,
            includeVat: profile.taxProfile.turnoverIncludesVat,
          ),
          opening: await repos.openingTurnover.forYear(y),
          trackingStart: profile.trackingStart,
        );
        final current = await year(day.year);
        final previous = await year(day.year - 1);
        expect(current.amount, DemoDatasetDe.currentYearTurnover);
        expect(previous.amount, DemoDatasetDe.previousYearTurnover);
        final assessment = SmallBusinessMonitor.assess(
          taxProfile: profile.taxProfile,
          isSmallBusiness: profile.isSmallBusiness,
          currentYearTurnover: current.amount,
          previousYearTurnover: previous.isComplete ? previous.amount : null,
          currentYearComplete: current.isComplete,
          isFoundingYear: profile.isFoundingYear(day.year),
        );
        expect(assessment.status, isNot(SmallBusinessStatus.exceeded));
        expect(assessment.displayLimit, const Money(10000000));
        expect(assessment.utilizationPercent, inInclusiveRange(60, 66));
        await db.close();
      });
    }
  });

  group('Abschottung', () {
    test('Schreiben auf die Muster-Datenbank scheitert', () async {
      final db = await demoDb();
      DemoMode.active = true;
      Object? error;
      try {
        await db.insert('customers', {'name': 'Neu'});
      } on Object catch (e) {
        error = e;
      }
      expect(error, isNotNull);
      expect(DemoMode.isWriteBlocked(error!), isTrue);
      await db.close();
    });

    test('Echte Datenbank bleibt unberührt, Demo verlassen zeigt sie '
        'wieder', () async {
      final real = await realDb();
      await real.insert('company_profile', {'id': 1, 'company_name': 'Echt'});
      await ConsentRepositoryHelper.acceptAll(real);
      AppDatabase.instance.overrideDatabaseForTesting(real);
      final state = AppState(
        Repositories(real),
        license: LicenseManager(
          cache: MemoryLicenseCache(),
          billing: FakeStoreBilling.new,
          enabled: false,
        ),
      );
      await state.reload();
      expect(state.profile!.companyName, 'Echt');

      var cleaned = false;
      await state.enterDemo(
        await demoDb(),
        onLeave: () async {
          await DemoSession.clear(docs);
          cleaned = true;
        },
      );
      expect(state.isDemo, isTrue);
      expect(state.entitlement, Entitlement.demo);
      expect(DemoMode.active, isTrue);
      expect(state.profile!.companyName, 'Muster Handel e.U.');
      expect(await AppDatabase.instance.database, isNot(same(real)));
      await expectLater(
        state.repositories.receipts.save(
          Receipt(
            date: today,
            direction: BookingDirection.expense,
            description: 'darf nicht',
            net: const Money(100),
            vat: const Money(20),
            gross: const Money(120),
            vatPermille: 200,
          ),
        ),
        throwsA(isA<Object>()),
      );

      await state.leaveDemo();
      expect(state.isDemo, isFalse);
      expect(DemoMode.active, isFalse);
      expect(state.profile!.companyName, 'Echt');
      expect(cleaned, isTrue);
      expect(Directory('${docs.path}/demo_belege').existsSync(), isFalse);
      expect(await AppDatabase.instance.database, same(real));
      expect(await real.query('receipts'), isEmpty);
      expect(await real.query('customers'), isEmpty);
      expect(await real.query('invoices'), isEmpty);
      await real.close();
    });
  });

  group('PDF und Teilen', () {
    Future<Uint8List> demoInvoicePdf() async {
      final db = await demoDb();
      final repos = Repositories(db);
      final invoice = (await repos.invoices.all()).firstWhere(
        (i) => i.status.isLocked && !i.isCancellation,
      );
      final profile = (await repos.company.load())!;
      final bytes = await InvoicePdf(
        invoice: invoice,
        customer: (await repos.customers.byId(invoice.customerId))!,
        profile: InvoiceSeller.profileFor(invoice, profile),
      ).build();
      await db.close();
      return bytes;
    }

    /// Seiten und Seiten mit gedrehtem Wasserzeichen (45°-Matrix im
    /// entpackten Inhaltsstrom) zählen.
    (int pages, int marked) watermarkCount(Uint8List bytes) {
      final text = latin1.decode(bytes, allowInvalid: true);
      final pages = RegExp(r'/Type\s*/Page\b').allMatches(text).length;
      var marked = 0;
      for (final m in RegExp(r'stream\r?\n').allMatches(text)) {
        final end = text.indexOf('endstream', m.end);
        if (end < 0) continue;
        try {
          final s = latin1.decode(
            zlib.decode(bytes.sublist(m.end, end)),
            allowInvalid: true,
          );
          if (s.contains('0.70711 0.70711 -0.70711 0.70711')) marked++;
        } on Object {
          // kein Inhaltsstrom
        }
      }
      return (pages, marked);
    }

    test('„MUSTER – DEMO“ auf jeder Seite in der Demo, sonst nicht', () async {
      DemoMode.active = true;
      final bytes = await demoInvoicePdf();
      final text = latin1.decode(bytes, allowInvalid: true);
      expect(text, contains(DemoMode.watermarkKeyword));
      final (pages, marked) = watermarkCount(bytes);
      expect(pages, greaterThan(0));
      expect(marked, pages);

      DemoMode.active = false;
      final real = await demoInvoicePdf();
      expect(
        latin1.decode(real, allowInvalid: true),
        isNot(contains(DemoMode.watermarkKeyword)),
      );
      expect(watermarkCount(real).$2, 0);
    });

    test('Teilen ist in der Demo gesperrt und meldet das Blatt', () async {
      DemoMode.active = true;
      var blocked = 0;
      DemoMode.onBlocked = () => blocked++;
      await ShareService.sharePdf(
        fileName: 'x.pdf',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      await ShareService.shareCsv(fileName: 'x.csv', content: 'a;b');
      expect(blocked, 2);
    });
  });

  group('Oberfläche (UX, Daumen)', () {
    /// Laden außerhalb der Test-Uhr abwarten (Datenbank im Hintergrund).
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('Demo aus den Einstellungen: Belege- und Rechnungsliste, '
        'Verträge zeigen Musterdaten; Ampel rund 27 %', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (call) async => null,
          );
      final real = (await tester.runAsync(realDb))!;
      await tester.runAsync(() async {
        await real.insert('company_profile', {'id': 1, 'company_name': 'Echt'});
        await ConsentRepositoryHelper.acceptAll(real);
      });
      AppDatabase.instance.overrideDatabaseForTesting(real);
      final state = AppState(
        Repositories(real),
        license: LicenseManager(
          cache: MemoryLicenseCache(),
          billing: FakeStoreBilling.new,
          enabled: false,
        ),
      );
      await tester.runAsync(state.reload);
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(BuchhaltungApp(state: state));
      await settle(tester);
      // Belege-Reiter einmal mit echten (leeren) Daten öffnen – genau der
      // Fall aus der Rückmeldung: die Liste lebte im IndexedStack weiter.
      await tester.tap(find.text('Belege').last);
      await settle(tester);
      final db = (await tester.runAsync(demoDb))!;
      await tester.runAsync(() => state.enterDemo(db, fromSettings: true));
      await settle(tester);
      expect(state.isDemo, isTrue);
      final sb = state.smallBusiness!;
      final percent = sb.currentYearTurnover.cents * 100 ~/ sb.limit.cents;
      expect(percent, inInclusiveRange(20, 35), reason: '$percent %');

      expect(find.textContaining('Laufkundschaft'), findsWidgets);
      await tester.tap(find.text('Rechnungen').last);
      await settle(tester);
      expect(find.textContaining('überfällig'), findsWidgets);
      expect(find.text('Storno'), findsWidgets);
      expect(find.textContaining('Anna Probe'), findsWidgets);

      await tester.tap(find.text('Belege').last);
      await settle(tester);
      await tester.tap(find.text('Verträge'));
      await settle(tester);
      expect(find.textContaining('Dienstvertrag Teilzeitkraft'), findsWidgets);
      expect(find.textContaining('Leasing Lieferwagen'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Demo Deutschland: Ampel misst an 100.000 € (§ 19 UStG), '
        'Listen gefüllt', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (call) async => null,
          );
      final real = (await tester.runAsync(realDb))!;
      await tester.runAsync(() async {
        await real.insert('company_profile', {'id': 1, 'company_name': 'Echt'});
        await ConsentRepositoryHelper.acceptAll(real);
      });
      AppDatabase.instance.overrideDatabaseForTesting(real);
      final state = AppState(
        Repositories(real),
        license: LicenseManager(
          cache: MemoryLicenseCache(),
          billing: FakeStoreBilling.new,
          enabled: false,
        ),
      );
      await tester.runAsync(state.reload);
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(BuchhaltungApp(state: state));
      await settle(tester);
      final db = (await tester.runAsync(() => demoDb(country: Country.de)))!;
      await tester.runAsync(() => state.enterDemo(db, fromSettings: true));
      await settle(tester);
      final sb = state.smallBusiness!;
      expect(sb.nextYearLimit, const Money(2500000));
      expect(sb.displayLimit, const Money(10000000));
      expect(sb.limit, const Money(10000000));
      expect(sb.utilizationPercent, inInclusiveRange(60, 66));
      expect(find.text('Kleinunternehmergrenze'), findsOneWidget);
      expect(find.byKey(const Key('small-business-limits')), findsOneWidget);
      expect(find.textContaining('§ 19 UStG'), findsWidgets);
      await tester.tap(find.text('Rechnungen').last);
      await settle(tester);
      expect(find.textContaining('Bäckerei Sonnenkorn'), findsWidgets);
      await tester.tap(find.text('Belege').last);
      await settle(tester);
      expect(find.textContaining('Passfotos'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Demo-Start fragt das Land: Deutschland zuerst und '
        'hervorgehoben, beide 56 dp', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Country? picked;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    picked = await chooseDemoCountry(context),
                child: const Text('los'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('los'));
      await tester.pumpAndSettle();
      final de = find.byKey(const Key('demo-country-de'));
      final at = find.byKey(const Key('demo-country-at'));
      expect(tester.widget(de), isA<FilledButton>());
      expect(tester.getTopLeft(de).dy, lessThan(tester.getTopLeft(at).dy));
      for (final f in [de, at]) {
        expect(tester.getSize(f).height, greaterThanOrEqualTo(56));
        expect(tester.getCenter(f).dy, greaterThan(740 / 2));
      }
      await tester.tap(de);
      await tester.pumpAndSettle();
      expect(picked, Country.de);
    });

    Future<AppState> pumpApp(WidgetTester tester) async {
      // Schlüsselbund gibt es im Test nicht: leer antworten.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (call) async => null,
          );
      final real = (await tester.runAsync(realDb))!;
      await tester.runAsync(() => ConsentRepositoryHelper.acceptAll(real));
      AppDatabase.instance.overrideDatabaseForTesting(real);
      final state = AppState(
        Repositories(real),
        license: LicenseManager(
          cache: MemoryLicenseCache(),
          billing: FakeStoreBilling.new,
          enabled: true,
        ),
      );
      await tester.runAsync(state.reload);
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      installDemoGuards();
      await tester.pumpWidget(BuchhaltungApp(state: state));
      await tester.pumpAndSettle();
      return state;
    }

    testWidgets('Willkommensseite: Los geht\'s und Demo groß unten, Demo '
        'startet mit Band, Speichern zeigt das Blatt', (tester) async {
      final state = await pumpApp(tester);
      expect(state.inFirstRunSetup, isTrue);
      final subscribe = find.byKey(const Key('welcome-start'));
      final demo = find.byKey(const Key('welcome-demo'));
      expect(find.text('Willkommen bei JeNi bucht'), findsOneWidget);
      expect(find.text('Erst ansehen (Demo)'), findsOneWidget);
      for (final f in [subscribe, demo]) {
        expect(tester.getSize(f).height, greaterThanOrEqualTo(56));
        // Daumenzone: unteres Drittel des Bildschirms.
        expect(tester.getCenter(f).dy, greaterThan(640 * 2 / 3));
      }
      expect(
        tester.getTopLeft(subscribe).dy - tester.getBottomLeft(demo).dy,
        greaterThanOrEqualTo(12),
      );

      // Gleicher Weg wie der Knopf; echte Datenbankarbeit außerhalb der
      // Test-Uhr.
      await tester.runAsync(
        () => startDemo(tester.element(demo), country: Country.at),
      );
      await settle(tester);
      expect(state.isDemo, isTrue);
      final banner = find.byKey(const Key('demo-banner'));
      expect(banner, findsOneWidget);
      expect(tester.getSize(banner).height, greaterThanOrEqualTo(48));
      expect(find.text(DemoBanner.text), findsOneWidget);

      // Speichern in der Demo: Blatt statt Buchung.
      final context = tester.element(find.byType(Scaffold).first);
      final future = ensureWritable(context);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(DemoSheet.savedText), findsOneWidget);
      final sub = find.byKey(const Key('demo-sheet-subscribe'));
      final stay = find.byKey(const Key('demo-sheet-stay'));
      expect(tester.getSize(sub).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(stay).height, greaterThanOrEqualTo(48));
      await tester.tap(stay);
      await tester.pump(const Duration(milliseconds: 400));
      expect(await future, isFalse);

      // Abo abschließen beendet die Demo; Einrichtung beginnt leer.
      await tester.runAsync(state.license.refresh);
      await tester.runAsync(
        () => state.license.buy(
          state.license.offers!.firstWhere(
            (o) => o.product.id == 'basis_monat',
          ),
        ),
      );
      for (var i = 0; i < 20 && state.isDemo; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
      }
      await settle(tester);
      expect(state.isDemo, isFalse);
      expect(state.needsOnboarding, isTrue);
      expect(state.entitlement, Entitlement.pro, reason: 'Pro inklusive');
      await tester.pumpWidget(const SizedBox());
    });
  });
}

/// Rechtstexte bestätigen, damit die App direkt startet.
class ConsentRepositoryHelper {
  static Future<void> acceptAll(Database db) =>
      Repositories(db).consents.accept(LegalText.all);
}
