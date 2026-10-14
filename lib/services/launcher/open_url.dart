import 'package:flutter/services.dart';

/// Öffnet eine https-Adresse im Browser des Systems (L-27.7). Die App selbst
/// zeigt keine Webseiten und kein Login.
Future<bool> openInBrowser(Uri uri) async {
  if (uri.scheme != 'https') return false;
  try {
    return await const MethodChannel(
          'buchhaltung/launcher',
        ).invokeMethod<bool>('openUrl', uri.toString()) ??
        false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}
