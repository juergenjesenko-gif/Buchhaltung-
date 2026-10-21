import 'dart:io';

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../domain/receipt.dart';
import '../../services/receipt_image_store.dart';
import '../../widgets/primary_action_bar.dart';
import '../pdf_viewer/pdf_viewer_screen.dart';
import 'receipt_edit_screen.dart';

/// Leseansicht eines gespeicherten Belegs. Antippen in der Belegliste zeigt
/// zuerst diese Ansicht; „Bearbeiten“ unten in der Daumenzone öffnet das
/// Formular. Gibt `true` zurück, wenn der Beleg im Formular geändert wurde.
class ReceiptViewScreen extends StatefulWidget {
  const ReceiptViewScreen({super.key, required this.receipt});

  final Receipt receipt;

  @override
  State<ReceiptViewScreen> createState() => _ReceiptViewScreenState();
}

class _ReceiptViewScreenState extends State<ReceiptViewScreen> {
  late Receipt _receipt = widget.receipt;
  bool _changed = false;
  List<File> _pages = const [];
  List<ReceiptDocument> _documents = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFiles());
  }

  Future<void> _loadFiles() async {
    final id = _receipt.id;
    if (id == null || !mounted) return;
    final repo = AppScope.read(context).repositories.receipts;
    final pages = await repo.pages(id);
    final documents = await repo.documents(id);
    // Belege vor Schema 8 ohne Seiteneintrag: das Einzelfoto zählt als Seite.
    final paths = pages.isEmpty && _receipt.hasImage
        ? [_receipt.imagePath!]
        : [for (final page in pages) page.imagePath];
    final files = <File>[];
    for (final path in paths) {
      final file = await ReceiptImageStore.resolve(path);
      if (file != null) files.add(file);
    }
    if (!mounted) return;
    setState(() {
      _pages = files;
      _documents = documents;
    });
  }

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ReceiptEditScreen(
          direction: _receipt.direction,
          existing: _receipt,
        ),
      ),
    );
    if (changed != true || !mounted) return;
    _changed = true;
    final fresh = await AppScope.read(
      context,
    ).repositories.receipts.byId(_receipt.id!);
    if (!mounted) return;
    // Im Formular gelöscht: zurück zur Liste, die neu lädt.
    if (fresh == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _receipt = fresh);
    await _loadFiles();
  }

  void _showPage(int index) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('Seite ${index + 1} von ${_pages.length}'),
            ),
            Flexible(
              child: InteractiveViewer(
                maxScale: 5,
                child: Image.file(_pages[index], fit: BoxFit.contain),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Schließen'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _viewDocument(ReceiptDocument doc) async {
    final file = await ReceiptImageStore.resolve(doc.filePath);
    if (file == null || !await file.exists() || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    await openPdfViewer(
      context,
      title: doc.fileName,
      fileName: doc.fileName,
      bytes: bytes,
    );
  }

  Widget _row(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final r = _receipt;
    final category = state.categoryById(r.categoryId)?.name ?? '';
    final partnerLabel = r.direction == BookingDirection.expense
        ? 'Lieferant'
        : 'Kunde';
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(r.direction.label)),
        body: ListView(
          key: const Key('receipt-view'),
          padding: const EdgeInsets.all(16),
          children: [
            if (r.isCancelled)
              Card(
                color: theme.colorScheme.errorContainer,
                child: ListTile(
                  leading: const Icon(Icons.block),
                  title: const Text('Storniert'),
                  subtitle: Text('am ${Fmt.date(r.cancelledAt!)}'),
                ),
              ),
            if (_pages.isNotEmpty)
              SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pages.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => InkWell(
                    key: Key('receipt-view-page-$i'),
                    onTap: () => _showPage(i),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _pages[i],
                        width: 120,
                        height: 160,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(
                          width: 120,
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            for (final doc in _documents)
              ListTile(
                contentPadding: EdgeInsets.zero,
                minTileHeight: 48,
                leading: const Icon(Icons.description_outlined),
                title: Text(doc.fileName),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _viewDocument(doc),
              ),
            const SizedBox(height: 12),
            Text(
              Fmt.money(r.gross),
              key: const Key('receipt-view-gross'),
              style: theme.textTheme.headlineMedium,
            ),
            if (r.isForeignCurrency && r.originalGross != null)
              Text('${Fmt.amount(r.originalGross!)} ${r.currency} laut Beleg'),
            const SizedBox(height: 12),
            _row(partnerLabel, r.counterparty),
            _row('Datum', Fmt.date(r.date)),
            _row('Beschreibung', r.description),
            _row('Kategorie', category),
            _row('Zahlungsart', r.paymentMethod.label),
            _row('Belegnummer', r.documentNumber),
            const Divider(height: 24),
            if (r.reverseCharge)
              _row('Steuer', 'Steuerschuld geht über (Reverse Charge)'),
            for (final line in r.lines) ...[
              _row('Steuersatz', Fmt.vatRate(line.vatPermille)),
              _row('Netto', Fmt.money(line.net)),
              _row('Steuer', Fmt.money(line.vat)),
              if (r.isSplit) _row('Brutto', Fmt.money(line.gross)),
              if (r.isSplit) const SizedBox(height: 8),
            ],
            if (r.note.trim().isNotEmpty) const Divider(height: 24),
            _row('Notiz', r.note),
          ],
        ),
        bottomNavigationBar: PrimaryActionBar(
          primary: PrimaryActionBar.filled(
            key: const Key('receipt-view-edit'),
            label: 'Bearbeiten',
            icon: Icons.edit,
            onPressed: _edit,
          ),
        ),
      ),
    );
  }
}
