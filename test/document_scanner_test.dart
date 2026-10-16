import 'package:buchhaltung/services/receipt_scan/document_scanner.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dokumentenscanner (FA-2.51): Rückfall auf die Kamera ohne Rückfrage.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('buchhaltung/document_scanner');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('ohne Plattform-Channel: null → Kamera', () async {
    expect(await const DocumentScanner().scan(), isNull);
  });

  test('Scanner nicht verfügbar: null → Kamera', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'unavailable');
    });
    expect(await const DocumentScanner().scan(), isNull);
  });

  test('abgebrochen: leere Liste, keine Kamera', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => <String>[]);
    expect(await const DocumentScanner().scan(), isEmpty);
  });

  test('Seiten in Reihenfolge, Seitenlimit übergeben', () async {
    Object? args;
    messenger.setMockMethodCallHandler(channel, (call) async {
      args = call.arguments;
      return ['/tmp/a.jpg', '/tmp/b.jpg'];
    });
    final files = await const DocumentScanner().scan();
    expect(files!.map((f) => f.path), ['/tmp/a.jpg', '/tmp/b.jpg']);
    expect(args, {'pageLimit': DocumentScanner.pageLimit});
  });

  // Gerätetest 0.21.0: nach dem ersten Scan blieb der Scanner gesperrt und
  // das Formular leer. Fake-Scanner über den Channel.
  group('ScanIntake', () {
    Future<File> keep(File f) async => f;

    test('zweimal hintereinander scannen funktioniert', () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls++;
        return ['/tmp/scan_$calls.jpg'];
      });
      final pages = <String>[];
      var prefills = 0;
      for (var i = 0; i < 2; i++) {
        final outcome = await ScanIntake.run(
          store: (f) async => f.path,
          onPage: (r) {
            pages.add(r);
            return true;
          },
          afterPages: () async => prefills++,
          enhance: keep,
        );
        expect(outcome, ScanIntakeOutcome.added);
      }
      expect(calls, 2);
      expect(pages, ['/tmp/scan_1.jpg', '/tmp/scan_2.jpg']);
      expect(prefills, 2);
      expect(DocumentScanner.isRunning, isFalse);
    });

    test('Abbruch setzt zurück, nächster Scan geht', () async {
      var cancel = true;
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => cancel ? <String>[] : ['/tmp/a.jpg'],
      );
      var prefills = 0;
      Future<ScanIntakeOutcome> once() => ScanIntake.run(
        store: (f) async => f.path,
        onPage: (_) => true,
        afterPages: () async => prefills++,
        enhance: keep,
      );
      expect(await once(), ScanIntakeOutcome.cancelled);
      expect(prefills, 0);
      expect(DocumentScanner.isRunning, isFalse);
      cancel = false;
      expect(await once(), ScanIntakeOutcome.added);
      expect(prefills, 1);
    });

    test('Fehler setzt zurück, nächster Scan geht', () async {
      var fail = true;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (fail) throw PlatformException(code: 'io');
        return ['/tmp/a.jpg'];
      });
      expect(await const DocumentScanner().scan(), isNull);
      expect(DocumentScanner.isRunning, isFalse);
      fail = false;
      expect(await const DocumentScanner().scan(), hasLength(1));
    });

    test('Doppeltipp: zweiter Aufruf endet sofort, keine Sperre', () async {
      final gate = Completer<List<String>>();
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls++;
        return gate.future;
      });
      final first = const DocumentScanner().scan();
      expect(await const DocumentScanner().scan(), isEmpty);
      gate.complete(['/tmp/a.jpg']);
      expect(await first, hasLength(1));
      expect(calls, 1);
      expect(DocumentScanner.isRunning, isFalse);
    });

    test('Vorbelegung läuft nach dem Scan über alle Seiten', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => ['/tmp/a.jpg', '/tmp/b.jpg'],
      );
      final events = <String>[];
      final outcome = await ScanIntake.run(
        store: (f) async => 'belege/${f.uri.pathSegments.last}',
        onPage: (r) {
          events.add('Seite $r');
          return true;
        },
        afterPages: () async => events.add('Vorbelegung'),
        enhance: (f) async {
          events.add('verbessert ${f.uri.pathSegments.last}');
          return f;
        },
      );
      expect(outcome, ScanIntakeOutcome.added);
      expect(events, [
        'verbessert a.jpg',
        'Seite belege/a.jpg',
        'verbessert b.jpg',
        'Seite belege/b.jpg',
        'Vorbelegung',
      ]);
    });

    test('kein Scanner: Kamera, keine Vorbelegung', () async {
      var prefills = 0;
      final outcome = await ScanIntake.run(
        store: (f) async => f.path,
        onPage: (_) => true,
        afterPages: () async => prefills++,
        enhance: keep,
      );
      expect(outcome, ScanIntakeOutcome.unavailable);
      expect(prefills, 0);
    });
  });
}
