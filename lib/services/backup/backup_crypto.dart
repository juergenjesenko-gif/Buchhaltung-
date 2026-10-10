import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Verschlüsselung der Datensicherung (Lastenheft L-7.1).
///
/// Schlüssel aus dem Kennwort per Argon2id, Inhalt mit AES-256-GCM. Das
/// Dateiformat ist selbstbeschreibend, damit eine Sicherung auch mit späteren
/// App-Versionen lesbar bleibt:
///
/// ```
/// 4 Byte  Kennung "JBBK"
/// 1 Byte  Formatversion (1)
/// 4 Byte  Argon2id-Speicher in KiB (big endian)
/// 4 Byte  Argon2id-Durchläufe
/// 1 Byte  Argon2id-Parallelität
/// 16 Byte Salz
/// 12 Byte Nonce
/// n Byte  Chiffrat
/// 16 Byte Authentifizierungs-Tag
/// ```
///
/// Ein vergessenes Kennwort lässt sich nicht wiederherstellen – das ist der
/// Preis dafür, dass niemand außer der Nutzerin die Sicherung lesen kann.
class BackupCrypto {
  const BackupCrypto({
    this.memoryKiB = 19456,
    this.iterations = 2,
    this.parallelism = 1,
  });

  /// Parameter nach der OWASP-Empfehlung für Argon2id (19 MiB, 2 Durchläufe).
  final int memoryKiB;
  final int iterations;
  final int parallelism;

  static const _magic = [0x4A, 0x42, 0x42, 0x4B]; // "JBBK"
  static const formatVersion = 1;

  /// Formatversion 2: mit zufälligem Sicherungsschlüssel statt Kennwort, für
  /// die automatische Sicherung. Kopf: Kennung, Version 2, Modus 1, Nonce.
  /// Version 1 bleibt über die gesamte Aufbewahrungsfrist lesbar.
  static const keyFormatVersion = 2;
  static const _keyMode = 1;
  static const _headerLength = 4 + 1 + 4 + 4 + 1 + 16 + 12;

  /// Mindestlänge des Kennworts.
  static const minPassphraseLength = 10;

  Future<Uint8List> encrypt(List<int> plain, String passphrase) async {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final key = await _deriveKey(
      passphrase,
      salt,
      memoryKiB: memoryKiB,
      iterations: iterations,
      parallelism: parallelism,
    );
    final aes = AesGcm.with256bits();
    final nonce = aes.newNonce();
    final box = await aes.encrypt(plain, secretKey: key, nonce: nonce);

    final header = BytesBuilder()
      ..add(_magic)
      ..addByte(formatVersion)
      ..add(_uint32(memoryKiB))
      ..add(_uint32(iterations))
      ..addByte(parallelism)
      ..add(salt)
      ..add(nonce);
    return (header
          ..add(box.cipherText)
          ..add(box.mac.bytes))
        .toBytes();
  }

  /// Verschlüsselt mit einem 256-Bit-Schlüssel (automatische Sicherung).
  static Future<Uint8List> encryptWithKey(
    List<int> plain,
    List<int> key,
  ) async {
    if (key.length != 32) throw ArgumentError('Schlüssel muss 32 Byte haben');
    final aes = AesGcm.with256bits();
    final nonce = aes.newNonce();
    final box = await aes.encrypt(
      plain,
      secretKey: SecretKey(key),
      nonce: nonce,
    );
    return (BytesBuilder()
          ..add(_magic)
          ..addByte(keyFormatVersion)
          ..addByte(_keyMode)
          ..add(nonce)
          ..add(box.cipherText)
          ..add(box.mac.bytes))
        .toBytes();
  }

  /// Wirft [BackupFormatException] bei fremden oder beschädigten Dateien und
  /// [BackupPassphraseException] bei falschem Kennwort. [secret] ist bei
  /// Version 1 das Kennwort, bei Version 2 der Wiederherstellungscode.
  static Future<Uint8List> decrypt(Uint8List data, String secret) async {
    if (data.length < 4 + 2 + 12 + 16 || !_startsWith(data, _magic)) {
      throw const BackupFormatException('Keine Datensicherung dieser App.');
    }
    final version = data[4];
    if (version == keyFormatVersion && data[5] == _keyMode) {
      final key = RecoveryCode.tryDecode(secret);
      if (key == null) throw const BackupPassphraseException();
      return decryptWithKey(data, key);
    }
    final passphrase = secret;
    if (data.length < _headerLength + 16) {
      throw const BackupFormatException('Keine Datensicherung dieser App.');
    }
    if (version != formatVersion) {
      throw BackupFormatException(
        'Sicherungsformat $version wird von dieser App-Version nicht unterstützt.',
      );
    }
    final view = ByteData.sublistView(data);
    final memory = view.getUint32(5);
    final iterations = view.getUint32(9);
    final parallelism = data[13];
    final salt = data.sublist(14, 30);
    final nonce = data.sublist(30, 42);
    final cipherText = data.sublist(42, data.length - 16);
    final mac = Mac(data.sublist(data.length - 16));

    final key = await _deriveKey(
      passphrase,
      salt,
      memoryKiB: memory,
      iterations: iterations,
      parallelism: parallelism,
    );
    try {
      final plain = await AesGcm.with256bits().decrypt(
        SecretBox(cipherText, nonce: nonce, mac: mac),
        secretKey: key,
      );
      return Uint8List.fromList(plain);
    } on SecretBoxAuthenticationError {
      throw const BackupPassphraseException();
    }
  }

  /// Entschlüsselt eine Sicherung der Version 2 mit dem Schlüssel selbst.
  static Future<Uint8List> decryptWithKey(Uint8List data, List<int> key) async {
    if (data.length < 4 + 2 + 12 + 16 ||
        !_startsWith(data, _magic) ||
        data[4] != keyFormatVersion) {
      throw const BackupFormatException('Keine automatische Sicherung.');
    }
    final nonce = data.sublist(6, 18);
    final cipherText = data.sublist(18, data.length - 16);
    final mac = Mac(data.sublist(data.length - 16));
    try {
      final plain = await AesGcm.with256bits().decrypt(
        SecretBox(cipherText, nonce: nonce, mac: mac),
        secretKey: SecretKey(key),
      );
      return Uint8List.fromList(plain);
    } on SecretBoxAuthenticationError {
      throw const BackupPassphraseException();
    }
  }

  static Future<SecretKey> _deriveKey(
    String passphrase,
    List<int> salt, {
    required int memoryKiB,
    required int iterations,
    required int parallelism,
  }) {
    return Argon2id(
      parallelism: parallelism,
      memory: memoryKiB,
      iterations: iterations,
      hashLength: 32,
    ).deriveKey(secretKey: SecretKey(utf8.encode(passphrase)), nonce: salt);
  }

  static List<int> _uint32(int value) =>
      (ByteData(4)..setUint32(0, value)).buffer.asUint8List();

  static bool _startsWith(Uint8List data, List<int> prefix) {
    for (var i = 0; i < prefix.length; i++) {
      if (data[i] != prefix[i]) return false;
    }
    return true;
  }
}

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BackupPassphraseException implements Exception {
  const BackupPassphraseException();
  @override
  String toString() =>
      'Das Kennwort passt nicht zu dieser Sicherung, oder die Datei ist beschädigt.';
}

/// Wiederherstellungscode für die automatische Sicherung: der 256-Bit-Schlüssel
/// in Base32 (RFC 4648, ohne Polsterung), in Vierergruppen. 52 Zeichen; wird
/// einmal angezeigt und muss von der Nutzerin aufbewahrt werden.
class RecoveryCode {
  const RecoveryCode._();

  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  static Uint8List newKey() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
  }

  static String encode(List<int> key) {
    final out = StringBuffer();
    var buffer = 0;
    var bits = 0;
    for (final byte in key) {
      buffer = (buffer << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        out.write(_alphabet[(buffer >> (bits - 5)) & 31]);
        bits -= 5;
      }
    }
    if (bits > 0) out.write(_alphabet[(buffer << (5 - bits)) & 31]);
    final text = out.toString();
    return [
      for (var i = 0; i < text.length; i += 4)
        text.substring(i, min(i + 4, text.length)),
    ].join('-');
  }

  /// `null`, wenn der Code kein gültiger 256-Bit-Schlüssel ist. Leerzeichen,
  /// Bindestriche und Kleinschreibung sind egal; 0/1/8 werden als O/I/B gelesen.
  static Uint8List? tryDecode(String code) {
    final clean = code
        .toUpperCase()
        .replaceAll(RegExp(r'[\s\-]'), '')
        .replaceAll('0', 'O')
        .replaceAll('1', 'I')
        .replaceAll('8', 'B');
    if (clean.length != 52) return null;
    final bytes = <int>[];
    var buffer = 0;
    var bits = 0;
    for (final char in clean.split('')) {
      final value = _alphabet.indexOf(char);
      if (value < 0) return null;
      buffer = ((buffer << 5) | value) & 0xFFFF;
      bits += 5;
      if (bits >= 8) {
        bytes.add((buffer >> (bits - 8)) & 0xFF);
        bits -= 8;
      }
    }
    return bytes.length == 32 ? Uint8List.fromList(bytes) : null;
  }
}
