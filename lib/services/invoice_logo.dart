import 'dart:convert';

import '../domain/company_profile.dart';
import '../domain/invoice.dart';

/// Welches Logo gehört auf das PDF einer Rechnung? (Lastenheft L-1.7)
///
/// Gestellte Rechnungen sind unveränderlich (GR-8): sie zeigen das Logo, das
/// bei der Rechnungslegung im `seller_snapshot` eingefroren wurde – auch wenn
/// das Logo im Profil später gewechselt oder entfernt wurde. Rechnungen aus
/// der Zeit vor Schema 8 haben keinen Eintrag und bleiben ohne Logo, so wie
/// sie damals erzeugt wurden. Entwürfe zeigen das aktuelle Logo.
class InvoiceLogo {
  const InvoiceLogo._();

  static String? pathFor(Invoice invoice, CompanyProfile profile) {
    final snapshot = invoice.sellerSnapshot;
    if (invoice.status.isLocked && snapshot != null && snapshot.isNotEmpty) {
      try {
        final map = jsonDecode(snapshot);
        if (map is Map<String, Object?>) {
          final path = map['logo_path'];
          return path is String && path.isNotEmpty ? path : null;
        }
      } on FormatException {
        return null;
      }
      return null;
    }
    return profile.hasLogo ? profile.logoPath : null;
  }
}
