import '../../domain/country.dart';
import '../../domain/money.dart';
import '../../domain/platform_import.dart';
import '../../domain/receipt.dart';
import '../../domain/tax_registration.dart';
import '../vat_calculator.dart';

/// Grenze für Fernverkäufe an Privatpersonen in andere EU-Länder, ab der
/// die Umsatzsteuer des Bestimmungslands gilt (OSS): 10.000 € je
/// Kalenderjahr, EU-weit (Art 59c MwStSystRL; AT Art 3 Abs 5 UStG 1994
/// Binnenmarktregelung; DE § 3c Abs 4 UStG). Prüfpunkt P-S53.
const ossThreshold = Money(1000000);

/// EU-Mitgliedstaaten (ISO 3166-1 alpha-2) für die OSS-Warnung.
const euCountries = {
  'AT', 'BE', 'BG', 'CY', 'CZ', 'DE', 'DK', 'EE', 'ES', 'FI', 'FR', //
  'GR', 'EL', 'HR', 'HU', 'IE', 'IT', 'LT', 'LU', 'LV', 'MT', 'NL', 'PL',
  'PT', 'RO', 'SE', 'SI', 'SK',
};

/// Seite in Seller Central mit den monatlichen Gebührenrechnungen (L-28.7).
const amazonFeeInvoiceUrl =
    'https://sellercentral.amazon.de/tax/seller-fee-invoices';

/// Zahlen eines Monats für die Zusammenfassung (L-28.2).
class PlatformMonthSummary {
  PlatformMonthSummary(this.month);

  final DateTime month;
  int saleCount = 0;
  Money sales = const Money.zero();
  Money refunds = const Money.zero();
  Money salesTax = const Money.zero();

  /// Positiv = Aufwand.
  Money fees = const Money.zero();
  Money advertising = const Money.zero();

  /// Positiv = an die Bank ausgezahlt.
  Money payout = const Money.zero();
  Money other = const Money.zero();
  int newEntries = 0;
  int duplicates = 0;

  Money get salesTotal => sales + refunds;
}

/// Ein vorbereiteter Beleg aus dem Import.
class PlatformBookingDraft {
  const PlatformBookingDraft({
    required this.receipt,
    required this.entryIds,
    required this.categoryName,
  });

  final Receipt receipt;
  final List<String> entryIds;

  /// Name der Startkategorie (Abschnitt 4 der Spezifikation).
  final String categoryName;
}

/// Was beim Tippen auf „Übernehmen“ passiert – vollständig vorab berechnet,
/// damit die Anzeige genau das zeigt, was gebucht wird.
class PlatformImportPlan {
  const PlatformImportPlan({
    required this.file,
    required this.months,
    required this.drafts,
    required this.newEntries,
    required this.duplicates,
    required this.warnings,
    required this.feeSupplier,
  });

  final PlatformImportFile file;
  final List<PlatformMonthSummary> months;
  final List<PlatformBookingDraft> drafts;

  /// Zeilen, die neu gemerkt werden (inkl. Auszahlungen, ohne Dubletten).
  final List<PlatformEntry> newEntries;
  final int duplicates;
  final List<String> warnings;
  final FeeSupplier feeSupplier;

  bool get hasAnythingNew => newEntries.isNotEmpty;
}

/// Baut aus den gelesenen Zeilen Monatszusammenfassung und Belege
/// (Bruttoprinzip, L-28.3): Umsatz als Einnahme, Gebühren und Werbung als
/// eigene Ausgaben mit Reverse Charge bzw. steuerfrei, Auszahlung nur als
/// Geldtransfer ohne Buchung.
class PlatformImportPlanner {
  const PlatformImportPlanner._();

  static PlatformImportPlan plan({
    required PlatformImportFile file,
    required Set<String> knownIds,
    required Country country,
    required bool isSmallBusiness,
    Map<String, Set<String>> otherFormatMonths = const {},
    List<TaxRegistration> registrations = const [],
  }) {
    // Steuerland je Verkauf (FA-18.9): Abgangsland laut Bericht, sonst bei
    // Versand durch die Plattform das Marktplatzland, wenn dort eine
    // Registrierung besteht (Annahme Lager im Marktplatzland, P-S73).
    var assumedStorage = false;
    var distanceFromStorage = false;
    TaxRegistration? registrationFor(PlatformEntry e) {
      var from = e.shipFromCountry;
      var assumed = false;
      if (from == null && e.fulfilledByPlatform) {
        from = e.destinationCountry;
        assumed = true;
      }
      if (from == null || from == country.code) return null;
      for (final reg in registrations) {
        if (reg.country.code == from && reg.activeOn(e.date)) {
          if (assumed) assumedStorage = true;
          final dest = e.destinationCountry;
          if (dest != null && dest != from) distanceFromStorage = true;
          return reg;
        }
      }
      return null;
    }

    final profile = country.taxProfile;
    final supplier = FeeSupplier.of(file.platform);
    final byMonth = <String, PlatformMonthSummary>{};
    final monthEntries = <String, List<PlatformEntry>>{};
    final fresh = <PlatformEntry>[];
    final seenInFile = <String>{};
    var duplicates = 0;

    for (final e in file.entries) {
      final key = _monthKey(e.date);
      final summary = byMonth.putIfAbsent(
        key,
        () => PlatformMonthSummary(DateTime(e.date.year, e.date.month)),
      );
      // Dubletten (schon übernommen oder doppelt in der Datei) still
      // überspringen (L-28.5).
      if (knownIds.contains(e.externalId) || !seenInFile.add(e.externalId)) {
        summary.duplicates++;
        duplicates++;
        continue;
      }
      summary.newEntries++;
      fresh.add(e);
      monthEntries.putIfAbsent(key, () => []).add(e);
    }

    final warnings = <String>[];
    final drafts = <PlatformBookingDraft>[];
    final keys = monthEntries.keys.toList()..sort();
    for (final key in keys) {
      final summary = byMonth[key]!;
      final entries = monthEntries[key]!;
      final orders = <String>{};
      // Verkäufe je Steuerland: null = Heimat (FA-18.9).
      final saleIds = <int?, List<String>>{};
      final saleSum = <int?, Money>{};
      final saleTax = <int?, Money>{};
      final saleOrders = <int?, Set<String>>{};
      final regById = <int?, TaxRegistration?>{null: null};
      void addSale(PlatformEntry e) {
        final reg = registrationFor(e);
        final k = reg?.id;
        regById[k] = reg;
        saleIds.putIfAbsent(k, () => []).add(e.externalId);
        saleSum[k] = (saleSum[k] ?? const Money.zero()) + e.amount;
        saleTax[k] = (saleTax[k] ?? const Money.zero()) + e.tax;
        if (e.kind == PlatformEntryKind.sale) {
          saleOrders
              .putIfAbsent(k, () => {})
              .add(e.orderRef.isEmpty ? e.externalId : e.orderRef);
        }
      }

      final feeIds = <String>[];
      final adIds = <String>[];
      var last = entries.first.date;
      for (final e in entries) {
        if (e.date.isAfter(last)) last = e.date;
        switch (e.kind) {
          case PlatformEntryKind.sale:
            summary.sales += e.amount;
            summary.salesTax += e.tax;
            orders.add(e.orderRef.isEmpty ? e.externalId : e.orderRef);
            addSale(e);
          case PlatformEntryKind.refund:
            summary.refunds += e.amount;
            summary.salesTax += e.tax;
            addSale(e);
          case PlatformEntryKind.fee:
            summary.fees -= e.amount;
            feeIds.add(e.externalId);
          case PlatformEntryKind.advertising:
            summary.advertising -= e.amount;
            adIds.add(e.externalId);
          case PlatformEntryKind.payout:
            summary.payout -= e.amount;
          case PlatformEntryKind.other:
            summary.other += e.amount;
        }
      }
      summary.saleCount = orders.length;
      final label =
          '${file.platform.label} ${monthLabel(summary.month, profile)}';

      // Umsatz (Einnahme), je Steuerland eine Sammelbuchung.
      for (final k in saleSum.keys) {
        final reg = regById[k];
        final sales = saleSum[k]!;
        final where = reg == null ? '' : ' (${reg.shortLabel})';
        if (sales.isNegative) {
          warnings.add(
            '$label$where: mehr Erstattungen als Verkäufe – bitte selbst '
            'buchen.',
          );
          continue;
        }
        if (sales.isZero) continue;
        final small = reg == null ? isSmallBusiness : reg.isSmallBusiness;
        final split = small
            ? VatCalculator.exempt(sales)
            : _salesSplit(sales, saleTax[k]!, reg?.taxProfile ?? profile);
        final count = saleOrders[k]?.length ?? 0;
        drafts.add(
          PlatformBookingDraft(
            categoryName: 'Umsatzerlöse',
            entryIds: saleIds[k]!,
            receipt: Receipt(
              date: last,
              direction: BookingDirection.income,
              description: '$label$where: $count Verkäufe',
              counterparty: '${file.platform.label}-Kunden (Sammelbuchung)',
              net: split.net,
              vat: split.vat,
              gross: split.gross,
              vatPermille: split.permille,
              paymentMethod: PaymentMethod.other,
              note: reg == null
                  ? 'Import ${file.format.label}'
                  : 'Import ${file.format.label}, Steuerland '
                        '${reg.country.label}',
              taxRegistrationId: reg?.id,
            ),
          ),
        );
      }

      // Gebühren und Werbung (Ausgaben, Bruttoprinzip).
      for (final (amount, ids, category, what) in [
        (summary.fees, feeIds, 'Bankspesen', 'Gebühren'),
        (summary.advertising, adIds, 'Werbung & Marketing', 'Werbung'),
      ]) {
        if (amount.isZero) continue;
        if (amount.isNegative) {
          warnings.add(
            '$label: $what insgesamt gutgeschrieben – bitte selbst buchen.',
          );
          continue;
        }
        drafts.add(
          PlatformBookingDraft(
            categoryName:
                file.platform == SalesPlatform.amazon && what == 'Gebühren'
                ? 'Beiträge & Gebühren'
                : category,
            entryIds: ids,
            receipt: Receipt(
              date: last,
              direction: BookingDirection.expense,
              description: '$label: $what',
              counterparty: supplier.name,
              net: amount,
              vat: const Money.zero(),
              gross: amount,
              vatPermille: 0,
              paymentMethod: PaymentMethod.other,
              reverseCharge: supplier.isReverseCharge,
              note: supplier.isReverseCharge
                  ? 'Reverse Charge, ${profile.reverseCharge.legalRef}'
                  : 'Steuerfreier Finanzumsatz (Prüfpunkt P-S54)',
            ),
          ),
        );
      }
      if (!summary.other.isZero) {
        warnings.add(
          '$label: Sonstige Zeilen (Anpassungen, Einbehalte) '
          'nicht gebucht – bitte prüfen.',
        );
      }
      final formats = otherFormatMonths[key];
      if (file.platform == SalesPlatform.amazon &&
          formats != null &&
          formats.any((f) => f != file.format.name)) {
        warnings.add(
          '$label: Für diesen Monat wurde schon ein anderer '
          '${file.platform.label}-Bericht übernommen. Nur einen Berichtstyp '
          'verwenden, sonst zählen Umsätze doppelt.',
        );
      }
    }

    warnings.addAll(_ossWarnings(fresh, country));
    if (assumedStorage) {
      warnings.add(
        'Versand durch Amazon: Verkäufe auf dem Marktplatz eines Landes mit '
        'eigener Registrierung wurden diesem Steuerland zugeordnet (Lager '
        'dort angenommen). Bei Pan-EU-Versand mit dem USt-Transaktionsbericht '
        'prüfen.',
      );
    }
    if (distanceFromStorage) {
      warnings.add(
        'Verkäufe aus dem Lager im Ausland in ein drittes Land: Fernverkauf – '
        'Steuerland und OSS mit der Steuerberatung klären.',
      );
    }
    if (registrations.isEmpty && fresh.any((e) => e.fulfilledByPlatform)) {
      warnings.add(
        'Versand durch Amazon: Lagert Ware in anderen Ländern (z. B. Pan-EU, '
        'CEE), brauchst du dort meist eine Umsatzsteuer-Registrierung. Mit '
        'der Steuerberatung klären.',
      );
    }
    if (fresh.any((e) => e.marketplaceCollectedTax)) {
      warnings.add(
        'Ein Teil der Umsatzsteuer wurde vom Marktplatz einbehalten '
        '(Plattform als Steuerschuldner). Diese Verkäufe mit der '
        'Steuerberatung abstimmen.',
      );
    }
    if (file.skippedForeignCurrency > 0) {
      warnings.add(
        '${file.skippedForeignCurrency} Zeilen in anderer Währung als Euro '
        'nicht übernommen.',
      );
    }
    if (file.skippedUnreadable > 0) {
      warnings.add(
        '${file.skippedUnreadable} Zeilen ohne lesbares Datum oder Betrag '
        'nicht übernommen.',
      );
    }
    if (supplier.isReverseCharge &&
        drafts.any((d) => d.receipt.reverseCharge)) {
      warnings.add(
        isSmallBusiness
            ? 'Gebühren von ${supplier.name} (${supplier.countryCode}): '
                  'Reverse Charge. Auch als Kleinunternehmer schuldest du '
                  'die Umsatzsteuer darauf (ohne Vorsteuerabzug) und '
                  'brauchst eine ${profile.vatIdLabel}.'
            : 'Gebühren von ${supplier.name} (${supplier.countryCode}): '
                  'Reverse Charge, Steuer und Vorsteuer in der '
                  '${profile.vatReturnLabel}.',
      );
    }

    return PlatformImportPlan(
      file: file,
      months: [for (final k in byMonth.keys.toList()..sort()) byMonth[k]!],
      drafts: drafts,
      newEntries: fresh,
      duplicates: duplicates,
      warnings: warnings,
      feeSupplier: supplier,
    );
  }

  /// Steuer laut Bericht, sonst aus dem Normalsatz herausgerechnet
  /// (Annahme Inlandsumsatz zum Normalsatz – Prüfpunkt P-S51).
  static VatSplit _salesSplit(Money gross, Money tax, TaxProfile profile) {
    final permille = profile.standardVatPermille;
    if (!tax.isZero && tax.abs < gross.abs) {
      return VatSplit(
        net: gross - tax,
        vat: tax,
        gross: gross,
        permille: permille,
      );
    }
    return VatCalculator.fromGross(gross, permille);
  }

  static List<String> _ossWarnings(List<PlatformEntry> entries, Country home) {
    final byYear = <int, Money>{};
    for (final e in entries) {
      final dest = e.destinationCountry;
      if (dest == null || dest == home.code || !euCountries.contains(dest)) {
        continue;
      }
      if (e.kind != PlatformEntryKind.sale &&
          e.kind != PlatformEntryKind.refund) {
        continue;
      }
      byYear[e.date.year] =
          (byYear[e.date.year] ?? const Money.zero()) + e.amount;
    }
    return [
      for (final MapEntry(key: year, value: sum) in byYear.entries)
        if (sum > ossThreshold)
          'OSS: Verkäufe in andere EU-Länder $year über 10.000 € '
              '(Art 59c MwStSystRL). Ab Überschreiten gilt die Umsatzsteuer '
              'des Bestimmungslands – One-Stop-Shop mit der Steuerberatung '
              'klären.',
    ];
  }

  static String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  /// „März 2026“ bzw. in Österreich „Jänner 2026“.
  static String monthLabel(DateTime m, TaxProfile profile) =>
      '${profile.monthNames[m.month - 1]} ${m.year}';

  static String monthKey(DateTime d) => _monthKey(d);
}
