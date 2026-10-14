import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../domain/customer.dart';
import '../../domain/invoice.dart';
import '../../domain/money.dart';
import '../../theme.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/common.dart';
import 'customer_edit_screen.dart';
import 'invoice_edit_screen.dart';
import 'invoice_share.dart';
import '../help/help_screen.dart';
import '../../services/help/help_index.dart';

/// Rechnungsübersicht mit PDF-Versand und Zahlungsstatus.
class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  List<Invoice> _invoices = const [];
  Map<int, Customer> _customers = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final state = AppScope.read(context);
    final invoices = await state.repositories.invoices.all();
    final customers = await state.repositories.customers.all();
    if (!mounted) return;
    setState(() {
      _invoices = invoices;
      _customers = {
        for (final customer in customers)
          if (customer.id != null) customer.id!: customer,
      };
      _loading = false;
    });
  }

  Money get _openAmount => _invoices
      .where((invoice) => invoice.status == InvoiceStatus.issued)
      .map((invoice) => invoice.grossTotal)
      .fold(const Money.zero(), (a, b) => a + b);

  Future<void> _openEditor([Invoice? invoice]) async {
    final changed = await ListDetail.open<bool>(
      context,
      (_) => InvoiceEditScreen(existing: invoice),
    );
    // Auch nach dem Ausstellen im Formular (ohne Rückgabewert) neu laden.
    if (changed != false) await _load();
  }

  Future<void> _sharePdf(Invoice invoice) => shareInvoicePdf(context, invoice);

  /// Stornieren und Löschen nur nach Bestätigung mit Nummer und Betrag.
  Future<bool> _confirmDestructive(Invoice invoice, String verb) async {
    final error = Theme.of(context).colorScheme.error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${invoice.status == InvoiceStatus.draft ? 'Entwurf' : invoice.number} $verb?',
        ),
        content: Text(
          '${invoice.status == InvoiceStatus.draft ? 'Entwurf' : 'Rechnung ${invoice.number}'} '
          'über ${Fmt.money(invoice.grossTotal)}. Das lässt sich nicht rückgängig machen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            key: const Key('confirmDestructive'),
            style: FilledButton.styleFrom(backgroundColor: error),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(verb),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _setStatus(Invoice invoice, InvoiceStatus status) async {
    final id = invoice.id;
    if (id == null) return;
    final state = AppScope.read(context);
    if (status == InvoiceStatus.paid) {
      final answer = await _askPayment(invoice);
      if (answer == null) return;
      await state.repositories.invoices.markPaid(
        id,
        answer.date,
        withSkonto: answer.withSkonto,
      );
    } else {
      if (status == InvoiceStatus.cancelled &&
          !await _confirmDestructive(invoice, 'Stornieren')) {
        return;
      }
      await state.repositories.invoices.setStatus(id, status);
    }
    await state.onBookingsChanged();
    await _load();
  }

  /// Zahlungseingang erfragen: vorbelegt mit heute, ein Tipp bestätigt
  /// (Leitprinzip: Vorschlag statt Pflicht). Die Einnahme zählt am Tag des
  /// Zahlungseingangs (Zuflussprinzip).
  ///
  /// Hat die Rechnung Skonto, fragt der Dialog „Mit Skonto bezahlt?“ – ein
  /// Tipp (L-3.24); vorbelegt mit Ja, solange die Skontofrist läuft.
  Future<({DateTime date, bool withSkonto})?> _askPayment(
    Invoice invoice,
  ) async {
    final today = DateTime.now();
    var date = DateTime(today.year, today.month, today.day);
    bool inTime(DateTime day) =>
        invoice.hasSkonto && !day.isAfter(invoice.skontoDate!);
    var withSkonto = inTime(date);
    return showModalBottomSheet<({DateTime date, bool withSkonto})>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${invoice.number} bezahlt',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Zahlungseingang'),
                  subtitle: Text(Fmt.date(date)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: invoice.issueDate.subtract(
                        const Duration(days: 366),
                      ),
                      lastDate: DateTime(today.year + 1, 12, 31),
                    );
                    if (picked != null) {
                      setSheetState(() {
                        date = picked;
                        withSkonto = inTime(picked);
                      });
                    }
                  },
                ),
                if (invoice.hasSkonto)
                  SwitchListTile(
                    key: const Key('paidWithSkonto'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mit Skonto bezahlt?'),
                    subtitle: Text(
                      '${Fmt.vatRate(invoice.skontoPermille)} = '
                      '${Fmt.money(invoice.skontoAmount)}, '
                      'Frist bis ${Fmt.date(invoice.skontoDate!)}',
                    ),
                    value: withSkonto,
                    onChanged: (value) =>
                        setSheetState(() => withSkonto = value),
                  ),
                const SizedBox(height: 8),
                Text(
                  '${Fmt.money(withSkonto ? invoice.grossTotal - invoice.skontoAmount : invoice.grossTotal)} '
                  'werden als Einnahme am Tag des Zahlungseingangs gebucht. '
                  'Bitte nicht zusätzlich als Einnahmebeleg erfassen.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('confirmPaid'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: () => Navigator.of(
                    context,
                  ).pop((date: date, withSkonto: withSkonto)),
                  child: const Text('Als bezahlt buchen'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteDraft(Invoice invoice) async {
    final id = invoice.id;
    if (id == null) return;
    if (!await _confirmDestructive(invoice, 'Löschen')) return;
    if (!mounted) return;
    final deleted = await AppScope.read(
      context,
    ).repositories.invoices.deleteDraft(id);
    if (!mounted) return;
    if (!deleted) {
      showSnack(context, 'Nur Entwürfe können gelöscht werden.');
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rechnungen'),
        actions: [
          const HelpButton(context: HelpTopic.invoices),
          IconButton(
            tooltip: 'Kunden',
            icon: const Icon(Icons.people_outline),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ListDetail(
                    list: _CustomerListScreen(),
                    placeholder: 'Wähle links einen Kunden aus.',
                  ),
                ),
              );
              await _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
          ? EmptyState(
              icon: Icons.description_outlined,
              title: 'Keine Rechnungen',
              message:
                  'Schreibe deine erste Rechnung – die Pflichtangaben '
                  'prüft die App für dich mit.',
              action: FilledButton.icon(
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add),
                label: const Text('Rechnung schreiben'),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  if (!_openAmount.isZero) ...[
                    SectionCard(
                      title: 'Offen',
                      child: LabeledValue(
                        label: 'Gestellt und noch nicht bezahlt',
                        value: Fmt.money(_openAmount),
                        emphasize: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  for (final invoice in _invoices)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _InvoiceTile(
                        invoice: invoice,
                        customer: _customers[invoice.customerId],
                        onTap: () => _openEditor(invoice),
                        onShare: () => _sharePdf(invoice),
                        onMarkPaid: invoice.status == InvoiceStatus.issued
                            ? () => _setStatus(invoice, InvoiceStatus.paid)
                            : null,
                        onCancel: invoice.status == InvoiceStatus.issued
                            ? () => _setStatus(invoice, InvoiceStatus.cancelled)
                            : null,
                        onDelete: invoice.status == InvoiceStatus.draft
                            ? () => _deleteDraft(invoice)
                            : null,
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        tooltip: 'Rechnung schreiben',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({
    required this.invoice,
    required this.customer,
    required this.onTap,
    required this.onShare,
    this.onMarkPaid,
    this.onCancel,
    this.onDelete,
  });

  final Invoice invoice;
  final Customer? customer;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (statusColor, statusLabel) = switch (invoice.status) {
      InvoiceStatus.draft => (scheme.outline, 'Entwurf'),
      InvoiceStatus.issued =>
        invoice.isOverdue
            ? (AppTheme.expense, 'Überfällig')
            : (AppTheme.warning, 'Offen'),
      InvoiceStatus.paid => (AppTheme.income, 'Bezahlt'),
      InvoiceStatus.cancelled => (scheme.outline, 'Storniert'),
    };

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      invoice.status == InvoiceStatus.draft
                          ? 'Entwurf'
                          : invoice.number,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                customer?.name ?? 'Unbekannter Kunde',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 2),
              Text(
                [
                  Fmt.date(invoice.issueDate),
                  if (invoice.dueDate != null)
                    'fällig ${Fmt.date(invoice.dueDate!)}',
                  '${invoice.items.length} ${invoice.items.length == 1 ? 'Position' : 'Positionen'}',
                ].join(' · '),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    Fmt.money(invoice.grossTotal),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (onMarkPaid != null) ...[
                    FilledButton.tonalIcon(
                      key: Key('paid-${invoice.id}'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: onMarkPaid,
                      icon: const Icon(Icons.check),
                      label: const Text('Bezahlt'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  IconButton(
                    tooltip: 'PDF teilen',
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    onPressed: onShare,
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Weitere Aktionen',
                    itemBuilder: (context) {
                      final error = TextStyle(color: scheme.error);
                      return [
                        if (onMarkPaid != null)
                          const PopupMenuItem(
                            value: 'paid',
                            child: Text('Als bezahlt markieren'),
                          ),
                        if (onCancel != null || onDelete != null)
                          const PopupMenuDivider(),
                        if (onCancel != null)
                          PopupMenuItem(
                            value: 'cancel',
                            child: Text('Stornieren', style: error),
                          ),
                        if (onDelete != null)
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Entwurf löschen', style: error),
                          ),
                      ];
                    },
                    onSelected: (value) => switch (value) {
                      'paid' => onMarkPaid?.call(),
                      'cancel' => onCancel?.call(),
                      'delete' => onDelete?.call(),
                      _ => null,
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kundenverwaltung.
class _CustomerListScreen extends StatefulWidget {
  const _CustomerListScreen();

  @override
  State<_CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<_CustomerListScreen> {
  List<Customer> _customers = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final customers = await AppScope.read(context).repositories.customers.all();
    if (!mounted) return;
    setState(() {
      _customers = customers;
      _loading = false;
    });
  }

  Future<void> _open([Customer? customer]) async {
    await ListDetail.open<void>(
      context,
      (_) => CustomerEditScreen(existing: customer),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kunden')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _customers.isEmpty
          ? EmptyState(
              icon: Icons.people_outline,
              title: 'Keine Kunden',
              message:
                  'Lege deine Kunden einmal an – danach genügt beim '
                  'Rechnungschreiben ein Tipp.',
              action: FilledButton.icon(
                onPressed: () => _open(),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Kunde anlegen'),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: _customers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final customer = _customers[index];
                return ListTile(
                  title: Text(customer.name),
                  subtitle: Text(
                    [
                      if (customer.street.isNotEmpty) customer.street,
                      [
                        customer.postalCode,
                        customer.city,
                      ].where((s) => s.isNotEmpty).join(' '),
                    ].where((s) => s.isNotEmpty).join(', '),
                  ),
                  trailing: customer.hasCompleteAddress
                      ? const Icon(Icons.chevron_right)
                      : const Icon(Icons.warning_amber_rounded, size: 20),
                  onTap: () => _open(customer),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _open(),
        child: const Icon(Icons.person_add_alt),
      ),
    );
  }
}
