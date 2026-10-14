import '../../core/formatting.dart';
import '../../domain/country.dart';
import '../../domain/money.dart';
import '../../domain/receipt.dart';
import '../receipt_vat_split.dart';
import 'receipt_codes.dart';
import 'receipt_scan_prefill.dart';
import 'receipt_text_parser.dart';

/// Führt Codes vom Foto mit der Texterkennung zusammen (L-27.2, L-27.3).
///
/// Kassen-QR hat Vorrang bei Betrag, Datum und Steuersätzen: die Werte sind
/// von der Kasse signiert und nicht durch Lesefehler verfälscht. Der Händler
/// kommt aus dem Lernspeicher (Kassen-ID → von der Nutzerin bestätigter Name)
/// oder aus dem Text, weil der Code keinen Namen enthält. Das Foto bleibt der
/// Beleg; der Code ist nur eine Lesehilfe.
class ReceiptCodePrefill {
  const ReceiptCodePrefill._();

  /// Ergebnis: [base] mit den Werten aus dem ersten verwertbaren Code.
  /// [knownMerchant] ist der gelernte Händler zur Kassen-ID, falls es einen
  /// gibt (Abfrage über [registerIdOf] vor dem Aufruf).
  static ReceiptScanPrefill merge(
    ReceiptScanPrefill base,
    List<ReceiptCode> codes, {
    required TaxProfile profile,
    required BookingDirection direction,
    ReceiptScanResult? ocr,
    String? knownMerchant,
  }) {
    for (final code in codes) {
      switch (code) {
        case RksvCode():
          return _register(
            base,
            registerId: 'AT:${code.registerId}',
            receiptNumber: code.receiptNumber,
            date: code.dateTime,
            amounts: code.amounts,
            ownCountry: profile.country == Country.at,
            profile: profile,
            direction: direction,
            ocr: ocr,
            knownMerchant: knownMerchant,
          );
        case TseCode():
          return _register(
            base,
            registerId: 'DE:${code.registerId}',
            receiptNumber: null,
            date: code.dateTime,
            amounts: code.amounts,
            ownCountry: profile.country == Country.de,
            profile: profile,
            direction: direction,
            ocr: ocr,
            knownMerchant: knownMerchant,
          );
        case EpcCode():
          return _payment(base, code);
        case LinkCode():
          continue;
      }
    }
    return base;
  }

  /// Kassen-ID des ersten Kassen-QR, für die Abfrage im Lernspeicher.
  static String? registerIdOf(List<ReceiptCode> codes) {
    for (final code in codes) {
      if (code is RksvCode) return 'AT:${code.registerId}';
      if (code is TseCode) return 'DE:${code.registerId}';
    }
    return null;
  }

  static ReceiptScanPrefill _register(
    ReceiptScanPrefill base, {
    required String registerId,
    required String? receiptNumber,
    required DateTime date,
    required List<CodeVatAmount> amounts,
    required bool ownCountry,
    required TaxProfile profile,
    required BookingDirection direction,
    required ReceiptScanResult? ocr,
    required String? knownMerchant,
  }) {
    final hints = [...base.hints];
    final total = amounts.fold(0, (sum, a) => sum + a.gross.cents);
    final day = DateTime(date.year, date.month, date.day);
    final key = registerId;
    // Storno oder leerer Beleg: nur Datum übernehmen, Beträge aus dem Text.
    if (total <= 0) {
      hints.add(
        'Kassen-QR erkannt, aber ohne positiven Betrag (Storno oder '
        'Nullbeleg). Bitte Betrag prüfen.',
      );
      return _copy(base, date: day, hints: hints, registerId: key);
    }
    // Sätze auflösen; „Besonders“ (RKSV) aus dem Belegtext (P-S49).
    final parts = <VatPart>[];
    var resolved = ownCountry;
    for (final a in amounts) {
      var permille = a.permille ?? _special(ocr, day);
      if (permille == null) {
        resolved = false;
        hints.add(
          'Kassen-QR: ${Fmt.amount(a.gross)} im Feld „Betrag-Satz-'
          '${a.field}“ – Steuersatz (4,9 % oder 19 %) bitte wählen.',
        );
        break;
      }
      if (profile.rateByPermille(permille)?.isValidOn(day) != true) {
        resolved = false;
      }
      parts.add((permille: permille, gross: a.gross));
    }
    final normalized = resolved
        ? ReceiptVatSplit.normalize(parts)
        : const <VatPart>[];
    final foreignExpense =
        !ownCountry &&
        direction == BookingDirection.expense &&
        profile.rateByPermille(0) != null;
    hints.add(
      'Betrag, Datum'
      '${normalized.isNotEmpty ? ' und Steuersätze' : ''} vom Kassen-QR.',
    );
    return ReceiptScanPrefill(
      date: day,
      gross: Money(total),
      vatPermille: normalized.length == 1
          ? normalized.first.permille
          : (normalized.length > 1
                ? normalized.first.permille
                : (foreignExpense ? 0 : base.vatPermille)),
      vatParts: normalized.length > 1 ? normalized : const [],
      counterparty: knownMerchant ?? base.counterparty,
      documentNumber:
          base.documentNumber ??
          (receiptNumber == null || receiptNumber.isEmpty
              ? null
              : receiptNumber),
      issuerVatId: base.issuerVatId,
      hints: hints,
      description: base.description,
      categoryName: base.categoryName,
      codeSource: 'Kassen-QR',
      registerId: key,
    );
  }

  /// Satz für „Betrag-Satz-Besonders“: steht genau einer der Sätze 4,9 % oder
  /// 19 % im Text, gilt er. Vor dem 01.07.2026 gab es dort nur 19 %
  /// (§ 10 Abs. 4 UStG 1994). Sonst `null` – nicht raten (P-S49).
  static int? _special(ReceiptScanResult? ocr, DateTime day) {
    final seen = {
      for (final l in ocr?.vatLines ?? const <DetectedVat>[])
        if (l.permille == 49 || l.permille == 190) l.permille,
    };
    if (seen.length == 1) return seen.first;
    if (day.isBefore(DateTime(2026, 7, 1))) return 190;
    return null;
  }

  static ReceiptScanPrefill _payment(ReceiptScanPrefill base, EpcCode code) {
    final note = [
      'IBAN ${code.iban}',
      if (code.bic != null) 'BIC ${code.bic}',
      if (code.reference != null) 'Referenz ${code.reference}',
    ].join(' · ');
    return ReceiptScanPrefill(
      date: base.date,
      gross: code.amount ?? base.gross,
      vatPermille: base.vatPermille,
      vatParts: base.vatParts,
      counterparty: code.name,
      documentNumber: base.documentNumber,
      issuerVatId: base.issuerVatId,
      currency: base.currency,
      originalGross: base.originalGross,
      hints: [
        ...base.hints,
        'Empfänger, IBAN${code.amount != null ? ', Betrag' : ''} und '
            'Referenz vom Zahlungs-QR.',
      ],
      description: base.description,
      categoryName: base.categoryName,
      note: note,
      codeSource: 'Zahlungs-QR',
    );
  }

  static ReceiptScanPrefill _copy(
    ReceiptScanPrefill b, {
    DateTime? date,
    required List<String> hints,
    String? registerId,
  }) => ReceiptScanPrefill(
    date: date ?? b.date,
    gross: b.gross,
    vatPermille: b.vatPermille,
    vatParts: b.vatParts,
    counterparty: b.counterparty,
    documentNumber: b.documentNumber,
    issuerVatId: b.issuerVatId,
    currency: b.currency,
    originalGross: b.originalGross,
    hints: hints,
    description: b.description,
    categoryName: b.categoryName,
    note: b.note,
    codeSource: b.codeSource,
    registerId: registerId ?? b.registerId,
  );
}
