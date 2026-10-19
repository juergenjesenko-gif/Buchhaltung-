import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Synthetische Belegbilder der Demo (FA-13.14): weißer Kassenzettel mit
/// erfundenem Händler, Positionen und Summe, im Code gezeichnet. Keine
/// echten Fotos, keine echten Marken oder Logos (P-R56). Nur ASCII, weil die
/// eingebaute Bitmap-Schrift keine Umlaute kennt.
class DemoReceiptImage {
  DemoReceiptImage._();

  static const width = 360;

  /// PNG eines Zettels mit [title] (Händler), [lines] (Text, Betrag) und
  /// [total]. Höhe wächst mit der Zahl der Zeilen.
  static Uint8List render({
    required String title,
    required List<(String, String)> lines,
    required String total,
    String footer = 'MUSTERBELEG - DEMO',
  }) {
    final height = 170 + lines.length * 22;
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(250, 250, 246));
    final ink = img.ColorRgb8(30, 30, 30);
    final muted = img.ColorRgb8(150, 40, 40);
    img.drawString(
      image,
      _ascii(title),
      font: img.arial24,
      x: 16,
      y: 14,
      color: ink,
    );
    img.drawLine(image, x1: 16, y1: 50, x2: width - 16, y2: 50, color: ink);
    var y = 62;
    for (final (text, amount) in lines) {
      img.drawString(
        image,
        _ascii(text),
        font: img.arial14,
        x: 16,
        y: y,
        color: ink,
      );
      img.drawString(
        image,
        _ascii(amount),
        font: img.arial14,
        x: width - 16 - amount.length * 8,
        y: y,
        color: ink,
      );
      y += 22;
    }
    img.drawLine(
      image,
      x1: 16,
      y1: y + 4,
      x2: width - 16,
      y2: y + 4,
      color: ink,
    );
    img.drawString(
      image,
      'SUMME EUR',
      font: img.arial24,
      x: 16,
      y: y + 12,
      color: ink,
    );
    img.drawString(
      image,
      _ascii(total),
      font: img.arial24,
      x: width - 16 - total.length * 13,
      y: y + 12,
      color: ink,
    );
    img.drawString(
      image,
      footer,
      font: img.arial14,
      x: 16,
      y: height - 30,
      color: muted,
    );
    return img.encodePng(image);
  }

  static String _ascii(String s) => s
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('Ä', 'Ae')
      .replaceAll('Ö', 'Oe')
      .replaceAll('Ü', 'Ue')
      .replaceAll('ß', 'ss')
      .replaceAll('é', 'e')
      .replaceAll('€', 'EUR')
      .replaceAll('–', '-')
      .replaceAll(RegExp(r'[^\x20-\x7E]'), '?');
}
