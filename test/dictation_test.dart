import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/services/dictation/dictation.dart';
import 'package:buchhaltung/widgets/common.dart';
import 'package:buchhaltung/widgets/dictation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Diktat auf dem Gerät (FA-2.61) mit Fake-Channel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('buchhaltung/dictation');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <String>[];

  setUpAll(() => initializeDateFormatting('de'));

  void fake({bool available = true}) {
    calls.clear();
    Dictation.instance.resetForTest();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'isAvailable') return available;
      return null;
    });
  }

  Future<void> native(String method, Map<String, Object?> args) async {
    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
      (_) {},
    );
  }

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    Dictation.instance.resetForTest();
  });

  Widget app(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('ohne Erkennung auf dem Gerät: kein Mikrofon', (tester) async {
    fake(available: false);
    final c = TextEditingController();
    await tester.pumpWidget(
      app(
        TextField(
          decoration: InputDecoration(
            suffixIcon: DictationButton(controller: c),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('dictation-mic')), findsNothing);
  });

  testWidgets('Freitext: live Zwischentext, Ergebnis angehängt', (
    tester,
  ) async {
    fake();
    final c = TextEditingController(text: 'Kaffee');
    await tester.pumpWidget(
      app(
        TextField(
          controller: c,
          decoration: InputDecoration(
            suffixIcon: DictationButton(controller: c),
          ),
        ),
      ),
    );
    await tester.pump();
    final mic = find.byKey(const Key('dictation-mic'));
    expect(tester.getSize(mic).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(mic).height, greaterThanOrEqualTo(48));
    await tester.tap(mic);
    await tester.pump();
    expect(calls, contains('start'));
    await native('onPartial', {'text': 'mit Kunden'});
    await tester.pump();
    expect(c.text, 'Kaffee mit Kunden');
    await native('onPartial', {'text': 'mit Kundin Huber'});
    await tester.pump();
    expect(c.text, 'Kaffee mit Kundin Huber');
    await native('onFinal', {'text': 'mit Kundin Huber'});
    await tester.pump();
    expect(c.text, 'Kaffee mit Kundin Huber');
    expect(Dictation.instance.isListening, isFalse);
  });

  testWidgets('Tippen während der Aufnahme beendet sie', (tester) async {
    fake();
    final c = TextEditingController();
    await tester.pumpWidget(app(DictationButton(controller: c)));
    await tester.pump();
    await tester.tap(find.byKey(const Key('dictation-mic')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('dictation-mic')));
    await tester.pump();
    expect(calls, containsAllInOrder(['start', 'stop']));
  });

  testWidgets('Fehler stellt den alten Text wieder her', (tester) async {
    fake();
    final c = TextEditingController(text: 'alt');
    await tester.pumpWidget(app(DictationButton(controller: c)));
    await tester.pump();
    await tester.tap(find.byKey(const Key('dictation-mic')));
    await tester.pump();
    await native('onPartial', {'text': 'irgendwas'});
    await native('onError', {'code': 'no_match'});
    await tester.pump();
    expect(c.text, 'alt');
    expect(Dictation.instance.isListening, isFalse);
  });

  testWidgets('Betrag: „zwölf Euro fünfzig“ wird Vorschlag 12,50', (
    tester,
  ) async {
    fake();
    final c = TextEditingController();
    Money? changed;
    await tester.pumpWidget(
      app(
        MoneyField(
          controller: c,
          label: 'Bruttobetrag',
          onChanged: (m) => changed = m,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('dictation-mic')));
    await tester.pump();
    await native('onPartial', {'text': 'zwölf Euro'});
    await tester.pump();
    expect(find.text('zwölf Euro'), findsOneWidget);
    expect(c.text, isEmpty);
    await native('onFinal', {'text': 'zwölf Euro fünfzig'});
    await tester.pump();
    expect(Money.tryParse(c.text), const Money(1250));
    expect(changed, const Money(1250));
    expect(find.text('Gesprochen – bitte prüfen'), findsOneWidget);
  });

  testWidgets('Betrag nicht verstanden: Feld bleibt, Hinweis', (tester) async {
    fake();
    final c = TextEditingController(text: '3,00');
    await tester.pumpWidget(app(MoneyField(controller: c, label: 'Betrag')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('dictation-mic')));
    await tester.pump();
    await native('onFinal', {'text': 'hallo'});
    await tester.pump();
    expect(c.text, '3,00');
    expect(find.textContaining('nicht als Betrag verstanden'), findsOneWidget);
  });
}
