import 'package:sqflite/sqflite.dart';

import '../services/levies/levy_estimator.dart';

/// Angaben für „Abgaben & Rücklagen“ als Schlüssel/Wert (Schema 29).
class LevySettingsRepository {
  const LevySettingsRepository(this._db);

  final Database _db;

  Future<LevySettings> load() async {
    final rows = await _db.query('levy_settings');
    return LevySettings.fromMap({
      for (final r in rows) r['key'] as String: r['value'] as String,
    });
  }

  Future<void> save(LevySettings settings) async {
    final batch = _db.batch();
    batch.delete('levy_settings');
    settings.toMap().forEach(
      (key, value) =>
          batch.insert('levy_settings', {'key': key, 'value': value}),
    );
    await batch.commit(noResult: true);
  }
}
