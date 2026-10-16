/// Kennzahlen für die Meldungen ans Finanzamt (Spezifikation FA-14.1 bis
/// FA-14.8, Lastenheft L-6.1, L-6.3, L-6.5).
///
/// Reines Dart: aus [PeriodTotals] und dem [TaxProfile] werden die Zeilen
/// der Voranmeldung bzw. der Jahreserklärung. Die Zuordnung der Kennzahlen
/// steht ausschließlich im [TaxProfile] (GR-6).
library;

import '../../data/repositories.dart' show PeriodTotals;
import '../../domain/country.dart';
import '../../domain/money.dart';

/// Eine Zeile mit Kennzahl, Text und Betrag.
class KennzahlLine {
  const KennzahlLine({
    required this.kz,
    required this.label,
    required this.amount,
    this.wholeEuros = false,
  });

  /// Kennzahl laut Formular; `null` bei reinen Hilfszeilen.
  final String? kz;
  final String label;
  final Money amount;

  /// Betrag ist in vollen Euro einzutragen (Cent abgeschnitten).
  final bool wholeEuros;

  /// Text zum Einfügen ins Portal: ohne Tausenderpunkt, Komma als
  /// Dezimaltrennzeichen, bei vollen Euro ohne Nachkommastellen.
  String get copyText {
    final cents = amount.cents;
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    if (wholeEuros) return '$sign${abs ~/ 100}';
    return '$sign${abs ~/ 100},${(abs % 100).toString().padLeft(2, '0')}';
  }
}

/// Ergebnis für einen Voranmeldungszeitraum.
class VatReturnFigures {
  const VatReturnFigures({
    required this.form,
    required this.required,
    required this.lines,
    required this.payable,
    required this.fileBlockers,
  });

  final VatReturnForm form;

  /// Muss überhaupt gemeldet werden? Kleinunternehmer nur bei Steuerschuld
  /// aus Reverse Charge (AT § 21 Abs 6 iVm § 19 Abs 1 UStG 1994; DE § 18
  /// Abs 4a UStG). Real zu prüfen: P-S57.
  final bool required;
  final List<KennzahlLine> lines;

  /// Zahllast (positiv) oder Überschuss (negativ).
  final Money payable;

  /// Gründe, warum keine Datei erzeugt werden kann. Leer = Datei möglich.
  final List<String> fileBlockers;

  bool get fileAvailable =>
      required && form.file != VatReturnFile.none && fileBlockers.isEmpty;

  /// Betrag einer Kennzahl oder `null`.
  Money? amountOf(String kz) {
    for (final line in lines) {
      if (line.kz == kz) return line.amount;
    }
    return null;
  }
}

class VatReturnCalculator {
  VatReturnCalculator._();

  /// Bemessungsgrundlage in vollen Euro: Cent werden abgeschnitten
  /// (ELSTER-Eingabe „volle Euro“, zugunsten der Steuerpflichtigen).
  static Money wholeEuros(Money value) =>
      Money(value.cents ~/ 100 * 100); // ~/ schneidet Richtung 0 ab

  static VatReturnFigures build({
    required PeriodTotals totals,
    required TaxProfile tax,
    required bool smallBusiness,
  }) {
    final form = tax.vatReturnForm;
    final rc = tax.reverseCharge;
    final lines = <KennzahlLine>[];
    final blockers = <String>[];

    KennzahlLine base(String? kz, String label, Money amount) => KennzahlLine(
      kz: kz,
      label: label,
      amount: form.wholeEuroBases ? wholeEuros(amount) : amount,
      wholeEuros: form.wholeEuroBases,
    );

    if (form.totalKz != null) {
      lines.add(
        base(
          form.totalKz,
          'Gesamtbetrag der Bemessungsgrundlagen',
          totals.incomeNet,
        ),
      );
    }

    final rates = totals.incomeNetByRate.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    for (final permille in rates) {
      final net = totals.incomeNetByRate[permille]!;
      if (net.isZero) continue;
      if (net.isNegative) {
        blockers.add(
          'Umsätze zu ${_rate(permille)} sind negativ (Gutschriften). '
          'Bitte mit der Kanzlei klären.',
        );
      }
      if (smallBusiness && permille == 0) {
        final kz = form.smallBusinessExemptKz;
        if (kz != null) {
          lines.add(base(kz, 'Steuerfrei als Kleinunternehmer', net));
        }
        continue;
      }
      final kz = form.baseKzByPermille[permille];
      if (kz == null) {
        lines.add(base(null, 'Umsätze zu ${_rate(permille)}', net));
        blockers.add(
          'Für Umsätze zu ${_rate(permille)} gibt es keine eindeutige '
          'Kennzahl (z. B. steuerfrei, Ausfuhr, EU-Lieferung). Bitte mit der '
          'Kanzlei klären und selbst eintragen.',
        );
        continue;
      }
      lines.add(base(kz, 'Umsätze zu ${_rate(permille)}', net));
    }

    if (totals.hasReverseCharge) {
      if (rc.baseKz != null) {
        lines.add(
          base(
            rc.baseKz,
            'Reverse Charge: Bemessungsgrundlage',
            totals.reverseChargeBase,
          ),
        );
      }
      lines.add(
        KennzahlLine(
          kz: rc.taxKz,
          label: 'Reverse Charge: Steuer',
          amount: totals.reverseChargeVat,
        ),
      );
    }

    if (!totals.expenseVat.isZero) {
      if (totals.expenseVat.isNegative) {
        blockers.add(
          'Die Vorsteuer ist negativ. Bitte mit der Kanzlei klären.',
        );
      }
      lines.add(
        KennzahlLine(
          kz: form.inputVatKz,
          label: 'Vorsteuer',
          amount: totals.expenseVat,
        ),
      );
    }
    if (totals.hasReverseCharge && !totals.reverseChargeInputVat.isZero) {
      lines.add(
        KennzahlLine(
          kz: rc.inputVatKz,
          label: 'Vorsteuer aus Reverse Charge',
          amount: totals.reverseChargeInputVat,
        ),
      );
    }

    final payable = totals.vatPayable;
    lines.add(
      KennzahlLine(
        kz: form.payableKz,
        label: payable.isNegative ? 'Überschuss (Guthaben)' : 'Zahllast',
        amount: payable,
      ),
    );

    return VatReturnFigures(
      form: form,
      required: !smallBusiness || totals.hasReverseCharge,
      lines: lines,
      payable: payable,
      fileBlockers: blockers,
    );
  }

  /// Jahreszahlen für die Gewinnermittlung (E1a bzw. Anlage EÜR).
  static List<KennzahlLine> annual({
    required PeriodTotals totals,
    required TaxProfile tax,
    required bool smallBusiness,
  }) {
    final form = tax.annualReturnForm;
    return [
      KennzahlLine(
        kz: smallBusiness ? form.smallBusinessIncomeKz : form.incomeKz,
        label: 'Betriebseinnahmen (netto)',
        amount: totals.incomeNet,
      ),
      if (form.outputVatKz != null && !smallBusiness)
        KennzahlLine(
          kz: form.outputVatKz,
          label: 'Vereinnahmte Umsatzsteuer',
          amount: totals.incomeVat,
        ),
      if (form.inputVatKz != null && !smallBusiness)
        KennzahlLine(
          kz: form.inputVatKz,
          label: 'Gezahlte Vorsteuer',
          amount: totals.expenseVat,
        ),
      KennzahlLine(
        kz: null,
        label: smallBusiness
            ? 'Betriebsausgaben (brutto, nach Art aufteilen)'
            : 'Betriebsausgaben (netto, nach Art aufteilen)',
        amount: totals.expenseNet + totals.expenseFxDifference,
      ),
      KennzahlLine(
        kz: null,
        label: 'Ergebnis (Gewinn/Verlust)',
        amount: totals.profit,
      ),
    ];
  }

  static String _rate(int permille) => permille % 10 == 0
      ? '${permille ~/ 10} %'
      : '${permille ~/ 10},${permille % 10} %';
}
