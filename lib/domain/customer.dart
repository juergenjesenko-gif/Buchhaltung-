import 'country.dart';

/// Rechnungsempfänger. Name und vollständige Anschrift sind Pflichtangaben auf
/// jeder Rechnung oberhalb der Kleinbetragsgrenze.
class Customer {
  const Customer({
    this.id,
    required this.name,
    this.contactPerson = '',
    this.street = '',
    this.postalCode = '',
    this.city = '',
    this.country = Country.at,
    this.vatId = '',
    this.email = '',
    this.note = '',
    this.isBusiness = false,
    this.buyerReference = '',
    this.supplierNumber = '',
    this.eInvoiceFormat = EInvoiceFormat.zugferd,
  });

  /// Leitweg-ID (Behörde DE, BT-10) bzw. Auftragsreferenz/Bestellnummer
  /// (Bund AT, ebInterface `OrderReference`) oder Käuferreferenz, die die
  /// Kundin verlangt. Leer = keine (FA-5.49).
  final String buyerReference;

  /// Eigene Lieferantennummer bei dieser Kundin (ebInterface
  /// `InvoiceRecipientsBillerID`, beim Bund AT Pflicht; FA-5.49).
  final String supplierNumber;

  /// Format der E-Rechnung an diese Kundin (FA-5.49). Standard ist die
  /// ZUGFeRD-PDF: lesbar für Menschen, auslesbar für Programme.
  final EInvoiceFormat eInvoiceFormat;

  /// Unternehmen (B2B) statt Verbraucherin (B2C). Bestimmt Verzugszinssatz,
  /// Pauschale und Hinweise im Mahnwesen (L-3.28); vorbelegt Ja, wenn eine
  /// UID eingetragen ist.
  final bool isBusiness;

  final int? id;
  final String name;
  final String contactPerson;
  final String street;
  final String postalCode;
  final String city;
  final Country country;

  /// UID des Kunden. Bei innergemeinschaftlichen Leistungen an Unternehmer
  /// Pflicht, weil dann das Reverse-Charge-Verfahren greift.
  final String vatId;

  final String email;
  final String note;

  bool get hasCompleteAddress =>
      street.trim().isNotEmpty &&
      postalCode.trim().isNotEmpty &&
      city.trim().isNotEmpty;

  /// Adresse als Zeilen für den Rechnungskopf.
  List<String> get addressLines => [
    name,
    if (contactPerson.isNotEmpty) contactPerson,
    if (street.isNotEmpty) street,
    if (postalCode.isNotEmpty || city.isNotEmpty) '$postalCode $city'.trim(),
    if (country != Country.at || postalCode.isEmpty) country.label,
  ];

  Customer copyWith({
    int? id,
    String? name,
    String? contactPerson,
    String? street,
    String? postalCode,
    String? city,
    Country? country,
    String? vatId,
    String? email,
    String? note,
    bool? isBusiness,
    String? buyerReference,
    String? supplierNumber,
    EInvoiceFormat? eInvoiceFormat,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      street: street ?? this.street,
      postalCode: postalCode ?? this.postalCode,
      city: city ?? this.city,
      country: country ?? this.country,
      vatId: vatId ?? this.vatId,
      email: email ?? this.email,
      note: note ?? this.note,
      isBusiness: isBusiness ?? this.isBusiness,
      buyerReference: buyerReference ?? this.buyerReference,
      supplierNumber: supplierNumber ?? this.supplierNumber,
      eInvoiceFormat: eInvoiceFormat ?? this.eInvoiceFormat,
    );
  }

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'contact_person': contactPerson,
    'street': street,
    'postal_code': postalCode,
    'city': city,
    'country_code': country.code,
    'vat_id': vatId,
    'email': email,
    'note': note,
    'is_business': isBusiness ? 1 : 0,
    'buyer_reference': buyerReference,
    'supplier_number': supplierNumber,
    'e_invoice_format': eInvoiceFormat.name,
  };

  static Customer fromMap(Map<String, Object?> map) => Customer(
    id: map['id'] as int?,
    name: map['name'] as String? ?? '',
    contactPerson: map['contact_person'] as String? ?? '',
    street: map['street'] as String? ?? '',
    postalCode: map['postal_code'] as String? ?? '',
    city: map['city'] as String? ?? '',
    country: Country.fromCode(map['country_code'] as String? ?? 'AT'),
    vatId: map['vat_id'] as String? ?? '',
    email: map['email'] as String? ?? '',
    note: map['note'] as String? ?? '',
    isBusiness: (map['is_business'] as int? ?? 0) == 1,
    buyerReference: map['buyer_reference'] as String? ?? '',
    supplierNumber: map['supplier_number'] as String? ?? '',
    eInvoiceFormat: EInvoiceFormat.values.firstWhere(
      (f) => f.name == map['e_invoice_format'],
      orElse: () => EInvoiceFormat.zugferd,
    ),
  );
}

/// Format der E-Rechnung (FA-5.49).
enum EInvoiceFormat {
  /// Hybride PDF/A-3 mit eingebettetem CII-XML, Profil EN 16931
  /// (ZUGFeRD 2.x / Factur-X). Standard für Unternehmen in DE und AT.
  zugferd('ZUGFeRD-PDF', 'PDF zum Lesen mit E-Rechnung darin (Standard)'),

  /// XRechnung 3.0 (CII-Syntax) als XML – für Behörden in Deutschland
  /// (Leitweg-ID).
  xrechnung('XRechnung', 'XML für Behörden in Deutschland (Leitweg-ID)'),

  /// ebInterface 6.1 als XML – für den Bund in Österreich
  /// (e-Rechnung.gv.at, Unternehmensserviceportal).
  ebInterface('ebInterface', 'XML für Bundesdienststellen in Österreich');

  const EInvoiceFormat(this.label, this.hint);

  final String label;
  final String hint;

  /// Reines XML statt PDF.
  bool get isXml => this != zugferd;
}
