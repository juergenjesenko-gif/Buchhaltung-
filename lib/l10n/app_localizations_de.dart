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

  @override
  String get setupDemoFailed => 'Die Demo ließ sich nicht öffnen.';

  @override
  String get setupOpeningRequired =>
      'Bitte angeben – 0, wenn es keinen Umsatz gab';

  @override
  String get setupAmountInvalid => 'Bitte einen Betrag eingeben';

  @override
  String get setupTurnoverNegative => 'Der Umsatz kann nicht negativ sein';

  @override
  String setupLogoFailed(String error) {
    return 'Logo konnte nicht übernommen werden: $error';
  }

  @override
  String get setupStepConsent => 'Bestätigungen';

  @override
  String get setupStepCompany => 'Dein Unternehmen';

  @override
  String get commonNext => 'Weiter';

  @override
  String get setupStepDetails => 'Zusatzdaten';

  @override
  String get setupStepExtras => 'Extras';

  @override
  String get commonDone => 'Fertig';

  @override
  String setupSubscribeTrial(int days) {
    return 'Abo wählen – $days Tage kostenlos';
  }

  @override
  String get setupStepSubscription => 'Abo wählen';

  @override
  String get setupDecideLater => 'Später entscheiden';

  @override
  String setupStepOf(int step, int total) {
    return 'Schritt $step von $total';
  }

  @override
  String get commonBack => 'Zurück';

  @override
  String get setupWelcomeTitle => 'Willkommen bei JeNi bucht';

  @override
  String get setupRestore => 'Sicherung wiederherstellen';

  @override
  String get setupDemo => 'Erst ansehen (Demo)';

  @override
  String get setupStart => 'Los geht\'s';

  @override
  String get setupHelperDevice =>
      'Dieses Gerät ist ein Mithelfer-Gerät (koppeln)';

  @override
  String get setupCountry => 'Land des Unternehmenssitzes';

  @override
  String get setupCompanyName => 'Name oder Firma *';

  @override
  String get setupCompanyNameHint => 'z. B. Max Mustermann e.U.';

  @override
  String get setupCompanyNameRequired =>
      'Bitte gib einen Namen oder eine Firma an';

  @override
  String get setupOwner => 'Inhaber:in';

  @override
  String get setupLegalForm => 'Rechtsform';

  @override
  String get setupStreet => 'Straße und Hausnummer';

  @override
  String get setupPostalCode => 'PLZ';

  @override
  String get setupCity => 'Ort';

  @override
  String get setupTaxation => 'Besteuerung';

  @override
  String get setupSmallBusiness => 'Kleinunternehmer';

  @override
  String get setupStandardTaxation => 'Regelbesteuerung';

  @override
  String setupSmallBusinessHelp(String ref) {
    return 'Rechnungen ohne Umsatzsteuer, mit dem Hinweis nach $ref. Nicht sicher? Lass es so – du kannst es in den Stammdaten ändern.';
  }

  @override
  String get setupStandardTaxationHelp =>
      'Umsatzsteuer wird ausgewiesen, Vorsteuer ist abziehbar.';

  @override
  String get setupFoundingYear => 'Gründungsjahr';

  @override
  String get setupFoundingYearHelp =>
      'Im Jahr der Gründung gelten eigene Regeln für die Umsatzgrenze.';

  @override
  String setupYearMax(int year) {
    return 'Bitte ein Jahr bis $year eingeben';
  }

  @override
  String get setupOpeningTitle => 'Umsatz vor Nutzung der App';

  @override
  String setupOpeningHelp(String date) {
    return 'Für die Kleinunternehmergrenze braucht die App auch die Zeit vor dem $date.';
  }

  @override
  String setupOpeningPrevious(int year) {
    return 'Umsatz $year gesamt *';
  }

  @override
  String setupOpeningCurrent(int year, String date) {
    return 'Umsatz $year vor dem $date';
  }

  @override
  String setupOpeningCurrentHelp(int year) {
    return 'Kannst du leer lassen. Buch dann die Belege seit 1.1.$year nach, damit Umsatz und Grenze stimmen.';
  }

  @override
  String setupDetailsIntro(String taxNumber, String vatId) {
    return 'Alles optional – für Rechnungen brauchst du später $taxNumber oder $vatId.';
  }

  @override
  String get setupRegisterHelp => 'Nur wenn du eingetragen bist';

  @override
  String setupRegisterCourtRequired(String register) {
    return 'Mit $register ist auch das Gericht Pflicht';
  }

  @override
  String get commonEmail => 'E-Mail';

  @override
  String get commonPhone => 'Telefon';

  @override
  String get setupIban => 'IBAN (für Rechnungen)';

  @override
  String get setupBank => 'Bank';

  @override
  String get setupExtrasIntro =>
      'Jedes davon kannst du überspringen und später in den Einstellungen nachholen.';

  @override
  String get setupLogoChoose => 'Logo wählen';

  @override
  String get setupLogoChange => 'Logo ändern';

  @override
  String get setupLogoHelp =>
      'Erscheint oben rechts auf Rechnungen und Angeboten.';

  @override
  String get setupBackup => 'Datensicherung einrichten';

  @override
  String get setupBackupHelp =>
      'Automatisch sichern und Wiederherstellungscode notieren – falls das Handy verloren geht.';

  @override
  String get setupMoreCountries => 'Weitere Länder';

  @override
  String get setupMoreCountriesHelp =>
      'Nur nötig bei Registrierung im Ausland, z. B. Amazon-Lager oder EU-Kleinunternehmer-Verfahren.';

  @override
  String setupTrialText(int days) {
    return '$days Tage kostenlos testen – mit allen Pro-Funktionen. Danach gilt dein gewähltes Abo (Preis aus dem Store). Jederzeit vorher im Store kündbar.';
  }

  @override
  String setupTrialTitle(int days) {
    return '$days Tage kostenlos testen';
  }

  @override
  String get setupNoPlan =>
      'Ohne Abo bleiben deine Angaben gespeichert; Buchen geht erst mit Abo.';

  @override
  String get setupLater => 'Später hinzufügen';

  @override
  String get setupWelcomeSubline =>
      'Rechnungswesen und Buchhaltung leicht gemacht. Ohne Vorwissen, nach den Regeln, die auch Profis anwenden.';

  @override
  String get setupPointReceipts => 'Belege scannen und auslesen';

  @override
  String get setupPointInvoices => 'Rechnungen & E-Rechnungen schreiben';

  @override
  String get setupPointContracts => 'Verträge und Fristen im Blick';

  @override
  String get setupPointReports => 'Saldenliste und Jahresübersicht';

  @override
  String setupRegistrationsCount(int count, String list) {
    return '$count angelegt: $list';
  }
}
