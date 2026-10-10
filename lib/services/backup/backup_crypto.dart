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

  /// Wirft [BackupFormatException] bei fremden oder beschädigten Dateien und
  /// [BackupPassphraseException] bei falschem Kennwort.
  static Future<Uint8List> decrypt(Uint8List data, String passphrase) async {
    if (data.length < _headerLength + 16 || !_startsWith(data, _magic)) {
      throw const BackupFormatException('Keine Datensicherung dieser App.');
    }
    final version = data[4];
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
