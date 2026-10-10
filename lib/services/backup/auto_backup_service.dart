import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:sqflite/sqflite.dart';

import 'backup_archive.dart';
import 'backup_crypto.dart';
import 'backup_retention.dart';
import 'backup_service.dart';
import 'backup_target.dart';

/// Ergebnis eines Laufs, für Anzeige und Protokoll.
class AutoBackupOutcome {
  const AutoBackupOutcome({
    required this.ran,
    this.fileName,
    this.error,
    this.deleted = const [],
  });

  final bool ran;
  final String? fileName;
  final String? error;
  final List<String> deleted;

  bool get failed => error != null;
}

/// Automatische Sicherung in den gewählten Ordner (Lastenheft L-7.2, L-7.6
/// bis L-7.10).
///
/// Fällig, wenn eingeschaltet, ein Ordner gewählt ist und sich seit der
/// letzten automatischen Sicherung etwas geändert hat – höchstens alle
/// [minInterval]. Ausgelöst beim Start und bei Rückkehr in die App; eine
/// echte Hintergrundausführung gibt es nicht.
///
/// „Erfolgreich" heißt erst nach Probe: die geschriebene Datei wird
/// zurückgelesen und entschlüsselt. Ein Fehlschlag wird gespeichert und
/// angezeigt, nie verschwiegen.
class AutoBackupService {
  AutoBackupService({
    required Database db,
    required BackupService backups,
    required this.target,
    required this.keys,
    this.retention = const BackupRetention(),
    this.minInterval = defaultMinInterval,
  }) : _db = db,
       _backups = backups;

  final Database _db;
  final BackupService _backups;
  final BackupTarget target;
  final BackupKeyStore keys;
  final BackupRetention retention;
  final Duration minInterval;

  /// Höchstens eine automatische Sicherung je Tag.
  static const defaultMinInterval = Duration(hours: 24);

  Future<bool> isDue(DateTime now) async {
    final row = (await _db.query('company_profile', limit: 1)).firstOrNull;
    if (row == null || (row['auto_backup_enabled'] as int? ?? 0) != 1) {
      return false;
    }
    final last = DateTime.tryParse(row['auto_backup_last_at'] as String? ?? '');
    if (last == null) return true;
    if (now.difference(last) < minInterval) return false;
    final changed = await _db.rawQuery(
      'SELECT 1 FROM audit_log WHERE created_at > ? '
      "AND entity != 'backup' LIMIT 1",
      [last.toIso8601String()],
    );
    return changed.isNotEmpty;
  }

  Future<AutoBackupOutcome> runIfDue({DateTime? now}) async {
    final at = now ?? DateTime.now();
    if (!await isDue(at)) return const AutoBackupOutcome(ran: false);
    return run(now: at);
  }

  Future<AutoBackupOutcome> run({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final name = BackupRetention.fileNameFor(at);
    try {
      final key = await keys.read();
      if (key == null) {
        return await _fail(
          at,
          'Kein Sicherungsschlüssel auf diesem Gerät – '
          'automatische Sicherung bitte neu einrichten.',
        );
      }
      if (!await target.isAvailable()) {
        return await _fail(
          at,
          'Der Sicherungsordner ist nicht erreichbar. '
          'Bitte den Ordner neu wählen.',
        );
      }
      final bytes = await _backups.createWithKey(key, now: at);
      await target.write(name, bytes);

      // Probe: zurücklesen, Prüfsumme vergleichen, entschlüsseln, entpacken.
      final readBack = await target.read(name);
      final sha = Sha256();
      final written = (await sha.hash(bytes)).bytes;
      final stored = (await sha.hash(readBack)).bytes;
      if (!_equal(written, stored)) {
        await _tryDelete(name);
        return await _fail(
          at,
          'Die Sicherung wurde unvollständig gespeichert.',
        );
      }
      BackupArchive.unpack(await BackupCrypto.decryptWithKey(readBack, key));

      final deleted = retention.toDelete(await target.list(), at);
      for (final old in deleted) {
        await _tryDelete(old);
      }

      await _db.update('company_profile', {
        'auto_backup_last_at': at.toIso8601String(),
        'auto_backup_last_error': null,
      });
      await _log(at, 'auto_backup', '$name SHA-256 ${_hex(written)}');
      return AutoBackupOutcome(ran: true, fileName: name, deleted: deleted);
    } on Object catch (error) {
      return await _fail(at, 'Sicherung fehlgeschlagen: $error');
    }
  }

  /// „Sicherung prüfen": jüngste automatische Sicherung lesen und
  /// entschlüsseln, ohne etwas zu ersetzen (Prüfinstanz Steuerberater, SB-3).
  Future<BackupManifest> verifyLatest({DateTime? now}) async {
    final key = await keys.read();
    if (key == null) {
      throw const BackupFormatException('Kein Sicherungsschlüssel vorhanden.');
    }
    final names =
        (await target.list())
            .where((n) => BackupRetention.parse(n) != null)
            .toList()
          ..sort();
    if (names.isEmpty) {
      throw const BackupFormatException('Im Ordner liegt keine Sicherung.');
    }
    final data = await target.read(names.last);
    final content = BackupArchive.unpack(
      await BackupCrypto.decryptWithKey(data, key),
    );
    await _log(now ?? DateTime.now(), 'verify', names.last);
    return content.manifest;
  }

  Future<AutoBackupOutcome> _fail(DateTime at, String message) async {
    await _db.update('company_profile', {'auto_backup_last_error': message});
    await _log(at, 'auto_backup_failed', message);
    return AutoBackupOutcome(ran: true, error: message);
  }

  Future<void> _log(DateTime at, String action, String detail) =>
      _db.insert('audit_log', {
        'entity': 'backup',
        'action': action,
        'detail': detail,
        'created_at': at.toIso8601String(),
      });

  Future<void> _tryDelete(String name) async {
    try {
      await target.delete(name);
    } on Object {
      // Beim nächsten Lauf erneut.
    }
  }

  static bool _equal(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Nur für Tests und als Platzhalter ohne Plattform.
class MemoryBackupTarget implements BackupTarget {
  final files = <String, Uint8List>{};
  bool available = true;

  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<List<String>> list() async => files.keys.toList();
  @override
  Future<void> write(String name, Uint8List bytes) async => files[name] = bytes;
  @override
  Future<Uint8List> read(String name) async => files[name]!;
  @override
  Future<void> delete(String name) async => files.remove(name);
}

class MemoryKeyStore implements BackupKeyStore {
  Uint8List? key;
  @override
  Future<Uint8List?> read() async => key;
  @override
  Future<void> write(Uint8List key) async => this.key = key;
  @override
  Future<void> delete() async => key = null;
}
