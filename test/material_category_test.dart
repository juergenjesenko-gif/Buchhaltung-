import 'package:buchhaltung/data/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Startkategorie „Material und Werkzeug“ (FA-2.31, Lastenheft 14a,
/// Schema 25).
void main() {
  setUpAll(sqfliteFfiInit);

  Future<Database> open([int version = AppDatabase.schemaVersion]) =>
      databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: version,
          onCreate: AppDatabase.createSchema,
          singleInstance: false,
        ),
      );

  Future<List<Map<String, Object?>>> material(Database db) => db.query(
    'categories',
    where: 'name = ?',
    whereArgs: ['Material und Werkzeug'],
  );

  test('neue Datenbank hat die Kategorie genau einmal', () async {
    final db = await open();
    final rows = await material(db);
    expect(rows, hasLength(1));
    expect(rows.single['direction'], 'expense');
    expect(rows.single['datev_account'], '4985');
    expect(rows.single['is_system'], 1);
    await db.close();
  });

  test('Upgrade von 24 ergänzt sie einmal', () async {
    final db = await open(24);
    await db.delete('categories', where: "name = 'Material und Werkzeug'");
    await AppDatabase.upgradeSchema(db, 24, AppDatabase.schemaVersion);
    expect(await material(db), hasLength(1));
    await db.close();
  });

  test('Upgrade legt keine Doppelte an', () async {
    final db = await open(24);
    await AppDatabase.upgradeSchema(db, 24, AppDatabase.schemaVersion);
    expect(await material(db), hasLength(1));
    await db.close();
  });
}
