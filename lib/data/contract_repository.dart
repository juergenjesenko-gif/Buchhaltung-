import 'package:sqflite/sqflite.dart';

import '../domain/contract.dart';
import '../domain/receipt.dart';
import 'repositories.dart' show AuditLog;

/// Vertragsarchiv (FA-16.x). Seiten nur anhängen, Änderungen im Protokoll.
class ContractRepository {
  const ContractRepository(this._db);

  final Database _db;

  Future<List<String>> _pages(int id) async {
    final rows = await _db.query(
      'contract_pages',
      where: 'contract_id = ?',
      whereArgs: [id],
      orderBy: 'position ASC',
    );
    return [for (final r in rows) r['image_path'] as String];
  }

  Future<List<Contract>> all() async {
    final rows = await _db.query('contracts', orderBy: 'title COLLATE NOCASE');
    return [
      for (final r in rows) Contract.fromMap(r, await _pages(r['id'] as int)),
    ];
  }

  Future<Contract?> byId(int id) async {
    final rows = await _db.query(
      'contracts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Contract.fromMap(rows.first, await _pages(id));
  }

  /// Speichert den Vertrag; [newPages] werden hinten angehängt.
  Future<int> save(Contract c, {List<String> newPages = const []}) {
    return _db.transaction((txn) async {
      final map = c.toMap();
      final int id;
      if (c.id == null) {
        map['created_at'] = DateTime.now().toIso8601String();
        id = await txn.insert('contracts', map);
      } else {
        id = c.id!;
        await txn.update('contracts', map, where: 'id = ?', whereArgs: [id]);
      }
      final existing =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM contract_pages WHERE contract_id = ?',
              [id],
            ),
          ) ??
          0;
      for (var i = 0; i < newPages.length; i++) {
        await txn.insert('contract_pages', {
          'contract_id': id,
          'position': existing + i,
          'image_path': newPages[i],
        });
      }
      await AuditLog(_db).record(
        entity: 'contract',
        entityId: id,
        action: c.id == null ? 'create' : 'update',
        detail: '${c.type.name} ${c.title}, +${newPages.length} Seite(n)',
        txn: txn,
      );
      return id;
    });
  }

  Future<void> delete(int id) async {
    // Ausdrücklich, auch ohne PRAGMA foreign_keys.
    await _db.delete(
      'contract_pages',
      where: 'contract_id = ?',
      whereArgs: [id],
    );
    await _db.delete(
      'contract_receipts',
      where: 'contract_id = ?',
      whereArgs: [id],
    );
    await _db.delete('contracts', where: 'id = ?', whereArgs: [id]);
    await AuditLog(
      _db,
    ).record(entity: 'contract', entityId: id, action: 'delete');
  }

  Future<void> link(int contractId, int receiptId) async {
    await _db.insert('contract_receipts', {
      'contract_id': contractId,
      'receipt_id': receiptId,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await AuditLog(_db).record(
      entity: 'contract',
      entityId: contractId,
      action: 'link',
      detail: 'Beleg $receiptId',
    );
  }

  Future<void> unlink(int contractId, int receiptId) async {
    await _db.delete(
      'contract_receipts',
      where: 'contract_id = ? AND receipt_id = ?',
      whereArgs: [contractId, receiptId],
    );
    await AuditLog(_db).record(
      entity: 'contract',
      entityId: contractId,
      action: 'unlink',
      detail: 'Beleg $receiptId',
    );
  }

  /// Verknüpfte, nicht stornierte Belege, älteste zuerst.
  Future<List<Receipt>> linkedReceipts(int contractId) async {
    final rows = await _db.rawQuery(
      '''
      SELECT r.* FROM receipts r
      JOIN contract_receipts cr ON cr.receipt_id = r.id
      WHERE cr.contract_id = ? AND r.cancelled_at IS NULL
      ORDER BY r.date ASC
      ''',
      [contractId],
    );
    return rows.map((r) => Receipt.fromMap(r)).toList();
  }
}
