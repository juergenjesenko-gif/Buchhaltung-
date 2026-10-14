import '../../core/formatting.dart';
import '../../domain/country.dart';
import '../../domain/money.dart';
import '../../domain/receipt.dart';
import '../receipt_vat_split.dart';
import 'ocr_text.dart';
import 'receipt_classifier.dart';
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
    this.description,
    this.categoryName,
    this.vatParts = const [],
    this.note,
    this.codeSource,
    this.registerId,
  });

  factory ReceiptScanPrefill.from(
    ReceiptScanResult r, {
    required BookingDirection direction,
    required TaxProfile profile,
    ReceiptClassification? classification,
    DateTime? today,
  }) {
    bool ok(Detected<Object?>? d) =>
        d != null && d.confidence >= receiptScanMinConfidence;

    // Ausgangsseite bleibt in Euro; Fremdwährung nur bei Eingangsbelegen.
    final foreign =
        direction == BookingDirection.expense &&
        r.currency.value != 'EUR' &&
        r.currency.confidence >= 60;
    final hints = <String>[];

    // Mehrdeutige Währung („$“, „kr“): weder ins Euro-Feld noch als
    // Fremdwährung vorbelegen, die Nutzerin muss sie bestätigen.
    final unclearCurrency =
        r.currency.value != 'EUR' && r.currency.confidence < 60;
    if (unclearCurrency && ok(r.gross)) {
      hints.add(
        'Betrag ${Fmt.amount(r.gross!.value)} erkannt, Währung aber unklar '
        '(vermutlich ${r.currency.value}). Bitte Währung und Betrag eintragen.',
      );
    }

    // Ausländische Umsatzsteuer: Aussteller-UID aus einem anderen Staat,
    // oder ein Satz, den es nur in einem anderen Länderprofil gibt. Erkennen,
    // aber 0 % vorbelegen: im Inland nicht als Vorsteuer abziehbar (§ 12
    // Abs. 1 Z 1 UStG 1994 bzw. § 15 Abs. 1 Nr. 1 UStG). Hinweistext je Land
    // aus dem TaxProfile (Spezifikation 14, P-S27, P-S30).
    int? permille;
    final dominant = r.dominantPermille;
    final issuerCountry = ok(r.vatId) ? r.vatId!.value.substring(0, 2) : null;
    final ownPrefix = profile.country == Country.at ? 'AT' : 'DE';
    final foreignIssuer = issuerCountry != null && issuerCountry != ownPrefix;
    final ownRate = dominant == null ? null : profile.rateByPermille(dominant);
    final otherCountryRate =
        dominant != null &&
        ownRate == null &&
        (Country.values.any(
              (c) => c.taxProfile.rateByPermille(dominant) != null,
            ) ||
            // Satz eines anderen EU-Staats (z. B. SI 22 %), auch wenn die
            // Aussteller-UID nicht lesbar war.
            ReceiptTextParser.euRates.contains(dominant));
    final onDate = ok(r.date) ? r.date!.value : (today ?? DateTime.now());
    final expense = direction == BookingDirection.expense;
    if (dominant != null && (foreignIssuer || otherCountryRate)) {
      if (expense && profile.rateByPermille(0) != null) {
        permille = 0;
        hints.add(
          'Ausländische Umsatzsteuer ${Fmt.vatRate(dominant)} erkannt – '
          'nicht als Vorsteuer abziehbar, deshalb 0 % vorbelegt. '
          '${profile.foreignVatHint}',
        );
      } else {
        hints.add(
          'Steuersatz ${Fmt.vatRate(dominant)} erkannt – gibt es in '
          '${profile.country.label} nicht, bitte Satz wählen.',
        );
      }
    } else if (dominant != null && ownRate == null) {
      // Satz rechnerisch belegt, aber in der App nicht hinterlegt: nichts
      // Falsches vorbelegen.
      hints.add(
        'Steuersatz ${Fmt.vatRate(dominant)} erkannt, in der App noch nicht '
        'hinterlegt. Bitte Satz prüfen.',
      );
    } else if (ownRate != null && !ownRate.isValidOn(onDate)) {
      hints.add(
        'Steuersatz ${Fmt.vatRate(dominant!)} erkannt, gilt aber erst ab '
        '${_ddmmyyyy(ownRate.validFrom!)}. Bitte Satz und Datum prüfen.',
      );
    } else if (dominant != null) {
      permille = dominant;
    } else if (expense && ok(r.gross) && profile.rateByPermille(0) != null) {
      // Kein Steuersatz auf dem Beleg (z. B. nur Kartenbeleg): keinen Satz
      // erfinden; „ohne Vorsteuer“ (0 %) statt des Standardsatzes vorbelegen.
      permille = 0;
      hints.add(profile.noVatShownHint);
    }
    // Mehrere Sätze (L-2.27): als Aufteilung vorbelegen, je Zeile mit
    // denselben Regeln wie oben – ausländischer Satz bei Ausgaben 0 %, ein
    // unbekannter oder noch nicht gültiger Satz verhindert die Vorbelegung.
    var vatParts = const <VatPart>[];
    if (r.vatLines.length > 1) {
      final listed = [
        for (final l in r.vatLines)
          '${Fmt.vatRate(l.permille)} brutto ${Fmt.amount(l.gross)}',
      ].join(', ');
      final parts = <VatPart>[];
      var mappable = !foreign && !unclearCurrency;
      for (final line in r.vatLines) {
        final own = profile.rateByPermille(line.permille);
        final foreignRate = own == null || foreignIssuer;
        if (own != null && !foreignIssuer && own.isValidOn(onDate)) {
          parts.add((permille: line.permille, gross: line.gross));
        } else if (foreignRate &&
            expense &&
            profile.rateByPermille(0) != null &&
            (foreignIssuer ||
                Country.values.any(
                  (c) => c.taxProfile.rateByPermille(line.permille) != null,
                ) ||
                ReceiptTextParser.euRates.contains(line.permille))) {
          parts.add((permille: 0, gross: line.gross));
        } else {
          mappable = false;
        }
      }
      final normalized = ReceiptVatSplit.normalize(parts);
      if (mappable && normalized.length > 1) {
        vatParts = normalized;
        hints.add(
          'Mehrere Steuersätze erkannt ($listed) – als Aufteilung '
          'vorbelegt, bitte prüfen.',
        );
      } else {
        hints.add(
          'Mehrere Steuersätze erkannt: $listed. Bitte bei Bedarf '
          '„Weiteren Steuersatz hinzufügen“.',
        );
      }
    }
    if (foreign && ok(r.gross)) {
      hints.add(
        'Betrag in ${r.currency.value} erkannt: ${Fmt.amount(r.gross!.value)} '
        '${r.currency.value}. Bitte den Kurs abrufen oder eintragen.',
      );
    }

    return ReceiptScanPrefill(
      date: ok(r.date) ? r.date!.value : null,
      gross: !foreign && !unclearCurrency && ok(r.gross)
          ? r.gross!.value
          : null,
      vatPermille: permille,
      counterparty: ok(r.merchant) ? r.merchant!.value : null,
      documentNumber: ok(r.invoiceNumber) ? r.invoiceNumber!.value : null,
      issuerVatId: ok(r.vatId) ? r.vatId!.value : null,
      currency: foreign ? r.currency.value : 'EUR',
      originalGross: foreign && ok(r.gross) ? r.gross!.value : null,
      hints: hints,
      description: classification?.description,
      categoryName: classification?.categoryName,
      vatParts: vatParts,
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

  /// Beschreibungsvorschlag („SPAR – Lebensmittel (Baguette, Biomilch)“).
  final String? description;

  /// Name einer Startkategorie als Vorschlag; das Formular wählt sie nur,
  /// wenn es eine Kategorie dieses Namens gibt.
  final String? categoryName;

  /// Erkannte Aufteilung nach Steuersätzen (L-2.27), leer bei einem Satz.
  final List<VatPart> vatParts;

  /// Notizvorschlag (z. B. IBAN und Referenz aus einem Zahlungs-QR, L-27.3).
  final String? note;

  /// „Kassen-QR“ oder „Zahlungs-QR“, wenn Werte aus einem Code stammen
  /// (L-27.2); das Formular zeigt dann den dezenten Vermerk.
  final String? codeSource;

  /// Kassen-ID aus dem Kassen-QR für den Lernspeicher Kasse → Händler.
  final String? registerId;
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

String _ddmmyyyy(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
