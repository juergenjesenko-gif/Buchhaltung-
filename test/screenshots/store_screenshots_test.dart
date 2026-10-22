@Tags(['screenshots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/core/formatting.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/invoice.dart';
import 'package:buchhaltung/domain/legal_texts.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/features/contracts/contract_screens.dart';
import 'package:buchhaltung/features/demo/demo_screens.dart';
import 'package:buchhaltung/features/invoices/invoice_share.dart';
import 'package:buchhaltung/features/licensing/subscription_screen.dart';
import 'package:buchhaltung/features/pdf_viewer/pdf_viewer_screen.dart';
import 'package:buchhaltung/features/receipts/receipt_edit_screen.dart';
import 'package:buchhaltung/main.dart';
import 'package:buchhaltung/services/demo/demo_mode.dart';
import 'package:buchhaltung/services/demo/demo_receipt_image.dart';
import 'package:buchhaltung/services/demo/demo_session.dart';
import 'package:buchhaltung/services/licensing/fake_store_billing.dart';
import 'package:buchhaltung/services/licensing/license_cache.dart';
import 'package:buchhaltung/services/licensing/license_manager.dart';
import 'package:buchhaltung/services/receipt_image_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Store-Screenshots aus der deutschen Demo (P-D34), ohne Emulator.
///
/// Läuft nur mit `SCREENSHOTS=1`, siehe `tool/screenshots/README.md`.
/// Ausgabe: `build/screenshots/<store>/<nr>_<name>.png`.
void main() {
  final enabled = Platform.environment['SCREENSHOTS'] == '1';

  const targets = <_Target>[
    _Target('play_phone', Size(1080, 1920), 2.625),
    _Target('play_tablet', Size(1600, 2560), 2),
    _Target('appstore_6_9', Size(1320, 2868), 3),
    _Target('appstore_ipad_13', Size(2064, 2752), 2),
  ];

  late Directory docs;

  setUpAll(() async {
    if (!enabled) return;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('de');
    await _loadFonts();
  });

  for (final target in targets) {
    testWidgets('Screenshots ${target.store}', (tester) async {
      docs = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('screenshots'),
      ))!;
      demoDocumentsDir = () async => docs;
      DemoFrame.showBanner = false;
      // Echte Schatten statt schwarzer Umrisse (Testvorgabe von Flutter).
      debugDisableShadows = false;
      addTearDown(() {
        debugDisableShadows = true;
        DemoFrame.showBanner = true;
        DemoMode.active = false;
        DemoMode.onBlocked = null;
        AppDatabase.instance.leaveDemo();
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (call) async => null,
          );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => docs.path,
          );

      final real = (await tester.runAsync(
        () => databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            version: AppDatabase.schemaVersion,
            onCreate: AppDatabase.createSchema,
            singleInstance: false,
          ),
        ),
      ))!;
      await tester.runAsync(() async {
        await real.insert('company_profile', {'id': 1, 'company_name': 'Echt'});
        await Repositories(real).consents.accept(LegalText.all);
      });
      AppDatabase.instance.overrideDatabaseForTesting(real);
      final state = AppState(
        Repositories(real),
        license: LicenseManager(
          cache: MemoryLicenseCache(),
          // Grundpreise laut STORE_LISTING „Preise“ (ohne Einführungscode).
          billing: () => FakeStoreBilling(
            prices: {
              'basis_monat': '12,90 €',
              'basis_jahr': '129,00 €',
              'pro_monat': '17,90 €',
              'pro_jahr': '179,00 €',
            },
          ),
          enabled: true,
        ),
      );
      await tester.runAsync(state.reload);
      await tester.runAsync(state.license.refresh);

      tester.view.physicalSize = target.size;
      tester.view.devicePixelRatio = target.ratio;
      addTearDown(tester.view.reset);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: BuchhaltungApp(state: state),
        ),
      );
      await _settle(tester);
      final db = (await tester.runAsync(
        () => DemoSession.open(
          documentsDir: docs,
          today: DateTime.now(),
          factory: databaseFactoryFfi,
          country: Country.de,
        ),
      ))!;
      // Bildschirmfotos ohne Sicherungshinweis: Sicherung „heute“ erledigt.
      await tester.runAsync(() async {
        await db.execute('PRAGMA query_only = OFF');
        await db.update('company_profile', {
          'last_backup_at': DateTime.now().toIso8601String(),
        });
        await db.execute('PRAGMA query_only = ON');
      });
      Map<String, Object?>? ocrResult;
      // Belegerkennung ohne Gerät: der Kanal liefert den Text des Demo-Belegs.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('buchhaltung/receipt_text'),
            (call) async => switch (call.method) {
              'isAvailable' => true,
              'recognize' => ocrResult,
              _ => null,
            },
          );
      await tester.runAsync(() => state.enterDemo(db, fromSettings: true));
      await _settle(tester);

      final out = Directory(p.join('build', 'screenshots', target.store));
      await tester.runAsync(() => out.create(recursive: true));
      Future<void> shot(String name) async {
        await _settle(tester);
        await _precacheImages(tester);
        await _settle(tester);
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await render.toImage(pixelRatio: target.ratio);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            p.join(out.path, '$name.png'),
          ).writeAsBytes(png!.buffer.asUint8List());
        });
      }

      final navigator = appNavigatorKey.currentState!;
      final repos = state.repositories;

      // 1 Übersicht, ans Ende gescrollt: unter der Aufnahmeleiste liegt
      // nur der Abstand, kein Betrag.
      await _scrollToEnd(tester, find.text('Kleinunternehmergrenze'));
      await shot('1_uebersicht');

      // 2 Beleg frisch fotografiert, Felder „erkannt – bitte prüfen“
      final receipts = (await tester.runAsync(() => repos.receipts.query()))!;
      final withImage = receipts.firstWhere((r) => r.hasImage);
      ocrResult = _ocrFor(withImage);
      final photo = (await tester.runAsync(
        () => ReceiptImageStore.resolve(withImage.imagePath),
      ))!;
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => ReceiptEditScreen(
            direction: BookingDirection.expense,
            sharedFiles: [photo],
          ),
        ),
      );
      await _settle(tester);
      // Hinweis „Beleg ausgelesen“ abwarten.
      await tester.pump(const Duration(seconds: 6));
      await shot('2_beleg');
      navigator.pop();
      await _settle(tester);

      // 3 Rechnungs-PDF
      final invoices = (await tester.runAsync(() => repos.invoices.all()))!;
      final invoice = invoices.firstWhere(
        (i) => i.status == InvoiceStatus.paid && !i.isCancellation,
        orElse: () => invoices.firstWhere((i) => !i.isCancellation),
      );
      final pagePng = (await tester.runAsync(() async {
        final customer = await repos.customers.byId(invoice.customerId);
        final (bytes, _) = await buildInvoicePdf(
          state,
          invoice,
          customer!,
          state.profile!,
        );
        return _rasterFirstPage(bytes);
      }))!;
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => PdfViewerScreen(
            title: 'Rechnung ${invoice.number}',
            fileName: 'Rechnung.pdf',
            bytes: Uint8List(0),
            rasterizer: (_) => Stream.value(MemoryImage(pagePng)),
          ),
        ),
      );
      await shot('3_rechnung_pdf');
      navigator.pop();
      await _settle(tester);

      // 4 Belegliste
      await tester.tap(find.text('Belege').last);
      await _settle(tester);
      // Tablet (Liste und Detail nebeneinander): einen Beleg zeigen.
      if (find.textContaining('Wähle links').evaluate().isNotEmpty) {
        await tester.tap(find.text(withImage.description).first);
        await _settle(tester);
      }
      await _scrollToEnd(tester, find.text('Oktober 2026').first);
      await shot('4_belegliste');

      // 5 Export
      await tester.tap(find.text('Export').last);
      await shot('5_export');

      // 6 Vertrag mit Seitenvorschau (Demo-Verträge haben kein Dokument)
      final contract = (await tester.runAsync(
        () => repos.contracts.all(),
      ))!.first;
      final page = p.join(ReceiptImageStore.demoFolder, 'vertrag_seite1.png');
      await tester.runAsync(
        () => File(p.join(docs.path, page)).writeAsBytes(_contractPage()),
      );
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ContractEditScreen(contract: contract.copyWith(pages: [page])),
        ),
      );
      await shot('6_vertraege');
      navigator.pop();
      await _settle(tester);

      // 7 Abo-Seite
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen()),
      );
      await shot('7_abo');
      navigator.pop();
      await _settle(tester);

      await tester.pumpWidget(const SizedBox());
      debugDisableShadows = true;
      await tester.runAsync(() => docs.delete(recursive: true));
    }, skip: !enabled);
  }
}

/// Antwort des Texterkennungs-Kanals: der Text des Demo-Belegs [r].
Map<String, Object?> _ocrFor(Receipt r) {
  final gross = Fmt.amount(r.gross);
  final vat = Fmt.amount(r.vat);
  final rows = [
    r.counterparty,
    'Datum ${Fmt.date(r.date)}',
    '${r.description} $gross',
    'SUMME EUR $gross',
    'MwSt ${r.vatPermille ~/ 10}% $vat',
  ];
  return {
    'engine': 'screenshot',
    'engineVersion': '1',
    'codes': <String>[],
    'lines': [
      for (var i = 0; i < rows.length; i++)
        {'text': rows[i], 'left': 16, 'top': 14 + i * 24, 'height': 16},
    ],
  };
}

/// Erste Vertragsseite als Musterbild.
Uint8List _contractPage() => DemoReceiptImage.render(
  title: 'Mietvertrag Atelier',
  lines: const [
    ('Vermieter: Hausverwaltung Muster', ''),
    ('Mieter: Musterunternehmen', ''),
    ('Mietbeginn 01.01.2024', ''),
    ('Kuendigungsfrist 3 Monate', ''),
    ('Miete monatlich', '450,00'),
    ('Nebenkosten', 'inkl.'),
  ],
  total: '450,00 EUR',
  footer: 'MUSTERVERTRAG - DEMO',
);

class _Target {
  const _Target(this.store, this.size, this.ratio);

  final String store;
  final Size size;
  final double ratio;
}

/// Liste mit [inside] ans Ende scrollen; die Aufnahmeleiste, die dabei
/// ausweicht, ist nach 5 s zurück.
Future<void> _scrollToEnd(WidgetTester tester, Finder inside) async {
  final scrollable = tester.state<ScrollableState>(
    find.ancestor(of: inside, matching: find.byType(Scrollable)).first,
  );
  // Lange Listen kennen ihr Ende erst nach dem Aufbau: bis es feststeht.
  for (var i = 0; i < 10; i++) {
    final end = scrollable.position.maxScrollExtent;
    scrollable.position.jumpTo(end);
    await tester.pump();
    if (scrollable.position.maxScrollExtent == end) break;
  }
  await tester.pump(const Duration(seconds: 6));
}

/// Laden außerhalb der Test-Uhr abwarten (Datenbank, Bilder).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(seconds: 1));
}

/// Alle sichtbaren Bilder dekodieren, sonst bleiben sie leer.
Future<void> _precacheImages(WidgetTester tester) async {
  final elements = find.byType(Image).evaluate().toList();
  await tester.runAsync(() async {
    for (final element in elements) {
      final widget = element.widget as Image;
      await precacheImage(widget.image, element);
    }
  });
}

/// Erste PDF-Seite als PNG über `pdftoppm` (poppler-utils); `printing`
/// rendert nur auf dem Gerät.
Future<Uint8List> _rasterFirstPage(Uint8List pdf) async {
  final dir = await Directory.systemTemp.createTemp('pdf_raster');
  try {
    final input = File(p.join(dir.path, 'in.pdf'));
    await input.writeAsBytes(pdf);
    final result = await Process.run('pdftoppm', [
      '-png',
      '-r',
      '144',
      '-f',
      '1',
      '-l',
      '1',
      '-singlefile',
      input.path,
      p.join(dir.path, 'page'),
    ]);
    if (result.exitCode != 0) {
      throw StateError('pdftoppm: ${result.stderr}');
    }
    return await File(p.join(dir.path, 'page.png')).readAsBytes();
  } finally {
    await dir.delete(recursive: true);
  }
}

/// Echte Schriften statt Ahem: Roboto und Material Icons aus dem
/// Flutter-SDK, Work Sans aus dem Projekt.
Future<void> _loadFonts() async {
  final root =
      Platform.environment['FLUTTER_ROOT'] ??
      p.dirname(p.dirname(Platform.resolvedExecutable));
  final material = Directory(
    p.join(root, 'bin', 'cache', 'artifacts', 'material_fonts'),
  );
  Future<void> load(String family, Iterable<File> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = await f.readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  final roboto = [
    for (final name in [
      'Roboto-Regular',
      'Roboto-Medium',
      'Roboto-Bold',
      'Roboto-Light',
      'Roboto-Italic',
    ])
      File(p.join(material.path, '$name.ttf')),
  ];
  await load('Roboto', roboto);
  await load('MaterialIcons', [
    File(p.join(material.path, 'MaterialIcons-Regular.otf')),
  ]);
  await load('WorkSans', [
    File('assets/fonts/WorkSans-Regular.ttf'),
    File('assets/fonts/WorkSans-Bold.ttf'),
  ]);
}
