import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../licensing/feature_gate.dart';
import '../../core/formatting.dart';
import '../../domain/customer.dart';
import '../../domain/invoice.dart';
import '../../domain/money.dart';
import '../../theme.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/common.dart';
import '../articles/article_screens.dart';
import '../offers/offer_screens.dart';
import 'customer_edit_screen.dart';
import 'invoice_edit_screen.dart';
import 'invoice_share.dart';
import 'dunning_sheet.dart';
import '../../services/dunning_service.dart';
import '../../domain/dunning.dart';
import '../help/help_screen.dart';
import '../../services/help/help_index.dart';
import '../../services/invoice_cancellation.dart';
import '../../services/invoice_numbering.dart';

/// Rechnungsübersicht mit PDF-Versand und Zahlungsstatus.
class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  List<Invoice> _invoices = const [];
  Map<int, Customer> _customers = const {};

  /// Letztes nicht storniertes Mahnschreiben je Rechnung (L-3.10).
  Map<int, DunningNotice> _dunning = const {};
  bool _loading = true;

  int? _loadedRevision;

  /// Lebt im `IndexedStack` der Startseite weiter: neu laden, sobald sich
  /// [AppState.bookingsRevision] ändert – auch beim Wechsel in die Demo und
  /// zurück (Rückmeldung 2026-10-19: Demo zeigte hier echte bzw. keine Daten).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = AppScope.of(context).bookingsRevision;
    if (revision == _loadedRevision) return;
    _loadedRevision = revision;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final state = AppScope.read(context);
    final invoices = await state.repositories.invoices.all();
    final customers = await state.repositories.customers.all();
    final dunning = await state.repositories.dunning.latestActive();
    if (!mounted) return;
    setState(() {
      _invoices = invoices;
      _dunning = dunning;
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

  /// Überfällig nach der maßgeblichen Frist: nach einer Erinnerung oder
  /// Mahnung erst wieder, wenn deren neue Frist abgelaufen ist.
  bool _needsReminder(Invoice invoice) => DunningService.needsReminder(
    invoice,
    _dunning[invoice.id],
    DateTime.now(),
  );

  /// Nummer der Gegenrechnung: bei der Stornorechnung das Original, beim
  /// stornierten Original die Stornorechnung.
  String? _relatedNumber(Invoice invoice) {
    if (invoice.isCancellation) return invoice.cancelsNumber;
    final by = invoice.cancelledByInvoiceId;
    if (by == null) return null;
    return _invoices.where((i) => i.id == by).firstOrNull?.number;
  }

  List<Invoice> get _overdue => _invoices.where(_needsReminder).toList();

  /// Mahnverlauf einer Rechnung als Bottom-Sheet.
  Future<void> _showDunningHistory(Invoice invoice) async {
    final notices = await AppScope.read(
      context,
    ).repositories.dunning.forInvoice(invoice.id!);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          key: const Key('dunningHistory'),
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              'Mahnverlauf ${invoice.number}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (invoice.dueDate != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: Text('Rechnung vom ${Fmt.date(invoice.issueDate)}'),
                subtitle: Text('fällig ${Fmt.date(invoice.dueDate!)}'),
              ),
            for (final notice in notices)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  notice.isCancelled
                      ? Icons.block
                      : Icons.mark_email_read_outlined,
                ),
                title: Text(
                  '${notice.title} vom ${Fmt.date(notice.issuedOn)}',
                  style: notice.isCancelled
                      ? const TextStyle(decoration: TextDecoration.lineThrough)
                      : null,
                ),
                subtitle: Text(
                  notice.isCancelled
                      ? 'Storniert: ${notice.cancelReason}'
                      : '${Fmt.money(notice.total)}, neue Frist '
                            '${Fmt.date(notice.newDueDate)}',
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Zahlungserinnerung bzw. Mahnung (L-3.10): Sheet mit Vorschau, ein Tipp
  /// auf „erstellen und senden“ öffnet den Teilen-Dialog.
  Future<void> _remind(Invoice invoice) async {
    final customer = _customers[invoice.customerId];
    if (customer == null || AppScope.read(context).profile == null) {
      showSnack(context, 'Kundendaten fehlen.');
      return;
    }
    final changed = await showDunningSheet(
      context,
      invoice: invoice,
      customer: customer,
    );
    if (changed) await _load();
  }

  Future<void> _setStatus(Invoice invoice, InvoiceStatus status) async {
    final id = invoice.id;
    if (id == null) return;
    // Demo (FA-13.14): nichts speichern.
    if (!await ensureWritable(context)) return;
    if (!mounted) return;

    final state = AppScope.read(context);
    if (status == InvoiceStatus.paid) {
      final answer = await _askPayment(invoice);
      if (answer == null) return;
      await state.repositories.invoices.markPaid(
        id,
        answer.date,
        withSkonto: answer.withSkonto,
        withDunningCosts: answer.withCosts,
      );
    } else {
      await state.repositories.invoices.setStatus(id, status);
    }
    await state.onBookingsChanged();
    await _load();
  }

  /// Storno mit eigener Stornorechnung (L-3.7). Mit [correct] entsteht
  /// danach in einem Zug ein neuer Entwurf als Kopie, der sich gleich
  /// öffnet („Korrigieren“). Ersetzt die frühere reine Statusänderung.
  Future<void> _cancelInvoice(Invoice invoice, {bool correct = false}) async {
    final id = invoice.id;
    final state = AppScope.read(context);
    final profile = state.profile;
    if (id == null || profile == null) return;
    // Demo (FA-13.14): nichts speichern.
    if (!await ensureWritable(context)) return;
    if (!mounted) return;
    final answer = await _askCancellation(invoice, correct: correct);
    if (answer == null || !mounted) return;
    final stornoId = await state.repositories.invoices.cancelWithInvoice(
      id,
      reason: answer.reason,
      date: answer.date,
      refundDate: answer.date,
      assignNumber: (sequence) => InvoiceNumbering.format(
        pattern: profile.invoiceNumberPattern,
        sequence: sequence,
        date: answer.date,
      ),
    );
    await state.reload();
    await state.onBookingsChanged();
    final storno = await state.repositories.invoices.byId(stornoId);
    if (correct) {
      final draft = InvoiceCancellation.correctionDraft(
        invoice,
        DateTime.now(),
      );
      final draftId = await state.repositories.invoices.save(draft);
      final saved = await state.repositories.invoices.byId(draftId);
      await _load();
      if (!mounted || saved == null) return;
      await _openEditor(saved);
    } else {
      await _load();
    }
    if (!mounted || storno == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Stornorechnung ${storno.number} erstellt.'),
          action: SnackBarAction(
            label: 'Ansehen',
            onPressed: () => _sharePdf(storno),
          ),
        ),
      );
  }

  /// Grund und Datum des Stornos: Vorschläge mit einem Tipp, Datum
  /// vorbelegt mit heute. Bei bezahlter Rechnung ist das Datum zugleich der
  /// Tag der Rückzahlung (Ist-Prinzip). Der Gefahrenknopf steht unten über
  /// die volle Breite, getrennt vom Abbrechen (DESIGN_SPEC 5a).
  Future<({String reason, DateTime date})?> _askCancellation(
    Invoice invoice, {
    required bool correct,
  }) {
    final today = DateTime.now();
    var date = DateTime(today.year, today.month, today.day);
    final reason = TextEditingController(
      text: InvoiceCancellation.reasonSuggestions.first,
    );
    final paid = invoice.status == InvoiceStatus.paid;
    final error = Theme.of(context).colorScheme.error;
    return showModalBottomSheet<({String reason, DateTime date})>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    correct
                        ? '${invoice.number} korrigieren'
                        : '${invoice.number} stornieren',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Die App erstellt eine Stornorechnung mit eigener Nummer '
                    'über ${Fmt.money(-invoice.grossTotal)}. Die Rechnung '
                    '${invoice.number} bleibt unverändert erhalten und wird '
                    'als storniert markiert.'
                    '${correct ? ' Danach öffnet sich eine Kopie als neuer Entwurf.' : ''}',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final suggestion
                          in InvoiceCancellation.reasonSuggestions)
                        ChoiceChip(
                          label: Text(suggestion),
                          materialTapTargetSize: MaterialTapTargetSize.padded,
                          selected: reason.text == suggestion,
                          onSelected: (_) =>
                              setSheetState(() => reason.text = suggestion),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('cancelReason'),
                    controller: reason,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Grund (steht auf der Stornorechnung)',
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: Text(
                      paid ? 'Storno und Rückzahlung am' : 'Storno am',
                    ),
                    subtitle: Text(Fmt.date(date)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: invoice.issueDate,
                        lastDate: DateTime(today.year + 1, 12, 31),
                      );
                      if (picked != null) setSheetState(() => date = picked);
                    },
                  ),
                  Text(
                    paid
                        ? 'Die Rechnung ist bezahlt: ${Fmt.money(invoice.grossTotal - invoice.skontoTaken)} '
                              'werden an diesem Tag als Rückzahlung gebucht '
                              '(Einnahme und Umsatzsteuer sinken). Überweise '
                              'den Betrag an den Kunden zurück.'
                        : 'Die Rechnung ist offen: es wird nichts gebucht. '
                              'Laufende Mahnungen werden mit storniert.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('confirmCancellation'),
                    style: FilledButton.styleFrom(
                      backgroundColor: error,
                      minimumSize: const Size.fromHeight(56),
                    ),
                    onPressed: reason.text.trim().isEmpty
                        ? null
                        : () => Navigator.of(
                            context,
                          ).pop((reason: reason.text.trim(), date: date)),
                    child: Text(
                      correct
                          ? 'Stornieren und neu schreiben'
                          : 'Stornorechnung erstellen',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Zahlungseingang erfragen: vorbelegt mit heute, ein Tipp bestätigt
  /// (Leitprinzip: Vorschlag statt Pflicht). Die Einnahme zählt am Tag des
  /// Zahlungseingangs (Zuflussprinzip).
  ///
  /// Hat die Rechnung Skonto, fragt der Dialog „Mit Skonto bezahlt?“ – ein
  /// Tipp (L-3.24); vorbelegt mit Ja, solange die Skontofrist läuft.
  Future<({DateTime date, bool withSkonto, bool withCosts})?> _askPayment(
    Invoice invoice,
  ) async {
    final today = DateTime.now();
    var date = DateTime(today.year, today.month, today.day);
    bool inTime(DateTime day) =>
        invoice.hasSkonto && !day.isAfter(invoice.skontoDate!);
    var withSkonto = inTime(date);
    final notice = _dunning[invoice.id];
    final costs = notice?.costs ?? const Money.zero();
    var withCosts = !costs.isZero;
    return showModalBottomSheet<
      ({DateTime date, bool withSkonto, bool withCosts})
    >(
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
                if (!costs.isZero)
                  SwitchListTile(
                    key: const Key('paidWithCosts'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mahnkosten und Zinsen mitbezahlt?'),
                    subtitle: Text(
                      '${Fmt.money(costs)} aus der ${notice!.title}, '
                      'nicht umsatzsteuerbar',
                    ),
                    value: withCosts,
                    onChanged: (value) =>
                        setSheetState(() => withCosts = value),
                  ),
                const SizedBox(height: 8),
                Text(
                  '${Fmt.money((withSkonto ? invoice.grossTotal - invoice.skontoAmount : invoice.grossTotal) + (withCosts ? costs : const Money.zero()))} '
                  'werden als Einnahme am Tag des Zahlungseingangs gebucht. '
                  'Bitte nicht zusätzlich als Einnahmebeleg erfassen.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('confirmPaid'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: () => Navigator.of(context).pop((
                    date: date,
                    withSkonto: withSkonto,
                    withCosts: withCosts,
                  )),
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
      body: Column(
        children: [
          _CatalogShortcuts(onReturn: _load),
          Expanded(child: _body()),
        ],
      ),
      // Zentriert und beschriftet, mit beiden Daumen erreichbar
      // (DESIGN_SPEC 5a, Regel 1 und 9).
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('invoice-new'),
        heroTag: 'invoice-new',
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Neue Rechnung'),
      ),
    );
  }

  Widget _body() {
    return _loading
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
                if (_overdue.isNotEmpty) ...[
                  NoticeBanner(
                    key: const Key('overdueBanner'),
                    icon: Icons.notification_important_outlined,
                    color: AppTheme.expense,
                    message: _overdue.length == 1
                        ? '1 Rechnung überfällig – mahnen?'
                        : '${_overdue.length} Rechnungen überfällig – mahnen?',
                    onTap: () => _remind(_overdue.first),
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
                      dunning: _dunning[invoice.id],
                      overdue: _needsReminder(invoice),
                      onDunningHistory: () => _showDunningHistory(invoice),
                      onRemind: _needsReminder(invoice)
                          ? () => _remind(invoice)
                          : null,
                      onCancel: invoice.status.canBeCancelled
                          ? () => _cancelInvoice(invoice)
                          : null,
                      onCorrect: invoice.status.canBeCancelled
                          ? () => _cancelInvoice(invoice, correct: true)
                          : null,
                      relatedNumber: _relatedNumber(invoice),
                      onDelete: invoice.status == InvoiceStatus.draft
                          ? () => _deleteDraft(invoice)
                          : null,
                    ),
                  ),
              ],
            ),
          );
  }
}

/// Angebote und Artikel, je ein Tipp von der Rechnungsliste (FA-5.40,
/// FA-5.44). Zwei gleich breite Knöpfe mit 48 dp Höhe.
class _CatalogShortcuts extends StatelessWidget {
  const _CatalogShortcuts({required this.onReturn});

  final Future<void> Function() onReturn;

  Future<void> _push(BuildContext context, Widget screen) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => screen));
    await onReturn();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('open-offers'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => _push(context, const OfferListScreen()),
            icon: const Icon(Icons.request_quote_outlined),
            label: const Text('Angebote'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('open-articles'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => _push(context, const ArticleListScreen()),
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('Artikel'),
          ),
        ),
      ],
    ),
  );
}

class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({
    required this.invoice,
    required this.customer,
    required this.onTap,
    required this.onShare,
    this.onMarkPaid,
    this.onRemind,
    this.dunning,
    this.overdue = false,
    this.onDunningHistory,
    this.onCancel,
    this.onCorrect,
    this.relatedNumber,
    this.onDelete,
  });

  final Invoice invoice;
  final Customer? customer;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onRemind;
  final DunningNotice? dunning;

  /// Maßgebliche Frist abgelaufen (nach Mahnung: deren neue Frist).
  final bool overdue;
  final VoidCallback? onDunningHistory;
  final VoidCallback? onCancel;
  final VoidCallback? onCorrect;

  /// „Storno zu …“ bzw. „storniert durch …“.
  final String? relatedNumber;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (statusColor, statusLabel) = switch (invoice.status) {
      InvoiceStatus.draft => (scheme.outline, 'Entwurf'),
      InvoiceStatus.issued =>
        overdue
            ? (AppTheme.expense, 'Überfällig')
            : (AppTheme.warning, 'Offen'),
      InvoiceStatus.paid => (AppTheme.income, 'Bezahlt'),
      InvoiceStatus.cancelled => (scheme.outline, 'Storniert'),
      InvoiceStatus.cancellation => (scheme.outline, 'Storno'),
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
              if (relatedNumber != null) ...[
                const SizedBox(height: 2),
                Text(
                  invoice.isCancellation
                      ? 'Storno zu $relatedNumber'
                      : 'storniert durch $relatedNumber',
                  key: Key('related-${invoice.id}'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (dunning != null) ...[
                const SizedBox(height: 4),
                _DunningBadge(
                  key: Key('dunning-badge-${invoice.id}'),
                  notice: dunning!,
                  overdue: overdue,
                  onTap: onDunningHistory,
                ),
              ],
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
                        if (onCorrect != null)
                          const PopupMenuItem(
                            value: 'correct',
                            child: Text('Korrigieren'),
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
                      'correct' => onCorrect?.call(),
                      'cancel' => onCancel?.call(),
                      'delete' => onDelete?.call(),
                      _ => null,
                    },
                  ),
                ],
              ),
              // Aktionen als Leiste über die volle Kartenbreite: mit beiden
              // Daumen erreichbar, Senden nicht nur rechts oben
              // (DESIGN_SPEC 5a, Regel 9). Stornieren bleibt im Menü.
              const SizedBox(height: 8),
              _ActionRow(
                children: [
                  if (onRemind != null)
                    FilledButton.tonalIcon(
                      key: Key('remind-${invoice.id}'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: onRemind,
                      icon: const Icon(Icons.mark_email_unread_outlined),
                      label: Text(dunning == null ? 'Erinnern' : 'Mahnen'),
                    ),
                  if (onMarkPaid != null)
                    FilledButton.tonalIcon(
                      key: Key('paid-${invoice.id}'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: onMarkPaid,
                      icon: const Icon(Icons.check),
                      label: const Text('Bezahlt'),
                    ),
                  OutlinedButton.icon(
                    key: Key('share-${invoice.id}'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: onShare,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Ansehen'),
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

/// Bis zu zwei Knöpfe nebeneinander über die volle Breite; ein dritter
/// steht darunter, damit Beschriftungen auch auf 360 dp und bei großer
/// Schrift nicht abgeschnitten werden.
class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    Widget row(List<Widget> items) => Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: items[i]),
        ],
        const SizedBox(width: 8),
      ],
    );
    if (children.length <= 2) return row(children);
    return Column(
      children: [
        row(children.take(2).toList()),
        const SizedBox(height: 8),
        row(children.skip(2).toList()),
      ],
    );
  }
}

/// Symbol einer gemahnten Rechnung: Stufe und neue Frist, Tipp zeigt den
/// Mahnverlauf. Mindestens 48 dp hoch.
class _DunningBadge extends StatelessWidget {
  const _DunningBadge({
    super.key,
    required this.notice,
    required this.overdue,
    this.onTap,
  });

  final DunningNotice notice;
  final bool overdue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = overdue ? AppTheme.expense : AppTheme.warning;
    return Semantics(
      button: true,
      label: 'Mahnverlauf anzeigen',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mark_email_read_outlined, size: 16, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${dunningBadge(notice.level)} · Frist '
                      '${Fmt.date(notice.newDueDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 16, color: color),
                ],
              ),
            ),
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

  int? _loadedRevision;

  /// Lebt im `IndexedStack` der Startseite weiter: neu laden, sobald sich
  /// [AppState.bookingsRevision] ändert – auch beim Wechsel in die Demo und
  /// zurück (Rückmeldung 2026-10-19: Demo zeigte hier echte bzw. keine Daten).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = AppScope.of(context).bookingsRevision;
    if (revision == _loadedRevision) return;
    _loadedRevision = revision;
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('customer-new'),
        heroTag: 'customer-new',
        onPressed: () => _open(),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Neuer Kunde'),
      ),
    );
  }
}
