import 'package:sqflite/sqflite.dart';

/// Schalter „Belege automatisch auslesen“ (Schema 9, L-2.23).
class ReceiptScanSettings {
  const ReceiptScanSettings._();

  static Future<bool> isEnabled(Database db) async {
    final row = (await db.query('company_profile', limit: 1)).firstOrNull;
    return (row?['receipt_scan_enabled'] as int? ?? 1) == 1;
  }

  static Future<void> setEnabled(Database db, bool enabled) =>
      db.update('company_profile', {'receipt_scan_enabled': enabled ? 1 : 0});
}
