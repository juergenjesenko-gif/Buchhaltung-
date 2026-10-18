/// Steuerliche Registrierung in einem weiteren Land (Lastenheft L-30,
/// Spezifikation 5.14, FA-18.x).
///
/// Die Heimatregistrierung ist das Firmenprofil selbst; hier stehen nur die
/// zusätzlichen Länder, z. B. eine deutsche USt-Registrierung einer
/// österreichischen Händlerin wegen eines Amazon-FBA-Lagers in Deutschland.
/// Länderspezifisches (Fristen, Kennzahlen, Finanzamt-Vorschlag) steht im
/// `TaxProfile` des Landes (GR-6).
library;

import 'country.dart';

/// Besteuerungsform in dem Land der Registrierung.
enum VatScheme {
  /// Regelbesteuerung: Umsatzsteuer ausweisen, Voranmeldungen, Vorsteuer.
  standard('Regelbesteuerung'),

  /// Kleinunternehmer nach dem Recht dieses Landes (nur für dort
  /// ansässige Unternehmen, z. B. DE § 19 Abs 1 UStG, AT § 6 Abs 1 Z 27
  /// UStG 1994). Für ausländische Unternehmen meist nicht möglich: P-S70.
  smallBusiness('Kleinunternehmer'),

  /// EU-Kleinunternehmer-Verfahren seit 1.1.2025 (Art 284 Abs 2
  /// MwStSystRL idF RL (EU) 2020/285; DE §§ 19, 19a UStG, AT § 6 Abs 1
  /// Z 27 UStG 1994 idF AbgÄG 2024): Steuerbefreiung im anderen Land über
  /// die Heimat-Finanzverwaltung, Meldung vierteljährlich dort
  /// (Art 284d MwStSystRL). Fundstellen ungesichert: P-S69.
  euSmallBusiness('EU-Kleinunternehmer-Verfahren');

  const VatScheme(this.label);
  final String label;

  static VatScheme fromName(String? name) => VatScheme.values.firstWhere(
    (v) => v.name == name,
    orElse: () => VatScheme.standard,
  );
}

/// Voranmeldungszeitraum der Registrierung.
enum FilingInterval {
  monthly('Monatlich'),
  quarterly('Vierteljährlich'),

  /// Nur Jahreserklärung (DE § 18 Abs 2 Satz 3 UStG: Befreiung durch das
  /// Finanzamt bei geringer Zahllast).
  annual('Nur jährlich'),

  /// Keine Erklärungen in diesem Land (z. B. EU-Kleinunternehmer-Verfahren).
  none('Keine');

  const FilingInterval(this.label);
  final String label;

  static FilingInterval fromName(String? name) => FilingInterval.values
      .firstWhere((v) => v.name == name, orElse: () => FilingInterval.monthly);
}

/// Länder, die im Auswahlfeld „Land hinzufügen“ schon sichtbar, aber noch
/// nicht wählbar sind („bald“). Reihenfolge: Amazon-Pan-EU-Lagerländer.
const upcomingRegistrationCountries = <(String, String)>[
  ('IT', 'Italien'),
  ('FR', 'Frankreich'),
  ('ES', 'Spanien'),
  ('PL', 'Polen'),
  ('CZ', 'Tschechien'),
  ('NL', 'Niederlande'),
];

class TaxRegistration {
  const TaxRegistration({
    this.id,
    required this.country,
    this.vatId = '',
    this.taxNumber = '',
    this.taxOffice = '',
    this.scheme = VatScheme.standard,
    this.interval = FilingInterval.monthly,
    this.permanentExtension = false,
    this.validFrom,
    this.validTo,
  });

  final int? id;
  final Country country;

  /// UID bzw. USt-IdNr. in diesem Land.
  final String vatId;
  final String taxNumber;

  /// Zuständiges Finanzamt, freier Text (Vorschlag aus dem `TaxProfile`).
  final String taxOffice;
  final VatScheme scheme;
  final FilingInterval interval;

  /// Dauerfristverlängerung (nur wo `TaxProfile.hasPermanentExtension`).
  final bool permanentExtension;
  final DateTime? validFrom;
  final DateTime? validTo;

  TaxProfile get taxProfile => country.taxProfile;

  /// Kein Vorsteuerabzug und keine Umsatzsteuer auf eigene Umsätze.
  bool get isSmallBusiness => scheme != VatScheme.standard;

  /// Kurzbezeichnung für Chips und Termine, z. B. „DE“.
  String get shortLabel => country.code;

  /// Gilt die Registrierung an [day]?
  bool activeOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    if (validFrom != null && d.isBefore(validFrom!)) return false;
    if (validTo != null && d.isAfter(validTo!)) return false;
    return true;
  }

  /// Überschneidet sich der Zeitraum [from] bis [to] mit der Gültigkeit?
  bool overlaps(DateTime from, DateTime to) =>
      !(validFrom != null && to.isBefore(validFrom!)) &&
      !(validTo != null && from.isAfter(validTo!));

  TaxRegistration copyWith({
    int? id,
    Country? country,
    String? vatId,
    String? taxNumber,
    String? taxOffice,
    VatScheme? scheme,
    FilingInterval? interval,
    bool? permanentExtension,
    DateTime? validFrom,
    bool clearValidFrom = false,
    DateTime? validTo,
    bool clearValidTo = false,
  }) => TaxRegistration(
    id: id ?? this.id,
    country: country ?? this.country,
    vatId: vatId ?? this.vatId,
    taxNumber: taxNumber ?? this.taxNumber,
    taxOffice: taxOffice ?? this.taxOffice,
    scheme: scheme ?? this.scheme,
    interval: interval ?? this.interval,
    permanentExtension: permanentExtension ?? this.permanentExtension,
    validFrom: clearValidFrom ? null : (validFrom ?? this.validFrom),
    validTo: clearValidTo ? null : (validTo ?? this.validTo),
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'country_code': country.code,
    'vat_id': vatId,
    'tax_number': taxNumber,
    'tax_office': taxOffice,
    'scheme': scheme.name,
    'filing_interval': interval.name,
    'permanent_extension': permanentExtension ? 1 : 0,
    'valid_from': _day(validFrom),
    'valid_to': _day(validTo),
  };

  static TaxRegistration fromMap(Map<String, Object?> m) => TaxRegistration(
    id: m['id'] as int?,
    country: Country.fromCode(m['country_code'] as String? ?? 'DE'),
    vatId: m['vat_id'] as String? ?? '',
    taxNumber: m['tax_number'] as String? ?? '',
    taxOffice: m['tax_office'] as String? ?? '',
    scheme: VatScheme.fromName(m['scheme'] as String?),
    interval: FilingInterval.fromName(m['filing_interval'] as String?),
    permanentExtension: (m['permanent_extension'] as int? ?? 0) == 1,
    validFrom: _parse(m['valid_from']),
    validTo: _parse(m['valid_to']),
  );

  static String? _day(DateTime? d) => d?.toIso8601String().substring(0, 10);
  static DateTime? _parse(Object? v) =>
      v is String && v.isNotEmpty ? DateTime.parse(v) : null;
}
