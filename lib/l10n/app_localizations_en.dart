// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get consentTitle => 'Before you start';

  @override
  String get consentAccept => 'Accept and continue';

  @override
  String get consentConfirm => 'Confirm and continue';

  @override
  String consentWith(String button, String confirmation) {
    return 'By tapping “$button”: $confirmation';
  }

  @override
  String get setupDemoFailed => 'The demo could not be opened.';

  @override
  String get setupOpeningRequired =>
      'Please enter an amount – 0 if there was no turnover';

  @override
  String get setupAmountInvalid => 'Please enter an amount';

  @override
  String get setupTurnoverNegative => 'Turnover cannot be negative';

  @override
  String setupLogoFailed(String error) {
    return 'The logo could not be added: $error';
  }

  @override
  String get setupStepConsent => 'Confirmations';

  @override
  String get setupStepCompany => 'Your business';

  @override
  String get commonNext => 'Next';

  @override
  String get setupStepDetails => 'More details';

  @override
  String get setupStepExtras => 'Extras';

  @override
  String get commonDone => 'Done';

  @override
  String setupSubscribeTrial(int days) {
    return 'Choose a plan – $days days free';
  }

  @override
  String get setupStepSubscription => 'Choose a plan';

  @override
  String get setupDecideLater => 'Decide later';

  @override
  String setupStepOf(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get commonBack => 'Back';

  @override
  String get setupWelcomeTitle => 'Welcome to JeNi books';

  @override
  String get setupRestore => 'Restore a backup';

  @override
  String get setupDemo => 'Look around first (demo)';

  @override
  String get setupStart => 'Let\'s go';

  @override
  String get setupHelperDevice => 'This is a helper device (pair it)';

  @override
  String get setupCountry => 'Country of your business';

  @override
  String get setupCompanyName => 'Name or business name *';

  @override
  String get setupCompanyNameHint => 'e.g. Jane Smith Design';

  @override
  String get setupCompanyNameRequired => 'Please enter a name or business name';

  @override
  String get setupOwner => 'Owner';

  @override
  String get setupLegalForm => 'Legal form';

  @override
  String get setupStreet => 'Street and number';

  @override
  String get setupPostalCode => 'Postcode';

  @override
  String get setupCity => 'Town or city';

  @override
  String get setupTaxation => 'Tax status';

  @override
  String get setupSmallBusiness => 'Not VAT-registered';

  @override
  String get setupStandardTaxation => 'VAT-registered';

  @override
  String setupSmallBusinessHelp(String ref) {
    return 'Invoices without VAT, with the note under $ref. Not sure? Leave it – you can change it later in your business details.';
  }

  @override
  String get setupStandardTaxationHelp =>
      'VAT is shown on invoices, input VAT can be reclaimed.';

  @override
  String get setupFoundingYear => 'Year you started';

  @override
  String get setupFoundingYearHelp =>
      'Special rules apply to the turnover threshold in your first year.';

  @override
  String setupYearMax(int year) {
    return 'Please enter a year up to $year';
  }

  @override
  String get setupOpeningTitle => 'Turnover before using the app';

  @override
  String setupOpeningHelp(String date) {
    return 'For the turnover threshold the app also needs the time before $date.';
  }

  @override
  String setupOpeningPrevious(int year) {
    return 'Total turnover $year *';
  }

  @override
  String setupOpeningCurrent(int year, String date) {
    return 'Turnover $year before $date';
  }

  @override
  String setupOpeningCurrentHelp(int year) {
    return 'You can leave this empty. Then add your receipts since 1 January $year so turnover and threshold are right.';
  }

  @override
  String setupDetailsIntro(String taxNumber, String vatId) {
    return 'All optional – for invoices you will later need your $taxNumber or $vatId.';
  }

  @override
  String get setupRegisterHelp => 'Only if you are registered';

  @override
  String setupRegisterCourtRequired(String register) {
    return 'With a $register, the court is required too';
  }

  @override
  String get commonEmail => 'Email';

  @override
  String get commonPhone => 'Phone';

  @override
  String get setupIban => 'IBAN (for invoices)';

  @override
  String get setupBank => 'Bank';

  @override
  String get setupExtrasIntro =>
      'You can skip any of these and do it later in Settings.';

  @override
  String get setupLogoChoose => 'Choose logo';

  @override
  String get setupLogoChange => 'Change logo';

  @override
  String get setupLogoHelp => 'Shown top right on invoices and quotes.';

  @override
  String get setupBackup => 'Set up backup';

  @override
  String get setupBackupHelp =>
      'Back up automatically and note your recovery code – in case you lose your phone.';

  @override
  String get setupMoreCountries => 'Other countries';

  @override
  String get setupMoreCountriesHelp =>
      'Only needed if you are registered abroad, e.g. for an Amazon warehouse.';

  @override
  String setupTrialText(int days) {
    return 'Try free for $days days – with all Pro features. After that your chosen plan applies (price shown in the store). Cancel any time before in the store.';
  }

  @override
  String setupTrialTitle(int days) {
    return 'Try free for $days days';
  }

  @override
  String get setupNoPlan =>
      'Without a plan your details stay saved; booking needs a plan.';

  @override
  String get setupLater => 'Add later';

  @override
  String get setupWelcomeSubline =>
      'Bookkeeping made easy. No prior knowledge needed, following the rules the professionals use.';

  @override
  String get setupPointReceipts => 'Scan and read receipts';

  @override
  String get setupPointInvoices => 'Write invoices & e-invoices';

  @override
  String get setupPointContracts => 'Keep track of contracts and deadlines';

  @override
  String get setupPointReports => 'Account balances and year overview';

  @override
  String setupRegistrationsCount(int count, String list) {
    return '$count added: $list';
  }
}
