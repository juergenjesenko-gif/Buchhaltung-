import '../domain/company_profile.dart';
import '../domain/customer.dart';
import '../domain/money.dart';

/// Pflichtangaben einer Rechnung, die vom Betrag abhängen. Länderunterschiede
/// nur über `TaxProfile` (CLAUDE.md, Regel 5).
class InvoiceRequirements {
  const InvoiceRequirements._();

  /// Fehlende Angaben für eine Rechnung über [gross] an [customer].
  /// Kleinunternehmer weisen keine Steuer aus und sind nicht betroffen.
  static List<String> missing({
    required CompanyProfile profile,
    required Customer customer,
    required Money gross,
    required bool isSmallBusiness,
  }) {
    final tax = profile.taxProfile;
    final limit = tax.largeInvoiceVatIdLimit;
    if (isSmallBusiness || limit == null || gross <= limit) return const [];
    return [
      if (profile.vatId.trim().isEmpty)
        'Eigene ${tax.vatIdLabel} (Rechnung über ${limit.cents ~/ 100} € brutto)',
      if (customer.vatId.trim().isEmpty)
        '${tax.vatIdLabel} des Kunden (Rechnung über ${limit.cents ~/ 100} € brutto)',
    ];
  }
}
