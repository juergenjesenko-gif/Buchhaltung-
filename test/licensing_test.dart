import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/features/licensing/feature_gate.dart';
import 'package:buchhaltung/features/licensing/subscription_screen.dart';
import 'package:buchhaltung/services/licensing/fake_store_billing.dart';
import 'package:buchhaltung/services/licensing/license_cache.dart';
import 'package:buchhaltung/services/licensing/license_manager.dart';
import 'package:buchhaltung/services/licensing/license_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Lizenz und Abo (Lastenheft 5.10, 5.22; Spezifikation FA-12).
void main() {
  final day0 = DateTime(2026, 11, 1);

  group('Anspruch', () {
    test('Tarifschnitt: Erkennung nur Pro, Buchen ab Basis, Lesen immer', () {
      expect(Entitlement.pro.allows(Feature.receiptRecognition), isTrue);
      expect(Entitlement.basis.allows(Feature.receiptRecognition), isFalse);
      expect(Entitlement.basis.allows(Feature.newBookings), isTrue);
      expect(Entitlement.readOnly.allows(Feature.newBookings), isFalse);
      expect(Entitlement.none.allows(Feature.newBookings), isFalse);
    });

    test('Pro-Funktionen (Entscheidung 2026-10-15): nur Pro', () {
      const proOnly = [
        Feature.receiptRecognition,
        Feature.dataImport,
        Feature.taxOfficeSubmission,
        Feature.pdfSending,
        Feature.dunningSending,
        Feature.invoiceLogo,
        Feature.exchangeRateFetch,
      ];
      for (final feature in proOnly) {
        expect(Entitlement.pro.allows(feature), isTrue, reason: '$feature');
        for (final e in [
          Entitlement.basis,
          Entitlement.readOnly,
          Entitlement.none,
        ]) {
          expect(e.allows(feature), isFalse, reason: '$e $feature');
        }
      }
      // Jede Funktion ist entweder Pro oder ab Basis – keine vergessen.
      expect(Feature.values.toSet(), {...proOnly, Feature.newBookings});
      expect(Entitlement.pro.allows(Feature.newBookings), isTrue);
    });

    test('Jede gesperrte Funktion hat eine Begründung', () {
      for (final feature in Feature.values) {
        expect(featureReason(feature), isNotEmpty);
      }
    });

    test('Offline gilt der bestätigte Stand 45 Tage, danach nur lesen', () {
      final record = LicenseRecord(
        tier: Tier.basis,
        checkedAt: day0,
        everSubscribed: true,
      );
      expect(
        LicensePolicy.entitlement(record, day0.add(const Duration(days: 44))),
        Entitlement.basis,
      );
      expect(
        LicensePolicy.needsOnlineCheck(
          record,
          day0.add(const Duration(days: 31)),
        ),
        isTrue,
      );
      expect(
        LicensePolicy.entitlement(record, day0.add(const Duration(days: 45))),
        Entitlement.readOnly,
      );
      expect(
        LicensePolicy.entitlement(const LicenseRecord(), day0),
        Entitlement.none,
      );
    });

    test('Erinnerung 3 Tage vor Testende', () {
      final record = LicenseRecord(
        tier: Tier.pro,
        checkedAt: day0,
        everSubscribed: true,
        trialStartedAt: day0,
      );
      expect(
        LicensePolicy.trialReminder(record, day0.add(const Duration(days: 10))),
        isNull,
      );
      expect(
        LicensePolicy.trialReminder(record, day0.add(const Duration(days: 11))),
        day0.add(const Duration(days: 14)),
      );
      expect(
        LicensePolicy.trialReminder(record, day0.add(const Duration(days: 14))),
        isNull,
      );
    });

    test('Stand übersteht Speichern und Laden', () async {
      final store = <String, String>{};
      final cache = KeyValueLicenseCache(
        read: (k) async => store[k],
        write: (k, v) async => store[k] = v,
      );
      await cache.save(
        LicenseRecord(tier: Tier.pro, checkedAt: day0, everSubscribed: true),
      );
      final loaded = await cache.load();
      expect(loaded.tier, Tier.pro);
      expect(loaded.checkedAt, day0);
      expect(loaded.everSubscribed, isTrue);
      store[KeyValueLicenseCache.key] = 'kaputt';
      expect((await cache.load()).tier, isNull);
    });
  });

  group('Lizenzmanager', () {
    late FakeStoreBilling store;
    late MemoryLicenseCache cache;
    var now = day0;

    LicenseManager manager({bool enabled = true}) => LicenseManager(
      cache: cache,
      billing: () => store,
      enabled: enabled,
      clock: () => now,
    );

    setUp(() {
      store = FakeStoreBilling();
      cache = MemoryLicenseCache();
      now = day0;
    });

    test('Testbuild ohne Lizenzprüfung: voller Umfang', () async {
      final m = manager(enabled: false);
      await m.init();
      await m.refresh();
      expect(m.entitlement, Entitlement.pro);
      expect(store.bought, isEmpty);
    });

    test('Kauf von Pro startet den Test und schaltet frei', () async {
      final m = manager();
      await m.init();
      await m.refresh();
      expect(m.entitlement, Entitlement.none);
      expect(m.offers!.map((o) => o.price), contains('24,90 €'));
      final pro = m.offers!.firstWhere((o) => o.product.id == 'pro_monat');
      await m.buy(pro);
      await pumpEventQueue();
      expect(m.entitlement, Entitlement.pro);
      expect(cache.record.trialStartedAt, day0);
    });

    test(
      'Wechsel Basis → Pro ersetzt das Abo statt es zu verdoppeln',
      () async {
        store.active = {'basis_monat'};
        final m = manager();
        await m.refresh();
        expect(m.entitlement, Entitlement.basis);
        await m.buy(m.offers!.firstWhere((o) => o.product.id == 'pro_jahr'));
        expect(store.lastReplaced, 'basis_monat');
        await pumpEventQueue();
        expect(m.entitlement, Entitlement.pro);
        expect(cache.record.trialStartedAt, isNull, reason: 'kein Neukunde');
      },
    );

    test('Offline senkt nie; Store ohne Abo stuft herab mit Hinweis', () async {
      store.active = {'pro_monat'};
      final m = manager();
      await m.refresh();
      expect(m.entitlement, Entitlement.pro);

      store.online = false;
      store.active = {};
      now = day0.add(const Duration(days: 20));
      await m.refresh();
      expect(m.entitlement, Entitlement.pro);

      store.online = true;
      await m.refresh();
      expect(m.entitlement, Entitlement.readOnly);
      expect(m.downgradedFrom, Tier.pro);
      await m.acknowledgeDowngrade();
      expect(m.downgradedFrom, isNull);
    });

    test('Pro endet, Basis bleibt: Herabstufung auf Basis', () async {
      store.active = {'pro_monat', 'basis_jahr'};
      final m = manager();
      await m.refresh();
      expect(m.entitlement, Entitlement.pro);
      store.active = {'basis_jahr'};
      expect(await m.restore(), 'Basis ist aktiv.');
      expect(m.entitlement, Entitlement.basis);
    });
  });

  group('Abo-Seite', () {
    setUpAll(() async {
      sqfliteFfiInit();
      await initializeDateFormatting('de');
    });

    Future<(AppState, FakeStoreBilling)> pump(
      WidgetTester tester,
      Widget home, {
      Set<String>? active,
    }) async {
      final db = await tester.runAsync(
        () => databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            version: AppDatabase.schemaVersion,
            onCreate: AppDatabase.createSchema,
            singleInstance: false,
          ),
        ),
      );
      final store = FakeStoreBilling(active: active);
      final state = AppState(
        Repositories(db!),
        license: LicenseManager(
          cache: MemoryLicenseCache(
            LicenseRecord(everSubscribed: active == null),
          ),
          billing: () => store,
          enabled: true,
        ),
      );
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(home: home),
        ),
      );
      await tester.runAsync(state.license.init);
      await tester.runAsync(state.license.refresh);
      await tester.pumpAndSettle();
      return (state, store);
    }

    testWidgets('Preise aus dem Store, Pflichtangaben und Links', (
      tester,
    ) async {
      await pump(tester, const SubscriptionScreen(), active: {});
      expect(find.text('24,90 € pro Monat'), findsOneWidget);
      expect(find.text('14 Tage kostenlos testen'), findsOneWidget);
      await tester.tap(find.text('Jährlich'));
      await tester.pumpAndSettle();
      expect(find.text('238,90 € pro Jahr'), findsOneWidget);
      for (final key in [
        'subscription-period',
        'subscription-buy-pro',
        'subscription-buy-basis',
        'subscription-terms',
        'subscription-restore',
        'subscription-manage',
        'subscription-terms-link',
        'subscription-privacy-link',
      ]) {
        final f = find.byKey(Key(key));
        await tester.scrollUntilVisible(f, 100);
        expect(tester.getSize(f).height, greaterThanOrEqualTo(48), reason: key);
      }
      expect(
        find.textContaining('verlängert sich automatisch um ein Jahr'),
        findsOneWidget,
      );
    });

    testWidgets('Nur lesen: Buchen öffnet die Abo-Seite, Kauf gibt frei', (
      tester,
    ) async {
      bool? result;
      final (state, _) = await pump(
        tester,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async =>
                  result = await ensureFeature(context, Feature.newBookings),
              child: const Text('Buchen'),
            ),
          ),
        ),
      );
      expect(state.entitlement, Entitlement.readOnly);
      await tester.tap(find.text('Buchen'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Neue Buchungen brauchen ein Abo'), findsOne);
      final basis = find.byKey(const Key('subscription-buy-basis'));
      await tester.dragUntilVisible(
        basis,
        find.byType(ListView),
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();
      expect(find.text('Basis wählen'), findsOneWidget);
      await tester.tap(basis);
      await tester.pumpAndSettle();
      expect(state.entitlement, Entitlement.basis);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });
}
