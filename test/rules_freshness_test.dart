import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/services/rules_freshness.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regelstand und Aktualisieren-Hinweis (FA-21.1 bis FA-21.3).
void main() {
  final at = TaxProfile.austria;
  final de = TaxProfile.germany;

  test('gültig bis einschließlich rulesValidUntil', () {
    final last = at.rulesValidUntil;
    expect(RulesFreshness.isOutdated(at, last), isFalse);
    expect(
      RulesFreshness.isOutdated(at, last.add(const Duration(hours: 23))),
      isFalse,
    );
    expect(
      RulesFreshness.isOutdated(at, last.add(const Duration(days: 1))),
      isTrue,
    );
  });

  test('Hinweis nennt das neue Jahr, sobald ein Profil abgelaufen ist', () {
    final next = DateTime(at.rulesValidUntil.year + 1, 1, 2);
    expect(RulesFreshness.outdatedYear([at, de], at.rulesValidUntil), isNull);
    expect(RulesFreshness.outdatedYear([at, de], next), next.year);
    expect(RulesFreshness.outdatedYear(const [], next), isNull);
    expect(
      RulesFreshness.bannerText(next.year),
      'Für ${next.year} gibt es neue Steuerwerte – bitte App aktualisieren.',
    );
  });

  test('Schätzung für ein Jahr ohne Werte ist gekennzeichnet', () {
    final y = at.rulesValidUntil.year;
    expect(RulesFreshness.estimateNote(at, y), isNull);
    expect(
      RulesFreshness.estimateNote(at, y + 1),
      'Werte von $y – Schätzung unsicher',
    );
  });

  test('Einstellungen fassen gleiche Stände zusammen', () {
    expect(
      RulesFreshness.settingsLine([at, de, de]),
      'Steuerregeln: Stand 01.01.2026, gültig für 2026 (AT/DE)',
    );
  });

  test('Store-Adressen sind https (openInBrowser)', () {
    expect(RulesFreshness.androidStoreUrl, startsWith('https://'));
    expect(RulesFreshness.iosStoreUrl, startsWith('https://'));
    expect(RulesFreshness.androidStoreUrl, contains('at.jenibarb.jenibucht'));
  });
}
