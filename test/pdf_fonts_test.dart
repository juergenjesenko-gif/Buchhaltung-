import 'dart:io';

import 'package:buchhaltung/services/pdf_fonts.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

/// Gerätetest 0.6.0: € und „–“ erschienen in allen PDFs als Kästchen
/// (Helvetica ohne Unicode). Die eingebettete Schrift muss sie als echte
/// Glyphen tragen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Schrift enthält €, Gedankenstrich, Anführungszeichen, Umlaute, ß',
    () async {
      for (final asset in [PdfFonts.regularAsset, PdfFonts.boldAsset]) {
        final parser = TtfParser(await rootBundle.load(asset));
        for (final char in '€–„“äöüÄÖÜß'.runes) {
          expect(
            parser.charToGlyphIndexMap[char] ?? 0,
            greaterThan(0),
            reason: '$asset: U+${char.toRadixString(16)} fehlt',
          );
        }
      }
    },
  );

  test('PDF-Schriften sind eingebettet, nicht Helvetica', () async {
    final fonts = await PdfFonts.load();
    expect(fonts.base.fontName, isNot(contains('Helvetica')));
    expect(fonts.bold.fontName, isNot(contains('Helvetica')));
  });

  test('Lizenzdatei wird mitgeliefert', () {
    expect(
      File('assets/fonts/OFL.txt').readAsStringSync(),
      contains('SIL Open Font License, Version 1.1'),
    );
  });
}
