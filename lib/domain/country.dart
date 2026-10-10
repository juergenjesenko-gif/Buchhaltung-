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
  });

  final int permille;
  final String label;
  final bool isDefault;

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
    required this.invoiceLegalRef,
    required this.smallAmountInvoiceLimit,
    required this.currentYearTurnoverLimit,
    required this.previousYearTurnoverLimit,
    required this.toleranceLimit,
    required this.turnoverIncludesVat,
    required this.foundingYearTurnoverLimit,
    required this.retentionYears,
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

  /// Fundstelle für die Rechnungs-Pflichtangaben.
  final String invoiceLegalRef;

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

  VatRate get defaultVatRate =>
      vatRates.firstWhere((r) => r.isDefault, orElse: () => vatRates.first);

  VatRate? rateByPermille(int permille) {
    for (final rate in vatRates) {
      if (rate.permille == permille) return rate;
    }
    return null;
  }

  /// Österreich – § 6 Abs 1 Z 27 UStG in der ab 1.1.2025 geltenden Fassung.
  static const austria = TaxProfile(
    country: Country.at,
    vatRates: [
      VatRate(permille: 200, label: 'Normalsteuersatz', isDefault: true),
      VatRate(permille: 130, label: 'Ermäßigt (z. B. Wein ab Hof, Kunst)'),
      VatRate(
        permille: 100,
        label: 'Ermäßigt (z. B. Lebensmittel, Bücher, Miete)',
      ),
      VatRate(permille: 0, label: 'Steuerfrei / 0 %'),
    ],
    vatIdLabel: 'UID-Nummer',
    vatIdExample: 'ATU12345678',
    taxNumberLabel: 'Steuernummer',
    smallBusinessLabel: 'Kleinunternehmerregelung',
    smallBusinessLegalRef: '§ 6 Abs 1 Z 27 UStG',
    smallBusinessInvoiceNote:
        'Umsatzsteuerbefreit – Kleinunternehmer gemäß § 6 Abs 1 Z 27 UStG.',
    invoiceLegalRef: '§ 11 UStG',
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
  );

  /// Deutschland – § 19 UStG in der ab 1.1.2025 geltenden Fassung.
  static const germany = TaxProfile(
    country: Country.de,
    vatRates: [
      VatRate(permille: 190, label: 'Regelsteuersatz', isDefault: true),
      VatRate(permille: 70, label: 'Ermäßigt (z. B. Lebensmittel, Bücher)'),
      VatRate(permille: 0, label: 'Steuerfrei / 0 %'),
    ],
    vatIdLabel: 'USt-IdNr.',
    vatIdExample: 'DE123456789',
    taxNumberLabel: 'Steuernummer',
    smallBusinessLabel: 'Kleinunternehmerregelung',
    smallBusinessLegalRef: '§ 19 UStG',
    smallBusinessInvoiceNote:
        // Seit 2025 sind Kleinunternehmerumsätze steuerfrei; Hinweis auf die
        // Steuerbefreiung nach § 34a UStDV (Spezifikation 14, P-S8).
        'Steuerbefreiung nach § 19 UStG (Kleinunternehmer).',
    invoiceLegalRef: '§ 14 UStG',
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
  );
}
