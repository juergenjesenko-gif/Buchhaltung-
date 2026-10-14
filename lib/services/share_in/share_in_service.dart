import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Teilen-Ziel (L-27.4): Andere Apps (Galerie, Mail, Browser, Banking)
/// teilen Bilder, PDF oder XML an die App; daraus wird direkt ein
/// Buchungsvorschlag. Android: `ShareInChannel.kt` kopiert die geteilten
/// Inhalte in den App-Cache und meldet die Pfade. Nichts verlässt das Gerät.
class ShareInService {
  ShareInService._() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shared') _poke.add(null);
    });
  }

  static final instance = ShareInService._();

  static const _channel = MethodChannel('buchhaltung/share_in');
  final _poke = StreamController<void>.broadcast();

  /// Meldet, dass neue geteilte Dateien bereitliegen ([take] holt sie).
  Stream<void> get onShared => _poke.stream;

  /// Holt die wartenden Dateien und leert die Warteschlange.
  Future<List<File>> take() async {
    try {
      final paths =
          await _channel.invokeListMethod<String>('takePending') ?? const [];
      return [for (final p in paths) File(p)];
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }
}

/// Art einer geteilten Datei nach Endung bzw. Inhalt.
enum SharedKind { image, pdf, xml, other }

SharedKind sharedKindOf(String path) {
  final lower = path.toLowerCase();
  if (RegExp(r'\.(jpe?g|png|webp|heic|heif)$').hasMatch(lower)) {
    return SharedKind.image;
  }
  if (lower.endsWith('.pdf')) return SharedKind.pdf;
  if (lower.endsWith('.xml')) return SharedKind.xml;
  return SharedKind.other;
}
