// Oberfläche des Mailwegs (FA-17.9): Empfangsadresse mit Häkchen „Andere
// E-Mail-Adresse …“, Verbinden über Ersatzserver, Gerät hinzufügen mit
// E-Mail als Standard, Mithelfer-Einrichtung; Touchflächen ≥ 48 dp.
import 'dart:io';

import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/helper_repository.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/features/helper/helper_devices_screen.dart';
import 'package:buchhaltung/features/helper/helper_home_screen.dart';
import 'package:buchhaltung/features/helper/helper_mail_setup_screen.dart';
import 'package:buchhaltung/features/helper/mail_receive_screen.dart';
import 'package:buchhaltung/services/helper/helper_mail.dart';
import 'package:buchhaltung/services/helper/helper_package.dart';
import 'package:buchhaltung/services/mail/mail_autoconfig.dart';
import 'package:buchhaltung/services/mail/mail_credentials.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'dashboard_refresh_test.dart' show settle;
import 'support/fake_mail_server.dart';

const _ispdb = '''
<clientConfig version="1.1"><emailProvider id="x">
<incomingServer type="imap"><hostname>imap.tischlerei.at</hostname><port>993</port>
<socketType>SSL</socketType><username>%EMAILADDRESS%</username></incomingServer>
<outgoingServer type="smtp"><hostname>smtp.tischlerei.at</hostname><port>465</port>
<socketType>SSL</socketType><username>%EMAILADDRESS%</username></outgoingServer>
</emailProvider></clientConfig>''';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting('de');
  });

  Future<(AppState, FakeMailbox, MemoryMailCredentialStore)> setup(
    WidgetTester tester, {
    String email = 'office@tischlerei.at',
  }) async {
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
    await tester.runAsync(
      () => db.insert('company_profile', {
        'id': 1,
        'company_name': 'Tischlerei',
        'is_small_business': 0,
        'email': email,
      }),
    );
    final state = AppState(Repositories(db));
    await tester.runAsync(state.reload);
    final box = FakeMailbox();
    final creds = MemoryMailCredentialStore();
    state
      ..mailCredentials = creds
      ..mailConnector = box.connector
      ..mailAutoconfig = MailAutoconfig(fetch: (_) async => _ispdb);
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return (state, box, creds);
  }

  Future<void> pump(WidgetTester tester, AppState state, Widget home) async {
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(home: home),
      ),
    );
    await settle(tester);
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.tap(f);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await settle(tester);
    // Animationen (Bottom-Sheet, Dialog) zu Ende laufen lassen.
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);
  }

  testWidgets('Standard: Geschäfts-E-Mail; Häkchen öffnet eigenes Feld', (
    tester,
  ) async {
    final (state, _, _) = await setup(tester);
    await pump(tester, state, const MailReceiveScreen());
    expect(find.text('Geschäfts-E-Mail: office@tischlerei.at'), findsOne);
    expect(find.byKey(const Key('mail-other-address')), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('mail-other'))).height,
      greaterThanOrEqualTo(48),
    );
    await tapAndSettle(tester, find.byKey(const Key('mail-other')));
    expect(find.byKey(const Key('mail-other-address')), findsOne);
    expect(
      tester.getSize(find.byKey(const Key('mail-save'))).height,
      greaterThanOrEqualTo(56),
    );
    expect(
      await tester.runAsync(state.receivingAddress),
      'office@tischlerei.at',
    );
  });

  testWidgets('Andere Adresse + App-Passwort: verbunden, nur lesend', (
    tester,
  ) async {
    final (state, box, creds) = await setup(tester);
    await pump(tester, state, const MailReceiveScreen());
    await tapAndSettle(tester, find.byKey(const Key('mail-other')));
    await tester.enterText(
      find.byKey(const Key('mail-other-address')),
      'belege@tischlerei.at',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('mail-password')),
        matching: find.byType(TextField),
      ),
      'geheim',
    );
    await tapAndSettle(tester, find.byKey(const Key('mail-save')));
    // Einmalige Erklärung zum Hintergrundabruf.
    expect(find.byKey(const Key('mail-permissions-ok')), findsOne);
    await tapAndSettle(tester, find.byKey(const Key('mail-permissions-ok')));
    final saved = await tester.runAsync(
      () => MailReceiveSettings.load(state.repositories.helpers),
    );
    expect(saved!.useOtherAddress, isTrue);
    expect(saved.imap!.host, 'imap.tischlerei.at');
    expect(saved.imap!.user, 'belege@tischlerei.at');
    expect(creds.values[MailSlots.receive], 'geheim');
    // Kennwort nicht in der Datenbank.
    final rows = await tester.runAsync(
      () => state.repositories.helpers.db.query('helper_settings'),
    );
    expect(rows.toString(), isNot(contains('geheim')));
    expect(box.imapCommands, contains('EXAMINE INBOX'));
    expect(
      await tester.runAsync(state.receivingAddress),
      'belege@tischlerei.at',
    );
  });

  testWidgets('Falsches Kennwort: Meldung, nichts gespeichert', (tester) async {
    final (state, _, creds) = await setup(tester);
    await pump(tester, state, const MailReceiveScreen());
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('mail-password')),
        matching: find.byType(TextField),
      ),
      'falsch',
    );
    await tapAndSettle(tester, find.byKey(const Key('mail-save')));
    expect(find.byKey(const Key('mail-error')), findsOne);
    expect(creds.values, isEmpty);
  });

  testWidgets('Ohne Geschäfts-E-Mail: Hinweis aufs Häkchen', (tester) async {
    final (state, _, _) = await setup(tester, email: '');
    await pump(tester, state, const MailReceiveScreen());
    await tapAndSettle(tester, find.byKey(const Key('mail-save')));
    expect(find.textContaining('keine gültige Geschäfts-E-Mail'), findsOne);
  });

  testWidgets('Gerät hinzufügen: E-Mail ist Standard, Teilen nicht angeboten', (
    tester,
  ) async {
    final (state, _, _) = await setup(tester);
    final docs = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('docs'),
    ))!;
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => docs.path);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null),
    );
    await pump(tester, state, const HelperDevicesScreen());
    expect(find.byKey(const Key('helper-mail')), findsOne);
    expect(
      tester.getSize(find.byKey(const Key('helper-mail'))).height,
      greaterThanOrEqualTo(48),
    );
    await tapAndSettle(tester, find.byKey(const Key('helper-add')));
    final mail = tester.widget<RadioListTile<HelperTransport>>(
      find.byKey(const Key('helper-transport-mail')),
    );
    // ignore: deprecated_member_use
    expect(mail.groupValue, HelperTransport.mail);
    expect(find.byKey(const Key('helper-transport-share')), findsNothing);
    await tapAndSettle(tester, find.byKey(const Key('helper-show-qr')));
    final pairing = (await tester.runAsync(
      () => state.repositories.helpers.pairings(),
    ))!.single;
    expect(pairing.transport, HelperTransport.mail);
    // QR-Code trägt die Empfangsadresse, kein Kennwort.
    expect(find.textContaining('koppeln'), findsWidgets);
  });

  testWidgets('Mithelfer: Einrichten-Hinweis und Gmail-Anleitung', (
    tester,
  ) async {
    final (state, box, creds) = await setup(tester);
    await tester.runAsync(
      () => state.setHelperLink(
        HelperLink(
          pairingId: HelperPackage.hex(List.filled(16, 1)),
          key: Uint8List(32),
          businessName: 'Tischlerei',
          deviceName: 'Handy Anna',
          transport: HelperTransport.mail,
          receivingAddress: 'office@tischlerei.at',
        ),
      ),
    );
    await pump(tester, state, const HelperHomeScreen());
    final banner = find.byKey(const Key('helper-mail-setup'));
    expect(banner, findsOne);
    final button = find.descendant(
      of: banner,
      matching: find.byType(FilledButton),
    );
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));

    await pump(tester, state, const HelperMailSetupScreen());
    await tester.enterText(
      find.byKey(const Key('smtp-address')),
      'anna@gmail.com',
    );
    await settle(tester);
    expect(find.text('Gmail braucht ein App-Passwort'), findsOne);
    expect(
      tester.getSize(find.byKey(const Key('app-password-link'))).height,
      greaterThanOrEqualTo(48),
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('smtp-password')),
        matching: find.byType(TextField),
      ),
      'geheim',
    );
    await tapAndSettle(tester, find.byKey(const Key('smtp-save')));
    await tapAndSettle(tester, find.byKey(const Key('mail-permissions-ok')));
    expect(creds.values[MailSlots.send], 'geheim');
    expect(box.logins, ['anna@gmail.com']);
    final s = await tester.runAsync(
      () => MailSendSettings.load(state.repositories.helpers),
    );
    expect(s!.smtp.host, 'smtp.gmail.com');
  });
}
