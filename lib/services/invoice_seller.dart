import 'dart:convert';

import '../domain/company_profile.dart';
import '../domain/invoice.dart';

/// Absenderangaben für das PDF einer Rechnung (GR-8, CLAUDE.md Regel 7).
///
/// Gestellte Rechnungen sind unveränderlich: Name, Anschrift, Steuernummer,
/// UID, Firmenbuch, Bankverbindung und Fußzeile kommen aus dem bei der
/// Rechnungslegung eingefrorenen `seller_snapshot`. Spätere Änderungen der
/// Stammdaten wirken nur auf Entwürfe und neue Rechnungen.
///
/// Rückfall für alte Rechnungen: Fehlt der Snapshot ganz oder ist er
/// unlesbar, gilt das aktuelle Profil. Fehlt nur ein Feld (Snapshot aus einer
/// Schemaversion, die das Feld noch nicht kannte, z. B. `register_number` vor
/// Schema 5), gilt für dieses Feld der aktuelle Wert. Ausnahme Logo: es wird
/// nie ergänzt, siehe `InvoiceLogo`; ebenso der AGB-Verweis `terms_url`. Ob Umsatzsteuer ausgewiesen wird, steht
/// ohnehin in `invoices.is_small_business`.
class InvoiceSeller {
  const InvoiceSeller._();

  static CompanyProfile profileFor(Invoice invoice, CompanyProfile current) {
    final snapshot = invoice.sellerSnapshot;
    if (!invoice.status.isLocked || snapshot == null || snapshot.isEmpty) {
      return current;
    }
    try {
      final frozen = jsonDecode(snapshot);
      if (frozen is! Map<String, Object?>) return current;
      final merged = {...current.toMap()};
      frozen.forEach((key, value) {
        if (value != null) merged[key] = value;
      });
      merged['logo_path'] = frozen['logo_path'];
      // Wie das Logo: der AGB-Verweis (L-3.25) wird nie aus dem aktuellen
      // Profil ergänzt – eine alte Rechnung bekäme sonst nachträglich AGB.
      merged['terms_url'] = frozen['terms_url'] ?? '';
      return CompanyProfile.fromMap(merged);
    } on FormatException {
      return current;
    }
  }
}
