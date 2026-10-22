/// Regelstand und Aktualisieren-Hinweis (FA-21.1 bis FA-21.3, Entscheidung
/// Auftraggeber 2026-10-20). Offline: die App vergleicht nur das heutige
/// Datum mit `TaxProfile.rulesValidUntil` – kein Server, keine Abfrage.
library;

import '../domain/country.dart';

class RulesFreshness {
  RulesFreshness._();

  /// Store-Seiten für „bitte App aktualisieren“. Apple-ID folgt mit der
  /// Freigabe im App Store (P-D57).
  static const androidStoreUrl =
      'https://play.google.com/store/apps/details?id=at.jenibarb.jenibucht';
  // Apple-ID der App aus App Store Connect (Angebotscode-Link, 2026-10-22).
  static const iosStoreUrl = 'https://apps.apple.com/app/id6824914122';

  /// Ob die Werte von [profile] am Tag [today] abgelaufen sind.
  static bool isOutdated(TaxProfile profile, DateTime today) {
    final d = DateTime(today.year, today.month, today.day);
    final until = profile.rulesValidUntil;
    return d.isAfter(DateTime(until.year, until.month, until.day));
  }

  /// Das Jahr, für das neue Werte fehlen, oder `null`, wenn alle Profile
  /// (Heimat und Registrierungen) aktuell sind.
  static int? outdatedYear(Iterable<TaxProfile> profiles, DateTime today) {
    for (final p in profiles) {
      if (isOutdated(p, today)) return today.year;
    }
    return null;
  }

  static String bannerText(int year) =>
      'Für $year gibt es neue Steuerwerte – bitte App aktualisieren.';

  /// Hinweis an Schätzungen und Kennzahlen eines Jahres, für das die App
  /// noch keine Werte hat; `null`, wenn die Werte gelten.
  static String? estimateNote(TaxProfile profile, int year) =>
      year > profile.rulesValidUntil.year
      ? 'Werte von ${profile.rulesValidUntil.year} – Schätzung unsicher'
      : null;

  /// Anzeige in den Einstellungen, z. B. „Stand 01.01.2026, gültig für 2026“.
  static String statusText(TaxProfile p) {
    String two(int v) => v.toString().padLeft(2, '0');
    final a = p.rulesAsOf;
    final from = p.rulesAsOf.year;
    final to = p.rulesValidUntil.year;
    return 'Stand ${two(a.day)}.${two(a.month)}.${a.year}, gültig für '
        '${from == to ? '$to' : '$from–$to'}';
  }

  /// Zeile in den Einstellungen für Heimat und Registrierungen, z. B.
  /// „Steuerregeln: Stand 01.01.2026, gültig für 2026 (AT/DE)“.
  static String settingsLine(Iterable<TaxProfile> profiles) {
    final byStatus = <String, List<String>>{};
    for (final p in profiles) {
      final codes = byStatus.putIfAbsent(statusText(p), () => []);
      if (!codes.contains(p.country.code)) codes.add(p.country.code);
    }
    return byStatus.entries
        .map((e) => 'Steuerregeln: ${e.key} (${e.value.join('/')})')
        .join('\n');
  }
}
