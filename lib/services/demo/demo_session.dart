import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../data/app_database.dart';
import '../../data/repositories.dart';
import '../receipt_image_store.dart';
import 'demo_dataset.dart';

/// Öffnet die Muster-Datenbank der Demo (FA-13.14): **im Arbeitsspeicher**,
/// bei jedem Start neu aus [DemoDataset] befüllt, danach per
/// `PRAGMA query_only` schreibgeschützt. Die echte Datei
/// `buchhaltung.db` wird dabei weder gelesen noch geschrieben.
class DemoSession {
  DemoSession._();

  /// [documentsDir]: Dokumentenordner der App; die Belegbilder liegen in
  /// `demo_belege/` darunter und werden vorher geleert. [factory] nur für
  /// Tests (sqflite_common_ffi).
  static Future<Database> open({
    required Directory documentsDir,
    required DateTime today,
    DatabaseFactory? factory,
  }) async {
    final images = Directory(
      p.join(documentsDir.path, ReceiptImageStore.demoFolder),
    );
    if (await images.exists()) await images.delete(recursive: true);
    await images.create(recursive: true);

    final db = await (factory ?? databaseFactory).openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: AppDatabase.createSchema,
        // Eigene Verbindung, nie die geteilte der echten Datenbank.
        singleInstance: false,
      ),
    );
    await DemoDataset.seed(
      db,
      today: today,
      writeImage: (name, Uint8List png) async {
        await File(p.join(images.path, name)).writeAsBytes(png, flush: true);
        return p.join(ReceiptImageStore.demoFolder, name);
      },
    );
    // Was AppState.reload sonst beim Laden nachbucht, schon jetzt.
    await Repositories(db).invoices.bookMissingPayments();
    await db.execute('PRAGMA query_only = ON');
    return db;
  }

  /// Fotos der Demo löschen (beim Verlassen): auch ausprobierte Scans
  /// bleiben nicht auf dem Gerät liegen (FA-13.14, Datenschutz).
  static Future<void> clear(Directory documentsDir) async {
    final images = Directory(
      p.join(documentsDir.path, ReceiptImageStore.demoFolder),
    );
    try {
      if (await images.exists()) await images.delete(recursive: true);
    } on FileSystemException {
      // Beim nächsten Demo-Start erneut.
    }
  }
}
