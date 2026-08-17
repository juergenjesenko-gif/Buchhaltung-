import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../domain/country.dart';
import '../../domain/customer.dart';
import '../../domain/invoice.dart';
import '../../domain/money.dart';
import '../../services/invoice_numbering.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'customer_edit_screen.dart';

/// Rechnung erstellen und bearbeiten.
///
/// Entwürfe sind frei editierbar. Beim Ausstellen wird die endgültige
/// Rechnungsnummer vergeben und die Rechnung gesperrt – eine gestellte
/// Rechnung nachträglich zu ändern wäre in beiden Ländern ein Formfehler.
class InvoiceEditScreen extends StatefulWidget {
  const InvoiceEditScreen({super.key, this.existing});

  final Invoice? existing;

  @override
  State<InvoiceEditScreen> createState() => _InvoiceEditScreenState();
}

class _InvoiceEditScreenState extends State<InvoiceEditScreen> {
  final _notesController = TextEditingController();

  Customer? _customer;
  DateTime _issueDate = DateTime.now();
  DateTime? _deliveryDate;
  DateTime? _dueDate;
  List<_ItemDraft> _items = [];
  bool _saving = false;
  bool _initialized = false;

  bool get _isEditing => widget.existing != null;
  bool get _isLocked => widget.existing?.status.isLocked ?? false;

  @override
  void initState() {
    super.initState();
    _deliveryDate = DateTime.now();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final state = AppScope.read(context);
    final existing = widget.existing;

    if (existing != null) {
      _issueDate = existing.issueDate;
      _deliveryDate = existing.deliveryDate;
      _dueDate = existing.dueDate;
      _notesController.text = existing.notes;
      _items = existing.items.map(_ItemDraft.fromItem).toList();
      _loadCustomer(existing.customerId);
    } else {
      _items = [_ItemDraft.empty(state.defaultVatPermille)];
      _dueDate = DateTime.now().add(
        Duration(days: state.profile?.defaultPaymentTermDays ?? 14),
      );
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCustomer(int id) async {
    final customer = await AppScope.read(
      context,
    ).repositories.customers.byId(id);
    if (mounted) setState(() => _customer = customer);
  }

  bool get _isSmallBusiness =>
      widget.existing?.isSmallBusiness ??
      (AppScope.read(context).profile?.isSmallBusiness ?? true);

  Money get _netTotal =>
      _items.map((item) => item.net).fold(const Money.zero(), (a, b) => a + b);

  Money get _vatTotal => _isSmallBusiness
      ? const Money.zero()
      : _items
            .map((item) => item.vat)
            .fold(const Money.zero(), (a, b) => a + b);

  Money get _grossTotal => _netTotal + _vatTotal;

  Future<void> _pickCustomer() async {
    final state = AppScope.read(context);
    final customers = await state.repositories.customers.all();
    if (!mounted) return;

    final selected = await showModalBottomSheet<Customer>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _CustomerPicker(customers: customers),
    );
    if (selected != null && mounted) setState(() => _customer = selected);
  }

  Future<void> _pickDate({
    required DateTime? initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 3),
      lastDate: DateTime(DateTime.now().year + 3),
      locale: const Locale('de'),
    );
    if (picked != null) setState(() => onPicked(picked));
  }

  /// Prüft, was einer gültigen Rechnung noch fehlt. Wird sowohl vor dem
  /// Speichern als auch für den Hinweis im Formular genutzt.
  List<String> _validationErrors() {
    final errors = <String>[];
    if (_customer == null) {
      errors.add('Kunde auswählen');
    } else if (!_customer!.hasCompleteAddress) {
      errors.add('Vollständige Anschrift des Kunden');
    }
    if (_items.isEmpty || _items.every((item) => item.isEmpty)) {
      errors.add('Mindestens eine Position');
    }
    if (_items.any(
      (item) => !item.isEmpty && item.description.text.trim().isEmpty,
    )) {
      errors.add('Bezeichnung für jede Position');
    }
    if (_deliveryDate == null) {
      errors.add('Liefer-/Leistungsdatum');
    }
    final profile = AppScope.read(context).profile;
    if (profile != null) {
      errors.addAll(
        profile.missingInvoiceFields.map((field) => 'Stammdaten: $field'),
      );
    }
    return errors;
  }

  Future<void> _save({required bool issue}) async {
    final errors = _validationErrors();
    if (errors.isNotEmpty) {
      showSnack(context, 'Es fehlt noch: ${errors.join(', ')}');
      return;
    }

    setState(() => _saving = true);
    final state = AppScope.read(context);
    final profile = state.profile!;

    var number = widget.existing?.number ?? '';
    if (issue &&
        (widget.existing == null || !widget.existing!.status.isLocked)) {
      // Endgültige Nummer erst beim Ausstellen ziehen. Würde jeder Entwurf eine
      // verbrauchen, hätte der Nummernkreis Lücken für nie gestellte Rechnungen.
      final sequence = await state.repositories.company
          .reserveNextInvoiceSequence();
      number = InvoiceNumbering.format(
        pattern: profile.invoiceNumberPattern,
        sequence: sequence,
        date: _issueDate,
      );
      await state.reload();
    } else if (number.isEmpty) {
      number = 'ENTWURF-${DateTime.now().millisecondsSinceEpoch}';
    }

    final invoice = Invoice(
      id: widget.existing?.id,
      number: number,
      issueDate: _issueDate,
      deliveryDate: _deliveryDate,
      dueDate: _dueDate,
      customerId: _customer!.id!,
      items: [
        for (final draft in _items.where((item) => !item.isEmpty))
          draft.toItem(),
      ],
      status: issue
          ? InvoiceStatus.issued
          : (widget.existing?.status ?? InvoiceStatus.draft),
      isSmallBusiness:
          widget.existing?.isSmallBusiness ?? profile.isSmallBusiness,
      notes: _notesController.text.trim(),
      sellerSnapshot:
          widget.existing?.sellerSnapshot ?? jsonEncode(profile.toMap()),
      customerSnapshot:
          widget.existing?.customerSnapshot ?? jsonEncode(_customer!.toMap()),
      createdAt: widget.existing?.createdAt,
    );

    await state.repositories.invoices.save(invoice);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final tax = state.profile?.taxProfile ?? TaxProfile.austria;
    final errors = _initialized ? _validationErrors() : const <String>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Rechnung ${widget.existing!.number}' : 'Neue Rechnung',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          if (_isLocked) ...[
            const NoticeBanner(
              icon: Icons.lock_outline,
              message:
                  'Diese Rechnung ist gestellt und kann nicht mehr geändert werden. '
                  'Für Korrekturen erstelle eine Storno- oder Gutschriftsrechnung.',
            ),
            const SizedBox(height: 16),
          ],

          SectionCard(
            title: 'Empfänger',
            action: _isLocked
                ? null
                : TextButton(
                    onPressed: _pickCustomer,
                    child: const Text('Wählen'),
                  ),
            child: _customer == null
                ? Text(
                    'Noch kein Kunde ausgewählt.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final line in _customer!.addressLines) Text(line),
                      if (!_customer!.hasCompleteAddress) ...[
                        const SizedBox(height: 8),
                        NoticeBanner(
                          icon: Icons.warning_amber_rounded,
                          color: AppTheme.warning,
                          message:
                              'Für eine Rechnung über der Kleinbetragsgrenze von '
                              '${Fmt.money(tax.smallAmountInvoiceLimit)} braucht der Kunde '
                              'eine vollständige Anschrift.',
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          SectionCard(
            title: 'Zeitraum',
            child: Column(
              children: [
                _dateTile(
                  label: 'Rechnungsdatum',
                  value: _issueDate,
                  onTap: _isLocked
                      ? null
                      : () => _pickDate(
                          initial: _issueDate,
                          onPicked: (date) => _issueDate = date,
                        ),
                ),
                _dateTile(
                  label: 'Liefer-/Leistungsdatum',
                  value: _deliveryDate,
                  helper: 'Pflichtangabe nach ${tax.invoiceLegalRef}',
                  onTap: _isLocked
                      ? null
                      : () => _pickDate(
                          initial: _deliveryDate,
                          onPicked: (date) => _deliveryDate = date,
                        ),
                ),
                _dateTile(
                  label: 'Fällig am',
                  value: _dueDate,
                  onTap: _isLocked
                      ? null
                      : () => _pickDate(
                          initial: _dueDate,
                          onPicked: (date) => _dueDate = date,
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SectionCard(
            title: 'Positionen',
            action: _isLocked
                ? null
                : IconButton(
                    tooltip: 'Position hinzufügen',
                    icon: const Icon(Icons.add),
                    onPressed: () => setState(
                      () => _items.add(
                        _ItemDraft.empty(state.defaultVatPermille),
                      ),
                    ),
                  ),
            child: Column(
              children: [
                for (var i = 0; i < _items.length; i++) ...[
                  if (i > 0) const Divider(height: 24),
                  _ItemEditor(
                    draft: _items[i],
                    index: i + 1,
                    vatRates: tax.vatRates,
                    showVat: !_isSmallBusiness,
                    readOnly: _isLocked,
                    onChanged: () => setState(() {}),
                    onRemove: _items.length == 1 || _isLocked
                        ? null
                        : () => setState(() {
                            _items.removeAt(i).dispose();
                          }),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          SectionCard(
            title: 'Summe',
            child: Column(
              children: [
                LabeledValue(label: 'Netto', value: Fmt.money(_netTotal)),
                if (!_isSmallBusiness) ...[
                  for (final entry in _vatByRate().entries)
                    LabeledValue(
                      label: 'USt ${Fmt.vatRate(entry.key)}',
                      value: Fmt.money(entry.value),
                    ),
                ],
                const Divider(height: 20),
                LabeledValue(
                  label: 'Gesamtbetrag',
                  value: Fmt.money(_grossTotal),
                  emphasize: true,
                ),
                if (_isSmallBusiness) ...[
                  const SizedBox(height: 12),
                  NoticeBanner(
                    icon: Icons.receipt_outlined,
                    message:
                        'Auf der Rechnung erscheint: '
                        '"${tax.smallBusinessInvoiceNote}"',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          SectionCard(
            title: 'Anmerkungen',
            child: TextFormField(
              controller: _notesController,
              readOnly: _isLocked,
              decoration: const InputDecoration(
                hintText: 'Erscheint unter den Positionen auf der Rechnung',
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),

          if (!_isLocked && errors.isNotEmpty) ...[
            const SizedBox(height: 16),
            NoticeBanner(
              icon: Icons.checklist_outlined,
              color: AppTheme.warning,
              message: 'Vor dem Ausstellen fehlt noch: ${errors.join(', ')}.',
            ),
          ],
        ],
      ),
      bottomNavigationBar: _isLocked
          ? null
          : Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                8 + MediaQuery.of(context).padding.bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => _save(issue: false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      child: const Text('Als Entwurf'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _saving || errors.isNotEmpty
                          ? null
                          : () => _save(issue: true),
                      child: const Text('Rechnung ausstellen'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Map<int, Money> _vatByRate() {
    final result = <int, Money>{};
    for (final item in _items) {
      if (item.isEmpty) continue;
      result[item.vatPermille] =
          (result[item.vatPermille] ?? const Money.zero()) + item.vat;
    }
    return Map.fromEntries(
      result.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
  }

  Widget _dateTile({
    required String label,
    required DateTime? value,
    VoidCallback? onTap,
    String? helper,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(
        [
          value == null ? 'Nicht gesetzt' : Fmt.date(value),
          if (helper != null) helper,
        ].join(' · '),
      ),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// Bearbeitbarer Zustand einer Rechnungsposition. Eigene Klasse, weil jede
/// Position ihre eigenen [TextEditingController] braucht.
class _ItemDraft {
  _ItemDraft({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.unit,
    required this.vatPermille,
  });

  factory _ItemDraft.empty(int vatPermille) => _ItemDraft(
    description: TextEditingController(),
    quantity: TextEditingController(text: '1'),
    unitPrice: TextEditingController(),
    unit: TextEditingController(text: 'Stk'),
    vatPermille: vatPermille,
  );

  factory _ItemDraft.fromItem(InvoiceItem item) => _ItemDraft(
    description: TextEditingController(text: item.description),
    quantity: TextEditingController(text: Fmt.quantity(item.quantityMilli)),
    unitPrice: TextEditingController(text: Fmt.amount(item.unitPrice)),
    unit: TextEditingController(text: item.unit),
    vatPermille: item.vatPermille,
  );

  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController unitPrice;
  final TextEditingController unit;
  int vatPermille;

  int get quantityMilli {
    final parsed = Money.tryParse(quantity.text);
    // Money parst "1,5" zu 150 Cent; für Mengen entspricht das 1500 Tausendstel.
    return parsed == null ? 0 : parsed.cents * 10;
  }

  Money get price => Money.tryParse(unitPrice.text) ?? const Money.zero();

  Money get net => Money((price.cents * quantityMilli / 1000).round());

  Money get vat => Money((net.cents * vatPermille / 1000).round());

  bool get isEmpty => description.text.trim().isEmpty && price.isZero;

  InvoiceItem toItem() => InvoiceItem(
    position: 0, // wird beim Speichern neu durchnummeriert
    description: description.text.trim(),
    quantityMilli: quantityMilli == 0 ? 1000 : quantityMilli,
    unit: unit.text.trim().isEmpty ? 'Stk' : unit.text.trim(),
    unitPrice: price,
    vatPermille: vatPermille,
  );

  void dispose() {
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
    unit.dispose();
  }
}

class _ItemEditor extends StatelessWidget {
  const _ItemEditor({
    required this.draft,
    required this.index,
    required this.vatRates,
    required this.showVat,
    required this.readOnly,
    required this.onChanged,
    this.onRemove,
  });

  final _ItemDraft draft;
  final int index;
  final List<VatRate> vatRates;
  final bool showVat;
  final bool readOnly;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Position $index',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const Spacer(),
            Text(
              Fmt.money(draft.net),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (onRemove != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18),
                onPressed: onRemove,
                tooltip: 'Position entfernen',
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: draft.description,
          readOnly: readOnly,
          decoration: const InputDecoration(labelText: 'Bezeichnung'),
          textCapitalization: TextCapitalization.sentences,
          maxLines: 2,
          minLines: 1,
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            SizedBox(
              width: 76,
              child: TextField(
                controller: draft.quantity,
                readOnly: readOnly,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.right,
                decoration: const InputDecoration(labelText: 'Menge'),
                onChanged: (_) => onChanged(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 68,
              child: TextField(
                controller: draft.unit,
                readOnly: readOnly,
                decoration: const InputDecoration(labelText: 'Einheit'),
                onChanged: (_) => onChanged(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: draft.unitPrice,
                readOnly: readOnly,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  labelText: 'Einzelpreis netto',
                  suffixText: '€',
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
          ],
        ),
        if (showVat) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            initialValue: draft.vatPermille,
            decoration: const InputDecoration(labelText: 'Umsatzsteuersatz'),
            items: [
              for (final rate in vatRates)
                DropdownMenuItem(
                  value: rate.permille,
                  child: Text(rate.display),
                ),
            ],
            onChanged: readOnly
                ? null
                : (value) {
                    draft.vatPermille = value ?? 0;
                    onChanged();
                  },
          ),
        ],
      ],
    );
  }
}

/// Auswahlliste der Kunden mit der Möglichkeit, direkt einen neuen anzulegen.
class _CustomerPicker extends StatelessWidget {
  const _CustomerPicker({required this.customers});

  final List<Customer> customers;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Kunde wählen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (customers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Noch keine Kunden angelegt.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final customer in customers)
                      ListTile(
                        title: Text(customer.name),
                        subtitle: Text(
                          [
                            customer.postalCode,
                            customer.city,
                          ].where((s) => s.isNotEmpty).join(' '),
                        ),
                        trailing: customer.hasCompleteAddress
                            ? null
                            : const Icon(Icons.warning_amber_rounded, size: 18),
                        onTap: () => Navigator.of(context).pop(customer),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () async {
                final created = await Navigator.of(context).push<Customer>(
                  MaterialPageRoute(builder: (_) => const CustomerEditScreen()),
                );
                if (created != null && context.mounted) {
                  Navigator.of(context).pop(created);
                }
              },
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Neuen Kunden anlegen'),
            ),
          ],
        ),
      ),
    );
  }
}
