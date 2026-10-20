/// Abschnitt „Buchungsregeln und Angaben für die Steuerberatung“ (FA-20.5):
/// jede Regel mit Grundlage, Zahlen, Begründung, Anhängen und den
/// betroffenen Summen des Zeitraums. Eingangsinformation für die
/// Steuerberatung, keine Beratung.
library;

import '../../core/formatting.dart';
import '../../domain/booking_rule.dart';
import '../booking_rule_split.dart';
import '../export/csv.dart';

class BookingRuleReportEntry {
  const BookingRuleReportEntry({
    required this.sums,
    required this.scopeLabel,
    this.attachments = const [],
  });

  final BookingRuleSums sums;

  /// Geltungsbereich in Worten (Kategorien, Lieferant, Steuerland).
  final String scopeLabel;
  final List<BookingRuleAttachment> attachments;

  BookingRule get rule => sums.rule;

  String get basisText {
    final r = rule;
    final part = r.basisPartMilli;
    final total = r.basisTotalMilli;
    final numbers = part == null || total == null
        ? ''
        : ': ${milli(part)} ${r.basis.partLabel} von ${milli(total)} '
              '${r.basis.totalLabel}';
    return '${r.basis.label}$numbers';
  }

  String get validity =>
      'ab ${Fmt.date(rule.validFrom)}'
      '${rule.validTo == null ? '' : ' bis ${Fmt.date(rule.validTo!)}'}';

  String get attachmentText => attachments.isEmpty
      ? 'keine'
      : attachments
            .map(
              (a) => a.note.isEmpty ? a.fileName : '${a.fileName} (${a.note})',
            )
            .join('; ');

  /// Tausendstel als Zahl mit bis zu drei Nachkommastellen („12,5“).
  static String milli(int v) {
    final whole = v ~/ 1000;
    var frac = (v % 1000).toString().padLeft(3, '0');
    while (frac.endsWith('0')) {
      frac = frac.substring(0, frac.length - 1);
    }
    return frac.isEmpty ? '$whole' : '$whole,$frac';
  }
}

/// Hinweis unter dem Abschnitt (Rechtsanwalt-Instanz, P-R65).
const bookingRuleDisclaimer =
    'Angaben der Unternehmerin als Grundlage für die Steuerberatung – '
    'ersetzt keine individuelle Beratung.';

/// CSV für das Paket an die Steuerberatung.
String bookingRulesCsv(List<BookingRuleReportEntry> entries) {
  final w = CsvWriter();
  final rows = <List<String>>[
    [
      'Regel',
      'Art',
      'Betrieblich',
      'Grundlage',
      'Gültig',
      'Geltungsbereich',
      'Begründung',
      'Anhänge',
      'Buchungen',
      'Ausgenommen',
      'Aufwand',
      'davon betrieblich',
      'Privatanteil',
      'Vorsteuer nicht abziehbar',
    ],
    for (final e in entries)
      [
        e.rule.name,
        e.rule.type.label,
        formatPermille(e.rule.businessPermille),
        e.basisText,
        e.validity,
        e.scopeLabel,
        e.rule.comment,
        e.attachmentText,
        '${e.sums.count}',
        '${e.sums.excludedCount}',
        csvAmount(e.sums.base.cents),
        csvAmount(e.sums.business.cents),
        csvAmount(e.sums.privatePart.cents),
        csvAmount(e.sums.inputVatRemoved.cents),
      ],
  ];
  rows.forEach(w.writeRow);
  w.writeRow([bookingRuleDisclaimer]);
  return w.build();
}
