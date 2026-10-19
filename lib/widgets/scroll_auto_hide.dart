import 'dart:async';

import 'package:flutter/material.dart';

/// Blendet eine schwebende Leiste beim Scrollen aus und nach
/// [showAfter] ohne Scrollen wieder ein (Rückmeldung Auftraggeber zu 0.30.0,
/// Übersicht). Ganz oben ist sie sofort wieder da. Solange ein Finger auf
/// der Leiste liegt, bleibt sie stehen – ein begonnener Tipp geht nie ins
/// Leere.
class ScrollHideController extends ValueNotifier<bool> {
  ScrollHideController({this.showAfter = defaultShowAfter}) : super(true);

  /// Wartezeit bis zum Wiedereinblenden (`spec.capture_bar_show_after_s`).
  static const defaultShowAfter = Duration(seconds: 5);

  final Duration showAfter;
  Timer? _timer;
  int _pointers = 0;

  bool get visible => value;

  /// Für `NotificationListener<ScrollNotification>`; gibt `false` zurück,
  /// damit die Meldung weiterläuft (RefreshIndicator).
  bool handle(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    if (n.metrics.pixels <= n.metrics.minScrollExtent) {
      _show();
      return false;
    }
    if (n is ScrollUpdateNotification && (n.scrollDelta ?? 0) != 0) {
      if (_pointers == 0) value = false;
      _timer?.cancel();
      _timer = Timer(showAfter, _show);
    }
    return false;
  }

  void pointerDown() => _pointers++;

  void pointerUp() {
    if (_pointers > 0) _pointers--;
  }

  void _show() {
    _timer?.cancel();
    _timer = null;
    value = true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Leiste, die [controller] folgt: gleitet nach unten aus und blendet aus.
/// Ausgeblendet nimmt sie keine Tipps an und ist für Screenreader weg; mit
/// eingeschalteter Bedienungshilfe (TalkBack/VoiceOver) bleibt sie immer
/// sichtbar.
class ScrollHidingBar extends StatelessWidget {
  const ScrollHidingBar({
    super.key,
    required this.controller,
    required this.child,
  });

  final ScrollHideController controller;
  final Widget child;

  static const duration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final a11y = MediaQuery.maybeAccessibleNavigationOf(context) ?? false;
    return ValueListenableBuilder<bool>(
      valueListenable: controller,
      builder: (context, visible, _) {
        final shown = visible || a11y;
        return Listener(
          onPointerDown: (_) => controller.pointerDown(),
          onPointerUp: (_) => controller.pointerUp(),
          onPointerCancel: (_) => controller.pointerUp(),
          child: AnimatedSlide(
            duration: duration,
            offset: shown ? Offset.zero : const Offset(0, 1.5),
            child: AnimatedOpacity(
              duration: duration,
              opacity: shown ? 1 : 0,
              child: IgnorePointer(
                ignoring: !shown,
                child: ExcludeSemantics(excluding: !shown, child: child),
              ),
            ),
          ),
        );
      },
    );
  }
}
