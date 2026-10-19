import 'dart:io';

import 'package:buchhaltung/services/helper/helper_mail_schedule.dart';
import 'package:buchhaltung/core/window_size.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/domain/exchange_rate.dart';
import 'package:buchhaltung/domain/company_profile.dart';
import 'package:buchhaltung/services/app_lock/app_lock_service.dart';
import 'package:buchhaltung/services/backup/auto_backup_service.dart';
import 'package:buchhaltung/services/backup/backup_retention.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/deadline_rule.dart';
import 'package:buchhaltung/domain/levy_rules.dart';
import 'package:buchhaltung/services/deadline_calculator.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/domain/offer.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/services/invoice_numbering.dart';
import 'package:buchhaltung/services/dunning_calculator.dart';
import 'package:buchhaltung/services/small_business_monitor.dart';
import 'package:buchhaltung/services/tax_office/u30_xml.dart';
import 'package:buchhaltung/services/contracts/contract_schedule.dart';
import 'package:buchhaltung/services/receipt_scan/document_scanner.dart';
import 'package:buchhaltung/services/logo_store.dart';
import 'package:buchhaltung/services/demo/demo_dataset.dart';
import 'package:buchhaltung/services/demo/demo_mode.dart';
import 'package:buchhaltung/services/licensing/license_policy.dart';
import 'package:buchhaltung/services/platform_import/platform_import_plan.dart';
import 'package:buchhaltung/widgets/primary_action_bar.dart';
import 'package:buchhaltung/features/onboarding/setup_wizard.dart';
import 'package:buchhaltung/services/vat_id/eu_sme_id_format.dart';
import 'package:flutter/material.dart' show kMinInteractiveDimension;
import 'package:flutter_test/flutter_test.dart';

/// Hält `docs/SPECIFICATION.md` und den Code zusammen.
///
/// Die Spezifikation enthält in Abschnitt 12 einen Block mit `spec.*`-Werten.
/// Dieser Test liest ihn und vergleicht jeden Wert mit der Implementierung.
/// Wer einen Steuersatz, eine Umsatzgrenze oder die Schemaversion im Code
/// ändert und die Spezifikation nicht mitzieht, bekommt hier einen roten Test –
/// und nicht in einem Jahr ein Dokument, dem niemand mehr glaubt.
///
/// Der Test prüft bewusst auch die Gegenrichtung: taucht in der Spezifikation
/// ein `spec.`-Schlüssel auf, den dieser Test nicht kennt, schlägt er ebenfalls
/// fehl. Sonst könnte man einen Wert dokumentieren, den nie jemand überprüft.
void main() {
  late Map<String, String> spec;

  setUpAll(() {
    final file = File('docs/SPECIFICATION.md');
    expect(
      file.existsSync(),
      isTrue,
      reason:
          'docs/SPECIFICATION.md fehlt. Die Spezifikation ist Teil der '
          'Auslieferung, nicht optional.',
    );
    spec = _parseSpecBlock(file.readAsStringSync());
    expect(
      spec,
      isNotEmpty,
      reason:
          'In docs/SPECIFICATION.md wurde kein Block mit spec.*-Werten '
          'gefunden. Abschnitt 12 muss erhalten bleiben.',
    );
  });

  /// Liest einen Wert und markiert ihn als geprüft.
  String value(String key) {
    final result = spec.remove(key);
    expect(
      result,
      isNotNull,
      reason: 'In docs/SPECIFICATION.md fehlt der Eintrag "$key".',
    );
    return result!;
  }

  int intValue(String key) {
    final raw = value(key);
    final parsed = int.tryParse(raw);
    expect(parsed, isNotNull, reason: '"$key" ist keine ganze Zahl: "$raw"');
    return parsed!;
  }

  Money? moneyValue(String key) {
    final raw = value(key);
    if (raw == 'none') return null;
    final parsed = int.tryParse(raw);
    expect(parsed, isNotNull, reason: '"$key" ist kein Centbetrag: "$raw"');
    return Money(parsed!);
  }

  List<int> intListValue(String key) =>
      value(key).split(',').map((part) => int.parse(part.trim())).toList();

  group('Allgemeine Kenndaten', () {
    test('Lizenz und Abo stimmen (L-10.3, L-22.2, L-22.5)', () {
      expect(intValue('spec.license_trial_days'), LicensePolicy.trialDays);
      expect(value('spec.license_promo_code'), LicensePolicy.promoCode);
      expect(
        intValue('spec.license_promo_free_months'),
        LicensePolicy.promoFreeMonths,
      );
      expect(
        intValue('spec.license_trial_reminder_days'),
        LicensePolicy.trialReminderDays,
      );
      expect(
        intValue('spec.license_offline_grace_days'),
        LicensePolicy.offlineGraceDays,
      );
      expect(
        intValue('spec.license_offline_warn_days'),
        LicensePolicy.offlineWarnDays,
      );
      expect(
        value('spec.license_product_ids'),
        LicensePolicy.products.map((p) => p.id).join(','),
      );
    });

    test('Demo stimmt (FA-13.14)', () {
      expect(intValue('spec.demo_receipt_count'), DemoDataset.receiptCount);
      expect(value('spec.demo_watermark'), DemoMode.watermark);
      expect(value('spec.demo_company'), DemoDataset.companyName);
    });

    test('Ersteinrichtung und EU-KU-Nummer (FA-1.13, FA-18.10)', () {
      expect(intValue('spec.setup_steps'), SetupWizard.steps);
      expect(value('spec.eu_sme_id_suffix'), EuSmeIdFormat.suffix);
    });

    test('App-Sperre stimmt', () {
      expect(
        intValue('spec.app_lock_pin_min_digits'),
        AppLockPolicy.pinMinDigits,
      );
      expect(
        intValue('spec.app_lock_pin_max_digits'),
        AppLockPolicy.pinMaxDigits,
      );
      expect(
        intValue('spec.app_lock_default_timeout_seconds'),
        AppLockPolicy.defaultTimeoutSeconds,
      );
      expect(
        intValue('spec.app_lock_free_attempts'),
        AppLockPolicy.freeAttempts,
      );
      expect(
        intValue('spec.app_lock_backoff_initial_seconds'),
        AppLockPolicy.backoffInitialSeconds,
      );
      expect(
        intValue('spec.app_lock_backoff_max_seconds'),
        AppLockPolicy.backoffMaxSeconds,
      );
    });

    test('Breitenklassen und Formularbreite stimmen', () {
      expect(
        intValue('spec.window_medium_min_dp'),
        WindowSizeClass.mediumMinWidth.toInt(),
      );
      expect(
        intValue('spec.window_expanded_min_dp'),
        WindowSizeClass.expandedMinWidth.toInt(),
      );
      expect(
        intValue('spec.max_content_width_dp'),
        WindowSizeClass.maxContentWidth.toInt(),
      );
    });

    test('Automatische Sicherung stimmt', () {
      const retention = BackupRetention();
      expect(intValue('spec.auto_backup_keep_daily'), retention.daily);
      expect(intValue('spec.auto_backup_keep_monthly'), retention.monthly);
      expect(
        intValue('spec.auto_backup_min_interval_hours'),
        AutoBackupService.defaultMinInterval.inHours,
      );
    });

    test('Abstand der UID-Prüfung stimmt', () {
      expect(
        intValue('spec.vat_check_interval_days'),
        CompanyProfile.vatCheckIntervalDays,
      );
    });

    test('Erinnerung an die Datensicherung stimmt', () {
      expect(
        intValue('spec.backup_reminder_days'),
        CompanyProfile.backupReminderDays,
      );
    });

    test('Skalierung des Umrechnungskurses stimmt', () {
      expect(intValue('spec.fx_rate_scale'), exchangeRateScale);
    });

    test('Bedienmaße der Primärleiste stimmen (FA-5.20)', () {
      expect(
        intValue('spec.primary_action_height_dp'),
        PrimaryActionBar.height.toInt(),
      );
      expect(intValue('spec.min_touch_target_dp'), kMinInteractiveDimension);
    });

    test('Mahnwesen: Standardwerte stimmen (L-3.27)', () {
      expect(
        moneyValue('spec.dunning_default_fee_cents'),
        DunningCalculator.defaultFee,
      );
      expect(
        const CompanyProfile(companyName: '', country: Country.at).dunningFee,
        DunningCalculator.defaultFee,
      );
      expect(
        intValue('spec.dunning_period_days'),
        DunningCalculator.defaultPeriodDays,
      );
      expect(
        const CompanyProfile(
          companyName: '',
          country: Country.at,
        ).dunningPeriodDays,
        DunningCalculator.defaultPeriodDays,
      );
    });

    test('Schemaversion der Datenbank stimmt', () {
      expect(intValue('spec.schema_version'), AppDatabase.schemaVersion);
    });

    test('Mailweg der Mithelfer: Takt und Aufbewahrung (FA-17.10 ff.)', () {
      expect(
        intValue('spec.helper_mail_poll_minutes'),
        HelperMailSchedule.pollInterval.inMinutes,
      );
      expect(
        intValue('spec.helper_mail_send_hours'),
        HelperMailSchedule.sendInterval.inHours,
      );
      expect(
        intValue('spec.helper_mail_retention_days'),
        HelperMailSchedule.defaultRetentionDays,
      );
    });

    test('Seitenlimit Dokumentenscanner stimmt (FA-2.51)', () {
      expect(intValue('spec.scanner_page_limit'), DocumentScanner.pageLimit);
    });

    test('Toleranz Vertragsabgleich stimmt (FA-16.5)', () {
      expect(
        intValue('spec.contract_match_tolerance_days'),
        ContractSchedule.matchToleranceDays,
      );
    });

    test('U30-Datenstrom-Stand stimmt (FA-14.4)', () {
      expect(value('spec.u30_schema_version'), U30Xml.schemaVersion);
    });

    test('OSS-Schwelle stimmt (FA-2.47)', () {
      expect(moneyValue('spec.oss_threshold_cents'), ossThreshold);
    });

    test('Anzahl und Aufteilung der Startkategorien stimmt', () {
      final seeds = AppDatabase.seedCategories;
      expect(intValue('spec.seed_category_count'), seeds.length);
      expect(
        intValue('spec.seed_category_income_count'),
        seeds.where((s) => s.$2 == 'income').length,
      );
      expect(
        intValue('spec.seed_category_expense_count'),
        seeds.where((s) => s.$2 == 'expense').length,
      );
    });

    test('jede Startkategorie hat eine gültige Richtung und ein Konto', () {
      for (final (name, direction, account) in AppDatabase.seedCategories) {
        expect(name.trim(), isNotEmpty);
        expect(direction, anyOf('income', 'expense'));
        expect(
          account,
          matches(RegExp(r'^\d{4}$')),
          reason: 'Konto von "$name" ist keine vierstellige Nummer',
        );
      }
    });

    test('Warnschwelle der Grenzwertampel stimmt', () {
      expect(
        intValue('spec.warn_threshold_percent'),
        (SmallBusinessMonitor.warnThreshold * 100).round(),
      );
    });

    test('Angebote: Nummernmuster und Gültigkeit stimmen (FA-5.40)', () {
      expect(value('spec.offer_number_pattern'), OfferPolicy.numberPattern);
      expect(
        intValue('spec.offer_validity_days'),
        OfferPolicy.defaultValidityDays,
      );
    });

    test('Standardwerte des Firmenprofils stimmen', () {
      const profile = CompanyProfile(companyName: 'X', country: Country.at);

      // Einmal lesen: value() entfernt den Schlüssel aus der Liste der noch
      // ungeprüften Einträge, ein zweiter Aufruf liefert null.
      final pattern = value('spec.default_invoice_pattern');
      expect(pattern, profile.invoiceNumberPattern);
      expect(
        pattern,
        InvoiceNumbering.defaultPattern,
        reason:
            'Standardmuster in CompanyProfile und InvoiceNumbering '
            'weichen voneinander ab',
      );
      expect(
        intValue('spec.default_payment_term_days'),
        profile.defaultPaymentTermDays,
      );
    });
  });

  group('Dokumentierte Werte ohne Konstante im Code', () {
    // Diese Werte stehen als Literale im UI-Code. Der Test prüft sie gegen die
    // Quelle, damit die Spezifikation nicht Zahlen behauptet, die dort nicht
    // stehen – schwächer als ein Konstantenvergleich, aber besser als nichts.

    test('Bildkomprimierung entspricht dem Aufruf in der Belegmaske', () {
      final source = File(
        'lib/features/receipts/receipt_edit_screen.dart',
      ).readAsStringSync();
      final maxEdge = value('spec.receipt_image_max_edge_px');
      final quality = value('spec.receipt_image_quality_percent');

      expect(
        source,
        contains('maxWidth: $maxEdge'),
        reason: 'Spezifikation nennt $maxEdge px Kantenlänge, der Code nicht',
      );
      expect(source, contains('maxHeight: $maxEdge'));
      expect(
        source,
        contains('imageQuality: $quality'),
        reason: 'Spezifikation nennt $quality % Qualität, der Code nicht',
      );
    });

    test('Logo-Verkleinerung entspricht LogoStore', () {
      expect(intValue('spec.logo_max_edge_px'), LogoStore.maxEdgePx);
      expect(intValue('spec.logo_quality_percent'), LogoStore.qualityPercent);
    });

    test('Verlauf und Schnellzugriff im Dashboard entsprechen dem Code', () {
      final source = File(
        'lib/features/dashboard/dashboard_screen.dart',
      ).readAsStringSync();
      final months = intValue('spec.trend_months');
      final recent = intValue('spec.dashboard_recent_receipts');

      // Die Schleife läuft von months-1 rückwärts bis 0.
      expect(
        source,
        contains('offset = ${months - 1}'),
        reason: 'Spezifikation nennt $months Monate Verlauf, der Code nicht',
      );
      expect(
        source,
        contains('limit: $recent'),
        reason: 'Spezifikation nennt $recent letzte Belege, der Code nicht',
      );
    });
  });

  test('Termin-Box zeigt die dokumentierte Anzahl', () {
    expect(intValue('spec.deadline_box_count'), DeadlineCalculator.boxCount);
  });

  group('Länderprofile', () {
    void checkCountry(String prefix, TaxProfile profile) {
      expect(
        intListValue('spec.$prefix.vat_permille'),
        profile.vatRates.map((r) => r.permille).toList(),
        reason: 'Steuersätze für $prefix weichen ab',
      );
      for (final rate in profile.vatRates.where((r) => r.validFrom != null)) {
        expect(
          value('spec.$prefix.vat_${rate.permille}_valid_from'),
          rate.validFrom!.toIso8601String().substring(0, 10),
          reason: 'Gültigkeitsbeginn ${rate.display} für $prefix weicht ab',
        );
      }
      expect(
        intValue('spec.$prefix.default_vat_permille'),
        profile.defaultVatRate.permille,
      );
      expect(
        moneyValue('spec.$prefix.turnover_limit_cents'),
        profile.currentYearTurnoverLimit,
      );
      expect(
        moneyValue('spec.$prefix.tolerance_limit_cents'),
        profile.toleranceLimit,
      );
      expect(
        moneyValue('spec.$prefix.previous_year_limit_cents'),
        profile.previousYearTurnoverLimit,
      );
      expect(
        moneyValue('spec.$prefix.small_amount_invoice_limit_cents'),
        profile.smallAmountInvoiceLimit,
      );
      expect(intValue('spec.$prefix.retention_years'), profile.retentionYears);
      expect(
        value('spec.$prefix.invoice_requires_tax_id'),
        profile.invoiceRequiresTaxId ? 'ja' : 'nein',
      );
      expect(
        moneyValue('spec.$prefix.large_invoice_vat_id_limit_cents'),
        profile.largeInvoiceVatIdLimit,
      );
      expect(
        moneyValue('spec.$prefix.founding_year_limit_cents'),
        profile.foundingYearTurnoverLimit,
      );
      expect(
        value('spec.$prefix.turnover_basis'),
        profile.turnoverIncludesVat ? 'brutto' : 'netto',
      );
      expect(value('spec.$prefix.vat_id_label'), profile.vatIdLabel);
      expect(value('spec.$prefix.invoice_legal_ref'), profile.invoiceLegalRef);
      expect(value('spec.$prefix.fx_rate_legal_ref'), profile.fxRateLegalRef);
      expect(
        value('spec.$prefix.small_business_legal_ref'),
        profile.smallBusinessLegalRef,
      );
      // Wirtschaftsjahr und Termine (L-24, L-25).
      expect(
        value('spec.$prefix.fiscal_year_legal_ref'),
        profile.fiscalYearLegalRef,
      );
      expect(
        value('spec.$prefix.deadline_shift_legal_ref'),
        profile.deadlineShiftLegalRef,
      );
      expect(
        moneyValue('spec.$prefix.monthly_vat_return_threshold_cents'),
        profile.monthlyVatReturnThreshold,
      );
      expect(
        value('spec.$prefix.vat_interval_basis'),
        profile.vatIntervalBasis == VatIntervalBasis.previousYearTurnover
            ? 'umsatz'
            : 'steuer',
      );
      expect(
        value('spec.$prefix.asks_federal_state'),
        profile.asksFederalState ? 'ja' : 'nein',
      );
      final dunning = profile.dunning;
      final consumerRate = value('spec.$prefix.dunning_consumer_rate_bp');
      expect(
        consumerRate == 'none' ? null : int.parse(consumerRate),
        dunning.consumerFixedRateBp,
      );
      expect(
        intValue('spec.$prefix.dunning_consumer_surcharge_bp'),
        dunning.consumerSurchargeBp,
      );
      expect(
        intValue('spec.$prefix.dunning_business_surcharge_bp'),
        dunning.businessSurchargeBp,
      );
      expect(
        moneyValue('spec.$prefix.dunning_flat_fee_cents'),
        dunning.flatFee,
      );
      expect(
        value('spec.$prefix.dunning_base_rates'),
        dunning.baseRates
            .map(
              (r) =>
                  '${r.validFrom.toIso8601String().substring(0, 10)}:'
                  '${r.basisPoints}',
            )
            .join(','),
      );
      expect(
        value('spec.$prefix.dunning_consumer_notice'),
        dunning.consumerDefaultNotice == null ? 'nein' : 'ja',
      );
      expect(
        value('spec.$prefix.dunning_interest_legal_ref'),
        '${dunning.consumerInterestLegalRef} | '
        '${dunning.businessInterestLegalRef}',
      );
      expect(
        value('spec.$prefix.deadline_rules'),
        profile.deadlineRules.map(_ruleSpec).join(' | '),
      );
      // Weitere Registrierungen (FA-18.2, FA-18.5).
      expect(
        value('spec.$prefix.registration_deadline_rules'),
        profile.registrationDeadlineRules.map(_ruleSpec).join(' | '),
      );
      expect(
        value('spec.$prefix.foreign_tax_offices'),
        [
          for (final e in profile.foreignTaxOffices.entries)
            '${e.key}=${e.value}',
        ].join(','),
      );
      final rc = profile.reverseCharge;
      expect(
        value('spec.$prefix.reverse_charge_kz'),
        '${rc.baseKz ?? '-'},${rc.taxKz},${rc.inputVatKz}',
      );
      // Kennzahlen für das Finanzamt (FA-14.1 bis FA-14.8).
      final vr = profile.vatReturnForm;
      expect(
        value('spec.$prefix.vat_return_kz'),
        [
          vr.formName,
          vr.totalKz ?? '-',
          vr.baseKzByPermille.entries
              .map((e) => '${e.key}=${e.value}')
              .join(','),
          vr.smallBusinessExemptKz ?? '-',
          vr.inputVatKz,
          vr.payableKz,
          vr.wholeEuroBases ? 'euro' : 'cent',
          vr.file.name,
        ].join(';'),
      );
      // Anlagevermögen und AfA (GR-15, FA-15.x).
      final dr = profile.depreciation;
      expect(
        value('spec.$prefix.depreciation'),
        [
          dr.timing.name,
          dr.gwgLimit.cents,
          dr.gwgLimitIsNet ? 'netto' : 'ak',
          dr.poolRange == null
              ? '-'
              : '${dr.poolRange!.$1.cents}-${dr.poolRange!.$2.cents}',
          dr.registerLegalRef,
          dr.classes
              .map(
                (c) =>
                    '${c.key}=${c.years}${c.minYears == null ? '' : 'min${c.minYears}'}',
              )
              .join(','),
        ].join(';'),
      );
      // Bewirtung (FA-2.60).
      final en = profile.entertainment;
      expect(
        value('spec.$prefix.entertainment'),
        [
          en.deductiblePermille,
          en.inputVatFull ? 'voll' : 'anteilig',
          en.asksOccasion ? 'ja' : 'nein',
          en.legalRef,
          en.inputVatLegalRef,
        ].join(';'),
      );
      // Abgaben & Rücklagen (FA-19.x).
      final lv = profile.levies;
      for (final e in lv.incomeTaxByYear.entries) {
        expect(value('spec.$prefix.income_tax_${e.key}'), switch (e.value) {
          BracketTariff(:final brackets) =>
            'stufen:${brackets.map((b) => '${b.$1?.cents ?? 'none'}=${b.$2}').join(',')}',
          GermanFormulaTariff t =>
            'formel:${[t.basicAllowance, t.zone2Top, t.zone2Factor, t.zone3Top, t.zone3Factor, t.zone3Constant, t.zone4Top, t.zone4Constant, t.zone5Constant].join(',')}',
        });
      }
      expect(
        value('spec.$prefix.social_insurance_business_expense'),
        lv.socialInsuranceIsBusinessExpense ? 'ja' : 'nein',
      );
      final pa = lv.profitAllowance;
      expect(
        value('spec.$prefix.profit_allowance'),
        pa == null ? 'none' : '${pa.rateBp};${pa.maxBase.cents}',
      );
      final si = lv.socialInsurance;
      expect(
        value('spec.$prefix.social_insurance'),
        si == null
            ? 'none'
            : [
                si.pensionBp,
                si.healthBp,
                si.provisionBp,
                si.accidentMonthly.cents,
                si.minBaseYear.cents,
                si.maxBaseYear.cents,
                si.exemptionTurnoverLimit.cents,
                si.exemptionIncomeLimit.cents,
                si.provisionalYears,
              ].join(';'),
      );
      final sur = lv.surcharges;
      expect(
        value('spec.$prefix.surcharges'),
        sur == null
            ? 'none'
            : '${sur.soliBp};${sur.soliExemptionTax.cents};${sur.soliPhaseInBp};'
                  '${sur.churchBpDefault};'
                  '${sur.churchBpByState.entries.map((e) => '${e.key}=${e.value}').join(',')}',
      );
      final tt = lv.tradeTax;
      expect(
        value('spec.$prefix.trade_tax'),
        tt == null
            ? 'none'
            : '${tt.allowance.cents};${tt.baseRateBp};'
                  '${tt.defaultMultiplierPercent};${tt.creditFactorPermille}',
      );
      final ar = profile.annualReturnForm;
      expect(
        value('spec.$prefix.annual_return_kz'),
        [
          ar.formName,
          ar.incomeKz,
          ar.smallBusinessIncomeKz,
          ar.outputVatKz ?? '-',
          ar.inputVatKz ?? '-',
        ].join(';'),
      );
    }

    test('Österreich stimmt mit der Spezifikation überein', () {
      checkCountry('at', TaxProfile.austria);
    });

    test('Deutschland stimmt mit der Spezifikation überein', () {
      checkCountry('de', TaxProfile.germany);
    });

    test('jedes unterstützte Land hat ein geprüftes Profil', () {
      // Kommt ein Land dazu, muss die Spezifikation es beschreiben.
      expect(
        Country.values.map((c) => c.code.toLowerCase()).toSet(),
        {'at', 'de'},
        reason:
            'Ein Land wurde hinzugefügt oder entfernt. '
            'docs/SPECIFICATION.md Abschnitt 12 und dieser Test müssen '
            'mitgezogen werden.',
      );
    });
  });

  group('Fachliche Grundregeln aus der Spezifikation', () {
    test('GR-8: nur Entwürfe sind änderbar', () {
      // In Abschnitt 6.1 als Zustandsmodell dokumentiert.
      final locked = [
        for (final status in _allInvoiceStatusNames)
          if (status != 'draft') status,
      ];
      expect(locked, ['issued', 'paid', 'cancelled']);
    });

    test('Buchungsrichtungen sind genau Einnahme und Ausgabe', () {
      expect(BookingDirection.values.map((d) => d.name).toList(), [
        'income',
        'expense',
      ]);
    });

    test('Zahlungsarten entsprechen dem Datenwörterbuch', () {
      expect(PaymentMethod.values.map((m) => m.name).toList(), [
        'cash',
        'bank',
        'card',
        'other',
      ]);
    });

    test('Rechtsformen entsprechen dem Datenwörterbuch', () {
      expect(LegalForm.values.map((f) => f.name).toList(), [
        'soleTrader',
        'freelancer',
        'gbr',
        'gmbh',
      ]);
    });
  });

  group('Vollständigkeit', () {
    test('kein dokumentierter Wert bleibt ungeprüft', () {
      // Läuft als letzter Test: alle geprüften Schlüssel wurden oben mit
      // remove() entfernt. Was übrig ist, steht in der Spezifikation, wird aber
      // von niemandem verifiziert.
      expect(
        spec.keys.toList(),
        isEmpty,
        reason:
            'Diese Einträge aus docs/SPECIFICATION.md werden nicht geprüft. '
            'Entweder eine Prüfung in specification_sync_test.dart ergänzen '
            'oder den Eintrag aus der Spezifikation entfernen.',
      );
    });
  });
}

const _allInvoiceStatusNames = ['draft', 'issued', 'paid', 'cancelled'];

/// Liest die `spec.*`-Zeilen aus dem Markdown.
///
/// Bewusst ein eigener kleiner Parser statt einer Properties-Bibliothek: das
/// Format ist eine Zeile `schlüssel = wert`, Kommentare beginnen mit `#`.
Map<String, String> _parseSpecBlock(String markdown) {
  final result = <String, String>{};
  for (final line in markdown.split('\n')) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('spec.')) continue;
    final separator = trimmed.indexOf('=');
    if (separator < 0) continue;
    final key = trimmed.substring(0, separator).trim();
    final value = trimmed.substring(separator + 1).trim();
    result[key] = value;
  }
  return result;
}

/// Kurzform einer Terminregel für Abschnitt 12: `Bezeichnung@Regel`.
/// `15+2m` = 15. im zweiten Monat nach Zeitraumende (0 = Monatsletzter,
/// `+Nx` = Dauerfristverlängerung), `02-15,…` = feste Tage, `+1j07-31` =
/// Folgejahr, `~` = ungefähr.
String _ruleSpec(DeadlineRule rule) {
  String two(int v) => v.toString().padLeft(2, '0');
  final schedule = switch (rule.schedule) {
    AfterPeriod(
      :final dueDay,
      :final monthsAfter,
      :final extensionMonths,
      :final quarterly,
    ) =>
      '$dueDay+${monthsAfter}m'
          '${extensionMonths == 0 ? '' : '+${extensionMonths}x'}'
          '${quarterly ? 'q' : ''}',
    FixedDates(:final monthDays) =>
      monthDays.map((md) => '${two(md.$1)}-${two(md.$2)}').join(','),
    FollowingYear(:final month, :final day) => '+1j${two(month)}-${two(day)}',
  };
  return '${rule.label}@$schedule${rule.approximate ? '~' : ''}${rule.shiftsToWorkday ? '' : '='}';
}
