import 'dart:typed_data';

/// Ablageort der automatischen Sicherung: ein Ordner, den die Nutzerin einmal
/// über die Dateiauswahl des Systems gewählt hat (iCloud Drive, Google Drive,
/// lokaler Ordner …). Plattformcode liegt hinter dieser Schnittstelle, damit
/// Ablauf, Rotation und Prüfung in reinem Dart testbar bleiben.
abstract class BackupTarget {
  /// Ist der Ordner noch erreichbar und beschreibbar? `false`, wenn die
  /// Berechtigung entzogen oder der Ordner gelöscht wurde.
  Future<bool> isAvailable();

  /// Dateinamen im Ordner (nur Namen, keine Pfade).
  Future<List<String>> list();

  Future<void> write(String name, Uint8List bytes);
  Future<Uint8List> read(String name);
  Future<void> delete(String name);
}

/// Hält den Schlüssel der automatischen Sicherung geräteintern (Schlüsselbund
/// bzw. Keystore, nicht synchronisiert).
abstract class BackupKeyStore {
  Future<Uint8List?> read();
  Future<void> write(Uint8List key);
  Future<void> delete();
}
