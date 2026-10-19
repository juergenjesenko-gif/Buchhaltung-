/// Berichte für die Steuerberatung (FA-15.8 bis FA-15.12): Anlagenverzeichnis,
/// Saldenliste und vorläufiger Jahresabschluss als PDF.
///
/// [AnnualReportData] wird aus Repositories geladen und hier nur gerechnet
/// und gesetzt; Widgets rechnen nichts.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/formatting.dart';
import '../../data/repositories.dart' show CategorySum, PeriodTotals;
import '../../domain/company_profile.dart';
import '../../domain/fixed_asset.dart';
import '../../domain/invoice.dart';
import '../../domain/money.dart';
import '../../domain/receipt.dart';
import '../assets/depreciation.dart';
import '../pdf_fonts.dart';
import '../pdf_watermark.dart';

/// Zeile der Saldenliste.
class BalanceLine {
  const BalanceLine(this.account, this.label, this.amount, {this.count = 0});

  final String account;
  final String label;
  final Money amount;
  final int count;
}

/// Zeile des Anlagenverzeichnisses für ein Jahr.
class AssetRegisterLine {
  const AssetRegisterLine(this.asset, this.row, this.classLabel);

  final FixedAsset asset;
  final AfaYear row;
  final String classLabel;
}

class AnnualReportData {
  AnnualReportData({
    required this.profile,
    required this.periodLabel,
    required this.from,
    required this.to,
    required this.totals,
    required this.categorySums,
    required this.categories,
    required this.assets,
    required this.openInvoices,
    this.comment = '',
  });

  final CompanyProfile profile;
  final String periodLabel;
  final DateTime from;
  final DateTime to;
  final PeriodTotals totals;
  final List<CategorySum> categorySums;
  final List<ExpenseCategory> categories;
  final List<FixedAsset> assets;
  final List<Invoice> openInvoices;

  /// Kommentar an die Steuerberatung, steht im PDF.
  final String comment;

  bool get smallBusiness => profile.isSmallBusiness;
  DepreciationRules get rules => profile.taxProfile.depreciation;

  /// Anlagenverzeichnis des Jahres von [to]: alle Güter, die im Jahr
  /// vorhanden waren (angeschafft bis Jahresende, nicht vor Jahresbeginn
  /// ausgeschieden).
  List<AssetRegisterLine> get register {
    final year = to.year;
    final out = <AssetRegisterLine>[];
    for (final a in assets) {
      if (a.acquiredOn.year > year) continue;
      final plan = Depreciation.plan(a, rules, untilYear: year);
      final row = plan.where((r) => r.year == year).firstOrNull;
      if (row == null) continue; // vor diesem Jahr vollständig abgegangen
      out.add(AssetRegisterLine(a, row, rules.classFor(a.categoryKey).label));
    }
    out.sort((x, y) => x.asset.acquiredOn.compareTo(y.asset.acquiredOn));
    return out;
  }

  /// Saldenliste: Kategorien, AfA, Anlagen, Umsatzsteuer.
  List<BalanceLine> get balances {
    String nameOf(int? id) =>
        categories.where((c) => c.id == id).firstOrNull?.name ??
        'Ohne Kategorie';
    String accountOf(int? id) =>
        categories.where((c) => c.id == id).firstOrNull?.datevAccount ?? '';
    final income = categorySums.where((c) => c.isIncome).toList()
      ..sort(
        (a, b) => accountOf(a.categoryId).compareTo(accountOf(b.categoryId)),
      );
    final expense = categorySums.where((c) => !c.isIncome).toList()
      ..sort(
        (a, b) => accountOf(a.categoryId).compareTo(accountOf(b.categoryId)),
      );
    final reg = register;
    Money sum(Iterable<Money> m) => m.fold(const Money.zero(), (a, b) => a + b);
    return [
      for (final c in income)
        BalanceLine(
          accountOf(c.categoryId),
          'Einnahmen: ${nameOf(c.categoryId)}',
          c.amount,
          count: c.count,
        ),
      for (final c in expense)
        BalanceLine(
          accountOf(c.categoryId),
          'Ausgaben: ${nameOf(c.categoryId)}',
          c.amount,
          count: c.count,
        ),
      // Bewirtung (FA-2.60): nicht abziehbarer Teil, in der Kategorie
      // enthalten und dem Ergebnis hinzugerechnet.
      if (!totals.entertainmentNonDeductible.isZero)
        BalanceLine(
          '',
          'davon Bewirtung nicht abziehbar '
              '(${profile.taxProfile.entertainment.legalRef})',
          totals.entertainmentNonDeductible,
        ),
      // Abgaben ohne Gewinnminderung (FA-19.4): privat bzw. nicht abziehbar.
      if (!totals.nonDeductibleLevies.isZero)
        BalanceLine(
          '',
          'davon Steuern/Abgaben privat, nicht Betriebsausgabe',
          totals.nonDeductibleLevies,
        ),
      BalanceLine(
        '',
        'AfA, GWG, Sammelposten, Restbuchwerte',
        totals.depreciation,
      ),
      BalanceLine(
        '',
        'Anlagen: Buchwert Jahresbeginn',
        sum(
          reg
              .where((l) => l.asset.acquiredOn.year < to.year)
              .map((l) => l.row.opening),
        ),
      ),
      BalanceLine(
        '',
        'Anlagen: Zugänge',
        sum(
          reg
              .where((l) => l.asset.acquiredOn.year == to.year)
              .map((l) => l.row.opening),
        ),
      ),
      BalanceLine(
        '',
        'Anlagen: Buchwert Jahresende',
        sum(reg.map((l) => l.row.closing)),
      ),
      if (!smallBusiness) ...[
        BalanceLine('', 'Umsatzsteuer', totals.incomeVat),
        BalanceLine('', 'Vorsteuer', totals.expenseVat),
        BalanceLine('', 'Zahllast (+) / Guthaben (−)', totals.vatPayable),
      ],
    ];
  }

  Money get openInvoicesTotal =>
      openInvoices.fold(const Money.zero(), (a, i) => a + i.grossTotal);

  static String customerName(Invoice invoice) {
    final raw = invoice.customerSnapshot;
    if (raw == null || raw.isEmpty) return '';
    try {
      final map = jsonDecode(raw);
      if (map is Map && map['name'] is String) return map['name'] as String;
    } on FormatException {
      return '';
    }
    return '';
  }
}

enum ReportKind {
  assetRegister('Anlagenverzeichnis'),
  trialBalance('Saldenliste'),
  preliminary('Vorläufiger Jahresabschluss');

  const ReportKind(this.title);
  final String title;
}

class AnnualReportPdf {
  AnnualReportPdf(this.data);

  final AnnualReportData data;

  static const preliminaryMark =
      'VORLÄUFIG – zur Prüfung und Fertigstellung durch die Steuerberatung';

  String fileName(ReportKind kind) {
    final base = switch (kind) {
      ReportKind.assetRegister => 'Anlagenverzeichnis',
      ReportKind.trialBalance => 'Saldenliste',
      ReportKind.preliminary => 'Vorlaeufiger_Jahresabschluss',
    };
    return '${base}_${Fmt.isoDate(data.from)}_${Fmt.isoDate(data.to)}.pdf';
  }

  Future<Uint8List> build(ReportKind kind) async {
    final fonts = await PdfFonts.load();
    final doc = pw.Document(
      title: PdfWatermark.title(kind.title),
      author: data.profile.companyName,
      keywords: PdfWatermark.keywords(),
    );
    doc.addPage(
      pw.MultiPage(
        // Demo: „MUSTER – DEMO“ auf jeder Seite (FA-13.14).
        pageTheme: PdfWatermark.pageTheme(
          pageFormat: PdfPageFormat.a4,
          theme: fonts.theme,
          margin: const pw.EdgeInsets.all(36),
          font: fonts.bold,
        ),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              preliminaryMark,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.red800,
              ),
            ),
            pw.SizedBox(height: 4),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Seite ${context.pageNumber} von ${context.pagesCount} · '
            'erstellt mit JeNi bucht am ${Fmt.date(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
        build: (context) => [
          pw.Text(
            kind.title,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            '${data.profile.companyName} · ${data.periodLabel} '
            '(${Fmt.date(data.from)} – ${Fmt.date(data.to)})',
          ),
          if (data.profile.taxNumber.isNotEmpty)
            pw.Text(
              '${data.profile.taxProfile.taxNumberLabel}: '
              '${data.profile.taxNumber}',
            ),
          if (data.smallBusiness)
            pw.Text(
              'Kleinunternehmer (${data.profile.taxProfile.smallBusinessLegalRef}): '
              'Beträge brutto, kein Vorsteuerabzug.',
            ),
          pw.SizedBox(height: 10),
          if (data.comment.trim().isNotEmpty) ...[
            _heading('Kommentar an die Steuerberatung'),
            pw.Text(data.comment.trim()),
            pw.SizedBox(height: 10),
          ],
          ...switch (kind) {
            ReportKind.assetRegister => _assetRegister(),
            ReportKind.trialBalance => _trialBalance(),
            ReportKind.preliminary => [
              ..._incomeStatement(),
              ..._assetRegister(),
              ..._trialBalance(),
              ..._openItems(),
            ],
          },
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _heading(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
    ),
  );

  pw.Widget _table(
    List<String> head,
    List<List<String>> rows, {
    Set<int> right = const {},
  }) {
    return pw.TableHelper.fromTextArray(
      headers: head,
      data: rows,
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignments: {for (final i in right) i: pw.Alignment.centerRight},
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
    );
  }

  List<pw.Widget> _incomeStatement() {
    final t = data.totals;
    final form = data.profile.taxProfile.annualReturnForm;
    final rows = <List<String>>[
      ['Betriebseinnahmen', Fmt.money(t.incomeNet)],
      [
        data.smallBusiness
            ? 'Betriebsausgaben (brutto, ohne Anlagenzugänge)'
            : 'Betriebsausgaben (netto, ohne Anlagenzugänge)',
        Fmt.money(t.expenseNet - t.capitalizedExpense),
      ],
      ['AfA, GWG, Sammelposten, Restbuchwerte', Fmt.money(t.depreciation)],
      if (!t.expenseFxDifference.isZero)
        ['Kursdifferenzen laut Bank', Fmt.money(t.expenseFxDifference)],
      if (!t.entertainmentNonDeductible.isZero)
        [
          'Hinzurechnung Bewirtung nicht abziehbar '
              '(${data.profile.taxProfile.entertainment.legalRef})',
          Fmt.money(t.entertainmentNonDeductible),
        ],
      if (!t.nonDeductibleLevies.isZero)
        [
          'Hinzurechnung Steuern/Abgaben privat (FA-19.4)',
          Fmt.money(t.nonDeductibleLevies),
        ],
      ['Ergebnis (Gewinn/Verlust)', Fmt.signedMoney(t.profit)],
    ];
    return [
      _heading('Einnahmen-Ausgaben-Rechnung (Gliederung ${form.formName})'),
      _table(['Posten', 'Betrag'], rows, right: {1}),
      pw.Text(
        'Die Aufteilung der Betriebsausgaben auf die Zeilen der '
        '${form.formName} steht in der Saldenliste je Kategorie.',
        style: const pw.TextStyle(fontSize: 8),
      ),
    ];
  }

  List<pw.Widget> _assetRegister() {
    final lines = data.register;
    final rules = data.rules;
    final rows = <List<String>>[
      for (final l in lines)
        [
          l.asset.name,
          l.classLabel,
          Fmt.date(l.asset.acquiredOn),
          Fmt.money(l.asset.cost),
          switch (l.asset.method) {
            DepreciationMethod.linear => '${l.asset.usefulLifeYears} J.',
            DepreciationMethod.gwg => 'GWG',
            DepreciationMethod.pool => 'Sammelp.',
          },
          Fmt.money(l.row.opening),
          Fmt.money(l.row.afa),
          Fmt.money(l.row.disposalValue),
          Fmt.money(l.row.closing),
        ],
    ];
    final notes = <pw.Widget>[
      for (final l in lines)
        if (l.asset.comment.isNotEmpty ||
            l.asset.lifeReason.isNotEmpty ||
            l.asset.isDisposed)
          pw.Bullet(
            text: [
              l.asset.name,
              if (l.asset.lifeReason.isNotEmpty)
                'Nutzungsdauer: ${l.asset.lifeReason}',
              if (l.asset.comment.isNotEmpty) l.asset.comment,
              if (l.asset.isDisposed)
                'Ausgeschieden am ${Fmt.date(l.asset.disposedOn!)} '
                    '(${l.asset.disposalKind?.label ?? ''}'
                    '${l.asset.disposalProceeds.isZero ? '' : ', Erlös ${Fmt.money(l.asset.disposalProceeds)}'}): '
                    '${l.asset.disposalComment}',
            ].join(' – '),
            style: const pw.TextStyle(fontSize: 8),
          ),
    ];
    return [
      _heading(
        'Anlagenverzeichnis ${data.to.year} (${rules.registerLegalRef})',
      ),
      if (rows.isEmpty)
        pw.Text('Keine Anlagen.')
      else
        _table(
          [
            'Bezeichnung',
            'Art',
            'Angeschafft',
            data.smallBusiness ? 'AK brutto' : 'AK netto',
            'ND',
            'Buchwert 1.1.',
            'AfA',
            'Abgang',
            'Buchwert 31.12.',
          ],
          rows,
          right: {3, 5, 6, 7, 8},
        ),
      ...notes,
      pw.Text(
        'AfA ${rules.timingLegalRef}; GWG bis ${Fmt.money(rules.gwgLimit)} '
        '(${rules.gwgLegalRef}).',
        style: const pw.TextStyle(fontSize: 8),
      ),
    ];
  }

  List<pw.Widget> _trialBalance() {
    final lines = data.balances;
    return [
      _heading('Saldenliste ${data.periodLabel}'),
      _table(
        ['Konto', 'Bezeichnung', 'Belege', 'Saldo'],
        [
          for (final l in lines)
            [
              l.account,
              l.label,
              l.count == 0 ? '' : '${l.count}',
              Fmt.money(l.amount),
            ],
        ],
        right: {2, 3},
      ),
      pw.Text(
        'Einnahmen-Ausgaben-Rechnung: Salden sind Summen der Zahlungen im '
        'Zeitraum; Anfangs- und Endbestände nur beim Anlagevermögen.',
        style: const pw.TextStyle(fontSize: 8),
      ),
    ];
  }

  List<pw.Widget> _openItems() {
    final inv = data.openInvoices;
    return [
      _heading('Offene Posten (nur zur Information)'),
      if (inv.isEmpty)
        pw.Text('Keine offenen Rechnungen.')
      else ...[
        _table(
          ['Nummer', 'Datum', 'Kunde', 'Brutto'],
          [
            for (final i in inv)
              [
                i.number,
                Fmt.date(i.issueDate),
                AnnualReportData.customerName(i),
                Fmt.money(i.grossTotal),
              ],
          ],
          right: {3},
        ),
        pw.Text('Summe offen: ${Fmt.money(data.openInvoicesTotal)}'),
      ],
      pw.Text(
        'Offene Rechnungen sind bei der Einnahmen-Ausgaben-Rechnung erst '
        'mit Zahlung Einnahme (Zuflussprinzip).',
        style: const pw.TextStyle(fontSize: 8),
      ),
    ];
  }
}
