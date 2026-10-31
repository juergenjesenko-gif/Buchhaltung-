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

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String invDunningHistoryTitle(String number) {
    return 'Mahnverlauf $number';
  }

  @override
  String invInvoiceOf(String date) {
    return 'Rechnung vom $date';
  }

  @override
  String invDueOn(String date) {
    return 'fällig $date';
  }

  @override
  String invNoticeOf(String title, String date) {
    return '$title vom $date';
  }

  @override
  String invCancelledReason(String reason) {
    return 'Storniert: $reason';
  }

  @override
  String invNoticeNewDue(String amount, String date) {
    return '$amount, neue Frist $date';
  }

  @override
  String get invCustomerMissing => 'Kundendaten fehlen.';

  @override
  String invCreditNoteCreated(String number) {
    return 'Stornorechnung $number erstellt.';
  }

  @override
  String get commonView => 'Ansehen';

  @override
  String invCorrectTitle(String number) {
    return '$number korrigieren';
  }

  @override
  String invCancelTitle(String number) {
    return '$number stornieren';
  }

  @override
  String get invCancelReasonLabel => 'Grund (steht auf der Stornorechnung)';

  @override
  String get invCancelRefundOn => 'Storno und Rückzahlung am';

  @override
  String get invCancelOn => 'Storno am';

  @override
  String invCancelPaidHint(String amount) {
    return 'Die Rechnung ist bezahlt: $amount werden an diesem Tag als Rückzahlung gebucht (Einnahme und Umsatzsteuer sinken). Überweise den Betrag an den Kunden zurück.';
  }

  @override
  String get invCancelOpenHint =>
      'Die Rechnung ist offen: es wird nichts gebucht. Laufende Mahnungen werden mit storniert.';

  @override
  String get invCancelAndRewrite => 'Stornieren und neu schreiben';

  @override
  String get invCreateCreditNote => 'Stornorechnung erstellen';

  @override
  String invPaidTitle(String number) {
    return '$number bezahlt';
  }

  @override
  String get invPaymentDate => 'Zahlungseingang';

  @override
  String get invPaidWithDiscount => 'Mit Skonto bezahlt?';

  @override
  String invDiscountDetail(String rate, String amount, String date) {
    return '$rate = $amount, Frist bis $date';
  }

  @override
  String get invCostsPaid => 'Mahnkosten und Zinsen mitbezahlt?';

  @override
  String invCostsDetail(String amount, String title) {
    return '$amount aus der $title, nicht umsatzsteuerbar';
  }

  @override
  String get invBookAsPaid => 'Als bezahlt buchen';

  @override
  String get invOnlyDraftsDeletable => 'Nur Entwürfe können gelöscht werden.';

  @override
  String get invTitle => 'Rechnungen';

  @override
  String get invCustomers => 'Kunden';

  @override
  String get invPickCustomerLeft => 'Wähle links einen Kunden aus.';

  @override
  String get invNew => 'Neue Rechnung';

  @override
  String get invEmptyTitle => 'Keine Rechnungen';

  @override
  String get invEmptyText =>
      'Schreibe deine erste Rechnung – die Pflichtangaben prüft die App für dich mit.';

  @override
  String get invWrite => 'Rechnung schreiben';

  @override
  String get invOpenHint => 'Gestellt und noch nicht bezahlt';

  @override
  String invOverdueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Rechnungen überfällig – mahnen?',
      one: '1 Rechnung überfällig – mahnen?',
    );
    return '$_temp0';
  }

  @override
  String get invQuotes => 'Angebote';

  @override
  String get invArticles => 'Artikel';

  @override
  String get invStatusOverdue => 'Überfällig';

  @override
  String get invStatusPaid => 'Bezahlt';

  @override
  String get invStatusCancelled => 'Storniert';

  @override
  String get invStatusCreditNote => 'Storno';

  @override
  String get invUnknownCustomer => 'Unbekannter Kunde';

  @override
  String invCreditNoteFor(String number) {
    return 'Storno zu $number';
  }

  @override
  String invCancelledBy(String number) {
    return 'storniert durch $number';
  }

  @override
  String get commonMoreActions => 'Weitere Aktionen';

  @override
  String get invMarkPaid => 'Als bezahlt markieren';

  @override
  String get invCorrect => 'Korrigieren';

  @override
  String get invCancel => 'Stornieren';

  @override
  String get invDeleteDraft => 'Entwurf löschen';

  @override
  String get invRemind => 'Erinnern';

  @override
  String get invDun => 'Mahnen';

  @override
  String get invShowDunningHistory => 'Mahnverlauf anzeigen';

  @override
  String get custEmptyTitle => 'Keine Kunden';

  @override
  String get custEmptyText =>
      'Lege deine Kunden einmal an – danach genügt beim Rechnungschreiben ein Tipp.';

  @override
  String get custAdd => 'Kunde anlegen';

  @override
  String get custNew => 'Neuer Kunde';

  @override
  String get invDraft => 'Entwurf';

  @override
  String get invStatusOpen => 'Offen';

  @override
  String get invDelete => 'Löschen';

  @override
  String invPositions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Positionen',
      one: '1 Position',
    );
    return '$_temp0';
  }

  @override
  String invConfirmTitle(String subject, String verb) {
    return '$subject $verb?';
  }

  @override
  String invInvoiceNumber(String number) {
    return 'Rechnung $number';
  }

  @override
  String invConfirmText(String subject, String amount) {
    return '$subject über $amount. Das lässt sich nicht rückgängig machen.';
  }

  @override
  String invCancelExplain(String amount, String number) {
    return 'Die App erstellt eine Stornorechnung mit eigener Nummer über $amount. Die Rechnung $number bleibt unverändert erhalten und wird als storniert markiert.';
  }

  @override
  String get invCorrectExplain =>
      ' Danach öffnet sich eine Kopie als neuer Entwurf.';

  @override
  String invPaymentBooked(String amount) {
    return '$amount werden als Einnahme am Tag des Zahlungseingangs gebucht. Bitte nicht zusätzlich als Einnahmebeleg erfassen.';
  }

  @override
  String invNoticeBadgeDue(String badge, String date) {
    return '$badge · Frist $date';
  }
}
