/// Minimaler CSV-Schreiber nach RFC 4180, aber mit Semikolon als Trennzeichen.
///
/// Excel im deutschsprachigen Raum erwartet Semikolon; ein Komma würde bei
/// Beträgen wie "1.234,56" sofort die Spalten zerreißen.
class CsvWriter {
  CsvWriter({this.separator = ';'});

  final String separator;
  final StringBuffer _buffer = StringBuffer();
  var _rowCount = 0;

  int get rowCount => _rowCount;

  void writeRow(List<Object?> values) {
    _buffer.write(values.map(_escape).join(separator));
    // CRLF: DATEV und BMD erwarten Windows-Zeilenenden.
    _buffer.write('\r\n');
    _rowCount++;
  }

  void writeRaw(String line) {
    _buffer.write(line);
    _buffer.write('\r\n');
    _rowCount++;
  }

  String _escape(Object? value) {
    if (value == null) return '';
    final text = value.toString();
    if (text.contains(separator) ||
        text.contains('"') ||
        text.contains('\n') ||
        text.contains('\r')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  /// Mit BOM, damit Excel die Datei als UTF-8 erkennt und Umlaute nicht zerlegt.
  String build({bool withBom = true}) =>
      withBom ? '﻿$_buffer' : _buffer.toString();

  @override
  String toString() => build();
}

/// Betrag als Dezimalzahl mit Komma – so erwarten es DATEV, BMD und Excel im
/// deutschsprachigen Raum. Ohne Tausendertrenner, der würde die Spalte sprengen.
String csvAmount(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  return '$sign${abs ~/ 100},${(abs % 100).toString().padLeft(2, '0')}';
}
