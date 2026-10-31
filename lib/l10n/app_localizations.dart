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

  /// No description provided for @commonCancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get commonCancel;

  /// No description provided for @invDunningHistoryTitle.
  ///
  /// In de, this message translates to:
  /// **'Mahnverlauf {number}'**
  String invDunningHistoryTitle(String number);

  /// No description provided for @invInvoiceOf.
  ///
  /// In de, this message translates to:
  /// **'Rechnung vom {date}'**
  String invInvoiceOf(String date);

  /// No description provided for @invDueOn.
  ///
  /// In de, this message translates to:
  /// **'fällig {date}'**
  String invDueOn(String date);

  /// No description provided for @invNoticeOf.
  ///
  /// In de, this message translates to:
  /// **'{title} vom {date}'**
  String invNoticeOf(String title, String date);

  /// No description provided for @invCancelledReason.
  ///
  /// In de, this message translates to:
  /// **'Storniert: {reason}'**
  String invCancelledReason(String reason);

  /// No description provided for @invNoticeNewDue.
  ///
  /// In de, this message translates to:
  /// **'{amount}, neue Frist {date}'**
  String invNoticeNewDue(String amount, String date);

  /// No description provided for @invCustomerMissing.
  ///
  /// In de, this message translates to:
  /// **'Kundendaten fehlen.'**
  String get invCustomerMissing;

  /// No description provided for @invCreditNoteCreated.
  ///
  /// In de, this message translates to:
  /// **'Stornorechnung {number} erstellt.'**
  String invCreditNoteCreated(String number);

  /// No description provided for @commonView.
  ///
  /// In de, this message translates to:
  /// **'Ansehen'**
  String get commonView;

  /// No description provided for @invCorrectTitle.
  ///
  /// In de, this message translates to:
  /// **'{number} korrigieren'**
  String invCorrectTitle(String number);

  /// No description provided for @invCancelTitle.
  ///
  /// In de, this message translates to:
  /// **'{number} stornieren'**
  String invCancelTitle(String number);

  /// No description provided for @invCancelReasonLabel.
  ///
  /// In de, this message translates to:
  /// **'Grund (steht auf der Stornorechnung)'**
  String get invCancelReasonLabel;

  /// No description provided for @invCancelRefundOn.
  ///
  /// In de, this message translates to:
  /// **'Storno und Rückzahlung am'**
  String get invCancelRefundOn;

  /// No description provided for @invCancelOn.
  ///
  /// In de, this message translates to:
  /// **'Storno am'**
  String get invCancelOn;

  /// No description provided for @invCancelPaidHint.
  ///
  /// In de, this message translates to:
  /// **'Die Rechnung ist bezahlt: {amount} werden an diesem Tag als Rückzahlung gebucht (Einnahme und Umsatzsteuer sinken). Überweise den Betrag an den Kunden zurück.'**
  String invCancelPaidHint(String amount);

  /// No description provided for @invCancelOpenHint.
  ///
  /// In de, this message translates to:
  /// **'Die Rechnung ist offen: es wird nichts gebucht. Laufende Mahnungen werden mit storniert.'**
  String get invCancelOpenHint;

  /// No description provided for @invCancelAndRewrite.
  ///
  /// In de, this message translates to:
  /// **'Stornieren und neu schreiben'**
  String get invCancelAndRewrite;

  /// No description provided for @invCreateCreditNote.
  ///
  /// In de, this message translates to:
  /// **'Stornorechnung erstellen'**
  String get invCreateCreditNote;

  /// No description provided for @invPaidTitle.
  ///
  /// In de, this message translates to:
  /// **'{number} bezahlt'**
  String invPaidTitle(String number);

  /// No description provided for @invPaymentDate.
  ///
  /// In de, this message translates to:
  /// **'Zahlungseingang'**
  String get invPaymentDate;

  /// No description provided for @invPaidWithDiscount.
  ///
  /// In de, this message translates to:
  /// **'Mit Skonto bezahlt?'**
  String get invPaidWithDiscount;

  /// No description provided for @invDiscountDetail.
  ///
  /// In de, this message translates to:
  /// **'{rate} = {amount}, Frist bis {date}'**
  String invDiscountDetail(String rate, String amount, String date);

  /// No description provided for @invCostsPaid.
  ///
  /// In de, this message translates to:
  /// **'Mahnkosten und Zinsen mitbezahlt?'**
  String get invCostsPaid;

  /// No description provided for @invCostsDetail.
  ///
  /// In de, this message translates to:
  /// **'{amount} aus der {title}, nicht umsatzsteuerbar'**
  String invCostsDetail(String amount, String title);

  /// No description provided for @invBookAsPaid.
  ///
  /// In de, this message translates to:
  /// **'Als bezahlt buchen'**
  String get invBookAsPaid;

  /// No description provided for @invOnlyDraftsDeletable.
  ///
  /// In de, this message translates to:
  /// **'Nur Entwürfe können gelöscht werden.'**
  String get invOnlyDraftsDeletable;

  /// No description provided for @invTitle.
  ///
  /// In de, this message translates to:
  /// **'Rechnungen'**
  String get invTitle;

  /// No description provided for @invCustomers.
  ///
  /// In de, this message translates to:
  /// **'Kunden'**
  String get invCustomers;

  /// No description provided for @invPickCustomerLeft.
  ///
  /// In de, this message translates to:
  /// **'Wähle links einen Kunden aus.'**
  String get invPickCustomerLeft;

  /// No description provided for @invNew.
  ///
  /// In de, this message translates to:
  /// **'Neue Rechnung'**
  String get invNew;

  /// No description provided for @invEmptyTitle.
  ///
  /// In de, this message translates to:
  /// **'Keine Rechnungen'**
  String get invEmptyTitle;

  /// No description provided for @invEmptyText.
  ///
  /// In de, this message translates to:
  /// **'Schreibe deine erste Rechnung – die Pflichtangaben prüft die App für dich mit.'**
  String get invEmptyText;

  /// No description provided for @invWrite.
  ///
  /// In de, this message translates to:
  /// **'Rechnung schreiben'**
  String get invWrite;

  /// No description provided for @invOpenHint.
  ///
  /// In de, this message translates to:
  /// **'Gestellt und noch nicht bezahlt'**
  String get invOpenHint;

  /// No description provided for @invOverdueCount.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Rechnung überfällig – mahnen?} other{{count} Rechnungen überfällig – mahnen?}}'**
  String invOverdueCount(int count);

  /// No description provided for @invQuotes.
  ///
  /// In de, this message translates to:
  /// **'Angebote'**
  String get invQuotes;

  /// No description provided for @invArticles.
  ///
  /// In de, this message translates to:
  /// **'Artikel'**
  String get invArticles;

  /// No description provided for @invStatusOverdue.
  ///
  /// In de, this message translates to:
  /// **'Überfällig'**
  String get invStatusOverdue;

  /// No description provided for @invStatusPaid.
  ///
  /// In de, this message translates to:
  /// **'Bezahlt'**
  String get invStatusPaid;

  /// No description provided for @invStatusCancelled.
  ///
  /// In de, this message translates to:
  /// **'Storniert'**
  String get invStatusCancelled;

  /// No description provided for @invStatusCreditNote.
  ///
  /// In de, this message translates to:
  /// **'Storno'**
  String get invStatusCreditNote;

  /// No description provided for @invUnknownCustomer.
  ///
  /// In de, this message translates to:
  /// **'Unbekannter Kunde'**
  String get invUnknownCustomer;

  /// No description provided for @invCreditNoteFor.
  ///
  /// In de, this message translates to:
  /// **'Storno zu {number}'**
  String invCreditNoteFor(String number);

  /// No description provided for @invCancelledBy.
  ///
  /// In de, this message translates to:
  /// **'storniert durch {number}'**
  String invCancelledBy(String number);

  /// No description provided for @commonMoreActions.
  ///
  /// In de, this message translates to:
  /// **'Weitere Aktionen'**
  String get commonMoreActions;

  /// No description provided for @invMarkPaid.
  ///
  /// In de, this message translates to:
  /// **'Als bezahlt markieren'**
  String get invMarkPaid;

  /// No description provided for @invCorrect.
  ///
  /// In de, this message translates to:
  /// **'Korrigieren'**
  String get invCorrect;

  /// No description provided for @invCancel.
  ///
  /// In de, this message translates to:
  /// **'Stornieren'**
  String get invCancel;

  /// No description provided for @invDeleteDraft.
  ///
  /// In de, this message translates to:
  /// **'Entwurf löschen'**
  String get invDeleteDraft;

  /// No description provided for @invRemind.
  ///
  /// In de, this message translates to:
  /// **'Erinnern'**
  String get invRemind;

  /// No description provided for @invDun.
  ///
  /// In de, this message translates to:
  /// **'Mahnen'**
  String get invDun;

  /// No description provided for @invShowDunningHistory.
  ///
  /// In de, this message translates to:
  /// **'Mahnverlauf anzeigen'**
  String get invShowDunningHistory;

  /// No description provided for @custEmptyTitle.
  ///
  /// In de, this message translates to:
  /// **'Keine Kunden'**
  String get custEmptyTitle;

  /// No description provided for @custEmptyText.
  ///
  /// In de, this message translates to:
  /// **'Lege deine Kunden einmal an – danach genügt beim Rechnungschreiben ein Tipp.'**
  String get custEmptyText;

  /// No description provided for @custAdd.
  ///
  /// In de, this message translates to:
  /// **'Kunde anlegen'**
  String get custAdd;

  /// No description provided for @custNew.
  ///
  /// In de, this message translates to:
  /// **'Neuer Kunde'**
  String get custNew;

  /// No description provided for @invDraft.
  ///
  /// In de, this message translates to:
  /// **'Entwurf'**
  String get invDraft;

  /// No description provided for @invStatusOpen.
  ///
  /// In de, this message translates to:
  /// **'Offen'**
  String get invStatusOpen;

  /// No description provided for @invDelete.
  ///
  /// In de, this message translates to:
  /// **'Löschen'**
  String get invDelete;

  /// No description provided for @invPositions.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Position} other{{count} Positionen}}'**
  String invPositions(int count);

  /// No description provided for @invConfirmTitle.
  ///
  /// In de, this message translates to:
  /// **'{subject} {verb}?'**
  String invConfirmTitle(String subject, String verb);

  /// No description provided for @invInvoiceNumber.
  ///
  /// In de, this message translates to:
  /// **'Rechnung {number}'**
  String invInvoiceNumber(String number);

  /// No description provided for @invConfirmText.
  ///
  /// In de, this message translates to:
  /// **'{subject} über {amount}. Das lässt sich nicht rückgängig machen.'**
  String invConfirmText(String subject, String amount);

  /// No description provided for @invCancelExplain.
  ///
  /// In de, this message translates to:
  /// **'Die App erstellt eine Stornorechnung mit eigener Nummer über {amount}. Die Rechnung {number} bleibt unverändert erhalten und wird als storniert markiert.'**
  String invCancelExplain(String amount, String number);

  /// No description provided for @invCorrectExplain.
  ///
  /// In de, this message translates to:
  /// **' Danach öffnet sich eine Kopie als neuer Entwurf.'**
  String get invCorrectExplain;

  /// No description provided for @invPaymentBooked.
  ///
  /// In de, this message translates to:
  /// **'{amount} werden als Einnahme am Tag des Zahlungseingangs gebucht. Bitte nicht zusätzlich als Einnahmebeleg erfassen.'**
  String invPaymentBooked(String amount);

  /// No description provided for @invNoticeBadgeDue.
  ///
  /// In de, this message translates to:
  /// **'{badge} · Frist {date}'**
  String invNoticeBadgeDue(String badge, String date);

  /// No description provided for @ieErrCustomer.
  ///
  /// In de, this message translates to:
  /// **'Kunde auswählen'**
  String get ieErrCustomer;

  /// No description provided for @ieErrAddress.
  ///
  /// In de, this message translates to:
  /// **'Vollständige Anschrift des Kunden'**
  String get ieErrAddress;

  /// No description provided for @ieErrOneLine.
  ///
  /// In de, this message translates to:
  /// **'Mindestens eine Position'**
  String get ieErrOneLine;

  /// No description provided for @ieErrDescription.
  ///
  /// In de, this message translates to:
  /// **'Bezeichnung für jede Position'**
  String get ieErrDescription;

  /// No description provided for @ieDeliveryDate.
  ///
  /// In de, this message translates to:
  /// **'Liefer-/Leistungsdatum'**
  String get ieDeliveryDate;

  /// No description provided for @ieErrDiscountMax.
  ///
  /// In de, this message translates to:
  /// **'Rabatt höchstens 100 %'**
  String get ieErrDiscountMax;

  /// No description provided for @ieErrSkonto.
  ///
  /// In de, this message translates to:
  /// **'Skonto mit Tagen und Prozent'**
  String get ieErrSkonto;

  /// No description provided for @ieErrProfile.
  ///
  /// In de, this message translates to:
  /// **'Stammdaten: {field}'**
  String ieErrProfile(String field);

  /// No description provided for @ieMissing.
  ///
  /// In de, this message translates to:
  /// **'Es fehlt noch: {items}'**
  String ieMissing(String items);

  /// No description provided for @ieVatIdUnconfirmed.
  ///
  /// In de, this message translates to:
  /// **'UID des Kunden nicht bestätigt'**
  String get ieVatIdUnconfirmed;

  /// No description provided for @ieIssueAnyway.
  ///
  /// In de, this message translates to:
  /// **'Trotzdem ausstellen'**
  String get ieIssueAnyway;

  /// No description provided for @ieDraftNotSavable.
  ///
  /// In de, this message translates to:
  /// **'Entwurf noch nicht speicherbar'**
  String get ieDraftNotSavable;

  /// No description provided for @ieDraftMissing.
  ///
  /// In de, this message translates to:
  /// **'Es fehlt noch: {items}. Ohne diese Angaben kann die Rechnung nicht gespeichert werden.'**
  String ieDraftMissing(String items);

  /// No description provided for @commonDiscard.
  ///
  /// In de, this message translates to:
  /// **'Verwerfen'**
  String get commonDiscard;

  /// No description provided for @commonKeepEditing.
  ///
  /// In de, this message translates to:
  /// **'Weiter bearbeiten'**
  String get commonKeepEditing;

  /// No description provided for @ieCreditNoteInfo.
  ///
  /// In de, this message translates to:
  /// **'Stornorechnung zu {number}: Beträge mit umgekehrtem Vorzeichen, unveränderlich.'**
  String ieCreditNoteInfo(String number);

  /// No description provided for @ieIssuedInfo.
  ///
  /// In de, this message translates to:
  /// **'Diese Rechnung ist gestellt und kann nicht mehr geändert werden. Zum Ändern in der Rechnungsliste ⋮ → Korrigieren tippen.'**
  String get ieIssuedInfo;

  /// No description provided for @ieRecipient.
  ///
  /// In de, this message translates to:
  /// **'Empfänger'**
  String get ieRecipient;

  /// No description provided for @commonChoose.
  ///
  /// In de, this message translates to:
  /// **'Wählen'**
  String get commonChoose;

  /// No description provided for @ieNoCustomer.
  ///
  /// In de, this message translates to:
  /// **'Noch kein Kunde ausgewählt.'**
  String get ieNoCustomer;

  /// No description provided for @ieEditCustomer.
  ///
  /// In de, this message translates to:
  /// **'Kunde bearbeiten'**
  String get ieEditCustomer;

  /// No description provided for @ieAddressNeeded.
  ///
  /// In de, this message translates to:
  /// **'Für eine Rechnung über der Kleinbetragsgrenze von {limit} braucht der Kunde eine vollständige Anschrift.'**
  String ieAddressNeeded(String limit);

  /// No description provided for @iePeriod.
  ///
  /// In de, this message translates to:
  /// **'Zeitraum'**
  String get iePeriod;

  /// No description provided for @ieInvoiceDate.
  ///
  /// In de, this message translates to:
  /// **'Rechnungsdatum'**
  String get ieInvoiceDate;

  /// No description provided for @ieRequiredBy.
  ///
  /// In de, this message translates to:
  /// **'Pflichtangabe nach {ref}'**
  String ieRequiredBy(String ref);

  /// No description provided for @ieDueDate.
  ///
  /// In de, this message translates to:
  /// **'Fällig am'**
  String get ieDueDate;

  /// No description provided for @ieLines.
  ///
  /// In de, this message translates to:
  /// **'Positionen'**
  String get ieLines;

  /// No description provided for @ieAddLine.
  ///
  /// In de, this message translates to:
  /// **'Position hinzufügen'**
  String get ieAddLine;

  /// No description provided for @ieFromItems.
  ///
  /// In de, this message translates to:
  /// **'Aus Artikeln und Vorschlägen'**
  String get ieFromItems;

  /// No description provided for @ieNotes.
  ///
  /// In de, this message translates to:
  /// **'Anmerkungen'**
  String get ieNotes;

  /// No description provided for @ieNotesHint.
  ///
  /// In de, this message translates to:
  /// **'Erscheint unter den Positionen auf der Rechnung'**
  String get ieNotesHint;

  /// No description provided for @ieMissingBeforeIssue.
  ///
  /// In de, this message translates to:
  /// **'Vor dem Ausstellen fehlt noch: {items}.'**
  String ieMissingBeforeIssue(String items);

  /// No description provided for @ieFinish.
  ///
  /// In de, this message translates to:
  /// **'Beenden'**
  String get ieFinish;

  /// No description provided for @iePdfView.
  ///
  /// In de, this message translates to:
  /// **'PDF ansehen'**
  String get iePdfView;

  /// No description provided for @ieIssue.
  ///
  /// In de, this message translates to:
  /// **'Rechnung ausstellen'**
  String get ieIssue;

  /// No description provided for @ieTotal.
  ///
  /// In de, this message translates to:
  /// **'Summe'**
  String get ieTotal;

  /// No description provided for @ieLinesTotal.
  ///
  /// In de, this message translates to:
  /// **'Summe Positionen'**
  String get ieLinesTotal;

  /// No description provided for @ieDiscountSuffix.
  ///
  /// In de, this message translates to:
  /// **'Rabatt{suffix}'**
  String ieDiscountSuffix(String suffix);

  /// No description provided for @ieShippingSuffix.
  ///
  /// In de, this message translates to:
  /// **'Versand{suffix}'**
  String ieShippingSuffix(String suffix);

  /// No description provided for @ieNet.
  ///
  /// In de, this message translates to:
  /// **'Netto'**
  String get ieNet;

  /// No description provided for @ieVatOn.
  ///
  /// In de, this message translates to:
  /// **'USt {rate} auf {net}'**
  String ieVatOn(String rate, String net);

  /// No description provided for @ieGrandTotal.
  ///
  /// In de, this message translates to:
  /// **'Gesamtbetrag'**
  String get ieGrandTotal;

  /// No description provided for @ieSkontoPercent.
  ///
  /// In de, this message translates to:
  /// **'Skonto {percent}'**
  String ieSkontoPercent(String percent);

  /// No description provided for @ieNoteOnInvoice.
  ///
  /// In de, this message translates to:
  /// **'Auf der Rechnung erscheint: \"{note}\"'**
  String ieNoteOnInvoice(String note);

  /// No description provided for @ieExtras.
  ///
  /// In de, this message translates to:
  /// **'Rabatt, Versand, Skonto'**
  String get ieExtras;

  /// No description provided for @ieWholeDiscount.
  ///
  /// In de, this message translates to:
  /// **'Rabatt auf die ganze Rechnung'**
  String get ieWholeDiscount;

  /// No description provided for @ieWholeDiscountHelp.
  ///
  /// In de, this message translates to:
  /// **'Wird bei mehreren Steuersätzen anteilig aufgeteilt.'**
  String get ieWholeDiscountHelp;

  /// No description provided for @ieAddShipping.
  ///
  /// In de, this message translates to:
  /// **'Versandkosten hinzufügen'**
  String get ieAddShipping;

  /// No description provided for @ieShippingNet.
  ///
  /// In de, this message translates to:
  /// **'Versandkosten netto'**
  String get ieShippingNet;

  /// No description provided for @ieShippingVat.
  ///
  /// In de, this message translates to:
  /// **'Umsatzsteuer auf Versand'**
  String get ieShippingVat;

  /// No description provided for @ieShippingVatHelp.
  ///
  /// In de, this message translates to:
  /// **'Automatisch wie die Waren – bei mehreren Sätzen anteilig'**
  String get ieShippingVatHelp;

  /// No description provided for @ieLikeMain.
  ///
  /// In de, this message translates to:
  /// **'wie Hauptleistung (automatisch)'**
  String get ieLikeMain;

  /// No description provided for @ieOfferSkonto.
  ///
  /// In de, this message translates to:
  /// **'Skonto anbieten'**
  String get ieOfferSkonto;

  /// No description provided for @ieOfferSkontoHelp.
  ///
  /// In de, this message translates to:
  /// **'Nachlass, wenn deine Kundin schnell zahlt'**
  String get ieOfferSkontoHelp;

  /// No description provided for @ieSkonto.
  ///
  /// In de, this message translates to:
  /// **'Skonto'**
  String get ieSkonto;

  /// No description provided for @ieWithin.
  ///
  /// In de, this message translates to:
  /// **'innerhalb'**
  String get ieWithin;

  /// No description provided for @ieDays.
  ///
  /// In de, this message translates to:
  /// **'Tage'**
  String get ieDays;

  /// No description provided for @ieNotSet.
  ///
  /// In de, this message translates to:
  /// **'Nicht gesetzt'**
  String get ieNotSet;

  /// No description provided for @ieLineN.
  ///
  /// In de, this message translates to:
  /// **'Position {index}'**
  String ieLineN(int index);

  /// No description provided for @ieRemoveLine.
  ///
  /// In de, this message translates to:
  /// **'Position entfernen'**
  String get ieRemoveLine;

  /// No description provided for @ieDescription.
  ///
  /// In de, this message translates to:
  /// **'Bezeichnung'**
  String get ieDescription;

  /// No description provided for @ieQuantity.
  ///
  /// In de, this message translates to:
  /// **'Menge'**
  String get ieQuantity;

  /// No description provided for @ieUnit.
  ///
  /// In de, this message translates to:
  /// **'Einheit'**
  String get ieUnit;

  /// No description provided for @ieUnitPrice.
  ///
  /// In de, this message translates to:
  /// **'Einzelpreis netto'**
  String get ieUnitPrice;

  /// No description provided for @ieAddDiscount.
  ///
  /// In de, this message translates to:
  /// **'Rabatt hinzufügen'**
  String get ieAddDiscount;

  /// No description provided for @ieLineDiscount.
  ///
  /// In de, this message translates to:
  /// **'Rabatt auf Position {index}'**
  String ieLineDiscount(int index);

  /// No description provided for @ieLineDiscountHelp.
  ///
  /// In de, this message translates to:
  /// **'Mindert nur diese Position.'**
  String get ieLineDiscountHelp;

  /// No description provided for @ieVatRate.
  ///
  /// In de, this message translates to:
  /// **'Umsatzsteuersatz'**
  String get ieVatRate;

  /// No description provided for @ieChooseCustomer.
  ///
  /// In de, this message translates to:
  /// **'Kunde wählen'**
  String get ieChooseCustomer;

  /// No description provided for @ieNoCustomers.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Kunden angelegt.'**
  String get ieNoCustomers;

  /// No description provided for @ieNewCustomer.
  ///
  /// In de, this message translates to:
  /// **'Neuen Kunden anlegen'**
  String get ieNewCustomer;

  /// No description provided for @ieChangeDiscount.
  ///
  /// In de, this message translates to:
  /// **'Rabatt ändern'**
  String get ieChangeDiscount;

  /// No description provided for @ieDiscount.
  ///
  /// In de, this message translates to:
  /// **'Rabatt'**
  String get ieDiscount;

  /// No description provided for @commonRemove.
  ///
  /// In de, this message translates to:
  /// **'Entfernen'**
  String get commonRemove;

  /// No description provided for @commonApply.
  ///
  /// In de, this message translates to:
  /// **'Übernehmen'**
  String get commonApply;

  /// No description provided for @ieDiscountLine.
  ///
  /// In de, this message translates to:
  /// **'Rabatt {percent}= {amount}'**
  String ieDiscountLine(String percent, String amount);
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
