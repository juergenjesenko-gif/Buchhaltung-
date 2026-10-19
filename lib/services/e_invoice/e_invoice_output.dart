import '../../domain/customer.dart';
import 'e_invoice_writer.dart';

/// XML-E-Rechnung, die „XML senden“ statt des PDF schickt (XRechnung,
/// ebInterface; FA-5.49).
class XmlAttachment {
  const XmlAttachment({required this.fileName, required this.content});

  final String fileName;
  final String content;
}

/// Was beim Ansehen einer Rechnung zur E-Rechnung gehört (FA-5.49):
/// eingebettete CII für die ZUGFeRD-PDF, bei Behörden zusätzlich die
/// XML-Datei zum Senden, und eine Hinweiszeile für den Betrachter.
class EInvoiceOutput {
  const EInvoiceOutput({this.facturX, this.xml, this.notice});

  /// CII (EN 16931) für die PDF/A-3; `null` = normales PDF.
  final String? facturX;

  /// XRechnung bzw. ebInterface; `null` = „Senden“ schickt das PDF.
  final XmlAttachment? xml;
  final String? notice;

  static const zugferdNotice =
      'Mit E-Rechnung (ZUGFeRD): Menschen lesen das PDF, Programme die Daten.';
  static const proNotice =
      'E-Rechnung (ZUGFeRD, XRechnung, ebInterface) gibt es mit Pro.';

  /// In der Demo und ohne Anspruch bleibt es beim normalen PDF. Fehlen
  /// Pflichtangaben, nennt der Hinweis sie – statt still eine ungültige
  /// E-Rechnung zu schreiben.
  static EInvoiceOutput prepare({
    required EInvoiceInput input,
    required EInvoiceFormat format,
    required bool allowed,
    required bool demo,
  }) {
    if (demo) return const EInvoiceOutput();
    if (!allowed) return const EInvoiceOutput(notice: proNotice);
    final missing = EInvoiceCheck.missing(format, input);
    if (missing.isNotEmpty) {
      return EInvoiceOutput(
        notice: 'Ohne ${format.label} – es fehlt: ${missing.join(', ')}.',
      );
    }
    final facturX = EInvoiceCheck.missing(EInvoiceFormat.zugferd, input).isEmpty
        ? EInvoiceWriter.cii(input)
        : null;
    final safe = input.invoice.number.replaceAll(
      RegExp(r'[^A-Za-z0-9\-_]'),
      '-',
    );
    return switch (format) {
      EInvoiceFormat.zugferd => EInvoiceOutput(
        facturX: facturX,
        notice: zugferdNotice,
      ),
      EInvoiceFormat.xrechnung => EInvoiceOutput(
        facturX: facturX,
        xml: XmlAttachment(
          fileName: 'XRechnung_$safe.xml',
          content: EInvoiceWriter.cii(input, xrechnung: true),
        ),
        notice:
            '„XML senden“ schickt die XRechnung fürs Rechnungsportal; '
            'Drucken druckt das PDF.',
      ),
      EInvoiceFormat.ebInterface => EInvoiceOutput(
        facturX: facturX,
        xml: XmlAttachment(
          fileName: 'ebInterface_$safe.xml',
          content: EInvoiceWriter.ebInterface(input),
        ),
        notice:
            '„XML senden“ schickt die ebInterface-Datei für '
            'e-Rechnung.gv.at; Drucken druckt das PDF.',
      ),
    };
  }
}
