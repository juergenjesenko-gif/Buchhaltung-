import 'dart:convert';

import 'license_policy.dart';

/// Ablage des zuletzt bestätigten Lizenzstands (L-22.4: Schlüsselbund bzw.
/// Keystore). Nie in SQLite und damit nie in einer Sicherung.
abstract class LicenseCache {
  Future<LicenseRecord> load();
  Future<void> save(LicenseRecord record);
}

/// Für Tests und als Rückfall ohne Schlüsselbund.
class MemoryLicenseCache implements LicenseCache {
  MemoryLicenseCache([this.record = const LicenseRecord()]);

  LicenseRecord record;

  @override
  Future<LicenseRecord> load() async => record;

  @override
  Future<void> save(LicenseRecord record) async => this.record = record;
}

/// Liest und schreibt den Stand als JSON über eine Schlüssel-Wert-Ablage.
class KeyValueLicenseCache implements LicenseCache {
  KeyValueLicenseCache({required this.read, required this.write});

  static const key = 'license_record';

  final Future<String?> Function(String key) read;
  final Future<void> Function(String key, String value) write;

  @override
  Future<LicenseRecord> load() async {
    try {
      final raw = await read(key);
      if (raw == null) return const LicenseRecord();
      return LicenseRecord.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
    } on Object {
      return const LicenseRecord();
    }
  }

  @override
  Future<void> save(LicenseRecord record) =>
      write(key, jsonEncode(record.toJson()));
}
