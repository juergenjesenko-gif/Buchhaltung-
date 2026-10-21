/// Texterkennung über alle Seiten eines Vertrags (FA-16.3). Reines Dart, die
/// Engine und das Auflösen der Seitenpfade werden hereingereicht, damit die
/// Logik ohne Gerät testbar ist.
///
/// Gerätetest 2026-10-21 (englischer Lizenzvertrag, 5 Seiten): „Text erkennen“
/// zeigte nichts. Die Kurzübersicht kannte nur deutsche Schlüsselwörter, ein
/// englischer Text ergab null Fundstellen, und die Oberfläche blendete die
/// Karte dann ohne jede Meldung aus. Außerdem fielen nicht auflösbare Seiten
/// und Fehler einzelner Seiten still heraus. Jetzt wird jede Seite einzeln
/// erkannt, Fehler werden gezählt und das Ergebnis immer gemeldet.
library;

import 'dart:io';

import '../receipt_scan/ocr_text.dart';
import 'contract_text_extractor.dart';

/// Ergebnis eines Erkennungslaufs.
class ContractOcrOutcome {
  const ContractOcrOutcome({
    required this.text,
    required this.pages,
    required this.lines,
    required this.hints,
    this.missingPages = 0,
    this.failedPages = 0,
  });

  /// Gespeicherter Text mit Seitenmarkern (siehe [ContractTextExtractor]).
  final String text;

  /// Seiten insgesamt.
  final int pages;

  /// Nicht leere erkannte Zeilen.
  final int lines;

  /// Fundstellen der Kurzübersicht.
  final int hints;

  /// Seiten, deren Bilddatei nicht mehr gefunden wurde.
  final int missingPages;

  /// Seiten, bei denen die Erkennung einen Fehler meldete.
  final int failedPages;

  bool get hasText => lines > 0;

  /// Meldung für die Nutzerin, nie leer.
  String get message {
    final problems = [
      if (missingPages > 0) '$missingPages Seite(n) nicht gefunden',
      if (failedPages > 0) '$failedPages Seite(n) nicht lesbar',
    ];
    final suffix = problems.isEmpty ? '' : ' (${problems.join(', ')})';
    if (!hasText) {
      return 'Kein Text erkannt$suffix. Seiten gerade, hell und ohne '
          'Schatten fotografieren und erneut versuchen.';
    }
    final found = hints == 0
        ? 'keine Fristen oder Beträge gefunden – Text unter „Erkannter Text“'
        : '$hints Fundstelle(n) in der Kurzübersicht';
    return 'Text erkannt: $lines Zeilen auf $pages Seite(n), $found$suffix.';
  }
}

class ContractOcr {
  ContractOcr._();

  /// Erkennt jede Seite einzeln (Seitennummer = Position im Vertrag), damit
  /// eine unlesbare Seite den Rest nicht verhindert.
  static Future<ContractOcrOutcome> run({
    required List<String> pages,
    required Future<File?> Function(String relativePath) resolve,
    required ReceiptTextRecognizer recognizer,
  }) async {
    final lines = <OcrLine>[];
    var missing = 0;
    var failed = 0;
    for (var i = 0; i < pages.length; i++) {
      final file = await resolve(pages[i]);
      if (file == null) {
        missing++;
        continue;
      }
      try {
        final doc = await recognizer.recognize([file.path]);
        for (final l in doc.lines) {
          if (l.text.trim().isEmpty) continue;
          lines.add(
            OcrLine(
              l.text,
              page: i + 1,
              left: l.left,
              top: l.top,
              height: l.height,
            ),
          );
        }
      } on Exception {
        failed++;
      }
    }
    final text = ContractTextExtractor.serialize(OcrDocument(lines: lines));
    return ContractOcrOutcome(
      text: text,
      pages: pages.length,
      lines: lines.length,
      hints: ContractTextExtractor.extract(text).length,
      missingPages: missing,
      failedPages: failed,
    );
  }
}
