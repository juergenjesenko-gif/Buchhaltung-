import 'package:flutter/material.dart';

import '../../services/rules_freshness.dart';
import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../domain/company_profile.dart';
import '../../domain/money.dart';
import '../../services/levies/levy_estimator.dart';
import '../../services/levies/levy_overview.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/common.dart';
import '../../widgets/primary_action_bar.dart';
import '../help/help_screen.dart';

/// „Abgaben & Rücklagen“ (FA-19.1 bis FA-19.6): Jahresschätzung je Abgabe,
/// bisher bezahlt, nächste Zahlungen, Angaben der Nutzerin.
///
/// Länderunterschiede kommen ausschließlich aus `TaxProfile.levies` (GR-5):
/// welche Angaben gefragt werden, entscheidet, welche Regeln vorhanden sind.
class LeviesScreen extends StatefulWidget {
  const LeviesScreen({super.key});

  @override
  State<LeviesScreen> createState() => _LeviesScreenState();
}

class _LeviesScreenState extends State<LeviesScreen> {
  LevyOverview? _overview;
  LevySettings _settings = const LevySettings();
  final _prepayment = TextEditingController();
  final _health = TextEditingController();
  final _multiplier = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(fill: true));
  }

  @override
  void dispose() {
    _prepayment.dispose();
    _health.dispose();
    _multiplier.dispose();
    super.dispose();
  }

  Future<void> _load({bool fill = false}) async {
    final state = AppScope.read(context);
    final profile = state.profile;
    if (profile == null) return;
    final overview = await LevyOverview.load(
      repos: state.repositories,
      profile: profile,
      today: DateTime.now(),
    );
    if (!mounted) return;
    setState(() {
      _overview = overview;
      if (fill) {
        _settings = overview.settings;
        String amount(Money m) => m.isZero ? '' : Fmt.amount(m);
        _prepayment.text = amount(_settings.incomeTaxPrepaymentQuarter);
        _health.text = amount(_settings.healthInsuranceMonthly);
        _multiplier.text =
            _settings.tradeTaxMultiplierPercent?.toString() ?? '';
      }
    });
  }

  Future<void> _save() async {
    final state = AppScope.read(context);
    setState(() => _saving = true);
    final settings = _settings.copyWith(
      incomeTaxPrepaymentQuarter:
          Money.tryParse(_prepayment.text) ?? const Money.zero(),
      healthInsuranceMonthly:
          Money.tryParse(_health.text) ?? const Money.zero(),
      tradeTaxMultiplierPercent: int.tryParse(_multiplier.text.trim()),
    );
    await state.repositories.levySettings.save(settings);
    _settings = settings;
    await _load();
    if (!mounted) return;
    setState(() => _saving = false);
    showSnack(context, 'Angaben gespeichert');
  }

  @override
  Widget build(BuildContext context) {
    final profile = AppScope.of(context).profile;
    final overview = _overview;
    final rules = profile?.taxProfile.levies;
    final estimate = overview?.estimate;
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Abgaben & Rücklagen'),
        actions: const [HelpButton()],
      ),
      body: ReadableWidth(
        child: estimate == null || rules == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  const NoticeBanner(
                    icon: Icons.warning_amber_outlined,
                    message:
                        '${LevyEstimator.disclaimer}. Hochgerechnet '
                        'aus deinen bisherigen Buchungen dieses Jahres.',
                  ),
                  // Regelstand abgelaufen (FA-21.3).
                  if (profile != null &&
                      RulesFreshness.estimateNote(
                            profile.taxProfile,
                            DateTime.now().year,
                          ) !=
                          null) ...[
                    const SizedBox(height: 8),
                    NoticeBanner(
                      key: const Key('levy-rules-outdated'),
                      icon: Icons.update,
                      message: RulesFreshness.estimateNote(
                        profile.taxProfile,
                        DateTime.now().year,
                      )!,
                    ),
                  ],
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Rücklage',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${Fmt.money(estimate.monthlyReserve)} pro Monat',
                          key: const Key('levy-monthly'),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Noch offen dieses Jahr: '
                          '${Fmt.money(estimate.totalOpen)} · '
                          'bezahlt: ${Fmt.money(estimate.totalPaid)}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Jahr ${DateTime.now().year} – Schätzung',
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gewinn hochgerechnet: '
                          '${Fmt.money(estimate.projectedProfit)}',
                          style: muted,
                        ),
                        for (final line in estimate.lines)
                          ListTile(
                            key: Key('levy-${line.key}'),
                            contentPadding: EdgeInsets.zero,
                            minVerticalPadding: 8,
                            title: Text(line.label),
                            subtitle: Text(
                              'bezahlt ${Fmt.money(line.paid)} · offen '
                              '${Fmt.money(line.open)}'
                              '${line.note == null ? '' : '\n${line.note}'}',
                            ),
                            trailing: Text(Fmt.money(line.year)),
                            onTap: () => showSnack(
                              context,
                              'Grundlage: ${line.legalRef}',
                            ),
                          ),
                        for (final hint in estimate.hints)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, right: 8),
                            child: Text(hint, style: muted),
                          ),
                      ],
                    ),
                  ),
                  if (overview!.payments.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SectionCard(
                      title: 'Nächste Zahlungen',
                      padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                      child: Column(
                        children: [
                          for (final p in overview.payments)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.event_outlined),
                              title: Text(p.deadline.label),
                              subtitle: Text(
                                '${p.deadline.approximate ? 'ca. ' : ''}'
                                '${Fmt.date(p.deadline.date)}',
                              ),
                              trailing: p.amount == null
                                  ? null
                                  : Text(Fmt.money(p.amount!)),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Deine Angaben',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MoneyField(
                          key: const Key('levy-prepayment'),
                          controller: _prepayment,
                          label: 'ESt-Vorauszahlung je Quartal (Bescheid)',
                        ),
                        if (rules.socialInsurance != null)
                          SwitchListTile(
                            key: const Key('levy-exempt'),
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Ausnahme von KV/PV beantragt '
                              '(Kleinunternehmerin)',
                            ),
                            value: _settings.socialInsuranceExempt,
                            onChanged: (v) => setState(
                              () => _settings = _settings.copyWith(
                                socialInsuranceExempt: v,
                              ),
                            ),
                          )
                        else ...[
                          const SizedBox(height: 12),
                          MoneyField(
                            key: const Key('levy-health'),
                            controller: _health,
                            label: '${rules.socialInsuranceLabel} monatlich',
                          ),
                        ],
                        if (rules.tradeTax != null) ...[
                          SwitchListTile(
                            key: const Key('levy-freelancer'),
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Freiberuflich (keine Gewerbesteuer)',
                            ),
                            value:
                                _settings.freelancer ??
                                profile!.legalForm == LegalForm.freelancer,
                            onChanged: (v) => setState(
                              () =>
                                  _settings = _settings.copyWith(freelancer: v),
                            ),
                          ),
                          TextField(
                            key: const Key('levy-multiplier'),
                            controller: _multiplier,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Hebesatz der Gemeinde in %',
                              hintText:
                                  '${rules.tradeTax!.defaultMultiplierPercent}',
                            ),
                          ),
                        ],
                        if (rules.surcharges != null)
                          SwitchListTile(
                            key: const Key('levy-church'),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Kirchensteuerpflichtig'),
                            value: _settings.churchTax,
                            onChanged: (v) => setState(
                              () =>
                                  _settings = _settings.copyWith(churchTax: v),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: estimate == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: PrimaryActionBar.filled(
                  key: const Key('levy-save'),
                  label: 'Angaben speichern',
                  icon: Icons.check,
                  busy: _saving,
                  onPressed: _save,
                ),
              ),
            ),
    );
  }
}

/// Karte „Rücklage für Steuern & SV“ auf der Übersicht (FA-19.1).
class LevyReserveCard extends StatelessWidget {
  const LevyReserveCard({super.key, required this.estimate, this.onTap});

  final LevyEstimate estimate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Card(
      child: InkWell(
        key: const Key('levy-card'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Rücklage für Steuern & SV',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${Fmt.money(estimate.monthlyReserve)} pro Monat',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              for (final line in estimate.lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      Expanded(child: Text(line.label)),
                      Text('offen ${Fmt.money(line.open)}'),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              Text(LevyEstimator.disclaimer, style: muted),
            ],
          ),
        ),
      ),
    );
  }
}
