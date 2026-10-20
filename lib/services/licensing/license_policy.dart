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
  pro,

  /// Demo ohne Abo (FA-13.14, Entscheidung Auftraggeber 2026-10-19, O-42):
  /// eigene Muster-Datenbank, alles ansehen und ausprobieren (Scanner mit
  /// Erkennung, Rechnung zusammenstellen), aber nichts speichern, senden,
  /// teilen, exportieren oder sichern. Gilt nur, solange die Demo läuft;
  /// echte Daten sieht die Demo nie.
  demo;

  /// Die einzige Stelle, die entscheidet, was ein Anspruch erlaubt.
  bool allows(Feature feature) => switch (feature) {
    // E-Rechnung ausstellen ab Basis (Entscheidung Auftraggeber 2026-10-19,
    // O-44): gesetzliche Pflicht nie nur in Pro (Lastenheft 5.10).
    Feature.newBookings ||
    Feature.eInvoiceIssue => this == basis || this == pro,
    // Ausprobieren in der Demo: Erkennung füllt das Formular, Kurs abrufen
    // zeigt den Kurs – gespeichert wird nichts (newBookings fehlt).
    Feature.receiptRecognition ||
    Feature.exchangeRateFetch ||
    Feature.annualReports ||
    Feature.levyReserve => this == pro || this == demo,
    // Ansehen, Export, Sicherung und Wiederherstellung bleiben ohne Abo
    // erlaubt (L-10.4, L-22.6); nur die Demo hat keine eigenen Daten.
    Feature.dataExport => this != demo,
    Feature.dataImport ||
    Feature.taxOfficeSubmission ||
    Feature.pdfSending ||
    Feature.dunningSending ||
    Feature.invoiceLogo ||
    Feature.assetManagement ||
    Feature.contractSummary ||
    Feature.bookingRules ||
    Feature.helperDevices => this == pro,
  };

  String get label => switch (this) {
    none => 'Kein Abo',
    readOnly => 'Nur lesen',
    basis => 'Basis',
    pro => 'Pro',
    demo => 'Demo',
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

  /// Import aus Fremdplattformen (Amazon, PayPal, Shopify, Stripe, L-28) und
  /// Auslesen von E-Rechnungen (ZUGFeRD, XRechnung, ebInterface) in einen
  /// Beleg (nur Pro, Entscheidung 2026-10-15, O-34). Die Datei selbst wird
  /// in jedem Abo als Beleganhang gespeichert.
  dataImport,

  /// Direkte Übermittlung an das Finanzamt (FinanzOnline, ELSTER, UVA;
  /// L-6.5, nur Pro). Noch nicht gebaut; der Wert legt den Tarif fest.
  taxOfficeSubmission,

  /// Rechnung und Stornorechnung mit einem Tipp als PDF senden (nur Pro).
  /// Ohne Pro bleibt „PDF speichern oder drucken“ über den Systemdialog
  /// (L-10.4: eine Rechnung muss die Kundin immer erreichen können).
  pdfSending,

  /// Zahlungserinnerung und Mahnung als PDF mit Text senden (nur Pro).
  /// Erstellen und speichern geht ab Basis.
  dunningSending,

  /// Firmenlogo auf Angeboten und Rechnungen hochladen (L-1.7, nur Pro).
  invoiceLogo,

  /// „Kurs abrufen“ bei der EZB (L-19.29, nur Pro); Kurs eintippen geht
  /// in jedem Abo.
  exchangeRateFetch,

  /// Saldenliste und vorläufiger Jahresabschluss als PDF samt Paket für die
  /// Steuerberatung (FA-15.9, FA-15.10; Entscheidung Auftraggeberin
  /// 2026-10-16, Lastenheft 14a).
  annualReports,

  /// Anlagen anlegen, ändern und ausscheiden (FA-15.1 bis FA-15.7, nur Pro;
  /// Entscheidung Auftraggeberin 2026-10-16, Lastenheft 14a). Erfasste
  /// Anlagen ansehen, das Anlagenverzeichnis exportieren und die jährliche
  /// AfA bestehender Anlagen laufen in jedem Anspruch weiter (L-22.6), sonst
  /// stimmt der Gewinn nicht (§ 7 Abs 3 EStG AT, § 4 Abs 3 S 5 EStG DE).
  assetManagement,

  /// Texterkennung und Kurzübersicht im Vertragsarchiv (FA-16.3, nur Pro;
  /// Entscheidung Auftraggeberin 2026-10-16, Lastenheft 14a). Verträge ablegen, Fristen,
  /// Abgleich und Aufbewahrung gehen ab Basis.
  contractSummary,

  /// Mithelfer-Geräte koppeln (FA-17.1, Lastenheft 5.29; Entscheidung
  /// Auftraggeberin 2026-10-17: Pro auf dem Hauptgerät). Mithelfer-Geräte
  /// brauchen kein eigenes Abo (Vorschlag, Lastenheft 14a). Der Eingang nimmt
  /// bereits gesendete Belege in jedem Anspruch an – nichts geht verloren.
  helperDevices,

  /// Karte und Bildschirm „Abgaben & Rücklagen“ (FA-19.1 ff.; Entscheidung
  /// Auftraggeber 2026-10-19, O-43: nur Pro, in der Demo sichtbar). Buchungen
  /// in Abgabenkategorien bleiben in jedem Anspruch normale Buchungen.
  levyReserve,

  /// Buchungsregeln anlegen und ändern (FA-20.1; Vorschlag Pro, O-47 offen).
  /// Bestehende Regeln wirken in jedem Anspruch weiter, sonst stimmt der
  /// Gewinn nicht (wie die AfA, L-22.6); die Demo zeigt Musterregeln.
  bookingRules,

  /// E-Rechnung ausstellen (FA-5.49): ZUGFeRD-PDF, XRechnung, ebInterface.
  /// Ab Basis (Entscheidung Auftraggeber 2026-10-19, O-44): Pflicht zum
  /// Ausstellen in DE ab 2027/2028 (§ 27 Abs. 38 UStG), eine gesetzliche
  /// Pflicht liegt nie nur in Pro (Lastenheft 5.10). Zustellen geht in Basis
  /// über das Teilen-Blatt; Senden mit einem Tipp bleibt Pro ([pdfSending]).
  eInvoiceIssue,

  /// Exportieren, Teilen, Sichern und Wiederherstellen (L-22.6). Ohne Abo
  /// und im Nur-Lese-Modus immer erlaubt; gesperrt nur in der Demo
  /// (FA-13.14), damit Musterdaten nicht als echte Unterlagen weitergehen.
  dataExport,
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

  /// Test über das Einführungsangebot der Stores auf **allen vier**
  /// Produkten (L-10.3, L-22.3; Entscheidung Auftraggeber 2026-10-19, O-42,
  /// ersetzt O-35). Die Stores verwalten Test, Berechtigung und Abbuchung;
  /// in dieser Zeit gibt die App auch beim Basis-Abo alle Pro-Funktionen frei
  /// („Pro inklusive in der Testzeit“, [proIncludedUntil]). Kündigen in den
  /// 14 Tagen kostet nichts (Store-Regel des kostenlosen Einführungsangebots).
  static const trialDays = 14;

  /// Werbesatz für Hinweise ohne Abo (O-42; Preis nennt nur die Abo-Seite
  /// aus dem Store).
  static const trialTeaser =
      '$trialDays Tage kostenlos testen – mit allen Pro-Funktionen.';

  /// Erinnerung vor Testende (L-10.3: 3 Tage vorher).
  static const trialReminderDays = 3;

  /// Ohne Netz gilt der zuletzt vom Store bestätigte Anspruch so viele Tage
  /// ab der letzten Bestätigung: längster Monatszeitraum (31) plus die
  /// geforderte Kulanz von mindestens 14 Tagen (L-22.5, L-10.5).
  static const offlineGraceDays = 45;

  /// Ab so vielen Tagen ohne Bestätigung bittet die Übersicht, die App einmal
  /// mit Internet zu öffnen – Ankündigung vor jeder Herabstufung (L-22.5).
  static const offlineWarnDays = 31;

  /// Promo-Code für Instagram (Entscheidung Auftraggeberin 2026-10-16,
  /// FA-13.13): 2 Monate Pro gratis für neue Abonnentinnen, danach
  /// kostenpflichtig, vorher kündbar oder Wechsel auf Basis. Angelegt als
  /// Apple-Angebotscode (benutzerdefiniert) und Google-Play-Promo-Code; die
  /// Stores verwalten Gültigkeit und Einlösung, die App kennt den Code nur
  /// für Links und die Erinnerung.
  static const promoCode = 'JENIBUCHT2M';

  /// Gratismonate des Promo-Codes; Erinnerung wie beim Test 3 Tage vorher.
  static const promoFreeMonths = 2;

  /// Einlöse-Adresse von Google Play; öffnet die Play-Store-App.
  static Uri playRedeemUri(String code) => Uri.https(
    'play.google.com',
    '/redeem',
    {'code': code.trim().toUpperCase()},
  );

  /// Einlöse-Adresse des App Store für Angebotscodes. [appId] ist die
  /// numerische Apple-ID der App aus App Store Connect.
  static Uri appStoreRedeemUri(String appId, String code) => Uri.https(
    'apps.apple.com',
    '/redeem',
    {'ctx': 'offercodes', 'id': appId, 'code': code.trim().toUpperCase()},
  );

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

  /// Anspruch aus dem gespeicherten Stand (L-22.5, L-22.6). Basis in der
  /// Testzeit des ersten Abos zählt als Pro (O-42, [proIncludedUntil]).
  static Entitlement entitlement(LicenseRecord record, DateTime now) {
    final tier = record.tier;
    final checkedAt = record.checkedAt;
    if (tier != null &&
        checkedAt != null &&
        now.difference(checkedAt).inDays < offlineGraceDays) {
      if (tier == Tier.pro) return Entitlement.pro;
      return proIncludedUntil(record, now) != null
          ? Entitlement.pro
          : Entitlement.basis;
    }
    return record.everSubscribed ? Entitlement.readOnly : Entitlement.none;
  }

  /// Ende von „Pro inklusive in der Testzeit“ beim Basis-Abo (O-42), solange
  /// es läuft, sonst `null`.
  ///
  /// Testzeit = [trialDays] Tage ab dem ersten Abo dieser Installation bzw.
  /// dieses Store-Kontos ([LicenseRecord.trialStartedAt]: der früheste
  /// Kaufzeitpunkt, den der Store je gemeldet hat, im Schlüsselbund bzw.
  /// Keystore). iOS meldet zusätzlich, ob die Transaktion im
  /// Einführungsangebot läuft ([LicenseRecord.introOffer], StoreKit 2
  /// `offerType` introductory); meldet StoreKit „nein“ (z. B. Test schon
  /// früher verbraucht), gibt es kein Pro inklusive. Android liefert der App
  /// kein Testkennzeichen: dort gilt nur das Zeitfenster – eine Näherung
  /// (Spezifikation FA-13.4, Prüfung P-D49).
  static DateTime? proIncludedUntil(LicenseRecord record, DateTime now) {
    final start = record.trialStartedAt;
    if (record.tier != Tier.basis || start == null) return null;
    if (record.trialIsPromo || record.introOffer == false) return null;
    final end = start.add(const Duration(days: trialDays));
    return now.isBefore(end) ? end : null;
  }

  /// Ganze Tage bis [end], aufgerundet („Noch 3 Tage“).
  static int daysLeft(DateTime end, DateTime now) {
    final hours = end.difference(now).inHours;
    return hours <= 0 ? 0 : (hours + 23) ~/ 24;
  }

  /// Seit [offlineWarnDays] ohne Bestätigung: Hinweis vor der Herabstufung.
  static bool needsOnlineCheck(LicenseRecord record, DateTime now) {
    final checkedAt = record.checkedAt;
    return record.tier != null &&
        checkedAt != null &&
        now.difference(checkedAt).inDays >= offlineWarnDays;
  }

  /// Ende des Tests, solange die Erinnerung fällig ist (L-10.3), sonst `null`.
  /// Beim Promo-Code endet die Gratiszeit nach [promoFreeMonths] Monaten.
  /// Gilt für Pro und – als „danach Basis“ – für Basis mit Pro inklusive.
  static DateTime? trialReminder(LicenseRecord record, DateTime now) {
    final start = record.trialStartedAt;
    if (start == null || record.tier == null) return null;
    if (record.introOffer == false && !record.trialIsPromo) return null;
    if (record.tier == Tier.basis && record.trialIsPromo) return null;
    final end = record.trialIsPromo
        ? DateTime(start.year, start.month + promoFreeMonths, start.day)
        : start.add(const Duration(days: trialDays));
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
    this.trialIsPromo = false,
    this.introOffer,
  });

  /// iOS: StoreKit 2 meldet die aktive Transaktion als Einführungsangebot
  /// (`true`) bzw. als regulär bezahlt (`false`); `null` = unbekannt
  /// (Android liefert kein Kennzeichen, O-42).
  final bool? introOffer;

  /// Gratiszeit aus dem Promo-Code statt aus dem 14-Tage-Test (FA-13.13).
  final bool trialIsPromo;

  /// Aktive Stufe bei der letzten Bestätigung; `null` = kein Abo.
  final Tier? tier;

  /// Zeitpunkt der letzten erfolgreichen Abfrage beim Store.
  final DateTime? checkedAt;

  /// Je ein Abo gehabt – entscheidet zwischen „kein Abo“ und „nur lesen“.
  final bool everSubscribed;

  /// Beginn des ersten Abos (Basis oder Pro) dieser Installation bzw. dieses
  /// Store-Kontos: Beginn der Testzeit (O-42). Bleibt beim frühesten je
  /// gemeldeten Kaufzeitpunkt; beim Promo-Code der Einlösezeitpunkt.
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
    bool? trialIsPromo,
    bool? Function()? introOffer,
  }) => LicenseRecord(
    trialIsPromo: trialIsPromo ?? this.trialIsPromo,
    introOffer: introOffer == null ? this.introOffer : introOffer(),
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
    'trialIsPromo': trialIsPromo,
    'introOffer': introOffer,
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
      trialIsPromo: json['trialIsPromo'] == true,
      introOffer: json['introOffer'] is bool
          ? json['introOffer'] as bool
          : null,
    );
  }
}
