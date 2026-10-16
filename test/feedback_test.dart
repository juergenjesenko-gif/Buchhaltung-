import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/features/settings/feedback_screen.dart';
import 'package:buchhaltung/services/help/feedback_mail.dart';
import 'package:buchhaltung/services/help/support_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'dashboard_refresh_test.dart' show settle;

class _FakeLauncher implements SupportMailLauncher {
  _FakeLauncher({this.opens = true});
  final bool opens;
  Uri? sent;

  @override
  Future<String?> appVersion() async => '0.22.2';
  @override
  Future<String?> deviceInfo() async => 'Android 15 · Google Pixel 10';
  @override
  Future<bool> openMail(Uri uri) async {
    sent = uri;
    return opens;
  }
}

void main() {
  group('FeedbackMail', () {
    test('Betreff mit Titel, sonst erste Wörter', () {
      expect(
        const FeedbackMail(
          kind: FeedbackKind.bug,
          title: ' Absturz ',
          description: 'x',
        ).subject,
        '[JeNi bucht] Fehler melden: Absturz',
      );
      expect(
        const FeedbackMail(
          kind: FeedbackKind.feature,
          title: '',
          description: 'Bitte eine Fahrtenbuch Funktion mit GPS und Export',
        ).subject,
        '[JeNi bucht] Neue Funktion: Bitte eine Fahrtenbuch Funktion mit GPS …',
      );
    });

    test('Kontext nur wenn gewählt, Adresse aus einer Stelle', () {
      const ctx = FeedbackContext(
        appVersion: '0.22.2',
        device: 'iOS 26 · iPhone17,1',
        country: 'AT',
        tier: 'Pro',
      );
      const m = FeedbackMail(
        kind: FeedbackKind.improvement,
        title: 'T',
        description: 'Text',
        context: ctx,
      );
      expect(m.uri.path, supportAddress);
      expect(m.body, contains('Länderprofil: AT'));
      expect(m.body, contains('Abo: Pro'));
      expect(m.uri.toString(), isNot(contains('+')));
      const ohne = FeedbackMail(
        kind: FeedbackKind.improvement,
        title: 'T',
        description: 'Text',
      );
      expect(ohne.body, isNot(contains('App-Version')));
    });
  });

  group('Formular', () {
    setUpAll(sqfliteFfiInit);

    Future<void> pump(WidgetTester tester, SupportMailLauncher l) async {
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
      await tester.runAsync(
        () => db!.insert('company_profile', {'id': 1, 'company_name': 'T'}),
      );
      final state = AppState(Repositories(db!));
      await tester.runAsync(state.reload);
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(home: FeedbackScreen(launcher: l)),
        ),
      );
      await settle(tester);
    }

    testWidgets('Einhändig: Senden unten 56 dp, Chips und Schalter ≥ 48 dp', (
      tester,
    ) async {
      final l = _FakeLauncher();
      await pump(tester, l);
      final send = find.byKey(const Key('feedback-send'));
      expect(tester.getSize(send).height, greaterThanOrEqualTo(56));
      expect(tester.getSize(send).width, greaterThan(300));
      expect(tester.getRect(send).center.dy, greaterThan(640 * 2 / 3));
      for (final k in FeedbackKind.values) {
        expect(
          tester.getSize(find.byKey(Key('feedback-kind-${k.name}'))).height,
          greaterThanOrEqualTo(48),
        );
      }
      await tester.scrollUntilVisible(
        find.byKey(const Key('feedback-context')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.getSize(find.byKey(const Key('feedback-context'))).height,
        greaterThanOrEqualTo(48),
      );
      final chip = tester.widget<ChoiceChip>(
        find.byKey(const Key('feedback-kind-feature')),
      );
      expect(chip.selected, isTrue);

      // Beschreibung ist Pflicht: nichts geöffnet.
      await tester.tap(send);
      await settle(tester);
      expect(l.sent, isNull);
      expect(find.text('Bitte beschreibe kurz deinen Wunsch.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('feedback-kind-bug')));
      await tester.enterText(
        find.byKey(const Key('feedback-description')),
        'Absturz beim Export',
      );
      await tester.tap(send);
      await settle(tester);
      final q = l.sent!.queryParameters;
      expect(l.sent!.path, supportAddress);
      expect(q['subject'], '[JeNi bucht] Fehler melden: Absturz beim Export');
      expect(q['body'], contains('Google Pixel 10'));
      expect(q['body'], contains('Länderprofil: AT'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Ohne Mail-App: Text in der Zwischenablage, ohne Gerät', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      final l = _FakeLauncher(opens: false);
      await pump(tester, l);
      await tester.scrollUntilVisible(
        find.byKey(const Key('feedback-context')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await settle(tester);
      await tester.tap(find.byKey(const Key('feedback-context')));
      await tester.enterText(
        find.byKey(const Key('feedback-description')),
        'Idee',
      );
      await tester.tap(find.byKey(const Key('feedback-send')));
      await settle(tester);
      expect(copied, startsWith('An: $supportAddress'));
      expect(copied, isNot(contains('Pixel')));
      expect(find.textContaining('Text kopiert'), findsOneWidget);
    });
  });
}
