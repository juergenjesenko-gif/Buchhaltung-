import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../domain/money.dart';
import '../../domain/receipt.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'receipt_edit_screen.dart';

/// Belegliste mit Suche und Filter. Der Kern der täglichen Nutzung.
class ReceiptListScreen extends StatefulWidget {
  const ReceiptListScreen({super.key});

  @override
  State<ReceiptListScreen> createState() => _ReceiptListScreenState();
}

class _ReceiptListScreenState extends State<ReceiptListScreen> {
  final _searchController = TextEditingController();

  BookingDirection? _filter;
  int _year = DateTime.now().year;
  List<Receipt> _receipts = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
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
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReceiptEditScreen(
          direction: receipt?.direction ?? BookingDirection.expense,
          existing: receipt,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final years = _availableYears();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Belege'),
        actions: [
          PopupMenuButton<int>(
            tooltip: 'Jahr wählen',
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Text('$_year'), const Icon(Icons.arrow_drop_down)],
            ),
            itemBuilder: (context) => [
              for (final year in years)
                PopupMenuItem(value: year, child: Text(year.toString())),
            ],
            onSelected: (year) {
              setState(() => _year = year);
              _load();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Beschreibung, Partner oder Notiz suchen',
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final entry in <(String, BookingDirection?)>[
                  ('Alle', null),
                  ('Einnahmen', BookingDirection.income),
                  ('Ausgaben', BookingDirection.expense),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.$1),
                      selected: _filter == entry.$2,
                      onSelected: (_) {
                        setState(() => _filter = entry.$2);
                        _load();
                      },
                    ),
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _receipts.isEmpty
                ? EmptyState(
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
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
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
                                        .categoryById(group.value[i].categoryId)
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _open(null),
        tooltip: 'Beleg erfassen',
        child: const Icon(Icons.add),
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
          if (receipt.vatPermille > 0)
            Text(
              '${Fmt.vatRate(receipt.vatPermille)} USt',
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ),
    );
  }
}
