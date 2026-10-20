/// Buchungsregeln für gemischt genutzte Ausgaben (FA-20.1 ff., Entscheidung
/// Auftraggeber 2026-10-20, Lastenheft 14a): z. B. Privat-PKW teilweise
/// betrieblich oder ein Büro in der eigenen Wohnung. Eine Regel legt den
/// betrieblichen Anteil in Promille fest; für passende Ausgaben im
/// Gültigkeitszeitraum zählt nur dieser Anteil in der Einnahmen-Ausgaben-
/// Rechnung, der Rest ist Privatanteil.
library;

/// Wie die Nutzerin den Anteil denkt. Gespeichert wird immer der
/// betriebliche Anteil; die Art bestimmt nur Eingabe und Anzeige.
enum BookingRuleType {
  /// „30 % privat“ (z. B. Privatanteil am Firmen-PKW).
  privateShare('Privatanteil'),

  /// „30 % betrieblich“ (z. B. Privat-PKW, Büro in der Wohnung).
  businessShare('Betrieblicher Anteil');

  const BookingRuleType(this.label);
  final String label;
}

/// Grundlage des Anteils (Nachweis für die Steuerberatung).
enum BookingRuleBasis {
  /// Fahrtenbuch: betriebliche und gesamte Kilometer.
  logbook('Fahrtenbuch', 'km betrieblich', 'km gesamt'),

  /// Fläche: Büro und Wohnung in m².
  area('Fläche', 'm² Büro', 'm² gesamt'),

  /// Schätzung ohne Zahlen.
  estimate('Schätzung', '', ''),

  /// Sonstige Grundlage, Zahlen freiwillig.
  other('Sonstige', 'Anteil betrieblich', 'gesamt');

  const BookingRuleBasis(this.label, this.partLabel, this.totalLabel);
  final String label;
  final String partLabel;
  final String totalLabel;

  /// Der Anteil ergibt sich aus den Zahlen (Teil / gesamt).
  bool get computesShare => this == logbook || this == area;
}

/// Welche Steuerländer eine Regel umfasst (FA-18.4).
enum BookingRuleRegistration { all, home, one }

class BookingRule {
  const BookingRule({
    this.id,
    required this.name,
    this.type = BookingRuleType.businessShare,
    this.categoryIds = const {},
    this.supplier = '',
    this.registration = BookingRuleRegistration.all,
    this.registrationId,
    required this.businessPermille,
    this.basis = BookingRuleBasis.estimate,
    this.basisPartMilli,
    this.basisTotalMilli,
    required this.validFrom,
    this.validTo,
    required this.comment,
    this.createdAt,
  });

  final int? id;
  final String name;
  final BookingRuleType type;

  /// Kategorien; leer = jede Kategorie (dann muss [supplier] gesetzt sein).
  final Set<int> categoryIds;

  /// Lieferant (Teil des Namens, ohne Groß-/Kleinschreibung); leer = jeder.
  final String supplier;
  final BookingRuleRegistration registration;

  /// Nur bei [BookingRuleRegistration.one].
  final int? registrationId;

  /// Betrieblicher Anteil in Promille (0 bis 1000).
  final int businessPermille;
  final BookingRuleBasis basis;

  /// Zahlen der Grundlage in Tausendsteln (km bzw. m², GR-3).
  final int? basisPartMilli;
  final int? basisTotalMilli;
  final DateTime validFrom;

  /// Einschließlich; `null` = unbefristet.
  final DateTime? validTo;

  /// Begründung (Pflicht): was die Steuerberatung wissen muss.
  final String comment;
  final DateTime? createdAt;

  int get privatePermille => 1000 - businessPermille;

  /// Anteil aus den Zahlen der Grundlage, kaufmännisch auf Promille
  /// gerundet; `null`, wenn die Zahlen fehlen oder ungültig sind.
  static int? shareFromBasis(int? partMilli, int? totalMilli) {
    if (partMilli == null || totalMilli == null) return null;
    if (totalMilli <= 0 || partMilli < 0 || partMilli > totalMilli) {
      return null;
    }
    return (partMilli * 1000 * 2 + totalMilli) ~/ (totalMilli * 2);
  }

  /// Kurzanzeige an der Buchung, z. B. „PKW 30 % betrieblich“.
  String get shortLabel =>
      '$name ${formatPermille(businessPermille)} betrieblich';

  bool isValidOn(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final from = DateTime(validFrom.year, validFrom.month, validFrom.day);
    if (d.isBefore(from)) return false;
    final to = validTo;
    if (to == null) return true;
    return !d.isAfter(DateTime(to.year, to.month, to.day));
  }

  /// Ob eine Ausgabe in den Geltungsbereich fällt.
  bool matches(BookingFacts f) {
    if (!f.isExpense || !isValidOn(f.date)) return false;
    if (categoryIds.isEmpty && supplier.trim().isEmpty) return false;
    if (categoryIds.isNotEmpty &&
        (f.categoryId == null || !categoryIds.contains(f.categoryId))) {
      return false;
    }
    final s = supplier.trim().toLowerCase();
    if (s.isNotEmpty && !f.counterparty.toLowerCase().contains(s)) {
      return false;
    }
    return switch (registration) {
      BookingRuleRegistration.all => true,
      BookingRuleRegistration.home => f.taxRegistrationId == null,
      BookingRuleRegistration.one => f.taxRegistrationId == registrationId,
    };
  }

  /// Fehlermeldungen beim Speichern; leer = gültig.
  List<String> validate() => [
    if (name.trim().isEmpty) 'Bitte einen Namen eingeben.',
    if (comment.trim().isEmpty)
      'Bitte kurz begründen – das liest die Steuerberatung.',
    if (businessPermille < 0 || businessPermille > 1000)
      'Der Anteil muss zwischen 0 und 100 % liegen.',
    if (categoryIds.isEmpty && supplier.trim().isEmpty)
      'Bitte mindestens eine Kategorie oder einen Lieferanten wählen.',
    if (validTo != null && validTo!.isBefore(validFrom))
      '„Gültig bis“ liegt vor „Gültig ab“.',
    if (basis.computesShare &&
        shareFromBasis(basisPartMilli, basisTotalMilli) == null)
      'Bitte beide Zahlen eingeben (Teil höchstens so groß wie gesamt).',
  ];

  BookingRule copyWith({
    int? id,
    String? name,
    BookingRuleType? type,
    Set<int>? categoryIds,
    String? supplier,
    BookingRuleRegistration? registration,
    int? registrationId,
    int? businessPermille,
    BookingRuleBasis? basis,
    int? basisPartMilli,
    int? basisTotalMilli,
    DateTime? validFrom,
    DateTime? validTo,
    bool clearValidTo = false,
    String? comment,
  }) => BookingRule(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    categoryIds: categoryIds ?? this.categoryIds,
    supplier: supplier ?? this.supplier,
    registration: registration ?? this.registration,
    registrationId: registrationId ?? this.registrationId,
    businessPermille: businessPermille ?? this.businessPermille,
    basis: basis ?? this.basis,
    basisPartMilli: basisPartMilli ?? this.basisPartMilli,
    basisTotalMilli: basisTotalMilli ?? this.basisTotalMilli,
    validFrom: validFrom ?? this.validFrom,
    validTo: clearValidTo ? null : (validTo ?? this.validTo),
    comment: comment ?? this.comment,
    createdAt: createdAt,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name.trim(),
    'rule_type': type.name,
    'category_ids': (categoryIds.toList()..sort()).join(','),
    'supplier': supplier.trim(),
    'registration': registration.name,
    'registration_id': registrationId,
    'business_permille': businessPermille,
    'basis': basis.name,
    'basis_part_milli': basisPartMilli,
    'basis_total_milli': basisTotalMilli,
    'valid_from': _day(validFrom),
    'valid_to': validTo == null ? null : _day(validTo!),
    'comment': comment.trim(),
  };

  static BookingRule fromMap(Map<String, Object?> m) => BookingRule(
    id: m['id'] as int?,
    name: m['name'] as String? ?? '',
    type: BookingRuleType.values.firstWhere(
      (t) => t.name == m['rule_type'],
      orElse: () => BookingRuleType.businessShare,
    ),
    categoryIds: {
      for (final p in ((m['category_ids'] as String?) ?? '').split(','))
        if (int.tryParse(p.trim()) != null) int.parse(p.trim()),
    },
    supplier: m['supplier'] as String? ?? '',
    registration: BookingRuleRegistration.values.firstWhere(
      (r) => r.name == m['registration'],
      orElse: () => BookingRuleRegistration.all,
    ),
    registrationId: m['registration_id'] as int?,
    businessPermille: m['business_permille'] as int? ?? 1000,
    basis: BookingRuleBasis.values.firstWhere(
      (b) => b.name == m['basis'],
      orElse: () => BookingRuleBasis.other,
    ),
    basisPartMilli: m['basis_part_milli'] as int?,
    basisTotalMilli: m['basis_total_milli'] as int?,
    validFrom: DateTime.parse(m['valid_from'] as String),
    validTo: m['valid_to'] == null
        ? null
        : DateTime.parse(m['valid_to'] as String),
    comment: m['comment'] as String? ?? '',
    createdAt: m['created_at'] == null
        ? null
        : DateTime.parse(m['created_at'] as String),
  );

  static String _day(DateTime d) => d.toIso8601String().substring(0, 10);
}

/// Promille als Prozent mit höchstens einer Nachkommastelle („12,5 %“).
String formatPermille(int permille) {
  final whole = permille ~/ 10;
  final tenth = permille % 10;
  return tenth == 0 ? '$whole %' : '$whole,$tenth %';
}

/// Die Angaben einer Buchung, die für den Geltungsbereich zählen.
class BookingFacts {
  const BookingFacts({
    required this.date,
    required this.isExpense,
    required this.categoryId,
    required this.counterparty,
    required this.taxRegistrationId,
  });

  final DateTime date;
  final bool isExpense;
  final int? categoryId;
  final String counterparty;
  final int? taxRegistrationId;
}

/// Anhang einer Regel (Fahrtenbuch, Grundriss …), wie ein Belegfoto im
/// Ordner der Belege gespeichert. Nur anhängbar.
class BookingRuleAttachment {
  const BookingRuleAttachment({
    this.id,
    required this.ruleId,
    required this.filePath,
    required this.fileName,
    this.note = '',
    required this.createdAt,
  });

  final int? id;
  final int ruleId;

  /// Relativer Pfad (`ReceiptImageStore`).
  final String filePath;
  final String fileName;

  /// z. B. „Büro im Grundriss rot markiert, 12 m²“.
  final String note;
  final DateTime createdAt;

  static BookingRuleAttachment fromMap(Map<String, Object?> m) =>
      BookingRuleAttachment(
        id: m['id'] as int?,
        ruleId: m['rule_id'] as int,
        filePath: m['file_path'] as String,
        fileName: m['file_name'] as String? ?? '',
        note: m['note'] as String? ?? '',
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

/// Unveränderlicher Verlaufseintrag (angelegt, geändert, Anhang, Ausnahme).
class BookingRuleLogEntry {
  const BookingRuleLogEntry({
    required this.ruleId,
    required this.text,
    required this.createdAt,
  });

  final int ruleId;
  final String text;
  final DateTime createdAt;

  static BookingRuleLogEntry fromMap(Map<String, Object?> m) =>
      BookingRuleLogEntry(
        ruleId: m['rule_id'] as int,
        text: m['text'] as String? ?? '',
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
