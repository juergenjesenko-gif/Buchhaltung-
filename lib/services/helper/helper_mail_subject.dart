/// Betreff der Belegmails (FA-17.9): `[JeNi-Beleg] <Kopplungs-ID>-<JJJJMMTT>-<Nr>`.
///
/// Das Hauptgerät betrachtet im Postfach **nur** Mails mit diesem Kennzeichen
/// und einer bekannten Kopplungs-ID; alles andere bleibt unberührt.
library;

/// Kennzeichen am Anfang des Betreffs.
const helperMailTag = '[JeNi-Beleg]';

/// Zerlegter Betreff einer Belegmail.
typedef HelperMailSubjectParts = ({String pairingId, DateTime day, int seq});

abstract final class HelperMailSubject {
  static final _pattern = RegExp(
    r'\[JeNi-Beleg\]\s+([0-9a-f]{32})-(\d{4})(\d{2})(\d{2})-(\d{1,6})\b',
    caseSensitive: false,
  );

  /// Betreff für das [seq]-te Paket des Tages [day].
  static String format(String pairingId, DateTime day, int seq) =>
      '$helperMailTag $pairingId-${stamp(day)}-$seq';

  /// `JJJJMMTT`.
  static String stamp(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}'
      '${day.month.toString().padLeft(2, '0')}'
      '${day.day.toString().padLeft(2, '0')}';

  /// `null`, wenn [subject] keine Belegmail ist. Vorangestellte „Fwd:“/„AW:“
  /// stören nicht; die Kopplungs-ID wird klein geschrieben geliefert.
  static HelperMailSubjectParts? parse(String subject) {
    final m = _pattern.firstMatch(subject);
    if (m == null) return null;
    final y = int.parse(m.group(2)!);
    final mo = int.parse(m.group(3)!);
    final d = int.parse(m.group(4)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return (
      pairingId: m.group(1)!.toLowerCase(),
      day: DateTime(y, mo, d),
      seq: int.parse(m.group(5)!),
    );
  }
}
