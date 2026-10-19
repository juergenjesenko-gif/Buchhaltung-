import 'package:buchhaltung/widgets/scroll_auto_hide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Aufnahmeleiste der Übersicht (Rückmeldung zu 0.30.0): beim Scrollen weg,
/// nach 5 s ohne Scrollen wieder da, ganz oben sofort; nie während eines
/// Tipps; mit Bedienungshilfe immer sichtbar.
void main() {
  Future<(ScrollHideController, List<int>)> pump(
    WidgetTester tester, {
    bool a11y = false,
  }) async {
    final controller = ScrollHideController();
    addTearDown(controller.dispose);
    final taps = <int>[];
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(360, 740),
            accessibleNavigation: a11y,
          ),
          child: Scaffold(
            body: NotificationListener<ScrollNotification>(
              onNotification: controller.handle,
              child: ListView(
                key: const Key('list'),
                children: [
                  for (var i = 0; i < 60; i++)
                    SizedBox(height: 60, child: Text('Zeile $i')),
                ],
              ),
            ),
            floatingActionButton: ScrollHidingBar(
              controller: controller,
              child: SizedBox(
                width: 200,
                height: 56,
                child: FilledButton(
                  key: const Key('bar'),
                  onPressed: () => taps.add(1),
                  child: const Text('Foto'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return (controller, taps);
  }

  testWidgets('Scrollen blendet aus, nach 5 s wieder ein', (tester) async {
    final (c, taps) = await pump(tester);
    expect(c.visible, isTrue);
    await tester.drag(find.byKey(const Key('list')), const Offset(0, -300));
    await tester.pump();
    expect(c.visible, isFalse);
    await tester.pumpAndSettle();
    // Ausgeblendet nimmt die Leiste keinen Tipp an.
    await tester.tap(find.byKey(const Key('bar')), warnIfMissed: false);
    expect(taps, isEmpty);
    await tester.pump(const Duration(seconds: 4));
    expect(c.visible, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(c.visible, isTrue);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bar')));
    expect(taps, [1]);
  });

  testWidgets('Ganz oben sofort wieder sichtbar', (tester) async {
    final (c, _) = await pump(tester);
    await tester.drag(find.byKey(const Key('list')), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(c.visible, isFalse);
    await tester.drag(find.byKey(const Key('list')), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(c.visible, isTrue);
  });

  testWidgets('Finger auf der Leiste: kein Ausblenden', (tester) async {
    final (c, _) = await pump(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('bar'))),
    );
    await tester.drag(find.byKey(const Key('list')), const Offset(0, -300));
    await tester.pump();
    expect(c.visible, isTrue);
    await gesture.up();
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('Bedienungshilfe: Leiste bleibt sichtbar', (tester) async {
    await pump(tester, a11y: true);
    await tester.drag(find.byKey(const Key('list')), const Offset(0, -300));
    await tester.pumpAndSettle();
    final opacity = tester.widget<AnimatedOpacity>(
      find.byType(AnimatedOpacity),
    );
    expect(opacity.opacity, 1);
    await tester.pump(const Duration(seconds: 6));
  });
}
