import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../data/helper_repository.dart';
import '../backup/backup_target.dart';
import 'helper_package.dart';

/// Ergebnis eines Imports auf dem Hauptgerät.
class HelperImportResult {
  const HelperImportResult._({this.entry, this.error, this.duplicate = false});

  final InboxEntry? entry;
  final HelperPackageError? error;

  /// Derselbe Beleg (gleiche UUID) war schon im Eingang.
  final bool duplicate;

  bool get ok => entry != null;

  String get message {
    if (duplicate) {
      return 'Dieser Beleg ist schon im Eingang und wird nicht doppelt '
          'übernommen.';
    }
    if (error != null) return error!.message;
    return 'Beleg von ${entry!.deviceName} im Eingang.';
  }
}

/// Hauptgerät: koppeln, Pakete annehmen, Eingang abschließen (FA-17.x).
class HelperInbox {
  HelperInbox(this.repo, {required this.pagesDir, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final HelperRepository repo;

  /// Ordner der App für Seitenbilder im Eingang (`eingang/<uuid>/`).
  final Directory pagesDir;
  final DateTime Function() _clock;

  /// Neue Kopplung mit frischem Schlüssel; Rückgabe ist der Inhalt des
  /// QR-Codes.
  Future<HelperPairingCode> createPairing({
    required String deviceName,
    required String businessName,
    required HelperTransport transport,
  }) async {
    final id = HelperPackage.hex(HelperPackage.randomBytes(16));
    final key = HelperPackage.randomBytes(32);
    await repo.addPairing(
      HelperPairing(
        id: id,
        deviceName: deviceName,
        key: key,
        transport: transport,
        createdAt: _clock(),
      ),
    );
    return HelperPairingCode(
      pairingId: id,
      key: key,
      businessName: businessName,
      deviceName: deviceName,
      transport: transport,
    );
  }

  /// Prüft und entschlüsselt ein Paket und legt es in den Eingang.
  Future<HelperImportResult> importBytes(Uint8List data) async {
    final id = HelperPackage.pairingIdOf(data);
    if (id == null) {
      return const HelperImportResult._(error: HelperPackageError.notPackage);
    }
    final pairing = await repo.pairing(id);
    if (pairing == null) {
      return const HelperImportResult._(
        error: HelperPackageError.unknownDevice,
      );
    }
    if (pairing.isRevoked) {
      return const HelperImportResult._(error: HelperPackageError.revoked);
    }
    final HelperReceipt receipt;
    try {
      receipt = await HelperPackage.open(data, pairing.key);
    } on HelperPackageException catch (e) {
      return HelperImportResult._(error: e.error);
    }
    if (await repo.hasInbox(receipt.uuid)) {
      return const HelperImportResult._(duplicate: true);
    }
    final dir = Directory(p.join(pagesDir.path, receipt.uuid));
    await dir.create(recursive: true);
    final paths = <String>[];
    for (var i = 0; i < receipt.pages.length; i++) {
      final bytes = receipt.pages[i];
      final ext = bytes.length > 3 && bytes[0] == 0x89 ? '.png' : '.jpg';
      final file = File(p.join(dir.path, 'seite_${i + 1}$ext'));
      await file.writeAsBytes(bytes, flush: true);
      paths.add(file.path);
    }
    // Gerätename aus der Kopplung, nicht aus dem Paket.
    final named = HelperReceipt.fromJson(
      receipt.toJson()..['device'] = pairing.deviceName,
    );
    await repo.addInbox(named, pairingId: id, pagePaths: paths, now: _clock());
    final entry = (await repo.inbox()).firstWhere((e) => e.uuid == named.uuid);
    return HelperImportResult._(entry: entry);
  }

  /// Liest neue Pakete aus dem gemeinsamen Ordner. Pakete bleiben dort, bis
  /// der Beleg übernommen oder abgelehnt ist (dann sieht der Mithelfer
  /// „übernommen“). Rückgabe: Ergebnisse je neuer Datei.
  Future<List<HelperImportResult>> syncFolder(BackupTarget folder) async {
    if (!await folder.isAvailable()) return const [];
    final results = <HelperImportResult>[];
    for (final name in await folder.list()) {
      if (!name.endsWith(helperPackageExtension)) continue;
      final uuid = _uuidOf(name);
      if (uuid != null && await repo.hasInbox(uuid)) continue;
      results.add(await importBytes(await folder.read(name)));
    }
    return results;
  }

  static String? _uuidOf(String fileName) {
    final m = RegExp(r'_([0-9a-f-]{36})\.jenibeleg$').firstMatch(fileName);
    return m?.group(1);
  }

  /// Beleg gebucht bzw. abgelehnt: Bilder im Eingang und Paket im Ordner
  /// löschen.
  Future<void> close(
    InboxEntry entry,
    InboxStatus status, {
    String reason = '',
    BackupTarget? folder,
  }) async {
    await repo.closeInbox(entry.uuid, status, reason: reason);
    final dir = Directory(p.join(pagesDir.path, entry.uuid));
    if (await dir.exists()) await dir.delete(recursive: true);
    if (folder != null && await folder.isAvailable()) {
      final name = HelperPackage.fileName(entry.pairingId, entry.uuid);
      if ((await folder.list()).contains(name)) await folder.delete(name);
    }
  }

  /// Trennt ein Gerät: Schlüssel gelöscht, Pakete danach abgelehnt. Erneut
  /// koppeln erzeugt einen neuen Schlüssel.
  Future<void> revoke(String pairingId) => repo.revoke(pairingId, _clock());
}

/// Mithelfer-Gerät: Beleg verpacken, senden, Status nachführen.
class HelperOutbox {
  HelperOutbox(this.repo, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final HelperRepository repo;
  final DateTime Function() _clock;

  /// Verpackt den Beleg und übergibt ihn dem Weg der Kopplung. Erst nach
  /// erfolgreichem Senden werden die lokalen Bilder gelöscht; gemerkt wird
  /// nur eine Zusammenfassung ohne Bilder.
  Future<OutboxEntry> send({
    required HelperLink link,
    required HelperReceipt receipt,
    required String summary,
    BackupTarget? folder,
    Future<void> Function(String fileName, Uint8List bytes)? share,
    List<File> deleteAfter = const [],
  }) async {
    final bytes = await HelperPackage.seal(
      receipt,
      pairingId: link.pairingId,
      key: link.key,
    );
    final name = HelperPackage.fileName(link.pairingId, receipt.uuid);
    if (link.transport == HelperTransport.folder) {
      if (folder == null || !await folder.isAvailable()) {
        throw const HelperSendException(
          'Der gemeinsame Ordner ist nicht erreichbar. Bitte in den '
          'Einstellungen neu wählen oder per Messenger senden.',
        );
      }
      await folder.write(name, bytes);
    } else {
      if (share == null) throw const HelperSendException('Teilen fehlt.');
      await share(name, bytes);
    }
    final entry = OutboxEntry(
      uuid: receipt.uuid,
      createdAt: _clock(),
      fileName: name,
      transport: link.transport,
      status: OutboxStatus.sent,
      summary: summary,
    );
    await repo.addOutbox(entry);
    for (final f in deleteAfter) {
      if (await f.exists()) await f.delete();
    }
    return entry;
  }

  /// Ordnerweg: ein Paket, das das Hauptgerät aus dem Ordner entfernt hat,
  /// gilt als übernommen.
  Future<void> refresh(BackupTarget folder) async {
    if (!await folder.isAvailable()) return;
    final present = (await folder.list()).toSet();
    for (final e in await repo.outbox()) {
      if (e.transport == HelperTransport.folder &&
          e.status == OutboxStatus.sent &&
          !present.contains(e.fileName)) {
        await repo.markOutboxAccepted(e.uuid);
      }
    }
  }
}

class HelperSendException implements Exception {
  const HelperSendException(this.message);
  final String message;

  @override
  String toString() => message;
}
