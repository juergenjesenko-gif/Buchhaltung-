import 'package:buchhaltung/services/receipt_scan/document_scanner.dart';
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
}
