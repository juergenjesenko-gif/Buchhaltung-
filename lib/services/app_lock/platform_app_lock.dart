import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'app_lock_service.dart';

/// Ablage im Schlüsselbund (iOS, nur dieses Gerät) bzw. Keystore-gestützt
/// (Android). Nie in SQLite und damit nie in einer Sicherung.
class SecureAppLockStore implements AppLockStore {
  const SecureAppLockStore();

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Biometrie über das System (`local_auth`). Die App erhält nur „ja/nein",
/// nie biometrische Daten.
class BiometricUnlock {
  const BiometricUnlock();

  static final _auth = LocalAuthentication();

  Future<bool> isAvailable() async {
    try {
      return await _auth.canCheckBiometrics &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on Object {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'JeNi bucht entsperren',
        biometricOnly: true,
      );
    } on Object {
      return false;
    }
  }
}

/// Android: Vorschau im App-Umschalter ausblenden (API 33+,
/// `setRecentsScreenshotEnabled`), ohne Bildschirmfotos zu verbieten.
/// Unter iOS deckt die App sich selbst ab (siehe `AppLockGate`).
class RecentsPrivacy {
  const RecentsPrivacy();

  static const _channel = MethodChannel('buchhaltung/app_lock');

  Future<void> hidePreview(bool hide) async {
    try {
      await _channel.invokeMethod('hideRecentsPreview', {'hide': hide});
    } on MissingPluginException {
      // iOS und Tests: kein Kanal, nichts zu tun.
    } on PlatformException {
      // ältere Android-Versionen: Abdeckung in Flutter genügt.
    }
  }
}
