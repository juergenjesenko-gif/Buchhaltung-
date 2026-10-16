import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../domain/fixed_asset.dart';
import '../../domain/money.dart';
import '../../domain/receipt.dart';
import '../../services/assets/depreciation.dart';
import '../../services/licensing/license_policy.dart';
import '../../services/vat_calculator.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/common.dart';
import '../../widgets/primary_action_bar.dart';
import '../help/help_screen.dart';
import '../licensing/feature_gate.dart';

String _amountText(Money m) {
  final c = m.cents.abs();
  return '${m.isNegative ? '-' : ''}${c ~/ 100},'
      '${(c % 100).toString().padLeft(2, '0')}';
}

/// Anlagen (FA-15.1 ff.): Liste mit Buchwert heute.
class AssetListScreen extends StatefulWidget {
  const AssetListScreen({super.key});

  @override
  State<AssetListScreen> createState() => _AssetListScreenState();
}

class _AssetListScreenState extends State<AssetListScreen> {
  List<FixedAsset>? _assets;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final list = await AppScope.read(context).repositories.assets.all();
    if (mounted) setState(() => _assets = list);
  }

  Future<void> _open([FixedAsset? asset]) async {
    if (asset == null &&
        !await ensureFeature(context, Feature.assetManagement)) {
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AssetEditScreen(asset: asset)),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final rules = state.depreciationRules;
    final assets = _assets;
    final today = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anlagen'),
        actions: const [HelpButton()],
      ),
      bottomNavigationBar: PrimaryActionBar(
        primary: PrimaryActionBar.filled(
          key: const Key('asset-new'),
          label: 'Anlage ohne Beleg erfassen',
          icon: Icons.add,
          onPressed: () => _open(),
        ),
      ),
      body: ReadableWidth(
        child: assets == null || rules == null
            ? const Center(child: CircularProgressIndicator())
            : assets.isEmpty
            ? const EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'Noch keine Anlagen',
                message:
                    'Öffne eine Ausgabe und tippe „Als Investition '
                    'erfassen“ – oder erfasse eine Anlage hier ohne Beleg.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  for (final a in assets)
                    Card(
                      child: ListTile(
                        minVerticalPadding: 12,
                        title: Text(a.name),
                        subtitle: Text(
                          '${Fmt.date(a.acquiredOn)} · '
                          '${a.isDisposed ? 'ausgeschieden' : a.method.label}',
                        ),
                        trailing: Text(
                          Fmt.money(Depreciation.bookValue(a, rules, today)),
                        ),
                        onTap: () => _open(a),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Anlage erfassen oder ändern (FA-15.1 bis FA-15.4).
class AssetEditScreen extends StatefulWidget {
  const AssetEditScreen({super.key, this.asset, this.receipt});

  final FixedAsset? asset;

  /// Anschaffungsbeleg beim Erfassen aus einer Ausgabe.
  final Receipt? receipt;

  @override
  State<AssetEditScreen> createState() => _AssetEditScreenState();
}

class _AssetEditScreenState extends State<AssetEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _cost;
  late final TextEditingController _years;
  late final TextEditingController _reason;
  late final TextEditingController _comment;
  late DateTime _date;
  late String _category;
  late DepreciationMethod _method;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.asset;
    final r = widget.receipt;
    final state = AppScope.read(context);
    final rules = state.depreciationRules!;
    // Anschaffungskosten: netto, Kleinunternehmer brutto (§ 6 Z 11 EStG AT,
    // § 9b Abs 1 EStG DE).
    final cost =
        a?.cost ??
        (r == null
            ? const Money.zero()
            : (state.inputVatDeductible ? r.net : r.gross));
    _name = TextEditingController(text: a?.name ?? r?.description ?? '');
    _cost = TextEditingController(text: cost.isZero ? '' : _amountText(cost));
    _date = a?.acquiredOn ?? r?.date ?? DateTime.now();
    _category = a?.categoryKey ?? rules.classes.first.key;
    _method =
        a?.method ??
        (cost.isZero
            ? DepreciationMethod.linear
            : Depreciation.suggestMethod(cost, _netCost(cost), rules));
    _years = TextEditingController(
      text: '${a?.usefulLifeYears ?? rules.classFor(_category).years}',
    );
    _reason = TextEditingController(text: a?.lifeReason ?? '');
    _comment = TextEditingController(text: a?.comment ?? '');
  }

  /// Nettobetrag für die GWG-Grenze (DE stets netto): beim Kleinunternehmer
  /// aus dem Beleg bzw. zum Normalsatz herausgerechnet.
  Money _netCost(Money cost) {
    final state = AppScope.read(context);
    if (state.inputVatDeductible) return cost;
    final r = widget.receipt;
    if (r != null) return r.net.isZero ? r.gross : r.net;
    return VatCalculator.fromGross(cost, state.reverseChargePermille).net;
  }

  @override
  void dispose() {
    for (final c in [_name, _cost, _years, _reason, _comment]) {
      c.dispose();
    }
    super.dispose();
  }

  FixedAsset _current() {
    final base =
        widget.asset ??
        FixedAsset(
          receiptId: widget.receipt?.id,
          name: '',
          acquiredOn: _date,
          cost: const Money.zero(),
          categoryKey: _category,
          usefulLifeYears: 1,
        );
    return base.copyWith(
      name: _name.text.trim(),
      acquiredOn: _date,
      cost: Money.tryParse(_cost.text) ?? const Money.zero(),
      categoryKey: _category,
      usefulLifeYears: int.tryParse(_years.text.trim()) ?? 0,
      method: _method,
      lifeReason: _reason.text.trim(),
      comment: _comment.text.trim(),
    );
  }

  bool get _readOnly => widget.asset?.isDisposed ?? false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!await ensureFeature(context, Feature.assetManagement)) return;
    if (!mounted) return;
    final state = AppScope.read(context);
    final asset = _current();
    final error = Depreciation.validate(
      asset,
      _netCost(asset.cost),
      state.depreciationRules!,
    );
    if (error != null) {
      showSnack(context, error);
      return;
    }
    setState(() => _saving = true);
    await state.repositories.assets.save(asset);
    await state.onBookingsChanged();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _dispose() async {
    final asset = widget.asset;
    if (asset == null) return;
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DisposalSheet(asset: asset),
    );
    if (done == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final rules = state.depreciationRules!;
    final cls = rules.classFor(_category);
    final preview = _current();
    final plan = preview.cost.cents > 0 && preview.usefulLifeYears > 0
        ? Depreciation.plan(preview, rules)
        : const <AfaYear>[];
    final suggested = cls.years;
    final deviates =
        _method == DepreciationMethod.linear &&
        (int.tryParse(_years.text.trim()) ?? suggested) != suggested;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.asset == null ? 'Investition erfassen' : 'Anlage'),
        actions: const [HelpButton()],
      ),
      bottomNavigationBar: _readOnly
          ? null
          : PrimaryActionBar(
              secondary: widget.asset == null
                  ? null
                  : PrimaryActionBar.outlined(
                      key: const Key('asset-dispose'),
                      label: 'Ausscheiden',
                      icon: Icons.delete_sweep_outlined,
                      onPressed: _dispose,
                    ),
              primary: PrimaryActionBar.filled(
                key: const Key('asset-save'),
                label: 'Speichern',
                icon: Icons.check,
                busy: _saving,
                onPressed: _save,
              ),
            ),
      body: ReadableWidth(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              if (_readOnly)
                NoticeBanner(
                  icon: Icons.lock_outline,
                  message:
                      'Ausgeschieden am ${Fmt.date(widget.asset!.disposedOn!)} '
                      '(${widget.asset!.disposalKind?.label ?? ''}): '
                      '${widget.asset!.disposalComment}',
                ),
              SectionCard(
                title: 'Anlage',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _name,
                      enabled: !_readOnly,
                      decoration: const InputDecoration(
                        labelText: 'Bezeichnung',
                      ),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Bitte eine Bezeichnung eingeben'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      minVerticalPadding: 12,
                      title: const Text('Angeschafft / in Betrieb am'),
                      subtitle: Text(Fmt.date(_date)),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      enabled: !_readOnly,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(DateTime.now().year + 1, 12, 31),
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                    ),
                    MoneyField(
                      controller: _cost,
                      label: state.inputVatDeductible
                          ? 'Anschaffungskosten netto'
                          : 'Anschaffungskosten brutto',
                      onChanged: (_) => setState(() {}),
                      validator: (v) =>
                          (Money.tryParse(v ?? '') ?? const Money.zero())
                                  .cents <=
                              0
                          ? 'Bitte einen Betrag eingeben'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Art'),
                      items: [
                        for (final c in rules.classes)
                          DropdownMenuItem(value: c.key, child: Text(c.label)),
                      ],
                      onChanged: _readOnly
                          ? null
                          : (v) => setState(() {
                              _category = v ?? _category;
                              _years.text =
                                  '${rules.classFor(_category).years}';
                            }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Abschreibung',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final m in DepreciationMethod.values)
                      if (m != DepreciationMethod.pool ||
                          rules.poolRange != null)
                        _ChoiceTile(
                          label: m.label,
                          selected: _method == m,
                          onTap: _readOnly
                              ? null
                              : () => setState(() => _method = m),
                        ),
                    if (_method == DepreciationMethod.linear) ...[
                      TextFormField(
                        controller: _years,
                        enabled: !_readOnly,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Nutzungsdauer in Jahren',
                          helperText:
                              'Vorschlag $suggested Jahre (${cls.legalRef})',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      if (deviates) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _reason,
                          enabled: !_readOnly,
                          decoration: const InputDecoration(
                            labelText: 'Begründung der Nutzungsdauer',
                            helperText: 'Steht im Anlagenverzeichnis',
                          ),
                          validator: (v) => deviates && (v ?? '').trim().isEmpty
                              ? 'Bitte kurz begründen, warum die Dauer '
                                    'abweicht'
                              : null,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Kommentar',
                child: TextFormField(
                  controller: _comment,
                  enabled: !_readOnly,
                  maxLines: 3,
                  minLines: 1,
                  decoration: const InputDecoration(
                    hintText: 'z. B. für die Steuerberatung',
                  ),
                ),
              ),
              if (plan.isNotEmpty) ...[
                const SizedBox(height: 16),
                SectionCard(
                  title: 'AfA-Plan',
                  child: Column(
                    children: [
                      for (final y in plan)
                        LabeledValue(
                          label:
                              '${y.year}${y.disposalValue.isZero ? '' : ' (Abgang ${Fmt.money(y.disposalValue)})'}',
                          value:
                              '${Fmt.money(y.afa)} · Rest ${Fmt.money(y.closing)}',
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Ausscheiden bzw. vollständig abschreiben (FA-15.6): Datum, Art, Erlös,
/// Kommentar Pflicht. Ein Verkauf mit Erlös bucht eine Einnahme.
class _DisposalSheet extends StatefulWidget {
  const _DisposalSheet({required this.asset});

  final FixedAsset asset;

  @override
  State<_DisposalSheet> createState() => _DisposalSheetState();
}

class _DisposalSheetState extends State<_DisposalSheet> {
  DateTime _date = DateTime.now();
  DisposalKind _kind = DisposalKind.scrapped;
  final _proceeds = TextEditingController();
  final _comment = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _proceeds.dispose();
    _comment.dispose();
    super.dispose();
  }

  bool get _valid =>
      _comment.text.trim().isNotEmpty &&
      !_date.isBefore(widget.asset.acquiredOn);

  Future<void> _confirm() async {
    if (!await ensureFeature(context, Feature.assetManagement)) return;
    if (!mounted) return;
    setState(() => _saving = true);
    final state = AppScope.read(context);
    final proceeds = _kind == DisposalKind.sold
        ? (Money.tryParse(_proceeds.text) ?? const Money.zero())
        : const Money.zero();
    int? receiptId;
    if (proceeds.cents > 0) {
      // Verkaufserlös als Einnahme brutto, Steuer zum Normalsatz
      // (Kleinunternehmer ohne USt).
      final permille = state.inputVatDeductible
          ? state.reverseChargePermille
          : 0;
      final split = VatCalculator.fromGross(proceeds, permille);
      receiptId = await state.repositories.receipts.save(
        Receipt(
          date: _date,
          direction: BookingDirection.income,
          description: 'Verkauf Anlage: ${widget.asset.name}',
          net: split.net,
          vat: split.vat,
          gross: proceeds,
          vatPermille: permille,
          note: _comment.text.trim(),
        ),
      );
    }
    await state.repositories.assets.save(
      widget.asset.copyWith(
        disposedOn: _date,
        disposalKind: _kind,
        disposalProceeds: proceeds,
        disposalReceiptId: receiptId,
        disposalComment: _comment.text.trim(),
      ),
    );
    await state.onBookingsChanged();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ausscheiden: ${widget.asset.name}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Der Restbuchwert wird an diesem Tag vollständig abgeschrieben.',
            ),
            for (final k in DisposalKind.values)
              _ChoiceTile(
                label: k.label,
                selected: _kind == k,
                onTap: () => setState(() => _kind = k),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              minVerticalPadding: 12,
              title: const Text('Datum'),
              subtitle: Text(Fmt.date(_date)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: widget.asset.acquiredOn,
                  lastDate: DateTime(DateTime.now().year + 1, 12, 31),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            if (_kind == DisposalKind.sold)
              MoneyField(controller: _proceeds, label: 'Erlös brutto'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _comment,
              decoration: const InputDecoration(
                labelText: 'Kommentar (Pflicht)',
                hintText: 'z. B. Displayschaden, an Händler verkauft',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            PrimaryActionBar.filled(
              key: const Key('asset-dispose-confirm'),
              label: 'Ausscheiden buchen',
              icon: Icons.check,
              busy: _saving,
              onPressed: _valid ? _confirm : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Auswahlzeile mit Kreis, ganze Zeile tippbar (≥ 48 dp).
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    minVerticalPadding: 12,
    leading: Icon(
      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      color: selected ? Theme.of(context).colorScheme.primary : null,
    ),
    title: Text(label),
    selected: selected,
    onTap: onTap,
  );
}
