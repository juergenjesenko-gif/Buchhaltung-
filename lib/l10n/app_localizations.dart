import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @consentTitle.
  ///
  /// In de, this message translates to:
  /// **'Bevor es losgeht'**
  String get consentTitle;

  /// No description provided for @consentAccept.
  ///
  /// In de, this message translates to:
  /// **'Akzeptieren und weiter'**
  String get consentAccept;

  /// No description provided for @consentConfirm.
  ///
  /// In de, this message translates to:
  /// **'Bestätigen und weiter'**
  String get consentConfirm;

  /// No description provided for @consentWith.
  ///
  /// In de, this message translates to:
  /// **'Mit „{button}“: {confirmation}'**
  String consentWith(String button, String confirmation);

  /// No description provided for @setupDemoFailed.
  ///
  /// In de, this message translates to:
  /// **'Die Demo ließ sich nicht öffnen.'**
  String get setupDemoFailed;

  /// No description provided for @setupOpeningRequired.
  ///
  /// In de, this message translates to:
  /// **'Bitte angeben – 0, wenn es keinen Umsatz gab'**
  String get setupOpeningRequired;

  /// No description provided for @setupAmountInvalid.
  ///
  /// In de, this message translates to:
  /// **'Bitte einen Betrag eingeben'**
  String get setupAmountInvalid;

  /// No description provided for @setupTurnoverNegative.
  ///
  /// In de, this message translates to:
  /// **'Der Umsatz kann nicht negativ sein'**
  String get setupTurnoverNegative;

  /// No description provided for @setupLogoFailed.
  ///
  /// In de, this message translates to:
  /// **'Logo konnte nicht übernommen werden: {error}'**
  String setupLogoFailed(String error);

  /// No description provided for @setupStepConsent.
  ///
  /// In de, this message translates to:
  /// **'Bestätigungen'**
  String get setupStepConsent;

  /// No description provided for @setupStepCompany.
  ///
  /// In de, this message translates to:
  /// **'Dein Unternehmen'**
  String get setupStepCompany;

  /// No description provided for @commonNext.
  ///
  /// In de, this message translates to:
  /// **'Weiter'**
  String get commonNext;

  /// No description provided for @setupStepDetails.
  ///
  /// In de, this message translates to:
  /// **'Zusatzdaten'**
  String get setupStepDetails;

  /// No description provided for @setupStepExtras.
  ///
  /// In de, this message translates to:
  /// **'Extras'**
  String get setupStepExtras;

  /// No description provided for @commonDone.
  ///
  /// In de, this message translates to:
  /// **'Fertig'**
  String get commonDone;

  /// No description provided for @setupSubscribeTrial.
  ///
  /// In de, this message translates to:
  /// **'Abo wählen – {days} Tage kostenlos'**
  String setupSubscribeTrial(int days);

  /// No description provided for @setupStepSubscription.
  ///
  /// In de, this message translates to:
  /// **'Abo wählen'**
  String get setupStepSubscription;

  /// No description provided for @setupDecideLater.
  ///
  /// In de, this message translates to:
  /// **'Später entscheiden'**
  String get setupDecideLater;

  /// No description provided for @setupStepOf.
  ///
  /// In de, this message translates to:
  /// **'Schritt {step} von {total}'**
  String setupStepOf(int step, int total);

  /// No description provided for @commonBack.
  ///
  /// In de, this message translates to:
  /// **'Zurück'**
  String get commonBack;

  /// No description provided for @setupWelcomeTitle.
  ///
  /// In de, this message translates to:
  /// **'Willkommen bei JeNi bucht'**
  String get setupWelcomeTitle;

  /// No description provided for @setupRestore.
  ///
  /// In de, this message translates to:
  /// **'Sicherung wiederherstellen'**
  String get setupRestore;

  /// No description provided for @setupDemo.
  ///
  /// In de, this message translates to:
  /// **'Erst ansehen (Demo)'**
  String get setupDemo;

  /// No description provided for @setupStart.
  ///
  /// In de, this message translates to:
  /// **'Los geht\'s'**
  String get setupStart;

  /// No description provided for @setupHelperDevice.
  ///
  /// In de, this message translates to:
  /// **'Dieses Gerät ist ein Mithelfer-Gerät (koppeln)'**
  String get setupHelperDevice;

  /// No description provided for @setupCountry.
  ///
  /// In de, this message translates to:
  /// **'Land des Unternehmenssitzes'**
  String get setupCountry;

  /// No description provided for @setupCompanyName.
  ///
  /// In de, this message translates to:
  /// **'Name oder Firma *'**
  String get setupCompanyName;

  /// No description provided for @setupCompanyNameHint.
  ///
  /// In de, this message translates to:
  /// **'z. B. Max Mustermann e.U.'**
  String get setupCompanyNameHint;

  /// No description provided for @setupCompanyNameRequired.
  ///
  /// In de, this message translates to:
  /// **'Bitte gib einen Namen oder eine Firma an'**
  String get setupCompanyNameRequired;

  /// No description provided for @setupOwner.
  ///
  /// In de, this message translates to:
  /// **'Inhaber:in'**
  String get setupOwner;

  /// No description provided for @setupLegalForm.
  ///
  /// In de, this message translates to:
  /// **'Rechtsform'**
  String get setupLegalForm;

  /// No description provided for @setupStreet.
  ///
  /// In de, this message translates to:
  /// **'Straße und Hausnummer'**
  String get setupStreet;

  /// No description provided for @setupPostalCode.
  ///
  /// In de, this message translates to:
  /// **'PLZ'**
  String get setupPostalCode;

  /// No description provided for @setupCity.
  ///
  /// In de, this message translates to:
  /// **'Ort'**
  String get setupCity;

  /// No description provided for @setupTaxation.
  ///
  /// In de, this message translates to:
  /// **'Besteuerung'**
  String get setupTaxation;

  /// No description provided for @setupSmallBusiness.
  ///
  /// In de, this message translates to:
  /// **'Kleinunternehmer'**
  String get setupSmallBusiness;

  /// No description provided for @setupStandardTaxation.
  ///
  /// In de, this message translates to:
  /// **'Regelbesteuerung'**
  String get setupStandardTaxation;

  /// No description provided for @setupSmallBusinessHelp.
  ///
  /// In de, this message translates to:
  /// **'Rechnungen ohne Umsatzsteuer, mit dem Hinweis nach {ref}. Nicht sicher? Lass es so – du kannst es in den Stammdaten ändern.'**
  String setupSmallBusinessHelp(String ref);

  /// No description provided for @setupStandardTaxationHelp.
  ///
  /// In de, this message translates to:
  /// **'Umsatzsteuer wird ausgewiesen, Vorsteuer ist abziehbar.'**
  String get setupStandardTaxationHelp;

  /// No description provided for @setupFoundingYear.
  ///
  /// In de, this message translates to:
  /// **'Gründungsjahr'**
  String get setupFoundingYear;

  /// No description provided for @setupFoundingYearHelp.
  ///
  /// In de, this message translates to:
  /// **'Im Jahr der Gründung gelten eigene Regeln für die Umsatzgrenze.'**
  String get setupFoundingYearHelp;

  /// No description provided for @setupYearMax.
  ///
  /// In de, this message translates to:
  /// **'Bitte ein Jahr bis {year} eingeben'**
  String setupYearMax(int year);

  /// No description provided for @setupOpeningTitle.
  ///
  /// In de, this message translates to:
  /// **'Umsatz vor Nutzung der App'**
  String get setupOpeningTitle;

  /// No description provided for @setupOpeningHelp.
  ///
  /// In de, this message translates to:
  /// **'Für die Kleinunternehmergrenze braucht die App auch die Zeit vor dem {date}.'**
  String setupOpeningHelp(String date);

  /// No description provided for @setupOpeningPrevious.
  ///
  /// In de, this message translates to:
  /// **'Umsatz {year} gesamt *'**
  String setupOpeningPrevious(int year);

  /// No description provided for @setupOpeningCurrent.
  ///
  /// In de, this message translates to:
  /// **'Umsatz {year} vor dem {date}'**
  String setupOpeningCurrent(int year, String date);

  /// No description provided for @setupOpeningCurrentHelp.
  ///
  /// In de, this message translates to:
  /// **'Kannst du leer lassen. Buch dann die Belege seit 1.1.{year} nach, damit Umsatz und Grenze stimmen.'**
  String setupOpeningCurrentHelp(int year);

  /// No description provided for @setupDetailsIntro.
  ///
  /// In de, this message translates to:
  /// **'Alles optional – für Rechnungen brauchst du später {taxNumber} oder {vatId}.'**
  String setupDetailsIntro(String taxNumber, String vatId);

  /// No description provided for @setupRegisterHelp.
  ///
  /// In de, this message translates to:
  /// **'Nur wenn du eingetragen bist'**
  String get setupRegisterHelp;

  /// No description provided for @setupRegisterCourtRequired.
  ///
  /// In de, this message translates to:
  /// **'Mit {register} ist auch das Gericht Pflicht'**
  String setupRegisterCourtRequired(String register);

  /// No description provided for @commonEmail.
  ///
  /// In de, this message translates to:
  /// **'E-Mail'**
  String get commonEmail;

  /// No description provided for @commonPhone.
  ///
  /// In de, this message translates to:
  /// **'Telefon'**
  String get commonPhone;

  /// No description provided for @setupIban.
  ///
  /// In de, this message translates to:
  /// **'IBAN (für Rechnungen)'**
  String get setupIban;

  /// No description provided for @setupBank.
  ///
  /// In de, this message translates to:
  /// **'Bank'**
  String get setupBank;

  /// No description provided for @setupExtrasIntro.
  ///
  /// In de, this message translates to:
  /// **'Jedes davon kannst du überspringen und später in den Einstellungen nachholen.'**
  String get setupExtrasIntro;

  /// No description provided for @setupLogoChoose.
  ///
  /// In de, this message translates to:
  /// **'Logo wählen'**
  String get setupLogoChoose;

  /// No description provided for @setupLogoChange.
  ///
  /// In de, this message translates to:
  /// **'Logo ändern'**
  String get setupLogoChange;

  /// No description provided for @setupLogoHelp.
  ///
  /// In de, this message translates to:
  /// **'Erscheint oben rechts auf Rechnungen und Angeboten.'**
  String get setupLogoHelp;

  /// No description provided for @setupBackup.
  ///
  /// In de, this message translates to:
  /// **'Datensicherung einrichten'**
  String get setupBackup;

  /// No description provided for @setupBackupHelp.
  ///
  /// In de, this message translates to:
  /// **'Automatisch sichern und Wiederherstellungscode notieren – falls das Handy verloren geht.'**
  String get setupBackupHelp;

  /// No description provided for @setupMoreCountries.
  ///
  /// In de, this message translates to:
  /// **'Weitere Länder'**
  String get setupMoreCountries;

  /// No description provided for @setupMoreCountriesHelp.
  ///
  /// In de, this message translates to:
  /// **'Nur nötig bei Registrierung im Ausland, z. B. Amazon-Lager oder EU-Kleinunternehmer-Verfahren.'**
  String get setupMoreCountriesHelp;

  /// No description provided for @setupTrialText.
  ///
  /// In de, this message translates to:
  /// **'{days} Tage kostenlos testen – mit allen Pro-Funktionen. Danach gilt dein gewähltes Abo (Preis aus dem Store). Jederzeit vorher im Store kündbar.'**
  String setupTrialText(int days);

  /// No description provided for @setupTrialTitle.
  ///
  /// In de, this message translates to:
  /// **'{days} Tage kostenlos testen'**
  String setupTrialTitle(int days);

  /// No description provided for @setupNoPlan.
  ///
  /// In de, this message translates to:
  /// **'Ohne Abo bleiben deine Angaben gespeichert; Buchen geht erst mit Abo.'**
  String get setupNoPlan;

  /// No description provided for @setupLater.
  ///
  /// In de, this message translates to:
  /// **'Später hinzufügen'**
  String get setupLater;

  /// No description provided for @setupWelcomeSubline.
  ///
  /// In de, this message translates to:
  /// **'Rechnungswesen und Buchhaltung leicht gemacht. Ohne Vorwissen, nach den Regeln, die auch Profis anwenden.'**
  String get setupWelcomeSubline;

  /// No description provided for @setupPointReceipts.
  ///
  /// In de, this message translates to:
  /// **'Belege scannen und auslesen'**
  String get setupPointReceipts;

  /// No description provided for @setupPointInvoices.
  ///
  /// In de, this message translates to:
  /// **'Rechnungen & E-Rechnungen schreiben'**
  String get setupPointInvoices;

  /// No description provided for @setupPointContracts.
  ///
  /// In de, this message translates to:
  /// **'Verträge und Fristen im Blick'**
  String get setupPointContracts;

  /// No description provided for @setupPointReports.
  ///
  /// In de, this message translates to:
  /// **'Saldenliste und Jahresübersicht'**
  String get setupPointReports;

  /// No description provided for @setupRegistrationsCount.
  ///
  /// In de, this message translates to:
  /// **'{count} angelegt: {list}'**
  String setupRegistrationsCount(int count, String list);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
