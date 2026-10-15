import '../domain/invoice.dart';

/// Hilfen rund um Stornorechnung und Rechnungskorrektur (L-3.7).
/// Die Buchung selbst liegt in `InvoiceRepository.cancelWithInvoice`.
class InvoiceCancellation {
  const InvoiceCancellation._();

  /// Vorschläge für den Grund, ein Tipp übernimmt (Leitprinzip).
  static const reasonSuggestions = [
    'Fehler in der Rechnung',
    'Auftrag storniert',
    'Rechnung doppelt gestellt',
  ];

  /// Neuer Entwurf als Kopie der stornierten Rechnung für „Korrigieren“:
  /// gleicher Kunde, gleiche Positionen, Rabatt, Versand und Skonto,
  /// Rechnungsdatum [today], Zahlungsziel mit gleichem Abstand. Nummer und
  /// eingefrorene Stammdaten entstehen erst beim Ausstellen neu (GR-8).
  static Invoice correctionDraft(Invoice original, DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    final dueOffset = original.dueDate?.difference(original.issueDate);
    return Invoice(
      number: 'ENTWURF-${DateTime.now().microsecondsSinceEpoch}',
      issueDate: day,
      deliveryDate: original.deliveryDate,
      dueDate: dueOffset == null ? null : day.add(dueOffset),
      customerId: original.customerId,
      // `InvoiceRepository.save` legt die Positionen neu an (ohne alte ID).
      items: [...original.items],
      isSmallBusiness: original.isSmallBusiness,
      notes: original.notes,
      discountPermille: original.discountPermille,
      discountAmount: original.discountAmount,
      shipping: original.shipping,
      shippingVatPermille: original.shippingVatPermille,
      skontoDays: original.skontoDays,
      skontoPermille: original.skontoPermille,
    );
  }
}
