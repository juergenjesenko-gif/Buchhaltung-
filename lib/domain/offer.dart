import 'invoice.dart';
import 'money.dart';

/// Status eines Angebots (Lastenheft L-3.16). „Offen“ im Lastenheft sind
/// [draft] und [sent]. [expired] wird nie gespeichert, sondern aus dem
/// Gültigkeitsdatum abgeleitet ([Offer.statusOn]).
enum OfferStatus {
  draft('Entwurf'),
  sent('Gesendet'),
  accepted('Angenommen'),
  rejected('Abgelehnt'),
  expired('Abgelaufen');

  const OfferStatus(this.label);
  final String label;

  static OfferStatus fromName(String? name) => OfferStatus.values.firstWhere(
    (s) => s.name == name && s != OfferStatus.expired,
    orElse: () => OfferStatus.draft,
  );

  /// Offen: noch keine Antwort der Kundin.
  bool get isOpen => this == draft || this == sent;
}

/// Ein Angebot (Lastenheft L-3.13 bis L-3.17). Hat **keine steuerliche
/// Wirkung** (L-3.14): keine Buchung, kein Kassabuch, keine UVA, keine
/// Grenzwertüberwachung. Positionen rechnen wie Rechnungspositionen.
class Offer {
  const Offer({
    this.id,
    required this.number,
    required this.issueDate,
    required this.validUntil,
    required this.customerId,
    required this.items,
    this.status = OfferStatus.draft,
    this.isSmallBusiness = false,
    this.notes = '',
    this.invoiceId,
    this.createdAt,
  });

  final int? id;

  /// Eigener Nummernkreis `AN-{YYYY}-{NNNN}` (L-3.13), unabhängig von den
  /// Rechnungsnummern; vergeben beim ersten Speichern.
  final String number;
  final DateTime issueDate;

  /// Gültig bis einschließlich dieses Tages (L-3.16).
  final DateTime validUntil;
  final int customerId;
  final List<InvoiceItem> items;

  /// Gespeicherter Status; abgelaufen ist ein Angebot über [statusOn].
  final OfferStatus status;
  final bool isSmallBusiness;
  final String notes;

  /// Rechnungsentwurf, in den das Angebot umgewandelt wurde (L-3.15).
  final int? invoiceId;
  final DateTime? createdAt;

  /// Angenommene Angebote sind schreibgeschützt; die Arbeit geht in der
  /// Rechnung weiter.
  bool get isLocked => status == OfferStatus.accepted;

  /// Status am Tag [today]: offene Angebote nach dem Gültigkeitsdatum gelten
  /// als abgelaufen.
  OfferStatus statusOn(DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    final last = DateTime(validUntil.year, validUntil.month, validUntil.day);
    return status.isOpen && day.isAfter(last) ? OfferStatus.expired : status;
  }

  /// Rechenansicht als Rechnung – nur für Summen und PDF, nie gespeichert.
  Invoice get asInvoice => Invoice(
    number: number,
    issueDate: issueDate,
    customerId: customerId,
    items: items,
    isSmallBusiness: isSmallBusiness,
    notes: notes,
  );

  Money get netTotal => asInvoice.netTotal;
  Money get grossTotal => asInvoice.grossTotal;

  Offer copyWith({
    int? id,
    String? number,
    DateTime? issueDate,
    DateTime? validUntil,
    int? customerId,
    List<InvoiceItem>? items,
    OfferStatus? status,
    bool? isSmallBusiness,
    String? notes,
    int? invoiceId,
  }) => Offer(
    id: id ?? this.id,
    number: number ?? this.number,
    issueDate: issueDate ?? this.issueDate,
    validUntil: validUntil ?? this.validUntil,
    customerId: customerId ?? this.customerId,
    items: items ?? this.items,
    status: status ?? this.status,
    isSmallBusiness: isSmallBusiness ?? this.isSmallBusiness,
    notes: notes ?? this.notes,
    invoiceId: invoiceId ?? this.invoiceId,
    createdAt: createdAt,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'number': number,
    'issue_date': _day(issueDate),
    'valid_until': _day(validUntil),
    'customer_id': customerId,
    'status': status == OfferStatus.expired ? 'sent' : status.name,
    'is_small_business': isSmallBusiness ? 1 : 0,
    'notes': notes,
    'invoice_id': invoiceId,
    'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
  };

  static Offer fromMap(Map<String, Object?> map, List<InvoiceItem> items) =>
      Offer(
        id: map['id'] as int?,
        number: map['number'] as String? ?? '',
        issueDate: DateTime.parse(map['issue_date'] as String),
        validUntil: DateTime.parse(map['valid_until'] as String),
        customerId: map['customer_id'] as int? ?? 0,
        items: items,
        status: OfferStatus.fromName(map['status'] as String?),
        isSmallBusiness: (map['is_small_business'] as int? ?? 0) == 1,
        notes: map['notes'] as String? ?? '',
        invoiceId: map['invoice_id'] as int?,
        createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
      );

  static String _day(DateTime d) => d.toIso8601String().substring(0, 10);
}

/// Feste Vorgaben für Angebote (Spezifikation FA-5.40 ff., Abschnitt 12).
class OfferPolicy {
  const OfferPolicy._();

  /// Nummernmuster, eigener Kreis je Kalenderjahr (L-3.13).
  static const numberPattern = 'AN-{YYYY}-{NNNN}';

  /// Vorbelegte Gültigkeit ab Angebotsdatum. Ein Angebot bindet nur „bis
  /// zu dem Zeitpunkt, in welchem der Antragsteller unter regelmäßigen
  /// Umständen die Antwort erwarten darf“ (§ 147 Abs 2 BGB, § 862 ABGB);
  /// ein ausdrückliches Datum schafft Klarheit.
  static const defaultValidityDays = 30;
}
