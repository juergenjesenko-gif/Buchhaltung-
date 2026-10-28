import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../domain/country.dart';
import '../../domain/customer.dart';
import '../../domain/invoice.dart';
import '../../domain/money.dart';
import '../../services/invoice_logo.dart';
import '../../services/invoice_numbering.dart';
import '../../services/invoice_requirements.dart';
import '../../services/invoice_texts.dart';
import '../../widgets/source_link.dart';
import '../../services/licensing/license_policy.dart';
import '../licensing/feature_gate.dart';
import '../../services/invoice_totals.dart';
import '../../services/vat_id/vies_client.dart';
import '../../widgets/vat_check_status.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../articles/position_picker.dart';
import 'customer_edit_screen.dart';
import 'invoice_share.dart';
import '../../widgets/primary_action_bar.dart';
import '../../widgets/adaptive.dart';
import '../help/help_screen.dart';
import '../../services/help/help_index.dart';
import '../../domain/currency.dart';

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
  final _discountController = TextEditingController();
  final _shippingController = TextEditingController();
  final _skontoDaysController = TextEditingController();
  final _skontoPercentController = TextEditingController();
  bool _discountIsPercent = true;

  /// Steuersatz der Versandkosten; `null` = wie Hauptleistung (L-3.22).
  int? _shippingVatPermille;

  Customer? _customer;
  DateTime _issueDate = DateTime.now();
  DateTime? _deliveryDate;
  DateTime? _dueDate;
  List<ItemDraft> _items = [];
  bool _saving = false;
  bool _initialized = false;

  bool get _isEditing => widget.existing != null;

  /// Nach dem Ausstellen bleibt das Formular offen und bietet „PDF senden“.
  Invoice? _issued;

  bool get _isLocked =>
      _issued != null || (widget.existing?.status.isLocked ?? false);

  bool _showShipping = false;
  bool _skontoOn = false;

  /// Formularstand beim Öffnen; weicht der aktuelle davon ab, speichert
  /// „Beenden“ bzw. Zurück den Entwurf (FA-5.34).
  String? _initialSignature;

  /// Ein neuer oder noch nie gespeicherter Entwurf (z. B. Korrekturentwurf
  /// nach Storno) gilt immer als geändert.
  bool get _isDirty =>
      !_isLocked &&
      (widget.existing?.id == null || _signature() != _initialSignature);

  String _signature() => [
    _customer?.id ?? widget.existing?.customerId,
    _issueDate,
    _deliveryDate,
    _dueDate,
    _notesController.text,
    _discountIsPercent,
    _discountController.text,
    _shippingController.text,
    _shippingVatPermille,
    _skontoOn,
    _skontoDaysController.text,
    _skontoPercentController.text,
    for (final item in _items) ...[
      item.description.text,
      item.quantity.text,
      item.unitPrice.text,
      item.unit.text,
      item.vatPermille,
      item.discountIsPercent,
      item.discount.text,
    ],
  ].join('\u0001');

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
      _items = existing.items.map(ItemDraft.fromItem).toList();
      _loadCustomer(existing.customerId);
      _discountIsPercent = existing.discountAmount.isZero;
      _discountController.text = existing.discountPermille > 0
          ? percentText(existing.discountPermille)
          : (existing.discountAmount.isZero
                ? ''
                : Fmt.amount(existing.discountAmount));
      _shippingController.text = existing.shipping.isZero
          ? ''
          : Fmt.amount(existing.shipping);
      _shippingVatPermille = existing.shippingVatPermille;
      _showShipping = !existing.shipping.isZero;
      _skontoOn = existing.hasSkonto;
      _skontoDaysController.text = existing.skontoDays > 0
          ? existing.skontoDays.toString()
          : '';
      _skontoPercentController.text = existing.skontoPermille > 0
          ? percentText(existing.skontoPermille)
          : '';
    } else {
      _items = [ItemDraft.empty(state.defaultVatPermille)];
      _dueDate = DateTime.now().add(
        Duration(days: state.profile?.defaultPaymentTermDays ?? 14),
      );
      // Skonto aus dem Profil vorbelegen (L-3.23).
      final profile = state.profile;
      if (profile != null &&
          profile.defaultSkontoDays > 0 &&
          profile.defaultSkontoPermille > 0) {
        _skontoDaysController.text = profile.defaultSkontoDays.toString();
        _skontoPercentController.text = percentText(
          profile.defaultSkontoPermille,
        );
        _skontoOn = true;
      }
    }
    _initialSignature = _signature();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _discountController.dispose();
    _shippingController.dispose();
    _skontoDaysController.dispose();
    _skontoPercentController.dispose();
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

  int get _discountPermille =>
      _discountIsPercent ? parsePermille(_discountController.text) : 0;

  Money get _discountAmount => _discountIsPercent
      ? const Money.zero()
      : (Money.tryParse(_discountController.text) ?? const Money.zero());

  Money get _shipping =>
      Money.tryParse(_shippingController.text) ?? const Money.zero();

  int get _skontoDays =>
      _skontoOn ? (int.tryParse(_skontoDaysController.text.trim()) ?? 0) : 0;

  int get _skontoPermille =>
      _skontoOn ? parsePermille(_skontoPercentController.text) : 0;

  /// Summen aus `InvoiceTotals` – gerechnet wird nicht im Widget.
  InvoiceTotals get _totals => InvoiceTotals.compute(
    items: [
      for (final item in _items)
        if (!item.isEmpty) item.toItem(),
    ],
    isSmallBusiness: _isSmallBusiness,
    discountPermille: _discountPermille,
    discountAmount: _discountAmount,
    shipping: _shipping,
    shippingVatPermille: _shippingVatPermille,
  );

  Future<void> _pickCustomer() async {
    final state = AppScope.read(context);
    final customers = await state.repositories.customers.all();
    if (!mounted) return;

    final selected = await showModalBottomSheet<Customer>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => CustomerPicker(customers: customers),
    );
    if (selected != null && mounted) setState(() => _customer = selected);
  }

  /// Öffnet den gewählten Kunden im bestehenden Kundenformular und übernimmt
  /// den neuen Stand in den Entwurf (FA-5.50). Nur bei Entwürfen; gestellte
  /// Rechnungen behalten die eingefrorenen Stammdaten (GR-8).
  Future<void> _editCustomer() async {
    final current = _customer;
    if (current == null || _isLocked) return;
    final saved = await Navigator.of(context).push<Customer>(
      MaterialPageRoute(builder: (_) => CustomerEditScreen(existing: current)),
    );
    if (!mounted) return;
    if (saved != null) {
      setState(() => _customer = saved);
      return;
    }
    // Zurück ohne Speichern oder Kunde gelöscht: Stand aus der Datenbank.
    final id = current.id;
    if (id == null) return;
    final fresh = await AppScope.read(context).repositories.customers.byId(id);
    if (mounted) setState(() => _customer = fresh);
  }

  /// Hinweise, die das Ausstellen nicht sperren (FA-5.50).
  List<String> _warnings() {
    final profile = AppScope.read(context).profile;
    final customer = _customer;
    if (profile == null || customer == null) return const [];
    return InvoiceRequirements.warnings(
      profile: profile,
      customer: customer,
      gross: _totals.gross,
      isSmallBusiness:
          widget.existing?.isSmallBusiness ?? profile.isSmallBusiness,
    );
  }

  /// Übernimmt eine Position aus Artikeln oder früheren Positionen
  /// (L-11.5): ersetzt eine leere letzte Position, sonst anhängen.
  Future<void> _takePosition(int defaultVat) async {
    final item = await pickPosition(context);
    if (item == null || !mounted) return;
    final draft = ItemDraft.fromItem(
      _isSmallBusiness ? item.copyWith(vatPermille: defaultVat) : item,
    );
    setState(() {
      if (_items.isNotEmpty && _items.last.isEmpty) {
        _items.removeLast().dispose();
      }
      _items.add(draft);
    });
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
    if (_discountIsPercent && _discountPermille > 1000) {
      errors.add('Rabatt höchstens 100 %');
    }
    if ((_skontoDays > 0) != (_skontoPermille > 0)) {
      errors.add('Skonto mit Tagen und Prozent');
    }
    final profile = AppScope.read(context).profile;
    if (profile != null) {
      errors.addAll(
        profile.missingInvoiceFields.map((field) => 'Stammdaten: $field'),
      );
      if (_customer != null) {
        final gross = _totals.gross;
        errors.addAll(
          InvoiceRequirements.missing(
            profile: profile,
            customer: _customer!,
            gross: gross,
            isSmallBusiness:
                widget.existing?.isSmallBusiness ?? profile.isSmallBusiness,
          ),
        );
      }
    }
    return errors;
  }

  Future<void> _save({required bool issue}) async {
    final errors = _validationErrors();
    if (errors.isNotEmpty) {
      showSnack(context, 'Es fehlt noch: ${errors.join(', ')}');
      return;
    }
    // Demo (FA-13.14): zusammenstellen ja, speichern nein.
    if (!await ensureWritable(context)) return;
    if (!mounted) return;
    // Nur-Lese-Modus (L-22.6): neue und ausgestellte Rechnungen brauchen ein
    // Abo; vorhandene Entwürfe bleiben änderbar.
    if ((issue || widget.existing == null) &&
        !await ensureFeature(context, Feature.newBookings)) {
      return;
    }
    if (!mounted) return;

    setState(() => _saving = true);
    final state = AppScope.read(context);
    final profile = state.profile!;

    // Vor dem Ausstellen die Kunden-UID prüfen, wenn die Prüfung eingeschaltet
    // ist. Das Ergebnis wird mit der Rechnung eingefroren (Nachweis); ein
    // negatives Ergebnis warnt nur, es blockiert nie.
    VatCheck? vatCheck;
    if (issue &&
        profile.vatCheckEnabled &&
        _customer!.vatId.trim().isNotEmpty) {
      vatCheck = await state.vatCheckService.check(
        _customer!.vatId,
        profile: profile,
        subject: 'customer',
        subjectId: _customer!.id,
      );
      if (!mounted) return;
      if (vatCheck.result != VatCheckResult.valid) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('UID des Kunden nicht bestätigt'),
            content: Text(vatCheckMessage(vatCheck!)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Trotzdem ausstellen'),
              ),
            ],
          ),
        );
        if (proceed != true || !mounted) {
          if (mounted) setState(() => _saving = false);
          return;
        }
      }
    }

    var number = widget.existing?.number ?? '';
    // Endgültige Nummer erst beim Ausstellen ziehen, und zwar beim Speichern in
    // derselben Transaktion. Würde jeder Entwurf eine verbrauchen, hätte der
    // Nummernkreis Lücken für nie gestellte Rechnungen.
    final assignsNumber =
        issue && (widget.existing == null || !widget.existing!.status.isLocked);
    if (number.isEmpty) {
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
      discountPermille: _discountPermille,
      discountAmount: _discountAmount,
      shipping: _shipping,
      shippingVatPermille: _shippingVatPermille,
      skontoDays: _skontoPermille > 0 ? _skontoDays : 0,
      skontoPermille: _skontoDays > 0 ? _skontoPermille : 0,
      // Eingefroren wird bei der Rechnungslegung (GR-8): ein Entwurf
      // übernimmt beim Speichern den aktuellen Stand samt Logo (L-1.7).
      sellerSnapshot: (widget.existing?.status.isLocked ?? false)
          ? widget.existing!.sellerSnapshot
          : jsonEncode(
              InvoiceLogo.forNewDocument(
                profile,
                logoAllowed: state.allows(Feature.invoiceLogo),
              ).toMap(),
            ),
      // Wie beim Aussteller: ein Entwurf übernimmt den aktuellen Kundenstand
      // (FA-5.50, „Kunde bearbeiten“), gestellte Rechnungen bleiben (GR-8).
      customerSnapshot: (widget.existing?.status.isLocked ?? false)
          ? widget.existing!.customerSnapshot
          : jsonEncode({
              ..._customer!.toMap(),
              if (vatCheck != null) 'vat_check': vatCheck.toJson(),
            }),
      createdAt: widget.existing?.createdAt,
    );

    final savedId = await state.repositories.invoices.save(
      invoice,
      assignNumber: assignsNumber
          ? (sequence) => InvoiceNumbering.format(
              pattern: profile.invoiceNumberPattern,
              sequence: sequence,
              date: _issueDate,
            )
          : null,
    );
    if (assignsNumber) await state.reload();
    if (!mounted) return;
    if (issue) {
      // In derselben Leiste geht es mit „PDF senden“ weiter.
      final issued = await state.repositories.invoices.byId(savedId);
      if (!mounted) return;
      setState(() {
        _issued = issued;
        _saving = false;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  /// „Beenden“, Zurück-Pfeil und System-Zurück (FA-5.34): Änderungen werden
  /// als Entwurf gespeichert statt still verworfen. Fehlt für einen Entwurf
  /// noch etwas, fragt die App einmal, ob verworfen werden soll.
  Future<void> _leave() async {
    if (_saving) return;
    if (!_isDirty) {
      Navigator.of(context).pop(_issued != null);
      return;
    }
    final errors = _validationErrors();
    if (errors.isEmpty) {
      await _save(issue: false);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Entwurf noch nicht speicherbar'),
        content: Text(
          'Es fehlt noch: ${errors.join(', ')}. '
          'Ohne diese Angaben kann die Rechnung nicht gespeichert werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Verwerfen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Weiter bearbeiten'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final tax = state.profile?.taxProfile ?? TaxProfile.austria;
    final errors = _initialized ? _validationErrors() : const <String>[];

    return PopScope(
      // Im bearbeitbaren Zustand immer abfangen: Texteingaben lösen nicht
      // jedes Mal einen Neuaufbau aus, ein canPop aus _isDirty wäre veraltet.
      canPop: _isLocked,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: _scaffold(context, tax, errors),
    );
  }

  Widget _scaffold(BuildContext context, TaxProfile tax, List<String> errors) {
    final warnings = _initialized ? _warnings() : const <String>[];
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _issued != null
              ? 'Rechnung ${_issued!.number}'
              : (_isEditing
                    ? 'Rechnung ${widget.existing!.number}'
                    : 'Neue Rechnung'),
        ),

        actions: const [HelpButton(context: HelpTopic.invoices)],
      ),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            if (_isLocked) ...[
              NoticeBanner(
                icon: Icons.lock_outline,
                message: (widget.existing?.isCancellation ?? false)
                    ? 'Stornorechnung zu ${widget.existing!.cancelsNumber}: '
                          'Beträge mit umgekehrtem Vorzeichen, unveränderlich.'
                    : 'Diese Rechnung ist gestellt und kann nicht mehr '
                          'geändert werden. Zum Ändern in der Rechnungsliste '
                          '⋮ → Korrigieren tippen.',
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
                        if (!_isLocked) ...[
                          const SizedBox(height: 8),
                          // Volle Breite, 48 dp: mit dem Daumen sicher
                          // treffbar, weit weg von Gefahrenknöpfen.
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              key: const Key('invoice-edit-customer'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              ),
                              onPressed: _editCustomer,
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Kunde bearbeiten'),
                            ),
                          ),
                        ],
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
                  if (InvoiceTexts.deliveryAfterIssueHint(
                        _issueDate,
                        _deliveryDate,
                      )
                      case final hint?)
                    Padding(
                      key: const Key('deliveryAfterIssueHint'),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 18,
                            color: AppTheme.warning,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              hint,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < _items.length; i++) ...[
                    if (i > 0) const Divider(height: 24),
                    ItemEditor(
                      draft: _items[i],
                      index: i + 1,
                      vatRates: tax.vatRatesOn(
                        _deliveryDate ?? _issueDate,
                        keep: _items[i].vatPermille,
                      ),
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
                  if (!_isLocked) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const Key('addInvoiceItem'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => setState(
                        () => _items.add(
                          ItemDraft.empty(state.defaultVatPermille),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Position hinzufügen'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('pickInvoiceItem'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => _takePosition(state.defaultVatPermille),
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('Aus Artikeln und Vorschlägen'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            _extrasCard(tax),
            const SizedBox(height: 16),

            _summaryCard(tax),
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

            if (!_isLocked && warnings.isNotEmpty) ...[
              const SizedBox(height: 16),
              NoticeBanner(
                key: const Key('invoice-warning'),
                icon: Icons.info_outline,
                message: warnings.join(' '),
              ),
            ],
            if (!_isLocked && errors.isNotEmpty) ...[
              const SizedBox(height: 16),
              NoticeBanner(
                icon: Icons.checklist_outlined,
                color: AppTheme.warning,
                message: 'Vor dem Ausstellen fehlt noch: ${errors.join(', ')}.',
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: SourceLinkButton(
                  key: const Key('invoice-requirements-source'),
                  url: tax.invoiceSourceUrl,
                  label: tax.invoiceLegalRef,
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: _isLocked
          ? PrimaryActionBar(
              // „Beenden“ führt zur Liste zurück; nach dem Teilen-Blatt bleibt
              // die Rechnung offen (Gerätetest 0.13.0, FA-5.34).
              secondary: PrimaryActionBar.outlined(
                key: const Key('invoice-done'),
                label: 'Beenden',
                icon: Icons.done_all,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              primary: PrimaryActionBar.filled(
                key: const Key('invoice-share'),
                label: 'PDF ansehen',
                icon: Icons.send_outlined,
                onPressed: () =>
                    shareInvoicePdf(context, _issued ?? widget.existing!),
              ),
            )
          : PrimaryActionBar(
              secondary: PrimaryActionBar.outlined(
                key: const Key('invoice-draft'),
                label: 'Beenden',
                icon: Icons.save_outlined,
                onPressed: _saving ? null : _leave,
              ),
              primary: PrimaryActionBar.filled(
                key: const Key('invoice-issue'),
                label: 'Rechnung ausstellen',
                icon: Icons.check,
                busy: _saving,
                onPressed: errors.isNotEmpty ? null : () => _save(issue: true),
              ),
            ),
    );
  }

  Widget _summaryCard(TaxProfile tax) {
    final totals = _totals;
    final multiRate = totals.breakdown.length > 1 && !_isSmallBusiness;
    String suffix(int permille) =>
        multiRate ? ' (${Fmt.vatRate(permille)})' : '';
    final skonto = totals.skontoAmount(_skontoDays > 0 ? _skontoPermille : 0);
    return SectionCard(
      title: 'Summe',
      child: Column(
        children: [
          if (totals.discountLines.isNotEmpty ||
              totals.shippingLines.isNotEmpty) ...[
            LabeledValue(
              label: 'Summe Positionen',
              value: Fmt.money(totals.itemsNet),
            ),
            for (final line in totals.discountLines)
              LabeledValue(
                label: 'Rabatt${suffix(line.vatPermille)}',
                value: Fmt.money(line.net),
              ),
            for (final line in totals.shippingLines)
              LabeledValue(
                label: 'Versand${suffix(line.vatPermille)}',
                value: Fmt.money(line.net),
              ),
          ],
          LabeledValue(label: 'Netto', value: Fmt.money(totals.net)),
          if (!_isSmallBusiness) ...[
            for (final entry in totals.breakdown.entries)
              LabeledValue(
                label:
                    'USt ${Fmt.vatRate(entry.key)} auf '
                    '${Fmt.amount(entry.value.net)}',
                value: Fmt.money(entry.value.vat),
              ),
          ],
          const Divider(height: 20),
          LabeledValue(
            label: 'Gesamtbetrag',
            value: Fmt.money(totals.gross),
            emphasize: true,
          ),
          if (!skonto.isZero)
            LabeledValue(
              label: 'Skonto ${InvoiceTexts.percent(_skontoPermille)}',
              value: Fmt.money(skonto),
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
    );
  }

  /// Gesamtrabatt, Versandkosten und Skonto (L-3.21 bis L-3.23) – alles
  /// optional und eingeklappt, bis die Nutzerin es braucht.
  Widget _extrasCard(TaxProfile tax) {
    final rates = tax.vatRatesOn(
      _deliveryDate ?? _issueDate,
      keep: _shippingVatPermille,
    );
    final totals = _totals;
    final hasDiscount = _discountController.text.trim().isNotEmpty;
    return SectionCard(
      title: 'Rabatt, Versand, Skonto',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DiscountTile(
            key: const Key('invoiceDiscount'),
            addLabel: 'Rabatt auf die ganze Rechnung',
            summary: hasDiscount
                ? 'Rabatt ${_discountIsPercent ? '${_discountController.text} % ' : ''}'
                      '= ${Fmt.money(totals.discount)}'
                : null,
            readOnly: _isLocked,
            onEdit: () async {
              final result = await showDiscountSheet(
                context,
                title: 'Rabatt auf die ganze Rechnung',
                explanation:
                    'Wird bei mehreren Steuersätzen anteilig aufgeteilt.',
                isPercent: _discountIsPercent,
                text: _discountController.text,
              );
              if (result == null) return;
              setState(() {
                _discountIsPercent = result.isPercent;
                _discountController.text = result.text;
              });
            },
          ),
          const SizedBox(height: 8),
          if (!_showShipping)
            _AddButton(
              key: const Key('addShipping'),
              label: 'Versandkosten hinzufügen',
              icon: Icons.local_shipping_outlined,
              onPressed: _isLocked
                  ? null
                  : () => setState(() => _showShipping = true),
            )
          else ...[
            TextField(
              key: const Key('invoiceShipping'),
              controller: _shippingController,
              readOnly: _isLocked,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: 'Versandkosten netto',
                suffixText: Currency.home.symbol,
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (!_isSmallBusiness) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<int?>(
                initialValue: _shippingVatPermille,
                decoration: const InputDecoration(
                  labelText: 'Umsatzsteuer auf Versand',
                  helperText:
                      'Automatisch wie die Waren – bei mehreren Sätzen anteilig',
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('wie Hauptleistung (automatisch)'),
                  ),
                  for (final rate in rates)
                    DropdownMenuItem<int?>(
                      value: rate.permille,
                      child: Text(rate.display),
                    ),
                ],
                onChanged: _isLocked
                    ? null
                    : (value) => setState(() => _shippingVatPermille = value),
              ),
            ],
          ],
          const SizedBox(height: 8),
          SwitchListTile(
            key: const Key('skontoSwitch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Skonto anbieten'),
            subtitle: const Text('Nachlass, wenn deine Kundin schnell zahlt'),
            value: _skontoOn,
            onChanged: _isLocked
                ? null
                : (value) => setState(() => _skontoOn = value),
          ),
          if (_skontoOn) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('skontoPercent'),
                    controller: _skontoPercentController,
                    readOnly: _isLocked,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'Skonto',
                      suffixText: '%',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const Key('skontoDays'),
                    controller: _skontoDaysController,
                    readOnly: _isLocked,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'innerhalb',
                      suffixText: 'Tage',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            if (_skontoDays > 0 && _skontoPermille > 0) ...[
              const SizedBox(height: 8),
              Text(
                InvoiceTexts.paymentTerms(_draftInvoice()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Momentaufnahme des Formulars für Textvorschauen.
  Invoice _draftInvoice() => Invoice(
    number: '',
    issueDate: _issueDate,
    dueDate: _dueDate,
    customerId: 0,
    items: [
      for (final item in _items)
        if (!item.isEmpty) item.toItem(),
    ],
    isSmallBusiness: _isSmallBusiness,
    discountPermille: _discountPermille,
    discountAmount: _discountAmount,
    shipping: _shipping,
    shippingVatPermille: _shippingVatPermille,
    skontoDays: _skontoDays,
    skontoPermille: _skontoPermille,
  );

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
class ItemDraft {
  ItemDraft({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.unit,
    required this.vatPermille,
    required this.discount,
    this.discountIsPercent = true,
  });

  factory ItemDraft.empty(int vatPermille) => ItemDraft(
    description: TextEditingController(),
    quantity: TextEditingController(text: '1'),
    unitPrice: TextEditingController(),
    unit: TextEditingController(text: 'Stk'),
    vatPermille: vatPermille,
    discount: TextEditingController(),
  );

  factory ItemDraft.fromItem(InvoiceItem item) => ItemDraft(
    description: TextEditingController(text: item.description),
    quantity: TextEditingController(text: Fmt.quantity(item.quantityMilli)),
    unitPrice: TextEditingController(text: Fmt.amount(item.unitPrice)),
    unit: TextEditingController(text: item.unit),
    vatPermille: item.vatPermille,
    discount: TextEditingController(
      text: item.discountPermille > 0
          ? percentText(item.discountPermille)
          : (item.discountAmount.isZero ? '' : Fmt.amount(item.discountAmount)),
    ),
    discountIsPercent: item.discountAmount.isZero,
  );

  /// Positionsrabatt (L-3.21): Prozent oder Betrag.
  final TextEditingController discount;
  bool discountIsPercent;

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

  Money get net => toItem().net;

  bool get isEmpty => description.text.trim().isEmpty && price.isZero;

  InvoiceItem toItem() => InvoiceItem(
    position: 0, // wird beim Speichern neu durchnummeriert
    description: description.text.trim(),
    quantityMilli: quantityMilli == 0 ? 1000 : quantityMilli,
    unit: unit.text.trim().isEmpty ? 'Stk' : unit.text.trim(),
    unitPrice: price,
    vatPermille: vatPermille,
    discountPermille: discountIsPercent ? parsePermille(discount.text) : 0,
    discountAmount: discountIsPercent
        ? const Money.zero()
        : (Money.tryParse(discount.text) ?? const Money.zero()),
  );

  void dispose() {
    discount.dispose();
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
    unit.dispose();
  }
}

class ItemEditor extends StatelessWidget {
  const ItemEditor({
    super.key,
    required this.draft,
    required this.index,
    required this.vatRates,
    required this.showVat,
    required this.readOnly,
    required this.onChanged,
    this.onRemove,
  });

  final ItemDraft draft;
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
            if (onRemove != null) ...[
              const SizedBox(width: 8),
              IconButton(
                key: Key('removeItem$index'),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.delete_outline),
                onPressed: onRemove,
                tooltip: 'Position entfernen',
              ),
            ],
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
                decoration: InputDecoration(
                  labelText: 'Einzelpreis netto',
                  suffixText: Currency.home.symbol,
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DiscountTile(
          key: Key('itemDiscount$index'),
          addLabel: 'Rabatt hinzufügen',
          summary: draft.discount.text.trim().isEmpty
              ? null
              : 'Rabatt '
                    '${draft.discountIsPercent ? '${draft.discount.text} % ' : ''}'
                    '= ${Fmt.money(draft.toItem().discount)}',
          readOnly: readOnly,
          onEdit: () async {
            final result = await showDiscountSheet(
              context,
              title: 'Rabatt auf Position $index',
              explanation: 'Mindert nur diese Position.',
              isPercent: draft.discountIsPercent,
              text: draft.discount.text,
            );
            if (result == null) return;
            draft.discountIsPercent = result.isPercent;
            draft.discount.text = result.text;
            onChanged();
          },
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
class CustomerPicker extends StatelessWidget {
  const CustomerPicker({super.key, required this.customers});

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

/// Knopf mit 48-dp-Zielfläche zum Aufklappen eines optionalen Bereichs.
class _AddButton extends StatelessWidget {
  const _AddButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    ),
  );
}

/// Eingeklappter Rabatt: „Rabatt hinzufügen“ oder die Zusammenfassung mit
/// Bearbeiten-Knopf (L-3.21, UX-Vorgabe).
class DiscountTile extends StatelessWidget {
  const DiscountTile({
    super.key,
    required this.addLabel,
    required this.summary,
    required this.readOnly,
    required this.onEdit,
  });

  final String addLabel;
  final String? summary;
  final bool readOnly;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    if (summary == null) {
      if (readOnly) return const SizedBox.shrink();
      return _AddButton(
        label: addLabel,
        icon: Icons.sell_outlined,
        onPressed: onEdit,
      );
    }
    return Row(
      children: [
        const Icon(Icons.sell_outlined, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(summary!)),
        if (!readOnly)
          IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            tooltip: 'Rabatt ändern',
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
          ),
      ],
    );
  }
}

/// Bottom-Sheet für einen Rabatt mit Umschalter „% / €“. Liefert `null` bei
/// Abbruch; ein leerer Text entfernt den Rabatt.
Future<({bool isPercent, String text})?> showDiscountSheet(
  BuildContext context, {
  required String title,
  required String explanation,
  required bool isPercent,
  required String text,
}) {
  final controller = TextEditingController(text: text);
  var percent = isPercent;
  return showModalBottomSheet<({bool isPercent, String text})>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(explanation, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: true, label: Text('%')),
                ButtonSegment(value: false, label: Text(Currency.home.symbol)),
              ],
              selected: {percent},
              onSelectionChanged: (selection) =>
                  setSheetState(() => percent = selection.first),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('discountSheetField'),
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: 'Rabatt',
                suffixText: percent ? '%' : Currency.home.symbol,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (text.trim().isNotEmpty) ...[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () => Navigator.of(
                        context,
                      ).pop((isPercent: percent, text: '')),
                      child: const Text('Entfernen'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton(
                    key: const Key('discountSheetApply'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () => Navigator.of(
                      context,
                    ).pop((isPercent: percent, text: controller.text.trim())),
                    child: const Text('Übernehmen'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Prozenteingabe („2,5“) in Promille (25). Ungültig oder leer: 0.
int parsePermille(String input) {
  final parsed = Money.tryParse(input.replaceAll('%', ''));
  if (parsed == null || parsed.isNegative) return 0;
  return divideRounded(parsed.cents, 10);
}

/// Promille als Eingabetext: 25 → „2,5“, 100 → „10“.
String percentText(int permille) => permille % 10 == 0
    ? '${permille ~/ 10}'
    : '${permille ~/ 10},${permille % 10}';
