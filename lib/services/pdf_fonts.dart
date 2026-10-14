import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Schrift aller PDFs (Rechnung, Mahnung): Work Sans, SIL Open Font
/// License 1.1, Lizenz in `assets/fonts/OFL.txt` (Prüfpunkt P-R18).
///
/// Die eingebauten PDF-Standardschriften (Helvetica) kennen nur
/// WinAnsi ohne Unicode-Abbildung im pdf-Paket; € und „–“ erschienen im
/// Gerätetest 0.6.0 als Kästchen. Eine eingebettete TrueType-Schrift trägt
/// €, –, „“, Umlaute und ß als echte Glyphen.
class PdfFonts {
  const PdfFonts._(this.base, this.bold);

  final pw.Font base;
  final pw.Font bold;

  static const regularAsset = 'assets/fonts/WorkSans-Regular.ttf';
  static const boldAsset = 'assets/fonts/WorkSans-Bold.ttf';

  static PdfFonts? _cached;

  static Future<PdfFonts> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    final regular = await rootBundle.load(regularAsset);
    final bold = await rootBundle.load(boldAsset);
    return _cached = PdfFonts._(pw.Font.ttf(regular), pw.Font.ttf(bold));
  }

  pw.ThemeData get theme => pw.ThemeData.withFont(base: base, bold: bold);
}
