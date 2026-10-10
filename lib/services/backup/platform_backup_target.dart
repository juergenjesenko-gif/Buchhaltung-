import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'backup_target.dart';

/// Ordner über die Dateiauswahl des Systems; Plattformcode in
/// `android/.../BackupFolderChannel.kt` und `ios/Runner/BackupFolderChannel.swift`.
class PlatformBackupTarget implements BackupTarget {
  const PlatformBackupTarget(this.folder);

  /// SAF-Baum-URI (Android) bzw. Security-Scoped Bookmark in Base64 (iOS).
  final String folder;

  static const _channel = MethodChannel('buchhaltung/backup_folder');

  /// Öffnet die Ordnerauswahl. `null`, wenn abgebrochen; sonst Ordner und
  /// Anzeigename.
  static Future<({String folder, String label})?> pick() async {
    final result = await _channel.invokeMapMethod<String, Object?>('pick');
    if (result == null) return null;
    return (
      folder: result['folder'] as String,
      label: result['label'] as String? ?? '',
    );
  }

  @override
  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable', {
            'folder': folder,
          }) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<List<String>> list() async =>
      (await _channel.invokeListMethod<String>('list', {'folder': folder})) ??
      const [];

  @override
  Future<void> write(String name, Uint8List bytes) => _channel.invokeMethod(
    'write',
    {'folder': folder, 'name': name, 'bytes': bytes},
  );

  @override
  Future<Uint8List> read(String name) async => (await _channel
      .invokeMethod<Uint8List>('read', {'folder': folder, 'name': name}))!;

  @override
  Future<void> delete(String name) =>
      _channel.invokeMethod('delete', {'folder': folder, 'name': name});
}

/// Schlüssel im Schlüsselbund (iOS, nur dieses Gerät, nicht in iCloud) bzw.
/// Keystore-gestützt verschlüsselt (Android).
class SecureBackupKeyStore implements BackupKeyStore {
  const SecureBackupKeyStore();

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
  );
  static const _name = 'auto_backup_key';

  @override
  Future<Uint8List?> read() async {
    final value = await _storage.read(key: _name);
    return value == null ? null : Uint8List.fromList(_fromHex(value));
  }

  @override
  Future<void> write(Uint8List key) =>
      _storage.write(key: _name, value: _toHex(key));

  @override
  Future<void> delete() => _storage.delete(key: _name);

  static String _toHex(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  static List<int> _fromHex(String s) => [
    for (var i = 0; i < s.length; i += 2)
      int.parse(s.substring(i, i + 2), radix: 16),
  ];
}
