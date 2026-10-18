import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../domain/platform_import.dart';
import '../../services/launcher/open_url.dart';
import '../../services/platform_import/platform_import_plan.dart';
import '../../widgets/common.dart';
import '../../widgets/primary_action_bar.dart';

/// Plattformexport übernehmen (L-28.2): eine Zusammenfassung je Monat und
/// ein Knopf „Übernehmen“ unten in Daumenreichweite. Keine Rückfragen je
/// Zeile; Dubletten werden still übersprungen.
class PlatformImportScreen extends StatefulWidget {
  const PlatformImportScreen({super.key, required this.file});

  final PlatformImportFile file;

  @override
  State<PlatformImportScreen> createState() => _PlatformImportScreenState();
}

class _PlatformImportScreenState extends State<PlatformImportScreen> {
  PlatformImportPlan? _plan;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final state = AppScope.read(context);
    final profile = state.profile;
    final repo = state.repositories.platformImports;
    final known = await repo.knownIds(widget.file.platform);
    final formats = await repo.formatsByMonth(widget.file.platform);
    if (!mounted || profile == null) return;
    setState(() {
      _plan = PlatformImportPlanner.plan(
        file: widget.file,
        knownIds: known,
        country: profile.country,
        isSmallBusiness: profile.isSmallBusiness,
        otherFormatMonths: formats,
        registrations: state.registrations,
      );
    });
  }

  Future<void> _commit() async {
    final plan = _plan;
    if (plan == null) return;
    setState(() => _saving = true);
    final state = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    int? categoryOf(String name) {
      for (final c in state.categories) {
        if (c.name == name) return c.id;
      }
      return null;
    }

    final count = await state.repositories.platformImports.commit(
      format: plan.file.format,
      bookings: [
        for (final d in plan.drafts)
          (
            receipt: d.receipt,
            categoryId: categoryOf(d.categoryName),
            ids: d.entryIds,
          ),
      ],
      entries: [
        for (final e in plan.newEntries)
          (id: e.externalId, month: PlatformImportPlanner.monthKey(e.date)),
      ],
    );
    await state.onBookingsChanged();
    messenger.showSnackBar(
      SnackBar(content: Text('$count Buchungen übernommen')),
    );
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final profile = AppScope.of(context).profile;
    final title = '${widget.file.platform.label} – ${widget.file.format.label}';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: plan == null || profile == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                for (final m in plan.months)
                  _MonthCard(
                    summary: m,
                    label: PlatformImportPlanner.monthLabel(
                      m.month,
                      profile.country.taxProfile,
                    ),
                    feeNote: plan.feeSupplier.isReverseCharge
                        ? 'Reverse Charge'
                        : 'steuerfrei',
                  ),
                if (plan.duplicates > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '${plan.duplicates} Zeilen waren schon übernommen '
                      'und werden übersprungen.',
                      key: const Key('platform-import-duplicates'),
                    ),
                  ),
                for (final w in plan.warnings)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(w)),
                      ],
                    ),
                  ),
                if (plan.file.platform == SalesPlatform.amazon)
                  SectionCard(
                    title: 'Gebührenrechnung als Beleg ablegen',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Amazon stellt die Gebühren monatlich in Rechnung. '
                          'Die Rechnung aus Seller Central (Berichte → '
                          'Steuerdokumente → Gebührenrechnungen) als PDF an '
                          'die App teilen – sie wird eigener Beleg.',
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          key: const Key('platform-import-fee-invoices'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                          onPressed: () =>
                              openInBrowser(Uri.parse(amazonFeeInvoiceUrl)),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Gebührenrechnungen öffnen'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: plan == null
          ? null
          : PrimaryActionBar(
              note: plan.hasAnythingNew
                  ? '${plan.drafts.length} Buchungen; Auszahlungen sind nur '
                        'Geldtransfer und werden nicht gebucht.'
                  : 'Alles schon übernommen.',
              primary: PrimaryActionBar.filled(
                key: const Key('platform-import-commit'),
                label: 'Übernehmen',
                icon: Icons.check,
                busy: _saving,
                onPressed: plan.hasAnythingNew ? _commit : null,
              ),
            ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.summary,
    required this.label,
    required this.feeNote,
  });

  final PlatformMonthSummary summary;
  final String label;
  final String feeNote;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        title: label,
        child: Column(
          children: [
            Text(
              platformMonthLine(s, label, feeNote),
              key: Key('platform-import-month-${s.month.month}'),
            ),
            const SizedBox(height: 8),
            LabeledValue(
              label: '${s.saleCount} Verkäufe',
              value: Fmt.money(s.salesTotal),
            ),
            if (!s.fees.isZero)
              LabeledValue(
                label: 'Gebühren ($feeNote)',
                value: Fmt.money(s.fees),
              ),
            if (!s.advertising.isZero)
              LabeledValue(
                label: 'Werbung ($feeNote)',
                value: Fmt.money(s.advertising),
              ),
            if (!s.payout.isZero)
              LabeledValue(label: 'Auszahlung', value: Fmt.money(s.payout)),
            if (s.newEntries == 0)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Schon übernommen'),
              ),
          ],
        ),
      ),
    );
  }
}

/// „März 2026: 42 Verkäufe 1.230,00 €, Gebühren 210,00 € (Reverse Charge),
/// Auszahlung 1.020,00 €“.
String platformMonthLine(PlatformMonthSummary s, String label, String feeNote) {
  final parts = <String>[
    '${s.saleCount} Verkäufe ${Fmt.money(s.salesTotal)}',
    if (!s.fees.isZero) 'Gebühren ${Fmt.money(s.fees)} ($feeNote)',
    if (!s.advertising.isZero) 'Werbung ${Fmt.money(s.advertising)}',
    if (!s.payout.isZero) 'Auszahlung ${Fmt.money(s.payout)}',
  ];
  return '$label: ${parts.join(', ')}';
}
