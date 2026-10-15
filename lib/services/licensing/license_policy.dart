/// Tarife, Ansprüche und Regeln der Lizenz (Lastenheft 5.10 und 5.22,
/// Spezifikation FA-12.1 bis FA-12.10). Reines Dart, keine Store-Schnittstelle.
///
/// Oberfläche und Funktionen fragen **nur** [Entitlement.allows] ab (L-22.1),
/// nie den Store, nie den Tarif direkt.
library;

/// Abo-Stufe im Store. Die Reihenfolge ist die Rangfolge (Basis < Pro).
enum Tier { basis, pro }

/// Abrechnungszeitraum eines Store-Produkts.
enum BillingPeriod { month, year }

/// Anspruch, den die App aus dem Abo ableitet (L-22.1).
enum Entitlement {
  /// Nie ein Abo gehabt (neue Installation ohne Test).
  none,

  /// Abo beendet: alles ansehen, drucken, exportieren, sichern und
  /// wiederherstellen, aber keine neuen Buchungen (L-7.15, L-22.6).
  readOnly,
  basis,
  pro;

  /// Die einzige Stelle, die entscheidet, was ein Anspruch erlaubt.
  bool allows(Feature feature) => switch (feature) {
    Feature.newBookings => this == basis || this == pro,
    Feature.receiptRecognition => this == pro,
  };

  String get label => switch (this) {
    none => 'Kein Abo',
    readOnly => 'Nur lesen',
    basis => 'Basis',
    pro => 'Pro',
  };
}

/// Funktionen mit Tarifschnitt (Lastenheft 5.10, O-4). Alles, was hier nicht
/// steht – Ansehen, Drucken, Export, Sicherung, Wiederherstellung – ist
/// **immer** erlaubt, auch ohne Abo (L-10.4, L-22.6).
enum Feature {
  /// Neue Belege und Rechnungen speichern bzw. ausstellen (ab Basis).
  newBookings,

  /// Belegerkennung per Kamera (L-2.4, nur Pro).
  receiptRecognition,
}

/// Ein Store-Produkt. Die IDs sind in Google Play Console und App Store
/// Connect identisch anzulegen (STORE_ANMELDUNG.md, P-D30).
class LicenseProduct {
  const LicenseProduct(this.id, this.tier, this.period);

  final String id;
  final Tier tier;
  final BillingPeriod period;
}

class LicensePolicy {
  LicensePolicy._();

  /// Lizenzprüfung ein? Testbuilds laufen ohne Store-Produkte mit vollem
  /// Umfang; der Store-Build setzt `--dart-define=LICENSING=true`
  /// (RELEASE_PLAYBOOK, P-D30).
  static const enabled = bool.fromEnvironment('LICENSING');

  /// Test über das Einführungsangebot der Stores auf Pro (L-10.3, L-22.3,
  /// Entscheidung O-4 vom 2026-10-10). Die Stores verwalten den Test; die App
  /// nennt die Dauer nur auf der Abo-Seite.
  static const trialDays = 14;

  /// Erinnerung vor Testende (L-10.3: 3 Tage vorher).
  static const trialReminderDays = 3;

  /// Ohne Netz gilt der zuletzt vom Store bestätigte Anspruch so viele Tage
  /// ab der letzten Bestätigung: längster Monatszeitraum (31) plus die
  /// geforderte Kulanz von mindestens 14 Tagen (L-22.5, L-10.5).
  static const offlineGraceDays = 45;

  /// Ab so vielen Tagen ohne Bestätigung bittet die Übersicht, die App einmal
  /// mit Internet zu öffnen – Ankündigung vor jeder Herabstufung (L-22.5).
  static const offlineWarnDays = 31;

  /// Eine Abogruppe, vier Produkte (L-22.2).
  static const products = [
    LicenseProduct('basis_monat', Tier.basis, BillingPeriod.month),
    LicenseProduct('basis_jahr', Tier.basis, BillingPeriod.year),
    LicenseProduct('pro_monat', Tier.pro, BillingPeriod.month),
    LicenseProduct('pro_jahr', Tier.pro, BillingPeriod.year),
  ];

  static Set<String> get productIds => {for (final p in products) p.id};

  static LicenseProduct? product(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Höchste Stufe unter den aktiven Produkten; `null` ohne aktives Abo.
  static Tier? highestTier(Iterable<String> activeIds) {
    Tier? best;
    for (final id in activeIds) {
      final tier = product(id)?.tier;
      if (tier != null && (best == null || tier.index > best.index)) {
        best = tier;
      }
    }
    return best;
  }

  /// Anspruch aus dem gespeicherten Stand (L-22.5, L-22.6).
  static Entitlement entitlement(LicenseRecord record, DateTime now) {
    final tier = record.tier;
    final checkedAt = record.checkedAt;
    if (tier != null &&
        checkedAt != null &&
        now.difference(checkedAt).inDays < offlineGraceDays) {
      return tier == Tier.pro ? Entitlement.pro : Entitlement.basis;
    }
    return record.everSubscribed ? Entitlement.readOnly : Entitlement.none;
  }

  /// Seit [offlineWarnDays] ohne Bestätigung: Hinweis vor der Herabstufung.
  static bool needsOnlineCheck(LicenseRecord record, DateTime now) {
    final checkedAt = record.checkedAt;
    return record.tier != null &&
        checkedAt != null &&
        now.difference(checkedAt).inDays >= offlineWarnDays;
  }

  /// Ende des Tests, solange die Erinnerung fällig ist (L-10.3), sonst `null`.
  static DateTime? trialReminder(LicenseRecord record, DateTime now) {
    final start = record.trialStartedAt;
    if (start == null || record.tier != Tier.pro) return null;
    final end = start.add(const Duration(days: trialDays));
    final from = end.subtract(const Duration(days: trialReminderDays));
    return !now.isBefore(from) && now.isBefore(end) ? end : null;
  }
}

/// Gespeicherter, zuletzt vom Store bestätigter Stand.
class LicenseRecord {
  const LicenseRecord({
    this.tier,
    this.checkedAt,
    this.everSubscribed = false,
    this.trialStartedAt,
    this.downgradedFrom,
  });

  /// Aktive Stufe bei der letzten Bestätigung; `null` = kein Abo.
  final Tier? tier;

  /// Zeitpunkt der letzten erfolgreichen Abfrage beim Store.
  final DateTime? checkedAt;

  /// Je ein Abo gehabt – entscheidet zwischen „kein Abo“ und „nur lesen“.
  final bool everSubscribed;

  /// Erster Kauf von Pro ohne früheres Abo: Beginn des Store-Tests.
  final DateTime? trialStartedAt;

  /// Stufe vor der letzten Herabstufung, bis die Nutzerin den Hinweis
  /// gesehen hat (L-22.5).
  final Tier? downgradedFrom;

  LicenseRecord copyWith({
    Tier? Function()? tier,
    DateTime? checkedAt,
    bool? everSubscribed,
    DateTime? Function()? trialStartedAt,
    Tier? Function()? downgradedFrom,
  }) => LicenseRecord(
    tier: tier == null ? this.tier : tier(),
    checkedAt: checkedAt ?? this.checkedAt,
    everSubscribed: everSubscribed ?? this.everSubscribed,
    trialStartedAt: trialStartedAt == null
        ? this.trialStartedAt
        : trialStartedAt(),
    downgradedFrom: downgradedFrom == null
        ? this.downgradedFrom
        : downgradedFrom(),
  );

  Map<String, Object?> toJson() => {
    'tier': tier?.name,
    'checkedAt': checkedAt?.toIso8601String(),
    'everSubscribed': everSubscribed,
    'trialStartedAt': trialStartedAt?.toIso8601String(),
    'downgradedFrom': downgradedFrom?.name,
  };

  static LicenseRecord fromJson(Map<String, Object?> json) {
    Tier? tierOf(Object? v) =>
        Tier.values.where((t) => t.name == v).firstOrNull;
    DateTime? dateOf(Object? v) => v is String ? DateTime.tryParse(v) : null;
    return LicenseRecord(
      tier: tierOf(json['tier']),
      checkedAt: dateOf(json['checkedAt']),
      everSubscribed: json['everSubscribed'] == true,
      trialStartedAt: dateOf(json['trialStartedAt']),
      downgradedFrom: tierOf(json['downgradedFrom']),
    );
  }
}
