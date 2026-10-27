import 'dart:convert';
import 'dart:io';

import 'package:buchhaltung/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mehrsprachigkeit (L-34.1): Jede Sprache trägt genau die Schlüssel der
/// deutschen Vorlage, kein Text bleibt leer, Platzhalter stimmen überein.
void main() {
  Map<String, dynamic> arb(String code) =>
      jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
          as Map<String, dynamic>;

  Set<String> keys(Map<String, dynamic> m) =>
      m.keys.where((k) => !k.startsWith('@')).toSet();

  Set<String> placeholders(String text) =>
      RegExp(r'\{(\w+)').allMatches(text).map((m) => m[1]!).toSet();

  final vorlage = arb('de');
  final sprachen = Directory('lib/l10n')
      .listSync()
      .map((f) => RegExp(r'app_(\w+)\.arb$').firstMatch(f.path)?[1])
      .whereType<String>()
      .where((c) => c != 'de')
      .toList();

  test('es gibt mindestens Englisch', () {
    expect(sprachen, contains('en'));
  });

  for (final code in sprachen) {
    test('$code hat dieselben Schlüssel wie de', () {
      final sprache = arb(code);
      expect(keys(sprache), keys(vorlage));
      for (final k in keys(vorlage)) {
        expect((sprache[k] as String).trim(), isNotEmpty, reason: k);
        expect(
          placeholders(sprache[k] as String),
          placeholders(vorlage[k] as String),
          reason: k,
        );
      }
    });
  }

  testWidgets('ohne Delegate gilt Deutsch', (tester) async {
    late String titel;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            titel = context.l10n.consentTitle;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(titel, 'Bevor es losgeht');
  });

  testWidgets('mit englischer Locale kommt Englisch', (tester) async {
    late String titel;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'GB'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) {
            titel = context.l10n.consentTitle;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(titel, 'Before you start');
  });
}
