import 'dart:io';
import 'dart:typed_data';

import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/helper_repository.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/features/helper/helper_home_screen.dart';
import 'package:buchhaltung/services/backup/backup_target.dart';
import 'package:buchhaltung/services/helper/helper_exchange.dart';
import 'package:buchhaltung/services/helper/helper_package.dart';
import 'package:buchhaltung/services/licensing/license_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'dashboard_refresh_test.dart' show settle;

/// Gemeinsamer Ordner im Speicher (statt SAF/iCloud).
class FakeFolder implements BackupTarget {
  final files = <String, Uint8List>{};

  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<List<String>> list() async => files.keys.toList();
  @override
  Future<void> write(String name, Uint8List bytes) async => files[name] = bytes;
  @override
  Future<Uint8List> read(String name) async => files[name]!;
  @override
  Future<void> delete(String name) async => files.remove(name);
}

Future<Database> _db() => databaseFactoryFfi.openDatabase(
  inMemoryDatabasePath,
  options: OpenDatabaseOptions(
    version: AppDatabase.schemaVersion,
    onCreate: AppDatabase.createSchema,
    singleInstance: false,
  ),
);

HelperReceipt _receipt([String? uuid]) => HelperReceipt(
  uuid: uuid ?? HelperPackage.newUuid(),
  deviceName: 'Handy Anna',
  createdAt: DateTime(2026, 10, 17, 9),
  date: DateTime(2026, 10, 16),
  grossCents: 2146,
  counterparty: 'BAUHAUS Depot GmbH',
  categoryName: 'Sonstige Ausgaben',
  description: 'Lasurpinsel u. a.',
  comment: 'für die Terrasse',
  pages: [
    Uint8List.fromList([0xFF, 0xD8, 1, 2, 3]),
  ],
);

void main() {
  late Directory tmp;
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting('de');
  });
  setUp(() async => tmp = await Directory.systemTemp.createTemp('eingang'));
  tearDown(() async => tmp.delete(recursive: true));

  Future<(HelperInbox, HelperRepository, HelperLink)> pair({
    HelperTransport transport = HelperTransport.share,
  }) async {
    final main = HelperRepository(await _db());
    final inbox = HelperInbox(main, pagesDir: tmp);
    final code = HelperPairingCode.tryParse(
      (await inbox.createPairing(
        deviceName: 'Handy Anna',
        businessName: 'Tischlerei Muster',
        transport: transport,
      )).encode(),
    )!;
    final link = HelperLink(
      pairingId: code.pairingId,
      key: code.key,
      businessName: code.businessName,
      deviceName: code.deviceName,
      transport: code.transport,
    );
    return (inbox, main, link);
  }

  test(
    'Paket: verschlüsseln und öffnen, Werte und Seiten unverändert',
    () async {
      final key = HelperPackage.randomBytes(32);
      final id = HelperPackage.hex(HelperPackage.randomBytes(16));
      final r = _receipt();
      final bytes = await HelperPackage.seal(r, pairingId: id, key: key);
      expect(HelperPackage.pairingIdOf(bytes), id);
      // Klartext steht nicht im Paket.
      expect(String.fromCharCodes(bytes).contains('BAUHAUS'), isFalse);
      final back = await HelperPackage.open(bytes, key);
      expect(back.uuid, r.uuid);
      expect(back.grossCents, 2146);
      expect(back.counterparty, 'BAUHAUS Depot GmbH');
      expect(back.pages.single, r.pages.single);
    },
  );

  test(
    'Paket: verändertes Byte oder falscher Schlüssel → beschädigt',
    () async {
      final key = HelperPackage.randomBytes(32);
      final id = HelperPackage.hex(HelperPackage.randomBytes(16));
      final bytes = await HelperPackage.seal(
        _receipt(),
        pairingId: id,
        key: key,
      );
      final tampered = Uint8List.fromList(bytes)..[bytes.length - 20] ^= 1;
      await expectLater(
        HelperPackage.open(tampered, key),
        throwsA(
          isA<HelperPackageException>().having(
            (e) => e.error,
            'error',
            HelperPackageError.damaged,
          ),
        ),
      );
      await expectLater(
        HelperPackage.open(bytes, HelperPackage.randomBytes(32)),
        throwsA(isA<HelperPackageException>()),
      );
      // Kopf (Kopplungs-ID) ist mitgeschützt.
      final header = Uint8List.fromList(bytes)..[6] ^= 1;
      await expectLater(
        HelperPackage.open(header, key),
        throwsA(isA<HelperPackageException>()),
      );
    },
  );

  test('Kopplungscode: kodieren und lesen, Fremdes abgelehnt', () {
    final code = HelperPairingCode(
      pairingId: HelperPackage.hex(HelperPackage.randomBytes(16)),
      key: HelperPackage.randomBytes(32),
      businessName: 'Tischlerei Müller',
      deviceName: 'Handy Anna',
      transport: HelperTransport.folder,
    );
    final back = HelperPairingCode.tryParse(code.encode())!;
    expect(back.businessName, 'Tischlerei Müller');
    expect(back.transport, HelperTransport.folder);
    expect(back.key, code.key);
    expect(HelperPairingCode.tryParse('https://example.com'), isNull);
    expect(HelperPairingCode.tryParse('JENIBELEG1:kaputt'), isNull);
  });

  test(
    'Teilen: Paket per Messenger kommt in den Eingang, doppelt erkannt',
    () async {
      final (inbox, main, link) = await pair();
      final helper = HelperRepository(await _db());
      Uint8List? shared;
      final page = File('${tmp.path}/scan.jpg')..writeAsBytesSync([1, 2, 3]);
      final r = _receipt();
      await HelperOutbox(helper).send(
        link: link,
        receipt: r,
        summary: '21,46 € · BAUHAUS',
        share: (name, bytes) async {
          expect(name, endsWith(helperPackageExtension));
          shared = bytes;
        },
        deleteAfter: [page],
      );
      // Mithelfer behält keine Bilder, nur die Zusammenfassung.
      expect(page.existsSync(), isFalse);
      expect((await helper.outbox()).single.status, OutboxStatus.sent);

      final first = await inbox.importBytes(shared!);
      expect(first.ok, isTrue);
      expect(first.entry!.deviceName, 'Handy Anna');
      expect(File(first.entry!.pagePaths.single).existsSync(), isTrue);
      final again = await inbox.importBytes(shared!);
      expect(again.duplicate, isTrue);
      expect((await main.inbox()).length, 1);

      await inbox.close(first.entry!, InboxStatus.accepted);
      expect(await main.inbox(), isEmpty);
      expect(Directory('${tmp.path}/${r.uuid}').existsSync(), isFalse);
    },
  );

  test('Getrennt oder unbekannt: Paket abgelehnt mit klarer Meldung', () async {
    final (inbox, main, link) = await pair();
    final bytes = await HelperPackage.seal(
      _receipt(),
      pairingId: link.pairingId,
      key: link.key,
    );
    await inbox.revoke(link.pairingId);
    final revoked = await inbox.importBytes(bytes);
    expect(revoked.error, HelperPackageError.revoked);
    expect(revoked.message, contains('getrennt'));

    final stranger = await HelperPackage.seal(
      _receipt(),
      pairingId: HelperPackage.hex(HelperPackage.randomBytes(16)),
      key: HelperPackage.randomBytes(32),
    );
    expect(
      (await inbox.importBytes(stranger)).error,
      HelperPackageError.unknownDevice,
    );
    expect(
      (await inbox.importBytes(Uint8List.fromList([1, 2, 3]))).error,
      HelperPackageError.notPackage,
    );
    expect(await main.inbox(), isEmpty);
  });

  test('Ordner: Hauptgerät liest, nach Übernahme gilt „übernommen“', () async {
    final (inbox, main, link) = await pair(transport: HelperTransport.folder);
    final folder = FakeFolder();
    final helper = HelperRepository(await _db());
    final outbox = HelperOutbox(helper);
    await outbox.send(
      link: link,
      receipt: _receipt(),
      summary: 'Beleg',
      folder: folder,
    );
    expect(folder.files, hasLength(1));
    final results = await inbox.syncFolder(folder);
    expect(results.single.ok, isTrue);
    // Zweiter Lauf: nichts Neues, Paket bleibt bis zur Übernahme.
    expect(await inbox.syncFolder(folder), isEmpty);
    await outbox.refresh(folder);
    expect((await helper.outbox()).single.status, OutboxStatus.sent);

    await inbox.close(
      (await main.inbox()).single,
      InboxStatus.accepted,
      folder: folder,
    );
    expect(folder.files, isEmpty);
    await outbox.refresh(folder);
    expect((await helper.outbox()).single.status, OutboxStatus.accepted);
  });

  test('Ordner nicht gewählt: Senden meldet es, nichts verloren', () async {
    final (_, _, link) = await pair(transport: HelperTransport.folder);
    final page = File('${tmp.path}/p.jpg')..writeAsBytesSync([1]);
    await expectLater(
      HelperOutbox(HelperRepository(await _db())).send(
        link: link,
        receipt: _receipt(),
        summary: 'x',
        deleteAfter: [page],
      ),
      throwsA(isA<HelperSendException>()),
    );
    expect(page.existsSync(), isTrue);
  });

  test('Tarif: koppeln nur Pro', () {
    expect(Entitlement.pro.allows(Feature.helperDevices), isTrue);
    expect(Entitlement.basis.allows(Feature.helperDevices), isFalse);
  });

  testWidgets('Mithelfer-Start: Aufnahmeknopf mittig unten, ≥ 72 dp', (
    tester,
  ) async {
    const size = Size(360, 640);
    final db = await tester.runAsync(_db);
    final state = AppState(Repositories(db!));
    await tester.runAsync(
      () => state.setHelperLink(
        HelperLink(
          pairingId: HelperPackage.hex(List.filled(16, 1)),
          key: Uint8List(32),
          businessName: 'Tischlerei Muster',
          deviceName: 'Handy Anna',
          transport: HelperTransport.share,
        ),
      ),
    );
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: HelperHomeScreen()),
      ),
    );
    await settle(tester);
    final r = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('helper-camera')),
        matching: find.byType(FloatingActionButton),
      ),
    );
    expect(r.width, greaterThanOrEqualTo(72));
    expect((r.center.dx - size.width / 2).abs(), lessThan(2));
    expect(r.center.dy, greaterThan(size.height * 2 / 3));
    for (final key in ['helper-gallery', 'helper-file']) {
      expect(
        tester.getSize(find.byKey(Key(key))).height,
        greaterThanOrEqualTo(48),
      );
    }
    // Keine Buchhaltung auf dem Mithelfer-Gerät.
    expect(find.text('Rechnungen'), findsNothing);
    expect(find.text('Belege für Tischlerei Muster'), findsOne);
  });
}
