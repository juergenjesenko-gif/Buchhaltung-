import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../data/repositories.dart';
import '../../domain/receipt.dart';
import '../../services/export/exporters.dart';
import '../../services/share_service.dart';
import '../../widgets/common.dart';

/// Export an die Steuerberatung.
///
/// Zeitraum wählen, Format wählen, teilen. Die Vorschau zeigt vorab, wie viele
/// Belege und welche Summen in der Datei landen – ein Export, bei dem man erst
/// nach dem Versand merkt, dass er leer war, ist wertlos.
class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  late int _year;
  int? _quarter;
  int? _month;

  PeriodTotals? _totals;
  List<Receipt> _receipts = const [];
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Period get _period {
    if (_month != null) return Period.month(DateTime(_year, _month!, 1));
    if (_quarter != null) return Period.quarter(_year, _quarter!);
    return Period.year(_year);
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final state = AppScope.read(context);
    final period = _period;
    final totals = await state.repositories.receipts.totals(
      from: period.from,
      to: period.to,
    );
    final receipts = await state.repositories.receipts.query(
      from: period.from,
      to: period.to,
    );
    if (!mounted) return;
    setState(() {
      _totals = totals;
      _receipts = receipts;
      _loading = false;
    });
  }

  Future<void> _export(ExportFormat format) async {
    final state = AppScope.read(context);
    final profile = state.profile;
    final totals = _totals;
    if (profile == null || totals == null) return;

    setState(() => _exporting = true);
    try {
      final result = Exporter(
        profile: profile,
        receipts: _receipts,
        categories: state.categories,
        totals: totals,
        period: _period,
      ).build(format);

      await ShareService.shareCsv(
        fileName: result.fileName,
        content: result.content,
        subject: '${format.label} – ${profile.companyName} – ${_period.label}',
      );
    } on Exception catch (error) {
      if (mounted) showSnack(context, 'Export fehlgeschlagen: $error');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final profile = state.profile;
    final totals = _totals;
    final relevantFormats = _formatsFor(state);

    return Scaffold(
      appBar: AppBar(title: const Text('Export')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          SectionCard(
            title: 'Zeitraum',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _year,
                        decoration: const InputDecoration(labelText: 'Jahr'),
                        items: [
                          for (
                            var year = DateTime.now().year;
                            year >= DateTime.now().year - 7;
                            year--
                          )
                            DropdownMenuItem(value: year, child: Text('$year')),
                        ],
                        onChanged: (value) {
                          setState(() => _year = value ?? _year);
                          _load();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Eingrenzen',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Ganzes Jahr'),
                      selected: _quarter == null && _month == null,
                      onSelected: (_) {
                        setState(() {
                          _quarter = null;
                          _month = null;
                        });
                        _load();
                      },
                    ),
                    for (var quarter = 1; quarter <= 4; quarter++)
                      ChoiceChip(
                        label: Text('Q$quarter'),
                        selected: _quarter == quarter,
                        onSelected: (_) {
                          setState(() {
                            _quarter = quarter;
                            _month = null;
                          });
                          _load();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var month = 1; month <= 12; month++)
                      ChoiceChip(
                        label: Text(
                          Fmt.shortMonth(
                            DateTime(_year, month, 1),
                          ).split(' ').first,
                        ),
                        selected: _month == month,
                        onSelected: (_) {
                          setState(() {
                            _month = month;
                            _quarter = null;
                          });
                          _load();
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SectionCard(
            title: 'Vorschau – ${_period.label}',
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : totals == null
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      LabeledValue(
                        label: 'Belege',
                        value: '${_receipts.length}',
                      ),
                      LabeledValue(
                        label: 'Einnahmen netto',
                        value: Fmt.money(totals.incomeNet),
                      ),
                      LabeledValue(
                        label: 'Ausgaben netto',
                        value: Fmt.money(totals.expenseNet),
                      ),
                      if (!(profile?.isSmallBusiness ?? true)) ...[
                        LabeledValue(
                          label: 'Umsatzsteuer',
                          value: Fmt.money(totals.incomeVat),
                        ),
                        LabeledValue(
                          label: 'Vorsteuer',
                          value: Fmt.money(totals.expenseVat),
                        ),
                      ],
                      const Divider(height: 20),
                      LabeledValue(
                        label: 'Ergebnis netto',
                        value: Fmt.signedMoney(totals.profit),
                        emphasize: true,
                      ),
                      if (_receipts.isEmpty) ...[
                        const SizedBox(height: 12),
                        const NoticeBanner(
                          icon: Icons.inbox_outlined,
                          message:
                              'In diesem Zeitraum gibt es keine Belege. '
                              'Der Export wäre leer.',
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          SectionCard(
            title: 'Format wählen',
            child: Column(
              children: [
                for (final format in relevantFormats)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(format.label),
                      subtitle: Text(format.description),
                      trailing: const Icon(Icons.ios_share),
                      enabled: !_exporting && _receipts.isNotEmpty,
                      onTap: () => _export(format),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const NoticeBanner(
            icon: Icons.info_outline,
            message:
                'Die Exporte sind Vorlagen für die Übergabe an die Kanzlei. '
                'Kontonummern und Steuercodes stimmst du am besten einmalig mit '
                'deiner Steuerberatung ab – jede Kanzlei bucht ein wenig anders.',
          ),
        ],
      ),
    );
  }

  /// DATEV ist ein deutsches, BMD ein österreichisches Format. Beide anzubieten
  /// wäre nur Rauschen – die App kennt das Land des Nutzers.
  List<ExportFormat> _formatsFor(AppState state) {
    final country = state.profile?.country;
    return [
      ExportFormat.plainCsv,
      if (country?.code == 'DE') ExportFormat.datev,
      if (country?.code == 'AT') ExportFormat.bmd,
      ExportFormat.vatReturn,
    ];
  }
}
