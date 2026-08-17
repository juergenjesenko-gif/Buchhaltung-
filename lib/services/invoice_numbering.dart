/// Erzeugt fortlaufende Rechnungsnummern aus einem Muster.
///
/// Unterstützte Platzhalter:
///   {YYYY} – vierstelliges Jahr
///   {YY}   – zweistelliges Jahr
///   {MM}   – zweistelliger Monat
///   {N}    – laufende Nummer ohne Auffüllen
///   {NN}…{NNNNNN} – laufende Nummer, links mit Nullen auf die Anzahl der
///                    N aufgefüllt
///
/// Beide Rechtsordnungen verlangen eine *einmalige, fortlaufende* Nummer
/// (§ 11 Abs 1 Z 5 UStG AT, § 14 Abs 4 Nr. 4 UStG DE). Mehrere Nummernkreise
/// sind erlaubt, Lücken sind unschön, aber für sich noch kein Mangel –
/// Doppelvergaben dagegen sind einer.
class InvoiceNumbering {
  const InvoiceNumbering._();

  static const defaultPattern = 'RE-{YYYY}-{NNNN}';

  static String format({
    required String pattern,
    required int sequence,
    required DateTime date,
  }) {
    var result = pattern;
    result = result.replaceAll('{YYYY}', date.year.toString().padLeft(4, '0'));
    result = result.replaceAll(
      '{YY}',
      (date.year % 100).toString().padLeft(2, '0'),
    );
    result = result.replaceAll('{MM}', date.month.toString().padLeft(2, '0'));

    // Längste N-Gruppe zuerst ersetzen, sonst frisst {N} den Anfang von {NNNN}.
    for (var width = 6; width >= 1; width--) {
      final token = '{${'N' * width}}';
      if (result.contains(token)) {
        result = result.replaceAll(
          token,
          sequence.toString().padLeft(width, '0'),
        );
      }
    }
    return result;
  }

  /// Prüft, ob ein Muster überhaupt eine laufende Nummer enthält. Ohne sie
  /// würde jede Rechnung dieselbe Nummer tragen.
  static bool isValidPattern(String pattern) =>
      pattern.trim().isNotEmpty && RegExp(r'\{N{1,6}\}').hasMatch(pattern);

  /// Beispielnummer für die Vorschau in den Einstellungen.
  static String preview(String pattern, DateTime date) =>
      isValidPattern(pattern)
      ? format(pattern: pattern, sequence: 1, date: date)
      : 'Ungültiges Muster';
}
