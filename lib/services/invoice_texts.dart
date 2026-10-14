import '../core/formatting.dart';
import '../domain/invoice.dart';

/// Textbausteine der Rechnung zu Rabatt, Skonto und AGB (L-3.21 bis L-3.25).
/// An einer Stelle, damit PDF, Formular und Tests denselben Wortlaut nutzen.
class InvoiceTexts {
  const InvoiceTexts._();

  // ---------------------------------------------------------------------------
  // Anrede in Kundendokumenten (Rechnung, Mahnung, Begleittext beim Senden).
  // Die App-Oberfläche duzt, Briefe an Kunden siezen (Vorbelegung bis zur
  // Entscheidung der Auftraggeberin, Gerätetest 0.6.0). Alle Sätze mit
  // Anrede stehen hier, damit eine spätere Umschaltung an einer Stelle
  // ansetzt.
  // ---------------------------------------------------------------------------

  /// Zahlungsaufforderung auf der Rechnung.
  static String transferRequest(String invoiceNumber) =>
      'Bitte überweisen Sie den Betrag unter Angabe der Rechnungsnummer '
      '$invoiceNumber auf folgendes Konto:';

  /// Zahlungsaufforderung im Mahnschreiben.
  static String dunningPay(String total, String until) =>
      'Bitte überweisen Sie den Betrag von $total bis $until.';

  /// Schlusssatz jedes Mahnschreibens.
  static const dunningAlreadyPaid =
      'Falls Sie bereits bezahlt haben, betrachten Sie dieses Schreiben '
      'bitte als gegenstandslos.';

  /// Begleittext beim Senden der Rechnung.
  static String shareInvoice(String number) =>
      'Im Anhang finden Sie die Rechnung $number.';

  /// Begleittext beim Senden einer Erinnerung oder Mahnung.
  static String shareDunning(String title, String number) =>
      'Im Anhang finden Sie die $title zu Rechnung $number.';

  /// Dezenter Hinweis, kein Blocker: Leistungsdatum nach dem
  /// Rechnungsdatum ist zulässig (Vorausrechnung), aber oft ein Tippfehler
  /// (Gerätetest 0.6.0). `null`, wenn kein Hinweis nötig ist.
  static String? deliveryAfterIssueHint(DateTime issue, DateTime? delivery) {
    if (delivery == null) return null;
    final i = DateTime(issue.year, issue.month, issue.day);
    final d = DateTime(delivery.year, delivery.month, delivery.day);
    return d.isAfter(i)
        ? 'Leistungsdatum liegt nach dem Rechnungsdatum – stimmt das?'
        : null;
  }

  /// Prozentsatz aus Promille, z. B. 25 → „2,5 %“, 100 → „10 %“.
  static String percent(int permille) => Fmt.vatRate(permille);

  /// Zusatzzeile unter der Positionsbezeichnung.
  static String itemDiscount(InvoiceItem item) {
    final base =
        'Betrag ${Fmt.amount(item.lineAmount)}, abzgl. Rabatt'
        '${item.discountPermille > 0 ? ' ${percent(item.discountPermille)}' : ''}'
        ' ${Fmt.amount(item.discount)}';
    return base;
  }

  static String invoiceDiscountLabel(Invoice invoice) =>
      invoice.discountPermille > 0
      ? 'abzgl. Rabatt ${percent(invoice.discountPermille)}'
      : 'abzgl. Rabatt';

  /// Zahlungsbedingungen mit festem Datum und Betrag (L-3.23):
  /// „Zahlbar bis 31.10.2026 ohne Abzug. Bei Zahlung bis 24.10.2026 2 %
  /// Skonto (= 3,15 €).“
  static String paymentTerms(Invoice invoice) {
    final parts = <String>[
      if (invoice.dueDate != null)
        'Zahlbar bis ${Fmt.date(invoice.dueDate!)} ohne Abzug.'
      else if (invoice.hasSkonto)
        'Zahlbar ohne Abzug.',
      if (invoice.hasSkonto)
        'Bei Zahlung bis ${Fmt.date(invoice.skontoDate!)} '
            '${percent(invoice.skontoPermille)} Skonto '
            '(= ${Fmt.money(invoice.skontoAmount)}).',
    ];
    return parts.join(' ');
  }

  /// Verweis auf die Verkaufsbedingungen (L-3.25). Bewusst „soweit sie
  /// vereinbart wurden“: der Verweis auf der Rechnung allein bezieht AGB
  /// nicht in den Vertrag ein (P-R30).
  static String termsReference(String url) =>
      'Es gelten unsere Verkaufsbedingungen, abrufbar unter ${url.trim()}, '
      'soweit sie vereinbart wurden.';

  /// Einmaliger Hinweis beim Eintragen der AGB-Adresse (L-3.26).
  static const termsHint =
      'Der Verweis auf der Rechnung allein macht deine AGB nicht wirksam – '
      'binde sie schon im Angebot bzw. bei der Bestellung ein.';
}
