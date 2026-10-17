// Mailweg der Mithelfer-Geräte (FA-17.9, Entscheidung Auftraggeberin
// 2026-10-17): Sammelpaket v2 und v1, Betreff-Kennzeichen, Dubletten über
// mehrere Mails, IMAP nur lesend und SMTP mit Ersatzserver, Zeitentscheidungen,
// Aufbewahrung, Serversuche.
import 'dart:io';
import 'dart:typed_data';

import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/helper_repository.dart';
import 'package:buchhaltung/services/helper/helper_exchange.dart';
import 'package:buchhaltung/services/helper/helper_mail.dart';
import 'package:buchhaltung/services/helper/helper_mail_schedule.dart';
import 'package:buchhaltung/services/helper/helper_mail_subject.dart';
import 'package:buchhaltung/services/helper/helper_mail_sync.dart';
import 'package:buchhaltung/services/helper/helper_package.dart';
import 'package:buchhaltung/services/mail/imap_reader.dart';
import 'package:buchhaltung/services/mail/mail_autoconfig.dart';
import 'package:buchhaltung/services/mail/mail_credentials.dart';
import 'package:buchhaltung/services/mail/mail_server.dart';
import 'package:buchhaltung/services/mail/mime.dart';
import 'package:buchhaltung/services/mail/smtp_sender.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_mail_server.dart';

Future<Database> _db() => databaseFactoryFfi.openDatabase(
  inMemoryDatabasePath,
  options: OpenDatabaseOptions(
    version: AppDatabase.schemaVersion,
    onCreate: AppDatabase.createSchema,
    singleInstance: false,
  ),
);

HelperReceipt _receipt(int cents, [String? uuid]) => HelperReceipt(
  uuid: uuid ?? HelperPackage.newUuid(),
  deviceName: 'Handy Anna',
  createdAt: DateTime(2026, 10, 17, 9),
  date: DateTime(2026, 10, 16),
  grossCents: cents,
  counterparty: 'OMV Tankstelle',
  pages: [
    Uint8List.fromList([0xFF, 0xD8, cents & 0xff, 2, 3]),
  ],
);

const _imap = MailServer(
  host: 'imap.test',
  port: 993,
  security: MailSecurity.tls,
  user: 'belege@tischlerei.at',
);
const _smtp = MailServer(
  host: 'smtp.test',
  port: 587,
  security: MailSecurity.starttls,
  user: 'anna@gmail.com',
);

class _Notifier implements HelperNotifier {
  final calls = <int>[];
  @override
  Future<void> remindSend(int pending, String businessName) async =>
      calls.add(pending);
}

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('mailweg'));
  tearDown(() async => tmp.delete(recursive: true));

  final key = List<int>.generate(32, (i) => i);
  const pairingId = 'a0a1a2a3a4a5a6a7a8a9aaabacadaeaf';

  group('Sammelpaket', () {
    test('v2 trägt mehrere Belege, Werte und Seiten unverändert', () async {
      final a = _receipt(796);
      final b = _receipt(100);
      final data = await HelperPackage.sealBundle(
        [a, b],
        pairingId: pairingId,
        key: key,
      );
      expect(data[4], HelperPackage.bundleVersion);
      expect(HelperPackage.pairingIdOf(data), pairingId);
      final opened = await HelperPackage.openAll(data, key);
      expect(opened.map((r) => r.uuid), [a.uuid, b.uuid]);
      expect(opened.map((r) => r.grossCents), [796, 100]);
      expect(opened.last.pages.single, b.pages.single);
    });

    test('v1 bleibt lesbar (Einzelbeleg)', () async {
      final a = _receipt(2146);
      final v1 = await HelperPackage.seal(a, pairingId: pairingId, key: key);
      expect(v1[4], 1);
      expect((await HelperPackage.openAll(v1, key)).single.uuid, a.uuid);
      expect((await HelperPackage.open(v1, key)).uuid, a.uuid);
    });

    test('verändertes Sammelpaket: beschädigt', () async {
      final data = await HelperPackage.sealBundle(
        [_receipt(1)],
        pairingId: pairingId,
        key: key,
      );
      data[data.length - 20] ^= 1;
      expect(
        () => HelperPackage.openAll(data, key),
        throwsA(isA<HelperPackageException>()),
      );
    });

    test('Eingang nimmt v2 an, Dubletten über UUID nur einmal', () async {
      final repo = HelperRepository(await _db());
      final inbox = HelperInbox(repo, pagesDir: tmp);
      final code = await inbox.createPairing(
        deviceName: 'Handy Anna',
        businessName: 'Tischlerei',
        transport: HelperTransport.mail,
        receivingAddress: 'belege@tischlerei.at',
      );
      final a = _receipt(796);
      final b = _receipt(100);
      final first = await inbox.importBytes(
        await HelperPackage.sealBundle(
          [a, b],
          pairingId: code.pairingId,
          key: code.key,
        ),
      );
      expect(first.added, 2);
      expect(first.message, '2 Belege von Handy Anna im Eingang.');
      // Zweite Mail mit a (schon da) und c (neu).
      final c = _receipt(55);
      final second = await inbox.importBytes(
        await HelperPackage.sealBundle(
          [a, c],
          pairingId: code.pairingId,
          key: code.key,
        ),
      );
      expect(second.added, 1);
      final again = await inbox.importBytes(
        await HelperPackage.sealBundle(
          [a, b, c],
          pairingId: code.pairingId,
          key: code.key,
        ),
      );
      expect(again.duplicate, isTrue);
      expect((await repo.inbox()).length, 3);
    });
  });

  group('Betreff', () {
    test('Format und Zerlegung', () {
      final s = HelperMailSubject.format(pairingId, DateTime(2026, 10, 17), 3);
      expect(s, '[JeNi-Beleg] $pairingId-20261017-3');
      final p = HelperMailSubject.parse(s)!;
      expect(p.pairingId, pairingId);
      expect(p.day, DateTime(2026, 10, 17));
      expect(p.seq, 3);
    });

    test('weitergeleitet und groß geschrieben erkannt', () {
      final p = HelperMailSubject.parse(
        'WG: Fwd: [jeni-beleg] ${pairingId.toUpperCase()}-20261017-12',
      )!;
      expect(p.pairingId, pairingId);
      expect(p.seq, 12);
    });

    test('Fremdes wird nicht erkannt', () {
      for (final s in [
        'Rechnung Oktober',
        '[JeNi-Beleg] kaputt-20261017-1',
        '[JeNi-Beleg] $pairingId-20261317-1',
        '[JeNi bucht] Wunsch',
      ]) {
        expect(HelperMailSubject.parse(s), isNull, reason: s);
      }
    });
  });

  group('MIME', () {
    test('Anhang hin und zurück, Base64-Zeilen ≤ 76', () {
      final bytes = Uint8List.fromList(List.generate(300, (i) => i % 256));
      final m = Mime.build(
        from: 'anna@gmail.com',
        to: 'belege@tischlerei.at',
        subject: 'Test äöü',
        date: DateTime.utc(2026, 10, 17, 9),
        messageId: 'x@jeni',
        text: 'Hallo',
        attachmentName: 'a0a1a2a3_20261017-1.jenibeleg',
        attachment: bytes,
      );
      for (final line in m.split('\r\n')) {
        expect(line.length, lessThanOrEqualTo(998));
      }
      expect(m, contains('Date: Sat, 17 Oct 2026 09:00:00 +0000'));
      final found = Mime.attachments(m, extension: '.jenibeleg');
      expect(found.single.$2, bytes);
      expect(Mime.decodeHeader(Mime.split(m).$1['subject']!), 'Test äöü');
    });

    test('Punkt am Zeilenanfang wird verdoppelt', () {
      expect(SmtpSender.dotStuff('a\r\n.b\r\n'), 'a\r\n..b');
    });
  });

  group('Ende zu Ende über Ersatzserver', () {
    late FakeMailbox box;
    late HelperRepository mainRepo;
    late HelperRepository helperRepo;
    late HelperLink link;
    late MemoryMailCredentialStore mainCreds;
    late MemoryMailCredentialStore helperCreds;
    var now = DateTime(2026, 10, 17, 9);

    HelperMailSync mainSync() => HelperMailSync(
      mainRepo,
      documentsDir: Directory('${tmp.path}/haupt'),
      credentials: mainCreds,
      connector: box.connector,
      clock: () => now,
    );
    HelperMailSync helperSync({HelperNotifier? notifier}) => HelperMailSync(
      helperRepo,
      documentsDir: Directory('${tmp.path}/helfer'),
      credentials: helperCreds,
      connector: box.connector,
      notifier: notifier,
      clock: () => now,
    );

    setUp(() async {
      now = DateTime(2026, 10, 17, 9);
      box = FakeMailbox();
      mainRepo = HelperRepository(await _db());
      helperRepo = HelperRepository(await _db());
      mainCreds = MemoryMailCredentialStore();
      helperCreds = MemoryMailCredentialStore();
      final code = HelperPairingCode.tryParse(
        (await HelperInbox(
              mainRepo,
              pagesDir: Directory('${tmp.path}/haupt/eingang'),
            ).createPairing(
              deviceName: 'Handy Anna',
              businessName: 'Tischlerei',
              transport: HelperTransport.mail,
              receivingAddress: 'belege@tischlerei.at',
            ))
            .encode(),
      )!;
      // Kein Kennwort im QR-Code.
      expect(code.encode(), isNot(contains('geheim')));
      expect(code.receivingAddress, 'belege@tischlerei.at');
      link = HelperLink(
        pairingId: code.pairingId,
        key: code.key,
        businessName: code.businessName,
        deviceName: code.deviceName,
        transport: code.transport,
        receivingAddress: code.receivingAddress,
      );
      await helperRepo.saveLink(link);
      await const MailReceiveSettings(
        useOtherAddress: true,
        otherAddress: 'belege@tischlerei.at',
        imap: _imap,
      ).save(mainRepo);
      await mainCreds.write(MailSlots.receive, 'geheim');
      await const MailSendSettings(
        address: 'anna@gmail.com',
        smtp: _smtp,
      ).save(helperRepo);
      await helperCreds.write(MailSlots.send, 'geheim');
    });

    Future<void> queue(int cents) async {
      final photo = File('${tmp.path}/foto_$cents.jpg')
        ..writeAsBytesSync([1, 2, 3]);
      await helperSync().outbox.queue(
        link: link,
        receipt: _receipt(cents),
        summary: '$cents',
        deleteAfter: [photo],
      );
      expect(photo.existsSync(), isFalse);
    }

    test('zwei Belege → eine Mail → Eingang, Postfach unverändert', () async {
      await queue(796);
      await queue(100);
      final sent = await helperSync().run(MailTrigger.background);
      expect(sent.sent, 2);
      expect(box.messages, hasLength(1));
      expect(box.envelopes.single, ('anna@gmail.com', 'belege@tischlerei.at'));
      final subject = Mime.split(box.messages.single).$1['subject']!;
      expect(HelperMailSubject.parse(subject)!.pairingId, link.pairingId);
      expect(subject, endsWith('-20261017-1'));
      // Status beim Mithelfer: gesendet, Paket bleibt verschlüsselt liegen.
      final out = await helperRepo.outboxWithPackages();
      expect(out.map((e) => e.status), everyElement(OutboxStatus.sent));
      final stored = File(out.first.packagePath).readAsBytesSync();
      expect(String.fromCharCodes(stored), isNot(contains('OMV')));

      final polled = await mainSync().run(MailTrigger.background);
      expect(polled.polled, isTrue);
      expect(polled.added, 2);
      expect((await mainRepo.inbox()).length, 2);
      // Nur lesende Befehle.
      for (final c in box.imapCommands) {
        final verb = c.startsWith('UID ')
            ? c.split(' ').take(2).join(' ')
            : c.split(' ').first;
        expect(ImapReader.allowedCommands, contains(verb.toUpperCase()));
        expect(c.toUpperCase(), isNot(contains('STORE')));
        if (c.toUpperCase().startsWith('UID FETCH')) {
          expect(c.toUpperCase(), contains('BODY.PEEK'));
        }
      }
      expect(box.imapCommands, contains('EXAMINE INBOX'));
      expect(box.messages, hasLength(1), reason: 'nichts gelöscht');

      // Zweiter Abruf eine Stunde später: Message-ID gemerkt, kein Body.
      now = now.add(const Duration(hours: 1));
      box.imapCommands.clear();
      final again = await mainSync().run(MailTrigger.background);
      expect(again.added, 0);
      expect(
        box.imapCommands.where((c) => c.contains('BODY.PEEK[])')),
        isEmpty,
      );
    });

    test('dieselben Belege in zwei Mails: nur einmal im Eingang', () async {
      await queue(796);
      await helperSync().run(MailTrigger.background);
      // Notweg: Export (alle gespeicherten) noch einmal per Mail.
      final b = await helperSync().outbox.export(link);
      box.messages.add(
        Mime.build(
          from: 'anna@gmail.com',
          to: 'belege@tischlerei.at',
          subject: HelperMailSubject.format(link.pairingId, now, 9),
          date: now,
          messageId: 'zweite@test',
          text: 'nochmal',
          attachmentName: b!.fileName,
          attachment: b.bytes,
        ),
      );
      final r = await mainSync().run(MailTrigger.background);
      expect(r.added, 1);
      expect((await mainRepo.inbox()).length, 1);
    });

    test('fremde Mails und unbekannte Kopplung bleiben unberührt', () async {
      box.messages
        ..add(
          'Subject: [JeNi-Beleg] Werbung\r\nMessage-ID: <w@x>\r\n\r\nHallo\r\n',
        )
        ..add(
          'Subject: [JeNi-Beleg] ${'b' * 32}-20261017-1\r\n'
          'Message-ID: <u@x>\r\n\r\nHallo\r\n',
        );
      final r = await mainSync().run(MailTrigger.background);
      expect(r.added, 0);
      expect(
        box.imapCommands.where((c) => c.endsWith('BODY.PEEK[])')),
        isEmpty,
      );
      expect(await mainRepo.hasSeenMail('w@x'), isFalse);
    });

    test('getrennt: Mail wird gemerkt, Beleg abgelehnt', () async {
      await queue(796);
      await helperSync().run(MailTrigger.background);
      await HelperInbox(mainRepo, pagesDir: tmp).revoke(link.pairingId);
      final r = await mainSync().run(MailTrigger.background);
      expect(r.added, 0);
      expect((await mainRepo.inbox()), isEmpty);
    });

    test('falsches Kennwort: Fehler, Belege warten weiter', () async {
      await queue(796);
      await helperCreds.write(MailSlots.send, 'falsch');
      final r = await helperSync().run(MailTrigger.background);
      expect(r.error?.authentication, isTrue);
      expect(await helperSync().outbox.pending(), hasLength(1));
    });

    test('STARTTLS fehlt: keine unverschlüsselte Anmeldung', () async {
      box.offerStartTls = false;
      await queue(796);
      final r = await helperSync().run(MailTrigger.background);
      expect(r.error, isNotNull);
      expect(box.logins, isEmpty);
    });

    test(
      'ohne Postfach: einmal am Tag erinnern, Mail-App als Rückfall',
      () async {
        await helperCreds.delete(MailSlots.send);
        await queue(796);
        final n = _Notifier();
        expect(
          (await helperSync(notifier: n).run(MailTrigger.background)).reminded,
          isTrue,
        );
        expect(
          (await helperSync(notifier: n).run(MailTrigger.background)).reminded,
          isFalse,
        );
        now = now.add(const Duration(days: 1));
        expect(
          (await helperSync(notifier: n).run(MailTrigger.background)).reminded,
          isTrue,
        );
        expect(n.calls, [1, 1]);
        // Mailfenster: Paket wird übergeben und gilt als gesendet.
        HelperBundle? handed;
        final count = await helperSync().outbox.handOver(link, (b, text) async {
          handed = b;
          return true;
        });
        expect(count, 1);
        expect(handed!.subject, startsWith('[JeNi-Beleg] ${link.pairingId}-'));
        expect(await helperSync().outbox.pending(), isEmpty);
      },
    );

    test('Aufbewahrung: gesendete nach Frist gelöscht, wartende nie', () async {
      await queue(796);
      await helperSync().run(MailTrigger.background);
      await helperCreds.delete(MailSlots.send);
      await queue(100);
      now = now.add(const Duration(days: 89));
      expect(await helperSync().outbox.prune(), 0);
      now = now.add(const Duration(days: 1));
      expect(await helperSync().outbox.prune(), 1);
      final left = await helperRepo.outboxWithPackages();
      expect(left.single.status, OutboxStatus.queued);
      expect(await helperSync().outbox.prune(days: 1), 0);
    });

    test('Laufende Nummer je Tag', () async {
      await queue(1);
      await helperSync().run(MailTrigger.background);
      await queue(2);
      await helperSync().run(MailTrigger.appOpen);
      now = DateTime(2026, 10, 18, 8);
      await queue(3);
      await helperSync().run(MailTrigger.background);
      final subjects = [
        for (final m in box.messages) Mime.split(m).$1['subject']!,
      ];
      expect(subjects.map((s) => s.substring(s.length - 11)), [
        '-20261017-1',
        '-20261017-2',
        '-20261018-1',
      ]);
    });
  });

  group('Zeitentscheidungen', () {
    final t = DateTime(2026, 10, 17, 12);
    test('Hauptgerät: Abruf', () {
      bool poll(DateTime? last, MailTrigger tr, {bool configured = true}) =>
          HelperMailSchedule.shouldPoll(
            configured: configured,
            now: t,
            lastPoll: last,
            trigger: tr,
          );
      expect(poll(null, MailTrigger.appOpen, configured: false), isFalse);
      expect(poll(null, MailTrigger.appOpen), isTrue);
      expect(
        poll(t.subtract(const Duration(minutes: 1)), MailTrigger.appOpen),
        isFalse,
      );
      expect(
        poll(t.subtract(const Duration(minutes: 3)), MailTrigger.appOpen),
        isTrue,
      );
      expect(
        poll(t.subtract(const Duration(minutes: 10)), MailTrigger.background),
        isFalse,
      );
      expect(
        poll(t.subtract(const Duration(hours: 1)), MailTrigger.background),
        isTrue,
      );
      expect(
        poll(t.add(const Duration(hours: 1)), MailTrigger.appOpen),
        isTrue,
      );
      expect(HelperMailSchedule.pollInterval, const Duration(hours: 1));
      expect(HelperMailSchedule.sendInterval, const Duration(days: 1));
    });

    test('Mithelfer: senden, erinnern, nichts', () {
      HelperSendAction a({
        int pending = 2,
        bool smtp = true,
        DateTime? last,
        MailTrigger tr = MailTrigger.background,
      }) => HelperMailSchedule.sendAction(
        pending: pending,
        smtpConfigured: smtp,
        now: t,
        lastReminder: last,
        trigger: tr,
      );
      expect(a(pending: 0), HelperSendAction.none);
      expect(a(), HelperSendAction.smtp);
      expect(a(tr: MailTrigger.appOpen), HelperSendAction.smtp);
      expect(a(smtp: false), HelperSendAction.remind);
      expect(a(smtp: false, tr: MailTrigger.appOpen), HelperSendAction.none);
      expect(
        a(smtp: false, last: t.subtract(const Duration(hours: 3))),
        HelperSendAction.none,
      );
      expect(
        a(smtp: false, last: t.subtract(const Duration(days: 1))),
        HelperSendAction.remind,
      );
    });

    test('Aufbewahrung Standard 90 Tage', () {
      expect(HelperMailSchedule.defaultRetentionDays, 90);
      expect(
        HelperMailSchedule.expired(sentAt: null, now: t, days: 1),
        isFalse,
      );
    });
  });

  group('Serversuche', () {
    const ispdb = '''
<clientConfig version="1.1">
  <emailProvider id="tischlerei.at">
    <incomingServer type="pop3"><hostname>pop.x</hostname><port>995</port>
      <socketType>SSL</socketType><username>%EMAILADDRESS%</username></incomingServer>
    <incomingServer type="imap"><hostname>imap.plain</hostname><port>143</port>
      <socketType>plain</socketType><username>%EMAILADDRESS%</username></incomingServer>
    <incomingServer type="imap"><hostname>imap.world4you.com</hostname><port>993</port>
      <socketType>SSL</socketType><username>%EMAILADDRESS%</username></incomingServer>
    <outgoingServer type="smtp"><hostname>smtp.world4you.com</hostname><port>587</port>
      <socketType>STARTTLS</socketType><username>%EMAILLOCALPART%</username></outgoingServer>
  </emailProvider>
</clientConfig>''';

    test('ISPDB: nur verschlüsselte Einträge, Platzhalter ersetzt', () async {
      final asked = <Uri>[];
      final found = await MailAutoconfig(
        fetch: (uri) async {
          asked.add(uri);
          return uri.host == 'autoconfig.thunderbird.net' ? ispdb : null;
        },
      ).lookup('belege@tischlerei.at');
      expect(found!.imap!.host, 'imap.world4you.com');
      expect(found.imap!.security, MailSecurity.tls);
      expect(found.imap!.user, 'belege@tischlerei.at');
      expect(found.smtp!.security, MailSecurity.starttls);
      expect(found.smtp!.user, 'belege');
      // Nur die Domain verlässt das Gerät.
      for (final u in asked) {
        expect(u.toString(), isNot(contains('belege@')));
        expect(u.scheme, 'https');
      }
    });

    test('Reihenfolge ISPDB → autoconfig.<domain> → .well-known', () async {
      final asked = <String>[];
      final found = await MailAutoconfig(
        fetch: (uri) async {
          asked.add(uri.toString());
          return uri.path.contains('.well-known') ? ispdb : null;
        },
      ).lookup('x@tischlerei.at');
      expect(asked, [
        'https://autoconfig.thunderbird.net/v1.1/tischlerei.at',
        'https://autoconfig.tischlerei.at/mail/config-v1.1.xml',
        'https://tischlerei.at/.well-known/autoconfig/mail/config-v1.1.xml',
      ]);
      expect(found, isNotNull);
    });

    test('Gmail und iCloud ohne Netz, mit App-Passwort-Link', () async {
      final none = MailAutoconfig(fetch: (_) async => fail('kein Netz'));
      final g = await none.lookup('anna@gmail.com');
      expect(g!.smtp!.host, 'smtp.gmail.com');
      expect(g.smtp!.port, 465);
      final i = await none.lookup('anna@icloud.com');
      expect(i!.smtp!.security, MailSecurity.starttls);
      expect(i.imap!.user, 'anna');
      expect(
        MailProvider.gmail.appPasswordUrl,
        'https://myaccount.google.com/apppasswords',
      );
      expect(MailProvider.icloud.appPasswordUrl, 'https://account.apple.com');
      expect(MailAutoconfig.providerOf('a@googlemail.com'), MailProvider.gmail);
      expect(MailProvider.gmail.appPasswordSteps.length, greaterThan(2));
    });

    test('Nichts gefunden: null (Felder von Hand)', () async {
      expect(
        await MailAutoconfig(fetch: (_) async => null).lookup('a@b.at'),
        isNull,
      );
      expect(await MailAutoconfig().lookup('keine-adresse'), isNull);
    });
  });
}
