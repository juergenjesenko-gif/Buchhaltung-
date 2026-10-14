import 'package:sqflite/sqflite.dart';

/// Lernspeicher Kassen-ID → Händler (Schema 15, L-27.2). Schlüssel ist
/// `AT:<Kassen-ID>` (RKSV) bzw. `DE:<Seriennummer>` (TSE). Gespeichert wird
/// nur der Name, den die Nutzerin beim Speichern bestätigt hat.
class CashRegisterMerchants {
  const CashRegisterMerchants._();

  static Future<String?> lookup(Database db, String registerKey) async {
    final rows = await db.query(
      'cash_register_merchants',
      columns: ['merchant'],
      where: 'register_key = ?',
      whereArgs: [registerKey],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['merchant'] as String?;
  }

  static Future<void> remember(
    Database db,
    String registerKey,
    String merchant,
  ) async {
    final name = merchant.trim();
    if (name.isEmpty) return;
    await db.insert('cash_register_merchants', {
      'register_key': registerKey,
      'merchant': name,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
