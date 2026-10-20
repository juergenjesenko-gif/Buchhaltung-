import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/services/assets/depreciation.dart';
import 'package:buchhaltung/features/licensing/feature_gate.dart';
import 'package:buchhaltung/features/licensing/subscription_screen.dart';
import 'package:buchhaltung/services/licensing/fake_store_billing.dart';
import 'package:buchhaltung/services/licensing/license_cache.dart';
import 'package:buchhaltung/services/licensing/license_manager.dart';
import 'package:buchhaltung/services/licensing/license_policy.dart';
import 'package:buchhaltung/services/licensing/store_billing.dart';
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
        Feature.annualReports,
        Feature.levyReserve,
        Feature.contractSummary,
        Feature.assetManagement,
        Feature.bookingRules,
        Feature.helperDevices,
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
      // Jede Funktion ist entweder Pro, ab Basis oder Export – keine
      // vergessen.
      expect(Feature.values.toSet(), {
        ...proOnly,
        Feature.newBookings,
        Feature.eInvoiceIssue,
        Feature.dataExport,
      });
      // O-44: E-Rechnung ausstellen ab Basis, ohne Abo und in der Demo nicht.
      expect(Entitlement.basis.allows(Feature.eInvoiceIssue), isTrue);
      expect(Entitlement.pro.allows(Feature.eInvoiceIssue), isTrue);
      expect(Entitlement.readOnly.allows(Feature.eInvoiceIssue), isFalse);
      expect(Entitlement.none.allows(Feature.eInvoiceIssue), isFalse);
      expect(Entitlement.demo.allows(Feature.eInvoiceIssue), isFalse);
      expect(Entitlement.pro.allows(Feature.newBookings), isTrue);
    });

    test(
      'GWG-Hinweis ohne Pro nur über der Grenze (Entscheidung 2026-10-16)',
      () {
        final at = TaxProfile.austria.depreciation;
        final de = TaxProfile.germany.depreciation;
        expect(
          Depreciation.exceedsGwg(const Money(100000), const Money(83333), at),
          isFalse,
        );
        expect(
          Depreciation.exceedsGwg(const Money(100001), const Money(83334), at),
          isTrue,
        );
        expect(
          Depreciation.exceedsGwg(const Money(95200), const Money(80000), de),
          isFalse,
        );
        expect(
          Depreciation.exceedsGwg(const Money(95201), const Money(80001), de),
          isTrue,
        );
      },
    );

    group('Anspruchsmatrix (O-42, FA-13.4, FA-13.14)', () {
      LicenseRecord sub(Tier tier, {bool? intro, DateTime? start}) =>
          LicenseRecord(
            tier: tier,
            checkedAt: day0,
            everSubscribed: true,
            trialStartedAt: start ?? day0,
            introOffer: intro,
          );

      test('kein Abo → keine Buchungen, Startauswahl mit Demo', () {
        final e = LicensePolicy.entitlement(const LicenseRecord(), day0);
        expect(e, Entitlement.none);
        expect(e.allows(Feature.newBookings), isFalse);
        expect(e.allows(Feature.dataExport), isTrue);
      });

      test('Demo: ansehen und ausprobieren, nichts speichern oder teilen', () {
        const d = Entitlement.demo;
        expect(d.allows(Feature.receiptRecognition), isTrue);
        expect(d.allows(Feature.exchangeRateFetch), isTrue);
        expect(d.allows(Feature.annualReports), isTrue);
        expect(d.allows(Feature.levyReserve), isTrue);
        for (final f in [
          Feature.newBookings,
          Feature.dataExport,
          Feature.pdfSending,
          Feature.dunningSending,
          Feature.helperDevices,
          Feature.dataImport,
          Feature.taxOfficeSubmission,
          Feature.assetManagement,
          Feature.contractSummary,
          Feature.invoiceLogo,
        ]) {
          expect(d.allows(f), isFalse, reason: '$f');
        }
      });

      test('Basis in der Testzeit → Pro, danach Basis, Daten bleiben', () {
        final r = sub(Tier.basis);
        final in13 = day0.add(const Duration(days: 13, hours: 23));
        expect(LicensePolicy.entitlement(r, in13), Entitlement.pro);
        expect(
          LicensePolicy.proIncludedUntil(r, in13),
          day0.add(const Duration(days: 14)),
        );
        final after = day0.add(const Duration(days: 14));
        expect(LicensePolicy.entitlement(r, after), Entitlement.basis);
        expect(LicensePolicy.proIncludedUntil(r, after), isNull);
        expect(
          LicensePolicy.entitlement(r, after).allows(Feature.newBookings),
          isTrue,
        );
      });

      test('Pro bleibt Pro; abgelaufen → nur lesen, Export bleibt', () {
        final pro = sub(Tier.pro);
        expect(
          LicensePolicy.entitlement(pro, day0.add(const Duration(days: 30))),
          Entitlement.pro,
        );
        const expired = LicenseRecord(everSubscribed: true);
        final e = LicensePolicy.entitlement(expired, day0);
        expect(e, Entitlement.readOnly);
        expect(e.allows(Feature.newBookings), isFalse);
        expect(e.allows(Feature.dataExport), isTrue);
      });

      test('iOS meldet kein Einführungsangebot → kein Pro inklusive', () {
        final r = sub(Tier.basis, intro: false);
        expect(LicensePolicy.entitlement(r, day0), Entitlement.basis);
        expect(LicensePolicy.trialReminder(r, day0), isNull);
        final yes = sub(Tier.basis, intro: true);
        expect(LicensePolicy.entitlement(yes, day0), Entitlement.pro);
      });

      test('Erinnerung 3 Tage vorher: „Noch X Tage Pro inklusive“', () {
        final r = sub(Tier.basis);
        final at = day0.add(const Duration(days: 11, hours: 1));
        final end = LicensePolicy.trialReminder(r, at);
        expect(end, day0.add(const Duration(days: 14)));
        expect(LicensePolicy.daysLeft(end!, at), 3);
        expect(
          LicensePolicy.trialReminder(r, day0.add(const Duration(days: 10))),
          isNull,
        );
      });
    });

    group('Testangaben der Stores (O-42)', () {
      test('iOS: StoreKit-2-JSON mit offerType 1 = Einführungsangebot', () {
        final ms = day0.millisecondsSinceEpoch;
        final intro = StoreTrialInfo.fromAppleTransactionJson(
          '{"productId":"basis_monat","originalPurchaseDate":$ms,'
          '"purchaseDate":$ms,"offerType":1,"offerDiscountType":"FREE_TRIAL"}',
        );
        expect(intro.introOffer, isTrue);
        expect(intro.firstPurchaseAt, day0);
        final paid = StoreTrialInfo.fromAppleTransactionJson(
          '{"productId":"basis_monat","originalPurchaseDate":$ms}',
        );
        expect(paid.introOffer, isFalse);
        expect(
          StoreTrialInfo.fromAppleTransactionJson('kaputt').introOffer,
          isNull,
        );
      });

      test('Android: nur Kaufzeitpunkt, frühester gewinnt', () {
        final a = StoreTrialInfo.fromAndroidPurchaseTime(
          '${day0.millisecondsSinceEpoch}',
        );
        expect(a.introOffer, isNull);
        expect(a.firstPurchaseAt, day0);
        final later = StoreTrialInfo(
          firstPurchaseAt: day0.add(const Duration(days: 3)),
        );
        expect(StoreTrialInfo.merge([later, a]).firstPurchaseAt, day0);
      });
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

    test('Promo-Code (FA-13.13): Pro, Erinnerung nach 2 Monaten', () async {
      final m = manager();
      await m.init();
      await m.refresh();
      expect(m.entitlement, Entitlement.none);
      await m.redeemCode('jenibucht2m');
      await Future<void>.delayed(Duration.zero);
      expect(store.redeemed, ['jenibucht2m']);
      expect(m.entitlement, Entitlement.pro);
      expect(m.record.trialIsPromo, isTrue);
      // Kein 14-Tage-Hinweis, sondern 3 Tage vor Ende der 2 Monate.
      now = day0.add(const Duration(days: 12));
      expect(m.trialReminder, isNull);
      now = DateTime(2026, 12, 30);
      expect(m.trialReminder, DateTime(2027, 1, 1));
      final json = LicenseRecord.fromJson(m.record.toJson());
      expect(json.trialIsPromo, isTrue);
    });

    test('Android: Basis kaufen → 14 Tage Pro inklusive ab Kaufzeitpunkt, '
        'danach Basis', () async {
      final m = manager();
      await m.init();
      await m.refresh();
      expect(m.entitlement, Entitlement.none);
      final basis = m.offers!.firstWhere((o) => o.product.id == 'basis_monat');
      await m.buy(basis);
      await pumpEventQueue();
      expect(m.entitlement, Entitlement.pro);
      expect(m.message, contains('allen Pro-Funktionen'));
      expect(m.proIncludedUntil, day0.add(const Duration(days: 14)));
      // Neuinstallation: Keystore leer, Store meldet den alten Kaufzeitpunkt.
      cache = MemoryLicenseCache();
      store.trial = StoreTrialInfo(
        firstPurchaseAt: day0.subtract(const Duration(days: 20)),
      );
      final again = manager();
      await again.init();
      await again.refresh();
      expect(again.entitlement, Entitlement.basis);
      expect(
        again.record.trialStartedAt,
        day0.subtract(const Duration(days: 20)),
      );
      // Zeitfenster abgelaufen beim ersten Gerät.
      now = day0.add(const Duration(days: 15));
      expect(m.entitlement, Entitlement.basis);
    });

    test(
      'iOS: Basis mit Einführungsangebot → Pro; Verlängerung → Basis',
      () async {
        store.active = {'basis_jahr'};
        store.trial = StoreTrialInfo(firstPurchaseAt: day0, introOffer: true);
        final m = manager();
        await m.refresh();
        expect(m.entitlement, Entitlement.pro);
        expect(m.record.introOffer, isTrue);
        // StoreKit meldet die bezahlte Folgetransaktion ohne offerType.
        store.trial = StoreTrialInfo(firstPurchaseAt: day0, introOffer: false);
        now = day0.add(const Duration(days: 2));
        await m.refresh();
        expect(m.entitlement, Entitlement.basis);
        final json = LicenseRecord.fromJson(m.record.toJson());
        expect(json.introOffer, isFalse);
      },
    );

    test('Pro gewählt bleibt Pro über die Testzeit hinaus', () async {
      final m = manager();
      await m.refresh();
      await m.buy(m.offers!.firstWhere((o) => o.product.id == 'pro_jahr'));
      await pumpEventQueue();
      now = day0.add(const Duration(days: 40));
      await m.refresh();
      expect(m.entitlement, Entitlement.pro);
      expect(m.proIncludedUntil, isNull);
    });

    test('Promo-Code: Einlöse-Links der Stores', () {
      expect(
        LicensePolicy.playRedeemUri('jenibucht2m').toString(),
        'https://play.google.com/redeem?code=JENIBUCHT2M',
      );
      expect(
        LicensePolicy.appStoreRedeemUri(
          '123',
          LicensePolicy.promoCode,
        ).toString(),
        'https://apps.apple.com/redeem?ctx=offercodes&id=123&code=JENIBUCHT2M',
      );
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
      // O-42: Test auf beiden Stufen, Text mit Pro-Funktionen und Folgepreis.
      expect(find.text('Pro – 14 Tage kostenlos'), findsOneWidget);
      expect(
        find.text(
          '14 Tage kostenlos testen – mit allen Pro-Funktionen. Danach gilt '
          'dein gewähltes Abo (24,90 € pro Monat). Jederzeit vorher im Store '
          'kündbar.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Jährlich'));
      await tester.pumpAndSettle();
      expect(find.text('238,90 € pro Jahr'), findsOneWidget);
      for (final key in [
        'subscription-period',
        'subscription-buy-pro',
        'subscription-buy-basis',
        'subscription-terms',
        'subscription-restore',
        'subscription-redeem',
        'subscription-manage',
        'subscription-terms-link',
        'subscription-privacy-link',
      ]) {
        final f = find.byKey(Key(key));
        await tester.scrollUntilVisible(f, 100);
        expect(tester.getSize(f).height, greaterThanOrEqualTo(48), reason: key);
        if (key == 'subscription-buy-basis') {
          expect(find.text('Basis – 14 Tage kostenlos'), findsOneWidget);
        }
      }
      await tester.scrollUntilVisible(
        find.byKey(const Key('subscription-terms')),
        -100,
      );
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

    testWidgets('Promo-Code einlösen: Eingabe, ein Tipp, Pro aktiv', (
      tester,
    ) async {
      final (state, store) = await pump(
        tester,
        const SubscriptionScreen(),
        active: {},
      );
      final redeem = find.byKey(const Key('subscription-redeem'));
      await tester.scrollUntilVisible(redeem, 100);
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();
      await tester.tap(redeem);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('promo-code-field')),
        'jenibucht2m',
      );
      final submit = find.byKey(const Key('promo-code-submit'));
      expect(tester.getSize(submit).height, greaterThanOrEqualTo(48));
      await tester.tap(submit);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(store.redeemed, ['JENIBUCHT2M']);
      expect(state.entitlement, Entitlement.pro);
    });
  });
}
