// Selbsttest der Belegerkennung im Release-Build (CI-Job android-ocr-emulator).
//
// Eigener Einstiegspunkt statt package:integration_test: integration_test läuft
// nur im Debug-/Profile-Modus, der Fehler vom Pixel 10 trat aber nur im
// Release-Build mit R8 auf. Darum baut die CI diese Datei mit
// `flutter build apk --release -t …`, startet sie im Emulator und liest das
// Ergebnis aus logcat (Zeilen mit OCR-SELBSTTEST).
//
// Der Kassenbon ist synthetisch gezeichnet, kein echtes Foto.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:buchhaltung/services/receipt_scan/platform_text_recognizer.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_codes.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

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
        style: const TextStyle(color: Color(0xFF000000), fontSize: 56),
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
  final file = File('${Directory.systemTemp.path}/kassenbon_selbsttest.png');
  await file.writeAsBytes(png!.buffer.asUint8List(), flush: true);
  return file;
}

void _log(String line) {
  // ignore: avoid_print
  print('OCR-SELBSTTEST $line');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SizedBox.shrink());
  const recognizer = PlatformReceiptTextRecognizer();
  var ok = true;
  try {
    final file = await _kassenbon();
    final doc = await recognizer.recognize([file.path]);
    final text = doc.lines.map((l) => l.text).join(' / ');
    _log('ENGINE ${doc.engine} ${doc.engineVersion}');
    _log('TEXT $text');
    if (!text.contains('Gesamt') || !text.contains('10,00')) {
      ok = false;
      _log('FEHLER Gesamt oder 10,00 nicht erkannt');
    }
  } on PlatformException catch (e) {
    ok = false;
    _log('FEHLER ${e.code}: ${e.message} [${e.details}]');
  } catch (e) {
    ok = false;
    _log('FEHLER $e');
  }
  // Fehlende Datei muss einen aussagekräftigen Fehlercode liefern.
  try {
    await recognizer.recognize(['/data/local/tmp/gibt-es-nicht.png']);
    ok = false;
    _log('FEHLER fehlende Datei ohne Fehler');
  } on PlatformException catch (e) {
    _log('FEHLENDE-DATEI ${e.code}: ${e.message}');
    if (e.code != 'unreadable' ||
        !(e.message ?? '').contains('FileNotFoundException')) {
      ok = false;
    }
  }
  // Kassen- und Zahlungs-QR (L-27.1): synthetische Codes aus
  // test/fixtures/codes/*.png müssen erkannt und zerlegt werden.
  try {
    if (!await _codes()) ok = false;
  } catch (e) {
    ok = false;
    _log('FEHLER QR $e');
  }
  try {
    await _korpus();
  } catch (e, st) {
    ok = false;
    _log('FEHLER KORPUS $e ${st.toString().split('\n').take(3).join(' < ')}');
  }
  _log(ok ? 'ERGEBNIS OK' : 'ERGEBNIS FEHLER');
}

Future<bool> _codes() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final assets = manifest
      .listAssets()
      .where((a) => a.startsWith('test/fixtures/codes/'))
      .where((a) => a.endsWith('.png'))
      .toList();
  if (assets.isEmpty) {
    _log('FEHLER QR keine Testbilder');
    return false;
  }
  const recognizer = PlatformReceiptTextRecognizer();
  var ok = true;
  for (final asset in assets) {
    final data = await rootBundle.load(asset);
    final file = File('${Directory.systemTemp.path}/${asset.split('/').last}');
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    final doc = await recognizer.recognize([file.path]);
    final parsed = [for (final c in doc.codes) ?ReceiptCode.parse(c)];
    final kind = parsed.isEmpty ? 'keiner' : parsed.first.runtimeType;
    _log('QR ${asset.split('/').last} ${doc.codes.length} Code(s), Art $kind');
    final want = asset.contains('rksv') ? RksvCode : EpcCode;
    if (parsed.isEmpty || parsed.first.runtimeType != want) {
      ok = false;
      _log('FEHLER QR $asset nicht als $want erkannt');
    }
  }
  return ok;
}

/// Die Fotos aus test/fixtures/belege/ bindet tool/ci/ocr_emulator_test.sh
/// nur für diesen CI-Build als Assets ein (pubspec.yaml wird dort temporär
/// ergänzt, nicht eingecheckt): adb darf nicht in den App-Speicher schreiben.
///
/// Rohes OCR-Ergebnis je Foto als gzip+Base64 in logcat, in Stücken zu 700
/// Zeichen (logcat kürzt lange Zeilen). Das Skript setzt sie wieder zusammen.
Future<void> _korpus() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final assets =
      manifest
          .listAssets()
          .where((a) => a.startsWith('test/fixtures/belege/'))
          .where((a) => a.toLowerCase().endsWith('.jpg'))
          .toList()
        ..sort();
  final files = <File>[];
  for (final asset in assets) {
    final data = await rootBundle.load(asset);
    final file = File('${Directory.systemTemp.path}/${asset.split('/').last}');
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    files.add(file);
  }
  const recognizer = PlatformReceiptTextRecognizer();
  _log('KORPUS ${files.length} Dateien');
  for (final file in files) {
    final name = file.uri.pathSegments.last;
    if (!name.toLowerCase().endsWith('.jpg')) continue;
    _log('KORPUS START $name');
    Map<String, Object?> json;
    try {
      final doc = await recognizer.recognize([file.path]);
      json = {
        'datei': name,
        'engine': doc.engine,
        'engineVersion': doc.engineVersion,
        'codes': doc.codes,
        'lines': [
          for (final l in doc.lines)
            {
              'text': l.text,
              'left': l.left,
              'top': l.top,
              'height': l.height,
              'page': l.page,
            },
        ],
      };
    } on PlatformException catch (e) {
      json = {'datei': name, 'fehler': '${e.code}: ${e.message}'};
    }
    final packed = base64.encode(
      gzip.encode(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(json)),
      ),
    );
    const size = 700;
    final n = (packed.length + size - 1) ~/ size;
    for (var i = 0; i < n; i++) {
      final end = (i + 1) * size < packed.length
          ? (i + 1) * size
          : packed.length;
      _log('JSON $name ${i + 1}/$n ${packed.substring(i * size, end)}');
      // logcat verwirft bei zu schnellen Zeilen („chatty“); kurz drosseln.
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    _log('KORPUS $name CODES ${(json['codes'] as List?)?.length ?? 0}');
    _log(
      'KORPUS $name ${json['lines'] is List ? (json['lines'] as List).length : 0} Zeilen',
    );
  }
}
