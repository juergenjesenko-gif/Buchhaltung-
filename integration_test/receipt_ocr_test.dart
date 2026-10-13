// Echte Belegerkennung auf einem Android-Emulator (CI-Job android-ocr-emulator).
//
// Erzeugt einen synthetischen Kassenbon als PNG (keine echten Belegdaten),
// schickt ihn über den Platform-Channel an ML Kit und prüft den erkannten Text.
// Läuft mit `flutter test integration_test --profile`; Profile ist wie Release
// mit R8 verkleinert (android/app/build.gradle.kts).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:buchhaltung/services/receipt_scan/platform_text_recognizer.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _bon = [
  'MUSTERLADEN',
  'Hauptstrasse 1',
  'Brot            4,00',
  'Milch           6,00',
  'Gesamt EUR     10,00',
];

Future<File> _kassenbon() async {
  const width = 900.0;
  const lineHeight = 90.0;
  final height = lineHeight * (_bon.length + 2);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width, height),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  for (var i = 0; i < _bon.length; i++) {
    final painter = TextPainter(
      text: TextSpan(
        text: _bon[i],
        style: const TextStyle(
          color: Color(0xFF000000),
          fontSize: 56,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(40, lineHeight * (i + 1)));
  }
  final image = await recorder.endRecording().toImage(
    width.toInt(),
    height.toInt(),
  );
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('${Directory.systemTemp.path}/kassenbon_test.png');
  await file.writeAsBytes(png!.buffer.asUint8List(), flush: true);
  return file;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ML Kit erkennt synthetischen Kassenbon', (tester) async {
    const recognizer = PlatformReceiptTextRecognizer();
    expect(await recognizer.isAvailable(), isTrue);
    final file = await _kassenbon();
    final doc = await tester.runAsync(() => recognizer.recognize([file.path]));
    final text = doc!.lines.map((l) => l.text).join('\n');
    // ignore: avoid_print
    print('Erkannt (${doc.engine} ${doc.engineVersion}):\n$text');
    expect(text, contains('Gesamt'));
    expect(text, contains('10,00'));
  });

  testWidgets('Fehlende Datei liefert Fehlercode mit Details', (tester) async {
    const recognizer = PlatformReceiptTextRecognizer();
    Object? error;
    await tester.runAsync(() async {
      try {
        await recognizer.recognize(['/data/local/tmp/gibt-es-nicht.png']);
      } catch (e) {
        error = e;
      }
    });
    expect(error.toString(), contains('unreadable'));
    expect(error.toString(), contains('FileNotFoundException'));
  });
}
