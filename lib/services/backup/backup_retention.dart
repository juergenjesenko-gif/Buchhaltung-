/// Aufbewahrung automatischer Sicherungen (Prüfinstanz Steuerberater):
/// die letzten [daily] Stände, dazu je Monat der jüngste Stand der letzten
/// [monthly] Monate, dazu **je Kalenderjahr der jüngste Stand dauerhaft**.
/// Jahresstände löscht die Rotation nie; die Aufbewahrungspflicht beträgt
/// 7 (AT) bzw. 8–10 Jahre (DE).
class BackupRetention {
  const BackupRetention({this.daily = 7, this.monthly = 12});

  final int daily;
  final int monthly;

  static const prefix = 'Auto-Sicherung_';
  static const extension = '.jbbackup';

  static String fileNameFor(DateTime at) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '$prefix${at.year}-${two(at.month)}-${two(at.day)}_'
        '${two(at.hour)}${two(at.minute)}${two(at.second)}$extension';
  }

  static final _pattern = RegExp(
    r'^Auto-Sicherung_(\d{4})-(\d{2})-(\d{2})_(\d{2})(\d{2})(\d{2})\.jbbackup$',
  );

  /// Zeitpunkt aus dem Dateinamen; `null` für fremde Dateien, die die App
  /// nie anfasst.
  static DateTime? parse(String name) {
    final m = _pattern.firstMatch(name);
    if (m == null) return null;
    int g(int i) => int.parse(m.group(i)!);
    return DateTime(g(1), g(2), g(3), g(4), g(5), g(6));
  }

  /// Welche eigenen Sicherungen dürfen weg?
  List<String> toDelete(List<String> names, DateTime now) {
    final own = <String, DateTime>{
      for (final name in names)
        if (parse(name) case final at?) name: at,
    };
    final sorted = own.keys.toList()
      ..sort((a, b) => own[b]!.compareTo(own[a]!));

    final keep = <String>{...sorted.take(daily)};
    final months = <String>{};
    final years = <int>{};
    final oldestMonth = DateTime(now.year, now.month - monthly + 1);
    for (final name in sorted) {
      final at = own[name]!;
      if (years.add(at.year)) keep.add(name);
      final month = '${at.year}-${at.month}';
      if (!at.isBefore(oldestMonth) && months.add(month)) keep.add(name);
    }
    return [
      for (final name in sorted)
        if (!keep.contains(name)) name,
    ];
  }
}
