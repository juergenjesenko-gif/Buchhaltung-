import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../domain/country.dart';
import '../../domain/customer.dart';
import '../../domain/offer.dart';
import '../../services/invoice_logo.dart';
import '../../services/invoice_pdf.dart';
import '../../services/invoice_texts.dart';
import '../../services/licensing/license_policy.dart';
import '../../services/logo_store.dart';
import '../../widgets/common.dart';
import '../../widgets/primary_action_bar.dart';
import '../articles/position_picker.dart';
import '../invoices/invoice_edit_screen.dart';
import '../pdf_viewer/pdf_viewer_screen.dart';
import '../licensing/feature_gate.dart';

/// Angebotsliste (L-3.13 bis L-3.17). Erreichbar über Rechnungen → Angebote.
class OfferListScreen extends StatefulWidget {
  const OfferListScreen({super.key});

  @override
  State<OfferListScreen> createState() => _OfferListScreenState();
}

class _OfferListScreenState extends State<OfferListScreen> {
  List<Offer> _offers = const [];
  Map<int, Customer> _customers = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final repos = AppScope.read(context).repositories;
    final offers = await repos.offers.all();
    final customers = await repos.customers.all();
    if (!mounted) return;
    setState(() {
      _offers = offers;
      _customers = {
        for (final c in customers)
          if (c.id != null) c.id!: c,
      };
      _loading = false;
    });
  }

  Future<void> _open([Offer? offer]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => OfferEditScreen(existing: offer)),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Angebote')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _offers.isEmpty
          ? EmptyState(
              icon: Icons.request_quote_outlined,
              title: 'Keine Angebote',
              message:
                  'Ein Angebot bucht nichts. Nimmt die Kundin an, wird es '
                  'mit einem Tipp zur Rechnung.',
              action: FilledButton.icon(
                onPressed: () => _open(),
                icon: const Icon(Icons.add),
                label: const Text('Angebot schreiben'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                for (final o in _offers)
                  ListTile(
                    minTileHeight: 64,
                    title: Text(
                      '${o.number} · ${_customers[o.customerId]?.name ?? ''}',
                    ),
                    subtitle: Text(
                      '${o.statusOn(today).label} · gültig bis '
                      '${Fmt.date(o.validUntil)}',
                    ),
                    trailing: Text(
                      Fmt.money(o.grossTotal),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () => _open(o),
                  ),
              ],
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('offer-new'),
        heroTag: 'offer-new',
        onPressed: () => _open(),
        icon: const Icon(Icons.add),
        label: const Text('Neues Angebot'),
      ),
    );
  }
}

/// Angebot schreiben, senden, in Rechnung umwandeln (L-3.13 bis L-3.17).
class OfferEditScreen extends StatefulWidget {
  const OfferEditScreen({super.key, this.existing});

  final Offer? existing;

  @override
  State<OfferEditScreen> createState() => _OfferEditScreenState();
}

class _OfferEditScreenState extends State<OfferEditScreen> {
  final _notes = TextEditingController();
  Offer? _offer;
  Customer? _customer;
  DateTime _issueDate = DateTime.now();
  late DateTime _validUntil = _issueDate.add(
    const Duration(days: OfferPolicy.defaultValidityDays),
  );
  List<ItemDraft> _items = [];
  bool _busy = false;
  bool _initialized = false;

  bool get _locked => _offer?.isLocked ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final state = AppScope.read(context);
    final o = widget.existing;
    _offer = o;
    if (o != null) {
      _issueDate = o.issueDate;
      _validUntil = o.validUntil;
      _notes.text = o.notes;
      _items = o.items.map(ItemDraft.fromItem).toList();
      state.repositories.customers.byId(o.customerId).then((c) {
        if (mounted) setState(() => _customer = c);
      });
    } else {
      _items = [ItemDraft.empty(state.defaultVatPermille)];
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  bool get _small =>
      _offer?.isSmallBusiness ??
      (AppScope.read(context).profile?.isSmallBusiness ?? true);

  Offer get _current => Offer(
    id: _offer?.id,
    number: _offer?.number ?? '',
    issueDate: _issueDate,
    validUntil: _validUntil,
    customerId: _customer?.id ?? 0,
    items: [
      for (final d in _items)
        if (!d.isEmpty) d.toItem(),
    ],
    status: _offer?.status ?? OfferStatus.draft,
    isSmallBusiness: _small,
    notes: _notes.text.trim(),
    invoiceId: _offer?.invoiceId,
    createdAt: _offer?.createdAt,
  );

  List<String> _errors() => [
    if (_customer == null) 'Kunde auswählen',
    if (_items.every((d) => d.isEmpty)) 'Mindestens eine Position',
    if (_items.any((d) => !d.isEmpty && d.description.text.trim().isEmpty))
      'Bezeichnung für jede Position',
    if (_validUntil.isBefore(
      DateTime(_issueDate.year, _issueDate.month, _issueDate.day),
    ))
      'Gültig bis nach dem Angebotsdatum',
  ];

  /// Speichert; `false`, wenn etwas fehlt oder das Abo fehlt.
  Future<bool> _save() async {
    if (_locked) return true;
    final errors = _errors();
    if (errors.isNotEmpty) {
      showSnack(context, 'Es fehlt noch: ${errors.join(', ')}');
      return false;
    }
    // Demo (FA-13.14): nichts speichern.
    if (!await ensureWritable(context)) return false;
    if (!mounted) return false;
    // Neue Angebote ab Basis (Lastenheft 5.10); vorhandene bleiben änderbar.
    if (_offer?.id == null &&
        !await ensureFeature(context, Feature.newBookings)) {
      return false;
    }
    if (!mounted) return false;
    final repo = AppScope.read(context).repositories.offers;
    final id = await repo.save(_current);
    final saved = await repo.byId(id);
    if (!mounted) return false;
    setState(() => _offer = saved);
    return true;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveAndClose() => _run(() async {
    if (await _save() && mounted) Navigator.of(context).pop();
  });

  /// PDF senden (L-3.17): Tarifschnitt wie bei Rechnungen (FA-13.11).
  /// Ein Entwurf gilt danach als gesendet.
  Future<void> _sendPdf() => _run(() async {
    if (!await _save() || !mounted) return;
    final state = AppScope.read(context);
    final offer = _offer!;
    final profile = state.profile!;
    final logoAllowed = state.allows(Feature.invoiceLogo);
    final logo = await LogoStore.readBytes(
      logoAllowed && profile.hasLogo ? profile.logoPath : null,
    );
    final bytes = await InvoicePdf.offer(
      offer: offer,
      customer: _customer!,
      profile: InvoiceLogo.forNewDocument(profile, logoAllowed: logoAllowed),
      logo: logo,
    ).build();
    if (!mounted) return;
    final sent = await openPdfViewer(
      context,
      title: InvoiceTexts.offerTitle(offer.number),
      sendFeature: Feature.pdfSending,
      fileName: 'Angebot_${offer.number}.pdf',
      bytes: bytes,
      subject: InvoiceTexts.offerTitle(offer.number),
      text: InvoiceTexts.shareOffer(offer.number),
    );
    if (sent && offer.status == OfferStatus.draft) {
      await state.repositories.offers.setStatus(offer.id!, OfferStatus.sent);
      final reloaded = await state.repositories.offers.byId(offer.id!);
      if (mounted) setState(() => _offer = reloaded);
    }
  });

  /// Ein Tipp: Angebot angenommen, Rechnungsentwurf mit allen Positionen
  /// öffnet sich (L-3.15).
  Future<void> _convert() => _run(() async {
    if (!_locked) {
      if (!await _save() || !mounted) return;
      if (!await ensureFeature(context, Feature.newBookings)) return;
    }
    if (!mounted) return;
    final state = AppScope.read(context);
    final id = await state.repositories.offers.convertToInvoice(
      _offer!.id!,
      now: DateTime.now(),
      paymentTermDays: state.profile?.defaultPaymentTermDays ?? 14,
      isSmallBusiness: state.profile?.isSmallBusiness ?? _small,
    );
    final invoice = await state.repositories.invoices.byId(id);
    if (!mounted || invoice == null) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => InvoiceEditScreen(existing: invoice),
      ),
    );
  });

  Future<void> _setStatus(OfferStatus status) => _run(() async {
    final repo = AppScope.read(context).repositories.offers;
    await repo.setStatus(_offer!.id!, status);
    final reloaded = await repo.byId(_offer!.id!);
    if (mounted) setState(() => _offer = reloaded);
  });

  Future<void> _pickCustomer() async {
    final customers = await AppScope.read(context).repositories.customers.all();
    if (!mounted) return;
    final selected = await showModalBottomSheet<Customer>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => CustomerPicker(customers: customers),
    );
    if (selected != null && mounted) setState(() => _customer = selected);
  }

  Future<void> _pickDate(DateTime initial, ValueChanged<DateTime> set) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
      locale: const Locale('de'),
    );
    if (picked != null) setState(() => set(picked));
  }

  Future<void> _takePosition() async {
    final vat = AppScope.read(context).defaultVatPermille;
    final item = await pickPosition(context);
    if (item == null || !mounted) return;
    setState(() {
      if (_items.isNotEmpty && _items.last.isEmpty) {
        _items.removeLast().dispose();
      }
      _items.add(
        ItemDraft.fromItem(_small ? item.copyWith(vatPermille: vat) : item),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final tax = state.profile?.taxProfile;
    final status = _offer?.statusOn(DateTime.now());
    final saved = _offer?.id != null;
    return PopScope(
      canPop: _locked,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: _scaffold(context, state, tax, status, saved),
    );
  }

  /// Zurück: ein gespeichertes Angebot übernimmt Änderungen still; ein neues
  /// mit Eingaben fragt einmal (wie FA-5.34 bei Rechnungen).
  Future<void> _leave() async {
    final hasInput = _customer != null || _items.any((d) => !d.isEmpty);
    if (_offer?.id == null && !hasInput) {
      Navigator.of(context).pop();
      return;
    }
    if (_errors().isEmpty) {
      if (await _save() && mounted) Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Angebot noch nicht speicherbar'),
        content: Text('Es fehlt noch: ${_errors().join(', ')}.'),
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
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  Widget _scaffold(
    BuildContext context,
    AppState state,
    TaxProfile? tax,
    OfferStatus? status,
    bool saved,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(saved ? 'Angebot ${_offer!.number}' : 'Neues Angebot'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          if (status != null) ...[
            NoticeBanner(
              icon: _locked ? Icons.lock_outline : Icons.info_outline,
              message: _locked
                  ? 'Angenommen und in eine Rechnung umgewandelt – nicht mehr '
                        'änderbar.'
                  : 'Status: ${status.label}. Ein Angebot bucht nichts.',
            ),
            const SizedBox(height: 16),
          ],
          SectionCard(
            title: 'Kunde und Gültigkeit',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  key: const Key('offer-customer'),
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: 56,
                  leading: const Icon(Icons.person_outline),
                  title: Text(_customer?.name ?? 'Kunde wählen'),
                  trailing: _locked ? null : const Icon(Icons.chevron_right),
                  onTap: _locked ? null : _pickCustomer,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: 56,
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Angebotsdatum'),
                  trailing: Text(Fmt.date(_issueDate)),
                  onTap: _locked
                      ? null
                      : () => _pickDate(_issueDate, (d) => _issueDate = d),
                ),
                ListTile(
                  key: const Key('offer-valid-until'),
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: 56,
                  leading: const Icon(Icons.event_available_outlined),
                  title: const Text('Gültig bis'),
                  trailing: Text(Fmt.date(_validUntil)),
                  onTap: _locked
                      ? null
                      : () => _pickDate(_validUntil, (d) => _validUntil = d),
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
                    vatRates:
                        tax?.vatRatesOn(
                          _issueDate,
                          keep: _items[i].vatPermille,
                        ) ??
                        const [],
                    showVat: !_small,
                    readOnly: _locked,
                    onChanged: () => setState(() {}),
                    onRemove: _items.length == 1 || _locked
                        ? null
                        : () => setState(() => _items.removeAt(i).dispose()),
                  ),
                ],
                if (!_locked) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('addOfferItem'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => setState(
                      () =>
                          _items.add(ItemDraft.empty(state.defaultVatPermille)),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Position hinzufügen'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('pickOfferItem'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _takePosition,
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Aus Artikeln und Vorschlägen'),
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
                LabeledValue(
                  label: 'Netto',
                  value: Fmt.money(_current.netTotal),
                ),
                LabeledValue(
                  label: _small ? 'Gesamt' : 'Gesamt brutto',
                  value: Fmt.money(_current.grossTotal),
                  emphasize: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Anmerkungen',
            child: TextField(
              controller: _notes,
              readOnly: _locked,
              decoration: const InputDecoration(
                hintText: 'Erscheint unter den Positionen im Angebot',
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          if (saved && !_locked) ...[
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: status == OfferStatus.rejected
                  ? TextButton.icon(
                      key: const Key('offer-reopen'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () => _setStatus(OfferStatus.sent),
                      icon: const Icon(Icons.undo),
                      label: const Text('Wieder öffnen'),
                    )
                  : TextButton.icon(
                      key: const Key('offer-reject'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () => _setStatus(OfferStatus.rejected),
                      icon: const Icon(Icons.thumb_down_outlined),
                      label: const Text('Kundin hat abgelehnt'),
                    ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: PrimaryActionBar(
        secondary: PrimaryActionBar.outlined(
          key: const Key('offer-send'),
          label: 'PDF ansehen',
          icon: Icons.picture_as_pdf_outlined,
          onPressed: _busy ? null : _sendPdf,
        ),
        primary: !saved
            ? PrimaryActionBar.filled(
                key: const Key('offer-save'),
                label: 'Speichern',
                icon: Icons.check,
                busy: _busy,
                onPressed: _saveAndClose,
              )
            : PrimaryActionBar.filled(
                key: const Key('offer-convert'),
                label: _locked ? 'Rechnung öffnen' : 'Zur Rechnung machen',
                icon: Icons.receipt_long_outlined,
                busy: _busy,
                onPressed: _convert,
              ),
      ),
    );
  }
}
