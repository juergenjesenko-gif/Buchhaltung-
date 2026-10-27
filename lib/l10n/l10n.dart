import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// Zugriff auf die Übersetzungen (L-34.1).
///
/// Fehlt der Delegate – etwa in Widget-Tests mit eigenem `MaterialApp` –,
/// gilt Deutsch. So bleibt jeder Bildschirm ohne Sonderaufbau testbar.
extension L10nContext on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      lookupAppLocalizations(const Locale('de'));
}
