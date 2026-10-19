/// Laufzeitschalter der Demo (FA-13.14, Entscheidung Auftraggeber
/// 2026-10-19, O-42). Den Anspruch [Entitlement.demo] leitet `AppState`
/// daraus ab; Dienste ohne Zugriff auf den Zustand (Teilen, PDF, Datenbank)
/// fragen nur [active]. Reines Dart, keine Oberfläche.
library;

class DemoMode {
  DemoMode._();

  /// `true`, solange die Demo mit der Muster-Datenbank läuft.
  static bool active = false;

  /// Text des Wasserzeichens auf jeder PDF-Seite in der Demo (FA-13.14).
  static const watermark = 'MUSTER – DEMO';

  /// Gleicher Text ohne Sonderzeichen für die PDF-Metadaten (Stichwörter),
  /// damit Prüfungen ihn ohne Schriftdekodierung finden.
  static const watermarkKeyword = 'MUSTER-DEMO';

  /// Ruft die Oberfläche, wenn in der Demo etwas gespeichert, gesendet,
  /// geteilt oder exportiert werden sollte (Blatt „In der Demo wird nichts
  /// gespeichert“). Gesetzt von `main.dart`.
  static void Function()? onBlocked;

  /// Meldet eine blockierte Aktion; liefert `true`, wenn die Demo läuft.
  static bool blocked() {
    if (!active) return false;
    onBlocked?.call();
    return true;
  }

  /// Ob [error] ein Schreibversuch auf die schreibgeschützte
  /// Muster-Datenbank ist (`PRAGMA query_only`, SQLite-Fehler „readonly“).
  static bool isWriteBlocked(Object error) {
    if (!active) return false;
    final text = error.toString().toLowerCase();
    return text.contains('readonly') ||
        text.contains('read-only') ||
        text.contains('attempt to write');
  }
}
