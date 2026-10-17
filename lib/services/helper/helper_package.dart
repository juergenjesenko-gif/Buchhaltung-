/// Mithelfer-Geräte / Belegsammler (Lastenheft 5.29, FA-17.x).
///
/// Ein Belegpaket (`.jenibeleg`) trägt einen erfassten Beleg vom
/// Mithelfer-Gerät zum Hauptgerät: Werte als JSON und die Seitenbilder,
/// Ende-zu-Ende verschlüsselt mit dem Kopplungsschlüssel (AES-256-GCM wie die
/// automatische Sicherung, `BackupCrypto.encryptWithKey`). Reines Dart.
///
/// ```
/// 4 Byte  Kennung "JBHP"
/// 1 Byte  Formatversion (1 = ein Beleg, 2 = Sammelpaket)
/// 16 Byte Kopplungs-ID
/// 12 Byte Nonce
/// n Byte  Chiffrat (UTF-8-JSON, siehe [HelperReceipt.toJson]; Version 2:
///         `{"v": 2, "receipts": [...]}`)
/// 16 Byte Authentifizierungs-Tag (AEAD; Kopf als zusätzliche Daten)
/// ```
///
/// Version 2 (seit 0.24.0, FA-17.9) trägt mehrere Belege in einer Datei für
/// den Mailweg; Version 1 bleibt lesbar.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Dateiendung der Belegpakete.
const helperPackageExtension = '.jenibeleg';

/// Eigener MIME-Typ der Belegpakete (Android-Intent-Filter, iOS-UTI
/// `at.jesenko.buchhaltung.jenibeleg`). Gesendet wird als
/// `application/octet-stream`, weil Messenger fremde Typen sonst ablehnen.
const helperPackageMimeType = 'application/x-jenibeleg';

/// Kurzhinweis beim Ordnerweg (FA-17.5): gemischte Familien
/// (Android und iPhone) brauchen einen Ordner, den beide Systeme öffnen.
const helperFolderHint =
    'Android und iPhone gemischt? iCloud Drive gibt es auf Android nicht – '
    'nehmt Google Drive, OneDrive oder Dropbox, oder sendet per Messenger '
    'oder Mail.';

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
  static Cipher _defaultCipher() => AesGcm.with256bits();

  static const _magic = [0x4A, 0x42, 0x48, 0x50]; // "JBHP"
  static const formatVersion = 1;

  /// Sammelpaket mit mehreren Belegen (FA-17.9).
  static const bundleVersion = 2;
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

  /// Verpackt [receipt]. Plattformunabhängig: Kopf und Längen als Bytes ohne
  /// Ganzzahlen mit Bytereihenfolge, Werte als UTF-8-JSON, Bilder unverändert
  /// als Base64, AES-256-GCM nach NIST SP 800-38D (FA-17.4). [cipher] und
  /// [nonce] nur für Tests (Gegenprobe, festes Prüfmuster).
  static Future<Uint8List> seal(
    HelperReceipt receipt, {
    required String pairingId,
    required List<int> key,
    Cipher? cipher,
    List<int>? nonce,
  }) => _seal(
    receipt.toJson(),
    version: formatVersion,
    pairingId: pairingId,
    key: key,
    cipher: cipher,
    nonce: nonce,
  );

  /// Sammelpaket (Version 2) mit allen [receipts] in einer Datei.
  static Future<Uint8List> sealBundle(
    List<HelperReceipt> receipts, {
    required String pairingId,
    required List<int> key,
    Cipher? cipher,
    List<int>? nonce,
  }) => _seal(
    {
      'v': bundleVersion,
      'receipts': [for (final r in receipts) r.toJson()],
    },
    version: bundleVersion,
    pairingId: pairingId,
    key: key,
    cipher: cipher,
    nonce: nonce,
  );

  /// Dateiname eines Sammelpakets: Kopplung (8 Zeichen), Tag und Nummer.
  static String bundleFileName(String pairingId, String stamp) =>
      '${pairingId.substring(0, 8)}_$stamp$helperPackageExtension';

  static Future<Uint8List> _seal(
    Map<String, Object?> json, {
    required int version,
    required String pairingId,
    required List<int> key,
    Cipher? cipher,
    List<int>? nonce,
  }) async {
    if (key.length != 32) throw ArgumentError('Schlüssel muss 32 Byte haben');
    final id = fromHex(pairingId);
    if (id.length != 16) throw ArgumentError('Kopplungs-ID ungültig');
    final header = Uint8List.fromList([..._magic, version, ...id]);
    final aes = cipher ?? _defaultCipher();
    final iv = nonce ?? aes.newNonce();
    final box = await aes.encrypt(
      utf8.encode(jsonEncode(json)),
      secretKey: SecretKey(key),
      nonce: iv,
      aad: header,
    );
    return (BytesBuilder()
          ..add(header)
          ..add(iv)
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
    if (data[4] != formatVersion && data[4] != bundleVersion) return null;
    return hex(data.sublist(5, _headerLength));
  }

  /// Entschlüsselt und prüft; wirft [HelperPackageException] mit
  /// [HelperPackageError.notPackage] oder [HelperPackageError.damaged].
  ///
  /// [cipher] nur für Tests: andere AES-GCM-Implementierung (z. B. die reine
  /// Dart-Implementierung gegen die Plattform-Vorgabe), um zu belegen, dass
  /// das Format nicht vom Betriebssystem abhängt.
  static Future<HelperReceipt> open(
    Uint8List data,
    List<int> key, {
    Cipher? cipher,
  }) async => (await openAll(data, key, cipher: cipher)).first;

  /// Alle Belege eines Pakets: Version 1 ergibt einen, Version 2 beliebig
  /// viele (auch keinen).
  static Future<List<HelperReceipt>> openAll(
    Uint8List data,
    List<int> key, {
    Cipher? cipher,
  }) async {
    if (pairingIdOf(data) == null) {
      throw const HelperPackageException(HelperPackageError.notPackage);
    }
    final header = data.sublist(0, _headerLength);
    final nonce = data.sublist(_headerLength, _headerLength + 12);
    final cipherText = data.sublist(_headerLength + 12, data.length - 16);
    final mac = data.sublist(data.length - 16);
    try {
      final aes = cipher ?? _defaultCipher();
      final plain = await aes.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: SecretKey(key),
        aad: header,
      );
      final json = (jsonDecode(utf8.decode(plain)) as Map)
          .cast<String, Object?>();
      if (data[4] == formatVersion) return [HelperReceipt.fromJson(json)];
      return [
        for (final r in json['receipts'] as List)
          HelperReceipt.fromJson((r as Map).cast<String, Object?>()),
      ];
    } on SecretBoxAuthenticationError {
      throw const HelperPackageException(HelperPackageError.damaged);
    } on FormatException {
      throw const HelperPackageException(HelperPackageError.damaged);
    } on TypeError {
      throw const HelperPackageException(HelperPackageError.damaged);
    }
  }
}

/// Weg vom Mithelfer zum Hauptgerät, je Kopplung gewählt.
enum HelperTransport {
  /// E-Mail (Standard seit 0.24.0, FA-17.9): der Mithelfer sendet aus
  /// seinem eigenen Postfach, das Hauptgerät liest die Empfangsadresse.
  mail,

  /// Gemeinsamer Cloud-Ordner des Betriebs (Ordner „Eingang“), optional.
  folder,

  /// Teilen-Blatt von Hand (nur noch für ältere Kopplungen; Notweg ist
  /// „Exportieren“).
  share;

  String get label => switch (this) {
    mail => 'Per E-Mail (automatisch)',
    share => 'Per Datei teilen',
    folder => 'Gemeinsamer Ordner',
  };

  static HelperTransport parse(String? s) => switch (s) {
    'folder' => folder,
    'share' => share,
    _ => mail,
  };
}

/// Inhalt des Kopplungs-QR-Codes auf dem Hauptgerät.
class HelperPairingCode {
  const HelperPairingCode({
    required this.pairingId,
    required this.key,
    required this.businessName,
    required this.deviceName,
    required this.transport,
    this.receivingAddress,
  });

  static const prefix = 'JENIBELEG1:';

  /// Empfangsadresse des Betriebs für den Mailweg (FA-17.9). Nie ein
  /// Kennwort im Code.
  final String? receivingAddress;

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
            if (receivingAddress != null) 'a': receivingAddress,
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
        // Codes vor 0.24.0 ohne Weg galten als Teilen.
        transport: HelperTransport.parse(j['t'] as String? ?? 'share'),
        receivingAddress: j['a'] as String?,
      );
    } on Object {
      return null;
    }
  }
}
