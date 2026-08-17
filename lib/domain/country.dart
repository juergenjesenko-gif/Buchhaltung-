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
    required this.invoiceLegalRef,
    required this.smallAmountInvoiceLimit,
    required this.currentYearTurnoverLimit,
    required this.previousYearTurnoverLimit,
    required this.toleranceLimit,
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

  /// Fundstelle für die Rechnungs-Pflichtangaben.
  final String invoiceLegalRef;

  /// Bis zu diesem Bruttobetrag genügt eine Kleinbetragsrechnung mit
  /// reduzierten Pflichtangaben.
  final Money smallAmountInvoiceLimit;

  /// Umsatzgrenze für das laufende Jahr.
  final Money currentYearTurnoverLimit;

  /// Umsatzgrenze für das Vorjahr. `null`, wenn das Land keine getrennte
  /// Vorjahresgrenze kennt (Österreich).
  final Money? previousYearTurnoverLimit;

  /// Grenze inklusive Toleranz. Wird sie überschritten, fällt die
  /// Kleinunternehmerbefreiung sofort weg. `null`, wenn es keine Toleranz gibt.
  final Money? toleranceLimit;

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
    taxNumberLabel: 'Steuernummer',
    smallBusinessLabel: 'Kleinunternehmerregelung',
    smallBusinessLegalRef: '§ 6 Abs 1 Z 27 UStG',
    smallBusinessInvoiceNote:
        'Umsatzsteuerbefreit – Kleinunternehmer gemäß § 6 Abs 1 Z 27 UStG.',
    invoiceLegalRef: '§ 11 UStG',
    smallAmountInvoiceLimit: Money(40000), // 400,00 EUR brutto, § 11 Abs 6 UStG
    currentYearTurnoverLimit: Money(5500000), // 55.000,00 EUR
    previousYearTurnoverLimit: null,
    toleranceLimit: Money(6050000), // 55.000 + 10 % Toleranz
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
    taxNumberLabel: 'Steuernummer',
    smallBusinessLabel: 'Kleinunternehmerregelung',
    smallBusinessLegalRef: '§ 19 UStG',
    smallBusinessInvoiceNote:
        'Gemäß § 19 UStG wird keine Umsatzsteuer berechnet (Kleinunternehmer).',
    invoiceLegalRef: '§ 14 UStG',
    smallAmountInvoiceLimit: Money(25000), // 250,00 EUR brutto, § 33 UStDV
    currentYearTurnoverLimit: Money(10000000), // 100.000,00 EUR
    previousYearTurnoverLimit: Money(2500000), // 25.000,00 EUR
    toleranceLimit:
        null, // DE kennt keine Toleranz: bei Überschreiten sofortiger Wegfall
    retentionYears: 8, // § 147 AO, Buchungsbelege ab 2025 verkürzt
  );
}
