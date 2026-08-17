import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/formatting.dart';
import '../domain/company_profile.dart';
import '../domain/customer.dart';
import '../domain/invoice.dart';
import '../domain/money.dart';

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
  });

  final Invoice invoice;
  final Customer customer;
  final CompanyProfile profile;

  static const _accent = PdfColor.fromInt(0xFF1B4965);
  static const _muted = PdfColor.fromInt(0xFF5A6B78);
  static const _hairline = PdfColor.fromInt(0xFFD6DEE4);

  Future<Uint8List> build() async {
    final doc = pw.Document(
      title: 'Rechnung ${invoice.number}',
      author: profile.companyName,
    );

    final base = pw.Font.helvetica();
    final bold = pw.Font.helveticaBold();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 36),
        theme: pw.ThemeData.withFont(base: base, bold: bold).copyWith(
          defaultTextStyle: pw.TextStyle(
            font: base,
            fontSize: 10,
            color: PdfColors.black,
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
          _buildPaymentBlock(),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _buildHeader() {
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
        pw.SizedBox(height: 10),
        pw.Container(height: 2, color: _accent),
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
                'Rechnungsempfänger',
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
              _metaRow('Rechnungsnummer', invoice.number, emphasize: true),
              _metaRow('Rechnungsdatum', Fmt.date(invoice.issueDate)),
              if (invoice.deliveryDate != null)
                _metaRow('Leistungsdatum', Fmt.date(invoice.deliveryDate!)),
              if (invoice.dueDate != null)
                _metaRow('Fällig am', Fmt.date(invoice.dueDate!)),
              if (profile.taxNumber.isNotEmpty)
                _metaRow(tax.taxNumberLabel, profile.taxNumber),
              if (profile.vatId.isNotEmpty)
                _metaRow(tax.vatIdLabel, profile.vatId),
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

  pw.Widget _buildTitle() {
    return pw.Text(
      'Rechnung ${invoice.number}',
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
              _cell(item.description),
              _cell(
                '${Fmt.quantity(item.quantityMilli)} ${item.unit}',
                align: pw.TextAlign.right,
              ),
              _cell(Fmt.amount(item.unitPrice), align: pw.TextAlign.right),
              if (showVatColumn)
                _cell(Fmt.vatRate(item.vatPermille), align: pw.TextAlign.right),
              _cell(Fmt.amount(item.net), align: pw.TextAlign.right),
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
    final rows = <pw.Widget>[
      _totalRow('Zwischensumme netto', invoice.netTotal),
    ];

    if (!invoice.isSmallBusiness) {
      final breakdown = invoice.vatBreakdown.entries.toList()
        ..sort((a, b) => b.key.compareTo(a.key));
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

  pw.Widget _buildPaymentBlock() {
    final parts = <String>[];
    if (invoice.dueDate != null) {
      parts.add('Zahlbar ohne Abzug bis ${Fmt.date(invoice.dueDate!)}.');
    }
    if (profile.iban.isNotEmpty) {
      parts.add(
        'Bitte überweise den Betrag unter Angabe der Rechnungsnummer '
        '${invoice.number} auf folgendes Konto:',
      );
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
