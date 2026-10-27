// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get consentTitle => 'Bevor es losgeht';

  @override
  String get consentAccept => 'Akzeptieren und weiter';

  @override
  String get consentConfirm => 'Bestätigen und weiter';

  @override
  String consentWith(String button, String confirmation) {
    return 'Mit „$button“: $confirmation';
  }
}
