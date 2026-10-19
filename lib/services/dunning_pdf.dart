import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdf_fonts.dart';
import 'pdf_watermark.dart';

import '../core/formatting.dart';
import '../domain/company_profile.dart';
import '../domain/customer.dart';
import '../domain/dunning.dart';
import '../domain/invoice.dart';
import '../domain/money.dart';
import 'dunning_calculator.dart';

/// PDF einer Zahlungserinnerung bzw. Mahnung (L-3.29): Bezug auf die
/// Rechnungsnummer, Tabelle offener Betrag + Mahnkosten + Zinsen (+
/// Pauschale) = Gesamt, neue Frist als Datum. Nebenforderungen sind als
/// „nicht umsatzsteuerbar“ gekennzeichnet (kein Entgelt für eine Leistung).
class DunningPdf {
  const DunningPdf({
    required this.notice,
    required this.invoice,
    required this.customer,
    required this.profile,
  });

  final DunningNotice notice;
  final Invoice invoice;
  final Customer customer;
  final CompanyProfile profile;

  static const _accent = PdfColor.fromInt(0xFF1B4965);
  static const _muted = PdfColor.fromInt(0xFF5A6B78);

  /// Zeilen der Betragstabelle – auch für Tests und die Vorschau.
  static List<(String, Money)> rows(
    DunningNotice notice,
    DunningRules rules, {
    required bool business,
  }) => [
    ('Offener Rechnungsbetrag', notice.principal),
    if (!notice.feesTotal.isZero)
      ('Mahnkosten (nicht umsatzsteuerbar)', notice.feesTotal),
    if (!notice.interest.isZero)
      (
        'Verzugszinsen ${DunningCalculator.rateText(notice.interestRateBp)} '
            'p. a., ${rules.interestLegalRef(business: business)} '
            '(nicht umsatzsteuerbar)',
        notice.interest,
      ),
    if (!notice.flatFee.isZero)
      (
        'Pauschale ${rules.flatFeeLegalRef} (nicht umsatzsteuerbar)',
        notice.flatFee,
      ),
  ];

  Future<Uint8List> build() async {
    final rules = profile.taxProfile.dunning;
    final doc = pw.Document(
      title: PdfWatermark.title(
        '${notice.title} zu Rechnung ${invoice.number}',
      ),
      author: profile.companyName,
      keywords: PdfWatermark.keywords(),
    );
    final fonts = await PdfFonts.load();
    final base = fonts.base;
    final bold = fonts.bold;
    final tableRows = rows(notice, rules, business: customer.isBusiness);
    doc.addPage(
      pw.Page(
        // Demo: „MUSTER – DEMO“ auf der Seite (FA-13.14).
        pageTheme: PdfWatermark.pageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 36),
          theme: pw.ThemeData.withFont(base: base, bold: bold),
          font: bold,
        ),
        build: (context) => pw.Column(
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
            pw.Text(
              profile.addressLine,
              style: const pw.TextStyle(fontSize: 9, color: _muted),
            ),
            pw.SizedBox(height: 28),
            for (final line in customer.addressLines)
              pw.Text(line, style: const pw.TextStyle(fontSize: 10.5)),
            pw.SizedBox(height: 24),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                Fmt.date(notice.issuedOn),
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              '${notice.title} zu Rechnung ${invoice.number} vom '
              '${Fmt.date(invoice.issueDate)}',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: _accent,
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Text(notice.text, style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 16),
            pw.Table(
              columnWidths: const {
                0: pw.FlexColumnWidth(4),
                1: pw.FixedColumnWidth(90),
              },
              children: [
                for (final (label, amount) in tableRows)
                  pw.TableRow(
                    children: [
                      _cell(label),
                      _cell(Fmt.money(amount), right: true),
                    ],
                  ),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      top: pw.BorderSide(color: _accent, width: 1),
                    ),
                  ),
                  children: [
                    _cell('Gesamt', bold: true),
                    _cell(Fmt.money(notice.total), right: true, bold: true),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Neue Zahlungsfrist: ${Fmt.date(notice.newDueDate)}',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            if (profile.iban.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              pw.Text(
                [
                  if (profile.bankName.isNotEmpty) profile.bankName,
                  'IBAN ${profile.iban}',
                  if (profile.bic.isNotEmpty) 'BIC ${profile.bic}',
                  'Verwendungszweck ${invoice.number}',
                ].join('  ·  '),
                style: const pw.TextStyle(fontSize: 9.5),
              ),
            ],
          ],
        ),
      ),
    );
    return doc.save();
  }

  pw.Widget _cell(String text, {bool right = false, bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 3),
        child: pw.Text(
          text,
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
            fontSize: 9.5,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );

  /// SHA-256 des gesendeten PDFs als Hex – Nachweis im Datensatz.
  static Future<String> sha256Hex(List<int> bytes) async {
    final hash = await Sha256().hash(bytes);
    return hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
