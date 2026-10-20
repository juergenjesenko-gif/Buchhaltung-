import 'package:buchhaltung/core/window_size.dart';
import 'package:buchhaltung/widgets/adaptive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tablet-Auslegung (Spezifikation 5.7, FA-9.1 bis FA-9.4).
void main() {
  Future<void> setSize(WidgetTester tester, Size logical) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = logical * 2;
    addTearDown(tester.view.reset);
  }

  test('Breitenklassen nach Material 3', () {
    expect(WindowSizeClass.fromWidth(360), WindowSizeClass.compact);
    expect(WindowSizeClass.fromWidth(599.9), WindowSizeClass.compact);
    expect(WindowSizeClass.fromWidth(600), WindowSizeClass.medium);
    expect(WindowSizeClass.fromWidth(839.9), WindowSizeClass.medium);
    expect(WindowSizeClass.fromWidth(840), WindowSizeClass.expanded);
    // Telefon quer: breit, aber niedrig – höchstens medium.
    expect(
      WindowSizeClass.fromSize(const Size(915, 412)),
      WindowSizeClass.medium,
    );
    expect(
      WindowSizeClass.fromSize(const Size(1280, 800)),
      WindowSizeClass.expanded,
    );
    expect(WindowSizeClass.fromWidth(1366), WindowSizeClass.expanded);
  });

  group('Hauptnavigation', () {
    Widget shell() => MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => AdaptiveNavigationScaffold(
          destinations: const [
            AdaptiveDestination(Icons.home_outlined, Icons.home, 'Übersicht'),
            AdaptiveDestination(
              Icons.receipt_outlined,
              Icons.receipt,
              'Belege',
            ),
          ],
          selectedIndex: 0,
          onSelected: (_) {},
          body: const Text('Inhalt'),
        ),
      ),
    );

    testWidgets('Telefon hochkant: NavigationBar', (tester) async {
      await setSize(tester, const Size(390, 844));
      await tester.pumpWidget(shell());
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('Tablet hochkant (medium): NavigationRail', (tester) async {
      await setSize(tester, const Size(768, 1024));
      await tester.pumpWidget(shell());
      expect(find.byType(NavigationBar), findsNothing);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isFalse);
    });

    testWidgets('Tablet quer (expanded): ausgeklappte Rail', (tester) async {
      await setSize(tester, const Size(1194, 834));
      await tester.pumpWidget(shell());
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isTrue);
      expect(find.text('Belege'), findsOneWidget);
    });

    testWidgets('Telefon quer (medium): Rail, kein Überlauf', (tester) async {
      await setSize(tester, const Size(844, 390));
      await tester.pumpWidget(shell());
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Liste-Detail', () {
    Widget app() => MaterialApp(
      home: ListDetail(
        placeholder: 'Wähle links etwas aus.',
        list: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  final result = await ListDetail.open<bool>(
                    context,
                    (detail) => Scaffold(
                      appBar: AppBar(title: const Text('Detail')),
                      body: TextButton(
                        onPressed: () => Navigator.of(detail).pop(true),
                        child: const Text('Speichern'),
                      ),
                    ),
                  );
                  if (result == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Gespeichert')),
                    );
                  }
                },
                child: const Text('Öffnen'),
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('expanded: Detail rechts neben der Liste', (tester) async {
      await setSize(tester, const Size(1194, 834));
      await tester.pumpWidget(app());
      expect(find.text('Wähle links etwas aus.'), findsOneWidget);
      await tester.tap(find.text('Öffnen'));
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsOneWidget);
      expect(
        find.text('Öffnen'),
        findsOneWidget,
        reason: 'Liste bleibt sichtbar',
      );
      expect(
        tester.getTopLeft(find.text('Speichern')).dx,
        greaterThan(tester.getTopLeft(find.text('Öffnen')).dx),
      );
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(find.text('Gespeichert'), findsWidgets);
      expect(find.text('Wähle links etwas aus.'), findsOneWidget);
    });

    testWidgets('compact: Detail als eigene Seite', (tester) async {
      await setSize(tester, const Size(390, 844));
      await tester.pumpWidget(app());
      expect(find.text('Wähle links etwas aus.'), findsNothing);
      await tester.tap(find.text('Öffnen'));
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsOneWidget);
      expect(find.text('Öffnen'), findsNothing, reason: 'Liste verdeckt');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(find.text('Gespeichert'), findsOneWidget);
    });

    testWidgets('medium (Tablet hochkant): Detail als eigene Seite', (
      tester,
    ) async {
      await setSize(tester, const Size(768, 1024));
      await tester.pumpWidget(app());
      await tester.tap(find.text('Öffnen'));
      await tester.pumpAndSettle();
      expect(find.text('Öffnen'), findsNothing);
    });
  });

  testWidgets('Formulare sind auf großen Breiten begrenzt', (tester) async {
    await setSize(tester, const Size(1194, 834));
    await tester.pumpWidget(
      const MaterialApp(
        home: ReadableWidth(child: SizedBox.expand(key: Key('inhalt'))),
      ),
    );
    expect(
      tester.getSize(find.byKey(const Key('inhalt'))).width,
      WindowSizeClass.maxContentWidth,
    );
  });
}
