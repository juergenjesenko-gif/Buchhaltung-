import 'dart:io';
import 'dart:typed_data';

import 'package:buchhaltung/services/helper/helper_package.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';

/// Belegpaket plattformunabhängig (FA-17.4, P-D42): Hauptgerät Android mit
/// Mithelfer-iPhone und umgekehrt. Das Format darf von keiner
/// Plattform-Implementierung abhängen; ein festes Prüfmuster in
/// `test/fixtures/belegpaket/` hält es über Versionen stabil.
void main() {
  // Festes Prüfmuster: Schlüssel 0x00..0x1f, Kopplung 0xa0..0xaf,
  // Nonce 0x10..0x1b. Nur für Tests.
  final key = List<int>.generate(32, (i) => i);
  final pairingId = HelperPackage.hex(List<int>.generate(16, (i) => 0xa0 + i));
  final nonce = List<int>.generate(12, (i) => 0x10 + i);
  const goldenPath = 'test/fixtures/belegpaket/pruefmuster_v1.jenibeleg';

  // Kleinstes gültiges PNG-Signaturstück und JPEG-Kopf als „Seiten“.
  final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 1, 2]);
  final jpg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10, 3, 4]);

  final receipt = HelperReceipt(
    uuid: '6f1c2a3b-4d5e-4f60-8a71-9b8c7d6e5f40',
    deviceName: 'iPhone von Nina',
    createdAt: DateTime.utc(2026, 10, 17, 9, 30),
    date: DateTime(2026, 10, 16),
    grossCents: 12999,
    counterparty: 'BAUHAUS Depot GmbH',
    categoryName: 'Material und Werkzeug',
    description: 'Lasurpinsel u. a. – Öl, „Größe“ ß',
    comment: 'für Baustelle Müller 🙂',
    pages: [jpg, png],
  );

  void expectSame(HelperReceipt r) {
    expect(r.uuid, receipt.uuid);
    expect(r.deviceName, receipt.deviceName);
    expect(r.createdAt, receipt.createdAt);
    expect(r.date, receipt.date);
    expect(r.grossCents, 12999);
    expect(r.counterparty, receipt.counterparty);
    expect(r.categoryName, receipt.categoryName);
    expect(r.description, receipt.description);
    expect(r.comment, receipt.comment);
    expect(r.pages, [jpg, png]);
  }

  // „Android“ und „iOS“: die Vorgabe-Implementierung von `cryptography`
  // bzw. die reine Dart-Implementierung. Beide müssen dasselbe Format
  // erzeugen und lesen.
  final paths = <String, Cipher>{
    'Vorgabe': AesGcm.with256bits(),
    'reines Dart': DartAesGcm.with256bits(),
  };

  for (final from in paths.entries) {
    for (final to in paths.entries) {
      test('verpackt mit ${from.key}, geöffnet mit ${to.key}', () async {
        final data = await HelperPackage.seal(
          receipt,
          pairingId: pairingId,
          key: key,
          cipher: from.value,
        );
        expect(HelperPackage.pairingIdOf(data), pairingId);
        expectSame(await HelperPackage.open(data, key, cipher: to.value));
      });
    }
  }

  test('festes Prüfmuster: Bytes sind stabil', () async {
    final data = await HelperPackage.seal(
      receipt,
      pairingId: pairingId,
      key: key,
      nonce: nonce,
      cipher: DartAesGcm.with256bits(),
    );
    final golden = File(goldenPath);
    if (Platform.environment['UPDATE_GOLDEN'] == '1') {
      await golden.writeAsBytes(data, flush: true);
    }
    expect(data, await golden.readAsBytes());
  });

  test('festes Prüfmuster lässt sich auf jedem Weg öffnen', () async {
    final data = await File(goldenPath).readAsBytes();
    expect(String.fromCharCodes(data.sublist(0, 4)), 'JBHP');
    expect(data[4], HelperPackage.formatVersion);
    expect(HelperPackage.pairingIdOf(data), pairingId);
    for (final c in paths.values) {
      expectSame(await HelperPackage.open(data, key, cipher: c));
    }
  });

  test('Dateiname und Endung ohne Sonderzeichen', () {
    final name = HelperPackage.fileName(pairingId, receipt.uuid);
    expect(name, matches(RegExp(r'^[0-9a-f]{8}_[0-9a-f-]{36}\.jenibeleg$')));
    expect(helperPackageMimeType, 'application/x-jenibeleg');
  });

  test('Hinweis für gemischte Familien nennt die Wege', () {
    expect(helperFolderHint, contains('iCloud Drive'));
    expect(helperFolderHint, contains('Google Drive'));
    expect(helperFolderHint, contains('Messenger'));
  });

  test('iOS: Belegpaket als eigener Dateityp angemeldet', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('UTExportedTypeDeclarations'));
    expect(plist, contains('at.jenibarb.jenibucht.jenibeleg'));
    expect(plist, contains('UTImportedTypeDeclarations'));
    expect(plist, contains('at.jesenko.buchhaltung.jenibeleg'));
    expect(plist, contains('<string>jenibeleg</string>'));
  });

  test('Android: „Öffnen mit“ für Belegpakete', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains(helperPackageMimeType));
    expect(manifest, contains(r'.*\\.jenibeleg'));
  });
}
