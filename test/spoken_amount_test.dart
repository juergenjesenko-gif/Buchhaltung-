import 'package:buchhaltung/services/dictation/spoken_amount.dart';
import 'package:flutter_test/flutter_test.dart';

/// Diktat in Betragsfeldern (FA-2.61): gesprochene Beträge → Cent.
void main() {
  const cases = <String, int>{
    'zwölf Euro fünfzig': 1250,
    'Zwölf Euro und fünfzig Cent': 1250,
    'zwölf komma fünf null': 1250,
    'zwölf komma fünfzig': 1250,
    'zwölf komma fünf': 1250,
    'zwölf komma null fünf': 1205,
    'zwölf fünfzig': 1250,
    'zwölf Euro': 1200,
    'zwölf': 1200,
    'eintausendzweihundert': 120000,
    'tausendzweihundert': 120000,
    'tausend zweihundert Euro und fünfzig Cent': 120050,
    'eintausendzweihundertvierunddreißig Euro neunundneunzig': 123499,
    'dreiundzwanzig Euro': 2300,
    'drei und zwanzig Euro': 2300,
    'hunderteins': 10100,
    'einhundertundeins Euro': 10100,
    'zweihundertfünfzig': 25000,
    'fünfzig Cent': 50,
    'neunundneunzig Cent': 99,
    'eine Million': 100000000,
    'zwei Millionen dreihunderttausend': 230000000,
    'siebzehn Euro neunzig': 1790,
    'dreissig Euro': 3000,
    '1200,50': 120050,
    '1.200,50 €': 120050,
    '1200,5': 120050,
    '12,50 Euro': 1250,
    '12.50': 1250,
    '12 Euro 50': 1250,
    '12 komma 5': 1250,
    '12 komma 05': 1205,
    '€ 7,90': 790,
    'zwo Euro': 200,
  };
  for (final entry in cases.entries) {
    test('„${entry.key}“ → ${entry.value} Cent', () {
      expect(SpokenAmount.parse(entry.key)?.cents, entry.value);
    });
  }

  for (final bad in const [
    '',
    'hallo',
    'zwölf Euro hundertfünfzig',
    'minus zwölf',
    'null',
    'zwölf dreizehn vierzehn',
    'komma fünf',
    'hundert Cent',
  ]) {
    test('kein Vorschlag bei „$bad“', () {
      expect(SpokenAmount.parse(bad), isNull);
    });
  }
}
