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
    void fail(String message) => throw StateError('unerwartet: $message');

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
          onError: fail,
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
        onError: fail,
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
      var broken = true;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (broken) throw PlatformException(code: 'io', message: 'kaputt');
        return ['/tmp/a.jpg'];
      });
      // Kein Rückfall auf die Kamera, sondern eine sichtbare Meldung.
      await expectLater(
        const DocumentScanner().scan(),
        throwsA(isA<DocumentScanException>()),
      );
      expect(DocumentScanner.isRunning, isFalse);
      broken = false;
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
        onError: fail,
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

    test(
      'Codes werden auf jedem Original vor dem Verbessern gelesen',
      () async {
        messenger.setMockMethodCallHandler(
          channel,
          (call) async => ['/tmp/a.jpg', '/tmp/b.jpg'],
        );
        final events = <String>[];
        final outcome = await ScanIntake.run(
          store: (f) async => f.path,
          onPage: (_) => true,
          afterPages: () async {},
          onError: fail,
          beforeEnhance: (f) async {
            events.add('Codes ${f.uri.pathSegments.last}');
            if (f.path.endsWith('b.jpg')) throw Exception('kein Code');
          },
          enhance: (f) async {
            events.add('verbessert ${f.uri.pathSegments.last}');
            return f;
          },
        );
        expect(outcome, ScanIntakeOutcome.added);
        expect(events, [
          'Codes a.jpg',
          'verbessert a.jpg',
          'Codes b.jpg',
          'verbessert b.jpg',
        ]);
      },
    );

    test('kein Scanner: Kamera, keine Vorbelegung', () async {
      var prefills = 0;
      final outcome = await ScanIntake.run(
        store: (f) async => f.path,
        onPage: (_) => true,
        afterPages: () async => prefills++,
        onError: fail,
        enhance: keep,
      );
      expect(outcome, ScanIntakeOutcome.unavailable);
      expect(prefills, 0);
    });

    // Gerätetest 0.22.0: keine stillen Wege mehr.
    test('Ergebnis verloren: Meldung statt leerem Formular', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'lost', message: 'nicht angekommen');
      });
      final errors = <String>[];
      final outcome = await ScanIntake.run(
        store: (f) async => f.path,
        onPage: (_) => true,
        afterPages: () async {},
        onError: errors.add,
        enhance: keep,
      );
      expect(outcome, ScanIntakeOutcome.failed);
      expect(errors.single, contains('nicht angekommen'));
    });

    test(
      'Verbesserung scheitert (auch Error): Original wird abgelegt',
      () async {
        messenger.setMockMethodCallHandler(
          channel,
          (call) async => ['/tmp/a.jpg'],
        );
        final stored = <String>[];
        final outcome = await ScanIntake.run(
          store: (f) async {
            stored.add(f.path);
            return f.path;
          },
          onPage: (_) => true,
          afterPages: () async {},
          onError: fail,
          enhance: (f) async => throw StateError('Isolate'),
        );
        expect(outcome, ScanIntakeOutcome.added);
        expect(stored, ['/tmp/a.jpg']);
      },
    );

    test('Ablegen scheitert: Meldung, übrige Seiten bleiben', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => ['/tmp/a.jpg', '/tmp/b.jpg'],
      );
      final pages = <String>[];
      final errors = <String>[];
      final outcome = await ScanIntake.run(
        store: (f) async => f.path.endsWith('a.jpg')
            ? throw const FileSystemException('voll')
            : f.path,
        onPage: (r) {
          pages.add(r);
          return true;
        },
        afterPages: () async {},
        onError: errors.add,
        enhance: keep,
      );
      expect(outcome, ScanIntakeOutcome.added);
      expect(pages, ['/tmp/b.jpg']);
      expect(errors.single, contains('Seite 1'));
    });
  });

  // Ursache Gerätetest 0.22.0: Scanner und Sicherungsordner hatten denselben
  // Request-Code, das Scan-Ergebnis wurde vom Sicherungsordner verschluckt.
  test('Android: Request-Codes eindeutig, nur in RequestCodes.kt', () {
    final dir = Directory('android/app/src/main/kotlin/at/jesenko/buchhaltung');
    final codes = File('${dir.path}/RequestCodes.kt').readAsStringSync();
    final values = RegExp(
      r'const val \w+ = (\d+)',
    ).allMatches(codes).map((m) => m.group(1)).toList();
    expect(values, isNotEmpty);
    expect(values.toSet(), hasLength(values.length));
    for (final file in dir.listSync().whereType<File>()) {
      if (file.path.endsWith('RequestCodes.kt')) continue;
      expect(
        RegExp(r'REQUEST\w* = \d').hasMatch(file.readAsStringSync()),
        isFalse,
        reason: '${file.path}: Request-Code nur über RequestCodes',
      );
    }
  });
}
