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
  });

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
  );
}
