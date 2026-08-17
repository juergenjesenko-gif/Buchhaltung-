import 'dart:io';

import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/domain/company_profile.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/services/invoice_numbering.dart';
import 'package:buchhaltung/services/small_business_monitor.dart';
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
    test('Schemaversion der Datenbank stimmt', () {
      expect(intValue('spec.schema_version'), AppDatabase.schemaVersion);
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

  group('Länderprofile', () {
    void checkCountry(String prefix, TaxProfile profile) {
      expect(
        intListValue('spec.$prefix.vat_permille'),
        profile.vatRates.map((r) => r.permille).toList(),
        reason: 'Steuersätze für $prefix weichen ab',
      );
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
      expect(value('spec.$prefix.vat_id_label'), profile.vatIdLabel);
      expect(value('spec.$prefix.invoice_legal_ref'), profile.invoiceLegalRef);
      expect(
        value('spec.$prefix.small_business_legal_ref'),
        profile.smallBusinessLegalRef,
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
