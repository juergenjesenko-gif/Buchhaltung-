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
    r'\(?(\d{1,3})\)?\s*(?:\(\w+\)\s*)?(Tag|Tage|Tagen|Woche|Wochen|Monat|Monate|Monaten|Jahr|Jahre|Jahren|days?|weeks?|months?|years?)\b',
    caseSensitive: false,
  );

  // Englische Verträge (Gerätetest 2026-10-21, Lizenzvertrag): ISO-Datum,
  // „1 January 2026“, „January 1, 2026“ und Beträge „EUR 1,000.00“.
  static final _isoDate = RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b');
  static const _months = [
    'january',
    'february',
    'march',
    'april',
    'may',
    'june',
    'july',
    'august',
    'september',
    'october',
    'november',
    'december',
  ];
  static final _dayMonth = RegExp(
    r'\b(\d{1,2})(?:st|nd|rd|th)?\s+(?:of\s+)?([A-Za-z]{3,9})\.?,?\s+(\d{4})\b',
  );
  static final _monthDay = RegExp(
    r'\b([A-Za-z]{3,9})\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})\b',
  );
  static final _amountEn = RegExp(
    r'(?:€|EUR)\s?(\d{1,3}(?:,\d{3})*\.\d{2})\b',
    caseSensitive: false,
  );

  static int? _month(String word) {
    final w = word.toLowerCase();
    if (w.length < 3) return null;
    for (var i = 0; i < _months.length; i++) {
      if (_months[i].startsWith(w) || w == _months[i]) return i + 1;
    }
    return null;
  }

  static bool _any(String text, List<String> words) => words.any(text.contains);

  /// Alle Datumsangaben einer Zeile mit Originaltext.
  static List<(DateTime, String)> _dates(String text) {
    final out = <(DateTime, String)>[];
    void add(int y, int m, int d, String raw) {
      if (m < 1 || m > 12 || d < 1 || d > 31) return;
      out.add((DateTime(y, m, d), raw));
    }

    for (final d in _date.allMatches(text)) {
      add(
        int.parse(d.group(3)!),
        int.parse(d.group(2)!),
        int.parse(d.group(1)!),
        d.group(0)!,
      );
    }
    for (final d in _isoDate.allMatches(text)) {
      add(
        int.parse(d.group(1)!),
        int.parse(d.group(2)!),
        int.parse(d.group(3)!),
        d.group(0)!,
      );
    }
    for (final d in _dayMonth.allMatches(text)) {
      final m = _month(d.group(2)!);
      if (m != null) {
        add(int.parse(d.group(3)!), m, int.parse(d.group(1)!), d.group(0)!);
      }
    }
    for (final d in _monthDay.allMatches(text)) {
      final m = _month(d.group(1)!);
      if (m != null) {
        add(int.parse(d.group(3)!), m, int.parse(d.group(2)!), d.group(0)!);
      }
    }
    return out;
  }

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

      for (final (date, raw) in _dates(text)) {
        final field =
            _any(lower, [
              'beginn',
              'ab dem',
              'wirksam ab',
              'mietbeginn',
              'effective',
              'commence',
              'start date',
            ])
            ? ContractField.startDate
            : _any(lower, [
                'endet',
                'bis zum',
                'ablauf',
                'vertragsende',
                'expire',
                'expiry',
                'expiration',
                'end date',
              ])
            ? ContractField.endDate
            : ContractField.date;
        out.add(hint(field, raw, date: date));
      }

      final period = _period.firstMatch(text);
      if (period != null) {
        final n = int.parse(period.group(1)!);
        final word = period.group(2)!.toLowerCase();
        final unit = word.startsWith('tag') || word.startsWith('day')
            ? 'days'
            : word.startsWith('woche') || word.startsWith('week')
            ? 'weeks'
            : word.startsWith('monat') || word.startsWith('month')
            ? 'months'
            : 'years';
        if (_any(lower, ['kündigung', 'notice', 'terminat'])) {
          out.add(
            hint(ContractField.notice, period.group(0)!, number: n, unit: unit),
          );
        } else if (_any(lower, [
          'laufzeit',
          'dauer',
          'abgeschlossen für',
          'term',
          'duration',
          'period of',
        ])) {
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

      if (_any(lower, [
        'miete',
        'rate',
        'prämie',
        'entgelt',
        'pacht',
        'zins',
        'monatlich',
        'betrag',
        'fee',
        'royalt',
        'rent',
        'payment',
        'price',
        'amount',
        'monthly',
        'annual',
      ])) {
        final en = _amountEn.firstMatch(text);
        final a = en == null ? _amount.firstMatch(text) : null;
        // Englisch „1,000.00“ → „1000,00“ für Money.tryParse.
        final digits = en != null
            ? en.group(1)!.replaceAll(',', '').replaceAll('.', ',')
            : a == null
            ? null
            : (a.group(1) ?? a.group(2)!);
        final money = digits == null ? null : Money.tryParse(digits);
        if (money != null && money.cents > 0) {
          out.add(
            hint(
              ContractField.rate,
              (en ?? a)!.group(0)!.trim(),
              amount: money,
            ),
          );
        }
      }

      if (lower.contains('wertsicher') ||
          lower.contains('verbraucherpreisindex') ||
          lower.contains('vpi') ||
          lower.contains('indexanpassung') ||
          lower.contains('indexiert') ||
          lower.contains('consumer price index') ||
          lower.contains('indexation') ||
          lower.contains('inflation')) {
        out.add(hint(ContractField.indexation, excerpt));
      }
    }
    return out;
  }
}
