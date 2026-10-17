import 'dart:io';

import '../../data/helper_repository.dart';
import '../mail/mail_channel.dart';
import '../mail/mail_credentials.dart';
import '../mail/mail_server.dart';
import 'helper_exchange.dart';
import 'helper_mail.dart';
import 'helper_mail_schedule.dart';
import 'helper_package.dart';

/// Lokale Erinnerung „Belege senden“ (Mithelfer ohne eigenes Postfach).
abstract interface class HelperNotifier {
  Future<void> remindSend(int pending, String businessName);
}

/// Ergebnis eines Laufs (für Anzeige und Tests).
class MailSyncOutcome {
  const MailSyncOutcome({
    this.polled = false,
    this.added = 0,
    this.sent = 0,
    this.reminded = false,
    this.error,
  });

  final bool polled;
  final int added;
  final int sent;
  final bool reminded;
  final MailException? error;
}

/// Ein Lauf des Mailwegs (FA-17.9) – beim Öffnen der App, bei jeder Rückkehr
/// und im Hintergrund (WorkManager/BGTask). Je nach Rolle des Geräts:
/// Hauptgerät liest das Postfach, Mithelfer sendet bzw. erinnert und räumt
/// abgelaufene Pakete weg. Ohne Flutter-Oberfläche lauffähig.
class HelperMailSync {
  HelperMailSync(
    this.repo, {
    required this.documentsDir,
    required this.credentials,
    this.notifier,
    MailConnector? connector,
    DateTime Function()? clock,
  }) : _connector = connector,
       _clock = clock ?? DateTime.now;

  final HelperRepository repo;

  /// Dokumentenordner der App (Eingang `eingang/`, Ausgang `ausgang/`).
  final Directory documentsDir;
  final MailCredentialStore credentials;
  final HelperNotifier? notifier;
  final MailConnector? _connector;
  final DateTime Function() _clock;

  HelperInbox get _inbox => HelperInbox(
    repo,
    pagesDir: Directory('${documentsDir.path}/eingang'),
    clock: _clock,
  );

  HelperMailOutbox get outbox => HelperMailOutbox(
    repo,
    packagesDir: Directory('${documentsDir.path}/ausgang'),
    credentials: credentials,
    connector: _connector,
    clock: _clock,
  );

  HelperMailInbox get mailInbox => HelperMailInbox(
    _inbox,
    credentials: credentials,
    connector: _connector,
    clock: _clock,
  );

  Future<MailSyncOutcome> run(MailTrigger trigger) async {
    final link = await repo.link();
    if (link == null) return _main(trigger);
    if (link.transport != HelperTransport.mail) return const MailSyncOutcome();
    return _helper(link, trigger);
  }

  Future<MailSyncOutcome> _main(MailTrigger trigger) async {
    final inbox = mailInbox;
    final configured = await inbox.isConfigured();
    if (!HelperMailSchedule.shouldPoll(
      configured: configured,
      now: _clock(),
      lastPoll: await inbox.lastPoll(),
      trigger: trigger,
    )) {
      return const MailSyncOutcome();
    }
    final r = await inbox.poll();
    return MailSyncOutcome(polled: true, added: r.added, error: r.error);
  }

  Future<MailSyncOutcome> _helper(HelperLink link, MailTrigger trigger) async {
    final out = outbox;
    await out.prune();
    final pending = (await out.pending()).length;
    final lastReminder = DateTime.tryParse(
      await repo.setting(MailSettingKeys.lastReminder) ?? '',
    );
    final action = HelperMailSchedule.sendAction(
      pending: pending,
      smtpConfigured: await out.smtpConfigured(),
      now: _clock(),
      lastReminder: lastReminder,
      trigger: trigger,
    );
    switch (action) {
      case HelperSendAction.none:
        return const MailSyncOutcome();
      case HelperSendAction.smtp:
        try {
          return MailSyncOutcome(sent: await out.sendPending(link));
        } on MailException catch (e) {
          // Bleibt „wartet auf Versand“; nächster Lauf versucht es wieder.
          return MailSyncOutcome(error: e);
        }
      case HelperSendAction.remind:
        await notifier?.remindSend(pending, link.businessName);
        await repo.setSetting(
          MailSettingKeys.lastReminder,
          _clock().toIso8601String(),
        );
        return const MailSyncOutcome(reminded: true);
    }
  }
}
