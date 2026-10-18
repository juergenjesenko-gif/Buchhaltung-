/// Regeln für Steuer- und Abgabetermine (Lastenheft L-25). Die Regeln stehen
/// im `TaxProfile` des Landes; berechnet werden die Termine in
/// `lib/services/deadline_calculator.dart`.
library;

/// Voranmeldungszeitraum der Umsatzsteuer.
enum VatReturnInterval {
  /// Aus dem Vorjahr vorschlagen (Standard).
  auto('Automatisch aus dem Vorjahr'),
  monthly('Monatlich'),
  quarterly('Vierteljährlich');

  const VatReturnInterval(this.label);
  final String label;

  static VatReturnInterval fromName(String? name) => VatReturnInterval.values
      .firstWhere((v) => v.name == name, orElse: () => VatReturnInterval.auto);
}

/// Woran der Vorschlag „monatlich“ gemessen wird.
enum VatIntervalBasis {
  /// Umsatz (Entgelte) des Vorjahres, AT § 21 Abs 2 UStG 1994.
  previousYearTurnover,

  /// Umsatzsteuer-Zahllast des Vorjahres, DE § 18 Abs 2 UStG.
  previousYearVat,
}

/// Wann eine Regel gilt.
enum DeadlineCondition {
  always,

  /// Nur wer nicht Kleinunternehmer ist (Voranmeldung).
  notSmallBusiness,

  /// Nur wer eine Zusammenfassende Meldung abgibt.
  filesEcsl,

  /// Nur wer bei der SVS versichert ist (AT).
  socialInsurance,

  /// Jahreserklärung: ohne Steuerberatung mit Datum, mit Steuerberatung
  /// „laut Kanzlei“.
  annualReturn,

  /// Nimmt am One-Stop-Shop (EU-Regelung) teil (FA-18.6).
  oss,

  /// Mindestens eine weitere Registrierung im EU-Kleinunternehmer-
  /// Verfahren: vierteljährliche Umsatzmeldung im Heimatland (FA-18.6).
  euSmallBusinessReport,

  /// Voranmeldung einer weiteren Registrierung (Regelbesteuerung,
  /// monatlich oder vierteljährlich; FA-18.5).
  registrationReturn,

  /// Jahreserklärung einer weiteren Registrierung (Regelbesteuerung,
  /// Zeitraum nicht „keine“; FA-18.5).
  registrationAnnual,
}

/// Wie das Fälligkeitsdatum entsteht.
sealed class DeadlineSchedule {
  const DeadlineSchedule();
}

/// Fällig nach Ende des Voranmeldungs- bzw. Meldezeitraums:
/// Tag [dueDay] (0 = Monatsletzter) im [monthsAfter]-ten Monat danach.
/// [extensionMonths] kommen bei Dauerfristverlängerung (DE) dazu.
class AfterPeriod extends DeadlineSchedule {
  const AfterPeriod({
    required this.dueDay,
    required this.monthsAfter,
    this.extensionMonths = 0,
    this.quarterly = false,
  });

  final int dueDay;
  final int monthsAfter;
  final int extensionMonths;

  /// Immer vierteljährlich, unabhängig vom Voranmeldungszeitraum (OSS,
  /// EU-Kleinunternehmer-Meldung).
  final bool quarterly;
}

/// Feste Tage im Jahr, z. B. Vorauszahlungen. Tag 0 = Monatsletzter.
class FixedDates extends DeadlineSchedule {
  const FixedDates(this.monthDays);

  final List<(int month, int day)> monthDays;
}

/// Jahreserklärung: Tag im Folgejahr des Veranlagungsjahres.
class FollowingYear extends DeadlineSchedule {
  const FollowingYear({required this.month, required this.day});

  final int month;
  final int day;
}

/// Eine Terminregel samt Fundstelle.
class DeadlineRule {
  const DeadlineRule({
    required this.label,
    required this.legalRef,
    required this.schedule,
    this.condition = DeadlineCondition.always,
    this.approximate = false,
  });

  /// Bezeichnung, z. B. „UVA“; der Zeitraum wird angehängt.
  final String label;

  /// Fundstelle, angezeigt beim Tippen auf den Termin.
  final String legalRef;

  final DeadlineSchedule schedule;
  final DeadlineCondition condition;

  /// Nur ungefähr bekannt (z. B. SVS-Fälligkeit): angezeigt als „ca.“, ohne
  /// Verschiebung auf den nächsten Werktag. Spezifikation 14, P-S34.
  final bool approximate;
}
