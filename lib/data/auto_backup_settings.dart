import 'package:sqflite/sqflite.dart';

/// Einstellungen und Zustand der automatischen Sicherung (Schema 6). Bewusst
/// getrennt vom Firmenprofil: das Formular der Stammdaten fasst sie nicht an.
class AutoBackupSettings {
  const AutoBackupSettings({
    required this.enabled,
    this.folder,
    this.folderLabel = '',
    this.lastAt,
    this.lastError,
  });

  final bool enabled;
  final String? folder;
  final String folderLabel;
  final DateTime? lastAt;
  final String? lastError;

  static Future<AutoBackupSettings> load(Database db) async {
    final row = (await db.query('company_profile', limit: 1)).firstOrNull;
    if (row == null) return const AutoBackupSettings(enabled: false);
    return AutoBackupSettings(
      enabled: (row['auto_backup_enabled'] as int? ?? 0) == 1,
      folder: row['auto_backup_target'] as String?,
      folderLabel: row['auto_backup_target_label'] as String? ?? '',
      lastAt: DateTime.tryParse(row['auto_backup_last_at'] as String? ?? ''),
      lastError: row['auto_backup_last_error'] as String?,
    );
  }

  static Future<void> enable(
    Database db, {
    required String folder,
    required String label,
  }) => db.update('company_profile', {
    'auto_backup_enabled': 1,
    'auto_backup_target': folder,
    'auto_backup_target_label': label,
    'auto_backup_last_error': null,
  });

  static Future<void> disable(Database db) => db.update('company_profile', {
    'auto_backup_enabled': 0,
    'auto_backup_target': null,
    'auto_backup_target_label': null,
  });
}
