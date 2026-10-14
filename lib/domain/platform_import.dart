import 'money.dart';

/// Verkaufsplattformen und Zahlungsdienste, deren Standardexporte die App
/// ohne Server liest (L-28.1).
enum SalesPlatform {
  amazon('Amazon'),
  paypal('PayPal'),
  shopify('Shopify'),
  stripe('Stripe');

  const SalesPlatform(this.label);
  final String label;

  static SalesPlatform? fromName(String? name) {
    for (final p in values) {
      if (p.name == name) return p;
    }
    return null;
  }
}

/// Die erkannten Dateiformate.
enum PlatformFormat {
  amazonDateRange(SalesPlatform.amazon, 'Transaktionsbericht (Zeitraum)'),
  amazonSettlementV2(SalesPlatform.amazon, 'Abrechnung (Flatfile V2)'),
  paypalActivity(SalesPlatform.paypal, 'Aktivitäten'),
  shopifyPayouts(SalesPlatform.shopify, 'Auszahlungen (Transaktionen)'),
  shopifyOrders(SalesPlatform.shopify, 'Bestellungen'),
  stripeBalance(SalesPlatform.stripe, 'Saldo-Transaktionen');

  const PlatformFormat(this.platform, this.label);
  final SalesPlatform platform;
  final String label;

  static PlatformFormat? fromName(String? name) {
    for (final f in values) {
      if (f.name == name) return f;
    }
    return null;
  }
}

/// Art einer Zeile nach dem Bruttoprinzip: Umsätze, Gebühren und Werbung
/// werden getrennt gebucht; die Auszahlung ist nur ein Geldtransfer.
enum PlatformEntryKind { sale, refund, fee, advertising, payout, other }

/// Umsatzsteuerliche Behandlung der Gebühren eines Plattformbetreibers.
enum FeeVatTreatment {
  /// Sonstige Leistung eines im EU-Ausland ansässigen Unternehmers:
  /// Steuerschuld geht auf den Empfänger über (AT § 19 Abs 1 zweiter Satz
  /// iVm § 3a Abs 6 UStG 1994; DE § 13b Abs 1 und Abs 5 UStG).
  reverseCharge,

  /// Steuerfreier Finanzumsatz (Art 135 Abs 1 lit d MwStSystRL; AT § 6 Abs 1
  /// Z 8 lit c UStG 1994; DE § 4 Nr 8 Buchst d UStG). Prüfpunkt P-S54.
  exemptFinancial,
}

/// Leistender der Gebühren je Plattform (Befund Steuerberater, Prüfpunkte
/// P-S52 und P-S54 in Spezifikation 14).
class FeeSupplier {
  const FeeSupplier(this.name, this.countryCode, this.treatment);

  final String name;
  final String countryCode;
  final FeeVatTreatment treatment;

  bool get isReverseCharge => treatment == FeeVatTreatment.reverseCharge;

  static FeeSupplier of(SalesPlatform platform) => switch (platform) {
    // Amazon EU S.à r.l., 38 avenue John F. Kennedy, L-1855 Luxemburg.
    SalesPlatform.amazon => const FeeSupplier(
      'Amazon EU S.à r.l.',
      'LU',
      FeeVatTreatment.reverseCharge,
    ),
    // PayPal (Europe) S.à r.l. et Cie, S.C.A., Luxemburg; Zahlungsabwicklung
    // als Finanzumsatz steuerfrei – Prüfpunkt P-S54.
    SalesPlatform.paypal => const FeeSupplier(
      'PayPal (Europe) S.à r.l. et Cie, S.C.A.',
      'LU',
      FeeVatTreatment.exemptFinancial,
    ),
    // Stripe-Gebühren: Stripe stellt sie mit Hinweis auf Reverse Charge in
    // Rechnung; Leistender laut Vertrag prüfen – Prüfpunkt P-S54.
    SalesPlatform.stripe => const FeeSupplier(
      'Stripe Technology Europe Ltd.',
      'IE',
      FeeVatTreatment.reverseCharge,
    ),
    // Shopify Payments: Shopify International Ltd., Dublin – P-S54.
    SalesPlatform.shopify => const FeeSupplier(
      'Shopify International Ltd.',
      'IE',
      FeeVatTreatment.reverseCharge,
    ),
  };
}

/// Eine gelesene Zeile eines Plattformexports – nur die für die Buchung
/// nötigen Felder. Käuferdaten (Name, Adresse, E-Mail, Telefon) gibt es in
/// diesem Typ bewusst nicht (L-28.6).
class PlatformEntry {
  const PlatformEntry({
    required this.externalId,
    required this.date,
    required this.kind,
    required this.amount,
    this.tax = const Money.zero(),
    this.currency = 'EUR',
    this.orderRef = '',
    this.destinationCountry,
    this.fulfilledByPlatform = false,
    this.marketplaceCollectedTax = false,
  });

  /// Eindeutige Kennung je Plattform (Transaktions-ID bzw. Prüfsumme aus
  /// Abrechnungsnummer und Zeileninhalt) für das Überspringen von Dubletten.
  final String externalId;
  final DateTime date;
  final PlatformEntryKind kind;

  /// Vorzeichenbehaftet aus Sicht des Händlers: Verkauf positiv, Gebühr
  /// negativ, Auszahlung negativ (Geld verlässt das Plattformkonto).
  final Money amount;

  /// In [amount] enthaltene Umsatzsteuer laut Bericht, sonst 0.
  final Money tax;
  final String currency;

  /// Bestellnummer, nur zum Zählen der Verkäufe.
  final String orderRef;

  /// Bestimmungsland (ISO 3166-1 alpha-2) für die OSS-Warnung, soweit der
  /// Bericht es angibt (Marktplatz bzw. Lieferland).
  final String? destinationCountry;

  /// Versand durch die Plattform (FBA) – Hinweis auf Lager im Ausland.
  final bool fulfilledByPlatform;

  /// Plattform hat die Umsatzsteuer selbst abgeführt (Marketplace Facilitator).
  final bool marketplaceCollectedTax;
}

/// Ergebnis des Einlesens einer Datei.
class PlatformImportFile {
  const PlatformImportFile({
    required this.format,
    required this.entries,
    this.skippedForeignCurrency = 0,
    this.skippedUnreadable = 0,
  });

  final PlatformFormat format;
  final List<PlatformEntry> entries;

  /// Zeilen in anderer Währung als Euro – nicht übernommen.
  final int skippedForeignCurrency;

  /// Zeilen ohne lesbares Datum oder Betrag.
  final int skippedUnreadable;

  SalesPlatform get platform => format.platform;
}
