import 'dart:io';

import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// Datenbankseite der Datensicherung (Lastenheft L-7).
///
/// Die Sicherung ist ein konsistenter Schnappschuss (`VACUUM INTO`), die
/// Wiederherstellung kopiert die Tabellen einer Sicherungsdatei in die offene
/// Datenbank – in einer Transaktion, damit ein Abbruch nichts halb
/// überschreibt. Eine ältere Sicherung wird vorher auf das aktuelle Schema
/// migriert; eine neuere wird abgelehnt.
class BackupRepository {
  const BackupRepository(this._db, {DatabaseFactory? factory})
    : _factory = factory;

  final Database _db;
  final DatabaseFactory? _factory;

  DatabaseFactory get _dbFactory => _factory ?? databaseFactory;

  /// Schreibt einen konsistenten Schnappschuss nach [targetPath].
  Future<void> snapshot(String targetPath) async {
    final target = File(targetPath);
    if (await target.exists()) await target.delete();
    await _db.execute('VACUUM INTO ?', [targetPath]);
  }

  Future<Map<String, int>> counts() async {
    Future<int> count(String table, [String? where]) async {
      final rows = await _db.rawQuery(
        'SELECT COUNT(*) AS n FROM $table${where == null ? '' : ' WHERE $where'}',
      );
      return rows.first['n'] as int? ?? 0;
    }

    return {
      'receipts': await count('receipts'),
      'invoices': await count('invoices'),
      'customers': await count('customers'),
    };
  }

  /// Ersetzt den gesamten Datenbestand durch den der Sicherung unter
  /// [backupPath]. Die Datei wird dabei auf das aktuelle Schema gehoben.
  Future<void> restoreFrom(String backupPath) async {
    final backup = await _dbFactory.openDatabase(
      backupPath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onUpgrade: AppDatabase.upgradeSchema,
        onDowngrade: (_, from, to) => throw StateError(
          'Die Sicherung stammt aus einer neueren App-Version '
          '(Schema $from). Bitte zuerst die App aktualisieren.',
        ),
        singleInstance: false,
      ),
    );
    await backup.close();

    final tables = await _tables();
    await _db.execute('ATTACH DATABASE ? AS sicherung', [backupPath]);
    try {
      await _db.transaction((txn) async {
        await txn.execute('PRAGMA defer_foreign_keys = ON');
        for (final table in tables) {
          await txn.delete(table);
        }
        for (final table in tables) {
          final columns = await _columns(txn, table);
          final list = columns.join(', ');
          await txn.execute(
            'INSERT INTO main.$table ($list) SELECT $list FROM sicherung.$table',
          );
        }
      });
    } finally {
      await _db.execute('DETACH DATABASE sicherung');
    }
  }

  Future<List<String>> _tables() async {
    final rows = await _db.rawQuery(
      "SELECT name FROM main.sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata'",
    );
    return rows.map((r) => r['name'] as String).toList();
  }

  static Future<List<String>> _columns(
    DatabaseExecutor db,
    String table,
  ) async {
    final rows = await db.rawQuery('PRAGMA main.table_info($table)');
    return rows.map((r) => r['name'] as String).toList();
  }
}
