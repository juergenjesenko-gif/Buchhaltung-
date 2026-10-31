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

  @override
  String get commonCancel => 'Cancel';

  @override
  String invDunningHistoryTitle(String number) {
    return 'Reminder history $number';
  }

  @override
  String invInvoiceOf(String date) {
    return 'Invoice of $date';
  }

  @override
  String invDueOn(String date) {
    return 'due $date';
  }

  @override
  String invNoticeOf(String title, String date) {
    return '$title of $date';
  }

  @override
  String invCancelledReason(String reason) {
    return 'Cancelled: $reason';
  }

  @override
  String invNoticeNewDue(String amount, String date) {
    return '$amount, new due date $date';
  }

  @override
  String get invCustomerMissing => 'Customer details are missing.';

  @override
  String invCreditNoteCreated(String number) {
    return 'Credit note $number created.';
  }

  @override
  String get commonView => 'View';

  @override
  String invCorrectTitle(String number) {
    return 'Correct $number';
  }

  @override
  String invCancelTitle(String number) {
    return 'Cancel $number';
  }

  @override
  String get invCancelReasonLabel => 'Reason (shown on the credit note)';

  @override
  String get invCancelRefundOn => 'Cancellation and refund on';

  @override
  String get invCancelOn => 'Cancellation on';

  @override
  String invCancelPaidHint(String amount) {
    return 'The invoice is paid: $amount will be booked as a refund on this day (income and VAT go down). Transfer the amount back to the customer.';
  }

  @override
  String get invCancelOpenHint =>
      'The invoice is unpaid: nothing is booked. Open reminders are cancelled too.';

  @override
  String get invCancelAndRewrite => 'Cancel and rewrite';

  @override
  String get invCreateCreditNote => 'Create credit note';

  @override
  String invPaidTitle(String number) {
    return '$number paid';
  }

  @override
  String get invPaymentDate => 'Payment received';

  @override
  String get invPaidWithDiscount => 'Paid with early payment discount?';

  @override
  String invDiscountDetail(String rate, String amount, String date) {
    return '$rate = $amount, until $date';
  }

  @override
  String get invCostsPaid => 'Reminder fees and interest paid too?';

  @override
  String invCostsDetail(String amount, String title) {
    return '$amount from the $title, not subject to VAT';
  }

  @override
  String get invBookAsPaid => 'Book as paid';

  @override
  String get invOnlyDraftsDeletable => 'Only drafts can be deleted.';

  @override
  String get invTitle => 'Invoices';

  @override
  String get invCustomers => 'Customers';

  @override
  String get invPickCustomerLeft => 'Pick a customer on the left.';

  @override
  String get invNew => 'New invoice';

  @override
  String get invEmptyTitle => 'No invoices';

  @override
  String get invEmptyText =>
      'Write your first invoice – the app checks the required details for you.';

  @override
  String get invWrite => 'Write invoice';

  @override
  String get invOpenHint => 'Issued and not yet paid';

  @override
  String invOverdueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invoices overdue – send reminders?',
      one: '1 invoice overdue – send a reminder?',
    );
    return '$_temp0';
  }

  @override
  String get invQuotes => 'Quotes';

  @override
  String get invArticles => 'Items';

  @override
  String get invStatusOverdue => 'Overdue';

  @override
  String get invStatusPaid => 'Paid';

  @override
  String get invStatusCancelled => 'Cancelled';

  @override
  String get invStatusCreditNote => 'Credit note';

  @override
  String get invUnknownCustomer => 'Unknown customer';

  @override
  String invCreditNoteFor(String number) {
    return 'Credit note for $number';
  }

  @override
  String invCancelledBy(String number) {
    return 'cancelled by $number';
  }

  @override
  String get commonMoreActions => 'More actions';

  @override
  String get invMarkPaid => 'Mark as paid';

  @override
  String get invCorrect => 'Correct';

  @override
  String get invCancel => 'Cancel invoice';

  @override
  String get invDeleteDraft => 'Delete draft';

  @override
  String get invRemind => 'Remind';

  @override
  String get invDun => 'Send reminder';

  @override
  String get invShowDunningHistory => 'Show reminder history';

  @override
  String get custEmptyTitle => 'No customers';

  @override
  String get custEmptyText =>
      'Add your customers once – then one tap is enough when writing an invoice.';

  @override
  String get custAdd => 'Add customer';

  @override
  String get custNew => 'New customer';

  @override
  String get invDraft => 'Draft';

  @override
  String get invStatusOpen => 'Unpaid';

  @override
  String get invDelete => 'Delete';

  @override
  String invPositions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '1 line',
    );
    return '$_temp0';
  }

  @override
  String invConfirmTitle(String subject, String verb) {
    return '$verb $subject?';
  }

  @override
  String invInvoiceNumber(String number) {
    return 'Invoice $number';
  }

  @override
  String invConfirmText(String subject, String amount) {
    return '$subject for $amount. This cannot be undone.';
  }

  @override
  String invCancelExplain(String amount, String number) {
    return 'The app creates a credit note with its own number for $amount. Invoice $number stays unchanged and is marked as cancelled.';
  }

  @override
  String get invCorrectExplain => ' A copy then opens as a new draft.';

  @override
  String invPaymentBooked(String amount) {
    return '$amount will be booked as income on the day of payment. Please do not record it again as an income receipt.';
  }

  @override
  String invNoticeBadgeDue(String badge, String date) {
    return '$badge · due $date';
  }

  @override
  String get ieErrCustomer => 'Choose a customer';

  @override
  String get ieErrAddress => 'Customer\'s full address';

  @override
  String get ieErrOneLine => 'At least one line';

  @override
  String get ieErrDescription => 'A description for every line';

  @override
  String get ieDeliveryDate => 'Date of supply';

  @override
  String get ieErrDiscountMax => 'Discount at most 100%';

  @override
  String get ieErrSkonto => 'Early payment discount needs days and percent';

  @override
  String ieErrProfile(String field) {
    return 'Business details: $field';
  }

  @override
  String ieMissing(String items) {
    return 'Still missing: $items';
  }

  @override
  String get ieVatIdUnconfirmed => 'Customer\'s VAT number not confirmed';

  @override
  String get ieIssueAnyway => 'Issue anyway';

  @override
  String get ieDraftNotSavable => 'Draft cannot be saved yet';

  @override
  String ieDraftMissing(String items) {
    return 'Still missing: $items. The invoice cannot be saved without these details.';
  }

  @override
  String get commonDiscard => 'Discard';

  @override
  String get commonKeepEditing => 'Keep editing';

  @override
  String ieCreditNoteInfo(String number) {
    return 'Credit note for $number: amounts with reversed sign, cannot be changed.';
  }

  @override
  String get ieIssuedInfo =>
      'This invoice has been issued and cannot be changed. To change it, tap ⋮ → Correct in the invoice list.';

  @override
  String get ieRecipient => 'Recipient';

  @override
  String get commonChoose => 'Choose';

  @override
  String get ieNoCustomer => 'No customer chosen yet.';

  @override
  String get ieEditCustomer => 'Edit customer';

  @override
  String ieAddressNeeded(String limit) {
    return 'For an invoice above the small-amount limit of $limit the customer needs a full address.';
  }

  @override
  String get iePeriod => 'Dates';

  @override
  String get ieInvoiceDate => 'Invoice date';

  @override
  String ieRequiredBy(String ref) {
    return 'Required under $ref';
  }

  @override
  String get ieDueDate => 'Due on';

  @override
  String get ieLines => 'Lines';

  @override
  String get ieAddLine => 'Add line';

  @override
  String get ieFromItems => 'From items and suggestions';

  @override
  String get ieNotes => 'Notes';

  @override
  String get ieNotesHint => 'Shown below the lines on the invoice';

  @override
  String ieMissingBeforeIssue(String items) {
    return 'Still missing before issuing: $items.';
  }

  @override
  String get ieFinish => 'Close';

  @override
  String get iePdfView => 'View PDF';

  @override
  String get ieIssue => 'Issue invoice';

  @override
  String get ieTotal => 'Total';

  @override
  String get ieLinesTotal => 'Lines total';

  @override
  String ieDiscountSuffix(String suffix) {
    return 'Discount$suffix';
  }

  @override
  String ieShippingSuffix(String suffix) {
    return 'Shipping$suffix';
  }

  @override
  String get ieNet => 'Net';

  @override
  String ieVatOn(String rate, String net) {
    return 'VAT $rate on $net';
  }

  @override
  String get ieGrandTotal => 'Total amount';

  @override
  String ieSkontoPercent(String percent) {
    return 'Early payment discount $percent';
  }

  @override
  String ieNoteOnInvoice(String note) {
    return 'The invoice shows: \"$note\"';
  }

  @override
  String get ieExtras => 'Discount, shipping, early payment';

  @override
  String get ieWholeDiscount => 'Discount on the whole invoice';

  @override
  String get ieWholeDiscountHelp =>
      'Split proportionally across several VAT rates.';

  @override
  String get ieAddShipping => 'Add shipping';

  @override
  String get ieShippingNet => 'Shipping net';

  @override
  String get ieShippingVat => 'VAT on shipping';

  @override
  String get ieShippingVatHelp =>
      'Automatically like the goods – proportional for several rates';

  @override
  String get ieLikeMain => 'like main supply (automatic)';

  @override
  String get ieOfferSkonto => 'Offer early payment discount';

  @override
  String get ieOfferSkontoHelp => 'A reduction if your customer pays quickly';

  @override
  String get ieSkonto => 'Discount';

  @override
  String get ieWithin => 'within';

  @override
  String get ieDays => 'days';

  @override
  String get ieNotSet => 'Not set';

  @override
  String ieLineN(int index) {
    return 'Line $index';
  }

  @override
  String get ieRemoveLine => 'Remove line';

  @override
  String get ieDescription => 'Description';

  @override
  String get ieQuantity => 'Quantity';

  @override
  String get ieUnit => 'Unit';

  @override
  String get ieUnitPrice => 'Unit price net';

  @override
  String get ieAddDiscount => 'Add discount';

  @override
  String ieLineDiscount(int index) {
    return 'Discount on line $index';
  }

  @override
  String get ieLineDiscountHelp => 'Reduces only this line.';

  @override
  String get ieVatRate => 'VAT rate';

  @override
  String get ieChooseCustomer => 'Choose customer';

  @override
  String get ieNoCustomers => 'No customers yet.';

  @override
  String get ieNewCustomer => 'Add new customer';

  @override
  String get ieChangeDiscount => 'Change discount';

  @override
  String get ieDiscount => 'Discount';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonApply => 'Apply';

  @override
  String ieDiscountLine(String percent, String amount) {
    return 'Discount $percent= $amount';
  }
}
