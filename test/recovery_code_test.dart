import 'dart:math';

import 'package:buchhaltung/services/backup/backup_crypto.dart';
import 'package:buchhaltung/services/backup/recovery_code_sheet.dart';
import 'package:buchhaltung/features/backup/recovery_code_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Wiederherstellungscode als Druckblatt und Bestätigung (L-22.21, L-22.22).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('de'));

  final code = RecoveryCode.encode(List<int>.generate(32, (i) => i * 7));

  test('Druckblatt ist ein PDF', () async {
    final bytes = await RecoveryCodeSheet.build(
      code: code,
      createdAt: DateTime(2026, 10, 15),
      owner: 'Test',
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('zwei verschiedene Blöcke, immer im gültigen Bereich', () {
    final count = code.split('-').length;
    expect(count, 13);
    for (var seed = 0; seed < 200; seed++) {
      final c = RecoveryCodeChallenge(code, random: Random(seed));
      expect(c.blocks.$1, lessThan(c.blocks.$2));
      expect(c.blocks.$1, greaterThanOrEqualTo(1));
      expect(c.blocks.$2, lessThanOrEqualTo(count));
    }
  });

  test('richtige Blöcke bestätigen, falsche nicht', () {
    final c = RecoveryCodeChallenge(code, random: Random(1));
    final parts = code.split('-');
    final a = parts[c.blocks.$1 - 1];
    final b = parts[c.blocks.$2 - 1];
    expect(c.confirmed(a, b), isTrue);
    expect(c.confirmed(a.toLowerCase(), ' $b '), isTrue);
    expect(c.confirmed(b, a), a == b);
    expect(c.confirmed(a, 'XXXX'), isFalse);
    expect(c.confirmed('', ''), isFalse);
  });

  test('Verwechsler 0/1/8 werden wie beim Wiederherstellen gelesen', () {
    final c = RecoveryCodeChallenge('ABCD-OIBA', random: Random(0));
    expect(c.matches(2, '01ba'), isTrue);
  });

  testWidgets('Einrichten: erst teilen, dann zwei Blöcke, dann weiter', (
    tester,
  ) async {
    bool? result;
    var shared = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => RecoveryCodeSetupScreen(
                    code: code,
                    share: (_) async => shared++,
                  ),
                ),
              );
            },
            child: const Text('los'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('los'));
    await tester.pumpAndSettle();
    // Der Code selbst steht nicht in der App.
    expect(find.textContaining(code.split('-').first), findsNothing);
    final confirm = find.byKey(const Key('recoveryConfirm'));
    expect(tester.widget<ButtonStyleButton>(confirm).onPressed, isNull);
    expect(
      tester.getSize(find.byKey(const Key('recoveryShare'))).height,
      greaterThanOrEqualTo(48),
    );

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('recoveryShare')));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    expect(shared, 1);

    expect(find.byKey(const Key('recoveryBlockA')), findsNothing);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
