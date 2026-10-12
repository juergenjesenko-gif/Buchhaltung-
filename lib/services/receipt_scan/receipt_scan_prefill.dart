import '../../core/formatting.dart';
import '../../domain/country.dart';
import '../../domain/money.dart';
import '../../domain/receipt.dart';
import 'ocr_text.dart';
import 'receipt_text_parser.dart';

/// Unter dieser Konfidenz wird ein Feld nicht vorbelegt.
const receiptScanMinConfidence = 40;

/// Übersetzt ein [ReceiptScanResult] in Vorschläge für das Belegformular
/// (L-2.20). Rechnet nichts um: ein Betrag in fremder Währung landet nicht
/// im Euro-Feld, sondern als Originalbetrag (L-2.21).
class ReceiptScanPrefill {
  const ReceiptScanPrefill({
    this.date,
    this.gross,
    this.vatPermille,
    this.counterparty,
    this.documentNumber,
    this.issuerVatId,
    this.currency = 'EUR',
    this.originalGross,
    this.hints = const [],
  });

  factory ReceiptScanPrefill.from(
    ReceiptScanResult r, {
    required BookingDirection direction,
    required TaxProfile profile,
  }) {
    bool ok(Detected<Object?>? d) =>
        d != null && d.confidence >= receiptScanMinConfidence;

    // Ausgangsseite bleibt in Euro; Fremdwährung nur bei Eingangsbelegen.
    final foreign =
        direction == BookingDirection.expense &&
        r.currency.value != 'EUR' &&
        r.currency.confidence >= 60;
    final hints = <String>[];

    int? permille;
    final dominant = r.dominantPermille;
    if (dominant != null && profile.rateByPermille(dominant) != null) {
      permille = dominant;
    } else if (dominant != null) {
      hints.add(
        'Steuersatz ${dominant ~/ 10} % erkannt – gibt es in '
        '${profile.country.label} nicht, bitte Satz wählen.',
      );
    }
    if (r.vatLines.length > 1) {
      hints.add(
        'Mehrere Steuersätze erkannt: ${[for (final l in r.vatLines) '${l.permille ~/ 10} % brutto ${Fmt.amount(l.gross)}'].join(', ')}. '
        'Das Formular bucht einen Satz – bei Bedarf Beleg aufteilen.',
      );
    }
    if (foreign && ok(r.gross)) {
      hints.add(
        'Betrag in ${r.currency.value} erkannt: ${Fmt.amount(r.gross!.value)} '
        '${r.currency.value}. Bitte den Kurs abrufen oder eintragen.',
      );
    }

    return ReceiptScanPrefill(
      date: ok(r.date) ? r.date!.value : null,
      gross: !foreign && ok(r.gross) ? r.gross!.value : null,
      vatPermille: permille,
      counterparty: ok(r.merchant) ? r.merchant!.value : null,
      documentNumber: ok(r.invoiceNumber) ? r.invoiceNumber!.value : null,
      issuerVatId: ok(r.vatId) ? r.vatId!.value : null,
      currency: foreign ? r.currency.value : 'EUR',
      originalGross: foreign && ok(r.gross) ? r.gross!.value : null,
      hints: hints,
    );
  }

  final DateTime? date;
  final Money? gross;
  final int? vatPermille;
  final String? counterparty;
  final String? documentNumber;
  final String? issuerVatId;
  final String currency;
  final Money? originalGross;
  final List<String> hints;
}

/// Protokolltext „erkannt gegenüber bestätigt“ für das audit_log (L-2.22,
/// GoBD-Nachvollziehbarkeit). Enthält keine Bilddaten, nur Werte, Engine und
/// Prüfsummen der Originalbilder.
class ReceiptScanAudit {
  const ReceiptScanAudit._();

  static String detail({
    required OcrDocument document,
    required ReceiptScanResult result,
    required Receipt confirmed,
    List<String> imageSha256 = const [],
  }) {
    String date(DateTime d) => d.toIso8601String().substring(0, 10);
    final fields = <(String, Detected<Object?>?, String)>[
      (
        'datum',
        result.date == null
            ? null
            : Detected(date(result.date!.value), result.date!.confidence),
        date(confirmed.date),
      ),
      (
        'brutto',
        result.gross == null
            ? null
            : Detected(result.gross!.value.cents, result.gross!.confidence),
        '${confirmed.originalGross?.cents ?? confirmed.gross.cents}',
      ),
      (
        'satz',
        result.dominantPermille == null
            ? null
            : Detected(
                result.dominantPermille,
                result.vatLines.first.confidence,
              ),
        '${confirmed.vatPermille}',
      ),
      ('lieferant', result.merchant, confirmed.counterparty),
      ('uid', result.vatId, confirmed.issuerVatId),
      ('rechnungsnr', result.invoiceNumber, confirmed.documentNumber),
      ('waehrung', result.currency, confirmed.currency),
    ];
    final parts = [
      'engine=${document.engine} ${document.engineVersion}'.trim(),
      for (final (name, detected, confirmedValue) in fields)
        '$name: erkannt=${detected == null ? '-' : '${detected.value}(${detected.confidence})'} '
            'bestätigt=${confirmedValue.isEmpty ? '-' : confirmedValue}'
            '${detected != null && '${detected.value}' != confirmedValue ? ' GEÄNDERT' : ''}',
      if (imageSha256.isNotEmpty) 'sha256=${imageSha256.join(',')}',
    ];
    return parts.join('; ');
  }
}
