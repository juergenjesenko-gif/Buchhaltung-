import '../../domain/money.dart';

/// Gesprochene Beträge auf Deutsch → [Money] in ganzen Cent (Diktat in
/// Betragsfeldern, FA-2.61). Nur ein Vorschlag: das Feld zeigt ihn, die
/// Nutzerin bestätigt beim Speichern.
///
/// Verstanden werden u. a. „zwölf Euro fünfzig“, „zwölf komma fünf null“,
/// „zwölf komma fünfzig“, „eintausendzweihundert“, „tausend zweihundert
/// Euro und fünfzig Cent“, „fünfzig Cent“, „zwölf fünfzig“ sowie Ziffern
/// wie „1200,50“, „1.200,50 €“ oder „12 Euro 50“. Kein Double: alles in Cent.
class SpokenAmount {
  const SpokenAmount._();

  /// Obergrenze, damit ein Hörfehler keinen absurden Betrag vorschlägt.
  static const maxCents = 9999999999; // 99 999 999,99 €

  static const _units = <String, int>{
    'null': 0,
    'ein': 1,
    'eins': 1,
    'eine': 1,
    'einen': 1,
    'zwei': 2,
    'zwo': 2,
    'drei': 3,
    'vier': 4,
    'fünf': 5,
    'sechs': 6,
    'sieben': 7,
    'acht': 8,
    'neun': 9,
  };

  static const _teens = <String, int>{
    'zehn': 10,
    'elf': 11,
    'zwölf': 12,
    'dreizehn': 13,
    'vierzehn': 14,
    'fünfzehn': 15,
    'sechzehn': 16,
    'siebzehn': 17,
    'achtzehn': 18,
    'neunzehn': 19,
  };

  static const _tens = <String, int>{
    'zwanzig': 20,
    'dreißig': 30,
    'vierzig': 40,
    'fünfzig': 50,
    'sechzig': 60,
    'siebzig': 70,
    'achtzig': 80,
    'neunzig': 90,
  };

  /// Liest den Betrag oder `null`, wenn nichts Eindeutiges erkannt wurde.
  static Money? parse(String spoken) {
    var text = spoken
        .toLowerCase()
        .replaceAll('dreissig', 'dreißig')
        .replaceAll('€', ' euro ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.isEmpty) return null;
    if (text.contains('minus')) return null;

    // Reine Ziffern mit Komma/Punkt: „1200,50“, „1.200,50 €“, „12,5 Euro“.
    final parts = text
        .replaceAll(RegExp(r'\b(euro|eur)\b'), ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    final digitsOnly = parts.length == 1 ? parts.single : '';
    if (RegExp(r'^\d[\d.]*(,\d{1,2})?$').hasMatch(digitsOnly) ||
        RegExp(r'^\d+\.\d{1,2}$').hasMatch(digitsOnly)) {
      final normalized = RegExp(r'^\d+\.\d{1,2}$').hasMatch(digitsOnly)
          ? digitsOnly.replaceAll('.', ',')
          : digitsOnly;
      return _checked(Money.tryParse(normalized));
    }

    final items = _tokens(text);
    if (items == null || items.isEmpty) return null;
    return _checked(_combine(items));
  }

  static Money? _checked(Money? m) {
    if (m == null || m.cents <= 0 || m.cents > maxCents) return null;
    return m;
  }

  /// Zerlegt in Zahlen und Marker („euro“, „cent“, „komma“).
  static List<Object>? _tokens(String text) {
    final words = text
        .replaceAll(',', ' komma ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    final out = <Object>[];
    var i = 0;
    while (i < words.length) {
      final w = words[i];
      if (w == 'euro' || w == 'eur') {
        out.add(_Marker.euro);
        i++;
        continue;
      }
      if (w == 'cent' || w == 'cents' || w == 'ct') {
        out.add(_Marker.cent);
        i++;
        continue;
      }
      if (w == 'komma' || w == 'punkt') {
        out.add(_Marker.comma);
        i++;
        continue;
      }
      if (w == 'und' || w == 'genau' || w == 'betrag' || w == 'ist') {
        i++;
        continue;
      }
      if (RegExp(r'^\d+$').hasMatch(w)) {
        out.add(_Num(int.parse(w), w.length));
        i++;
        continue;
      }
      // Zahlwörter: so viele Wörter zusammenziehen, wie noch eine gültige
      // Zahl ergeben („tausend zweihundert“, „drei und zwanzig“).
      final first = _word(w);
      if (first == null) return null;
      var best = first;
      var used = 1;
      var joined = w;
      for (var j = i + 1; j < words.length; j++) {
        final next = words[j];
        if (next == 'und') {
          if (j + 1 < words.length) {
            final candidate = '${joined}und${words[j + 1]}';
            final v = _word(candidate);
            if (v != null) {
              best = v;
              joined = candidate;
              used = j + 2 - i;
              j++;
              continue;
            }
          }
          break;
        }
        final candidate = '$joined$next';
        final v = _word(candidate);
        if (v == null) break;
        best = v;
        joined = candidate;
        used = j + 1 - i;
      }
      out.add(_Num(best, _units.containsKey(joined) ? 1 : 0));
      i += used;
    }
    return out;
  }

  static Money? _combine(List<Object> items) {
    final comma = items.indexOf(_Marker.comma);
    if (comma >= 0) {
      final before = items.sublist(0, comma).whereType<_Num>().toList();
      final after = items.sublist(comma + 1).whereType<_Num>().toList();
      if (before.length != 1 || after.isEmpty) return null;
      final cents = _fraction(after);
      if (cents == null) return null;
      return Money(before.single.value * 100 + cents);
    }
    final euroAt = items.indexOf(_Marker.euro);
    final centAt = items.indexOf(_Marker.cent);
    final numbers = items.whereType<_Num>().toList();
    if (euroAt >= 0) {
      final before = items.sublist(0, euroAt).whereType<_Num>().toList();
      final after = items.sublist(euroAt + 1).whereType<_Num>().toList();
      if (before.length != 1 || after.length > 1) return null;
      final cents = after.isEmpty ? 0 : after.single.value;
      if (cents > 99) return null;
      return Money(before.single.value * 100 + cents);
    }
    if (centAt >= 0) {
      if (numbers.length != 1 || numbers.single.value > 99) return null;
      return Money(numbers.single.value);
    }
    if (numbers.length == 1) return Money(numbers.single.value * 100);
    if (numbers.length == 2 && numbers[1].value < 100) {
      return Money(numbers[0].value * 100 + numbers[1].value);
    }
    return null;
  }

  /// Nachkommastellen: „fünfzig“ → 50, „fünf null“ → 50, „fünf“ → 50,
  /// „null fünf“ → 5, „05“ → 5.
  static int? _fraction(List<_Num> after) {
    if (after.length == 1) {
      final n = after.single;
      if (n.digits == 2) return n.value; // „05“, „50“ als Ziffern
      if (n.value < 10) return n.value * 10;
      if (n.value < 100) return n.value;
      return null;
    }
    if (after.length == 2 && after.every((n) => n.value < 10)) {
      return after[0].value * 10 + after[1].value;
    }
    return null;
  }

  /// Ein zusammengesetztes Zahlwort, z. B. „eintausendzweihundertfünfzig“.
  static int? _word(String w) {
    if (w.isEmpty) return null;
    final million = RegExp(r'^(.*?)million(?:en)?(.*)$').firstMatch(w);
    if (million != null) {
      final left = million.group(1)!;
      final m = left.isEmpty ? 1 : _below1000(left);
      if (m == null) return null;
      final rest = million.group(2)!;
      final r = rest.isEmpty ? 0 : _belowMillion(rest);
      if (r == null) return null;
      return m * 1000000 + r;
    }
    return _belowMillion(w);
  }

  static int? _belowMillion(String w) {
    final i = w.indexOf('tausend');
    if (i < 0) return _below1000(w);
    final left = w.substring(0, i);
    final rest = w.substring(i + 'tausend'.length);
    final t = left.isEmpty ? 1 : _below1000(left);
    if (t == null) return null;
    final r = rest.isEmpty ? 0 : _below1000(rest);
    if (r == null) return null;
    return t * 1000 + r;
  }

  static int? _below1000(String w) {
    final i = w.indexOf('hundert');
    if (i < 0) return _below100(w);
    final left = w.substring(0, i);
    final rest = w.substring(i + 'hundert'.length);
    final h = left.isEmpty ? 1 : _units[left];
    if (h == null || h == 0) return null;
    final r = rest.isEmpty
        ? 0
        : _below100(rest.startsWith('und') ? rest.substring(3) : rest);
    if (r == null) return null;
    return h * 100 + r;
  }

  static int? _below100(String w) {
    final direct = _units[w] ?? _teens[w] ?? _tens[w];
    if (direct != null) return direct;
    final i = w.indexOf('und');
    if (i <= 0) return null;
    final unit = _units[w.substring(0, i)];
    final ten = _tens[w.substring(i + 3)];
    if (unit == null || unit == 0 || ten == null) return null;
    return ten + unit;
  }
}

enum _Marker { euro, cent, comma }

class _Num {
  const _Num(this.value, this.digits);
  final int value;

  /// Zahl der Ziffern bei Ziffern-Eingabe; 1 bei einzelnem Zahlwort 0–9;
  /// sonst 0.
  final int digits;
}
