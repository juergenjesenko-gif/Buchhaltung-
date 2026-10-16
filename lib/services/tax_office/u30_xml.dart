/// Datei für FinanzOnline: Umsatzsteuervoranmeldung U30 nach dem
/// BMF-Datenstrom „ERKLAERUNGS_UEBERMITTLUNG U30“ (XSD ab 07/2026, Stand
/// 24.04.2026; Spezifikation FA-14.4, Abschnitt 8.7). Nur Österreich – die
/// Datei gibt es nur, wenn das Länderprofil `VatReturnFile.u30Xml` meldet.
///
/// Schemaprüfung beim BMF und Testupload: Spezifikation 14, P-S57, P-D35.
library;

import '../../domain/money.dart';
import 'vat_return_figures.dart';

class U30Xml {
  U30Xml._();

  /// Stand des Datenstroms, dem die Datei folgt.
  static const schemaVersion = '07_2026';

  /// Finanzamts- und Steuernummer (FASTNR) aus der Steuernummer im Profil:
  /// zweistellige Finanzamtsnummer plus siebenstellige Steuernummer, also
  /// neun Ziffern, Bereich 010000010 bis 989999999 laut XSD. `null`, wenn die
  /// Eingabe nicht passt.
  static String? fastNr(String taxNumber) {
    final digits = taxNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 9) return null;
    final n = int.parse(digits);
    if (n < 10000010 || n > 989999999) return null;
    return digits;
  }

  /// Reihenfolge der Kennzahlen laut XSD, je Abschnitt.
  static const _steuerfrei = [
    '011', '012', '015', '017', '018', '019', '016', '020', //
  ];
  static const _versteuert = [
    '022', '124', '029', '006', '037', '052', '007', '056', '057', '048',
    '044', '032', //
  ];
  static const _vorsteuer = [
    '060', '061', '083', '065', '066', '082', '087', '089', '064', '062',
    '063', '067', '090', //
  ];

  /// Erzeugt die Datei. [fromMonth] und [toMonth] liegen im selben Jahr
  /// (Monat oder Quartal). Wirft [StateError], wenn keine Datei möglich ist.
  static String build({
    required VatReturnFigures figures,
    required String fastNr,
    required int year,
    required int fromMonth,
    required int toMonth,
    required DateTime createdAt,
  }) {
    if (!figures.fileAvailable) {
      throw StateError('Für diesen Zeitraum ist keine U30-Datei möglich.');
    }
    String two(int v) => v.toString().padLeft(2, '0');
    String amount(Money m) {
      final c = m.cents;
      return '${c ~/ 100}.${two(c % 100)}';
    }

    String section(String tag, List<String> order) {
      final b = StringBuffer();
      for (final kz in order) {
        final value = figures.amountOf(kz);
        // Typ „kz“ erlaubt nur Beträge ab 0,01: Nullen entfallen.
        if (value == null || value.cents <= 0) continue;
        b.write('<KZ$kz type="kz">${amount(value)}</KZ$kz>');
      }
      return b.isEmpty ? '' : '<$tag>$b</$tag>';
    }

    final total = figures.amountOf('000') ?? const Money.zero();
    // Paketnummer: Sekunden seit 2020 modulo 9 Stellen, nie 0.
    final paket =
        (createdAt.difference(DateTime(2020)).inSeconds % 999999999) + 1;
    final date =
        '${createdAt.year}-${two(createdAt.month)}-${two(createdAt.day)}';
    final time =
        '${two(createdAt.hour)}:${two(createdAt.minute)}:'
        '${two(createdAt.second)}';
    final vorsteuer = section('VORSTEUER', _vorsteuer);

    return '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<ERKLAERUNGS_UEBERMITTLUNG>'
        '<INFO_DATEN>'
        '<ART_IDENTIFIKATIONSBEGRIFF>FASTNR</ART_IDENTIFIKATIONSBEGRIFF>'
        '<IDENTIFIKATIONSBEGRIFF>$fastNr</IDENTIFIKATIONSBEGRIFF>'
        '<PAKET_NR>$paket</PAKET_NR>'
        '<DATUM_ERSTELLUNG type="datum">$date</DATUM_ERSTELLUNG>'
        '<UHRZEIT_ERSTELLUNG type="uhrzeit">$time</UHRZEIT_ERSTELLUNG>'
        '<ANZAHL_ERKLAERUNGEN>1</ANZAHL_ERKLAERUNGEN>'
        '</INFO_DATEN>'
        '<ERKLAERUNG art="U30">'
        '<SATZNR>1</SATZNR>'
        '<ALLGEMEINE_DATEN>'
        '<ANBRINGEN>U30</ANBRINGEN>'
        '<ZRVON type="jahrmonat">$year-${two(fromMonth)}</ZRVON>'
        '<ZRBIS type="jahrmonat">$year-${two(toMonth)}</ZRBIS>'
        '<FASTNR>$fastNr</FASTNR>'
        '</ALLGEMEINE_DATEN>'
        '<LIEFERUNGEN_LEISTUNGEN_EIGENVERBRAUCH>'
        '<KZ000 type="kz">${amount(total)}</KZ000>'
        '${section('STEUERFREI', _steuerfrei)}'
        '${section('VERSTEUERT', _versteuert)}'
        '</LIEFERUNGEN_LEISTUNGEN_EIGENVERBRAUCH>'
        '$vorsteuer'
        '</ERKLAERUNG>'
        '</ERKLAERUNGS_UEBERMITTLUNG>\n';
  }

  /// Dateiname, z. B. `U30_2026-07_2026-09.xml`.
  static String fileName(int year, int fromMonth, int toMonth) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'U30_$year-${two(fromMonth)}_$year-${two(toMonth)}.xml';
  }
}
