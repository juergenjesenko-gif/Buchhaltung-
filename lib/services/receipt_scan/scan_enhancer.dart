import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Nachbearbeitung gescannter Seiten (FA-2.51, Gerätetest 0.21.0): der
/// System-Scanner entzerrt nur, ML Kit überlässt den Filter der Nutzerin
/// (Vorgabe „keiner“). Damit der Beleg wie ein Scan aussieht und die
/// Texterkennung sicherer liest:
///
/// 1. lange Kante auf höchstens [maxEdge] Pixel,
/// 2. Tonwertkorrektur über die Helligkeit (je [clipPercent] % dunkelste und
///    hellste Pixel abgeschnitten, Farbton bleibt erhalten),
/// 3. leichte Gammakorrektur, damit das Papier weiß wird,
/// 4. leichtes Nachschärfen (Unscharf maskieren, 3×3),
/// 5. fast farblose Belege (Thermopapier) werden grau – besser lesbar, kleiner,
/// 6. JPEG mit Qualität [jpegQuality].
///
/// Gespeichert wird nur das Ergebnis (Entscheidung Auftraggeberin
/// 2026-10-16, P-S63). Läuft in einem eigenen Isolate.
class ScanEnhancer {
  const ScanEnhancer._();

  static const maxEdge = 2400;
  static const jpegQuality = 85;
  static const clipPercent = 1;

  /// Mittlere Farbsättigung (max − min je Pixel, 0–255), unter der eine
  /// Seite als farblos gilt und grau gespeichert wird.
  static const grayscaleChromaBelow = 18;

  /// Gamma < 1 hellt die Mitteltöne auf (Papier wird weißer).
  static const gamma = 0.85;

  /// Stärke des Nachschärfens in Prozent.
  static const sharpenPercent = 60;

  /// Verbessert die JPEG-/PNG-Bytes im Hintergrund. `null`, wenn das Bild
  /// nicht dekodierbar ist – dann speichert der Aufrufer das Original.
  static Future<Uint8List?> enhanceInBackground(Uint8List bytes) =>
      Isolate.run(() => enhance(bytes));

  /// Synchrone Variante (Tests, Isolate).
  static Uint8List? enhance(Uint8List bytes) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      // Unbekanntes oder kaputtes Format: Original behalten.
      return null;
    }
    if (decoded == null) return null;
    var image = img.bakeOrientation(decoded);
    final long = image.width > image.height ? image.width : image.height;
    if (long > maxEdge) {
      image = image.width >= image.height
          ? img.copyResize(
              image,
              width: maxEdge,
              interpolation: img.Interpolation.average,
            )
          : img.copyResize(
              image,
              height: maxEdge,
              interpolation: img.Interpolation.average,
            );
    }
    final w = image.width;
    final h = image.height;
    final rgb = Uint8List.fromList(image.getBytes(order: img.ChannelOrder.rgb));
    final result = enhanceRgb(rgb, w, h);
    final out = img.Image.fromBytes(
      width: w,
      height: h,
      bytes: result.buffer,
      numChannels: 3,
      order: img.ChannelOrder.rgb,
    );
    return img.encodeJpg(out, quality: jpegQuality);
  }

  /// Kern auf rohen RGB-Bytes (je Pixel 3 Bytes). Liefert neue Bytes.
  static Uint8List enhanceRgb(Uint8List rgb, int w, int h) {
    final n = w * h;
    // Helligkeit (BT.601, ganzzahlig) und Farbsättigung.
    final luma = Uint8List(n);
    final histogram = List<int>.filled(256, 0);
    var chromaSum = 0;
    for (var i = 0, j = 0; i < n; i++, j += 3) {
      final r = rgb[j], g = rgb[j + 1], b = rgb[j + 2];
      final y = (299 * r + 587 * g + 114 * b) ~/ 1000;
      luma[i] = y;
      histogram[y]++;
      final mx = r > g ? (r > b ? r : b) : (g > b ? g : b);
      final mn = r < g ? (r < b ? r : b) : (g < b ? g : b);
      chromaSum += mx - mn;
    }
    final gray = n > 0 && chromaSum ~/ n < grayscaleChromaBelow;

    // Grenzen mit Abschneiden der Ränder.
    final clip = n * clipPercent ~/ 100;
    var lo = 0, acc = 0;
    while (lo < 255 && acc + histogram[lo] <= clip) {
      acc += histogram[lo++];
    }
    var hi = 255;
    acc = 0;
    while (hi > 0 && acc + histogram[hi] <= clip) {
      acc += histogram[hi--];
    }
    if (hi - lo < 16) {
      // Fast einfarbig: nicht spreizen, sonst wird Rauschen verstärkt.
      lo = 0;
      hi = 255;
    }

    // Tonwertkurve: spreizen, dann Gamma.
    final curve = Uint8List(256);
    for (var v = 0; v < 256; v++) {
      final stretched = ((v - lo) * 255 / (hi - lo)).clamp(0, 255) / 255;
      curve[v] = (255 * _pow(stretched, gamma)).round().clamp(0, 255);
    }

    final out = Uint8List(n * 3);
    for (var i = 0, j = 0; i < n; i++, j += 3) {
      if (gray) {
        final v = curve[luma[i]];
        out[j] = v;
        out[j + 1] = v;
        out[j + 2] = v;
      } else {
        out[j] = curve[rgb[j]];
        out[j + 1] = curve[rgb[j + 1]];
        out[j + 2] = curve[rgb[j + 2]];
      }
    }
    return _sharpen(out, w, h);
  }

  /// Unscharf maskieren mit 3×3-Mittelwert: v + k·(v − Mittel).
  static Uint8List _sharpen(Uint8List src, int w, int h) {
    if (w < 3 || h < 3) return src;
    final dst = Uint8List.fromList(src);
    final stride = w * 3;
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final base = y * stride + x * 3;
        for (var c = 0; c < 3; c++) {
          final p = base + c;
          final sum =
              src[p - stride - 3] +
              src[p - stride] +
              src[p - stride + 3] +
              src[p - 3] +
              src[p] +
              src[p + 3] +
              src[p + stride - 3] +
              src[p + stride] +
              src[p + stride + 3];
          final v = src[p];
          final mean = sum ~/ 9;
          final sharpened = v + (v - mean) * sharpenPercent ~/ 100;
          dst[p] = sharpened < 0 ? 0 : (sharpened > 255 ? 255 : sharpened);
        }
      }
    }
    return dst;
  }

  static double _pow(double x, double e) =>
      x <= 0 ? 0 : (x >= 1 ? 1 : math.pow(x, e).toDouble());
}
