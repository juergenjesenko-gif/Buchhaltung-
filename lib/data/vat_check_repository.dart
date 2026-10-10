import 'package:sqflite/sqflite.dart';

import '../services/vat_id/vies_client.dart';

/// Prüfprotokoll der UID-Abfragen. Nur Einfügen: jede Abfrage bleibt als
/// Nachweis erhalten (Aufbewahrung wie Buchungsbelege).
class VatCheckRepository {
  const VatCheckRepository(this._db);

  final Database _db;

  static const subjectCompany = 'company';
  static const subjectCustomer = 'customer';

  Future<void> record(
    VatCheck check, {
    required String subject,
    int? subjectId,
  }) {
    return _db.insert('vat_id_checks', {
      'subject': subject,
      'subject_id': subjectId,
      ...check.toJson(),
    });
  }

  /// Letzte Prüfung einer UID, `null` wenn nie geprüft.
  Future<VatCheck?> latest(String vatId) async {
    final rows = await _db.query(
      'vat_id_checks',
      where: 'vat_id = ?',
      whereArgs: [vatId],
      orderBy: 'checked_at DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return VatCheck(
      vatId: row['vat_id'] as String,
      result: VatCheckResult.values.byName(row['result'] as String),
      checkedAt: DateTime.parse(row['checked_at'] as String),
      name: row['name'] as String? ?? '',
      address: row['address'] as String? ?? '',
      requestIdentifier: row['request_identifier'] as String? ?? '',
      errorCode: row['error_code'] as String? ?? '',
    );
  }

  /// Kunden mit UID und einer Rechnung in den letzten [months] Monaten. Nur
  /// sie werden automatisch geprüft (Datenminimierung).
  Future<List<(int, String)>> activeCustomerVatIds(
    DateTime now, {
    int months = 12,
  }) async {
    final since = DateTime(now.year, now.month - months, now.day);
    final rows = await _db.rawQuery(
      '''
      SELECT DISTINCT c.id AS id, c.vat_id AS vat_id FROM customers c
      JOIN invoices i ON i.customer_id = c.id
      WHERE c.vat_id != '' AND i.issue_date >= ?
      ''',
      [since.toIso8601String().substring(0, 10)],
    );
    return [for (final r in rows) (r['id'] as int, r['vat_id'] as String)];
  }

  Future<void> markRun(DateTime at) => _db.update('company_profile', {
    'vat_check_last_run': at.toIso8601String(),
  });
}
