import '../services/invoice_totals.dart';
import 'money.dart';

enum InvoiceStatus {
  draft('Entwurf'),
  issued('Gestellt'),
  paid('Bezahlt'),
  cancelled('Storniert'),

  /// Die Stornorechnung selbst (L-3.7): eigener Beleg mit eigener Nummer,
  /// negativen Beträgen und Verweis auf die Originalrechnung.
  cancellation('Stornorechnung');

  const InvoiceStatus(this.label);
  final String label;

  static InvoiceStatus fromName(String? name) => InvoiceStatus.values
      .firstWhere((s) => s.name == name, orElse: () => InvoiceStatus.draft);

  /// Ab dem Zeitpunkt der Ausstellung darf eine Rechnung inhaltlich nicht mehr
  /// verändert werden – Korrekturen laufen über eine Stornorechnung (L-3.7).
  bool get isLocked => this != InvoiceStatus.draft;

  /// Darf storniert werden: gestellt oder bezahlt, nicht schon storniert und
  /// nicht selbst eine Stornorechnung.
  bool get canBeCancelled =>
      this == InvoiceStatus.issued || this == InvoiceStatus.paid;
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
    this.discountPermille = 0,
    this.discountAmount = const Money.zero(),
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

  /// Positionsrabatt in Promille des Positionsbetrags (L-3.21). 0 = keiner.
  final int discountPermille;

  /// Positionsrabatt als fester Betrag; gilt nur, wenn [discountPermille] 0
  /// ist. Höchstens der Positionsbetrag.
  final Money discountAmount;

  double get quantity => quantityMilli / 1000;

  /// Menge × Einzelpreis vor Rabatt, kaufmännisch auf ganze Cent gerundet.
  Money get lineAmount =>
      Money(divideRounded(unitPrice.cents * quantityMilli, 1000));

  /// Positionsrabatt als positiver Betrag.
  Money get discount {
    final line = lineAmount.cents;
    if (discountPermille > 0) {
      return Money(divideRounded(line * discountPermille, 1000));
    }
    if (discountAmount.cents <= 0) return const Money.zero();
    return Money(discountAmount.cents > line ? line : discountAmount.cents);
  }

  bool get hasDiscount => !discount.isZero;

  /// Entgelt der Position nach Positionsrabatt.
  Money get net => lineAmount - discount;

  /// Umsatzsteuer der Position. Die Rundung passiert bewusst pro Position und
  /// nicht erst auf der Summe – so stimmt der ausgewiesene Steuerbetrag mit der
  /// Summe der Positionen überein.
  Money get vat => Money(divideRounded(net.cents * vatPermille, 1000));

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
    int? discountPermille,
    Money? discountAmount,
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
      discountPermille: discountPermille ?? this.discountPermille,
      discountAmount: discountAmount ?? this.discountAmount,
    );
  }

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'invoice_id': invoiceId,
    'discount_permille': discountPermille,
    'discount_cents': discountAmount.cents,
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
    discountPermille: map['discount_permille'] as int? ?? 0,
    discountAmount: Money(map['discount_cents'] as int? ?? 0),
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
    this.discountPermille = 0,
    this.discountAmount = const Money.zero(),
    this.shipping = const Money.zero(),
    this.shippingVatPermille,
    this.skontoDays = 0,
    this.skontoPermille = 0,
    this.skontoTaken = const Money.zero(),
    this.cancelsInvoiceId,
    this.cancelsNumber = '',
    this.cancelsIssueDate,
    this.cancelReason = '',
    this.cancelledByInvoiceId,
  });

  final int? id;

  /// Nur bei einer Stornorechnung (L-3.7, Schema 18): die stornierte
  /// Originalrechnung samt eingefrorener Nummer und Datum für den Bezug
  /// auf dem Beleg (§ 11 UStG AT, § 14 Abs 4, § 31 Abs 5 UStDV DE).
  final int? cancelsInvoiceId;
  final String cancelsNumber;
  final DateTime? cancelsIssueDate;

  /// Grund des Stornos, steht auf der Stornorechnung.
  final String cancelReason;

  /// Nur bei der Originalrechnung: die Stornorechnung, die sie aufhebt.
  final int? cancelledByInvoiceId;

  bool get isCancellation => cancelsInvoiceId != null;

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

  /// Gesamtrabatt in Promille der Positionssumme (L-3.21). 0 = keiner.
  final int discountPermille;

  /// Gesamtrabatt als Betrag; gilt nur, wenn [discountPermille] 0 ist.
  final Money discountAmount;

  /// Versandkosten netto (L-3.22).
  final Money shipping;

  /// Steuersatz der Versandkosten; `null` = wie Hauptleistung (anteilig).
  final int? shippingVatPermille;

  /// Skonto: Tage ab Rechnungsdatum und Satz in Promille (L-3.23).
  final int skontoDays;
  final int skontoPermille;

  /// Beim Zahlungseingang abgezogenes Skonto; 0 = ohne Skonto bezahlt.
  /// Die Rechnung selbst bleibt unverändert (GR-8).
  final Money skontoTaken;

  bool get hasSkonto => skontoDays > 0 && skontoPermille > 0;

  /// Letzter Tag, an dem mit Skonto gezahlt werden darf.
  DateTime? get skontoDate => hasSkonto
      ? DateTime(issueDate.year, issueDate.month, issueDate.day + skontoDays)
      : null;

  /// Summen samt Rabatt, Versand und Steuer je Satz.
  InvoiceTotals get totals => InvoiceTotals.of(this);

  Money get netTotal => totals.net;
  Money get vatTotal => totals.vat;
  Money get grossTotal => totals.gross;

  /// Skontobetrag laut Rechnung.
  Money get skontoAmount => totals.skontoAmount(skontoPermille);

  bool get isOverdue =>
      status == InvoiceStatus.issued &&
      dueDate != null &&
      dueDate!.isBefore(DateTime.now());

  /// Umsatzsteuer je Steuersatz – so muss sie auf der Rechnung ausgewiesen und
  /// in der UVA gemeldet werden.
  Map<int, ({Money net, Money vat})> get vatBreakdown => totals.breakdown;

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
    int? discountPermille,
    Money? discountAmount,
    Money? shipping,
    int? shippingVatPermille,
    int? skontoDays,
    int? skontoPermille,
    Money? skontoTaken,
    int? cancelsInvoiceId,
    String? cancelsNumber,
    DateTime? cancelsIssueDate,
    String? cancelReason,
    int? cancelledByInvoiceId,
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
      discountPermille: discountPermille ?? this.discountPermille,
      discountAmount: discountAmount ?? this.discountAmount,
      shipping: shipping ?? this.shipping,
      shippingVatPermille: shippingVatPermille ?? this.shippingVatPermille,
      skontoDays: skontoDays ?? this.skontoDays,
      skontoPermille: skontoPermille ?? this.skontoPermille,
      skontoTaken: skontoTaken ?? this.skontoTaken,
      cancelsInvoiceId: cancelsInvoiceId ?? this.cancelsInvoiceId,
      cancelsNumber: cancelsNumber ?? this.cancelsNumber,
      cancelsIssueDate: cancelsIssueDate ?? this.cancelsIssueDate,
      cancelReason: cancelReason ?? this.cancelReason,
      cancelledByInvoiceId: cancelledByInvoiceId ?? this.cancelledByInvoiceId,
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
    'discount_permille': discountPermille,
    'discount_cents': discountAmount.cents,
    'shipping_cents': shipping.cents,
    'shipping_vat_permille': shippingVatPermille,
    'skonto_days': skontoDays,
    'skonto_permille': skontoPermille,
    'skonto_taken_cents': skontoTaken.cents,
    'cancels_invoice_id': cancelsInvoiceId,
    'cancels_number': cancelsNumber,
    'cancels_issue_date': cancelsIssueDate?.toIso8601String().substring(0, 10),
    'cancel_reason': cancelReason,
    'cancelled_by_invoice_id': cancelledByInvoiceId,
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
        discountPermille: map['discount_permille'] as int? ?? 0,
        discountAmount: Money(map['discount_cents'] as int? ?? 0),
        shipping: Money(map['shipping_cents'] as int? ?? 0),
        shippingVatPermille: map['shipping_vat_permille'] as int?,
        skontoDays: map['skonto_days'] as int? ?? 0,
        skontoPermille: map['skonto_permille'] as int? ?? 0,
        skontoTaken: Money(map['skonto_taken_cents'] as int? ?? 0),
        cancelsInvoiceId: map['cancels_invoice_id'] as int?,
        cancelsNumber: map['cancels_number'] as String? ?? '',
        cancelsIssueDate: _parseOrNull(map['cancels_issue_date']),
        cancelReason: map['cancel_reason'] as String? ?? '',
        cancelledByInvoiceId: map['cancelled_by_invoice_id'] as int?,
      );

  static DateTime? _parseOrNull(Object? value) =>
      value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;
}
