import 'dart:typed_data';

import 'package:buchhaltung/services/receipt_scan/scan_enhancer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Nachbearbeitung gescannter Seiten (FA-2.51): synthetische Belege.
void main() {
  /// Grauer, flauer Beleg: Papier 170, Schrift 110, leicht gelblich.
  Uint8List flatReceipt(int w, int h, {bool colored = false}) {
    final rgb = Uint8List(w * h * 3);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final ink = (y ~/ 4).isEven && x % 7 < 3;
        final v = ink ? 110 : 170;
        final j = (y * w + x) * 3;
        if (colored) {
          rgb[j] = ink ? 40 : 200;
          rgb[j + 1] = ink ? 60 : 120;
          rgb[j + 2] = ink ? 180 : 60;
        } else {
          rgb[j] = v + 4;
          rgb[j + 1] = v + 2;
          rgb[j + 2] = v - 4;
        }
      }
    }
    return rgb;
  }

  ({double paper, double ink}) levels(Uint8List rgb, int w, int h) {
    var paper = 0, ink = 0, np = 0, ni = 0;
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final j = (y * w + x) * 3;
        final l = (rgb[j] + rgb[j + 1] + rgb[j + 2]) ~/ 3;
        if ((y ~/ 4).isEven && x % 7 < 3) {
          ink += l;
          ni++;
        } else {
          paper += l;
          np++;
        }
      }
    }
    return (paper: paper / np, ink: ink / ni);
  }

  test('Kontrast steigt, Papier wird heller', () {
    const w = 70, h = 40;
    final before = flatReceipt(w, h);
    final after = ScanEnhancer.enhanceRgb(before, w, h);
    final a = levels(before, w, h);
    final b = levels(after, w, h);
    expect(b.paper, greaterThan(a.paper + 40));
    expect(b.paper, greaterThan(230));
    expect(b.paper - b.ink, greaterThan((a.paper - a.ink) * 2));
  });

  test('farbloser Beleg wird grau', () {
    const w = 70, h = 40;
    final after = ScanEnhancer.enhanceRgb(flatReceipt(w, h), w, h);
    for (var j = 0; j < after.length; j += 3) {
      expect(after[j], after[j + 1]);
      expect(after[j + 1], after[j + 2]);
    }
  });

  test('farbiger Beleg bleibt farbig', () {
    const w = 70, h = 40;
    final after = ScanEnhancer.enhanceRgb(
      flatReceipt(w, h, colored: true),
      w,
      h,
    );
    final j = (2 * w + 20) * 3; // Papierpixel
    expect(after[j], greaterThan(after[j + 2] + 50));
  });

  test('einfarbige Fläche wird nicht aufgerissen', () {
    const w = 20, h = 20;
    final rgb = Uint8List(w * h * 3)..fillRange(0, w * h * 3, 128);
    final after = ScanEnhancer.enhanceRgb(rgb, w, h);
    // Nur Gamma, keine Spreizung auf Schwarz/Weiß.
    expect(after.every((v) => v > 128 && v < 180), isTrue);
  });

  test('JPEG: lange Kante begrenzt, Ergebnis dekodierbar', () {
    final big = img.Image(width: 3000, height: 1200);
    img.fill(big, color: img.ColorRgb8(160, 160, 150));
    final out = ScanEnhancer.enhance(img.encodeJpg(big, quality: 90))!;
    final decoded = img.decodeJpg(out)!;
    expect(decoded.width, ScanEnhancer.maxEdge);
    expect(decoded.height, 960);
  });

  test('kein Bild: null, Aufrufer behält das Original', () {
    expect(ScanEnhancer.enhance(Uint8List.fromList([1, 2, 3])), isNull);
  });
}
