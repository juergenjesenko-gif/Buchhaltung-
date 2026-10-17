import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../data/helper_repository.dart';
import '../mail/imap_reader.dart';
import '../mail/mail_channel.dart';
import '../mail/mail_credentials.dart';
import '../mail/mail_server.dart';
import '../mail/mime.dart';
import '../mail/smtp_sender.dart';
import 'helper_exchange.dart';
import 'helper_mail_schedule.dart';
import 'helper_mail_subject.dart';
import 'helper_package.dart';

/// Schlüssel in `helper_settings` für den Mailweg (FA-17.9).
abstract final class MailSettingKeys {
  /// Hauptgerät: Empfangsadresse und IMAP-Server (ohne Kennwort).
  static const receive = 'mail_receive';
  static const lastPoll = 'mail_last_poll';

  /// Mithelfer: Absenderadresse und SMTP-Server (ohne Kennwort).
  static const send = 'mail_send';
  static const lastSend = 'mail_last_send';
  static const lastReminder = 'mail_last_reminder';
  static const seq = 'mail_seq';
  static const retentionDays = 'retention_days';

  /// Einmalige Erklärung der Berechtigungen (Mitteilungen, Hintergrund)
  /// wurde gezeigt.
  static const permissionsExplained = 'mail_permissions_explained';
}

/// Hauptgerät: wohin die Mithelfer senden und wie die App das Postfach liest.
class MailReceiveSettings {
  const MailReceiveSettings({
    required this.useOtherAddress,
    required this.otherAddress,
    this.imap,
  });

  /// Häkchen „Andere E-Mail-Adresse für den Empfang von Belegen“; sonst die
  /// Geschäfts-E-Mail aus den Stammdaten.
  final bool useOtherAddress;
  final String otherAddress;

  /// Nur-Lese-Zugang; `null`, solange nicht verbunden.
  final MailServer? imap;

  static const empty = MailReceiveSettings(
    useOtherAddress: false,
    otherAddress: '',
  );

  /// Tatsächliche Empfangsadresse.
  String address(String businessEmail) =>
      useOtherAddress ? otherAddress.trim() : businessEmail.trim();

  Map<String, Object?> toJson() => {
    'other': useOtherAddress,
    'address': otherAddress,
    'imap': imap?.toJson(),
  };

  static MailReceiveSettings fromJson(Map<String, Object?> j) =>
      MailReceiveSettings(
        useOtherAddress: j['other'] as bool? ?? false,
        otherAddress: j['address'] as String? ?? '',
        imap: j['imap'] == null
            ? null
            : MailServer.fromJson((j['imap'] as Map).cast<String, Object?>()),
      );

  static Future<MailReceiveSettings> load(HelperRepository repo) async {
    final v = await repo.setting(MailSettingKeys.receive);
    if (v == null) return empty;
    return fromJson((jsonDecode(v) as Map).cast<String, Object?>());
  }

  Future<void> save(HelperRepository repo) =>
      repo.setSetting(MailSettingKeys.receive, jsonEncode(toJson()));
}

/// Mithelfer: eigenes Postfach zum Senden.
class MailSendSettings {
  const MailSendSettings({required this.address, required this.smtp});

  final String address;
  final MailServer smtp;

  Map<String, Object?> toJson() => {'address': address, 'smtp': smtp.toJson()};

  static Future<MailSendSettings?> load(HelperRepository repo) async {
    final v = await repo.setting(MailSettingKeys.send);
    if (v == null) return null;
    final j = (jsonDecode(v) as Map).cast<String, Object?>();
    return MailSendSettings(
      address: j['address'] as String? ?? '',
      smtp: MailServer.fromJson((j['smtp'] as Map).cast<String, Object?>()),
    );
  }

  Future<void> save(HelperRepository repo) =>
      repo.setSetting(MailSettingKeys.send, jsonEncode(toJson()));
}

/// Ergebnis eines Postfach-Abrufs.
class MailPollResult {
  const MailPollResult({
    this.mails = 0,
    this.added = 0,
    this.messages = const [],
    this.error,
  });

  /// Neue Belegmails.
  final int mails;

  /// Neu in den Eingang gelegte Belege.
  final int added;
  final List<String> messages;
  final MailException? error;
}

/// Hauptgerät: liest die Empfangsadresse **nur** (FA-17.9). Betrachtet nur
/// Mails mit Kennzeichen `[JeNi-Beleg]` und bekannter Kopplung, lädt den
/// Anhang, entschlüsselt ihn und legt die Belege in den Eingang. Keine Mail
/// wird gelöscht, verschoben oder als gelesen markiert; verarbeitete
/// Message-IDs merkt sich die App in `helper_mail_seen`.
class HelperMailInbox {
  HelperMailInbox(
    this.inbox, {
    required this.credentials,
    MailConnector? connector,
    DateTime Function()? clock,
  }) : _connector = connector,
       _clock = clock ?? DateTime.now;

  final HelperInbox inbox;
  final MailCredentialStore credentials;
  final MailConnector? _connector;
  final DateTime Function() _clock;

  HelperRepository get repo => inbox.repo;

  /// Ist ein Nur-Lese-Zugang eingerichtet?
  Future<bool> isConfigured() async {
    final s = await MailReceiveSettings.load(repo);
    return s.imap != null &&
        (await credentials.read(MailSlots.receive))?.isNotEmpty == true;
  }

  /// Anmeldung prüfen (beim Einrichten), ohne etwas zu lesen.
  static Future<void> test(
    MailServer server,
    String password, {
    MailConnector? connector,
  }) async {
    final reader = ImapReader(server, password, connector: connector);
    try {
      await reader.open();
    } finally {
      await reader.close();
    }
  }

  Future<MailPollResult> poll() async {
    final settings = await MailReceiveSettings.load(repo);
    final password = await credentials.read(MailSlots.receive);
    final server = settings.imap;
    if (server == null || password == null || password.isEmpty) {
      return const MailPollResult();
    }
    final reader = ImapReader(server, password, connector: _connector);
    var mails = 0;
    var added = 0;
    final messages = <String>[];
    try {
      await reader.open();
      for (final uid in await reader.searchSubject(helperMailTag)) {
        final head = await reader.header(uid);
        if (head == null || await repo.hasSeenMail(head.messageId)) continue;
        final parts = HelperMailSubject.parse(head.subject);
        // Fremde Mail mit ähnlichem Betreff: nicht anfassen, nicht merken.
        if (parts == null) continue;
        final pairing = await repo.pairing(parts.pairingId);
        if (pairing == null) continue;
        final raw = await reader.body(uid);
        if (raw == null) continue;
        mails++;
        final results = <HelperImportResult>[
          for (final (_, bytes) in Mime.attachments(
            raw,
            extension: helperPackageExtension,
          ))
            await inbox.importBytes(bytes),
        ];
        for (final r in results) {
          added += r.added;
          if (r.error != null) messages.add(r.error!.message);
        }
        await repo.markMailSeen(
          head.messageId,
          _clock(),
          results.isEmpty
              ? 'ohne Anhang'
              : results
                    .map((r) => r.ok ? 'ok:${r.added}' : r.message)
                    .join('; '),
        );
      }
      await repo.setSetting(
        MailSettingKeys.lastPoll,
        _clock().toIso8601String(),
      );
      return MailPollResult(mails: mails, added: added, messages: messages);
    } on MailException catch (e) {
      return MailPollResult(
        mails: mails,
        added: added,
        messages: messages,
        error: e,
      );
    } finally {
      await reader.close();
    }
  }

  Future<DateTime?> lastPoll() async {
    final v = await repo.setting(MailSettingKeys.lastPoll);
    return v == null ? null : DateTime.tryParse(v);
  }
}

/// Fertiges Sammelpaket zum Senden oder Exportieren.
typedef HelperBundle = ({
  String fileName,
  String subject,
  Uint8List bytes,
  List<String> uuids,
});

/// Mithelfer: Belege verschlüsselt ablegen und gesammelt per Mail senden
/// (FA-17.9). Ein Beleg bleibt verschlüsselt auf dem Gerät, bis die
/// Aufbewahrungsfrist nach dem Senden abläuft.
class HelperMailOutbox {
  HelperMailOutbox(
    this.repo, {
    required this.packagesDir,
    required this.credentials,
    MailConnector? connector,
    DateTime Function()? clock,
  }) : _connector = connector,
       _clock = clock ?? DateTime.now;

  final HelperRepository repo;

  /// Ordner der App für verschlüsselte Einzelpakete (`ausgang/`).
  final Directory packagesDir;
  final MailCredentialStore credentials;
  final MailConnector? _connector;
  final DateTime Function() _clock;

  /// Beleg verschlüsselt ablegen (Status „wartet auf Versand“). Erst danach
  /// werden die Aufnahmen gelöscht.
  Future<OutboxEntry> queue({
    required HelperLink link,
    required HelperReceipt receipt,
    required String summary,
    List<File> deleteAfter = const [],
  }) async {
    final bytes = await HelperPackage.seal(
      receipt,
      pairingId: link.pairingId,
      key: link.key,
    );
    await packagesDir.create(recursive: true);
    final file = File(p.join(packagesDir.path, '${receipt.uuid}.jenibeleg'));
    await file.writeAsBytes(bytes, flush: true);
    final entry = OutboxEntry(
      uuid: receipt.uuid,
      createdAt: _clock(),
      fileName: HelperPackage.fileName(link.pairingId, receipt.uuid),
      transport: HelperTransport.mail,
      status: OutboxStatus.queued,
      summary: summary,
      packagePath: file.path,
    );
    await repo.addOutbox(entry);
    for (final f in deleteAfter) {
      if (await f.exists()) await f.delete();
    }
    return entry;
  }

  Future<List<OutboxEntry>> pending() async => [
    for (final e in await repo.outboxWithPackages())
      if (e.status == OutboxStatus.queued) e,
  ];

  /// Ein Sammelpaket aus [entries]; Pakete, die fehlen oder sich nicht
  /// öffnen lassen, werden übersprungen.
  Future<HelperBundle?> bundle(
    HelperLink link,
    List<OutboxEntry> entries, {
    bool consumeSeq = true,
  }) async {
    final receipts = <HelperReceipt>[];
    final uuids = <String>[];
    for (final e in entries) {
      final f = File(e.packagePath);
      if (!await f.exists()) continue;
      try {
        receipts.add(await HelperPackage.open(await f.readAsBytes(), link.key));
        uuids.add(e.uuid);
      } on HelperPackageException {
        continue;
      }
    }
    if (receipts.isEmpty) return null;
    final now = _clock();
    final today = HelperMailSubject.stamp(now);
    var seq = 1;
    if (consumeSeq) {
      final next = HelperMailSchedule.nextSeq(
        await repo.setting(MailSettingKeys.seq),
        today,
      );
      seq = next.$1;
      await repo.setSetting(MailSettingKeys.seq, next.$2);
    }
    final bytes = await HelperPackage.sealBundle(
      receipts,
      pairingId: link.pairingId,
      key: link.key,
    );
    return (
      fileName: HelperPackage.bundleFileName(link.pairingId, '$today-$seq'),
      subject: HelperMailSubject.format(link.pairingId, now, seq),
      bytes: bytes,
      uuids: uuids,
    );
  }

  /// Text der Mail: kurz, ohne Geschäftsdaten.
  static String mailText(HelperLink link, int count) =>
      '${count == 1 ? 'Ein Beleg' : '$count Belege'} von ${link.deviceName} '
      'für ${link.businessName}.\n\n'
      'Der Anhang ist verschlüsselt; nur JeNi bucht auf dem Hauptgerät kann '
      'ihn öffnen. Bitte diese Mail nicht löschen, bis die Belege im Eingang '
      'angekommen sind.';

  /// Alle wartenden Belege in **einer** Mail über das eigene Postfach.
  /// Rückgabe: Zahl gesendeter Belege.
  Future<int> sendPending(HelperLink link) async {
    final to = link.receivingAddress;
    if (to == null || to.isEmpty) {
      throw const MailException(
        'Keine Empfangsadresse – bitte auf dem Hauptgerät neu koppeln.',
      );
    }
    final settings = await MailSendSettings.load(repo);
    final password = await credentials.read(MailSlots.send);
    if (settings == null || password == null || password.isEmpty) {
      throw const MailException('Kein E-Mail-Konto zum Senden eingerichtet.');
    }
    final entries = await pending();
    if (entries.isEmpty) return 0;
    final b = await bundle(link, entries);
    if (b == null) return 0;
    final now = _clock();
    final message = Mime.build(
      from: settings.address,
      to: to,
      subject: b.subject,
      date: now,
      messageId:
          '${b.subject.hashCode.toUnsigned(32)}.${now.microsecondsSinceEpoch}'
          '@jeni-bucht',
      text: mailText(link, b.uuids.length),
      attachmentName: b.fileName,
      attachment: b.bytes,
    );
    await SmtpSender(
      settings.smtp,
      password,
      connector: _connector,
    ).send(from: settings.address, to: to, message: message);
    await repo.markOutboxSent(b.uuids, now);
    await repo.setSetting(MailSettingKeys.lastSend, now.toIso8601String());
    return b.uuids.length;
  }

  /// Ohne eigenes Postfach: Paket an die Mail-App übergeben ([compose]
  /// öffnet das Mailfenster mit Anhang). Gilt als gesendet, wenn die
  /// Mail-App geöffnet wurde.
  Future<int> handOver(
    HelperLink link,
    Future<bool> Function(HelperBundle bundle, String text) compose,
  ) async {
    final entries = await pending();
    if (entries.isEmpty) return 0;
    final b = await bundle(link, entries);
    if (b == null) return 0;
    if (!await compose(b, mailText(link, b.uuids.length))) return 0;
    await repo.markOutboxSent(b.uuids, _clock());
    return b.uuids.length;
  }

  /// „Exportieren“: alle noch gespeicherten Belege als eine Datei (Notweg).
  Future<HelperBundle?> export(HelperLink link) async =>
      bundle(link, await repo.outboxWithPackages(), consumeSeq: false);

  /// Gesendete Pakete nach Ablauf der Frist löschen; wartende nie.
  Future<int> prune({int? days}) async {
    final keep = days ?? await retentionDays();
    var removed = 0;
    for (final e in await repo.outboxWithPackages()) {
      if (e.status == OutboxStatus.queued) continue;
      if (!HelperMailSchedule.expired(
        sentAt: e.sentAt,
        now: _clock(),
        days: keep,
      )) {
        continue;
      }
      final f = File(e.packagePath);
      if (await f.exists()) await f.delete();
      await repo.clearOutboxPackage(e.uuid);
      removed++;
    }
    return removed;
  }

  Future<int> retentionDays() async =>
      int.tryParse(await repo.setting(MailSettingKeys.retentionDays) ?? '') ??
      HelperMailSchedule.defaultRetentionDays;

  Future<bool> smtpConfigured() async =>
      await MailSendSettings.load(repo) != null &&
      (await credentials.read(MailSlots.send))?.isNotEmpty == true;
}
