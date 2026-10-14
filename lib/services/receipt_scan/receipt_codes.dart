/// Maschinenlesbare Codes auf Belegen (L-27.1 bis L-27.3, L-27.7): Kassen-QR
/// Österreich (RKSV), Kassen-QR Deutschland (TSE nach DSFinV-K), Zahlungs-QR
/// (EPC069-12, „GiroCode“) und Link-QR. Reines Dart, keine Plattformteile.
///
/// Die Codes liest dieselbe Erkennung auf demselben Foto aus wie den Text
/// (Android ML Kit Barcode Scanning, iOS Vision); hier wird nur der Inhalt
/// zerlegt. Ein Code, der nicht exakt dem Format entspricht, wird verworfen
/// statt erraten.
library;

import '../../domain/money.dart';

/// Ein erkannter Code mit seinem Rohinhalt.
sealed class ReceiptCode {
  const ReceiptCode(this.raw);
  final String raw;

  /// Zerlegt [raw]; `null`, wenn der Inhalt keinem bekannten Format folgt.
  static ReceiptCode? parse(String raw) {
    final text = raw.trim();
    return RksvCode.tryParse(text) ??
        TseCode.tryParse(text) ??
        EpcCode.tryParse(text) ??
        LinkCode.tryParse(text);
  }
}

/// Betrag je Steuersatz aus einem Kassen-QR.
typedef CodeVatAmount = ({int? permille, Money gross, String field});

/// Maschinenlesbarer Code nach RKSV (§ 10 RKSV, BGBl. II Nr. 410/2015;
/// Format nach „Festlegungen des BMF zu Detailfragen der RKSV“
/// (Detailspezifikation) Abschnitt 7 und A-SIT-Mustercode
/// github.com/BMF-RKSV-Technik/at-registrierkassen-mustercode,
/// `MachineCodeValue.java`, `ReceiptRepresentationForSignature.java`):
///
/// ```text
/// _R1-AT<n>_<Kassen-ID>_<Belegnr>_<yyyy-MM-ddTHH:mm:ss>_<Normal>_<Ermäßigt-1>_
/// <Ermäßigt-2>_<Null>_<Besonders>_<Umsatzzähler>_<Zertifikat>_<Sig-Vorbeleg>_
/// <Signatur>
/// ```
///
/// Beträge brutto, deutsches Zahlenformat mit zwei Nachkommastellen (der
/// Mustercode nutzt `NumberFormat.getNumberInstance(Locale.GERMAN)`, also mit
/// Tausenderpunkt „1.234,56“), negativ bei Storno.
///
/// Satzzuordnung: Normal 20 % (§ 10 Abs. 1 UStG 1994), Ermäßigt-1 10 %
/// (§ 10 Abs. 2), Ermäßigt-2 13 % (§ 10 Abs. 3), Null 0 %. „Besonders“ war
/// 19 % (Jungholz, Mittelberg, § 10 Abs. 4); seit 01.07.2026 erfasst die Kasse
/// dort laut BMF auch den neuen Satz 4,9 % (§ 10 Abs. 1a UStG 1994, BGBl. I
/// Nr. 37/2026; BMF-Hinweis im Mustercode-Repository vom 13.03.2026). Der
/// Satz ist damit aus dem Code allein NICHT bestimmbar: [CodeVatAmount.permille]
/// bleibt `null` und wird aus dem Belegtext übernommen (Spezifikation 14, P-S49).
class RksvCode extends ReceiptCode {
  const RksvCode._(
    super.raw, {
    required this.suite,
    required this.registerId,
    required this.receiptNumber,
    required this.dateTime,
    required this.amounts,
  });

  /// Algorithmuskennzeichen, z. B. `R1-AT1`.
  final String suite;

  /// Kassen-ID (eindeutig je Unternehmer, § 7 RKSV).
  final String registerId;
  final String receiptNumber;
  final DateTime dateTime;

  /// Ein Eintrag je Feld mit Betrag ≠ 0, in der Feldreihenfolge.
  final List<CodeVatAmount> amounts;

  Money get gross => amounts.fold(
    const Money(0),
    (sum, a) => Money(sum.cents + a.gross.cents),
  );

  static const _fields = <(String, int?)>[
    ('Normal', 200),
    ('Ermäßigt-1', 100),
    ('Ermäßigt-2', 130),
    ('Null', 0),
    ('Besonders', null),
  ];

  static RksvCode? tryParse(String text) {
    if (!text.startsWith('_R')) return null;
    final parts = text.substring(1).split('_');
    if (parts.length != 13) return null;
    if (!RegExp(r'^R\d+-AT\d+$').hasMatch(parts[0])) return null;
    final date = _isoDateTime(parts[3]);
    if (date == null || parts[1].isEmpty || parts[2].isEmpty) return null;
    final amounts = <CodeVatAmount>[];
    for (var i = 0; i < _fields.length; i++) {
      final cents = parseCents(parts[4 + i], decimal: ',', group: '.');
      if (cents == null) return null;
      if (cents != 0) {
        amounts.add((
          permille: _fields[i].$2,
          gross: Money(cents),
          field: _fields[i].$1,
        ));
      }
    }
    return RksvCode._(
      text,
      suite: parts[0],
      registerId: parts[1],
      receiptNumber: parts[2],
      dateTime: date,
      amounts: amounts,
    );
  }
}

/// QR-Code nach KassenSichV § 6 und DSFinV-K Anhang I „QR-Code“ (Version V0):
///
/// ```text
/// V0;<Kassen-Seriennr>;<processType>;<processData>;<Transaktionsnr>;
/// <Signaturzähler>;<Start>;<Ende>;<Sig-Algorithmus>;<Zeitformat>;<Signatur>;
/// <Public Key>
/// ```
///
/// Für `processType` `Kassenbeleg-V1` ist `processData`
/// `Belegtyp^B1_B2_B3_B4_B5^Zahlungen`, Bruttobeträge mit Punkt
/// in der Reihenfolge der DSFinV-K-Steuersatz-IDs 1 bis 5: allgemeiner Satz
/// 19 % (§ 12 Abs. 1 UStG), ermäßigt 7 % (§ 12 Abs. 2), Durchschnittsatz
/// 10,7 % (§ 24 Abs. 1 Nr. 3), Durchschnittsatz 5,5 % (§ 24 Abs. 1 Nr. 1),
/// 0 %. Die Reihenfolge ist gegen die aktuelle DSFinV-K zu bestätigen (P-S50).
class TseCode extends ReceiptCode {
  const TseCode._(
    super.raw, {
    required this.registerId,
    required this.transactionNumber,
    required this.dateTime,
    required this.amounts,
  });

  /// Seriennummer der Kasse (Client-ID).
  final String registerId;
  final String transactionNumber;

  /// Ende der Transaktion (Belegzeit), sonst Start.
  final DateTime dateTime;
  final List<CodeVatAmount> amounts;

  Money get gross => amounts.fold(
    const Money(0),
    (sum, a) => Money(sum.cents + a.gross.cents),
  );

  static const _fields = <(String, int)>[
    ('Satz 1', 190),
    ('Satz 2', 70),
    ('Satz 3', 107),
    ('Satz 4', 55),
    ('Satz 5', 0),
  ];

  static TseCode? tryParse(String text) {
    if (!text.startsWith('V0;')) return null;
    final parts = text.split(';');
    if (parts.length < 12) return null;
    if (parts[2] != 'Kassenbeleg-V1') return null;
    final data = parts[3].split('^');
    if (data.length < 2) return null;
    final sums = data[1].split('_');
    if (sums.length != _fields.length) return null;
    final amounts = <CodeVatAmount>[];
    for (var i = 0; i < sums.length; i++) {
      final cents = parseCents(sums[i], decimal: '.');
      if (cents == null) return null;
      if (cents != 0) {
        amounts.add((
          permille: _fields[i].$2,
          gross: Money(cents),
          field: _fields[i].$1,
        ));
      }
    }
    final date = _isoDateTime(parts[7]) ?? _isoDateTime(parts[6]);
    if (date == null || parts[1].isEmpty) return null;
    return TseCode._(
      text,
      registerId: parts[1],
      transactionNumber: parts[4],
      dateTime: date,
      amounts: amounts,
    );
  }
}

/// Überweisungs-QR nach EPC069-12 „Quick Response Code: Guidelines to Enable
/// Data Capture for the Initiation of a SEPA Credit Transfer“ (Version 3.0,
/// European Payments Council): Zeilen `BCD`, Version `001`/`002`, Zeichensatz
/// `1`–`8`, `SCT`, BIC (bei 002 optional), Name (≤ 70), IBAN, Betrag
/// `EUR<n.nn>` (optional, 0,01 bis 999.999.999,99), Zweck, strukturierte
/// Referenz (RF) ODER unstrukturierter Text, Hinweis. Höchstens 331 Byte.
class EpcCode extends ReceiptCode {
  const EpcCode._(
    super.raw, {
    required this.name,
    required this.iban,
    this.bic,
    this.amount,
    this.reference,
  });

  final String name;
  final String iban;
  final String? bic;
  final Money? amount;

  /// Strukturierte Referenz oder Verwendungszweck.
  final String? reference;

  static EpcCode? tryParse(String text) {
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    if (lines.length < 7 || lines[0].trim() != 'BCD') return null;
    final version = lines[1].trim();
    if (version != '001' && version != '002') return null;
    if (lines[3].trim() != 'SCT') return null;
    String at(int i) => i < lines.length ? lines[i].trim() : '';
    final bic = at(4);
    if (version == '001' && bic.isEmpty) return null;
    final name = at(5);
    final iban = at(6).replaceAll(' ', '').toUpperCase();
    if (name.isEmpty || name.length > 70 || !isValidIban(iban)) return null;
    Money? amount;
    final rawAmount = at(7);
    if (rawAmount.isNotEmpty) {
      if (!rawAmount.startsWith('EUR')) return null;
      final cents = parseCents(rawAmount.substring(3), decimal: '.');
      if (cents == null || cents <= 0 || cents > 99999999999) return null;
      amount = Money(cents);
    }
    final structured = at(9);
    final unstructured = at(10);
    final reference = structured.isNotEmpty
        ? structured
        : (unstructured.isNotEmpty ? unstructured : null);
    return EpcCode._(
      text,
      name: name,
      iban: iban,
      bic: bic.isEmpty ? null : bic,
      amount: amount,
      reference: reference,
    );
  }
}

/// QR mit einer Webadresse (z. B. „Rechnung online abrufen“). Nur `https`
/// wird als Link geführt (L-27.7); alles andere gilt als unbekannter Inhalt.
class LinkCode extends ReceiptCode {
  const LinkCode._(super.raw, this.uri);
  final Uri uri;

  String get domain => uri.host.toLowerCase();

  static LinkCode? tryParse(String text) {
    if (text.contains(RegExp(r'\s'))) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || uri.scheme.toLowerCase() != 'https') return null;
    if (uri.host.isEmpty || uri.userInfo.isNotEmpty) return null;
    return LinkCode._(text, uri);
  }
}

/// Betrag aus Text in Cent, ohne Gleitkomma (GR-1). Genau zwei oder keine
/// Nachkommastellen; `null` bei anderem Inhalt.
int? parseCents(String input, {required String decimal, String? group}) {
  var s = input.trim();
  if (s.isEmpty) return null;
  var negative = false;
  if (s.startsWith('-')) {
    negative = true;
    s = s.substring(1);
  }
  if (group != null) {
    // Tausenderpunkte nur in Dreiergruppen zulassen.
    final pattern = RegExp(
      '^\\d{1,3}(${RegExp.escape(group)}\\d{3})*'
      '(${RegExp.escape(decimal)}\\d{1,2})?\$',
    );
    if (pattern.hasMatch(s)) s = s.replaceAll(group, '');
  }
  final m = RegExp(
    '^(\\d+)(?:${RegExp.escape(decimal)}(\\d{1,2}))?\$',
  ).firstMatch(s);
  if (m == null) return null;
  final euros = int.parse(m.group(1)!);
  final fraction = (m.group(2) ?? '0').padRight(2, '0');
  final cents = euros * 100 + int.parse(fraction);
  return negative ? -cents : cents;
}

/// IBAN-Prüfung nach ISO 13616 (Prüfziffer Modulo 97).
bool isValidIban(String iban) {
  if (!RegExp(r'^[A-Z]{2}\d{2}[A-Z0-9]{11,30}$').hasMatch(iban)) return false;
  final rearranged = iban.substring(4) + iban.substring(0, 4);
  var rest = 0;
  for (final c in rearranged.codeUnits) {
    final value = c >= 65 ? c - 55 : c - 48;
    rest = (value >= 10 ? rest * 100 + value : rest * 10 + value) % 97;
  }
  return rest == 1;
}

DateTime? _isoDateTime(String s) {
  final m = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})',
  ).firstMatch(s);
  if (m == null) return null;
  final v = [for (var i = 1; i <= 6; i++) int.parse(m.group(i)!)];
  if (v[1] < 1 || v[1] > 12 || v[2] < 1 || v[2] > 31) return null;
  return DateTime(v[0], v[1], v[2], v[3], v[4], v[5]);
}
