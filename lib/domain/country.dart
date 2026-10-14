import 'deadline_rule.dart';
import 'dunning.dart';
import 'holidays.dart';
import 'money.dart';

/// Unterstützte Länder. Die App bildet Österreich und Deutschland ab; die
/// Unterschiede stecken bewusst nur in dieser Datei, damit ein weiteres Land
/// später eine reine Konfigurationsfrage ist.
///
/// ACHTUNG: Die hier hinterlegten Werte sind Stand 2025/2026 recherchiert, aber
/// Steuerrecht ändert sich. Die Werte sind bewusst als Konstanten an einer
/// Stelle gebündelt und über die Einstellungen überschreibbar. Sie ersetzen
/// keine steuerliche Beratung – siehe docs/COMPLIANCE_AT_DE.md.
enum Country {
  at('AT', 'Österreich'),
  de('DE', 'Deutschland');

  const Country(this.code, this.label);

  final String code;
  final String label;

  static Country fromCode(String code) => Country.values.firstWhere(
    (c) => c.code == code.toUpperCase(),
    orElse: () => Country.at,
  );

  TaxProfile get taxProfile => switch (this) {
    Country.at => TaxProfile.austria,
    Country.de => TaxProfile.germany,
  };
}

/// Ein Umsatzsteuersatz mit Bezeichnung. `permille` statt Prozent, damit auch
/// krumme Sätze (z. B. 10,7 % pauschaliert Land-/Forstwirtschaft DE) darstellbar
/// bleiben, ohne Fließkomma in die Rechnung zu holen.
class VatRate {
  const VatRate({
    required this.permille,
    required this.label,
    this.isDefault = false,
    this.validFrom,
  });

  final int permille;
  final String label;
  final bool isDefault;

  /// Erster Tag (Leistungs- bzw. Belegdatum), ab dem der Satz gilt. `null`:
  /// ohne Beginn. Vorher wird der Satz weder angeboten noch vorbelegt.
  final DateTime? validFrom;

  /// Gilt der Satz für eine Leistung bzw. einen Beleg vom [date]?
  bool isValidOn(DateTime date) =>
      validFrom == null ||
      !DateTime(date.year, date.month, date.day).isBefore(validFrom!);

  double get percent => permille / 10;

  String get display => permille % 10 == 0
      ? '${permille ~/ 10} %'
      : '${percent.toStringAsFixed(1)} %';

  @override
  bool operator ==(Object other) =>
      other is VatRate && other.permille == permille;

  @override
  int get hashCode => permille.hashCode;
}

/// Länderspezifische steuerliche Rahmenbedingungen.
class TaxProfile {
  const TaxProfile({
    required this.country,
    required this.vatRates,
    required this.vatIdLabel,
    required this.taxNumberLabel,
    required this.smallBusinessLabel,
    required this.smallBusinessLegalRef,
    required this.smallBusinessInvoiceNote,
    required this.dunning,
    required this.vatIdExample,
    required this.invoiceRequiresTaxId,
    required this.largeInvoiceVatIdLimit,
    required this.registerNumberLabel,
    required this.registerCourtLabel,
    required this.invoiceLegalRef,
    required this.fxRateLegalRef,
    required this.smallAmountInvoiceLimit,
    required this.currentYearTurnoverLimit,
    required this.previousYearTurnoverLimit,
    required this.toleranceLimit,
    required this.turnoverIncludesVat,
    required this.foundingYearTurnoverLimit,
    required this.retentionYears,
    required this.foreignVatHint,
    required this.noVatShownHint,
    required this.monthNames,
    required this.fiscalYearLegalRef,
    required this.fiscalYearConfirmation,
    required this.fiscalYearHint,
    required this.holidayCalendar,
    required this.asksFederalState,
    required this.deadlineShiftLegalRef,
    required this.vatReturnLabel,
    required this.monthlyVatReturnThreshold,
    required this.vatIntervalBasis,
    required this.vatIntervalLegalRef,
    required this.hasPermanentExtension,
    required this.asksSocialInsurance,
    required this.deadlineRules,
  });

  final Country country;

  /// Verfügbare Steuersätze, absteigend sortiert.
  final List<VatRate> vatRates;

  /// "UID-Nummer" (AT) bzw. "USt-IdNr." (DE).
  final String vatIdLabel;

  /// "Steuernummer" – in beiden Ländern so benannt, aber unterschiedlich formatiert.
  final String taxNumberLabel;

  final String smallBusinessLabel;
  final String smallBusinessLegalRef;

  /// Pflichthinweis, der auf jeder Rechnung eines Kleinunternehmers stehen muss.
  final String smallBusinessInvoiceNote;

  /// Mahnwesen: Verzugszinsen, Pauschale, Verbraucherhinweis (L-3.27 ff.).
  final DunningRules dunning;

  /// Beispiel einer gültigen UID als Eingabehilfe.
  final String vatIdExample;

  /// Muss die Rechnung Steuernummer oder UID des Ausstellers tragen,
  /// unabhängig vom Betrag? DE: § 14 Abs 4 Nr 2 UStG. AT: nein, dort ist die
  /// UID erst ab [largeInvoiceVatIdLimit] Pflicht.
  final bool invoiceRequiresTaxId;

  /// Ab diesem Bruttobetrag braucht eine Rechnung mit Steuerausweis die UID
  /// des Ausstellers und des Empfängers. `null`, wenn es keine solche Grenze
  /// gibt.
  final Money? largeInvoiceVatIdLimit;

  /// Bezeichnungen für die Registerangaben eingetragener Unternehmen.
  final String registerNumberLabel;
  final String registerCourtLabel;

  /// Fundstelle für die Rechnungs-Pflichtangaben.
  final String invoiceLegalRef;

  /// Fundstelle für den Umrechnungskurs fremder Währung in der
  /// Umsatzsteuer (Monatskurs; Tageskurs nur mit Genehmigung, L-2.25).
  final String fxRateLegalRef;

  /// Bis zu diesem Bruttobetrag genügt eine Kleinbetragsrechnung mit
  /// reduzierten Pflichtangaben.
  final Money smallAmountInvoiceLimit;

  /// Umsatzgrenze für das laufende Jahr.
  final Money currentYearTurnoverLimit;

  /// Umsatzgrenze für das Vorjahr. `null`, wenn das Land keine getrennte
  /// Vorjahresgrenze kennt.
  final Money? previousYearTurnoverLimit;

  /// Grenze inklusive Toleranz. Wird sie überschritten, fällt die
  /// Kleinunternehmerbefreiung sofort weg. `null`, wenn es keine Toleranz gibt.
  final Money? toleranceLimit;

  /// Zählt für die Kleinunternehmergrenze der Bruttobetrag? Bei einer
  /// Kleinunternehmerin ist brutto gleich netto; weist sie dennoch
  /// Umsatzsteuer aus (versehentlich oder bei Auslandslieferungen), zählt in
  /// Österreich auch diese Steuer zur Grenze.
  final bool turnoverIncludesVat;

  /// Grenze für das laufende Jahr im Jahr der Gründung. `null`, wenn das Land
  /// keine eigene Gründungsjahrgrenze kennt; dann gilt die normale Grenze.
  final Money? foundingYearTurnoverLimit;

  /// Aufbewahrungsfrist für Buchungsbelege in Jahren.
  final int retentionYears;

  /// Hinweis bei erkannter ausländischer Umsatzsteuer auf einem
  /// Eingangsbeleg (Belegerkennung). Steuerberater-Befund 2026-10-14,
  /// real zu prüfen: Spezifikation 14, P-S30.
  final String foreignVatHint;

  /// Hinweis bei einem Beleg ohne Steuerausweis (z. B. nur Kartenbeleg).
  /// Real zu prüfen: Spezifikation 14, P-S29.
  final String noVatShownHint;

  /// Monatsnamen in der Landessprache (AT „Jänner“, DE „Januar“).
  final List<String> monthNames;

  /// Fundstelle für das abweichende Wirtschaftsjahr (L-24).
  final String fiscalYearLegalRef;

  /// Einmalige Bestätigung bei einem Wirtschaftsjahr, das nicht im Jänner
  /// beginnt (L-24.3). Steuerberater-Befund 2026-10-14, Spezifikation 14,
  /// P-S32.
  final String fiscalYearConfirmation;

  /// Dauerhafter Hinweis in den Einstellungen bei abweichendem
  /// Wirtschaftsjahr.
  final String fiscalYearHint;

  /// Feiertage für die Verschiebung von Fristen (L-25.3).
  final HolidayCalendar holidayCalendar;

  /// Bundesland abfragen? Nur DE: Landesfeiertage verschieben Fristen.
  final bool asksFederalState;

  /// Fundstelle für die Verschiebung auf den nächsten Werktag.
  final String deadlineShiftLegalRef;

  /// „UVA“ (AT) bzw. „UStVA“ (DE).
  final String vatReturnLabel;

  /// Über diesem Vorjahreswert schlägt die App monatliche Voranmeldung vor;
  /// gemessen nach [vatIntervalBasis].
  final Money monthlyVatReturnThreshold;
  final VatIntervalBasis vatIntervalBasis;
  final String vatIntervalLegalRef;

  /// Kennt das Land die Dauerfristverlängerung (DE § 46 UStDV)?
  final bool hasPermanentExtension;

  /// SVS-Beiträge abfragen (nur AT)?
  final bool asksSocialInsurance;

  /// Steuer- und Abgabetermine (L-25), ohne Länder-ifs im Widget.
  final List<DeadlineRule> deadlineRules;

  VatRate get defaultVatRate =>
      vatRates.firstWhere((r) => r.isDefault, orElse: () => vatRates.first);

  /// Sätze, die am [date] gelten (Auswahllisten, Vorbelegung). Ein bereits
  /// gewählter Satz [keep] bleibt enthalten, damit gespeicherte Werte
  /// anzeigbar bleiben.
  List<VatRate> vatRatesOn(DateTime date, {int? keep}) => [
    for (final r in vatRates)
      if (r.isValidOn(date) || r.permille == keep) r,
  ];

  VatRate? rateByPermille(int permille) {
    for (final rate in vatRates) {
      if (rate.permille == permille) return rate;
    }
    return null;
  }

  /// Österreich – § 6 Abs 1 Z 27 UStG in der ab 1.1.2025 geltenden Fassung.
  static final austria = TaxProfile(
    country: Country.at,
    dunning: DunningRules(
      // § 1000 Abs 1 ABGB: 4 % p. a. gegenüber Verbrauchern.
      consumerFixedRateBp: 400,
      consumerSurchargeBp: 0,
      // § 456 UGB: 9,2 Prozentpunkte über dem Basiszinssatz unter
      // Unternehmern; Basiszinssatz am ersten Kalendertag des Halbjahrs.
      businessSurchargeBp: 920,
      consumerInterestLegalRef: '§ 1000 Abs 1 ABGB',
      businessInterestLegalRef: '§ 456 UGB',
      // Basiszinssatz der OeNB (2. Euro-JuBeG). Vorbefund, real zu prüfen:
      // P-S44.
      baseRates: [
        BaseRate(DateTime(2025, 1, 1), 253),
        BaseRate(DateTime(2025, 7, 1), 153),
        BaseRate(DateTime(2026, 1, 1), 153),
      ],
      baseRateLegalRef: 'OeNB-Basiszinssatz, § 456 UGB',
      // § 458 UGB: 40 EUR Pauschale unter Unternehmern.
      flatFee: const Money(4000),
      flatFeeLegalRef: '§ 458 UGB',
      consumerDefaultNotice: null,
      // § 1416 ABGB: Zahlung zuerst auf Kosten, dann Zinsen, dann Kapital.
      paymentAllocationLegalRef: '§ 1416 ABGB',
    ),
    vatRates: [
      VatRate(permille: 200, label: 'Normalsteuersatz', isDefault: true),
      VatRate(permille: 130, label: 'Ermäßigt (z. B. Wein ab Hof, Kunst)'),
      VatRate(
        permille: 100,
        label: 'Ermäßigt (z. B. Lebensmittel, Bücher, Miete)',
      ),
      // § 10 Abs 1a UStG 1994 iVm Anlage 3 (BGBl. I Nr. 37/2026): 4,9 % für
      // Grundnahrungsmittel, Leistungen ab 1.7.2026, unbefristet.
      // Wortlaut und BGBl.-Nr. im RIS abgleichen: Spezifikation 14, P-S28.
      VatRate(
        permille: 49,
        label: '4,9 % (ermäßigt, Grundnahrungsmittel)',
        validFrom: DateTime(2026, 7, 1),
      ),
      VatRate(permille: 0, label: 'Steuerfrei / 0 %'),
    ],
    vatIdLabel: 'UID-Nummer',
    vatIdExample: 'ATU12345678',
    invoiceRequiresTaxId: false,
    // § 11 Abs 1 Z 3 lit i UStG: über 10.000 EUR brutto UID des Empfängers.
    largeInvoiceVatIdLimit: Money(1000000), // 10.000,00 EUR brutto
    // § 14 UGB: eingetragene Unternehmer geben Firmenbuchnummer und -gericht an.
    registerNumberLabel: 'Firmenbuchnummer',
    registerCourtLabel: 'Firmenbuchgericht',
    taxNumberLabel: 'Steuernummer',
    smallBusinessLabel: 'Kleinunternehmerregelung',
    smallBusinessLegalRef: '§ 6 Abs 1 Z 27 UStG',
    smallBusinessInvoiceNote:
        'Umsatzsteuerbefreit – Kleinunternehmer gemäß § 6 Abs 1 Z 27 UStG.',
    invoiceLegalRef: '§ 11 UStG',
    fxRateLegalRef: '§ 20 Abs 6 UStG',
    smallAmountInvoiceLimit: Money(40000), // 400,00 EUR brutto, § 11 Abs 6 UStG
    currentYearTurnoverLimit: Money(5500000), // 55.000,00 EUR
    // § 6 Abs 1 Z 27 UStG: auch der Vorjahresumsatz darf 55.000 EUR nicht
    // überschritten haben; ohne Toleranz. Vom Auftraggeber bestätigt am
    // 2026-10-10 (LASTENHEFT.md O-1).
    previousYearTurnoverLimit: Money(5500000), // 55.000,00 EUR
    toleranceLimit: Money(6050000), // 55.000 + 10 % Toleranz
    // § 6 Abs 1 Z 27 UStG: Bruttobetrag; ausgewiesene Umsatzsteuer zählt mit.
    // Vom Auftraggeber bestätigt am 2026-10-10 (Spezifikation 14, P-S1).
    turnoverIncludesVat: true,
    foundingYearTurnoverLimit: null,
    retentionYears: 7, // § 132 BAO
    // § 12 Abs 1 Z 1 UStG 1994: nur österreichische USt ist Vorsteuer;
    // Erstattung nach § 21 Abs 9 UStG iVm VO BGBl. II Nr. 222/2009
    // (Richtlinie 2008/9/EG), Antrag über FinanzOnline bis 30.09. des
    // Folgejahres; Mindestbeträge Art. 17 RL 2008/9/EG.
    foreignVatHint:
        'Ausländische Umsatzsteuer (z. B. SI 22 %, DK 25 %) ist in der UVA '
        'nicht als Vorsteuer abziehbar. Sie wird brutto als Ausgabe erfasst. '
        'Eine Erstattung ist nur über das EU-Vorsteuer-Erstattungsverfahren '
        '(FinanzOnline, Frist 30.09. des Folgejahres, Mindestbetrag '
        '50 €/400 €) möglich – nicht für Kleinunternehmer.',
    // § 11 Abs 6 und § 12 Abs 1 Z 1 UStG 1994: Vorsteuer nur aus einer
    // Rechnung mit Steuersatz.
    noVatShownHint:
        'Beleg ohne Steuerausweis – kein Vorsteuerabzug. Für den Abzug '
        'Rechnung mit Steuersatz beim Aussteller anfordern '
        '(Kleinbetragsrechnung § 11 Abs. 6 UStG).',
    monthNames: const [
      'Jänner',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember',
    ],
    // § 2 Abs 5 EStG 1988: abweichendes Wirtschaftsjahr nur für
    // protokollierte (im Firmenbuch eingetragene), bilanzierende
    // Gewerbetreibende; Umstellung nur mit Zustimmung des Finanzamts.
    fiscalYearLegalRef: '§ 2 Abs 5 EStG',
    fiscalYearConfirmation:
        'Ein Wirtschaftsjahr, das nicht im Jänner beginnt, ist nur zulässig, '
        'wenn dein Unternehmen im Firmenbuch eingetragen ist, bilanziert und '
        'die Zustimmung des Finanzamts vorliegt (§ 2 Abs 5 EStG). '
        'Umsatzsteuer, UVA und Kleinunternehmergrenze bleiben beim '
        'Kalenderjahr.',
    fiscalYearHint:
        'Abweichendes Wirtschaftsjahr: nur für eingetragene, bilanzierende '
        'Unternehmen mit Zustimmung des Finanzamts. Umsatzsteuer bleibt '
        'beim Kalenderjahr.',
    holidayCalendar: HolidayCalendar.austria,
    // Abgabenfristen: bundeseinheitliche Feiertage reichen, § 108 Abs 3 BAO.
    asksFederalState: false,
    deadlineShiftLegalRef: '§ 108 Abs 3 BAO',
    vatReturnLabel: 'UVA',
    // § 21 Abs 2 UStG 1994: Vorjahresumsatz bis 100.000 EUR →
    // Kalendervierteljahr, darüber Kalendermonat. Real zu prüfen: P-S33.
    monthlyVatReturnThreshold: Money(10000000), // 100.000,00 EUR
    vatIntervalBasis: VatIntervalBasis.previousYearTurnover,
    vatIntervalLegalRef: '§ 21 Abs 2 UStG',
    hasPermanentExtension: false,
    asksSocialInsurance: true,
    deadlineRules: const [
      // § 21 Abs 1 UStG 1994: 15. des zweitfolgenden Monats.
      DeadlineRule(
        label: 'UVA',
        legalRef: '§ 21 Abs 1 UStG',
        schedule: AfterPeriod(dueDay: 15, monthsAfter: 2),
        condition: DeadlineCondition.notSmallBusiness,
      ),
      // Art. 21 Abs 10 UStG 1994 (Binnenmarktregelung): Ende des auf den
      // Meldezeitraum folgenden Monats.
      DeadlineRule(
        label: 'ZM',
        legalRef: 'Art. 21 Abs 10 UStG',
        schedule: AfterPeriod(dueDay: 0, monthsAfter: 1),
        condition: DeadlineCondition.filesEcsl,
      ),
      // § 45 Abs 2 EStG 1988: Vorauszahlungen am 15.2., 15.5., 15.8., 15.11.
      DeadlineRule(
        label: 'ESt-Vorauszahlung',
        legalRef: '§ 45 Abs 2 EStG',
        schedule: FixedDates([(2, 15), (5, 15), (8, 15), (11, 15)]),
      ),
      // § 134 Abs 1 BAO: Erklärungen bis 30.04. (Papier) bzw. 30.06.
      // (FinanzOnline) des Folgejahres; mit Steuerberatung Quotenregelung
      // § 134a BAO, daher „laut Kanzlei“. Real zu prüfen: P-S33.
      DeadlineRule(
        label: 'ESt-/USt-Erklärung (FinanzOnline)',
        legalRef: '§ 134 Abs 1 BAO',
        schedule: FollowingYear(month: 6, day: 30),
        condition: DeadlineCondition.annualReturn,
      ),
      // § 35 Abs 1 GSVG: Beiträge Ende Feb., Mai, Aug., Nov. fällig.
      // Verschiebung bei Wochenende unsicher → „ca.“ (P-S34).
      DeadlineRule(
        label: 'SVS-Beitrag',
        legalRef: '§ 35 Abs 1 GSVG',
        schedule: FixedDates([(2, 0), (5, 0), (8, 0), (11, 0)]),
        condition: DeadlineCondition.socialInsurance,
        approximate: true,
      ),
    ],
  );

  /// Deutschland – § 19 UStG in der ab 1.1.2025 geltenden Fassung.
  static final germany = TaxProfile(
    country: Country.de,
    dunning: DunningRules(
      // § 288 Abs 1 BGB: 5 Prozentpunkte über dem Basiszinssatz.
      consumerFixedRateBp: null,
      consumerSurchargeBp: 500,
      // § 288 Abs 2 BGB: 9 Prozentpunkte, wenn kein Verbraucher beteiligt.
      businessSurchargeBp: 900,
      consumerInterestLegalRef: '§ 288 Abs 1 BGB',
      businessInterestLegalRef: '§ 288 Abs 2 BGB',
      // § 247 BGB, Bekanntmachung der Bundesbank zum 1.1. und 1.7.
      // Vorbefund, real zu prüfen: P-S44.
      baseRates: [
        BaseRate(DateTime(2025, 1, 1), 227),
        BaseRate(DateTime(2025, 7, 1), 127),
        BaseRate(DateTime(2026, 1, 1), 127),
      ],
      baseRateLegalRef: '§ 247 BGB',
      // § 288 Abs 5 BGB: 40 EUR Pauschale, nicht gegenüber Verbrauchern.
      flatFee: const Money(4000),
      flatFeeLegalRef: '§ 288 Abs 5 BGB',
      // § 286 Abs 3 Satz 1 BGB: Verbraucher kommen nach 30 Tagen nur in
      // Verzug, wenn die Rechnung darauf hinweist.
      consumerDefaultNotice:
          'Hinweis nach § 286 Abs. 3 BGB: Wird die Rechnung nicht '
          'innerhalb von 30 Tagen nach Fälligkeit und Zugang bezahlt, tritt '
          'Verzug auch ohne Mahnung ein.',
      // § 367 Abs 1 BGB: Kosten, dann Zinsen, dann Hauptleistung.
      paymentAllocationLegalRef: '§ 367 BGB',
    ),
    vatRates: [
      VatRate(permille: 190, label: 'Regelsteuersatz', isDefault: true),
      VatRate(permille: 70, label: 'Ermäßigt (z. B. Lebensmittel, Bücher)'),
      VatRate(permille: 0, label: 'Steuerfrei / 0 %'),
    ],
    vatIdLabel: 'USt-IdNr.',
    vatIdExample: 'DE123456789',
    // § 14 Abs 4 Nr 2 UStG: Steuernummer oder USt-IdNr. auf jeder Rechnung.
    invoiceRequiresTaxId: true,
    largeInvoiceVatIdLimit: null,
    // § 37a HGB: eingetragene Kaufleute geben Registergericht und -nummer an.
    registerNumberLabel: 'Handelsregisternummer',
    registerCourtLabel: 'Registergericht',
    taxNumberLabel: 'Steuernummer',
    smallBusinessLabel: 'Kleinunternehmerregelung',
    smallBusinessLegalRef: '§ 19 UStG',
    smallBusinessInvoiceNote:
        // Seit 2025 sind Kleinunternehmerumsätze steuerfrei; Hinweis auf die
        // Steuerbefreiung nach § 34a UStDV (Spezifikation 14, P-S8).
        'Steuerbefreiung nach § 19 UStG (Kleinunternehmer).',
    invoiceLegalRef: '§ 14 UStG',
    fxRateLegalRef: '§ 16 Abs 6 UStG',
    smallAmountInvoiceLimit: Money(25000), // 250,00 EUR brutto, § 33 UStDV
    currentYearTurnoverLimit: Money(10000000), // 100.000,00 EUR
    previousYearTurnoverLimit: Money(2500000), // 25.000,00 EUR
    toleranceLimit:
        null, // DE kennt keine Toleranz: bei Überschreiten sofortiger Wegfall
    // § 19 Abs 2 UStG: Gesamtumsatz nach vereinnahmten Entgelten, also netto.
    turnoverIncludesVat: false,
    // § 19 Abs 1 UStG: im Jahr der Aufnahme der Tätigkeit darf der Umsatz
    // 25.000 EUR nicht überschreiten (statt 100.000 EUR).
    foundingYearTurnoverLimit: Money(2500000), // 25.000,00 EUR
    retentionYears: 8, // § 147 AO, Buchungsbelege ab 2025 verkürzt
    // § 15 Abs 1 Nr 1 UStG: nur deutsche USt ist Vorsteuer; Vergütung nach
    // § 18 Abs 9 UStG iVm §§ 59–61 UStDV über das BZSt-Online-Portal,
    // Frist 30.09. des Folgejahres (§ 61 Abs 1 UStDV).
    foreignVatHint:
        'Ausländische Umsatzsteuer (z. B. SI 22 %, DK 25 %) ist in der '
        'Umsatzsteuer-Voranmeldung nicht als Vorsteuer abziehbar. Sie wird '
        'brutto als Ausgabe erfasst. Eine Erstattung ist nur über das '
        'Vorsteuer-Vergütungsverfahren beim BZSt (Frist 30.09. des '
        'Folgejahres, Mindestbetrag 50 €/400 €) möglich – nicht für '
        'Kleinunternehmer.',
    // § 15 Abs 1 Nr 1 UStG, § 33 UStDV: Vorsteuer nur aus einer Rechnung
    // mit Steuersatz.
    noVatShownHint:
        'Beleg ohne Steuerausweis – kein Vorsteuerabzug. Für den Abzug '
        'Rechnung mit Steuersatz beim Aussteller anfordern '
        '(Kleinbetragsrechnung § 33 UStDV).',
    monthNames: const [
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember',
    ],
    // § 4a Abs 1 Nr 2 EStG: abweichendes Wirtschaftsjahr nur für im
    // Handelsregister eingetragene Gewerbetreibende; Umstellung nur im
    // Einvernehmen mit dem Finanzamt.
    fiscalYearLegalRef: '§ 4a EStG',
    fiscalYearConfirmation:
        'Ein Wirtschaftsjahr, das nicht im Januar beginnt, ist nur zulässig, '
        'wenn dein Unternehmen im Handelsregister eingetragen ist und das '
        'Einvernehmen mit dem Finanzamt besteht (§ 4a EStG). Umsatzsteuer, '
        'UStVA und Kleinunternehmergrenze bleiben beim Kalenderjahr.',
    fiscalYearHint:
        'Abweichendes Wirtschaftsjahr: nur für im Handelsregister '
        'eingetragene Gewerbetreibende im Einvernehmen mit dem Finanzamt. '
        'Umsatzsteuer bleibt beim Kalenderjahr.',
    holidayCalendar: HolidayCalendar.germany,
    asksFederalState: true,
    deadlineShiftLegalRef: '§ 108 Abs 3 AO',
    vatReturnLabel: 'UStVA',
    // § 18 Abs 2 UStG idF ab 2025: Vorjahressteuer über 9.000 EUR →
    // Kalendermonat, sonst Kalendervierteljahr. Real zu prüfen: P-S33.
    monthlyVatReturnThreshold: Money(900000), // 9.000,00 EUR
    vatIntervalBasis: VatIntervalBasis.previousYearVat,
    vatIntervalLegalRef: '§ 18 Abs 2 UStG',
    hasPermanentExtension: true,
    asksSocialInsurance: false,
    deadlineRules: const [
      // § 18 Abs 1 UStG: 10. Tag nach Ablauf des Voranmeldungszeitraums;
      // Dauerfristverlängerung um einen Monat, §§ 46 ff. UStDV.
      DeadlineRule(
        label: 'UStVA',
        legalRef: '§ 18 Abs 1 UStG, § 46 UStDV',
        schedule: AfterPeriod(dueDay: 10, monthsAfter: 1, extensionMonths: 1),
        condition: DeadlineCondition.notSmallBusiness,
      ),
      // § 18a Abs 1 UStG: 25. Tag nach Ablauf des Meldezeitraums.
      DeadlineRule(
        label: 'ZM',
        legalRef: '§ 18a Abs 1 UStG',
        schedule: AfterPeriod(dueDay: 25, monthsAfter: 1),
        condition: DeadlineCondition.filesEcsl,
      ),
      // § 37 Abs 1 EStG: 10.3., 10.6., 10.9., 10.12.
      DeadlineRule(
        label: 'ESt-Vorauszahlung',
        legalRef: '§ 37 Abs 1 EStG',
        schedule: FixedDates([(3, 10), (6, 10), (9, 10), (12, 10)]),
      ),
      // § 149 Abs 2 AO: 31.07. des Folgejahres; mit Beratung § 149 Abs 3 AO
      // (später, „laut Kanzlei“). Real zu prüfen: P-S33.
      DeadlineRule(
        label: 'Steuererklärungen',
        legalRef: '§ 149 Abs 2 AO',
        schedule: FollowingYear(month: 7, day: 31),
        condition: DeadlineCondition.annualReturn,
      ),
    ],
  );
}
