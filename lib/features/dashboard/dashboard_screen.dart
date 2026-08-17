import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../data/repositories.dart';
import '../../domain/money.dart';
import '../../domain/receipt.dart';
import '../../services/small_business_monitor.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../onboarding/company_setup_screen.dart';
import '../receipts/receipt_edit_screen.dart';
import '../settings/settings_screen.dart';

/// Kassabuch-Übersicht: das Erste, was der Nutzer sieht.
///
/// Zeigt Einnahmen, Ausgaben und Ergebnis für einen wählbaren Zeitraum sowie
/// die Umsatzsteuer je Satz. Bei Kleinunternehmern kommt der Grenzwertmonitor
/// dazu – die eine Zahl, die über das Jahr hinweg wirklich wichtig ist.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  _Range _range = _Range.currentMonth;
  PeriodTotals? _totals;
  List<Receipt> _recent = const [];
  List<_MonthBar> _trend = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Period get _period => _range.toPeriod(DateTime.now());

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final state = AppScope.read(context);
    final period = _period;
    final totals = await state.repositories.receipts.totals(
      from: period.from,
      to: period.to,
    );
    final recent = await state.repositories.receipts.query(limit: 5);
    final trend = await _loadTrend(state);

    if (!mounted) return;
    setState(() {
      _totals = totals;
      _recent = recent;
      _trend = trend;
      _loading = false;
    });
  }

  /// Sechs Monate Verlauf – gerade genug, um eine Entwicklung zu erkennen,
  /// ohne auf dem Telefon zur Briefmarke zu schrumpfen.
  Future<List<_MonthBar>> _loadTrend(AppState state) async {
    final now = DateTime.now();
    final bars = <_MonthBar>[];
    for (var offset = 5; offset >= 0; offset--) {
      final anchor = DateTime(now.year, now.month - offset, 1);
      final period = Period.month(anchor);
      final totals = await state.repositories.receipts.totals(
        from: period.from,
        to: period.to,
      );
      bars.add(
        _MonthBar(
          label: Fmt.shortMonth(anchor),
          income: totals.incomeNet,
          expense: totals.expenseNet,
        ),
      );
    }
    return bars;
  }

  Future<void> _addReceipt(BookingDirection direction) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReceiptEditScreen(direction: direction),
      ),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final profile = state.profile;
    final totals = _totals;

    return Scaffold(
      appBar: AppBar(
        title: Text(profile?.companyName ?? 'Übersicht'),
        actions: [
          IconButton(
            tooltip: 'Einstellungen',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            if (profile != null && !profile.canIssueInvoices) ...[
              NoticeBanner(
                icon: Icons.warning_amber_rounded,
                color: AppTheme.warning,
                message:
                    'Für rechtssichere Rechnungen fehlen noch: '
                    '${profile.missingInvoiceFields.join(', ')}.',
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CompanySetupScreen(),
                    ),
                  );
                  if (mounted) await _load();
                },
              ),
              const SizedBox(height: 16),
            ],

            if (state.smallBusiness != null &&
                state.smallBusiness!.status !=
                    SmallBusinessStatus.notApplicable) ...[
              _SmallBusinessCard(assessment: state.smallBusiness!),
              const SizedBox(height: 16),
            ],

            _rangeSelector(),
            const SizedBox(height: 16),

            if (_loading && totals == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (totals != null) ...[
              _TotalsCard(totals: totals, period: _period),
              const SizedBox(height: 16),
              if (!totals.isEmpty) ...[
                _VatCard(
                  totals: totals,
                  isSmallBusiness: profile?.isSmallBusiness ?? true,
                ),
                const SizedBox(height: 16),
              ],
              if (_trend.any(
                (bar) => !bar.income.isZero || !bar.expense.isZero,
              )) ...[
                SectionCard(
                  title: 'Letzte 6 Monate',
                  child: _TrendChart(bars: _trend),
                ),
                const SizedBox(height: 16),
              ],
              _recentCard(),
            ],
          ],
        ),
      ),
      floatingActionButton: _AddReceiptButton(onSelected: _addReceipt),
    );
  }

  Widget _rangeSelector() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final range in _Range.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(range.label),
                selected: _range == range,
                onSelected: (_) {
                  setState(() => _range = range);
                  _load();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _recentCard() {
    if (_recent.isEmpty) {
      return SectionCard(
        title: 'Letzte Belege',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Noch keine Belege erfasst. Tippe auf das Plus, um deinen ersten '
            'Beleg zu fotografieren.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final state = AppScope.of(context);
    return SectionCard(
      title: 'Letzte Belege',
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Column(
        children: [
          for (final receipt in _recent)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                receipt.direction == BookingDirection.income
                    ? Icons.south_west
                    : Icons.north_east,
                color: AppTheme.amountColor(
                  receipt.direction == BookingDirection.income,
                  context,
                ),
              ),
              title: Text(
                receipt.description.isEmpty
                    ? 'Ohne Bezeichnung'
                    : receipt.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  Fmt.date(receipt.date),
                  state.categoryById(receipt.categoryId)?.name,
                ].whereType<String>().join(' · '),
              ),
              trailing: Text(
                Fmt.money(receipt.gross),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.amountColor(
                    receipt.direction == BookingDirection.income,
                    context,
                  ),
                ),
              ),
              onTap: () async {
                final changed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => ReceiptEditScreen(
                      direction: receipt.direction,
                      existing: receipt,
                    ),
                  ),
                );
                if (changed == true) await _load();
              },
            ),
        ],
      ),
    );
  }
}

/// Auswahlmöglichkeiten für den Zeitraum. Quartal ist dabei, weil die
/// Umsatzsteuervoranmeldung bei kleinen Umsätzen quartalsweise abzugeben ist.
enum _Range {
  currentMonth('Dieser Monat'),
  lastMonth('Letzter Monat'),
  currentQuarter('Dieses Quartal'),
  currentYear('Dieses Jahr'),
  lastYear('Letztes Jahr');

  const _Range(this.label);
  final String label;

  Period toPeriod(DateTime now) => switch (this) {
    _Range.currentMonth => Period.month(now),
    _Range.lastMonth => Period.month(DateTime(now.year, now.month - 1, 1)),
    _Range.currentQuarter => Period.quarter(
      now.year,
      ((now.month - 1) ~/ 3) + 1,
    ),
    _Range.currentYear => Period.year(now.year),
    _Range.lastYear => Period.year(now.year - 1),
  };
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.totals, required this.period});

  final PeriodTotals totals;
  final Period period;

  @override
  Widget build(BuildContext context) {
    final profit = totals.profit;
    return SectionCard(
      title: period.label,
      child: Column(
        children: [
          LabeledValue(
            label: 'Einnahmen (netto)',
            value: Fmt.money(totals.incomeNet),
            valueColor: AppTheme.amountColor(true, context),
          ),
          LabeledValue(
            label: 'Ausgaben (netto)',
            value: Fmt.money(totals.expenseNet),
            valueColor: AppTheme.amountColor(false, context),
          ),
          const Divider(height: 20),
          LabeledValue(
            label: 'Ergebnis',
            value: Fmt.signedMoney(profit),
            emphasize: true,
            valueColor: AppTheme.amountColor(!profit.isNegative, context),
          ),
        ],
      ),
    );
  }
}

class _VatCard extends StatelessWidget {
  const _VatCard({required this.totals, required this.isSmallBusiness});

  final PeriodTotals totals;
  final bool isSmallBusiness;

  @override
  Widget build(BuildContext context) {
    if (isSmallBusiness) {
      return SectionCard(
        title: 'Umsatzsteuer',
        child: Text(
          'Als Kleinunternehmer weist du keine Umsatzsteuer aus und kannst keine '
          'Vorsteuer abziehen. Es fällt daher keine Zahllast an.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final payable = totals.vatPayable;
    final rates = totals.incomeNetByRate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return SectionCard(
      title: 'Umsatzsteuer',
      child: Column(
        children: [
          for (final permille in rates.where((p) => p > 0))
            LabeledValue(
              label: 'Umsatz ${Fmt.vatRate(permille)}',
              value: Fmt.money(
                totals.incomeNetByRate[permille] ?? const Money.zero(),
              ),
            ),
          const Divider(height: 20),
          LabeledValue(
            label: 'Umsatzsteuer',
            value: Fmt.money(totals.incomeVat),
          ),
          LabeledValue(label: 'Vorsteuer', value: Fmt.money(totals.expenseVat)),
          const Divider(height: 20),
          LabeledValue(
            label: payable.isNegative ? 'Guthaben' : 'Zahllast',
            value: Fmt.money(payable.abs),
            emphasize: true,
            valueColor: AppTheme.amountColor(payable.isNegative, context),
          ),
        ],
      ),
    );
  }
}

class _SmallBusinessCard extends StatelessWidget {
  const _SmallBusinessCard({required this.assessment});

  final SmallBusinessAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, icon) = switch (assessment.status) {
      SmallBusinessStatus.exceeded => (AppTheme.expense, Icons.error_outline),
      SmallBusinessStatus.withinTolerance => (
        AppTheme.warning,
        Icons.warning_amber_rounded,
      ),
      SmallBusinessStatus.approaching => (AppTheme.warning, Icons.trending_up),
      _ => (scheme.primary, Icons.check_circle_outline),
    };

    final fraction = (assessment.utilizationPercent / 100).clamp(0.0, 1.0);

    return SectionCard(
      title: 'Kleinunternehmergrenze',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${Fmt.money(assessment.currentYearTurnover)} von '
                  '${Fmt.money(assessment.limit)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${assessment.utilizationPercent.toStringAsFixed(0)} %',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            assessment.message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _MonthBar {
  const _MonthBar({
    required this.label,
    required this.income,
    required this.expense,
  });

  final String label;
  final Money income;
  final Money expense;
}

/// Schlichtes Balkendiagramm ohne Chart-Bibliothek. Zwei Balken pro Monat,
/// skaliert auf den größten Wert im Zeitraum.
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.bars});

  final List<_MonthBar> bars;

  @override
  Widget build(BuildContext context) {
    final max = bars
        .expand((bar) => [bar.income.cents, bar.expense.cents])
        .fold<int>(1, (a, b) => b > a ? b : a);

    return Column(
      children: [
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final bar in bars)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _bar(context, bar.income.cents / max, true),
                            const SizedBox(width: 3),
                            _bar(context, bar.expense.cents / max, false),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          bar.label,
                          style: Theme.of(context).textTheme.labelSmall,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legend(context, 'Einnahmen', true),
            const SizedBox(width: 16),
            _legend(context, 'Ausgaben', false),
          ],
        ),
      ],
    );
  }

  Widget _bar(BuildContext context, double fraction, bool isIncome) {
    // Mindesthöhe 2, damit ein kleiner Betrag nicht unsichtbar wird.
    final height = (fraction.clamp(0.0, 1.0) * 88).clamp(
      fraction > 0 ? 2.0 : 0.0,
      88.0,
    );
    return Container(
      width: 10,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.amountColor(isIncome, context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
      ),
    );
  }

  Widget _legend(BuildContext context, String label, bool isIncome) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: AppTheme.amountColor(isIncome, context),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

/// Zwei Wege zum Beleg – Einnahme oder Ausgabe. Der häufigere Fall (Ausgabe)
/// liegt näher am Daumen.
class _AddReceiptButton extends StatelessWidget {
  const _AddReceiptButton({required this.onSelected});

  final void Function(BookingDirection) onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.small(
          heroTag: 'income',
          tooltip: 'Einnahme erfassen',
          onPressed: () => onSelected(BookingDirection.income),
          backgroundColor: AppTheme.amountColor(true, context),
          foregroundColor: Colors.white,
          child: const Icon(Icons.south_west),
        ),
        const SizedBox(height: 10),
        FloatingActionButton(
          heroTag: 'expense',
          tooltip: 'Ausgabe erfassen',
          onPressed: () => onSelected(BookingDirection.expense),
          child: const Icon(Icons.add_a_photo_outlined),
        ),
      ],
    );
  }
}
