import 'dart:io';

import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/legal_texts.dart';
import 'package:flutter_test/flutter_test.dart';

/// Länder-Abschnitte in den Rechtstexten (Rückmeldung Tester: nur die Normen
/// des eigenen Landes zeigen).
void main() {
  const text = '''
Gemeinsam.

<!-- nur AT -->
Österreich: § 377 UGB.
<!-- /nur -->
<!-- nur DE -->
Deutschland: § 377 HGB.
<!-- /nur -->

Ende.''';

  test('AT zeigt nur den AT-Abschnitt, ohne Markierungen', () {
    final out = LegalDocument.forCountry(text, Country.at);
    expect(out, contains('UGB'));
    expect(out, isNot(contains('HGB')));
    expect(out, isNot(contains('<!--')));
    expect(out, contains('Gemeinsam.'));
    expect(out, contains('Ende.'));
  });

  test('DE zeigt nur den DE-Abschnitt', () {
    final out = LegalDocument.forCountry(text, Country.de);
    expect(out, contains('HGB'));
    expect(out, isNot(contains('UGB')));
    expect(out, isNot(contains('<!--')));
  });

  test('ohne Land bleibt alles stehen, nur Markierungen fallen weg', () {
    final out = LegalDocument.forCountry(text, null);
    expect(out, contains('UGB'));
    expect(out, contains('HGB'));
    expect(out, isNot(contains('<!--')));
  });

  for (final broken in [
    '<!-- nur AT -->\nA\n<!-- nur DE -->\nB\n<!-- /nur -->\n<!-- /nur -->',
    '<!-- nur AT -->\nA ohne Ende',
    'B\n<!-- /nur -->',
    '<!-- nur CH -->\nC\n<!-- /nur -->',
  ]) {
    test('fehlerhafte Markierung verschluckt keinen Text: $broken', () {
      expect(LegalDocument.countryMarkupValid(broken), isFalse);
      expect(LegalDocument.forCountry(broken, Country.de), broken);
    });
  }

  for (final doc in LegalDocument.values) {
    final source = File(doc.asset).readAsStringSync();

    test('${doc.title}: Markierungen sind gültig', () {
      expect(LegalDocument.countryMarkupValid(source), isTrue);
    });
  }

  // Das Impressum folgt dem Recht der Anbieterin (Herkunftsland Österreich,
  // § 5 ECG) und wird deshalb nicht geteilt.
  for (final doc in [LegalDocument.terms, LegalDocument.privacy]) {
    final source = File(doc.asset).readAsStringSync();

    test('${doc.title}: AT nennt keine deutschen Normen und umgekehrt', () {
      final at = LegalDocument.forCountry(source, Country.at);
      // Die eigene Aufbewahrungsfrist der Anbieterin (österreichisch) darf
      // auch in der DE-Fassung stehen.
      final de = LegalDocument.forCountry(
        source,
        Country.de,
      ).replaceAll('(§ 132 BAO: 7 Jahre)', '');
      for (final norm in ['BGB', 'HGB', '§ 147 AO', '§ 69e']) {
        expect(at, isNot(contains(norm)), reason: norm);
      }
      for (final norm in ['KSchG', 'UGB', 'VGG', '§ 132 BAO', '§ 40e']) {
        expect(de, isNot(contains(norm)), reason: norm);
      }
    });
  }
}
