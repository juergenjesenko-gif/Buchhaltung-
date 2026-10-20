import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../data/repositories.dart';
import '../../domain/country.dart';
import '../../domain/fiscal_year.dart';
import '../../domain/money.dart';
import '../../domain/receipt.dart';
import '../../services/deadline_calculator.dart';
import '../../services/levies/levy_estimator.dart';
import '../../services/licensing/license_policy.dart';
import '../../services/levies/levy_overview.dart';
import '../../services/small_business_monitor.dart';
import '../../theme.dart';
import '../../widgets/capture_button.dart';
import '../../widgets/scroll_auto_hide.dart';
import '../../widgets/common.dart';
import '../backup/backup_screen.dart';
import '../onboarding/company_setup_screen.dart';
import '../receipts/receipt_edit_screen.dart';
import '../settings/settings_screen.dart';
import '../help/help_screen.dart';
import '../levies/levies_screen.dart';
import '../licensing/feature_gate.dart';
import '../licensing/license_notice.dart';

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
  LevyEstimate? _levies;
  bool _loading = true;
  int? _loadedRevision;

  /// Aufnahmeleiste weicht beim Scrollen aus (Rückmeldung zu 0.30.0).
  final _barVisibility = ScrollHideController();

  @override
  void dispose() {
    _barVisibility.dispose();
    super.dispose();
  }

  /// Die Übersicht lebt im `IndexedStack` der Startseite weiter und wird
  /// nicht neu aufgebaut, wenn in einem anderen Reiter gebucht wird. Deshalb
  /// lädt sie neu, sobald sich [AppState.bookingsRevision] ändert
  /// (Gerätetest 0.3.3). Der erste Aufruf ersetzt das Laden in `initState`.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = AppScope.of(context).bookingsRevision;
    if (revision == _loadedRevision) return;
    _loadedRevision = revision;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Period get _period {
    final profile = AppScope.read(context).profile;
    return _range.toPeriod(
      DateTime.now(),
      profile?.fiscalYear ?? const FiscalYear(1),
      profile?.taxProfile.monthNames ?? TaxProfile.austria.monthNames,
    );
  }

  /// Zählt Ladevorgänge. Nur der jüngste darf sein Ergebnis anzeigen;
  /// ein älterer, langsamerer Lauf überschreibt sonst neue Summen mit alten
  /// (zwei Läufe nach einer Buchung: Revision und Rückkehr vom Formular).
  int _loadSequence = 0;

  Future<void> _load() async {
    if (!mounted) return;
    final sequence = ++_loadSequence;
    setState(() => _loading = true);

    final state = AppScope.read(context);
    final period = _period;
    final totals = await state.repositories.receipts.totals(
      from: period.from,
      to: period.to,
      inputVatDeductible: state.inputVatDeductible,
      reverseChargePermille: state.reverseChargePermille,
      depreciation: state.depreciationRules,
      entertainment: state.entertainmentRules,
      mixedUse: state.mixedUseRules,
      nonDeductibleKinds: state.nonDeductibleKinds,
    );
    final recent = await state.repositories.receipts.query(limit: 5);
    final trend = await _loadTrend(state);
    final profile = state.profile;
    final levies = profile == null
        ? null
        : (await LevyOverview.load(
            repos: state.repositories,
            profile: profile,
            today: DateTime.now(),
          )).estimate;

    if (!mounted || sequence != _loadSequence) return;
    setState(() {
      _levies = levies;
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
        inputVatDeductible: state.inputVatDeductible,
        reverseChargePermille: state.reverseChargePermille,
        depreciation: state.depreciationRules,
        entertainment: state.entertainmentRules,
        mixedUse: state.mixedUseRules,
        nonDeductibleKinds: state.nonDeductibleKinds,
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

  /// Ein zentraler Knopf für beide Hände; Einnahme oder Ausgabe wählt man im
  /// Formular (DESIGN_SPEC 5a, Regel 9).
  Future<void> _addReceipt(ReceiptStart start) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReceiptEditScreen(
          direction: BookingDirection.expense,
          start: start,
        ),
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
          const HelpButton(),
          IconButton(
            tooltip: 'Einstellungen',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: _barVisibility.handle,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            // Unten Platz für beide schwebenden Knöpfe (40 + 10 + 56 dp plus
            // 16 dp Rand) und Luft, damit keine Karte verdeckt bleibt
            // (Gerätetest 0.3.4).
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
            children: [
              const LicenseNotice(),
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

              if (state.autoBackupError != null) ...[
                NoticeBanner(
                  icon: Icons.cloud_off_outlined,
                  color: AppTheme.expense,
                  message:
                      'Automatische Sicherung fehlgeschlagen: '
                      '${state.autoBackupError}',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BackupScreen()),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (profile != null &&
                  !state.isLoading &&
                  profile.needsBackup(DateTime.now())) ...[
                BackupReminder(profile: profile),
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
                _TotalsCard(
                  totals: totals,
                  period: _period,
                  inputVatDeductible: state.inputVatDeductible,
                ),
                const SizedBox(height: 16),
                // Rücklage für Steuern & SV (FA-19.1), direkt unter dem Ergebnis.
                // Nur Pro (O-43): ohne Pro ein Hinweis mit „(Pro)“ zur Abo-Seite.
                if (!state.allows(Feature.levyReserve)) ...[
                  Card(
                    child: ListTile(
                      key: const Key('levy-teaser'),
                      minTileHeight: 56,
                      leading: const Icon(Icons.savings_outlined),
                      title: const Text('Abgaben & Rücklagen (Pro)'),
                      subtitle: const Text(
                        'Wie viel du für Steuern und SV zurücklegen solltest',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        if (!await ensureFeature(
                              context,
                              Feature.levyReserve,
                            ) ||
                            !context.mounted) {
                          return;
                        }
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const LeviesScreen(),
                          ),
                        );
                        await _load();
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else if (_levies != null && !_levies!.totalYear.isZero) ...[
                  LevyReserveCard(
                    estimate: _levies!,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LeviesScreen(),
                        ),
                      );
                      await _load();
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                if (!totals.isEmpty) ...[
                  _VatCard(
                    totals: totals,
                    isSmallBusiness: profile?.isSmallBusiness ?? true,
                    reverseCharge: (profile?.country ?? Country.at)
                        .taxProfile
                        .reverseCharge,
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

              // Termine stehen am Ende: zuerst die Zahlen, dann der Ausblick
              // (Gerätetest 0.6.0).
              if (state.deadlines != null &&
                  (state.deadlines!.upcoming.isNotEmpty ||
                      state.deadlines!.advisorNote != null)) ...[
                const SizedBox(height: 16),
                _DeadlineCard(overview: state.deadlines!),
              ],
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      // Runder Aufnahmeknopf unten in der Mitte, wie in der Belegliste
      // (DESIGN_SPEC 5a, Regel 13).
      floatingActionButton: ScrollHidingBar(
        key: const Key('dashboard-capture-bar'),
        controller: _barVisibility,
        child: CaptureBar(
          cameraKey: const Key('dashboard-photo'),
          keyPrefix: 'dashboard',
          onCamera: () => _addReceipt(ReceiptStart.camera),
          onPhoto: () => _addReceipt(ReceiptStart.gallery),
          onFile: () => _addReceipt(ReceiptStart.file),
        ),
      ),
    );
  }

  Widget _rangeSelector() {
    // Umbrechen statt seitlich scrollen (DESIGN_SPEC 5a, Regel 7).
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final range in _Range.values)
          Padding(
            padding: EdgeInsets.zero,
            child: ChoiceChip(
              label: Text(
                range.labelFor(
                  AppScope.of(context).profile?.fiscalYear ??
                      const FiscalYear(1),
                  DateTime.now(),
                ),
              ),
              selected: _range == range,
              onSelected: (_) {
                setState(() => _range = range);
                _load();
              },
            ),
          ),
      ],
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

  /// „Dieses Jahr“ und „Letztes Jahr“ folgen dem Wirtschaftsjahr der
  /// Gewinnermittlung (L-24.5); Monat und Quartal bleiben Kalenderzeiträume.
  Period toPeriod(DateTime now, FiscalYear fy, List<String> monthNames) =>
      switch (this) {
        _Range.currentMonth => Period.month(now),
        _Range.lastMonth => Period.month(DateTime(now.year, now.month - 1, 1)),
        _Range.currentQuarter => Period.quarter(
          now.year,
          ((now.month - 1) ~/ 3) + 1,
        ),
        _Range.currentYear => Period.fiscalYear(fy, fy.yearOf(now), monthNames),
        _Range.lastYear => Period.fiscalYear(
          fy,
          fy.yearOf(now) - 1,
          monthNames,
        ),
      };

  /// Beschriftung des Chips; beim abweichenden Wirtschaftsjahr „WJ 2027“.
  String labelFor(FiscalYear fy, DateTime now) => switch (this) {
    _Range.currentYear when !fy.isCalendarYear =>
      'Dieses WJ (${fy.shortLabel(fy.yearOf(now)).substring(3)})',
    _Range.lastYear when !fy.isCalendarYear =>
      'Letztes WJ (${fy.shortLabel(fy.yearOf(now) - 1).substring(3)})',
    _ => label,
  };
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({
    required this.totals,
    required this.period,
    required this.inputVatDeductible,
  });

  final PeriodTotals totals;
  final Period period;

  /// Ohne Vorsteuerabzug zählen Ausgaben brutto.
  final bool inputVatDeductible;

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
            key: const Key('dashboard-expense'),
            label: inputVatDeductible
                ? 'Ausgaben (netto)'
                : 'Ausgaben (brutto)',
            value: Fmt.money(totals.expenseNet),
            valueColor: AppTheme.amountColor(false, context),
          ),
          // Anlagen (FA-15.5): Anschaffung raus, AfA rein.
          if (!totals.capitalizedExpense.isZero)
            LabeledValue(
              label: 'davon Investitionen (nicht Ergebnis)',
              value: Fmt.money(totals.capitalizedExpense),
            ),
          if (!totals.depreciation.isZero)
            LabeledValue(
              label: 'Abschreibung (AfA)',
              value: Fmt.money(totals.depreciation),
              valueColor: AppTheme.amountColor(false, context),
            ),
          // Bewirtung (FA-2.60): nur teilweise abziehbar.
          if (!totals.entertainmentNonDeductible.isZero)
            LabeledValue(
              label: 'davon Bewirtung nicht abziehbar',
              value: Fmt.money(totals.entertainmentNonDeductible),
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
  const _VatCard({
    required this.totals,
    required this.isSmallBusiness,
    required this.reverseCharge,
  });

  final PeriodTotals totals;
  final bool isSmallBusiness;
  final ReverseChargeRules reverseCharge;

  /// Reverse Charge mit Kennzahlen (L-28.4), z. B. Amazon-Gebühren.
  List<Widget> _reverseChargeRows() => [
    if (reverseCharge.baseKz != null)
      LabeledValue(
        label: 'Reverse Charge Kz ${reverseCharge.baseKz} (Basis)',
        value: Fmt.money(totals.reverseChargeBase),
      ),
    LabeledValue(
      key: const Key('dashboard-reverse-charge'),
      label: 'Reverse Charge Kz ${reverseCharge.taxKz} (Steuer)',
      value: Fmt.money(totals.reverseChargeVat),
    ),
    LabeledValue(
      label: 'Vorsteuer daraus Kz ${reverseCharge.inputVatKz}',
      value: Fmt.money(totals.reverseChargeInputVat),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (isSmallBusiness && totals.hasReverseCharge) {
      // Auch Kleinunternehmer schulden die Steuer aus Reverse Charge, ohne
      // Vorsteuerabzug (AT § 19 Abs 1, DE § 13b Abs 5 UStG).
      final payable = totals.vatPayable;
      return SectionCard(
        title: 'Umsatzsteuer',
        child: Column(
          children: [
            const Text(
              'Als Kleinunternehmer weist du keine Umsatzsteuer aus. Für '
              'Leistungen aus dem EU-Ausland (z. B. Amazon-Gebühren) '
              'schuldest du sie trotzdem – ohne Vorsteuerabzug.',
            ),
            const Divider(height: 20),
            ..._reverseChargeRows(),
            const Divider(height: 20),
            LabeledValue(
              label: 'Zahllast',
              value: Fmt.money(payable),
              emphasize: true,
            ),
          ],
        ),
      );
    }
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
          if (totals.hasReverseCharge) ...[
            const Divider(height: 20),
            ..._reverseChargeRows(),
          ],
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
      SmallBusinessStatus.approaching => (AppTheme.warning, Icons.trending_up),
      // Unvollständige Zahlen sind nie ein Grund zur Entwarnung (O-19).
      SmallBusinessStatus.incomplete => (AppTheme.warning, Icons.help_outline),
      SmallBusinessStatus.ok => (scheme.primary, Icons.check_circle_outline),
      // Wird oben gar nicht angezeigt; steht hier, damit der switch vollständig
      // bleibt. Ein neuer Status soll den Build brechen, nicht still grün sein.
      SmallBusinessStatus.notApplicable => (scheme.outline, Icons.remove),
    };
    final incomplete = assessment.status == SmallBusinessStatus.incomplete;

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
                  '${incomplete ? 'mind. ' : ''}'
                  '${Fmt.money(assessment.currentYearTurnover)} von '
                  '${Fmt.money(assessment.displayLimit)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                incomplete
                    ? '?'
                    : '${assessment.utilizationPercent.toStringAsFixed(0)} %',
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
          if (assessment.limitsNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              assessment.limitsNote,
              key: const Key('small-business-limits'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          Text(
            assessment.message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (incomplete) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CompanySetupScreen()),
                ),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Umsatz ergänzen'),
              ),
            ),
          ],
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
    // Mindesthöhe 6, damit ein kleiner Betrag neben einem großen sichtbar
    // bleibt (Gerätetest 0.6.0: 12 € Ausgabe neben 2.500 € Einnahme).
    final height = (fraction.clamp(0.0, 1.0) * 88).clamp(
      fraction > 0 ? 6.0 : 0.0,
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

/// Termin-Box (L-25, Stufe 1: nur Anzeige). Ein Tipp auf einen Termin zeigt
/// die Rechtsgrundlage.
class _DeadlineCard extends StatelessWidget {
  const _DeadlineCard({required this.overview});

  final DeadlineOverview overview;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return SectionCard(
      title: 'Nächste Termine',
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final deadline in overview.upcoming)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.event_outlined),
              title: Text(deadline.label),
              subtitle: Text(
                '${deadline.approximate ? 'ca. ' : ''}'
                '${Fmt.date(deadline.date)}',
              ),
              trailing: Text(_daysText(deadline.daysFrom(today))),
              onTap: () => showSnack(
                context,
                'Rechtsgrundlage: ${deadline.legalRef}'
                '${deadline.approximate ? ' – Datum ungefähr' : ''}',
              ),
            ),
          if (overview.advisorNote != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(overview.advisorNote!),
            ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(deadlineDisclaimer, style: muted),
          ),
        ],
      ),
    );
  }

  static String _daysText(int days) => switch (days) {
    0 => 'heute',
    1 => 'morgen',
    _ => 'in $days Tagen',
  };
}
