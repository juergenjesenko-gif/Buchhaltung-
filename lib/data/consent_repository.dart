import 'package:sqflite/sqflite.dart';

import '../domain/legal_texts.dart';

/// Nachweis der Bestätigungen (L-17.3): Art, Fassung, Zeitpunkt. Nur
/// Einfügen; liegt in der Datenbank und damit in jeder Sicherung.
class ConsentRepository {
  const ConsentRepository(this._db);

  final Database _db;

  /// Texte, deren aktuelle Fassung noch nicht bestätigt ist (L-17.4).
  Future<List<LegalText>> missing() async {
    final rows = await _db.query('consents', columns: ['kind', 'version']);
    final accepted = {for (final r in rows) '${r['kind']}@${r['version']}'};
    return [
      for (final text in LegalText.all)
        if (!accepted.contains('${text.kind}@${text.version}')) text,
    ];
  }

  Future<void> accept(List<LegalText> texts, {DateTime? now}) async {
    final at = (now ?? DateTime.now()).toIso8601String();
    final batch = _db.batch();
    for (final text in texts) {
      batch.insert('consents', {
        'kind': text.kind,
        'version': text.version,
        'accepted_at': at,
      });
    }
    await batch.commit(noResult: true);
  }
}
