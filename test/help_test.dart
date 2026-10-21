import 'dart:io';

import 'package:buchhaltung/features/help/help_screen.dart';
import 'package:buchhaltung/services/help/help_index.dart';
import 'package:buchhaltung/services/help/help_outline.dart';
import 'package:buchhaltung/services/help/support_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hilfe Stufe 1 (FA-11.1 bis FA-11.3).
void main() {
  final manual = File('docs/BENUTZERHANDBUCH.md').readAsStringSync();
  final index = HelpIndex.fromManual(manual);

  String top(String q, {HelpTopic? context}) =>
      index.search(q, context: context).first.section.title;

  Iterable<String> top3(String q, {HelpTopic? context}) =>
      index.search(q, context: context).take(3).map((h) => h.section.title);

  group('Asset-Synchronität', () {
    test('das Handbuch selbst ist als Asset eingebunden', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('    - $manualAsset'));
      expect(File(manualAsset).existsSync(), isTrue);
    });

    test('jede Handbuch-Überschrift ist durchsuchbar', () {
      final titles = index.sections.map((s) => s.title).toSet();
      final chapters = index.sections.map((s) => s.chapter).toSet();
      for (final m in RegExp(
        r'^#{2,3}\s+(.*)$',
        multiLine: true,
      ).allMatches(manual)) {
        final heading = stripMarkdown(
          m.group(1)!,
        ).replaceFirst(RegExp(r'^\d+\.\s*'), '').trim();
        if (heading == 'Inhalt') continue;
        expect(
          titles.contains(heading) || chapters.contains(heading),
          isTrue,
          reason: 'Abschnitt „$heading“ fehlt im Hilfe-Index',
        );
      }
    });

    test('jede Frage aus „Häufige Fragen“ ist ein eigener Treffer', () {
      final faq = manual.split('## 12. Häufige Fragen')[1].split('\n## ')[0];
      final questions = RegExp(
        r'^\*\*(.+?)\*\*',
        multiLine: true,
      ).allMatches(faq).length;
      expect(
        index.sections.where((s) => s.chapter == 'Häufige Fragen').length,
        questions,
      );
    });
  });

  group('Suche', () {
    test('Normalisierung: Umlaute und Groß/Klein', () {
      expect(normalizeHelpText('Rückseite LÖSCHEN'), 'ruckseite loschen');
      expect(helpTokens('Belege'), helpTokens('beleg'));
    });

    test('„Beleg löschen“ findet Stornieren (Synonym)', () {
      expect(top3('Beleg löschen'), contains('Beleg ändern oder stornieren'));
      expect(
        top('Beleg löschen', context: HelpTopic.receipts),
        'Beleg ändern oder stornieren',
      );
      expect(top('beleg stornieren'), 'Beleg ändern oder stornieren');
    });

    test('Kleinunternehmergrenze', () {
      final hits = index.search('Kleinunternehmergrenze').take(3);
      expect(
        hits.map((h) => h.section.chapter),
        contains('Die Kleinunternehmergrenze'),
      );
    });

    test('Rückseite', () {
      final hits = index.search('Rückseite').take(3).map((h) => h.section);
      expect(hits.any((s) => s.chapter == 'Belege erfassen'), isTrue);
    });

    test('Datensicherung, Fremdwährung, Rechnungsnummer', () {
      expect(
        index.search('Backup').take(3).map((h) => h.section.chapter),
        contains('Deine Daten und ihre Sicherung'),
      );
      expect(top3('Dollar'), contains('Belege in fremder Währung'));
      expect(top('Rechnungsnummer'), 'Rechnungsnummern');
    });

    test('Kontext: vom Belegformular zuerst Beleg-Themen', () {
      final hits = index.search('', context: HelpTopic.receipts);
      expect(hits, isNotEmpty);
      expect(hits.every((h) => h.section.topic == HelpTopic.receipts), isTrue);
    });

    test('Unsinn liefert keinen Treffer', () {
      expect(index.search('xylophonquartett'), isEmpty);
    });
  });

  group('Support-Mail', () {
    test('Betreff enthält Version, keine Daten', () {
      final uri = supportMailUri(supportSubject('0.3.4', 'Wo ist X?'));
      expect(uri.scheme, 'mailto');
      expect(uri.path, 'office@jenibarb.com');
      expect(uri.query, startsWith('subject='));
      expect(uri.query, isNot(contains('body')));
      expect(
        Uri.decodeComponent(uri.query.substring(8)),
        'Frage zu JeNi bucht (Version 0.3.4): Wo ist X?',
      );
      expect(uri.toString(), isNot(contains('+')));
    });
  });

  testWidgets('Hilfe-Bildschirm: suchen, öffnen, ohne Treffer Support', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: HelpScreen(manual: manual)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Beleg löschen');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beleg ändern oder stornieren').first);
    await tester.pumpAndSettle();
    expect(find.byType(HelpSectionScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'xylophonquartett');
    await tester.pumpAndSettle();
    expect(find.text('E-Mail an den Support'), findsOneWidget);
  });

  group('Gliederung', () {
    const md = """# Titel

## Inhalt

1. Belege

## 1. Belege erfassen

Einleitung.

### Foto

Fotografieren.

### Stornieren

Stornieren.

## 2. Rechnungen schreiben

Rechnungstext.
""";
    final outline = helpOutline(parseManual(md));

    test('Kapitel ohne Inhalt, mit Einleitung und Abschnitten', () {
      expect(outline.map((c) => c.title), [
        'Belege erfassen',
        'Rechnungen schreiben',
      ]);
      expect(outline.first.intro!.body, 'Einleitung.');
      expect(outline.first.sections.map((s) => s.title), [
        'Foto',
        'Stornieren',
      ]);
      expect(outline.last.sections, isEmpty);
    });

    test('Thema springt ins passende Kapitel', () {
      expect(
        chapterForTopic(outline, HelpTopic.receipts)!.title,
        'Belege erfassen',
      );
      expect(
        chapterForTopic(outline, HelpTopic.invoices)!.title,
        'Rechnungen schreiben',
      );
      expect(chapterForTopic(outline, HelpTopic.general), isNull);
      expect(chapterForTopic(outline, null), isNull);
    });

    test('echtes Handbuch: Kapitel 4 gefunden, kein Inhalt', () {
      final real = helpOutline(index.sections);
      expect(real.map((c) => c.title), contains('Belege erfassen'));
      expect(real.map((c) => c.title), isNot(contains('Inhalt')));
      expect(
        chapterForTopic(real, HelpTopic.receipts)!.title,
        'Belege erfassen',
      );
    });
  });

  testWidgets('Übersicht zeigt Kapitel, Antippen nur dieses Kapitel', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: HelpScreen(manual: manual)));
    await tester.pumpAndSettle();
    expect(find.text('Belege erfassen'), findsOneWidget);
    expect(find.text('Inhalt'), findsNothing);
    await tester.tap(find.text('Belege erfassen'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpChapterScreen), findsOneWidget);
    expect(find.byType(ExpansionTile), findsWidgets);
    expect(find.text('Rechnungen schreiben'), findsNothing);
  });

  testWidgets('Hilfe-Knopf mit Thema springt direkt ins Kapitel', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HelpScreen(manual: manual, context: HelpTopic.invoices),
      ),
    );
    await tester.pumpAndSettle();
    final screen = tester.widget<HelpChapterScreen>(
      find.byType(HelpChapterScreen),
    );
    expect(screen.chapter.title, 'Rechnungen schreiben');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Belege erfassen'), findsOneWidget);
  });
}
