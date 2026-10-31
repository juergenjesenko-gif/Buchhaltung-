/// Gratis-Belegerkennung in Basis (Entscheidung Auftraggeber 2026-10-31):
/// Basis liest **5 Belege je Kalendermonat** automatisch aus, damit der
/// Komfort von Pro regelmäßig spürbar bleibt. Pro und Demo ohne Grenze.
/// Gezählt wird jeder gestartete Auslesevorgang eines Belegs; der Zähler
/// beginnt am 1. jedes Monats neu.
class ScanQuota {
  const ScanQuota._();

  /// Freie Auslesungen je Kalendermonat in Basis (`spec.basis_free_scans`).
  static const freePerMonth = 5;

  /// Schlüssel in `helper_settings`, Wert `JJJJ-MM:n`.
  static const settingKey = 'scan_quota';

  static String _month(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}';

  /// Bereits verbrauchte Auslesungen im Monat von [now] aus dem
  /// gespeicherten Wert; ein Wert aus einem anderen Monat zählt nicht.
  static int used(String? stored, DateTime now) {
    if (stored == null) return 0;
    final parts = stored.split(':');
    if (parts.length != 2 || parts[0] != _month(now)) return 0;
    return int.tryParse(parts[1]) ?? 0;
  }

  static int remaining(String? stored, DateTime now) =>
      (freePerMonth - used(stored, now)).clamp(0, freePerMonth);

  /// Neuer gespeicherter Wert nach einer weiteren Auslesung.
  static String consume(String? stored, DateTime now) =>
      '${_month(now)}:${used(stored, now) + 1}';
}
