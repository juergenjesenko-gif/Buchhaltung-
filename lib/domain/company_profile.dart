import 'country.dart';

/// Die Stammdaten des eigenen Unternehmens. Genau ein Datensatz pro Installation.
class CompanyProfile {
  const CompanyProfile({
    required this.companyName,
    required this.country,
    this.ownerName = '',
    this.legalForm = LegalForm.soleTrader,
    this.street = '',
    this.postalCode = '',
    this.city = '',
    this.email = '',
    this.phone = '',
    this.website = '',
    this.taxNumber = '',
    this.vatId = '',
    this.isSmallBusiness = true,
    this.iban = '',
    this.bic = '',
    this.bankName = '',
    this.invoiceNumberPattern = 'RE-{YYYY}-{NNNN}',
    this.nextInvoiceSequence = 1,
    this.defaultPaymentTermDays = 14,
    this.invoiceFooter = '',
    this.fiscalYearStartMonth = 1,
    this.trackingStart,
    this.foundingYear,
    this.lastBackupAt,
  });

  final String companyName;
  final String ownerName;
  final Country country;
  final LegalForm legalForm;

  final String street;
  final String postalCode;
  final String city;
  final String email;
  final String phone;
  final String website;

  /// Steuernummer beim Finanzamt.
  final String taxNumber;

  /// UID-Nummer (AT) bzw. USt-IdNr. (DE). Bei Kleinunternehmern oft leer.
  final String vatId;

  /// Nimmt das Unternehmen die Kleinunternehmerregelung in Anspruch?
  /// Wenn ja, wird auf Rechnungen keine Umsatzsteuer ausgewiesen und der
  /// gesetzliche Hinweistext ist Pflicht.
  final bool isSmallBusiness;

  final String iban;
  final String bic;
  final String bankName;

  /// Muster für die Rechnungsnummer, siehe [InvoiceNumbering].
  final String invoiceNumberPattern;

  /// Nächste laufende Nummer im aktuellen Nummernkreis.
  final int nextInvoiceSequence;

  final int defaultPaymentTermDays;
  final String invoiceFooter;

  /// 1 = Kalenderjahr. Abweichende Wirtschaftsjahre sind bei
  /// Einzelunternehmern selten, aber möglich.
  final int fiscalYearStartMonth;

  /// Tag, ab dem die App die Buchhaltung führt. Umsätze davor kennt sie nur
  /// aus den Eröffnungswerten (Lastenheft L-16.1, L-16.11). `null` bei Profilen,
  /// die vor Einführung dieses Felds angelegt und noch nicht migriert wurden.
  final DateTime? trackingStart;

  /// Jahr der Unternehmensgründung, `null` wenn nicht angegeben. Im
  /// Gründungsjahr gibt es keinen Vorjahresumsatz, und in Deutschland gilt
  /// eine niedrigere Grenze (`TaxProfile.foundingYearTurnoverLimit`).
  final int? foundingYear;

  bool isFoundingYear(int year) => foundingYear == year;

  /// Zeitpunkt der letzten erfolgreichen Datensicherung, `null` wenn noch nie.
  /// Wird nur vom Sicherungsdienst geschrieben, nicht über das Formular.
  final DateTime? lastBackupAt;

  /// Nach so vielen Tagen ohne Sicherung erinnert die App (L-7.4).
  static const backupReminderDays = 30;

  bool needsBackup(DateTime now) =>
      lastBackupAt == null ||
      now.difference(lastBackupAt!).inDays >= backupReminderDays;

  TaxProfile get taxProfile => country.taxProfile;

  String get addressLine => [
    street,
    [postalCode, city].where((s) => s.isNotEmpty).join(' '),
  ].where((s) => s.isNotEmpty).join(', ');

  /// Das Profil ist vollständig genug, um eine rechtskonforme Rechnung zu
  /// erzeugen. Fehlende Angaben werden in [missingInvoiceFields] benannt.
  bool get canIssueInvoices => missingInvoiceFields.isEmpty;

  /// Pflichtangaben des Rechnungsausstellers laut § 11 UStG (AT) bzw.
  /// § 14 UStG (DE): Name, vollständige Anschrift und Steuernummer bzw. UID.
  List<String> get missingInvoiceFields {
    final missing = <String>[];
    if (companyName.trim().isEmpty) missing.add('Firmenname');
    if (street.trim().isEmpty) missing.add('Straße');
    if (postalCode.trim().isEmpty) missing.add('PLZ');
    if (city.trim().isEmpty) missing.add('Ort');
    if (taxNumber.trim().isEmpty && vatId.trim().isEmpty) {
      missing.add('${taxProfile.taxNumberLabel} oder ${taxProfile.vatIdLabel}');
    }
    // Wer Umsatzsteuer ausweist, braucht zwingend eine UID/USt-IdNr.
    if (!isSmallBusiness && vatId.trim().isEmpty) {
      missing.add(taxProfile.vatIdLabel);
    }
    return missing;
  }

  CompanyProfile copyWith({
    String? companyName,
    String? ownerName,
    Country? country,
    LegalForm? legalForm,
    String? street,
    String? postalCode,
    String? city,
    String? email,
    String? phone,
    String? website,
    String? taxNumber,
    String? vatId,
    bool? isSmallBusiness,
    String? iban,
    String? bic,
    String? bankName,
    String? invoiceNumberPattern,
    int? nextInvoiceSequence,
    int? defaultPaymentTermDays,
    String? invoiceFooter,
    int? fiscalYearStartMonth,
    DateTime? trackingStart,
    int? foundingYear,
    DateTime? lastBackupAt,
  }) {
    return CompanyProfile(
      companyName: companyName ?? this.companyName,
      ownerName: ownerName ?? this.ownerName,
      country: country ?? this.country,
      legalForm: legalForm ?? this.legalForm,
      street: street ?? this.street,
      postalCode: postalCode ?? this.postalCode,
      city: city ?? this.city,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      taxNumber: taxNumber ?? this.taxNumber,
      vatId: vatId ?? this.vatId,
      isSmallBusiness: isSmallBusiness ?? this.isSmallBusiness,
      iban: iban ?? this.iban,
      bic: bic ?? this.bic,
      bankName: bankName ?? this.bankName,
      invoiceNumberPattern: invoiceNumberPattern ?? this.invoiceNumberPattern,
      nextInvoiceSequence: nextInvoiceSequence ?? this.nextInvoiceSequence,
      defaultPaymentTermDays:
          defaultPaymentTermDays ?? this.defaultPaymentTermDays,
      invoiceFooter: invoiceFooter ?? this.invoiceFooter,
      fiscalYearStartMonth: fiscalYearStartMonth ?? this.fiscalYearStartMonth,
      trackingStart: trackingStart ?? this.trackingStart,
      foundingYear: foundingYear ?? this.foundingYear,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
    );
  }

  Map<String, Object?> toMap() => {
    'id': 1,
    'company_name': companyName,
    'owner_name': ownerName,
    'country_code': country.code,
    'legal_form': legalForm.name,
    'street': street,
    'postal_code': postalCode,
    'city': city,
    'email': email,
    'phone': phone,
    'website': website,
    'tax_number': taxNumber,
    'vat_id': vatId,
    'is_small_business': isSmallBusiness ? 1 : 0,
    'iban': iban,
    'bic': bic,
    'bank_name': bankName,
    'invoice_number_pattern': invoiceNumberPattern,
    'next_invoice_sequence': nextInvoiceSequence,
    'default_payment_term_days': defaultPaymentTermDays,
    'invoice_footer': invoiceFooter,
    'fiscal_year_start_month': fiscalYearStartMonth,
    'tracking_start': trackingStart?.toIso8601String().substring(0, 10),
    'founding_year': foundingYear,
    'last_backup_at': lastBackupAt?.toIso8601String(),
  };

  static CompanyProfile fromMap(Map<String, Object?> map) => CompanyProfile(
    companyName: map['company_name'] as String? ?? '',
    ownerName: map['owner_name'] as String? ?? '',
    country: Country.fromCode(map['country_code'] as String? ?? 'AT'),
    legalForm: LegalForm.values.firstWhere(
      (f) => f.name == map['legal_form'],
      orElse: () => LegalForm.soleTrader,
    ),
    street: map['street'] as String? ?? '',
    postalCode: map['postal_code'] as String? ?? '',
    city: map['city'] as String? ?? '',
    email: map['email'] as String? ?? '',
    phone: map['phone'] as String? ?? '',
    website: map['website'] as String? ?? '',
    taxNumber: map['tax_number'] as String? ?? '',
    vatId: map['vat_id'] as String? ?? '',
    isSmallBusiness: (map['is_small_business'] as int? ?? 1) == 1,
    iban: map['iban'] as String? ?? '',
    bic: map['bic'] as String? ?? '',
    bankName: map['bank_name'] as String? ?? '',
    invoiceNumberPattern:
        map['invoice_number_pattern'] as String? ?? 'RE-{YYYY}-{NNNN}',
    nextInvoiceSequence: map['next_invoice_sequence'] as int? ?? 1,
    defaultPaymentTermDays: map['default_payment_term_days'] as int? ?? 14,
    invoiceFooter: map['invoice_footer'] as String? ?? '',
    fiscalYearStartMonth: map['fiscal_year_start_month'] as int? ?? 1,
    trackingStart: _parseDate(map['tracking_start']),
    foundingYear: map['founding_year'] as int?,
    lastBackupAt: map['last_backup_at'] == null
        ? null
        : DateTime.tryParse(map['last_backup_at'] as String),
  );

  static DateTime? _parseDate(Object? value) =>
      value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;
}

enum LegalForm {
  soleTrader('Einzelunternehmen'),
  freelancer('Freiberufler / Neue Selbständige'),
  gbr('GbR / GesbR'),
  gmbh('GmbH');

  const LegalForm(this.label);
  final String label;
}
