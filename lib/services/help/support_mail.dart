import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Support-Kontakt der Hilfe Stufe 1 (FA-11.3). Die App öffnet nur die
/// Mail-App mit Empfänger und Betreff; sie hängt keine Daten an und sendet
/// nichts selbst.
const supportAddress = 'office@jenibarb.com';

/// Betreff mit App-Version, damit der Support weiß, welcher Stand gemeint ist.
String supportSubject(String? appVersion, String question) {
  final v = (appVersion == null || appVersion.isEmpty) ? '?' : appVersion;
  final q = question.trim();
  return 'Frage zur Buchhaltungs-App (Version $v)${q.isEmpty ? '' : ': $q'}';
}

/// `mailto:`-Adresse; Leerzeichen als %20, nicht als „+“ (RFC 6068).
Uri supportMailUri(String subject) => Uri(
  scheme: 'mailto',
  path: supportAddress,
  query: 'subject=${Uri.encodeComponent(subject)}',
);

/// Plattformkanal `buchhaltung/launcher` (Android `LauncherChannel.kt`,
/// iOS `AppDelegate.swift`).
class SupportMailLauncher {
  const SupportMailLauncher();

  static const _channel = MethodChannel('buchhaltung/launcher');

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Versionsname aus dem installierten Paket, `null` wenn nicht ermittelbar.
  Future<String?> appVersion() async {
    if (!_supported) return null;
    try {
      return await _channel.invokeMethod<String>('appVersion');
    } on Exception {
      return null;
    }
  }

  /// `true`, wenn eine Mail-App geöffnet wurde.
  Future<bool> openMail(Uri uri) async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>('openMail', uri.toString()) ??
          false;
    } on Exception {
      return false;
    }
  }
}
