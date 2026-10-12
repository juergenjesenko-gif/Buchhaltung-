import 'package:sqflite/sqflite.dart';

import '../services/fx/currency_converter.dart';
import '../services/fx/ecb_rates.dart';

/// Lokaler Speicher der abgerufenen EZB-Referenzkurse (Schema 10). Ein Kurs
/// wird nur auf Knopfdruck geladen (L-19.29) und danach offline genutzt.
class ExchangeRateRepository {
  const ExchangeRateRepository(this._db);

  final Database _db;

  Future<void> store(List<EcbRate> rates, {DateTime? now}) async {
    final fetchedAt = (now ?? DateTime.now()).toIso8601String();
    final batch = _db.batch();
    for (final r in rates) {
      batch.insert('ecb_rates', {
        'date': _day(r.date),
        'currency': r.currency,
        'rate_micros': r.rateMicros,
        'fetched_at': fetchedAt,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Alle gespeicherten Tageskurse von [currency] im Monat.
  Future<List<EcbRate>> month(String currency, int year, int month) async {
    final prefix = '$year-${month.toString().padLeft(2, '0')}-';
    final rows = await _db.query(
      'ecb_rates',
      where: 'currency = ? AND date LIKE ?',
      whereArgs: [currency, '$prefix%'],
      orderBy: 'date',
    );
    return rows.map(_fromRow).toList();
  }

  /// Letzter gespeicherter Tageskurs am oder vor [date]. Die EZB notiert an
  /// Wochenenden und TARGET-Feiertagen nicht.
  Future<EcbRate?> onOrBefore(String currency, DateTime date) async {
    final rows = await _db.query(
      'ecb_rates',
      where: 'currency = ? AND date <= ? AND date >= ?',
      whereArgs: [
        currency,
        _day(date),
        _day(date.subtract(const Duration(days: 7))),
      ],
      orderBy: 'date DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  /// Mittel der gespeicherten Tageskurse eines Monats, `null` ohne Daten.
  Future<({int rateMicros, int days})?> monthlyAverage(
    String currency,
    int year,
    int month,
  ) async {
    final rates = await this.month(currency, year, month);
    final avg = CurrencyConverter.average([
      for (final r in rates) r.rateMicros,
    ]);
    return avg == null ? null : (rateMicros: avg, days: rates.length);
  }

  static EcbRate _fromRow(Map<String, Object?> row) => EcbRate(
    DateTime.parse('${row['date']}T00:00:00Z'),
    row['currency'] as String,
    row['rate_micros'] as int,
  );

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Vermerk „Tageskurs vom Finanzamt genehmigt“ im Firmenprofil (L-2.25).
class FxSettings {
  const FxSettings._();

  static Future<bool> dailyRateApproved(Database db) async {
    final row = (await db.query('company_profile', limit: 1)).firstOrNull;
    return (row?['fx_daily_rate_approved'] as int? ?? 0) == 1;
  }

  static Future<void> setDailyRateApproved(Database db, bool approved) => db
      .update('company_profile', {'fx_daily_rate_approved': approved ? 1 : 0});
}
