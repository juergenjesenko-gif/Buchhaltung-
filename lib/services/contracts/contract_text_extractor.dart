/// Kurzübersicht aus dem lokal erkannten Vertragstext (Spezifikation
/// FA-16.3, Lastenheft L-23.6): **nur Auszug** mit Fundstelle (Seite und
/// Zeile), keine rechtliche Bewertung, keine Empfehlung. Reine Heuristik auf
/// dem Gerät, keine KI.
library;

import '../../domain/money.dart';
import '../receipt_scan/ocr_text.dart';

enum ContractField {
  startDate,
  endDate,
  duration,
  notice,
  rate,
  indexation,
  date,
}

/// Ein gefundener Wert mit Fundstelle.
class ContractHint {
  const ContractHint({
    required this.field,
    required this.value,
    required this.page,
    required this.line,
    required this.excerpt,
    this.date,
    this.amount,
    this.number,
    this.unit,
  });

  final ContractField field;

  /// Anzeigewert, z. B. „3 Monate“.
  final String value;
  final int page;

  /// Zeile auf der Seite, ab 1.
  final int line;

  /// Originalzeile (gekürzt).
  final String excerpt;
  final DateTime? date;
  final Money? amount;
  final int? number;

  /// `days`, `weeks`, `months`, `years`.
  final String? unit;

  String get source => 'S. $page, Z. $line';
}

class ContractTextExtractor {
  ContractTextExtractor._();

  /// Speicherformat des erkannten Texts: eine Zeile je OCR-Zeile mit
  /// Seitenmarker `[S.n] `.
  static String serialize(OcrDocument doc) =>
      [for (final l in doc.lines) '[S.${l.page}] ${l.text}'].join('\n');

  static final _marker = RegExp(r'^\[S\.(\d+)\] ?(.*)$');
  static final _date = RegExp(r'\b(\d{1,2})\.\s?(\d{1,2})\.\s?(\d{4})\b');
  static final _amount = RegExp(
    r'(?:€|EUR)\s?(\d{1,3}(?:[.\s]\d{3})*(?:,\d{2})?)|(\d{1,3}(?:[.\s]\d{3})*,\d{2})\s?(?:€|EUR|Euro)',
    caseSensitive: false,
  );
  static final _period = RegExp(
    r'(\d{1,3})\s*(Tag|Tage|Tagen|Woche|Wochen|Monat|Monate|Monaten|Jahr|Jahre|Jahren)\b',
    caseSensitive: false,
  );

  static List<ContractHint> extract(String ocrText) {
    final out = <ContractHint>[];
    final lineNo = <int, int>{};
    for (final raw in ocrText.split('\n')) {
      final m = _marker.firstMatch(raw);
      final page = m == null ? 1 : int.parse(m.group(1)!);
      final text = (m == null ? raw : m.group(2)!).trim();
      final line = (lineNo[page] ?? 0) + 1;
      lineNo[page] = line;
      if (text.isEmpty) continue;
      final lower = text.toLowerCase();
      final excerpt = text.length > 120 ? '${text.substring(0, 117)}…' : text;

      ContractHint hint(
        ContractField f,
        String value, {
        DateTime? date,
        Money? amount,
        int? number,
        String? unit,
      }) => ContractHint(
        field: f,
        value: value,
        page: page,
        line: line,
        excerpt: excerpt,
        date: date,
        amount: amount,
        number: number,
        unit: unit,
      );

      for (final d in _date.allMatches(text)) {
        final day = int.parse(d.group(1)!);
        final month = int.parse(d.group(2)!);
        final year = int.parse(d.group(3)!);
        if (month < 1 || month > 12 || day < 1 || day > 31) continue;
        final date = DateTime(year, month, day);
        final field =
            lower.contains('beginn') ||
                lower.contains('ab dem') ||
                lower.contains('wirksam ab') ||
                lower.contains('mietbeginn')
            ? ContractField.startDate
            : lower.contains('endet') ||
                  lower.contains('bis zum') ||
                  lower.contains('ablauf') ||
                  lower.contains('vertragsende')
            ? ContractField.endDate
            : ContractField.date;
        out.add(hint(field, d.group(0)!, date: date));
      }

      final period = _period.firstMatch(text);
      if (period != null) {
        final n = int.parse(period.group(1)!);
        final word = period.group(2)!.toLowerCase();
        final unit = word.startsWith('tag')
            ? 'days'
            : word.startsWith('woche')
            ? 'weeks'
            : word.startsWith('monat')
            ? 'months'
            : 'years';
        if (lower.contains('kündigung')) {
          out.add(
            hint(ContractField.notice, period.group(0)!, number: n, unit: unit),
          );
        } else if (lower.contains('laufzeit') ||
            lower.contains('dauer') ||
            lower.contains('abgeschlossen für')) {
          out.add(
            hint(
              ContractField.duration,
              period.group(0)!,
              number: n,
              unit: unit,
            ),
          );
        }
      }

      if (lower.contains('miete') ||
          lower.contains('rate') ||
          lower.contains('prämie') ||
          lower.contains('entgelt') ||
          lower.contains('pacht') ||
          lower.contains('zins') ||
          lower.contains('monatlich') ||
          lower.contains('betrag')) {
        final a = _amount.firstMatch(text);
        if (a != null) {
          final money = Money.tryParse(a.group(1) ?? a.group(2)!);
          if (money != null && money.cents > 0) {
            out.add(
              hint(ContractField.rate, a.group(0)!.trim(), amount: money),
            );
          }
        }
      }

      if (lower.contains('wertsicher') ||
          lower.contains('verbraucherpreisindex') ||
          lower.contains('vpi') ||
          lower.contains('indexanpassung') ||
          lower.contains('indexiert')) {
        out.add(hint(ContractField.indexation, excerpt));
      }
    }
    return out;
  }
}
