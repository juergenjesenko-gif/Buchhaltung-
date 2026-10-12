import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'home_shortcut_service.dart';

/// Plattformcode in `android/.../LauncherChannel.kt`. Außerhalb von Android
/// immer „nicht unterstützt“.
class MethodChannelHomeShortcutPlatform implements HomeShortcutPlatform {
  const MethodChannelHomeShortcutPlatform();

  static const _channel = MethodChannel('buchhaltung/launcher');

  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> isSupported() async {
    if (!_android) return false;
    return await _channel.invokeMethod<bool>('isSupported') ?? false;
  }

  @override
  Future<bool> requestPin() async {
    if (!_android) return false;
    return await _channel.invokeMethod<bool>('requestPin') ?? false;
  }
}

/// Merker gerätegebunden, nicht in SQLite und damit nicht in der Sicherung:
/// nach einer Wiederherstellung auf einem neuen Gerät wird erneut gefragt.
class SecureHomeShortcutFlagStore implements HomeShortcutFlagStore {
  const SecureHomeShortcutFlagStore();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

final homeShortcutService = HomeShortcutService(
  const MethodChannelHomeShortcutPlatform(),
  const SecureHomeShortcutFlagStore(),
);
