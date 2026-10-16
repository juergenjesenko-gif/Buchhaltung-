import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/formatting.dart';
import '../domain/country.dart';
import '../domain/money.dart';
import '../services/dictation/dictation.dart';
import '../services/dictation/spoken_amount.dart';

/// Mikrofonknopf als Suffix eines Textfelds (FA-2.61): Tippen startet,
/// erneutes Tippen oder eine Sprechpause beendet. Zwischentext erscheint
/// live über [onPartial]; das Ergebnis über [onFinal]. Nur sichtbar, wenn
/// die Erkennung auf dem Gerät läuft – sonst bleibt das Diktat der Tastatur.
/// Zielfläche 48 × 48 dp (DESIGN_SPEC 5a, Regel 2).
class DictationButton extends StatefulWidget {
  const DictationButton({
    super.key,
    required this.controller,
    this.amount = false,
    this.onHeard,
    this.onAmount,
    this.dictation,
  });

  /// Feld, in das diktiert wird. Freitext: Gesprochenes wird angehängt,
  /// Zwischentext steht live im Feld. Betrag ([amount]): das Feld erhält
  /// den erkannten Betrag als Vorschlag, die Nutzerin bestätigt beim
  /// Speichern.
  final TextEditingController controller;
  final bool amount;

  /// Betrag: gehörter Text (live) bzw. `null` nach dem Ende.
  final ValueChanged<String?>? onHeard;

  /// Betrag erkannt und ins Feld übernommen.
  final ValueChanged<Money>? onAmount;
  final Dictation? dictation;

  @override
  State<DictationButton> createState() => _DictationButtonState();
}

class _DictationButtonState extends State<DictationButton> {
  bool _available = false;
  bool _listening = false;
  String? _base;
  StreamSubscription<DictationEvent>? _sub;

  Dictation get _dictation => widget.dictation ?? Dictation.instance;

  String get _locale {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    return scope?.notifier?.profile?.taxProfile.speechLocale ??
        TaxProfile.austria.speechLocale;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dictation.isAvailable(_locale).then((ok) {
      if (mounted && ok != _available) setState(() => _available = ok);
    });
  }

  @override
  void dispose() {
    if (_listening) _dictation.stop();
    _sub?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_listening) {
      _dictation.stop();
      return;
    }
    setState(() => _listening = true);
    _base = widget.controller.text;
    _sub?.cancel();
    _sub = _dictation
        .listen(_locale)
        .listen(
          (event) {
            switch (event) {
              case DictationPartial(:final text):
                _partial(text);
              case DictationFinal(:final text):
                _final(text);
              case DictationError(:final code):
                _restore();
                if (mounted && code == 'permission') {
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Ohne Mikrofon-Erlaubnis kein Diktat – bitte in den '
                        'Einstellungen des Telefons erlauben.',
                      ),
                    ),
                  );
                }
            }
          },
          onDone: () {
            if (mounted) setState(() => _listening = false);
          },
        );
  }

  void _show(String text) {
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  String _join(String spoken) {
    final base = _base ?? '';
    if (spoken.isEmpty) return base;
    return base.trim().isEmpty ? spoken : '${base.trimRight()} $spoken';
  }

  void _partial(String text) {
    if (widget.amount) {
      widget.onHeard?.call(text);
    } else {
      _show(_join(text));
    }
  }

  void _final(String text) {
    if (!widget.amount) {
      _show(_join(text));
      _base = null;
      return;
    }
    final money = SpokenAmount.parse(text);
    _base = null;
    if (money == null) {
      widget.onHeard?.call(
        text.isEmpty
            ? 'Nichts verstanden'
            : '„$text“ nicht als Betrag verstanden',
      );
      return;
    }
    _show(Fmt.amount(money));
    widget.onHeard?.call(null);
    widget.onAmount?.call(money);
  }

  void _restore() {
    if (!widget.amount && _base != null) _show(_base!);
    _base = null;
    widget.onHeard?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      key: const Key('dictation-mic'),
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      tooltip: _listening ? 'Diktat beenden' : 'Diktieren',
      isSelected: _listening,
      color: _listening ? scheme.error : null,
      icon: Icon(_listening ? Icons.stop_circle_outlined : Icons.mic_none),
      onPressed: _toggle,
    );
  }
}
