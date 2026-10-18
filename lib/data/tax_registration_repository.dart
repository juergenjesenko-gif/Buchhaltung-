import 'package:sqflite/sqflite.dart';

import '../domain/tax_registration.dart';

/// Weitere steuerliche Registrierungen (Schema 27, FA-18.x).
class TaxRegistrationRepository {
  const TaxRegistrationRepository(this._db);

  final Database _db;

  Future<List<TaxRegistration>> all() async {
    final rows = await _db.query(
      'tax_registrations',
      orderBy: 'country_code, id',
    );
    return rows.map(TaxRegistration.fromMap).toList();
  }

  Future<int> save(TaxRegistration registration) async {
    final map = registration.toMap();
    if (registration.id == null) {
      return _db.insert('tax_registrations', map);
    }
    await _db.update(
      'tax_registrations',
      map,
      where: 'id = ?',
      whereArgs: [registration.id],
    );
    return registration.id!;
  }

  /// Zahl der Belege mit diesem Steuerland.
  Future<int> usage(int id) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM receipts WHERE tax_registration_id = ?',
      [id],
    );
    return rows.first['n'] as int? ?? 0;
  }

  /// Löscht nur unbenutzte Registrierungen; sonst `false` (dann ein
  /// Ende-Datum setzen, damit die Auswertungen erhalten bleiben).
  Future<bool> delete(int id) async {
    if (await usage(id) > 0) return false;
    await _db.delete('tax_registrations', where: 'id = ?', whereArgs: [id]);
    return true;
  }
}
