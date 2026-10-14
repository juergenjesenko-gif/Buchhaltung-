import 'package:buchhaltung/features/receipts/receipt_save_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Speicherleiste mit Vollständigkeitsbestätigung (FA-2.14, L-2.16).
void main() {
  Future<void> setSize(WidgetTester tester, Size logical) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = logical * 2;
    addTearDown(tester.view.reset);
  }

  Widget app({
    int pages = 2,
    bool newPages = true,
    bool editing = false,
    VoidCallback? onSave,
    VoidCallback? onAddPage,
    EdgeInsets viewInsets = EdgeInsets.zero,
  }) => MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(viewInsets: viewInsets),
        child: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: ReceiptSaveBar(
            totalPages: pages,
            hasNewPages: newPages,
            editing: editing,
            saving: false,
            onSave: onSave ?? () {},
            onAddPage: onAddPage,
          ),
        ),
      ),
    ),
  );

  final save = find.byKey(const ValueKey('receipt-save'));

  testWidgets('neue Seiten: ein Knopf bestätigt und speichert', (tester) async {
    await setSize(tester, const Size(390, 844));
    var saved = 0;
    await tester.pumpWidget(app(onSave: () => saved++));
    expect(find.text('Vollständig – Beleg speichern (2 Seiten)'), findsOne);
    expect(find.textContaining('Mit Speichern bestätigst du'), findsOne);
    expect(find.byType(Checkbox), findsNothing);
    await tester.tap(save);
    expect(saved, 1);
  });

  testWidgets('Telefon: volle Breite, mindestens 48 dp hoch', (tester) async {
    await setSize(tester, const Size(390, 844));
    await tester.pumpWidget(app());
    final size = tester.getSize(save);
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.width, greaterThan(390 - 2 * 16 - 1));
  });

  testWidgets('Tablet: rechtsbündig', (tester) async {
    await setSize(tester, const Size(1024, 768));
    await tester.pumpWidget(app());
    final rect = tester.getRect(save);
    expect(rect.right, closeTo(1024 - 16, 0.5));
    expect(rect.left, greaterThan(1024 / 2));
  });

  testWidgets('eine Seite: sekundärer Knopf für die Rückseite links', (
    tester,
  ) async {
    await setSize(tester, const Size(390, 844));
    var added = 0;
    await tester.pumpWidget(app(pages: 1, onAddPage: () => added++));
    expect(find.text('Vollständig – Beleg speichern (1 Seite)'), findsOne);
    final back = find.byKey(const ValueKey('receipt-add-back'));
    expect(tester.getRect(back).right, lessThan(tester.getRect(save).left));
    expect(tester.getSize(back).height, greaterThanOrEqualTo(48));
    await tester.tap(back);
    expect(added, 1);
  });

  testWidgets('ohne neue Seiten: gewohntes Speichern ohne Bestätigung', (
    tester,
  ) async {
    await setSize(tester, const Size(390, 844));
    await tester.pumpWidget(app(newPages: false, editing: true));
    expect(find.text('Änderungen speichern'), findsOne);
    expect(find.textContaining('Mit Speichern bestätigst du'), findsNothing);
    expect(find.byKey(const ValueKey('receipt-add-back')), findsNothing);
  });

  testWidgets('Tastatur verdeckt den Knopf nicht', (tester) async {
    await setSize(tester, const Size(390, 844));
    const keyboard = 300.0;
    await tester.pumpWidget(
      app(viewInsets: const EdgeInsets.only(bottom: keyboard)),
    );
    expect(tester.getRect(save).bottom, lessThanOrEqualTo(844 - keyboard));
    expect(tester.takeException(), isNull);
  });
}
