import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/legal_texts.dart';
import 'package:buchhaltung/domain/company_profile.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/tax_registration.dart';
import 'package:buchhaltung/features/helper/helper_help_sheet.dart';
import 'package:buchhaltung/features/settings/tax_registration_screen.dart';
import 'package:buchhaltung/features/onboarding/setup_wizard.dart';
import 'package:buchhaltung/services/licensing/fake_store_billing.dart';
import 'package:buchhaltung/services/licensing/license_cache.dart';
import 'package:buchhaltung/services/licensing/license_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Geführte Ersteinrichtung (FA-1.13): Schrittfolge, Überspringen,
/// Fortsetzen nach dem Schließen, Daumenmaße (UX-Prüfinstanz).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('de');
    // Echte Schrift statt Ahem: die Willkommensseite ist auf echte
    // Zeichenbreiten ausgelegt (welcome_page_test.dart).
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

  Future<AppState> pump(WidgetTester tester, Database db) async {
    final state = stateFor(db);
    await tester.runAsync(state.reload);
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: SetupWizard()),
      ),
    );
    await tester.pumpAndSettle();
    return state;
  }

  /// Datenbankarbeit läuft außerhalb der Test-Uhr.
  Future<void> tapAndWait(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  void expectThumbButton(WidgetTester tester, Finder f, {double min = 48}) {
    expect(f, findsOneWidget);
    expect(tester.getSize(f).height, greaterThanOrEqualTo(min));
  }

  testWidgets('Schritte 1 bis 4: bestätigen, Pflichtangaben, überspringen, '
      'fertig; Fortsetzen nach dem Schließen', (tester) async {
    final db = (await tester.runAsync(openDb))!;
    var state = await pump(tester, db);

    // Willkommensseite mit Logo und allen Wegen.
    expect(find.byKey(const Key('welcome-logo')), findsOneWidget);
    expectThumbButton(tester, find.byKey(const Key('welcome-start')), min: 56);
    expectThumbButton(tester, find.byKey(const Key('welcome-demo')), min: 56);
    expectThumbButton(tester, find.byKey(const Key('welcome-restore')));
    expect(find.byKey(const Key('welcome-helper')), findsNothing);
    expect(find.text('Sicherung wiederherstellen'), findsOneWidget);
    expect(
      tester.getCenter(find.byKey(const Key('welcome-start'))).dy,
      greaterThan(740 * 2 / 3),
    );

    // Schritt 1: ein Häkchen plus ein Knopf.
    await tester.tap(find.byKey(const Key('welcome-start')));
    await tester.pumpAndSettle();
    expect(find.text('Schritt 1 von 4'), findsOneWidget);
    final accept = find.byKey(const Key('consent-accept'));
    expectThumbButton(tester, accept, min: 56);
    expect(tester.widget<FilledButton>(accept).onPressed, isNull);
    expect(find.byKey(const Key('consent-open-terms')), findsOneWidget);
    expect(find.byKey(const Key('consent-open-privacy')), findsOneWidget);
    expect(find.text('Akzeptieren und weiter'), findsOneWidget);
    await tester.tap(find.byKey(const Key('consent-disclaimer')));
    await tester.pump();
    await tapAndWait(tester, accept);
    expect(state.missingConsents, isEmpty);

    // Schritt 2: Pflichtfeld.
    expect(find.text('Schritt 2 von 4'), findsOneWidget);
    // Mithelfer-Gerät nur als Nebenoption, keine Pflichtfrage.
    expectThumbButton(tester, find.byKey(const Key('setup-helper')));
    final next = find.byKey(const Key('setup-next'));
    expectThumbButton(tester, next, min: 56);
    expect(find.byKey(const Key('setup-skip')), findsNothing);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('Bitte gib einen Namen oder eine Firma an'), findsOne);
    await tester.enterText(
      find.byKey(const Key('setup-companyName')),
      'Anna Test e.U.',
    );
    await tester.ensureVisible(find.text('Regelbesteuerung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Regelbesteuerung'));
    await tester.pump();
    await tapAndWait(tester, next);
    expect(state.profile?.companyName, 'Anna Test e.U.');
    expect(state.profile?.isSmallBusiness, isFalse);
    expect(state.setupStep, SetupPage.details.index);

    // Schritt 3: optional, „Später hinzufügen“ ≥ 48 dp, Abstand zum
    // Hauptknopf.
    expect(find.text('Schritt 3 von 4'), findsOneWidget);
    final skip = find.byKey(const Key('setup-skip'));
    expectThumbButton(tester, skip);
    expect(find.text(SetupWizard.skipLabel), findsOneWidget);
    expect(
      tester.getTopLeft(next).dy - tester.getBottomLeft(skip).dy,
      greaterThanOrEqualTo(SetupWizard.gap),
    );

    // App „geschlossen“: neuer Zustand aus derselben Datenbank.
    await tester.pumpWidget(const SizedBox());
    state = await pump(tester, db);
    expect(state.inFirstRunSetup, isTrue);
    expect(find.text('Schritt 3 von 4'), findsOneWidget);

    // Zurück zu Schritt 2 mit den gespeicherten Angaben.
    await tapAndWait(tester, find.byKey(const Key('setup-back')));
    expect(find.text('Schritt 2 von 4'), findsOneWidget);
    expect(find.text('Anna Test e.U.'), findsOneWidget);
    await tapAndWait(tester, find.byKey(const Key('setup-next')));

    // UID mit falschem Format blockiert Weiter, Überspringen nicht.
    await tester.enterText(find.byKey(const Key('setup-vatId')), 'ATU1');
    await tester.tap(find.byKey(const Key('setup-next')));
    await tester.pumpAndSettle();
    expect(find.text('Schritt 3 von 4'), findsOneWidget);
    await tapAndWait(tester, find.byKey(const Key('setup-skip')));

    // Schritt 4: Extras, ohne Abo-Schritt im Testbuild „Fertig“.
    expect(find.text('Schritt 4 von 4'), findsOneWidget);
    for (final k in ['setup-logo', 'setup-backup', 'setup-registrations']) {
      await tester.ensureVisible(find.byKey(Key(k)));
      expectThumbButton(tester, find.byKey(Key(k)));
    }
    expect(find.text('Fertig'), findsOneWidget);
    await tapAndWait(tester, find.byKey(const Key('setup-next')));
    expect(state.setupStep, isNull);
    expect(state.inFirstRunSetup, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });

  testWidgets('Entwurf von Schritt 2 übersteht das Schließen', (tester) async {
    final db = (await tester.runAsync(openDb))!;
    await tester.runAsync(
      () => Repositories(db).consents.accept(LegalText.all),
    );
    await pump(tester, db);
    await tester.tap(find.byKey(const Key('welcome-start')));
    await tester.pumpAndSettle();
    expect(find.text('Schritt 2 von 4'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('setup-companyName')),
      'Entwurf GmbH',
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpWidget(const SizedBox());
    await pump(tester, db);
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
    expect(find.text('Entwurf GmbH'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });

  testWidgets('Hilfe zum Mithelfer-Gerät: ?-Knopf 48 dp öffnet das Blatt', (
    tester,
  ) async {
    final db = (await tester.runAsync(openDb))!;
    await pump(tester, db);
    // Seit 0.31.0 in Schritt 2 statt auf der Willkommensseite.
    expect(find.byKey(const Key('helper-help')), findsNothing);
    await tester.tap(find.byKey(const Key('welcome-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('consent-disclaimer')));
    await tester.pump();
    await tapAndWait(tester, find.byKey(const Key('consent-accept')));
    final help = find.byKey(const Key('helper-help'));
    expect(tester.getSize(help).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(help).height, greaterThanOrEqualTo(48));
    await tester.tap(help);
    await tester.pumpAndSettle();
    expect(find.text(helperHelpTitle), findsOneWidget);
    expect(find.textContaining('verschlüsselt'), findsOneWidget);
    expect(find.textContaining('eigenen'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('helper-help-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('helper-help-close')));
    await tester.pumpAndSettle();
    expect(find.text(helperHelpTitle), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });

  testWidgets('EU-KU-Verfahren: Feld „EU-KU-Nummer (EX)“ mit Formatprüfung, '
      'gespeichert im Profil getrennt von der UID', (tester) async {
    final db = (await tester.runAsync(openDb))!;
    final state = stateFor(db);
    await tester.runAsync(
      () => Repositories(db).company.save(
        const CompanyProfile(
          companyName: 'Anna',
          country: Country.at,
          vatId: 'ATU12345675',
        ),
      ),
    );
    await tester.runAsync(state.reload);
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(
          home: TaxRegistrationScreen(
            registration: TaxRegistration(
              country: Country.de,
              scheme: VatScheme.euSmallBusiness,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('EU-KU-Nummer (EX)'), findsOneWidget);
    expect(find.byKey(const Key('registration-vat-id')), findsNothing);
    final field = find.byKey(const Key('registration-eu-sme-id'));
    await tester.enterText(field, 'ATU12345675');
    await tester.tap(find.byKey(const Key('registration-save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('endet auf EX'), findsOneWidget);
    await tester.enterText(field, 'ATU12345675EX');
    await tapAndWait(tester, find.byKey(const Key('registration-save')));
    expect(state.profile!.euSmeId, 'ATU12345675EX');
    expect(state.profile!.vatId, 'ATU12345675');
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });

  test('Mithelfer nur ohne Buchhaltungsdaten (FA-17.13)', () async {
    final db = await openDb();
    final repos = Repositories(db);
    expect(await repos.helpers.hasBookkeepingData(), isFalse);
    await db.insert('receipts', {
      'date': '2026-10-19',
      'direction': 'expense',
      'created_at': '2026-10-19',
      'updated_at': '2026-10-19',
      'description': 'Test',
      'gross_cents': 100,
      'net_cents': 100,
      'vat_cents': 0,
      'vat_permille': 0,
    });
    expect(await repos.helpers.hasBookkeepingData(), isTrue);
    await db.close();
  });
}
