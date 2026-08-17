import 'money.dart';

enum InvoiceStatus {
  draft('Entwurf'),
  issued('Gestellt'),
  paid('Bezahlt'),
  cancelled('Storniert');

  const InvoiceStatus(this.label);
  final String label;

  static InvoiceStatus fromName(String? name) => InvoiceStatus.values
      .firstWhere((s) => s.name == name, orElse: () => InvoiceStatus.draft);

  /// Ab dem Zeitpunkt der Ausstellung darf eine Rechnung inhaltlich nicht mehr
  /// verändert werden – Korrekturen laufen über eine Storno-/Gutschriftsrechnung.
  bool get isLocked => this != InvoiceStatus.draft;
}

/// Eine Rechnungsposition. Menge wird als Tausendstel gespeichert, damit
/// Teilmengen (0,25 Stunden) exakt bleiben.
class InvoiceItem {
  const InvoiceItem({
    this.id,
    this.invoiceId,
    required this.position,
    required this.description,
    required this.quantityMilli,
    required this.unitPrice,
    required this.vatPermille,
    this.unit = 'Stk',
  });

  final int? id;
  final int? invoiceId;
  final int position;
  final String description;

  /// Menge × 1000. 1500 entspricht 1,5 Einheiten.
  final int quantityMilli;

  final String unit;

  /// Nettopreis pro Einheit.
  final Money unitPrice;

  final int vatPermille;

  double get quantity => quantityMilli / 1000;

  /// Nettobetrag der Position, kaufmännisch auf ganze Cent gerundet.
  Money get net => Money((unitPrice.cents * quantityMilli / 1000).round());

  /// Umsatzsteuer der Position. Die Rundung passiert bewusst pro Position und
  /// nicht erst auf der Summe – so stimmt der ausgewiesene Steuerbetrag mit der
  /// Summe der Positionen überein.
  Money get vat => Money((net.cents * vatPermille / 1000).round());

  Money get gross => net + vat;

  InvoiceItem copyWith({
    int? id,
    int? invoiceId,
    int? position,
    String? description,
    int? quantityMilli,
    String? unit,
    Money? unitPrice,
    int? vatPermille,
  }) {
    return InvoiceItem(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      position: position ?? this.position,
      description: description ?? this.description,
      quantityMilli: quantityMilli ?? this.quantityMilli,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      vatPermille: vatPermille ?? this.vatPermille,
    );
  }

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'invoice_id': invoiceId,
    'position': position,
    'description': description,
    'quantity_milli': quantityMilli,
    'unit': unit,
    'unit_price_cents': unitPrice.cents,
    'vat_permille': vatPermille,
  };

  static InvoiceItem fromMap(Map<String, Object?> map) => InvoiceItem(
    id: map['id'] as int?,
    invoiceId: map['invoice_id'] as int?,
    position: map['position'] as int? ?? 1,
    description: map['description'] as String? ?? '',
    quantityMilli: map['quantity_milli'] as int? ?? 1000,
    unit: map['unit'] as String? ?? 'Stk',
    unitPrice: Money(map['unit_price_cents'] as int? ?? 0),
    vatPermille: map['vat_permille'] as int? ?? 0,
  );
}

/// Eine Ausgangsrechnung mit ihren Positionen.
class Invoice {
  const Invoice({
    this.id,
    required this.number,
    required this.issueDate,
    required this.customerId,
    required this.items,
    this.deliveryDate,
    this.dueDate,
    this.status = InvoiceStatus.draft,
    this.isSmallBusiness = false,
    this.notes = '',
    this.sellerSnapshot,
    this.customerSnapshot,
    this.paidAt,
    this.createdAt,
  });

  final int? id;

  /// Fortlaufende Rechnungsnummer. Bei Entwürfen vorläufig, endgültig vergeben
  /// wird sie erst beim Ausstellen.
  final String number;

  final DateTime issueDate;

  /// Liefer- bzw. Leistungsdatum. Pflichtangabe – fehlt sie, ist die Rechnung
  /// formal mangelhaft und der Empfänger verliert den Vorsteuerabzug.
  final DateTime? deliveryDate;

  final DateTime? dueDate;
  final int customerId;
  final List<InvoiceItem> items;
  final InvoiceStatus status;

  /// Momentaufnahme: War der Aussteller bei Rechnungslegung Kleinunternehmer?
  /// Ein späterer Wechsel darf alte Rechnungen nicht rückwirkend verändern.
  final bool isSmallBusiness;

  final String notes;

  /// Eingefrorene Aussteller-/Empfängerdaten als JSON. Rechnungen müssen auch
  /// dann noch korrekt darstellbar sein, wenn sich Stammdaten später ändern.
  final String? sellerSnapshot;
  final String? customerSnapshot;

  final DateTime? paidAt;
  final DateTime? createdAt;

  Money get netTotal => items.map((i) => i.net).sum;
  Money get vatTotal =>
      isSmallBusiness ? const Money.zero() : items.map((i) => i.vat).sum;
  Money get grossTotal => netTotal + vatTotal;

  bool get isOverdue =>
      status == InvoiceStatus.issued &&
      dueDate != null &&
      dueDate!.isBefore(DateTime.now());

  /// Umsatzsteuer je Steuersatz – so muss sie auf der Rechnung ausgewiesen und
  /// in der UVA gemeldet werden.
  Map<int, ({Money net, Money vat})> get vatBreakdown {
    final result = <int, ({Money net, Money vat})>{};
    if (isSmallBusiness) {
      return {0: (net: netTotal, vat: const Money.zero())};
    }
    for (final item in items) {
      final existing = result[item.vatPermille];
      result[item.vatPermille] = existing == null
          ? (net: item.net, vat: item.vat)
          : (net: existing.net + item.net, vat: existing.vat + item.vat);
    }
    return result;
  }

  Invoice copyWith({
    int? id,
    String? number,
    DateTime? issueDate,
    DateTime? deliveryDate,
    DateTime? dueDate,
    int? customerId,
    List<InvoiceItem>? items,
    InvoiceStatus? status,
    bool? isSmallBusiness,
    String? notes,
    String? sellerSnapshot,
    String? customerSnapshot,
    DateTime? paidAt,
    DateTime? createdAt,
  }) {
    return Invoice(
      id: id ?? this.id,
      number: number ?? this.number,
      issueDate: issueDate ?? this.issueDate,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      dueDate: dueDate ?? this.dueDate,
      customerId: customerId ?? this.customerId,
      items: items ?? this.items,
      status: status ?? this.status,
      isSmallBusiness: isSmallBusiness ?? this.isSmallBusiness,
      notes: notes ?? this.notes,
      sellerSnapshot: sellerSnapshot ?? this.sellerSnapshot,
      customerSnapshot: customerSnapshot ?? this.customerSnapshot,
      paidAt: paidAt ?? this.paidAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'number': number,
    'issue_date': issueDate.toIso8601String().substring(0, 10),
    'delivery_date': deliveryDate?.toIso8601String().substring(0, 10),
    'due_date': dueDate?.toIso8601String().substring(0, 10),
    'customer_id': customerId,
    'status': status.name,
    'is_small_business': isSmallBusiness ? 1 : 0,
    'notes': notes,
    'seller_snapshot': sellerSnapshot,
    'customer_snapshot': customerSnapshot,
    'paid_at': paidAt?.toIso8601String(),
    'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
  };

  static Invoice fromMap(Map<String, Object?> map, List<InvoiceItem> items) =>
      Invoice(
        id: map['id'] as int?,
        number: map['number'] as String? ?? '',
        issueDate: DateTime.parse(map['issue_date'] as String),
        deliveryDate: _parseOrNull(map['delivery_date']),
        dueDate: _parseOrNull(map['due_date']),
        customerId: map['customer_id'] as int? ?? 0,
        items: items,
        status: InvoiceStatus.fromName(map['status'] as String?),
        isSmallBusiness: (map['is_small_business'] as int? ?? 0) == 1,
        notes: map['notes'] as String? ?? '',
        sellerSnapshot: map['seller_snapshot'] as String?,
        customerSnapshot: map['customer_snapshot'] as String?,
        paidAt: _parseOrNull(map['paid_at']),
        createdAt: _parseOrNull(map['created_at']),
      );

  static DateTime? _parseOrNull(Object? value) =>
      value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;
}
