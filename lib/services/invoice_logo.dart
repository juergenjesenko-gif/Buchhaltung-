import 'dart:convert';

import '../domain/company_profile.dart';
import '../domain/invoice.dart';

/// Welches Logo gehört auf das PDF einer Rechnung? (Lastenheft L-1.7)
///
/// Gestellte Rechnungen sind unveränderlich (GR-8): sie zeigen das Logo, das
/// bei der Rechnungslegung im `seller_snapshot` eingefroren wurde – auch wenn
/// das Logo im Profil später gewechselt oder entfernt wurde. Rechnungen aus
/// der Zeit vor Schema 8 haben keinen Eintrag und bleiben ohne Logo, so wie
/// sie damals erzeugt wurden. Entwürfe zeigen das aktuelle Logo – aber nur,
/// solange Pro oder der Store-Test aktiv ist ([logoAllowed]).
///
/// Entscheidung der Auftraggeberin 2026-10-16 (FA-13.12): Das Logo wird im
/// Onboarding ohne Abo-Seite gewählt und bleibt gespeichert. Mit Basis oder
/// ohne Abo wird es auf **neuen** Rechnungen und Angeboten nicht gedruckt;
/// nach einem Wechsel auf Pro erscheint es wieder.
class InvoiceLogo {
  const InvoiceLogo._();

  /// Profil, wie es in neue Belege eingefroren wird: ohne Logo, wenn der
  /// Anspruch das Logo nicht erlaubt. Das Profil selbst behält den Pfad.
  static CompanyProfile forNewDocument(
    CompanyProfile profile, {
    required bool logoAllowed,
  }) => logoAllowed ? profile : profile.copyWith(clearLogo: true);

  static String? pathFor(
    Invoice invoice,
    CompanyProfile profile, {
    required bool logoAllowed,
  }) {
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
    return logoAllowed && profile.hasLogo ? profile.logoPath : null;
  }
}
