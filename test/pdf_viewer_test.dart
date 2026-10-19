import 'dart:typed_data';

import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/features/pdf_viewer/pdf_viewer_screen.dart';
import 'package:buchhaltung/services/demo/demo_mode.dart';
import 'package:buchhaltung/services/licensing/fake_store_billing.dart';
import 'package:buchhaltung/services/licensing/license_cache.dart';
import 'package:buchhaltung/services/licensing/license_manager.dart';
import 'package:buchhaltung/services/licensing/license_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// PDF-Betrachter (FA-5.48): Seiten, Seitenanzeige, Leiste, Demo-Sperre.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  tearDown(() {
    DemoMode.active = false;
    DemoMode.onBlocked = null;
  });

  Future<Database> openDb() => databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: AppDatabase.schemaVersion,
      onCreate: AppDatabase.createSchema,
      singleInstance: false,
    ),
  );

  // 1×1-PNG als Seitenbild; echte PDF-Rasterung braucht die Plattform.
  final pixel = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
    0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00,
    0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  Stream<ImageProvider> twoPages(Uint8List _) =>
      Stream.fromIterable([MemoryImage(pixel), MemoryImage(pixel)]);

  Future<(AppState, List<String>)> pump(
    WidgetTester tester, {
    bool demo = false,
  }) async {
    final db = (await tester.runAsync(openDb))!;
    final state = AppState(
      Repositories(db),
      license: LicenseManager(
        cache: MemoryLicenseCache(),
        billing: FakeStoreBilling.new,
        enabled: false,
      ),
    );
    await tester.runAsync(state.reload);
    if (demo) {
      final demoDb = (await tester.runAsync(openDb))!;
      await tester.runAsync(
        () => state.enterDemo(demoDb, onLeave: () async {}),
      );
    }
    final printed = <String>[];
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          home: PdfViewerScreen(
            title: 'Rechnung 1',
            fileName: 'Rechnung_1.pdf',
            bytes: Uint8List.fromList([1, 2, 3]),
            sendFeature: Feature.pdfSending,
            rasterizer: twoPages,
            printer: (_, name) async => printed.add(name),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (state, printed);
  }

  testWidgets('Seiten wischen, Seitenanzeige, Leiste 56 dp, Drucken frei', (
    tester,
  ) async {
    final (_, printed) = await pump(tester);
    expect(find.text('Seite 1 von 2'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('pdf-pages')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Seite 2 von 2'), findsOneWidget);
    for (final key in ['pdf-close', 'pdf-print', 'pdf-send']) {
      final f = find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      expect(tester.getSize(f).height, greaterThanOrEqualTo(56), reason: key);
      // Daumenzone: unteres Drittel.
      expect(tester.getCenter(f).dy, greaterThan(740 * 2 / 3));
    }
    expect(find.byType(InteractiveViewer), findsWidgets);
    await tester.tap(find.byKey(const Key('pdf-print')));
    await tester.pumpAndSettle();
    expect(printed, ['Rechnung_1.pdf']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Demo: Drucken und Senden zeigen das Hinweisblatt', (
    tester,
  ) async {
    final (state, printed) = await pump(tester, demo: true);
    expect(state.isDemo, isTrue);
    expect(find.textContaining('Demo: Senden und Drucken'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pdf-print')));
    await tester.pumpAndSettle();
    expect(printed, isEmpty);
    expect(find.byType(BottomSheet), findsOneWidget);
  });
}
