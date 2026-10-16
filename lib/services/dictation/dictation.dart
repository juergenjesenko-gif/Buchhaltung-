import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Ereignis einer Spracheingabe.
sealed class DictationEvent {
  const DictationEvent();
}

/// Zwischenstand, während gesprochen wird.
class DictationPartial extends DictationEvent {
  const DictationPartial(this.text);
  final String text;
}

/// Endergebnis; danach ist die Aufnahme beendet.
class DictationFinal extends DictationEvent {
  const DictationFinal(this.text);
  final String text;
}

/// Abbruch mit Grund (`permission`, `no_match`, `busy`, `unavailable`, …).
class DictationError extends DictationEvent {
  const DictationError(this.code);
  final String code;
}

/// Spracheingabe **nur auf dem Gerät** (FA-2.61, Lastenheft 5.19): Android
/// `SpeechRecognizer.createOnDeviceSpeechRecognizer` (ab Android 12), iOS
/// `SFSpeechRecognizer` mit `requiresOnDeviceRecognition`. Eigener schmaler
/// Channel, kein Paket. Gibt es keine Erkennung auf dem Gerät, ist
/// [isAvailable] `false` und kein Mikrofonknopf erscheint – es gibt
/// bewusst keinen Rückfall auf eine Erkennung im Netz.
class Dictation {
  Dictation._(this._channel) {
    _channel.setMethodCallHandler(_onNative);
  }

  static final Dictation instance = Dictation._(
    const MethodChannel('buchhaltung/dictation'),
  );

  final MethodChannel _channel;
  final Map<String, Future<bool>> _available = {};
  StreamController<DictationEvent>? _session;

  @visibleForTesting
  void resetForTest() {
    _available.clear();
    _session?.close();
    _session = null;
  }

  /// Läuft gerade eine Aufnahme?
  bool get isListening => _session != null;

  /// Erkennung auf dem Gerät für [locale] vorhanden? Einmal je Sprache
  /// gefragt und gemerkt.
  Future<bool> isAvailable(String locale) =>
      _available.putIfAbsent(locale, () async {
        try {
          return await _channel.invokeMethod<bool>('isAvailable', {
                'locale': locale,
              }) ??
              false;
        } on PlatformException {
          return false;
        } on MissingPluginException {
          return false;
        }
      });

  /// Startet die Aufnahme. Der Stream endet nach [DictationFinal] oder
  /// [DictationError]. Läuft schon eine, wird sie zuerst beendet.
  Stream<DictationEvent> listen(String locale) {
    _finish(const DictationError('replaced'));
    final controller = StreamController<DictationEvent>();
    _session = controller;
    () async {
      try {
        await _channel.invokeMethod<void>('start', {'locale': locale});
      } on PlatformException catch (e) {
        if (identical(_session, controller)) _finish(DictationError(e.code));
      } on MissingPluginException {
        if (identical(_session, controller)) {
          _finish(const DictationError('unavailable'));
        }
      }
    }();
    return controller.stream;
  }

  /// Beendet die Aufnahme; das Endergebnis kommt noch als [DictationFinal].
  Future<void> stop() async {
    if (_session == null) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException {
      _finish(const DictationError('stop_failed'));
    } on MissingPluginException {
      _finish(const DictationError('unavailable'));
    }
  }

  void _finish(DictationEvent event) {
    final s = _session;
    if (s == null) return;
    _session = null;
    s.add(event);
    s.close();
  }

  Future<Object?> _onNative(MethodCall call) async {
    final args = (call.arguments as Map?)?.cast<String, Object?>() ?? const {};
    final text = args['text'] as String? ?? '';
    switch (call.method) {
      case 'onPartial':
        _session?.add(DictationPartial(text));
      case 'onFinal':
        _finish(DictationFinal(text));
      case 'onError':
        _finish(DictationError(args['code'] as String? ?? 'error'));
    }
    return null;
  }
}
