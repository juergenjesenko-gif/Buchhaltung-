import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/features/onboarding/setup_wizard.dart';
import 'package:buchhaltung/services/licensing/fake_store_billing.dart';
import 'package:buchhaltung/services/licensing/license_cache.dart';
import 'package:buchhaltung/services/licensing/license_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Willkommensseite (FA-1.10): Unterzeile und Funktionsliste passen ohne
/// Scrollen auf 360×740 und 412×915. Mit echter Schrift (Work Sans als
/// Ersatz für Roboto), nicht der Testschrift Ahem, die jedes Zeichen ein
/// Geviert breit setzt.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('de');
    final font = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/WorkSans-Regular.ttf'));
    await font.load();
  });

  Future<Database> openDb() => databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: AppDatabase.schemaVersion,
      onCreate: AppDatabase.createSchema,
      singleInstance: false,
    ),
  );

  AppState stateFor(Database db) => AppState(
    Repositories(db),
    license: LicenseManager(
      cache: MemoryLicenseCache(),
      billing: FakeStoreBilling.new,
      enabled: false,
    ),
  );

  for (final size in const [Size(360, 740), Size(412, 915)]) {
    testWidgets('Willkommensseite passt ohne Scrollen auf $size', (
      tester,
    ) async {
      final db = (await tester.runAsync(openDb))!;
      final state = stateFor(db);
      await tester.runAsync(state.reload);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: const MaterialApp(home: SetupWizard()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(SetupWizard.welcomeSubline), findsOneWidget);
      for (final (_, text) in SetupWizard.welcomePoints) {
        final f = find.byKey(Key('welcome-point-$text'));
        expect(f, findsOneWidget);
        // Jede Zeile in einer Zeile, ohne Abschneiden.
        final widget = tester.widget<Text>(f);
        final painter = TextPainter(
          text: TextSpan(text: text, style: widget.style),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(tester.element(f)),
        )..layout();
        expect(
          painter.width,
          lessThanOrEqualTo(tester.getSize(f).width),
          reason: '„$text“ passt nicht in eine Zeile',
        );
      }
      expect(find.textContaining('Ich habe schon Daten'), findsNothing);
      expect(find.textContaining('Gerät koppeln'), findsNothing);
      // Seit 0.32.0 gebaut und getestet (FA-5.49, UWG P-R61).
      expect(find.text('Rechnungen & E-Rechnungen schreiben'), findsOne);
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scrollable.position.maxScrollExtent, 0);
    });
  }
}
