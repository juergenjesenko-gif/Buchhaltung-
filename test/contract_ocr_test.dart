import 'dart:io';

import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/services/contracts/contract_ocr.dart';
import 'package:buchhaltung/services/contracts/contract_text_extractor.dart';
import 'package:buchhaltung/services/receipt_scan/ocr_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// Erkennung je Seite, liefert je Pfad vorgegebene Zeilen oder wirft.
class _FakeRecognizer implements ReceiptTextRecognizer {
  _FakeRecognizer(this.byPath);

  final Map<String, Object> byPath;
  final calls = <List<String>>[];

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<OcrDocument> recognize(List<String> paths) async {
    calls.add(paths);
    final v = byPath[paths.single];
    if (v is Exception) throw v;
    return OcrDocument(lines: [for (final t in v as List<String>) OcrLine(t)]);
  }
}

/// Gerätetest 2026-10-21: englischer Lizenzvertrag, 5 Seiten, kein Ergebnis.
void main() {
  Future<File?> resolve(String rel) async =>
      rel.startsWith('fehlt') ? null : File('/abs/$rel');

  test('jede Seite einzeln, Seitennummer bleibt, Meldung nie leer', () async {
    final rec = _FakeRecognizer({
      '/abs/s1.jpg': ['LICENSE AGREEMENT', ''],
      '/abs/s3.jpg': ['This Agreement is effective as of January 1, 2026.'],
      '/abs/s4.jpg': const FormatException('kaputt'),
    });
    final out = await ContractOcr.run(
      pages: ['s1.jpg', 'fehlt.jpg', 's3.jpg', 's4.jpg'],
      resolve: resolve,
      recognizer: rec,
    );
    expect(rec.calls, hasLength(3));
    expect(out.lines, 2);
    expect(out.missingPages, 1);
    expect(out.failedPages, 1);
    expect(out.text, contains('[S.3] This Agreement'));
    expect(out.hints, 1);
    expect(out.message, startsWith('Text erkannt: 2 Zeilen auf 4 Seite(n)'));
    expect(out.message, contains('1 Seite(n) nicht gefunden'));
  });

  test('kein Text: klare Meldung statt nichts', () async {
    final out = await ContractOcr.run(
      pages: ['a.jpg'],
      resolve: resolve,
      recognizer: _FakeRecognizer({
        '/abs/a.jpg': <String>[' '],
      }),
    );
    expect(out.hasText, isFalse);
    expect(out.message, startsWith('Kein Text erkannt'));
  });

  test('englischer Vertrag liefert Fundstellen', () {
    const text =
        '[S.1] This Agreement shall commence on 1 March 2026.\n'
        '[S.2] The license fee is EUR 1,250.00 per month.\n'
        '[S.3] Either party may terminate with three (3) months notice.\n'
        '[S.3] The initial term is 2 years.\n'
        '[S.4] This Agreement expires on 2028-02-29.';
    final hints = ContractTextExtractor.extract(text);
    ContractHint of(ContractField f) => hints.firstWhere((h) => h.field == f);
    expect(of(ContractField.startDate).date, DateTime(2026, 3, 1));
    expect(of(ContractField.rate).amount, const Money(125000));
    expect(of(ContractField.notice).number, 3);
    expect(of(ContractField.notice).unit, 'months');
    expect(of(ContractField.duration).unit, 'years');
    expect(of(ContractField.endDate).date, DateTime(2028, 2, 29));
  });
}
