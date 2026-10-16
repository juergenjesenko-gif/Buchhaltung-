import '../../domain/contract.dart';
import '../export/csv.dart';

/// Vertragsliste als CSV für das Paket an die Steuerberatung (L-23.11).
/// Seiten und Originale stecken in der Sicherung.
class ContractCsv {
  ContractCsv._();

  static const fileName = 'vertraege.csv';

  static String build(List<Contract> contracts) {
    String d(DateTime? v) =>
        v == null ? '' : v.toIso8601String().substring(0, 10);
    final csv = CsvWriter()
      ..writeRow([
        'Art',
        'Bezeichnung',
        'Vertragspartner',
        'Beginn',
        'Ende',
        'Kündigungsfrist',
        'Rate brutto',
        'Rhythmus',
        'Wertsicherung',
        'Nächste Indexanpassung',
        'Seiten',
        'Kommentar',
      ]);
    for (final c in contracts) {
      csv.writeRow([
        c.type.label,
        c.title,
        c.partner,
        d(c.startDate),
        d(c.endDate),
        c.noticeValue == null ? '' : '${c.noticeValue} ${c.noticeUnit.label}',
        csvAmount(c.rate.cents),
        c.rhythm.label,
        c.indexation,
        d(c.nextIndexDate),
        c.pages.length,
        c.comment,
      ]);
    }
    return csv.build();
  }
}
