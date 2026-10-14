import 'dart:convert';

/// Minimaler CSV-Leser für Plattformexporte (RFC 4180 mit Anführungszeichen,
/// Trennzeichen `,` `;` oder Tabulator, UTF-8 mit/ohne BOM, sonst Latin-1).
class CsvTable {
  CsvTable._(this.rows);

  final List<List<String>> rows;

  static String decode(List<int> bytes) {
    var data = bytes;
    if (data.length >= 3 &&
        data[0] == 0xEF &&
        data[1] == 0xBB &&
        data[2] == 0xBF) {
      data = data.sublist(3);
    }
    try {
      return utf8.decode(data);
    } on FormatException {
      return latin1.decode(data);
    }
  }

  /// Ermittelt das Trennzeichen aus den ersten Zeilen: das häufigste
  /// außerhalb von Anführungszeichen.
  static String detectDelimiter(String text) {
    final sample = text.length > 8000 ? text.substring(0, 8000) : text;
    final counts = {',': 0, ';': 0, '\t': 0};
    var quoted = false;
    for (final ch in sample.split('')) {
      if (ch == '"') quoted = !quoted;
      if (!quoted && counts.containsKey(ch)) counts[ch] = counts[ch]! + 1;
    }
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  static CsvTable parse(String text, {String? delimiter}) {
    if (text.startsWith('﻿')) text = text.substring(1);
    final sep = delimiter ?? detectDelimiter(text);
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var quoted = false;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (quoted) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            quoted = false;
          }
        } else {
          field.write(ch);
        }
      } else if (ch == '"') {
        quoted = true;
      } else if (ch == sep) {
        row.add(field.toString());
        field.clear();
      } else if (ch == '\n' || ch == '\r') {
        if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        row.add(field.toString());
        field.clear();
        if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
        row = <String>[];
      } else {
        field.write(ch);
      }
    }
    row.add(field.toString());
    if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
    return CsvTable._(rows);
  }
}

/// Vereinheitlicht einen Spaltennamen: klein, ohne Akzente, ohne Satzzeichen.
String normalizeHeader(String raw) {
  const map = {
    'ä': 'a', 'à': 'a', 'á': 'a', 'â': 'a', //
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ö': 'o', 'ó': 'o', 'ò': 'o', 'ô': 'o',
    'ü': 'u', 'ú': 'u', 'ù': 'u', 'û': 'u',
    'ñ': 'n', 'ç': 'c', 'ß': 'ss',
  };
  final lower = raw.trim().toLowerCase();
  final b = StringBuffer();
  for (final ch in lower.split('')) {
    final m = map[ch] ?? ch;
    if (RegExp(r'[a-z0-9]').hasMatch(m)) b.write(m);
  }
  return b.toString();
}

/// Liest einen Betrag in Cent. Versteht `1.234,56`, `1,234.56`, `-12.5`,
/// `(12,50)`, Währungszeichen und Leerzeichen. `null`, wenn nicht lesbar.
/// Ganzzahlige Rechnung, kein `double` (CLAUDE.md Regel 1).
int? parseCents(String raw) {
  var s = raw.trim().replaceAll(' ', '').replaceAll(' ', '');
  if (s.isEmpty) return null;
  var negative = false;
  if (s.startsWith('(') && s.endsWith(')')) {
    negative = true;
    s = s.substring(1, s.length - 1);
  }
  s = s.replaceAll(RegExp(r'[€$£A-Za-z]'), '');
  if (s.startsWith('-')) {
    negative = !negative;
    s = s.substring(1);
  } else if (s.startsWith('+')) {
    s = s.substring(1);
  }
  if (s.endsWith('-')) {
    negative = !negative;
    s = s.substring(0, s.length - 1);
  }
  final lastComma = s.lastIndexOf(',');
  final lastDot = s.lastIndexOf('.');
  String intPart;
  var fracPart = '';
  int? decimalAt;
  if (lastComma >= 0 && lastDot >= 0) {
    decimalAt = lastComma > lastDot ? lastComma : lastDot;
  } else {
    final at = lastComma >= 0 ? lastComma : lastDot;
    if (at >= 0) {
      final digitsAfter = s.length - at - 1;
      final separators = s.split(s[at]).length - 1;
      // „1.234“ bzw. „1,234“ ist ein Tausenderpunkt, „12,5“ ein Dezimalkomma.
      if (separators == 1 && digitsAfter != 3) decimalAt = at;
    }
  }
  if (decimalAt != null) {
    intPart = s.substring(0, decimalAt);
    fracPart = s.substring(decimalAt + 1);
  } else {
    intPart = s;
  }
  intPart = intPart.replaceAll(RegExp('[.,\']'), '');
  if (!RegExp(r'^\d*$').hasMatch(intPart) ||
      !RegExp(r'^\d*$').hasMatch(fracPart) ||
      (intPart.isEmpty && fracPart.isEmpty)) {
    return null;
  }
  // Auf Cent runden (halbe Cent von der Null weg).
  var cents = int.parse(intPart.isEmpty ? '0' : intPart) * 100;
  final padded = fracPart.padRight(3, '0');
  cents += int.parse(padded.substring(0, 2));
  if (int.parse(padded[2]) >= 5) cents += 1;
  return negative ? -cents : cents;
}

const _monthNames = <String, int>{
  // EN
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
  'jul': 7, 'aug': 8, 'sep': 9, 'sept': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  // DE
  'januar': 1, 'jan.': 1, 'februar': 2, 'marz': 3, 'mrz': 3, 'mai': 5,
  'juni': 6, 'juli': 7, 'okt': 10, 'dez': 12,
  // FR
  'janv': 1, 'fevr': 2, 'fev': 2, 'mars': 3, 'avr': 4, 'juin': 6,
  'juil': 7, 'aout': 8, 'oct.': 10, 'dec.': 12,
  // IT
  'gen': 1, 'mag': 5, 'giu': 6, 'lug': 7, 'ago': 8, 'set': 9, 'ott': 10,
  'dic': 12,
  // ES
  'ene': 1, 'abr': 4, 'dic.': 12,
};

/// Liest ein Datum aus den üblichen Exportformaten: ISO (`2026-03-05`),
/// `05.03.2026`, `05/03/2026` bzw. `03/05/2026` ([monthFirst]) und mit
/// Monatsnamen (`Mar 5, 2026`, `5 mars 2026`, `05.03.2026 10:15:00 UTC`).
DateTime? parsePlatformDate(String raw, {bool monthFirst = false}) {
  final s = raw.trim();
  var m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s);
  if (m != null) {
    return _date(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }
  m = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})').firstMatch(s);
  if (m != null) {
    return _date(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
  }
  m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(s);
  if (m != null) {
    final a = int.parse(m[1]!), b = int.parse(m[2]!);
    return monthFirst
        ? _date(int.parse(m[3]!), a, b)
        : _date(int.parse(m[3]!), b, a);
  }
  final year = RegExp(r'\b(\d{4})\b').firstMatch(s);
  if (year == null) return null;
  int? month;
  int? day;
  for (final token
      in s
          .toLowerCase()
          .split(RegExp(r'[\s,/-]+'))
          .where((t) => t.isNotEmpty)) {
    final word = normalizeHeader(token);
    if (month == null && word.isNotEmpty && !RegExp(r'^\d').hasMatch(word)) {
      month = _monthNames[word] ?? _monthNames['$word.'];
      if (month == null && word.length > 3) {
        month = _monthNames[word.substring(0, 3)];
      }
      continue;
    }
    if (day == null && RegExp(r'^\d{1,2}\.?$').hasMatch(token)) {
      day = int.parse(token.replaceAll('.', ''));
    }
  }
  if (month == null || day == null) return null;
  return _date(int.parse(year[1]!), month, day);
}

DateTime? _date(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  return DateTime(y, m, d);
}

/// FNV-1a 64 Bit (hex) – stabile Kennung für Zeilen ohne eigene ID.
String fnv1a(String input) {
  var hash = 0xcbf29ce484222325;
  const prime = 0x100000001b3;
  for (final b in utf8.encode(input)) {
    hash ^= b;
    hash = (hash * prime) & 0xFFFFFFFFFFFFFFFF;
  }
  return hash.toUnsigned(64).toRadixString(16).padLeft(16, '0');
}
