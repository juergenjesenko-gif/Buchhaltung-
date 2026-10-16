import 'package:sqflite/sqflite.dart';

import '../domain/fixed_asset.dart';
import 'repositories.dart' show AuditLog;

/// Anlagevermögen (FA-15.x). Jede Änderung landet im Protokoll.
class AssetRepository {
  const AssetRepository(this._db);

  final Database _db;

  Future<List<FixedAsset>> all() async {
    final rows = await _db.query(
      'fixed_assets',
      orderBy: 'acquired_on DESC, id DESC',
    );
    return rows.map(FixedAsset.fromMap).toList();
  }

  Future<FixedAsset?> byReceipt(int receiptId) async {
    final rows = await _db.query(
      'fixed_assets',
      where: 'receipt_id = ?',
      whereArgs: [receiptId],
      limit: 1,
    );
    return rows.isEmpty ? null : FixedAsset.fromMap(rows.first);
  }

  Future<int> save(FixedAsset asset) async {
    final map = asset.toMap();
    final audit = AuditLog(_db);
    if (asset.id == null) {
      map['created_at'] = DateTime.now().toIso8601String();
      final id = await _db.insert('fixed_assets', map);
      await audit.record(
        entity: 'fixed_asset',
        entityId: id,
        action: 'create',
        detail:
            '${asset.name} ${asset.cost} ${asset.method.name} '
            '${asset.usefulLifeYears} J. ${asset.lifeReason}',
      );
      return id;
    }
    await _db.update(
      'fixed_assets',
      map,
      where: 'id = ?',
      whereArgs: [asset.id],
    );
    await audit.record(
      entity: 'fixed_asset',
      entityId: asset.id,
      action: asset.isDisposed ? 'dispose' : 'update',
      detail: asset.isDisposed
          ? '${asset.disposalKind?.name} ${asset.disposedOn} '
                '${asset.disposalProceeds} ${asset.disposalComment}'
          : '${asset.name} ${asset.cost} ${asset.usefulLifeYears} J. '
                '${asset.lifeReason}',
    );
    return asset.id!;
  }

  Future<void> delete(int id) async {
    await _db.delete('fixed_assets', where: 'id = ?', whereArgs: [id]);
    await AuditLog(
      _db,
    ).record(entity: 'fixed_asset', entityId: id, action: 'delete');
  }
}
