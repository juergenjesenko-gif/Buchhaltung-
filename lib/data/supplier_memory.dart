import 'package:sqflite/sqflite.dart';

import '../domain/receipt.dart';
import '../services/receipt_scan/supplier_learning.dart';

/// Lernspeicher je Lieferant (Schema 20, FA-2.50). Nur auf dem Gerät; kommt
/// mit der verschlüsselten Sicherung mit, weil er in derselben Datenbank liegt.
class SupplierMemory {
  const SupplierMemory._();

  /// Erster Treffer in der Reihenfolge von [keys] (UID vor Name).
  static Future<LearnedSupplier?> lookup(Database db, List<String> keys) async {
    for (final key in keys) {
      final rows = await db.query(
        'supplier_memory',
        where: 'supplier_key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) continue;
      final r = rows.first;
      final payment = r['payment_method'] as String?;
      return LearnedSupplier(
        counterparty: r['counterparty'] as String? ?? '',
        categoryId: r['category_id'] as int?,
        vatPermille: r['vat_permille'] as int?,
        currency: r['currency'] as String? ?? 'EUR',
        paymentMethod: PaymentMethod.values
            .where((m) => m.name == payment)
            .firstOrNull,
      );
    }
    return null;
  }

  /// Merkt den gespeicherten Beleg unter allen [keys] (UID, bestätigter Name
  /// und die erkannte Schreibweise).
  static Future<void> remember(
    Database db,
    List<String> keys,
    Receipt receipt,
  ) async {
    final name = receipt.counterparty.trim();
    if (name.isEmpty || keys.isEmpty) return;
    final batch = db.batch();
    for (final key in keys.toSet()) {
      batch.insert('supplier_memory', {
        'supplier_key': key,
        'counterparty': name,
        'category_id': receipt.categoryId,
        'vat_permille': receipt.vatPermille,
        'currency': receipt.currency,
        'payment_method': receipt.paymentMethod.name,
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }
}
