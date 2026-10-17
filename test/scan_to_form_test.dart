import 'dart:io';

import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/features/dashboard/dashboard_screen.dart';
import 'package:buchhaltung/features/receipts/receipt_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'dashboard_refresh_test.dart' show settle;

/// Gerätetest 0.22.0 (Pixel): nach dem Scan blieb das Belegformular leer –
/// kein Seitenbild, kein „Erneut auslesen“, keine Vorbelegung. Fake-Scanner
/// über den Channel mit echten JPEG-Bytes, Weg wie auf dem Gerät.
void main() {
  const scannerChannel = MethodChannel('buchhaltung/document_scanner');
  const textChannel = MethodChannel('buchhaltung/receipt_text');
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  const pickerChannel = MethodChannel('buchhaltung/document_picker');
  const galleryChannel = MethodChannel('plugins.flutter.io/image_picker');

  late Directory root;
  late List<String> recognized;
  late Object? Function(MethodCall call) scannerAnswer;

  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting('de');
  });

  /// Echte JPEG-Datei im „Cache“ des Scanners.
  String jpegPage(String name) {
    final image = img.Image(width: 300, height: 400);
    img.fill(image, color: img.ColorRgb8(235, 232, 225));
    img.fillRect(
      image,
      x1: 20,
      y1: 20,
      x2: 200,
      y2: 60,
      color: img.ColorRgb8(20, 20, 20),
    );
    final file = File('${root.path}/cache/$name')
      ..createSync(recursive: true)
      ..writeAsBytesSync(Uint8List.fromList(img.encodeJpg(image)));
    return file.path;
  }

  Future<Database> pump(WidgetTester tester) async {
    root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('scan_form'),
    ))!;
    addTearDown(() => root.deleteSync(recursive: true));
    recognized = [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pathChannel, (call) async {
      return '${root.path}/docs';
    });
    messenger.setMockMethodCallHandler(textChannel, (call) async {
      if (call.method == 'isAvailable') return true;
      recognized.add((call.arguments as Map)['path'] as String);
      return {
        'engine': 'test',
        'engineVersion': '1',
        'lines': [
          {'text': 'Papierladen GmbH', 'left': 0, 'top': 0, 'height': 10},
          {'text': 'SUMME EUR 12,00', 'left': 0, 'top': 40, 'height': 10},
        ],
      };
    });
    messenger.setMockMethodCallHandler(
      scannerChannel,
      (call) async => scannerAnswer(call),
    );
    messenger.setMockMethodCallHandler(
      pickerChannel,
      (call) async => [jpegPage('gewaehlt.jpg')],
    );
    messenger.setMockMethodCallHandler(
      galleryChannel,
      (call) async => jpegPage('galerie.jpg'),
    );
    addTearDown(() {
      for (final c in [
        scannerChannel,
        textChannel,
        pathChannel,
        pickerChannel,
        galleryChannel,
      ]) {
        messenger.setMockMethodCallHandler(c, null);
      }
    });
    final db = (await tester.runAsync(
      () => databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: AppDatabase.schemaVersion,
          onCreate: AppDatabase.createSchema,
          singleInstance: false,
        ),
      ),
    ))!;
    AppDatabase.instance.overrideDatabaseForTesting(db);
    await tester.runAsync(
      () => db.insert('company_profile', {
        'id': 1,
        'company_name': 'Test',
        'is_small_business': 0,
      }),
    );
    final state = AppState(Repositories(db));
    await tester.runAsync(state.reload);
    tester.view.physicalSize = const Size(412, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await settle(tester);
    return db;
  }

  Future<void> settleLong(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await settle(tester);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    }
  }

  /// Erkennung auf den abgelegten Seiten; Aufrufe auf dem unverbesserten
  /// Scan-Original (nur Codes, FA-2.62) liegen im Cache und zählen nicht.
  List<String> stored() => [
    for (final p in recognized)
      if (!p.contains('/cache/')) p,
  ];

  void expectScannedForm(WidgetTester tester, {int pages = 1}) {
    expect(find.byType(ReceiptEditScreen), findsOneWidget);
    expect(find.text('Seite $pages'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    expect(find.text('Erneut auslesen'), findsOneWidget);
    expect(stored(), hasLength(pages));
  }

  testWidgets('Scan von der Übersicht: Seitenbild, Auslesen, Vorbelegung', (
    tester,
  ) async {
    scannerAnswer = (_) => [jpegPage('scan_1.jpg')];
    final db = await pump(tester);
    await tester.tap(find.byKey(const Key('dashboard-photo')));
    await settleLong(tester);
    expectScannedForm(tester);
    await tester.runAsync(db.close);
  });

  testWidgets('Scan im Formular über den runden Knopf', (tester) async {
    scannerAnswer = (_) => [jpegPage('scan_2.jpg')];
    final db = await pump(tester);
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<bool>(
            builder: (_) =>
                const ReceiptEditScreen(direction: BookingDirection.expense),
          ),
        );
    await settleLong(tester);
    expect(find.text('Seite 1'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('receipt-add-page')));
    await settleLong(tester);
    expectScannedForm(tester);
    await tester.runAsync(db.close);
  });

  testWidgets('Nicht verbesserbare Seite: Original bleibt, wird ausgelesen', (
    tester,
  ) async {
    scannerAnswer = (_) {
      final file = File('${root.path}/cache/kaputt.jpg')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3, 4]);
      return [file.path];
    };
    final db = await pump(tester);
    await tester.tap(find.byKey(const Key('dashboard-photo')));
    await settleLong(tester);
    expect(find.text('Seite 1'), findsOneWidget);
    expect(find.text('Erneut auslesen'), findsOneWidget);
    expect(stored(), hasLength(1));
    await tester.runAsync(db.close);
  });

  testWidgets('Scan-Fehler: Meldung statt leerem Formular', (tester) async {
    scannerAnswer = (_) => throw PlatformException(
      code: 'lost',
      message: 'Das Scan-Ergebnis ist nicht in der App angekommen.',
    );
    final db = await pump(tester);
    await tester.tap(find.byKey(const Key('dashboard-photo')));
    await settleLong(tester);
    expect(find.byType(SnackBar), findsWidgets);
    expect(find.textContaining('nicht in der App angekommen'), findsWidgets);
    expect(recognized, isEmpty);
    await tester.runAsync(db.close);
  });

  for (final (button, label) in [
    ('dashboard-gallery', 'Foto'),
    ('dashboard-file', 'Datei'),
  ]) {
    testWidgets('Übersicht „$label“: neues Formular mit Seite und Auslesen', (
      tester,
    ) async {
      scannerAnswer = (_) => throw StateError('Scanner nicht erwartet');
      final db = await pump(tester);
      await tester.tap(find.byKey(Key(button)));
      await settleLong(tester);
      expectScannedForm(tester);
      await tester.runAsync(db.close);
    });
  }
}
