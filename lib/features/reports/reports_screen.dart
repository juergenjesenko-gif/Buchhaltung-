import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../domain/invoice.dart';
import '../../services/contracts/contract_csv.dart';
import '../../services/export/exporters.dart';
import '../../services/licensing/license_policy.dart';
import '../../services/reports/annual_report.dart';
import '../../services/reports/report_package.dart';
import '../../services/share_service.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/common.dart';
import '../assets/asset_screens.dart';
import '../help/help_screen.dart';
import '../licensing/feature_gate.dart';

/// Berichte für die Steuerberatung (FA-15.8 bis FA-15.11): Anlagen,
/// Anlagenverzeichnis, Saldenliste, vorläufiger Jahresabschluss.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late int _year;
  final _comment = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final profile = AppScope.read(context).profile;
    // Vorbelegt: das zuletzt abgeschlossene Jahr.
    _year =
        (profile?.fiscalYear.yearOf(DateTime.now()) ?? DateTime.now().year) - 1;
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<AnnualReportData?> _data() async {
    final state = AppScope.read(context);
    final profile = state.profile;
    if (profile == null) return null;
    final period = Period.fiscalYear(
      profile.fiscalYear,
      _year,
      profile.taxProfile.monthNames,
    );
    final repos = state.repositories;
    final totals = await repos.receipts.totals(
      from: period.from,
      to: period.to,
      inputVatDeductible: state.inputVatDeductible,
      reverseChargePermille: state.reverseChargePermille,
      depreciation: state.depreciationRules,
    );
    return AnnualReportData(
      profile: profile,
      periodLabel: period.label,
      from: period.from,
      to: period.to,
      totals: totals,
      categorySums: await repos.receipts.categorySums(
        from: period.from,
        to: period.to,
        inputVatDeductible: state.inputVatDeductible,
      ),
      categories: state.categories,
      assets: await repos.assets.all(),
      openInvoices: await repos.invoices.all(status: InvoiceStatus.issued),
      comment: _comment.text,
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on Exception catch (e) {
      if (mounted) showSnack(context, 'Nicht erstellt: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sharePdf(ReportKind kind) async {
    if (kind != ReportKind.assetRegister &&
        !await ensureFeature(context, Feature.annualReports)) {
      return;
    }
    await _run(() async {
      final data = await _data();
      if (data == null) return;
      final pdf = AnnualReportPdf(data);
      await ShareService.sharePdf(
        fileName: pdf.fileName(kind),
        bytes: await pdf.build(kind),
        subject: '${kind.title} ${data.periodLabel}',
      );
    });
  }

  Future<void> _sharePackage() async {
    if (!await ensureFeature(context, Feature.annualReports)) return;
    if (!mounted) return;
    final state = AppScope.read(context);
    await _run(() async {
      final data = await _data();
      if (data == null) return;
      final pdf = AnnualReportPdf(data);
      final repos = state.repositories;
      final period = Period.fiscalYear(
        data.profile.fiscalYear,
        _year,
        data.profile.taxProfile.monthNames,
      );
      final exporter = Exporter(
        profile: data.profile,
        receipts: await repos.receipts.query(from: data.from, to: data.to),
        categories: state.categories,
        totals: data.totals,
        period: period,
        comments: await repos.receipts.allComments(),
        pageCounts: await repos.receipts.pageCounts(),
        originals: await repos.receipts.documentSummaries(),
      );
      final code = data.profile.country.code;
      final formats = [
        ExportFormat.plainCsv,
        if (code == 'DE') ExportFormat.datev,
        if (code == 'AT') ExportFormat.bmd,
        ExportFormat.vatReturn,
      ];
      final csvs = <String, String>{};
      for (final f in formats) {
        final r = exporter.build(f);
        csvs[r.fileName] = r.content;
      }
      final contracts = await repos.contracts.all();
      if (contracts.isNotEmpty) {
        csvs[ContractCsv.fileName] = ContractCsv.build(contracts);
      }
      final zip = ReportPackage.zip(
        pdfs: {
          pdf.fileName(ReportKind.preliminary): await pdf.build(
            ReportKind.preliminary,
          ),
        },
        csvs: csvs,
      );
      await ShareService.shareZip(
        fileName:
            'Jahresabschluss_vorlaeufig_${Fmt.isoDate(data.from)}_'
            '${Fmt.isoDate(data.to)}.zip',
        bytes: zip,
        subject:
            'Vorläufiger Jahresabschluss ${data.periodLabel} – '
            '${data.profile.companyName}',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = AppScope.of(context).profile;
    final now = DateTime.now().year;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anlagen und Jahresabschluss'),
        actions: const [HelpButton()],
      ),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Card(
              child: ListTile(
                key: const Key('open-assets'),
                minVerticalPadding: 12,
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Anlagen'),
                subtitle: const Text('Investitionen, AfA, Ausscheiden'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AssetListScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Jahr',
              child: Column(
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _year,
                    decoration: const InputDecoration(labelText: 'Jahr'),
                    items: [
                      for (var y = now; y >= now - 7; y--)
                        DropdownMenuItem(
                          value: y,
                          child: Text(
                            profile?.fiscalYear.shortLabel(y) ?? '$y',
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _year = v ?? _year),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _comment,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Kommentar an die Steuerberatung (optional)',
                      helperText: 'Steht oben im PDF',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Berichte',
              child: Column(
                children: [
                  _ReportTile(
                    key: const Key('report-assets'),
                    icon: Icons.list_alt_outlined,
                    title: 'Anlagenverzeichnis (PDF)',
                    subtitle: 'Pflichtverzeichnis mit AfA, in jedem Abo',
                    enabled: !_busy,
                    onTap: () => _sharePdf(ReportKind.assetRegister),
                  ),
                  _ReportTile(
                    key: const Key('report-balance'),
                    icon: Icons.table_rows_outlined,
                    title: proLabel(
                      context,
                      Feature.annualReports,
                      'Saldenliste (PDF)',
                    ),
                    subtitle: 'Summen je Kategorie, Anlagen, Umsatzsteuer',
                    enabled: !_busy,
                    onTap: () => _sharePdf(ReportKind.trialBalance),
                  ),
                  _ReportTile(
                    key: const Key('report-preliminary'),
                    icon: Icons.inventory_outlined,
                    title: proLabel(
                      context,
                      Feature.annualReports,
                      'Vorläufiger Jahresabschluss (Paket)',
                    ),
                    subtitle:
                        'PDF plus Belegliste und Buchungsexport als ZIP '
                        'für die Steuerberatung',
                    enabled: !_busy,
                    onTap: _sharePackage,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const NoticeBanner(
              icon: Icons.info_outline,
              message:
                  'Alle Berichte sind als VORLÄUFIG gekennzeichnet. Prüfen '
                  'und fertigstellen macht deine Steuerberatung.',
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    minVerticalPadding: 12,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.ios_share),
    enabled: enabled,
    onTap: onTap,
  );
}
