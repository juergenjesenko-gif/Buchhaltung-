import 'dart:io';

import 'package:buchhaltung/domain/legal_texts.dart';
import 'package:buchhaltung/features/settings/legal_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

/// Menü „Rechtliches“ (L-22.18): eine Quelle für Store-Seite und App.
void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();

  for (final doc in LegalDocument.values) {
    test('${doc.title} ist als Asset eingebunden', () {
      expect(File(doc.asset).existsSync(), isTrue);
      expect(pubspec, contains('    - ${doc.asset}'));
    });
  }

  test('alle Rechtstexte in docs/legal/ sind im Menü', () {
    final files = Directory('docs/legal')
        .listSync()
        .map((f) => f.path.replaceAll('\\', '/'))
        .where((p) => p.endsWith('.md') && !p.endsWith('README.md'));
    expect(files.toSet(), LegalDocument.values.map((d) => d.asset).toSet());
  });

  test('Entwurfsvermerk der Datei wird durch den App-Vermerk ersetzt', () {
    final body = LegalDocument.body(
      File(LegalDocument.imprint.asset).readAsStringSync(),
    );
    expect(body, isNot(contains('ENTWURF')));
    expect(body, contains('Anbieterin'));
  });

  test('Entwurfsvermerk passt zum Stand der Texte (P-L1)', () {
    final draft = LegalDocument.values.any(
      (d) => File(d.asset).readAsStringSync().contains('ENTWURF'),
    );
    expect(LegalDocument.reviewed, !draft);
  });

  test('Work-Sans-Lizenz wird mitgeliefert', () {
    expect(pubspec, contains('    - assets/fonts/OFL.txt'));
  });

  testWidgets('Text öffnet offline mit Entwurfsvermerk', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LegalDocumentScreen(
          document: LegalDocument.imprint,
          bundle: _FileBundle(),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('legal-draft')), findsOneWidget);
    expect(find.textContaining('Anbieterin', findRichText: true), findsWidgets);
  });

  testWidgets('Menü zeigt alle Einträge mit Touchfläche ≥ 48 dp', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LegalScreen()));
    for (final key in [
      ...LegalDocument.values.map((d) => 'legal-${d.name}'),
      'legal-disclaimer',
      'legal-support',
      'legal-licenses',
    ]) {
      final size = tester.getSize(find.byKey(Key(key)));
      expect(size.height, greaterThanOrEqualTo(48), reason: key);
    }
  });
}
