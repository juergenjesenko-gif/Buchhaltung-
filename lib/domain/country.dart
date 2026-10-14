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
  );

  /// Deutschland – § 19 UStG in der ab 1.1.2025 geltenden Fassung.
  static final germany = TaxProfile(
    country: Country.de,
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
  );
}
