/// Mithelfer-Geräte / Belegsammler (Lastenheft 5.29, FA-17.x).
///
/// Ein Belegpaket (`.jenibeleg`) trägt einen erfassten Beleg vom
/// Mithelfer-Gerät zum Hauptgerät: Werte als JSON und die Seitenbilder,
/// Ende-zu-Ende verschlüsselt mit dem Kopplungsschlüssel (AES-256-GCM wie die
/// automatische Sicherung, `BackupCrypto.encryptWithKey`). Reines Dart.
///
/// ```
/// 4 Byte  Kennung "JBHP"
/// 1 Byte  Formatversion (1)
/// 16 Byte Kopplungs-ID
/// 12 Byte Nonce
/// n Byte  Chiffrat (UTF-8-JSON, siehe [HelperReceipt.toJson])
/// 16 Byte Authentifizierungs-Tag (AEAD; Kopf als zusätzliche Daten)
/// ```
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Dateiendung der Belegpakete.
const helperPackageExtension = '.jenibeleg';

/// Ein vom Mithelfer erfasster Beleg. Alles Vorschläge; gebucht wird erst auf
/// dem Hauptgerät.
class HelperReceipt {
  const HelperReceipt({
    required this.uuid,
    required this.deviceName,
    required this.createdAt,
    this.date,
    this.grossCents,
    this.counterparty = '',
    this.categoryName,
    this.description = '',
    this.comment = '',
    this.pages = const [],
  });

  /// Eindeutige Kennung; ein zweiter Import derselben Kennung wird erkannt.
  final String uuid;
  final String deviceName;
  final DateTime createdAt;
  final DateTime? date;

  /// Bruttobetrag in Cent (Geld ist `int`).
  final int? grossCents;
  final String counterparty;
  final String? categoryName;
  final String description;
  final String comment;

  /// Seitenbilder (JPEG/PNG) in Reihenfolge.
  final List<Uint8List> pages;

  Map<String, Object?> toJson() => {
    'v': 1,
    'uuid': uuid,
    'device': deviceName,
    'created': createdAt.toIso8601String(),
    'date': date?.toIso8601String().substring(0, 10),
    'gross': grossCents,
    'counterparty': counterparty,
    'category': categoryName,
    'description': description,
    'comment': comment,
    'pages': [for (final p in pages) base64Encode(p)],
  };

  static HelperReceipt fromJson(Map<String, Object?> j) => HelperReceipt(
    uuid: j['uuid'] as String,
    deviceName: j['device'] as String? ?? '',
    createdAt: DateTime.parse(j['created'] as String),
    date: j['date'] == null ? null : DateTime.parse(j['date'] as String),
    grossCents: (j['gross'] as num?)?.toInt(),
    counterparty: j['counterparty'] as String? ?? '',
    categoryName: j['category'] as String?,
    description: j['description'] as String? ?? '',
    comment: j['comment'] as String? ?? '',
    pages: [
      for (final p in (j['pages'] as List? ?? const []))
        base64Decode(p as String),
    ],
  );
}

/// Warum ein Paket nicht angenommen wurde.
enum HelperPackageError {
  /// Keine Datei dieses Formats.
  notPackage,

  /// Kopplung unbekannt (nie gekoppelt oder auf einem anderen Hauptgerät).
  unknownDevice,

  /// Kopplung wurde auf dem Hauptgerät getrennt.
  revoked,

  /// Inhalt verändert oder beschädigt (Prüfung des Tags fehlgeschlagen).
  damaged;

  String get message => switch (this) {
    notPackage => 'Diese Datei ist kein Belegpaket von JeNi bucht.',
    unknownDevice =>
      'Dieses Belegpaket stammt von einem Gerät, das hier nicht gekoppelt '
          'ist. Bitte das Gerät unter Einstellungen → Mithelfer-Geräte '
          'koppeln.',
    revoked =>
      'Dieses Gerät wurde getrennt. Belege von ihm werden nicht mehr '
          'angenommen; bitte neu koppeln.',
    damaged =>
      'Das Belegpaket ist beschädigt oder wurde verändert und wird nicht '
          'übernommen.',
  };
}

class HelperPackageException implements Exception {
  const HelperPackageException(this.error);
  final HelperPackageError error;

  @override
  String toString() => error.message;
}

abstract final class HelperPackage {
  static const _magic = [0x4A, 0x42, 0x48, 0x50]; // "JBHP"
  static const formatVersion = 1;
  static const _headerLength = 4 + 1 + 16;

  /// Neue Kopplungs-ID (16 Byte) bzw. neuer Schlüssel (32 Byte).
  static Uint8List randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
  }

  static String hex(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List fromHex(String s) => Uint8List.fromList([
    for (var i = 0; i + 1 < s.length; i += 2)
      int.parse(s.substring(i, i + 2), radix: 16),
  ]);

  /// Zufällige UUID (Version 4) für einen Beleg.
  static String newUuid() {
    final b = randomBytes(16);
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = hex(b);
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }

  /// Dateiname: Kopplung (8 Zeichen) und Beleg-UUID.
  static String fileName(String pairingId, String uuid) =>
      '${pairingId.substring(0, 8)}_$uuid$helperPackageExtension';

  static Future<Uint8List> seal(
    HelperReceipt receipt, {
    required String pairingId,
    required List<int> key,
  }) async {
    if (key.length != 32) throw ArgumentError('Schlüssel muss 32 Byte haben');
    final id = fromHex(pairingId);
    if (id.length != 16) throw ArgumentError('Kopplungs-ID ungültig');
    final header = Uint8List.fromList([..._magic, formatVersion, ...id]);
    final aes = AesGcm.with256bits();
    final nonce = aes.newNonce();
    final box = await aes.encrypt(
      utf8.encode(jsonEncode(receipt.toJson())),
      secretKey: SecretKey(key),
      nonce: nonce,
      aad: header,
    );
    return (BytesBuilder()
          ..add(header)
          ..add(nonce)
          ..add(box.cipherText)
          ..add(box.mac.bytes))
        .toBytes();
  }

  /// Kopplungs-ID aus dem Kopf, ohne zu entschlüsseln; `null`, wenn die
  /// Datei kein Belegpaket ist.
  static String? pairingIdOf(Uint8List data) {
    if (data.length < _headerLength + 12 + 16) return null;
    for (var i = 0; i < 4; i++) {
      if (data[i] != _magic[i]) return null;
    }
    if (data[4] != formatVersion) return null;
    return hex(data.sublist(5, _headerLength));
  }

  /// Entschlüsselt und prüft; wirft [HelperPackageException] mit
  /// [HelperPackageError.notPackage] oder [HelperPackageError.damaged].
  static Future<HelperReceipt> open(Uint8List data, List<int> key) async {
    if (pairingIdOf(data) == null) {
      throw const HelperPackageException(HelperPackageError.notPackage);
    }
    final header = data.sublist(0, _headerLength);
    final nonce = data.sublist(_headerLength, _headerLength + 12);
    final cipher = data.sublist(_headerLength + 12, data.length - 16);
    final mac = data.sublist(data.length - 16);
    try {
      final plain = await AesGcm.with256bits().decrypt(
        SecretBox(cipher, nonce: nonce, mac: Mac(mac)),
        secretKey: SecretKey(key),
        aad: header,
      );
      return HelperReceipt.fromJson(
        (jsonDecode(utf8.decode(plain)) as Map).cast<String, Object?>(),
      );
    } on SecretBoxAuthenticationError {
      throw const HelperPackageException(HelperPackageError.damaged);
    } on FormatException {
      throw const HelperPackageException(HelperPackageError.damaged);
    }
  }
}

/// Weg vom Mithelfer zum Hauptgerät, je Kopplung gewählt.
enum HelperTransport {
  /// Teilen-Blatt: Messenger oder Mail (Standard, ohne Einrichtung).
  share,

  /// Gemeinsamer Cloud-Ordner des Betriebs (Ordner „Eingang“).
  folder;

  String get label => switch (this) {
    share => 'Per Messenger oder Mail',
    folder => 'Gemeinsamer Ordner',
  };

  static HelperTransport parse(String? s) => s == 'folder' ? folder : share;
}

/// Inhalt des Kopplungs-QR-Codes auf dem Hauptgerät.
class HelperPairingCode {
  const HelperPairingCode({
    required this.pairingId,
    required this.key,
    required this.businessName,
    required this.deviceName,
    required this.transport,
  });

  static const prefix = 'JENIBELEG1:';

  final String pairingId;
  final Uint8List key;
  final String businessName;
  final String deviceName;
  final HelperTransport transport;

  String encode() =>
      prefix +
      base64Url.encode(
        utf8.encode(
          jsonEncode({
            'i': pairingId,
            'k': base64Url.encode(key),
            'b': businessName,
            'd': deviceName,
            't': transport.name,
          }),
        ),
      );

  /// `null`, wenn [raw] kein Kopplungscode ist.
  static HelperPairingCode? tryParse(String raw) {
    final t = raw.trim();
    if (!t.startsWith(prefix)) return null;
    try {
      final j =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(
                    base64Url.normalize(t.substring(prefix.length)),
                  ),
                ),
              )
              as Map;
      final key = base64Url.decode(j['k'] as String);
      final id = j['i'] as String;
      if (key.length != 32 || !RegExp(r'^[0-9a-f]{32}$').hasMatch(id)) {
        return null;
      }
      return HelperPairingCode(
        pairingId: id,
        key: Uint8List.fromList(key),
        businessName: j['b'] as String? ?? '',
        deviceName: j['d'] as String? ?? '',
        transport: HelperTransport.parse(j['t'] as String?),
      );
    } on Object {
      return null;
    }
  }
}
