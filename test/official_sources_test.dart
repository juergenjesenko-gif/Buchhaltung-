import 'dart:io';

import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/official_sources.dart';
import 'package:buchhaltung/features/help/help_screen.dart';
import 'package:buchhaltung/features/help/sources_screen.dart';
import 'package:buchhaltung/features/settings/legal_screen.dart';
import 'package:buchhaltung/widgets/source_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// FA-11.11: amtliche Quellen nach der Google-Play-Ablehnung 2026-10-24.
void main() {
  group('Quellen je Land', () {
    test('Österreich: RIS-Links auf § 11 und § 6 UStG 1994', () {
      final t = TaxProfile.austria;
      expect(t.invoiceSourceUrl, startsWith('https://www.ris.bka.gv.at/'));
      expect(t.invoiceSourceUrl, contains('Gesetzesnummer=10004873'));
      expect(t.invoiceSourceUrl, endsWith('Paragraf=11'));
      expect(t.smallBusinessSourceUrl, endsWith('Paragraf=6'));
      expect(
        t.officialSources.map((s) => s.url),
        containsAll(['https://www.bmf.gv.at', 'https://www.erb.gv.at']),
      );
    });

    test('Deutschland: gesetze-im-internet.de § 14 und § 19 UStG', () {
      final t = TaxProfile.germany;
      expect(
        t.invoiceSourceUrl,
        'https://www.gesetze-im-internet.de/ustg_1980/__14.html',
      );
      expect(
        t.smallBusinessSourceUrl,
        'https://www.gesetze-im-internet.de/ustg_1980/__19.html',
      );
      expect(
        t.officialSources.map((s) => s.url),
        containsAll([
          'https://www.bundesfinanzministerium.de',
          'https://www.e-rechnung-bund.de',
        ]),
      );
    });

    test('alle Adressen https und in der Store-Beschreibung', () {
      final store = File('docs/STORE_LISTING.md').readAsStringSync();
      expect(store, contains('QUELLEN (AMTLICHE INFORMATIONEN)'));
      expect(store, contains('kein Angebot einer Behörde'));
      final urls = [
        for (final s in OfficialSource.all) s.url,
        for (final t in [TaxProfile.austria, TaxProfile.germany]) ...[
          t.invoiceSourceUrl,
          t.smallBusinessSourceUrl,
        ],
      ];
      for (final u in urls) {
        expect(Uri.parse(u).scheme, 'https', reason: u);
        expect(store, contains(u), reason: u);
      }
    });

    test('Store-Beschreibung höchstens 4000 Zeichen', () {
      final store = File('docs/STORE_LISTING.md').readAsStringSync();
      final start = store.indexOf('```\nJeNi bucht: Buchhaltung') + 4;
      final end = store.indexOf('```', start);
      final text = store.substring(start, end).trimRight();
      expect(text.length, lessThanOrEqualTo(4000));
    });

    test('Widgets nutzen TaxProfile statt Länderabfrage', () {
      for (final f in [
        'lib/features/dashboard/dashboard_screen.dart',
        'lib/features/invoices/invoice_edit_screen.dart',
      ]) {
        final src = File(f).readAsStringSync();
        expect(src, contains('SourceLinkButton('), reason: f);
        expect(
          src,
          contains(RegExp(r'tax\.(invoice|smallBusiness)SourceUrl')),
          reason: f,
        );
      }
    });
  });

  testWidgets('Quelle-Link mindestens 48 dp', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SourceLinkButton(
              url: TaxProfile.austria.invoiceSourceUrl,
              label: '§ 11 UStG',
            ),
          ),
        ),
      ),
    );
    expect(find.text('Quelle: § 11 UStG'), findsOneWidget);
    final size = tester.getSize(find.byType(TextButton));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.width, greaterThanOrEqualTo(48));
  });

  testWidgets('Quellen-Bildschirm zeigt Hinweis und alle Links', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SourcesScreen()));
    expect(find.text('Kein Angebot einer Behörde'), findsOneWidget);
    for (final s in OfficialSource.all) {
      final tile = find.byKey(Key('source-${s.url}'));
      await tester.scrollUntilVisible(tile, 100);
      expect(find.text(s.label), findsOneWidget);
      expect(tester.getSize(tile).height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('Rechtliches führt zu den Quellen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LegalScreen()));
    await tester.tap(find.byKey(const Key('legal-sources')));
    await tester.pumpAndSettle();
    expect(find.byType(SourcesScreen), findsOneWidget);
  });

  testWidgets('Hilfe-Übersicht führt zu den Quellen', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HelpScreen(manual: '# Handbuch\n\n## 1. Start\n\nText.\n'),
      ),
    );
    await tester.pumpAndSettle();
    final tile = find.byKey(const Key('help-sources'));
    expect(tile, findsOneWidget);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byType(SourcesScreen), findsOneWidget);
  });
}
