import '../domain/company_profile.dart';
import '../domain/customer.dart';
import '../domain/money.dart';

/// Pflichtangaben einer Rechnung, die vom Betrag abhängen. Länderunterschiede
/// nur über `TaxProfile` (CLAUDE.md, Regel 5).
class InvoiceRequirements {
  const InvoiceRequirements._();

  /// Fehlende Angaben für eine Rechnung über [gross] an [customer], die das
  /// Ausstellen sperren. Kleinunternehmer weisen keine Steuer aus und sind
  /// nicht betroffen. Die UID des Kunden sperrt nicht (siehe [warnings]).
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
    ];
  }

  /// Hinweise, die das Ausstellen **nicht** sperren (FA-5.50).
  ///
  /// AT: Über 10.000 € brutto gehört die UID des Empfängers auf die Rechnung,
  /// aber nur, wenn er Unternehmer ist (§ 11 Abs 1 Z 3 lit i UStG 1994;
  /// UStR Rz 1508a). Fehlt sie, bleibt die Rechnung ein gültiger Beleg; der
  /// Kunde kann die Vorsteuer erst nach einer Berichtigung (§ 11 Abs 1
  /// UStG 1994, EuGH C-518/14 Senatex) sicher abziehen. Ob der Kunde
  /// Unternehmer ist, weiß die App nicht verlässlich – daher Hinweis statt
  /// Sperre (Entscheidung Auftraggeber 2026-10-24).
  static List<String> warnings({
    required CompanyProfile profile,
    required Customer customer,
    required Money gross,
    required bool isSmallBusiness,
  }) {
    final tax = profile.taxProfile;
    final limit = tax.largeInvoiceVatIdLimit;
    if (isSmallBusiness || limit == null || gross <= limit) return const [];
    if (customer.vatId.trim().isNotEmpty) return const [];
    return [
      '${tax.vatIdLabel} des Kunden fehlt (Rechnung über '
          '${limit.cents ~/ 100} € brutto). Ist der Kunde Unternehmer, '
          'trag sie unter „Kunde bearbeiten“ ein. Ausstellen geht trotzdem – '
          'die UID kann per Berichtigung nachgereicht werden.',
    ];
  }
}
