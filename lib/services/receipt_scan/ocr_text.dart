/// Erkannter Text eines Belegfotos, unabhängig von der Erkennungs-Engine.
///
/// Die Engine (Android ML Kit, iOS Apple Vision, später ggf. Tesseract) liefert
/// Zeilen mit Lage im Bild. Der Parser arbeitet nur mit diesen Typen, damit ein
/// Austausch der Engine nur den Plattformteil betrifft.
library;

/// Eine erkannte Textzeile. Koordinaten in Bildpunkten, Ursprung oben links.
class OcrLine {
  const OcrLine(
    this.text, {
    this.page = 1,
    this.left = 0,
    this.top = 0,
    this.height = 0,
  });

  final String text;

  /// Belegseite ab 1.
  final int page;
  final int left;
  final int top;
  final int height;
}

/// Ergebnis der Texterkennung über alle Seiten eines Belegs.
class OcrDocument {
  const OcrDocument({
    required this.lines,
    this.engine = 'unbekannt',
    this.engineVersion = '',
    this.codes = const [],
  });

  /// Erzeugt ein Dokument aus Klartext, eine Zeile je Zeilenumbruch (Tests).
  factory OcrDocument.fromText(String text) => OcrDocument(
    lines: [for (final line in text.split('\n')) OcrLine(line)],
    engine: 'text',
  );

  final List<OcrLine> lines;

  /// Rohinhalte der QR- und Barcodes auf denselben Fotos (L-27.1), in der
  /// Reihenfolge der Seiten. Zerlegt in `receipt_codes.dart`.
  final List<String> codes;

  /// Name und Version der Engine, für das Änderungsprotokoll.
  final String engine;
  final String engineVersion;

  /// Fasst Zeilen zu Bildzeilen zusammen. Engines liefern Bezeichnung und
  /// Betrag einer Bonzeile („Summe … 12,34“) oft als getrennte Blöcke; über
  /// die senkrechte Lage werden sie wieder zu einer Zeile verbunden.
  /// Ohne Lageangaben (alle Höhen 0) bleibt die Reihenfolge unverändert.
  List<String> get rows {
    if (lines.every((l) => l.height == 0)) {
      return [
        for (final l in lines)
          if (l.text.trim().isNotEmpty) l.text.trim(),
      ];
    }
    final result = <String>[];
    final pages = lines.map((l) => l.page).toSet().toList()..sort();
    for (final page in pages) {
      final onPage = lines.where((l) => l.page == page).toList()
        ..sort((a, b) => a.top.compareTo(b.top));
      final groups = <List<OcrLine>>[];
      for (final line in onPage) {
        final center = line.top + line.height ~/ 2;
        // Gegen die letzten Gruppen prüfen, nicht nur die letzte: bei schräg
        // gehaltenem Beleg liegt der Betrag rechts etwas höher oder tiefer
        // als die Bezeichnung links (Gerätetest Pixel 10, Mautbeleg).
        List<OcrLine>? target;
        for (var g = groups.length - 1; g >= 0 && g >= groups.length - 3; g--) {
          final group = groups[g];
          final ref = group.first;
          final refCenter = ref.top + ref.height ~/ 2;
          final maxHeight = ref.height > line.height ? ref.height : line.height;
          // Untereinander stehende Zeilen gleicher Einrückung sind keine
          // gemeinsame Bildzeile, auch wenn ihre Kästen sich überlappen.
          final stacked = group.any(
            (m) => (m.left - line.left).abs() < maxHeight,
          );
          if (!stacked && (center - refCenter).abs() <= maxHeight * 3 ~/ 4) {
            target = group;
            break;
          }
        }
        if (target != null) {
          target.add(line);
          continue;
        }
        groups.add([line]);
      }
      for (final group in groups) {
        group.sort((a, b) => a.left.compareTo(b.left));
        final text = group.map((l) => l.text.trim()).join('  ').trim();
        if (text.isNotEmpty) result.add(text);
      }
    }
    return result;
  }
}

/// Schmale Schnittstelle zur Erkennungs-Engine. Die Plattformumsetzung liegt
/// in `platform_text_recognizer.dart`.
abstract interface class ReceiptTextRecognizer {
  /// Erkennt den Text der Bilder in der gegebenen Reihenfolge (Seite 1, 2, …).
  /// Die Bilder werden nur gelesen, nie verändert; nichts verlässt das Gerät.
  Future<OcrDocument> recognize(List<String> absoluteImagePaths);

  Future<bool> isAvailable();
}
