import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../services/helper/helper_package.dart';

/// Kopplung auf dem Hauptgerät (Schema 24 `helper_pairings`).
class HelperPairing {
  const HelperPairing({
    required this.id,
    required this.deviceName,
    required this.key,
    required this.transport,
    required this.createdAt,
    this.revokedAt,
  });

  final String id;
  final String deviceName;
  final Uint8List key;
  final HelperTransport transport;
  final DateTime createdAt;
  final DateTime? revokedAt;

  bool get isRevoked => revokedAt != null;
}

/// Eigene Kopplung auf dem Mithelfer-Gerät (`helper_settings`, Schlüssel
/// `link`).
class HelperLink {
  const HelperLink({
    required this.pairingId,
    required this.key,
    required this.businessName,
    required this.deviceName,
    required this.transport,
    this.folder,
    this.folderLabel,
    this.receivingAddress,
  });

  /// Empfangsadresse des Betriebs aus dem QR-Code (Mailweg, FA-17.9).
  final String? receivingAddress;

  final String pairingId;
  final Uint8List key;
  final String businessName;
  final String deviceName;
  final HelperTransport transport;

  /// Ordner „Eingang“ (SAF-URI bzw. Bookmark), nur bei [HelperTransport.folder].
  final String? folder;
  final String? folderLabel;

  Map<String, Object?> toJson() => {
    'id': pairingId,
    'key': HelperPackage.hex(key),
    'business': businessName,
    'device': deviceName,
    'transport': transport.name,
    'folder': folder,
    'folderLabel': folderLabel,
    'address': receivingAddress,
  };

  static HelperLink fromJson(Map<String, Object?> j) => HelperLink(
    pairingId: j['id'] as String,
    key: HelperPackage.fromHex(j['key'] as String),
    businessName: j['business'] as String? ?? '',
    deviceName: j['device'] as String? ?? '',
    transport: HelperTransport.parse(j['transport'] as String?),
    folder: j['folder'] as String?,
    folderLabel: j['folderLabel'] as String?,
    receivingAddress: j['address'] as String?,
  );

  HelperLink withFolder(String? folder, String? label) => HelperLink(
    pairingId: pairingId,
    key: key,
    businessName: businessName,
    deviceName: deviceName,
    transport: transport,
    folder: folder,
    folderLabel: label,
    receivingAddress: receivingAddress,
  );
}

enum InboxStatus { pending, accepted, rejected }

/// Eingegangener Beleg auf dem Hauptgerät (`helper_inbox`).
class InboxEntry {
  const InboxEntry({
    required this.uuid,
    required this.pairingId,
    required this.deviceName,
    required this.receivedAt,
    required this.status,
    required this.receipt,
    required this.pagePaths,
    this.reason = '',
  });

  final String uuid;
  final String pairingId;
  final String deviceName;
  final DateTime receivedAt;
  final InboxStatus status;
  final String reason;

  /// Werte ohne Bilder.
  final HelperReceipt receipt;

  /// Absolute Pfade der Seitenbilder im Eingangsordner der App.
  final List<String> pagePaths;
}

enum OutboxStatus {
  /// Mailweg: verschlüsselt abgelegt, wartet auf den nächsten Versand.
  queued,
  sent,
  accepted;

  String get label => switch (this) {
    queued => 'wartet auf Versand',
    sent => 'gesendet',
    accepted => 'übernommen',
  };
}

/// Beleg auf dem Mithelfer-Gerät (`helper_outbox`). Bilder nur im
/// verschlüsselten Paket [packagePath] (Mailweg, FA-17.9), bis die
/// Aufbewahrungsfrist abläuft; sonst nur die Zusammenfassung.
class OutboxEntry {
  const OutboxEntry({
    required this.uuid,
    required this.createdAt,
    required this.fileName,
    required this.transport,
    required this.status,
    required this.summary,
    this.sentAt,
    this.packagePath = '',
  });

  final String uuid;
  final DateTime createdAt;
  final String fileName;
  final HelperTransport transport;
  final OutboxStatus status;
  final String summary;
  final DateTime? sentAt;

  /// Absoluter Pfad des verschlüsselten Einzelpakets; leer, wenn gelöscht.
  final String packagePath;
}

class HelperRepository {
  HelperRepository(this.db);

  final Database db;

  // ----------------------------------------------------------- Hauptgerät

  Future<List<HelperPairing>> pairings() async => [
    for (final r in await db.query('helper_pairings', orderBy: 'created_at'))
      HelperPairing(
        id: r['id'] as String,
        deviceName: r['device_name'] as String,
        key: HelperPackage.fromHex(r['key_hex'] as String),
        transport: HelperTransport.parse(r['transport'] as String?),
        createdAt: DateTime.parse(r['created_at'] as String),
        revokedAt: r['revoked_at'] == null
            ? null
            : DateTime.parse(r['revoked_at'] as String),
      ),
  ];

  Future<HelperPairing?> pairing(String id) async {
    for (final p in await pairings()) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> addPairing(HelperPairing p) => db.insert('helper_pairings', {
    'id': p.id,
    'device_name': p.deviceName,
    'key_hex': HelperPackage.hex(p.key),
    'transport': p.transport.name,
    'created_at': p.createdAt.toIso8601String(),
  });

  /// Trennt die Kopplung; der Schlüssel wird gelöscht, spätere Pakete werden
  /// abgelehnt.
  Future<void> revoke(String id, DateTime now) => db.update(
    'helper_pairings',
    {'revoked_at': now.toIso8601String(), 'key_hex': ''},
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<bool> hasInbox(String uuid) async => (await db.query(
    'helper_inbox',
    where: 'uuid = ?',
    whereArgs: [uuid],
  )).isNotEmpty;

  Future<void> addInbox(
    HelperReceipt r, {
    required String pairingId,
    required List<String> pagePaths,
    required DateTime now,
  }) {
    final values = r.toJson()..remove('pages');
    return db.insert('helper_inbox', {
      'uuid': r.uuid,
      'pairing_id': pairingId,
      'device_name': r.deviceName,
      'received_at': now.toIso8601String(),
      'status': InboxStatus.pending.name,
      'values_json': jsonEncode(values),
      'page_paths': pagePaths.join('\n'),
    });
  }

  Future<List<InboxEntry>> inbox({bool pendingOnly = true}) async => [
    for (final r in await db.query(
      'helper_inbox',
      where: pendingOnly ? 'status = ?' : null,
      whereArgs: pendingOnly ? [InboxStatus.pending.name] : null,
      orderBy: 'received_at DESC',
    ))
      InboxEntry(
        uuid: r['uuid'] as String,
        pairingId: r['pairing_id'] as String,
        deviceName: r['device_name'] as String,
        receivedAt: DateTime.parse(r['received_at'] as String),
        status: InboxStatus.values.byName(r['status'] as String),
        reason: r['reason'] as String,
        receipt: HelperReceipt.fromJson(
          (jsonDecode(r['values_json'] as String) as Map)
              .cast<String, Object?>(),
        ),
        pagePaths: [
          for (final p in (r['page_paths'] as String).split('\n'))
            if (p.isNotEmpty) p,
        ],
      ),
  ];

  Future<void> closeInbox(
    String uuid,
    InboxStatus status, {
    String reason = '',
  }) => db.update(
    'helper_inbox',
    {'status': status.name, 'reason': reason, 'page_paths': ''},
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  // ------------------------------------------------------------ Mithelfer

  /// Belege, Rechnungen oder Angebote vorhanden? (FA-17.13)
  Future<bool> hasBookkeepingData() async {
    for (final table in const ['receipts', 'invoices']) {
      final rows = await db.rawQuery('SELECT 1 FROM $table LIMIT 1');
      if (rows.isNotEmpty) return true;
    }
    return false;
  }

  Future<String?> setting(String key) async {
    final rows = await db.query(
      'helper_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setSetting(String key, String? value) async {
    if (value == null) {
      await db.delete('helper_settings', where: 'key = ?', whereArgs: [key]);
      return;
    }
    await db.insert('helper_settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<HelperLink?> link() async {
    final v = await setting('link');
    return v == null
        ? null
        : HelperLink.fromJson((jsonDecode(v) as Map).cast<String, Object?>());
  }

  Future<void> saveLink(HelperLink? link) =>
      setSetting('link', link == null ? null : jsonEncode(link.toJson()));

  Future<void> addOutbox(OutboxEntry e) => db.insert('helper_outbox', {
    'uuid': e.uuid,
    'created_at': e.createdAt.toIso8601String(),
    'file_name': e.fileName,
    'transport': e.transport.name,
    'status': e.status.name,
    'summary': e.summary,
    'sent_at': e.sentAt?.toIso8601String(),
    'package_path': e.packagePath,
  });

  /// Mailweg: Belege als gesendet markieren.
  Future<void> markOutboxSent(Iterable<String> uuids, DateTime now) async {
    for (final u in uuids) {
      await db.update(
        'helper_outbox',
        {'status': OutboxStatus.sent.name, 'sent_at': now.toIso8601String()},
        where: 'uuid = ? AND status = ?',
        whereArgs: [u, OutboxStatus.queued.name],
      );
    }
  }

  /// Paket nach Ablauf der Frist gelöscht: Pfad leeren.
  Future<void> clearOutboxPackage(String uuid) => db.update(
    'helper_outbox',
    {'package_path': ''},
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  /// Alle Belege mit noch vorhandenem Paket (für Versand, Export, Frist).
  Future<List<OutboxEntry>> outboxWithPackages() async => [
    for (final r in await db.query(
      'helper_outbox',
      where: "package_path <> ''",
      orderBy: 'created_at',
    ))
      _outbox(r),
  ];

  // ------------------------------------------------------ Mailweg Hauptgerät

  Future<bool> hasSeenMail(String messageId) async => (await db.query(
    'helper_mail_seen',
    where: 'message_id = ?',
    whereArgs: [messageId],
  )).isNotEmpty;

  Future<void> markMailSeen(String messageId, DateTime now, String result) =>
      db.insert('helper_mail_seen', {
        'message_id': messageId,
        'seen_at': now.toIso8601String(),
        'result': result,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> markOutboxAccepted(String uuid) => db.update(
    'helper_outbox',
    {'status': OutboxStatus.accepted.name},
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  Future<List<OutboxEntry>> outbox() async => [
    for (final r in await db.query(
      'helper_outbox',
      orderBy: 'created_at DESC',
      limit: 100,
    ))
      _outbox(r),
  ];

  static OutboxEntry _outbox(Map<String, Object?> r) => OutboxEntry(
    uuid: r['uuid'] as String,
    createdAt: DateTime.parse(r['created_at'] as String),
    fileName: r['file_name'] as String,
    transport: HelperTransport.parse(r['transport'] as String?),
    status: OutboxStatus.values.byName(r['status'] as String),
    summary: r['summary'] as String,
    sentAt: r['sent_at'] == null
        ? null
        : DateTime.parse(r['sent_at'] as String),
    packagePath: r['package_path'] as String? ?? '',
  );
}
