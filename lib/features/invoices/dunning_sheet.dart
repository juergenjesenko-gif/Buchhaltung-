import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../domain/customer.dart';
import '../../domain/dunning.dart';
import '../../domain/invoice.dart';
import '../../domain/money.dart';
import '../../services/dunning_calculator.dart';
import '../../services/dunning_pdf.dart';
import '../../services/dunning_service.dart';
import '../../services/invoice_seller.dart';
import '../../services/invoice_texts.dart';
import '../../services/licensing/license_policy.dart';
import '../pdf_viewer/pdf_viewer_screen.dart';
import '../licensing/feature_gate.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/primary_action_bar.dart';
import '../../domain/currency.dart';

/// Zahlungserinnerung bzw. Mahnung als Bottom-Sheet (L-3.10, L-3.27 bis
/// L-3.30): Vorschau mit Stufe, Frist, Kosten, Zinsen, Gesamt; ein Tipp auf
/// „Erstellen und senden“ öffnet den Teilen-Dialog. Liefert `true`, wenn
/// etwas erstellt oder storniert wurde.
Future<bool> showDunningSheet(
  BuildContext context, {
  required Invoice invoice,
  required Customer customer,
}) async {
  final state = AppScope.read(context);
  final notices = await state.repositories.dunning.forInvoice(invoice.id!);
  if (!context.mounted) return false;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) =>
        _DunningSheet(invoice: invoice, customer: customer, previous: notices),
  );
  return result ?? false;
}

class _DunningSheet extends StatefulWidget {
  const _DunningSheet({
    required this.invoice,
    required this.customer,
    required this.previous,
  });

  final Invoice invoice;
  final Customer customer;
  final List<DunningNotice> previous;

  @override
  State<_DunningSheet> createState() => _DunningSheetState();
}

class _DunningSheetState extends State<_DunningSheet> {
  final _fee = TextEditingController();
  final _rate = TextEditingController();
  late DateTime _newDue;
  bool _interest = false;
  bool _flatFee = false;
  bool _busy = false;
  bool _initialized = false;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  int get _level => DunningService.nextLevel(widget.previous);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final profile = AppScope.read(context).profile!;
    final rules = profile.taxProfile.dunning;
    _newDue = _today.add(Duration(days: profile.dunningPeriodDays));
    _fee.text = Fmt.amount(
      DunningCalculator.suggestedFee(_level, profile.dunningFee),
    );
    _interest = profile.dunningInterest;
    _flatFee = profile.dunningFlatFee && widget.customer.isBusiness;
    _rate.text = DunningCalculator.rateText(
      rules.statutoryRateBp(business: widget.customer.isBusiness, date: _today),
    ).replaceAll(' %', '');
  }

  @override
  void dispose() {
    _fee.dispose();
    _rate.dispose();
    super.dispose();
  }

  DunningDraft _draft() {
    final profile = AppScope.read(context).profile!;
    return DunningService.compose(
      invoice: widget.invoice,
      previous: widget.previous,
      rules: profile.taxProfile.dunning,
      business: widget.customer.isBusiness,
      issuedOn: _today,
      newDueDate: _newDue,
      fee: Money.tryParse(_fee.text) ?? const Money.zero(),
      withInterest: _interest,
      rateBp: DunningCalculator.parseRate(_rate.text),
      withFlatFee: _flatFee,
    );
  }

  Future<void> _create() async {
    // Demo (FA-13.14): kein Mahnschreiben speichern.
    if (!await ensureWritable(context)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    final state = AppScope.read(context);
    final profile = state.profile!;
    var notice = _draft().notice;
    try {
      final bytes = await DunningPdf(
        notice: notice,
        invoice: widget.invoice,
        customer: widget.customer,
        profile: InvoiceSeller.profileFor(widget.invoice, profile),
      ).build();
      final hash = await DunningPdf.sha256Hex(bytes);
      notice = DunningNotice.fromMap({
        ...notice.toMap(),
        'pdf_sha256': hash,
        'invoice_id': widget.invoice.id,
      });
      await state.repositories.dunning.insert(notice);
      final safe = widget.invoice.number.replaceAll(
        RegExp(r'[^A-Za-z0-9\-_]'),
        '-',
      );
      if (!mounted) return;
      await openPdfViewer(
        context,
        title: '${notice.title} zu ${widget.invoice.number}',
        sendFeature: Feature.dunningSending,
        fileName: '${notice.title.replaceAll(' ', '_')}_$safe.pdf',
        bytes: bytes,
        subject: '${notice.title} zu Rechnung ${widget.invoice.number}',
        text: InvoiceTexts.shareDunning(notice.title, widget.invoice.number),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, 'Mahnung konnte nicht erstellt werden: $error');
      }
    }
  }

  Future<void> _cancel(DunningNotice notice) async {
    final reason = TextEditingController();
    final error = Theme.of(context).colorScheme.error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${notice.title} stornieren?'),
          content: TextField(
            key: const Key('dunningCancelReason'),
            controller: reason,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Begründung'),
            onChanged: (_) => setDialogState(() {}),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: error),
              onPressed: reason.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(true),
              child: const Text('Stornieren'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await AppScope.read(
      context,
    ).repositories.dunning.cancel(notice.id!, reason.text);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final profile = AppScope.of(context).profile!;
    final rules = profile.taxProfile.dunning;
    final business = widget.customer.isBusiness;
    final draft = _draft();
    final notice = draft.notice;
    final theme = Theme.of(context);
    final fee = Money.tryParse(_fee.text) ?? const Money.zero();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Text(
                    '${notice.title} zu ${widget.invoice.number}',
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    '${widget.customer.name} · '
                    '${business ? 'Unternehmen' : 'Privatkunde'}',
                    style: theme.textTheme.bodySmall,
                  ),
                  for (final previous in widget.previous)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${previous.title} vom ${Fmt.date(previous.issuedOn)}',
                        style: previous.isCancelled
                            ? const TextStyle(
                                decoration: TextDecoration.lineThrough,
                              )
                            : null,
                      ),
                      subtitle: Text(
                        previous.isCancelled
                            ? 'Storniert: ${previous.cancelReason}'
                            : '${Fmt.money(previous.total)}, Frist '
                                  '${Fmt.date(previous.newDueDate)}',
                      ),
                      trailing: previous.isCancelled
                          ? null
                          : TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: theme.colorScheme.error,
                                minimumSize: const Size(48, 48),
                              ),
                              onPressed: () => _cancel(previous),
                              child: const Text('Stornieren'),
                            ),
                    ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Neue Zahlungsfrist'),
                    subtitle: Text(Fmt.date(_newDue)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _newDue,
                        firstDate: _today,
                        lastDate: _today.add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _newDue = picked);
                    },
                  ),
                  TextField(
                    key: const Key('dunningFee'),
                    controller: _fee,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      labelText: 'Mahnkosten (nicht umsatzsteuerbar)',
                      suffixText: Currency.home.symbol,
                      helperText: _level <= 1
                          ? 'Die Zahlungserinnerung ist üblicherweise kostenlos'
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (!business && !fee.isZero) ...[
                    const SizedBox(height: 8),
                    NoticeBanner(
                      key: const Key('consumerFeeHint'),
                      icon: Icons.info_outline,
                      color: AppTheme.warning,
                      message: DunningService.consumerFeeHint,
                    ),
                  ],
                  SwitchListTile(
                    key: const Key('dunningInterest'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Verzugszinsen'),
                    subtitle: Text(
                      'Vorschlag: gesetzlicher Satz '
                      '(${rules.interestLegalRef(business: business)})',
                    ),
                    value: _interest,
                    onChanged: (value) => setState(() => _interest = value),
                  ),
                  if (_interest)
                    TextField(
                      controller: _rate,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        labelText: 'Zinssatz pro Jahr',
                        suffixText: '%',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  if (business)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Pauschale ${Fmt.money(rules.flatFee)}'),
                      subtitle: Text(rules.flatFeeLegalRef),
                      value: _flatFee,
                      onChanged: (value) => setState(() => _flatFee = value),
                    ),
                  const Divider(height: 24),
                  for (final (label, amount) in DunningPdf.rows(
                    notice,
                    rules,
                    business: business,
                  ))
                    LabeledValue(label: label, value: Fmt.money(amount)),
                  LabeledValue(
                    label: 'Gesamt',
                    value: Fmt.money(notice.total),
                    emphasize: true,
                  ),
                  const SizedBox(height: 8),
                  Text(notice.text, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            PrimaryActionBar(
              primary: PrimaryActionBar.filled(
                key: const Key('dunningCreate'),
                label: proLabel(
                  context,
                  Feature.dunningSending,
                  '${notice.title} erstellen und senden',
                ),
                icon: Icons.send_outlined,
                busy: _busy,
                onPressed: _create,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
