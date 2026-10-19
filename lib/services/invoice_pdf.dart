import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

import 'e_invoice/e_invoice_writer.dart';

import 'pdf_fonts.dart';
import 'pdf_watermark.dart';

import '../core/formatting.dart';
import '../domain/company_profile.dart';
import '../domain/customer.dart';
import '../domain/invoice.dart';
import '../domain/money.dart';
import '../domain/offer.dart';
import 'invoice_texts.dart';

/// Erzeugt das Rechnungs-PDF.
///
/// Das Layout deckt die Pflichtangaben nach § 11 UStG (AT) bzw. § 14 UStG (DE)
/// ab: Name und Anschrift beider Parteien, Steuernummer bzw. UID des
/// Ausstellers, Ausstellungsdatum, fortlaufende Rechnungsnummer, Menge und
/// Bezeichnung der Leistung, Liefer-/Leistungsdatum, Entgelt je Steuersatz,
/// Steuerbetrag – und bei Kleinunternehmern statt des Steuerbetrags den
/// gesetzlich vorgeschriebenen Hinweis.
class InvoicePdf {
  const InvoicePdf({
    required this.invoice,
    required this.customer,
    required this.profile,
    this.logo,
    this.offerValidUntil,
    this.facturX,
  });

  /// CII-XML der E-Rechnung (FA-5.49). Gesetzt → das PDF wird eine
  /// PDF/A-3b mit eingebetteter `factur-x.xml` (ZUGFeRD 2.x / Factur-X,
  /// Profil EN 16931), Beziehung `Alternative`, XMP-Metadaten und
  /// sRGB-Ausgabeabsicht.
  final String? facturX;

  /// Farbprofil der PDF/A-Ausgabeabsicht.
  static const iccAsset = 'assets/icc/sRGB2014.icc';

  /// Producer im Info-Wörterbuch des pdf-Pakets; XMP muss gleich lauten.
  static const _pdfProducer = 'https://github.com/DavBfr/dart_pdf';

  /// PDF eines Angebots (L-3.17): trägt sichtbar „Angebot“, nie „Rechnung“,
  /// und statt Zahlungsangaben die Gültigkeit. Texte in Sie-Form (L-3.31).
  factory InvoicePdf.offer({
    required Offer offer,
    required Customer customer,
    required CompanyProfile profile,
    Uint8List? logo,
  }) => InvoicePdf(
    invoice: offer.asInvoice,
    customer: customer,
    profile: profile,
    logo: logo,
    offerValidUntil: offer.validUntil,
  );

  /// Gesetzt bei einem Angebot: letzter Tag der Gültigkeit.
  final DateTime? offerValidUntil;

  bool get isOffer => offerValidUntil != null;

  final Invoice invoice;
  final Customer customer;
  final CompanyProfile profile;

  /// Bilddaten des Firmenlogos (PNG oder JPEG), `null` = ohne Logo. Welches
  /// Logo gilt, bestimmt `InvoiceLogo.pathFor` (L-1.7). Das Logo steht
  /// zusätzlich zu Name und Anschrift, nie an ihrer Stelle (§ 11 UStG AT,
  /// § 14 UStG DE).
  final Uint8List? logo;

  /// Höchstmaße des Logos im PDF in Punkt (1 pt = 1/72 Zoll).
  static const logoMaxWidth = 140.0;
  static const logoMaxHeight = 60.0;

  static const _accent = PdfColor.fromInt(0xFF1B4965);
  static const _muted = PdfColor.fromInt(0xFF5A6B78);
  static const _hairline = PdfColor.fromInt(0xFFD6DEE4);

  Future<Uint8List> build() async {
    final xml = facturX;
    final title = PdfWatermark.title(_title);
    final keywords = PdfWatermark.keywords();
    final doc = xml == null
        ? pw.Document(
            title: title,
            author: profile.companyName,
            keywords: keywords,
          )
        : pw.Document(
            title: title,
            author: profile.companyName,
            creator: 'JeNi bucht',
            subject: _title,
            keywords: keywords ?? 'Rechnung, E-Rechnung, ZUGFeRD',
            // Factur-X 1.0 / ZUGFeRD 2.x: XMP-Erweiterung `fx`.
            metadata: PdfaRdf(
              title: title,
              author: profile.companyName,
              creator: 'JeNi bucht',
              subject: _title,
              keywords: keywords ?? 'Rechnung, E-Rechnung, ZUGFeRD',
              producer: _pdfProducer,
              invoiceRdf: PdfaFacturxRdf().create(
                filename: EInvoiceWriter.zugferdFileName,
                namespace:
                    'urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#',
                conformanceLevel: 'EN 16931',
                version: '1.0',
              ),
            ).create(),
          );
    if (xml != null) {
      final icc = await rootBundle.load(iccAsset);
      PdfaColorProfile(doc.document, icc.buffer.asUint8List());
      PdfaAttachedFiles(doc.document, [
        PdfaAttachedFile(
          name: EInvoiceWriter.zugferdFileName,
          data: xml,
          subType: '/text/xml',
          afRelationship: '/Alternative',
        ),
      ]);
    }

    final fonts = await PdfFonts.load();
    final base = fonts.base;
    final bold = fonts.bold;

    doc.addPage(
      pw.MultiPage(
        // Demo: „MUSTER – DEMO“ auf jeder Seite (FA-13.14).
        pageTheme: PdfWatermark.pageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 36),
          font: bold,
          theme: pw.ThemeData.withFont(base: base, bold: bold).copyWith(
            defaultTextStyle: pw.TextStyle(
              font: base,
              fontSize: 10,
              color: PdfColors.black,
            ),
          ),
        ),
        footer: _buildFooter,
        build: (context) => [
          _buildHeader(),
          pw.SizedBox(height: 28),
          _buildAddressAndMeta(),
          pw.SizedBox(height: 28),
          _buildTitle(),
          pw.SizedBox(height: 14),
          _buildItemTable(),
          pw.SizedBox(height: 12),
          _buildTotals(),
          if (invoice.isSmallBusiness) ...[
            pw.SizedBox(height: 16),
            _buildSmallBusinessNote(),
          ],
          if (invoice.notes.trim().isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(invoice.notes, style: const pw.TextStyle(fontSize: 9.5)),
          ],
          pw.SizedBox(height: 20),
          if (isOffer)
            _buildOfferBlock()
          else if (invoice.isCancellation)
            _buildCancellationBlock()
          else
            _buildPaymentBlock(),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _buildHeader() {
    final logo = _logoImage();
    final text = _buildSellerText();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (logo == null)
          text
        else
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: text),
              pw.SizedBox(width: 16),
              pw.ConstrainedBox(
                constraints: const pw.BoxConstraints(
                  maxWidth: logoMaxWidth,
                  maxHeight: logoMaxHeight,
                ),
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
            ],
          ),
        pw.SizedBox(height: 10),
        pw.Container(height: 2, color: _accent),
      ],
    );
  }

  /// Ein unlesbares Bild darf das PDF nicht verhindern – dann ohne Logo.
  pw.ImageProvider? _logoImage() {
    final bytes = logo;
    if (bytes == null || bytes.isEmpty) return null;
    try {
      return pw.MemoryImage(bytes);
    } on Object {
      return null;
    }
  }

  pw.Widget _buildSellerText() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          profile.companyName,
          style: pw.TextStyle(
            fontSize: 17,
            fontWeight: pw.FontWeight.bold,
            color: _accent,
          ),
        ),
        if (profile.ownerName.isNotEmpty)
          pw.Text(
            profile.ownerName,
            style: const pw.TextStyle(fontSize: 10, color: _muted),
          ),
        pw.SizedBox(height: 4),
        pw.Text(
          [
            profile.addressLine,
            if (profile.email.isNotEmpty) profile.email,
            if (profile.phone.isNotEmpty) profile.phone,
            if (profile.website.isNotEmpty) profile.website,
          ].where((s) => s.isNotEmpty).join('  ·  '),
          style: const pw.TextStyle(fontSize: 9, color: _muted),
        ),
      ],
    );
  }

  pw.Widget _buildAddressAndMeta() {
    final tax = profile.taxProfile;
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                isOffer ? 'Angebot für' : 'Rechnungsempfänger',
                style: const pw.TextStyle(fontSize: 8, color: _muted),
              ),
              pw.SizedBox(height: 6),
              for (final line in customer.addressLines)
                pw.Text(line, style: const pw.TextStyle(fontSize: 10.5)),
              if (customer.vatId.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  '${tax.vatIdLabel}: ${customer.vatId}',
                  style: const pw.TextStyle(fontSize: 9, color: _muted),
                ),
              ],
            ],
          ),
        ),
        pw.SizedBox(width: 24),
        pw.Expanded(
          flex: 2,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (isOffer) ...[
                _metaRow('Angebotsnummer', invoice.number, emphasize: true),
                _metaRow('Angebotsdatum', Fmt.date(invoice.issueDate)),
                _metaRow('Gültig bis', Fmt.date(offerValidUntil!)),
              ] else ...[
                _metaRow('Rechnungsnummer', invoice.number, emphasize: true),
                _metaRow('Rechnungsdatum', Fmt.date(invoice.issueDate)),
              ],
              if (invoice.isCancellation) ...[
                _metaRow('Storno zu', invoice.cancelsNumber),
                if (invoice.cancelsIssueDate != null)
                  _metaRow('vom', Fmt.date(invoice.cancelsIssueDate!)),
              ],
              if (invoice.deliveryDate != null)
                _metaRow('Leistungsdatum', Fmt.date(invoice.deliveryDate!)),
              if (invoice.dueDate != null)
                _metaRow('Fällig am', Fmt.date(invoice.dueDate!)),
              if (profile.taxNumber.isNotEmpty)
                _metaRow(tax.taxNumberLabel, profile.taxNumber),
              if (profile.vatId.isNotEmpty)
                _metaRow(tax.vatIdLabel, profile.vatId),
              if (InvoiceTexts.showsEuSmeId(profile, invoice, customer))
                _metaRow(InvoiceTexts.euSmeIdLabel, profile.euSmeId),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _metaRow(String label, String value, {bool emphasize = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 82,
            child: pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 9, color: _muted),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: emphasize ? 10.5 : 9.5,
                fontWeight: emphasize
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _title => isOffer
      ? InvoiceTexts.offerTitle(invoice.number)
      : invoice.isCancellation
      ? InvoiceTexts.cancellationTitle(invoice.number)
      : 'Rechnung ${invoice.number}';

  /// Gültigkeit und AGB-Verweis statt Zahlungsangaben (L-3.17, L-3.25).
  pw.Widget _buildOfferBlock() => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        InvoiceTexts.offerValidity(Fmt.date(offerValidUntil!)),
        style: const pw.TextStyle(fontSize: 9.5),
      ),
      if (profile.termsUrl.trim().isNotEmpty) ...[
        pw.SizedBox(height: 10),
        pw.Text(
          InvoiceTexts.termsReference(profile.termsUrl),
          style: const pw.TextStyle(fontSize: 8.5, color: _muted),
        ),
      ],
    ],
  );

  pw.Widget _buildTitle() {
    return pw.Text(
      _title,
      style: pw.TextStyle(
        fontSize: 15,
        fontWeight: pw.FontWeight.bold,
        color: _accent,
      ),
    );
  }

  pw.Widget _buildItemTable() {
    final showVatColumn = !invoice.isSmallBusiness;

    return pw.Table(
      columnWidths: {
        0: const pw.FixedColumnWidth(24),
        1: const pw.FlexColumnWidth(4),
        2: const pw.FixedColumnWidth(52),
        3: const pw.FixedColumnWidth(70),
        if (showVatColumn) 4: const pw.FixedColumnWidth(42),
        (showVatColumn ? 5 : 4): const pw.FixedColumnWidth(78),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _accent, width: 1)),
          ),
          children: [
            _headerCell('Pos'),
            _headerCell('Bezeichnung'),
            _headerCell('Menge', align: pw.TextAlign.right),
            _headerCell('Einzelpreis', align: pw.TextAlign.right),
            if (showVatColumn) _headerCell('USt', align: pw.TextAlign.right),
            _headerCell('Betrag', align: pw.TextAlign.right),
          ],
        ),
        for (final item in invoice.items)
          pw.TableRow(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _hairline, width: 0.5),
              ),
            ),
            children: [
              _cell(item.position.toString()),
              _cell(
                item.hasDiscount
                    ? '${item.description}\n${InvoiceTexts.itemDiscount(item)}'
                    : item.description,
              ),
              _cell(
                '${Fmt.quantity(invoice.isCancellation ? -item.quantityMilli : item.quantityMilli)} ${item.unit}',
                align: pw.TextAlign.right,
              ),
              _cell(Fmt.amount(item.unitPrice), align: pw.TextAlign.right),
              if (showVatColumn)
                _cell(Fmt.vatRate(item.vatPermille), align: pw.TextAlign.right),
              _cell(
                Fmt.amount(invoice.isCancellation ? -item.net : item.net),
                align: pw.TextAlign.right,
              ),
            ],
          ),
      ],
    );
  }

  pw.Widget _headerCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 3),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: 8.5,
        fontWeight: pw.FontWeight.bold,
        color: _accent,
      ),
    ),
  );

  pw.Widget _cell(String text, {pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 3),
        child: pw.Text(
          text,
          textAlign: align,
          style: const pw.TextStyle(fontSize: 9.5),
        ),
      );

  pw.Widget _buildTotals() {
    final totals = invoice.totals;
    final multiRate = totals.breakdown.length > 1;
    String rateSuffix(int permille) => multiRate && !invoice.isSmallBusiness
        ? ' (${Fmt.vatRate(permille)})'
        : '';
    final rows = <pw.Widget>[];
    if (totals.discountLines.isNotEmpty || totals.shippingLines.isNotEmpty) {
      rows.add(_totalRow('Summe Positionen', totals.itemsNet));
      for (final line in totals.discountLines) {
        rows.add(
          _totalRow(
            '${InvoiceTexts.invoiceDiscountLabel(invoice)}'
            '${rateSuffix(line.vatPermille)}',
            line.net,
          ),
        );
      }
      for (final line in totals.shippingLines) {
        rows.add(
          _totalRow('Versandkosten${rateSuffix(line.vatPermille)}', line.net),
        );
      }
    }
    rows.add(_totalRow('Zwischensumme netto', invoice.netTotal));

    if (!invoice.isSmallBusiness) {
      final breakdown = totals.breakdown.entries.toList();
      for (final entry in breakdown) {
        rows.add(
          _totalRow(
            'zzgl. ${Fmt.vatRate(entry.key)} USt auf ${Fmt.amount(entry.value.net)}',
            entry.value.vat,
          ),
        );
      }
    }

    rows.add(pw.SizedBox(height: 4));
    rows.add(_totalRow('Gesamtbetrag', invoice.grossTotal, emphasize: true));

    return pw.Row(
      children: [
        pw.Spacer(flex: 3),
        pw.Expanded(
          flex: 4,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: rows,
          ),
        ),
      ],
    );
  }

  pw.Widget _totalRow(String label, Money value, {bool emphasize = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      decoration: emphasize
          ? const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: _accent, width: 1)),
            )
          : null,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: emphasize ? 11 : 9.5,
              fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            Fmt.money(value),
            style: pw.TextStyle(
              fontSize: emphasize ? 11 : 9.5,
              fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSmallBusinessNote() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF2F6F8),
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Text(
        profile.taxProfile.smallBusinessInvoiceNote,
        style: const pw.TextStyle(fontSize: 9.5),
      ),
    );
  }

  /// Bezug, Grund und Erstattungshinweis der Stornorechnung (L-3.7).
  pw.Widget _buildCancellationBlock() {
    final paid = invoice.paidAt != null;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          InvoiceTexts.cancellationReference(
            invoice.cancelsNumber,
            invoice.cancelsIssueDate ?? invoice.issueDate,
          ),
          style: const pw.TextStyle(fontSize: 9.5),
        ),
        if (invoice.cancelReason.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            'Grund: ${invoice.cancelReason}',
            style: const pw.TextStyle(fontSize: 9.5),
          ),
        ],
        pw.SizedBox(height: 6),
        pw.Text(
          paid
              ? InvoiceTexts.cancellationRefund(Fmt.money(-invoice.grossTotal))
              : InvoiceTexts.cancellationNothingToPay,
          style: const pw.TextStyle(fontSize: 9.5),
        ),
      ],
    );
  }

  pw.Widget _buildPaymentBlock() {
    final parts = <String>[];
    final terms = InvoiceTexts.paymentTerms(invoice);
    if (terms.isNotEmpty) parts.add(terms);
    if (profile.iban.isNotEmpty) {
      parts.add(InvoiceTexts.transferRequest(invoice.number));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (parts.isNotEmpty)
          pw.Text(parts.join(' '), style: const pw.TextStyle(fontSize: 9.5)),
        if (profile.iban.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            [
              if (profile.bankName.isNotEmpty) profile.bankName,
              'IBAN ${profile.iban}',
              if (profile.bic.isNotEmpty) 'BIC ${profile.bic}',
            ].join('  ·  '),
            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
          ),
        ],
        // DE: Verzug bei Verbrauchern nach 30 Tagen nur mit Hinweis
        // (§ 286 Abs 3 BGB, L-3.28). Text aus dem TaxProfile.
        if (!customer.isBusiness &&
            profile.taxProfile.dunning.consumerDefaultNotice != null) ...[
          pw.SizedBox(height: 8),
          pw.Text(
            profile.taxProfile.dunning.consumerDefaultNotice!,
            style: const pw.TextStyle(fontSize: 8.5, color: _muted),
          ),
        ],
        if (profile.termsUrl.trim().isNotEmpty) ...[
          pw.SizedBox(height: 10),
          pw.Text(
            InvoiceTexts.termsReference(profile.termsUrl),
            style: const pw.TextStyle(fontSize: 8.5, color: _muted),
          ),
        ],
      ],
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    final line = [
      profile.companyName,
      profile.addressLine,
      if (profile.taxNumber.isNotEmpty)
        '${profile.taxProfile.taxNumberLabel} ${profile.taxNumber}',
      if (profile.vatId.isNotEmpty)
        '${profile.taxProfile.vatIdLabel} ${profile.vatId}',
      // § 14 UGB / § 37a HGB: eingetragene Unternehmen auf jeder Rechnung.
      if (profile.registerNumber.isNotEmpty)
        '${profile.taxProfile.registerNumberLabel} ${profile.registerNumber}, '
            '${profile.registerCourt}',
    ].where((s) => s.isNotEmpty).join('  ·  ');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(height: 0.5, color: _hairline),
        pw.SizedBox(height: 6),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(
                profile.invoiceFooter.isNotEmpty ? profile.invoiceFooter : line,
                style: const pw.TextStyle(fontSize: 7.5, color: _muted),
              ),
            ),
            pw.Text(
              'Seite ${context.pageNumber} von ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 7.5, color: _muted),
            ),
          ],
        ),
      ],
    );
  }
}
