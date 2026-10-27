import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/features/onboarding/setup_wizard.dart';
import 'package:buchhaltung/services/licensing/fake_store_billing.dart';
import 'package:buchhaltung/services/licensing/license_cache.dart';
import 'package:buchhaltung/services/licensing/license_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:buchhaltung/l10n/l10n.dart';
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

  // Englisch seit FA-1.20 (L-34.1): gleiche Anforderung an die Zeilenbreite.
  for (final lang in const ['de', 'en']) {
    for (final size in const [Size(360, 740), Size(412, 915)]) {
      testWidgets('Willkommensseite ($lang) passt ohne Scrollen auf $size', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(Locale(lang));
        final db = (await tester.runAsync(openDb))!;
        final state = stateFor(db);
        await tester.runAsync(state.reload);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          AppScope(
            state: state,
            child: MaterialApp(
              locale: Locale(lang),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: const SetupWizard(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(SetupWizard.welcomeSubline(l10n)), findsOneWidget);
        for (final (_, text) in SetupWizard.welcomePoints(l10n)) {
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
        // Endgültiges Hauptlogo, 280 dp breit (DESIGN_SPEC 10a).
        final logo = tester.widget<Image>(
          find.byKey(const Key('welcome-logo')),
        );
        expect((logo.image as AssetImage).assetName, brandLogoAsset);
        expect(
          tester.getSize(find.byKey(const Key('welcome-logo'))).width,
          280,
        );
        expect(find.textContaining('Ich habe schon Daten'), findsNothing);
        expect(find.textContaining('Gerät koppeln'), findsNothing);
        // Seit 0.32.0 gebaut und getestet (FA-5.49, UWG P-R61).
        expect(find.text(l10n.setupPointInvoices), findsOne);
        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        expect(scrollable.position.maxScrollExtent, 0);
      });
    }
  }

  testWidgets('Dunkelmodus zeigt das helle Logo', (tester) async {
    final db = (await tester.runAsync(openDb))!;
    final state = stateFor(db);
    await tester.runAsync(state.reload);
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: const SetupWizard(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final logo = tester.widget<Image>(find.byKey(const Key('welcome-logo')));
    expect((logo.image as AssetImage).assetName, brandLogoDarkAsset);
  });
}
