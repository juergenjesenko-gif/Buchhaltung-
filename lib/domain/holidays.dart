/// Gesetzliche Feiertage für die Fristberechnung (Lastenheft L-25.3).
///
/// Fällt das Ende einer Frist auf einen Samstag, Sonntag oder Feiertag, endet
/// sie am nächsten Werktag: AT § 108 Abs 3 BAO (dort zählen auch Karfreitag
/// und 24. Dezember nicht als Werktag), DE § 108 Abs 3 AO.
enum HolidayCalendar {
  /// Österreich: Feiertage nach § 1 Feiertagsruhegesetz 1957 und § 7
  /// Arbeitsruhegesetz, bundeseinheitlich; dazu Karfreitag und 24.12. nach
  /// § 108 Abs 3 BAO. Ein Bundesland ist für Abgabenfristen nicht nötig.
  austria,

  /// Deutschland: bundeseinheitliche Feiertage plus die Landesfeiertage des
  /// gewählten Bundeslands (Feiertagsgesetze der Länder).
  germany;

  /// Ist [date] ein Feiertag (oder nach § 108 Abs 3 BAO wie einer zu
  /// behandeln)? [state] ist das Bundesland-Kürzel (nur DE), leer = nur
  /// bundeseinheitliche Feiertage.
  bool isHoliday(DateTime date, {String state = ''}) {
    final d = DateTime(date.year, date.month, date.day);
    final easter = easterSunday(d.year);
    DateTime e(int offset) =>
        DateTime(easter.year, easter.month, easter.day + offset);
    bool on(int month, int day) => d.month == month && d.day == day;

    switch (this) {
      case HolidayCalendar.austria:
        return on(1, 1) || // Neujahr
            on(1, 6) || // Heilige Drei Könige
            d == e(-2) || // Karfreitag, § 108 Abs 3 BAO
            d == e(1) || // Ostermontag
            on(5, 1) || // Staatsfeiertag
            d == e(39) || // Christi Himmelfahrt
            d == e(50) || // Pfingstmontag
            d == e(60) || // Fronleichnam
            on(8, 15) || // Mariä Himmelfahrt
            on(10, 26) || // Nationalfeiertag
            on(11, 1) || // Allerheiligen
            on(12, 8) || // Mariä Empfängnis
            on(12, 24) || // Heiliger Abend, § 108 Abs 3 BAO
            on(12, 25) ||
            on(12, 26);
      case HolidayCalendar.germany:
        final national =
            on(1, 1) ||
            d == e(-2) || // Karfreitag
            d == e(1) || // Ostermontag
            on(5, 1) ||
            d == e(39) || // Christi Himmelfahrt
            d == e(50) || // Pfingstmontag
            on(10, 3) || // Tag der Deutschen Einheit
            on(12, 25) ||
            on(12, 26);
        if (national) return true;
        bool inState(List<String> states) => states.contains(state);
        return (on(1, 6) && inState(const ['BW', 'BY', 'ST'])) ||
            (on(3, 8) && inState(const ['BE', 'MV'])) ||
            (d == e(60) &&
                inState(const ['BW', 'BY', 'HE', 'NW', 'RP', 'SL'])) ||
            (on(8, 15) && inState(const ['SL'])) ||
            (on(9, 20) && inState(const ['TH'])) ||
            (on(10, 31) &&
                inState(const [
                  'BB',
                  'HB',
                  'HH',
                  'MV',
                  'NI',
                  'SH',
                  'SN',
                  'ST',
                  'TH',
                ])) ||
            (on(11, 1) && inState(const ['BW', 'BY', 'NW', 'RP', 'SL'])) ||
            (d == _repentanceDay(d.year) && inState(const ['SN']));
    }
  }

  /// Nächster Werktag ab [date] (einschließlich).
  DateTime nextWorkday(DateTime date, {String state = ''}) {
    var d = DateTime(date.year, date.month, date.day);
    while (d.weekday == DateTime.saturday ||
        d.weekday == DateTime.sunday ||
        isHoliday(d, state: state)) {
      d = DateTime(d.year, d.month, d.day + 1);
    }
    return d;
  }

  /// Ostersonntag nach der Gaußschen Osterformel (anonymer gregorianischer
  /// Algorithmus).
  static DateTime easterSunday(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }

  /// Buß- und Bettag: Mittwoch vor dem 23. November.
  static DateTime _repentanceDay(int year) {
    var d = DateTime(year, 11, 22);
    while (d.weekday != DateTime.wednesday) {
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return d;
  }
}

/// Deutsche Bundesländer für die Auswahl im Profil (nur DE).
const germanStates = <(String, String)>[
  ('BW', 'Baden-Württemberg'),
  ('BY', 'Bayern'),
  ('BE', 'Berlin'),
  ('BB', 'Brandenburg'),
  ('HB', 'Bremen'),
  ('HH', 'Hamburg'),
  ('HE', 'Hessen'),
  ('MV', 'Mecklenburg-Vorpommern'),
  ('NI', 'Niedersachsen'),
  ('NW', 'Nordrhein-Westfalen'),
  ('RP', 'Rheinland-Pfalz'),
  ('SL', 'Saarland'),
  ('SN', 'Sachsen'),
  ('ST', 'Sachsen-Anhalt'),
  ('SH', 'Schleswig-Holstein'),
  ('TH', 'Thüringen'),
];
