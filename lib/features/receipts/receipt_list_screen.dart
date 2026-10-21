import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../domain/money.dart';
import '../../domain/receipt.dart';
import '../../theme.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/capture_button.dart';
import '../../widgets/common.dart';
import '../contracts/contract_screens.dart';
import 'receipt_edit_screen.dart';
import 'receipt_view_screen.dart';
import '../help/help_screen.dart';
import '../../services/help/help_index.dart';

/// Belegliste mit Suche und Filter. Der Kern der täglichen Nutzung.
class ReceiptListScreen extends StatefulWidget {
  const ReceiptListScreen({super.key});

  @override
  State<ReceiptListScreen> createState() => _ReceiptListScreenState();
}

class _ReceiptListScreenState extends State<ReceiptListScreen> {
  final _searchController = TextEditingController();

  BookingDirection? _filter;

  /// Stornierte Belege statt der gültigen zeigen – nur zum Nachlesen (L-2.17).
  bool _showCancelled = false;
  int _year = DateTime.now().year;
  List<Receipt> _receipts = const [];
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final state = AppScope.read(context);
    final receipts = await state.repositories.receipts.query(
      from: DateTime(_year, 1, 1),
      to: DateTime(_year, 12, 31),
      direction: _filter,
      search: _searchController.text,
      cancelledOnly: _showCancelled,
    );
    if (!mounted) return;
    setState(() {
      _receipts = receipts;
      _loading = false;
    });
  }

  /// Belege nach Monat gruppieren – so findet man einen Beleg tatsächlich wieder.
  Map<String, List<Receipt>> get _grouped {
    final groups = <String, List<Receipt>>{};
    for (final receipt in _receipts) {
      final key = Fmt.monthYear(receipt.date);
      groups.putIfAbsent(key, () => []).add(receipt);
    }
    return groups;
  }

  Money get _visibleBalance => _receipts
      .map((receipt) => receipt.signedGross)
      .fold(const Money.zero(), (a, b) => a + b);

  Future<void> _open(Receipt? receipt) async {
    final changed = await ListDetail.open<bool>(
      context,
      // Vorhandener Beleg: zuerst lesen, „Bearbeiten“ öffnet das Formular.
      (_) => receipt == null
          ? const ReceiptEditScreen(direction: BookingDirection.expense)
          : ReceiptViewScreen(receipt: receipt),
    );
    if (changed == true) await _load();
  }

  /// Neuer Beleg, Scanner bzw. Kamera öffnet sofort (wie auf der Übersicht).
  Future<void> _capture(ReceiptStart start) async {
    final changed = await ListDetail.open<bool>(
      context,
      (_) =>
          ReceiptEditScreen(direction: BookingDirection.expense, start: start),
    );
    if (changed == true) await _load();
  }

  Future<void> _pickYear(List<int> years) async {
    final year = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final y in years)
              ListTile(
                title: Text('$y'),
                selected: y == _year,
                onTap: () => Navigator.of(context).pop(y),
              ),
          ],
        ),
      ),
    );
    if (year == null || !mounted) return;
    setState(() => _year = year);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final years = _availableYears();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Belege'),
        actions: [const HelpButton(context: HelpTopic.receipts)],
      ),
      // Kopf (Umschalter, Suche, Filter, Summe) scrollt mit der Liste: quer
      // bliebe sonst kaum Platz für Belege (Gerätetest 2026-10-20, FA-9.6).
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  // Vertragsarchiv sichtbar machen (Rückmeldung 2026-10-19, FA-16.9).
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<int>(
                        key: const Key('receipts-contracts-switch'),
                        style: SegmentedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: 0,
                            icon: Icon(Icons.receipt_long_outlined),
                            label: Text('Belege'),
                          ),
                          ButtonSegment(
                            value: 1,
                            icon: Icon(Icons.description_outlined),
                            label: Text('Verträge'),
                          ),
                        ],
                        selected: const {0},
                        onSelectionChanged: (s) {
                          if (s.first != 1) return;
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ContractListScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Produkt, Partner oder Notiz suchen',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _load();
                                },
                              ),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _load(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Umbrechen statt seitlich scrollen; das Jahr steht mit in der
                  // Reihe statt oben in der AppBar (DESIGN_SPEC 5a, Regel 4 und 7).
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          key: const Key('receipt-year'),
                          avatar: const Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                          ),
                          label: Text('$_year'),
                          onPressed: () => _pickYear(years),
                        ),
                        for (final entry in <(String, BookingDirection?)>[
                          ('Alle', null),
                          ('Einnahmen', BookingDirection.income),
                          ('Ausgaben', BookingDirection.expense),
                        ])
                          Padding(
                            padding: EdgeInsets.zero,
                            child: ChoiceChip(
                              label: Text(entry.$1),
                              selected: _filter == entry.$2,
                              onSelected: (_) {
                                setState(() => _filter = entry.$2);
                                _load();
                              },
                            ),
                          ),
                        FilterChip(
                          label: const Text('Storniert'),
                          selected: _showCancelled,
                          onSelected: (value) {
                            setState(() => _showCancelled = value);
                            _load();
                          },
                        ),
                      ],
                    ),
                  ),
                  if (_receipts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          Text(
                            '${_receipts.length} ${_receipts.length == 1 ? 'Beleg' : 'Belege'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const Spacer(),
                          Text(
                            'Saldo ${Fmt.signedMoney(_visibleBalance)}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.amountColor(
                                    !_visibleBalance.isNegative,
                                    context,
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (_receipts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Keine Belege',
                        message: _searchController.text.isEmpty
                            ? 'Erfasse deinen ersten Beleg – Foto machen, Betrag '
                                  'eintippen, fertig.'
                            : 'Zu dieser Suche gibt es keine Treffer.',
                        action: FilledButton.icon(
                          onPressed: () => _open(null),
                          icon: const Icon(Icons.add),
                          label: const Text('Beleg erfassen'),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final group in _grouped.entries) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                              child: Text(
                                group.key,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                            ),
                            Card(
                              child: Column(
                                children: [
                                  for (
                                    var i = 0;
                                    i < group.value.length;
                                    i++
                                  ) ...[
                                    if (i > 0) const Divider(height: 1),
                                    _ReceiptTile(
                                      receipt: group.value[i],
                                      categoryName: state
                                          .categoryById(
                                            group.value[i].categoryId,
                                          )
                                          ?.name,
                                      onTap: () => _open(group.value[i]),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
      // Runder Aufnahmeknopf unten in der Mitte, an derselben Stelle wie
      // auf der Übersicht (DESIGN_SPEC 5a, Regel 1, 9 und 13).
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: CaptureBar(
        cameraKey: const Key('receipt-new'),
        keyPrefix: 'receipt-new',
        onCamera: () => _capture(ReceiptStart.camera),
        onPhoto: () => _capture(ReceiptStart.gallery),
        onFile: () => _capture(ReceiptStart.file),
      ),
    );
  }

  /// Auswahl der Jahre: das laufende Jahr plus die gesetzliche
  /// Aufbewahrungsfrist rückwärts.
  List<int> _availableYears() {
    final current = DateTime.now().year;
    final years =
        AppScope.read(context).profile?.taxProfile.retentionYears ?? 7;
    return [for (var year = current; year > current - years; year--) year];
  }
}

class _ReceiptTile extends StatelessWidget {
  const _ReceiptTile({
    required this.receipt,
    required this.categoryName,
    required this.onTap,
  });

  final Receipt receipt;
  final String? categoryName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isIncome = receipt.direction == BookingDirection.income;
    final color = AppTheme.amountColor(isIncome, context);

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.14),
        child: Icon(
          receipt.hasImage
              ? Icons.photo_outlined
              : (isIncome ? Icons.south_west : Icons.north_east),
          size: 18,
          color: color,
        ),
      ),
      title: Text(
        receipt.description.isEmpty ? 'Ohne Bezeichnung' : receipt.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          Fmt.date(receipt.date),
          if (receipt.counterparty.isNotEmpty) receipt.counterparty,
          if (categoryName != null) categoryName!,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Fmt.money(receipt.gross),
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
          if (receipt.isSplit)
            Text(
              receipt.lines.map((l) => Fmt.vatRate(l.vatPermille)).join(' + '),
              style: Theme.of(context).textTheme.labelSmall,
            )
          else if (receipt.vatPermille > 0)
            Text(
              '${Fmt.vatRate(receipt.vatPermille)} USt',
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ),
    );
  }
}
