import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Kennwort bzw. App-Passwort eines Postfachs, nur im sicheren Speicher des
/// Geräts (iOS-Schlüsselbund „nur dieses Gerät“, Android Keystore). Nie in
/// Datenbank, Sicherung, QR-Code oder Protokoll (FA-17.9).
abstract interface class MailCredentialStore {
  Future<String?> read(String slot);
  Future<void> write(String slot, String secret);
  Future<void> delete(String slot);
}

/// Steckplätze: Hauptgerät liest (IMAP), Mithelfer sendet (SMTP).
abstract final class MailSlots {
  static const receive = 'mail_receive_password';
  static const send = 'mail_send_password';
}

class SecureMailCredentialStore implements MailCredentialStore {
  const SecureMailCredentialStore();

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      // Auch im Hintergrundabruf lesbar, nachdem das Gerät einmal entsperrt
      // wurde; nicht in iCloud.
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
  );

  @override
  Future<String?> read(String slot) => _storage.read(key: slot);

  @override
  Future<void> write(String slot, String secret) =>
      _storage.write(key: slot, value: secret);

  @override
  Future<void> delete(String slot) => _storage.delete(key: slot);
}

/// Ersatz im Speicher für Tests.
class MemoryMailCredentialStore implements MailCredentialStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String slot) async => values[slot];

  @override
  Future<void> write(String slot, String secret) async => values[slot] = secret;

  @override
  Future<void> delete(String slot) async => values.remove(slot);
}
