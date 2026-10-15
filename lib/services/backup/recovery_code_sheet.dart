import 'dart:math';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/formatting.dart';
import '../pdf_fonts.dart';

/// Druckblatt mit dem Wiederherstellungscode (L-22.21): ein lokal erzeugtes
/// PDF mit Code und QR-Code. Es verlässt das Gerät nur über Teilen oder
/// Drucken, das die Nutzerin selbst auslöst; die App behält keine Kopie –
/// weder die Datei noch den Code im Klartext.
class RecoveryCodeSheet {
  const RecoveryCodeSheet._();

  static const fileName = 'JeNi-bucht-Wiederherstellungscode.pdf';

  static Future<Uint8List> build({
    required String code,
    required DateTime createdAt,
    String owner = '',
  }) async {
    final fonts = await PdfFonts.load();
    final doc = pw.Document(title: 'Wiederherstellungscode', author: owner);
    final blocks = code.split('-');
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        theme: pw.ThemeData.withFont(base: fonts.base, bold: fonts.bold),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'JeNi bucht – Wiederherstellungscode',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              [
                if (owner.isNotEmpty) owner,
                'erstellt am ${Fmt.date(createdAt)}',
              ].join(' · '),
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              'Mit diesem Code öffnest du deine automatische Sicherung auf '
              'einem neuen Gerät. Ohne ihn geht das nicht – auch wir können '
              'dir dann nicht helfen, weil wir keine Kopie haben.',
              style: const pw.TextStyle(fontSize: 11),
            ),
            pw.SizedBox(height: 20),
            pw.Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < blocks.length; i++)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey600),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'Block ${i + 1}',
                          style: const pw.TextStyle(fontSize: 7),
                        ),
                        pw.Text(
                          blocks[i],
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: code,
                  width: 140,
                  height: 140,
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  child: pw.Text(
                    'So bewahrst du ihn auf:\n'
                    '• Ausdrucken und zu deinen wichtigen Papieren legen, '
                    'oder in deinem Passwortmanager speichern.\n'
                    '• Nicht auf demselben Handy aufheben – geht das Handy '
                    'verloren, ist sonst auch der Code weg.\n'
                    '• Niemandem schicken. Wer den Code und deine '
                    'Sicherungsdatei hat, kann deine Buchhaltung lesen.\n\n'
                    'Beim Wiederherstellen: Code abtippen oder den QR-Code '
                    'mit der Kamera einlesen. Groß- und Kleinschreibung und '
                    'Bindestriche sind egal.',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }
}

/// Bestätigung beim Einrichten (L-22.22): zwei zufällige, verschiedene
/// Blöcke des Codes müssen vom Druckblatt abgetippt werden.
class RecoveryCodeChallenge {
  RecoveryCodeChallenge(this.code, {Random? random})
    : blocks = _pick(code.split('-').length, random ?? Random.secure());

  final String code;

  /// Zwei verschiedene Blocknummern ab 1, aufsteigend.
  final (int, int) blocks;

  static (int, int) _pick(int count, Random random) {
    final first = random.nextInt(count);
    var second = random.nextInt(count - 1);
    if (second >= first) second++;
    return first < second ? (first + 1, second + 1) : (second + 1, first + 1);
  }

  /// Eingabe eines Blocks prüfen; Leerzeichen, Kleinschreibung und die
  /// Verwechsler 0/1/8 sind egal (wie `RecoveryCode.tryDecode`).
  bool matches(int block, String input) {
    final expected = code.split('-')[block - 1];
    final clean = input
        .toUpperCase()
        .replaceAll(RegExp(r'[\s\-]'), '')
        .replaceAll('0', 'O')
        .replaceAll('1', 'I')
        .replaceAll('8', 'B');
    return clean == expected;
  }

  bool confirmed(String first, String second) =>
      matches(blocks.$1, first) && matches(blocks.$2, second);
}
