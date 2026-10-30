import 'dart:io';

import 'package:buchhaltung/domain/company_profile.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/deadline_rule.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/services/deadline_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regressionsnetz für AT/DE vor dem Umbau der Länderregeln (Umbauplan
/// AP3/AP4, `docs/maerkte/Umbauplan_Laender.md`): Was die App heute für
/// Österreich und Deutschland festlegt und berechnet, steht als Text in
/// `test/golden/laender_<land>.txt`. Ändert ein Umbau davon etwas, wird der
/// Test rot und zeigt die Abweichung.
///
/// Bewusste Änderung: `UPDATE_GOLDEN=1 flutter test test/laender_snapshot_test.dart`
/// und den Unterschied im Commit begründen.
void main() {
  final update = Platform.environment['UPDATE_GOLDEN'] == '1';

  String money(Money? m) => m == null ? '–' : '${m.cents}';
  String day(DateTime d) => d.toIso8601String().substring(0, 10);

  String profil(TaxProfile t) {
    final b = StringBuffer()
      ..writeln('# Profil ${t.country.code}')
      ..writeln('currency: ${t.currency.code}')
      ..writeln('rulesAsOf: ${day(t.rulesAsOf)} bis ${day(t.rulesValidUntil)}');
    for (final r in t.vatRates) {
      b.writeln(
        'vatRate: ${r.permille} ${r.label} default=${r.isDefault} '
        'ab=${r.validFrom == null ? '–' : day(r.validFrom!)}',
      );
    }
    final felder = <String, Object?>{
      'vatIdLabel': t.vatIdLabel,
      'vatIdExample': t.vatIdExample,
      'taxNumberLabel': t.taxNumberLabel,
      'smallBusinessLabel': t.smallBusinessLabel,
      'smallBusinessLegalRef': t.smallBusinessLegalRef,
      'smallBusinessInvoiceNote': t.smallBusinessInvoiceNote,
      'invoiceRequiresTaxId': t.invoiceRequiresTaxId,
      'largeInvoiceVatIdLimit': money(t.largeInvoiceVatIdLimit),
      'registerNumberLabel': t.registerNumberLabel,
      'registerCourtLabel': t.registerCourtLabel,
      'invoiceLegalRef': t.invoiceLegalRef,
      'invoiceSourceUrl': t.invoiceSourceUrl,
      'smallBusinessSourceUrl': t.smallBusinessSourceUrl,
      'fxRateLegalRef': t.fxRateLegalRef,
      'smallAmountInvoiceLimit': money(t.smallAmountInvoiceLimit),
      'currentYearTurnoverLimit': money(t.currentYearTurnoverLimit),
      'previousYearTurnoverLimit': money(t.previousYearTurnoverLimit),
      'toleranceLimit': money(t.toleranceLimit),
      'turnoverIncludesVat': t.turnoverIncludesVat,
      'foundingYearTurnoverLimit': money(t.foundingYearTurnoverLimit),
      'retentionYears': t.retentionYears,
      'foreignVatHint': t.foreignVatHint,
      'noVatShownHint': t.noVatShownHint,
      'monthNames': t.monthNames.join(','),
      'fiscalYearLegalRef': t.fiscalYearLegalRef,
      'holidayCalendar': t.holidayCalendar.runtimeType,
      'asksFederalState': t.asksFederalState,
      'deadlineShiftLegalRef': t.deadlineShiftLegalRef,
      'vatReturnLabel': t.vatReturnLabel,
      'monthlyVatReturnThreshold': money(t.monthlyVatReturnThreshold),
      'vatIntervalBasis': t.vatIntervalBasis,
      'vatIntervalLegalRef': t.vatIntervalLegalRef,
      'hasPermanentExtension': t.hasPermanentExtension,
      'asksSocialInsurance': t.asksSocialInsurance,
      'deadlineRules': t.deadlineRules.length,
      'registrationDeadlineRules': t.registrationDeadlineRules.length,
      'foreignTaxOffices': t.foreignTaxOffices.length,
      'vatReturnForm': t.vatReturnForm,
      'annualReturnForm': t.annualReturnForm,
    };
    felder.forEach((k, v) => b.writeln('$k: $v'));
    return b.toString();
  }

  String fristen(Country land) {
    final b = StringBuffer();
    for (final klein in [true, false]) {
      for (final intervall in [
        VatReturnInterval.monthly,
        VatReturnInterval.quarterly,
      ]) {
        for (final beraterin in [false, true]) {
          final profil = CompanyProfile(
            companyName: 'Muster',
            country: land,
            isSmallBusiness: klein,
            hasTaxAdvisor: beraterin,
            filesEcsl: !klein,
          );
          b.writeln(
            '# Fristen ${land.code} 2027 klein=$klein ${intervall.name} '
            'steuerberatung=$beraterin',
          );
          for (final d in DeadlineCalculator.forYear(
            profile: profil,
            year: 2027,
            interval: intervall,
          )) {
            b.writeln(
              '${day(d.date)}${d.approximate ? ' ca.' : ''} | ${d.label} | '
              '${d.legalRef}',
            );
          }
        }
      }
    }
    return b.toString();
  }

  for (final land in Country.values) {
    test('Länderregeln ${land.code} unverändert', () {
      final ist = '${profil(land.taxProfile)}\n${fristen(land)}';
      final datei = File('test/golden/laender_${land.code.toLowerCase()}.txt');
      if (update || !datei.existsSync()) {
        datei.writeAsStringSync(ist);
        return;
      }
      expect(ist, datei.readAsStringSync());
    });
  }
}
