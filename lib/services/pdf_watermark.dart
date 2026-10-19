import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'demo/demo_mode.dart';

/// Seitenrahmen aller Geschäfts-PDFs (Rechnung, Angebot, Storno, Mahnung,
/// Saldenliste, Jahresabschluss). In der Demo trägt **jede Seite** schräg
/// über die ganze Fläche „MUSTER – DEMO“ (FA-13.14, P-R55): ein Muster-PDF
/// darf nie als echte Rechnung durchgehen (§ 11 UStG AT, § 14 UStG DE –
/// eine Rechnung braucht echte Angaben; Irreführung § 2 UWG AT, § 5 UWG DE).
class PdfWatermark {
  PdfWatermark._();

  /// Seitenvorlage mit Wasserzeichen im Vordergrund, wenn [demo] (Vorgabe:
  /// die laufende Demo). Außerhalb der Demo unverändert.
  static pw.PageTheme pageTheme({
    required PdfPageFormat pageFormat,
    required pw.EdgeInsets margin,
    required pw.ThemeData theme,
    pw.Font? font,
    bool? demo,
  }) => pw.PageTheme(
    pageFormat: pageFormat,
    margin: margin,
    theme: theme,
    buildForeground: (demo ?? DemoMode.active)
        ? (context) => foreground(font: font)
        : null,
  );

  /// Das Wasserzeichen selbst: groß, halbtransparent, um 45° gedreht.
  static pw.Widget foreground({pw.Font? font}) => pw.FullPage(
    ignoreMargins: true,
    child: pw.Center(
      child: pw.Transform.rotate(
        angle: math.pi / 4,
        child: pw.Opacity(
          opacity: 0.22,
          child: pw.Text(
            DemoMode.watermark,
            style: pw.TextStyle(
              font: font,
              fontSize: 72,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.red800,
            ),
          ),
        ),
      ),
    ),
  );

  /// Stichwort für die PDF-Metadaten (`keywords`), nur in der Demo.
  static String? keywords({bool? demo}) =>
      (demo ?? DemoMode.active) ? DemoMode.watermarkKeyword : null;

  /// Titel mit Vorsatz „MUSTER – DEMO“ in der Demo.
  static String title(String title, {bool? demo}) =>
      (demo ?? DemoMode.active) ? '${DemoMode.watermark}: $title' : title;
}
