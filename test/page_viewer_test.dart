import 'package:buchhaltung/widgets/page_image_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Seiten durchblättern statt einzeln öffnen (Rückmeldung 2026-10-21).
void main() {
  testWidgets('Seitenbetrachter blättert per Wischen und Pfeil', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showPageImageDialog(
              context,
              files: const [null, null, null],
              initialIndex: 1,
            ),
            child: const Text('los'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('los'));
    await tester.pumpAndSettle();
    expect(find.text('Seite 2 von 3'), findsOneWidget);

    await tester.fling(
      find.byKey(const Key('page-viewer')),
      const Offset(-400, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.text('Seite 3 von 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Vorherige Seite'));
    await tester.pumpAndSettle();
    expect(find.text('Seite 2 von 3'), findsOneWidget);

    await tester.tap(find.text('Schließen'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('page-viewer')), findsNothing);
  });
}
