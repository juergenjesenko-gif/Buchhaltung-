import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../domain/contract.dart';
import '../../domain/invoice.dart';
import '../../services/contracts/contract_csv.dart';
import '../../services/export/document_package.dart';
import '../../services/receipt_image_store.dart';
import '../../services/share_service.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/common.dart';
import '../../widgets/primary_action_bar.dart';
import '../contracts/contract_screens.dart';
import '../help/help_screen.dart';
import '../invoices/invoice_share.dart';

/// Zeitraumart für den ZIP-Export.
enum _Span { month, quarter, year, custom }

/// Belege und Rechnungen eines Zeitraums als eine ZIP-Datei teilen.
/// Standard: laufendes Jahr, dann genügt ein Tipp auf „ZIP teilen“.
class DocumentZipScreen extends StatefulWidget {
  const DocumentZipScreen({super.key});

  @override
  State<DocumentZipScreen> createState() => _DocumentZipScreenState();
}

class _DocumentZipScreenState extends State<DocumentZipScreen> {
  final _now = DateTime.now();
  _Span _span = _Span.year;

  /// Index in der Auswahlliste (0 = laufender Zeitraum).
  int _choice = 0;
  late DateTime _from = DateTime(_now.year, 1, 1);
  late DateTime _to = DateTime(_now.year, 12, 31);
  bool _busy = false;

  List<Period> get _choices => switch (_span) {
    _Span.month => [
      for (var i = 0; i < 24; i++)
        Period.month(DateTime(_now.year, _now.month - i, 1)),
    ],
    _Span.quarter => [
      for (var i = 0; i < 8; i++)
        () {
          final q = (_now.month - 1) ~/ 3 - i;
          final year = _now.year + (q < 0 ? (q - 3) ~/ 4 : 0);
          return Period.quarter(year, q % 4 + 1);
        }(),
    ],
    _Span.year => [for (var i = 0; i < 8; i++) Period.year(_now.year - i)],
    _Span.custom => const [],
  };

  Period get _period => _span == _Span.custom
      ? Period(_from, _to, '${Fmt.date(_from)} – ${Fmt.date(_to)}')
      : _choices[_choice];

  Future<void> _pick(bool start) async {
    final d = await showDatePicker(
      context: context,
      initialDate: start ? _from : _to,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    setState(() {
      if (start) {
        _from = d;
        if (_to.isBefore(d)) _to = d;
      } else {
        _to = d;
        if (_from.isAfter(d)) _from = d;
      }
    });
  }

  Future<void> _share() async {
    final state = AppScope.read(context);
    final profile = state.profile;
    if (profile == null) return;
    final period = _period;
    setState(() => _busy = true);
    try {
      final repos = state.repositories;
      final receipts = await repos.receipts.query(
        from: period.from,
        to: period.to,
      );
      final files = <ReceiptFile>[];
      for (final r in receipts) {
        final id = r.id;
        if (id == null) continue;
        final pages = [
          for (final p in await repos.receipts.pages(id)) p.imagePath,
        ];
        if (pages.isEmpty && r.hasImage) pages.add(r.imagePath!);
        for (var i = 0; i < pages.length; i++) {
          final f = await ReceiptImageStore.resolve(pages[i]);
          if (f == null) continue;
          files.add(
            ReceiptFile(
              receipt: r,
              page: i + 1,
              extension: DocumentPackage.extensionOf(pages[i]),
              bytes: await f.readAsBytes(),
            ),
          );
        }
        for (final doc in await repos.receipts.documents(id)) {
          final f = await ReceiptImageStore.resolve(doc.filePath);
          if (f == null) continue;
          files.add(
            ReceiptFile(
              receipt: r,
              extension: DocumentPackage.extensionOf(doc.fileName),
              bytes: await f.readAsBytes(),
            ),
          );
        }
      }
      final last = DateTime(period.to.year, period.to.month, period.to.day + 1);
      final invoices = [
        for (final i in await repos.invoices.all())
          if (i.status != InvoiceStatus.draft &&
              !i.issueDate.isBefore(period.from) &&
              i.issueDate.isBefore(last))
            i,
      ]..sort((a, b) => a.issueDate.compareTo(b.issueDate));
      final customers = {for (final c in await repos.customers.all()) c.id: c};
      final names = <int, String>{};
      final pdfs = <int, Uint8List>{};
      for (final i in invoices) {
        final customer = customers[i.customerId];
        if (customer == null || i.id == null) continue;
        names[i.customerId] = customer.name;
        if (!mounted) return;
        pdfs[i.id!] = (await buildInvoicePdf(state, i, customer, profile)).$1;
      }
      if (receipts.isEmpty && invoices.isEmpty) {
        if (mounted) {
          showSnack(
            context,
            'Im Zeitraum gibt es keine Belege oder Rechnungen.',
          );
        }
        return;
      }
      final zip = DocumentPackage.receiptsAndInvoices(
        receipts: receipts,
        receiptFiles: files,
        invoices: invoices,
        customerNames: names,
        invoicePdfs: pdfs,
      );
      await ShareService.shareZip(
        fileName:
            'Belege_Rechnungen_${Fmt.isoDate(period.from)}_'
            '${Fmt.isoDate(period.to)}.zip',
        bytes: zip,
        subject:
            'Belege und Rechnungen ${period.label} – ${profile.companyName}',
      );
    } on Exception catch (error) {
      if (mounted) {
        showSnack(context, 'ZIP konnte nicht erstellt werden: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final choices = _choices;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Belege & Rechnungen als ZIP'),
        actions: const [HelpButton()],
      ),
      bottomNavigationBar: PrimaryActionBar(
        primary: PrimaryActionBar.filled(
          key: const Key('zip-share'),
          label: 'ZIP teilen',
          icon: Icons.ios_share,
          busy: _busy,
          onPressed: _share,
        ),
      ),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            SectionCard(
              title: 'Zeitraum',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (span, label) in [
                        (_Span.month, 'Monat'),
                        (_Span.quarter, 'Quartal'),
                        (_Span.year, 'Jahr'),
                        (_Span.custom, 'Von – bis'),
                      ])
                        ChoiceChip(
                          key: Key('zip-span-${span.name}'),
                          label: Text(label),
                          selected: _span == span,
                          onSelected: (_) => setState(() {
                            _span = span;
                            _choice = 0;
                          }),
                        ),
                    ],
                  ),
                  if (_span == _Span.custom) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      minVerticalPadding: 12,
                      title: const Text('Von'),
                      subtitle: Text(Fmt.date(_from)),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: () => _pick(true),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      minVerticalPadding: 12,
                      title: const Text('Bis'),
                      subtitle: Text(Fmt.date(_to)),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: () => _pick(false),
                    ),
                  ] else
                    DropdownButtonFormField<int>(
                      key: ValueKey(_span),
                      isExpanded: true,
                      initialValue: _choice,
                      decoration: const InputDecoration(labelText: 'Zeitraum'),
                      items: [
                        for (var i = 0; i < choices.length; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(choices[i].label),
                          ),
                      ],
                      onChanged: (v) => setState(() => _choice = v ?? 0),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const NoticeBanner(
              icon: Icons.folder_zip_outlined,
              message:
                  'Im ZIP: Belegfotos und -PDFs (Datum_Partner_Betrag), die '
                  'Rechnungs-PDFs und je eine CSV-Übersicht der Belege und '
                  'Rechnungen. Die Datei verlässt das Gerät nur über den '
                  'Teilen-Dialog.',
            ),
          ],
        ),
      ),
    );
  }
}

/// Verträge exportieren (aus der Export-Seite): Liste mit Fristen als CSV
/// oder alle Vertragsdokumente als ZIP; dazu der Weg zur Vertragsübersicht.
Future<void> showContractExportSheet(BuildContext context) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const Key('contracts-export-zip'),
            minVerticalPadding: 12,
            leading: const Icon(Icons.folder_zip_outlined),
            title: const Text('Alle Verträge als ZIP'),
            subtitle: const Text('Liste mit Fristen (CSV), Seiten und PDFs'),
            onTap: () => Navigator.pop(ctx, 'zip'),
          ),
          ListTile(
            key: const Key('contracts-export-select'),
            minVerticalPadding: 12,
            leading: const Icon(Icons.checklist_outlined),
            title: const Text('Verträge auswählen und als ZIP'),
            subtitle: const Text('Nur die angehakten Verträge'),
            onTap: () => Navigator.pop(ctx, 'select'),
          ),
          ListTile(
            key: const Key('contracts-export-csv'),
            minVerticalPadding: 12,
            leading: const Icon(Icons.table_view_outlined),
            title: const Text('Vertragsliste mit Fristen (CSV)'),
            onTap: () => Navigator.pop(ctx, 'csv'),
          ),
          const Divider(height: 16),
          ListTile(
            key: const Key('contracts-open-list'),
            minVerticalPadding: 12,
            leading: const Icon(Icons.description_outlined),
            title: const Text('Verträge ansehen'),
            onTap: () => Navigator.pop(ctx, 'list'),
          ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  if (action == 'list') {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ContractListScreen()));
    return;
  }
  final state = AppScope.read(context);
  try {
    var contracts = await state.repositories.contracts.all();
    if (contracts.isEmpty) {
      if (context.mounted) showSnack(context, 'Noch keine Verträge abgelegt.');
      return;
    }
    if (action == 'select') {
      if (!context.mounted) return;
      final chosen = await _pickContracts(context, contracts);
      if (chosen == null || chosen.isEmpty) return;
      contracts = [
        for (var i = 0; i < contracts.length; i++)
          if (chosen.contains(i)) contracts[i],
      ];
    }
    final company = state.profile?.companyName ?? '';
    if (action == 'csv') {
      await ShareService.shareCsv(
        fileName: 'Vertraege.csv',
        content: ContractCsv.build(contracts),
        subject: 'Verträge mit Fristen – $company',
      );
      return;
    }
    final bytes = <String, Uint8List>{};
    for (final c in contracts) {
      for (final path in [...c.pages, ?c.originalPath]) {
        final f = await ReceiptImageStore.resolve(path);
        if (f != null) bytes[path] = await f.readAsBytes();
      }
    }
    await ShareService.shareZip(
      fileName: 'Vertraege_${Fmt.isoDate(DateTime.now())}.zip',
      bytes: DocumentPackage.contracts(contracts, bytes),
      subject: 'Verträge – $company',
    );
  } on Exception catch (error) {
    if (context.mounted) showSnack(context, 'Export fehlgeschlagen: $error');
  }
}

/// Auswahl der Verträge für den ZIP-Export (Rückmeldung 2026-10-21):
/// Liste zum Anhaken, Knopf unten in der Daumenzone. Liefert die Indizes.
Future<Set<int>?> _pickContracts(
  BuildContext context,
  List<Contract> contracts,
) => showModalBottomSheet<Set<int>>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (ctx) {
    final selected = <int>{};
    return StatefulBuilder(
      builder: (ctx, setState) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Verträge auswählen',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (var i = 0; i < contracts.length; i++)
                      CheckboxListTile(
                        key: Key('contract-pick-$i'),
                        value: selected.contains(i),
                        title: Text(
                          contracts[i].title.isEmpty
                              ? contracts[i].type.label
                              : contracts[i].title,
                        ),
                        subtitle: contracts[i].partner.isEmpty
                            ? null
                            : Text(contracts[i].partner),
                        onChanged: (v) => setState(
                          () =>
                              v == true ? selected.add(i) : selected.remove(i),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton.icon(
                  key: const Key('contract-pick-confirm'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.pop(ctx, selected),
                  icon: const Icon(Icons.folder_zip_outlined),
                  label: Text(
                    selected.isEmpty
                        ? 'Verträge anhaken'
                        : '${selected.length} als ZIP teilen',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  },
);
