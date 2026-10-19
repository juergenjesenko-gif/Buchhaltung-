import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../data/repositories.dart';
import '../../domain/country.dart';
import '../../domain/tax_registration.dart';
import '../../services/launcher/open_url.dart';
import '../../services/licensing/license_policy.dart';
import '../../services/share_service.dart';
import '../../services/tax_office/u30_xml.dart';
import '../../services/tax_office/vat_return_figures.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/common.dart';
import '../../widgets/primary_action_bar.dart';
import '../help/help_screen.dart';
import '../levies/levies_screen.dart';
import '../licensing/feature_gate.dart';

/// „Für das Finanzamt“ (FA-14.1 bis FA-14.8): Kennzahlen der Voranmeldung
/// und der Jahreserklärung zum Kopieren mit einem Tipp; in Österreich die
/// U30-Datei zum Hochladen in FinanzOnline (Pro).
class TaxOfficeScreen extends StatefulWidget {
  const TaxOfficeScreen({super.key});

  @override
  State<TaxOfficeScreen> createState() => _TaxOfficeScreenState();
}

class _TaxOfficeScreenState extends State<TaxOfficeScreen> {
  late int _year;
  int? _quarter;
  int? _month;
  PeriodTotals? _totals;
  PeriodTotals? _yearTotals;
  bool _loading = true;
  bool _sharing = false;

  /// Steuerland der Voranmeldung (FA-18.4): `null` = Heimat.
  int? _registrationId;

  @override
  void initState() {
    super.initState();
    // Vorbelegt: das zuletzt abgeschlossene Quartal (Leitprinzip).
    final now = DateTime.now();
    final currentQuarter = (now.month - 1) ~/ 3 + 1;
    if (currentQuarter == 1) {
      _year = now.year - 1;
      _quarter = 4;
    } else {
      _year = now.year;
      _quarter = currentQuarter - 1;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  int get _fromMonth => _month ?? (_quarter! - 1) * 3 + 1;
  int get _toMonth => _month ?? _quarter! * 3;

  Period get _period => _month != null
      ? Period.month(DateTime(_year, _month!, 1))
      : Period.quarter(_year, _quarter!);

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final state = AppScope.read(context);
    final profile = state.profile;
    final period = _period;
    final yearPeriod = profile == null
        ? Period.year(_year)
        : Period.fiscalYear(
            profile.fiscalYear,
            _year,
            profile.taxProfile.monthNames,
          );
    final receipts = state.repositories.receipts;
    final registrations = state.registrations;
    final reg = state.registrationById(_registrationId);
    // Voranmeldung je Steuerland mit dessen Vorsteuerabzug (FA-18.4).
    final totals = await receipts.totals(
      from: period.from,
      to: period.to,
      inputVatDeductible: reg == null
          ? state.inputVatDeductible
          : !reg.isSmallBusiness,
      reverseChargePermille: reg == null
          ? state.reverseChargePermille
          : reg.taxProfile.standardVatPermille,
      depreciation: reg == null ? state.depreciationRules : null,
      entertainment: state.entertainmentRules,
      nonDeductibleKinds: state.nonDeductibleKinds,
      scope: reg != null
          ? RegistrationScope.of(reg.id!)
          : registrations.isEmpty
          ? RegistrationScope.all
          : RegistrationScope.home,
    );
    // Gewinnermittlung (E1a/EÜR) immer im Heimatland über alle Steuerländer,
    // je Land mit dessen Vorsteuerabzug (FA-18.8).
    var yearTotals = await receipts.totals(
      from: yearPeriod.from,
      to: yearPeriod.to,
      inputVatDeductible: state.inputVatDeductible,
      reverseChargePermille: state.reverseChargePermille,
      depreciation: state.depreciationRules,
      entertainment: state.entertainmentRules,
      nonDeductibleKinds: state.nonDeductibleKinds,
      scope: registrations.isEmpty
          ? RegistrationScope.all
          : RegistrationScope.home,
    );
    for (final r in registrations) {
      yearTotals += await receipts.totals(
        from: yearPeriod.from,
        to: yearPeriod.to,
        inputVatDeductible: !r.isSmallBusiness,
        reverseChargePermille: r.taxProfile.standardVatPermille,
        entertainment: state.entertainmentRules,
        nonDeductibleKinds: state.nonDeductibleKinds,
        scope: RegistrationScope.of(r.id!),
      );
    }
    if (!mounted) return;
    setState(() {
      _totals = totals;
      _yearTotals = yearTotals;
      _loading = false;
    });
  }

  Future<void> _copy(KennzahlLine line) async {
    await Clipboard.setData(ClipboardData(text: line.copyText));
    if (!mounted) return;
    showSnack(
      context,
      line.kz == null
          ? '${line.copyText} kopiert'
          : 'Kz ${line.kz}: ${line.copyText} kopiert',
    );
  }

  Future<void> _shareFile(VatReturnFigures figures, String fastNr) async {
    if (!await ensureFeature(context, Feature.taxOfficeSubmission)) return;
    if (!mounted) return;
    setState(() => _sharing = true);
    try {
      final xml = U30Xml.build(
        figures: figures,
        fastNr: fastNr,
        year: _year,
        fromMonth: _fromMonth,
        toMonth: _toMonth,
        createdAt: DateTime.now(),
      );
      await ShareService.shareXml(
        fileName: U30Xml.fileName(_year, _fromMonth, _toMonth),
        content: xml,
        subject: 'UVA ${_period.label}',
      );
    } on Exception catch (error) {
      if (mounted) showSnack(context, 'Datei nicht erstellt: $error');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final profile = state.profile;
    final totals = _totals;
    final yearTotals = _yearTotals;
    if (profile == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final home = profile.taxProfile;
    final reg = state.registrationById(_registrationId);
    final tax = reg?.taxProfile ?? home;
    final smallBusiness = reg?.isSmallBusiness ?? profile.isSmallBusiness;
    final form = tax.vatReturnForm;
    final figures = totals == null
        ? null
        : VatReturnCalculator.build(
            totals: totals,
            tax: tax,
            smallBusiness: smallBusiness,
          );
    final fastNr = U30Xml.fastNr(reg?.taxNumber ?? profile.taxNumber);
    final offersFile = form.file == VatReturnFile.u30Xml;
    final canShare = figures != null && figures.fileAvailable && fastNr != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Für das Finanzamt'),
        actions: const [HelpButton()],
      ),
      bottomNavigationBar: offersFile && (figures?.required ?? false)
          ? PrimaryActionBar(
              note: canShare
                  ? 'Datei teilen und in ${form.portalName} hochladen.'
                  : null,
              primary: PrimaryActionBar.filled(
                key: const Key('share-u30'),
                label: proLabel(
                  context,
                  Feature.taxOfficeSubmission,
                  '${form.formName}-Datei teilen',
                ),
                icon: Icons.upload_file,
                busy: _sharing,
                onPressed: canShare ? () => _shareFile(figures, fastNr) : null,
              ),
            )
          : null,
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // Abgaben & Rücklagen (FA-19.2): zweiter Einstieg neben der Übersicht.
            Card(
              child: ListTile(
                key: const Key('open-levies'),
                minVerticalPadding: 12,
                leading: const Icon(Icons.savings_outlined),
                title: Text(
                  proLabel(context, Feature.levyReserve, 'Abgaben & Rücklagen'),
                ),
                subtitle: const Text('Einkommensteuer, Sozialversicherung'),
                trailing: const Icon(Icons.chevron_right),
                // Nur Pro (O-43).
                onTap: () async {
                  if (!await ensureFeature(context, Feature.levyReserve) ||
                      !context.mounted) {
                    return;
                  }
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LeviesScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Zeitraum',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Steuerland nur bei mehreren Registrierungen (FA-18.4).
                  if (state.registrations.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          key: const Key('tax-office-home'),
                          label: Text(profile.country.label),
                          selected: _registrationId == null,
                          onSelected: (_) {
                            setState(() => _registrationId = null);
                            _load();
                          },
                        ),
                        for (final r in state.registrations)
                          ChoiceChip(
                            key: Key('tax-office-reg-${r.id}'),
                            label: Text(r.country.label),
                            selected: _registrationId == r.id,
                            onSelected: (_) {
                              setState(() => _registrationId = r.id);
                              _load();
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  DropdownButtonFormField<int>(
                    initialValue: _year,
                    decoration: const InputDecoration(labelText: 'Jahr'),
                    items: [
                      for (
                        var y = DateTime.now().year;
                        y >= DateTime.now().year - 7;
                        y--
                      )
                        DropdownMenuItem(value: y, child: Text('$y')),
                    ],
                    onChanged: (value) {
                      setState(() => _year = value ?? _year);
                      _load();
                    },
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var q = 1; q <= 4; q++)
                        ChoiceChip(
                          label: Text('Q$q'),
                          selected: _quarter == q,
                          onSelected: (_) {
                            setState(() {
                              _quarter = q;
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
                      for (var m = 1; m <= 12; m++)
                        ChoiceChip(
                          label: Text(
                            Fmt.shortMonth(
                              DateTime(_year, m, 1),
                            ).split(' ').first,
                          ),
                          selected: _month == m,
                          onSelected: (_) {
                            setState(() {
                              _month = m;
                              _quarter = (m - 1) ~/ 3 + 1;
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
            if (_loading || figures == null || yearTotals == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (!figures.required)
                NoticeBanner(
                  icon: Icons.check_circle_outline,
                  message: reg != null && reg.scheme != VatScheme.standard
                      ? 'In ${reg.country.label}: ${reg.scheme.label} – keine '
                            '${form.formName}. Bitte mit der Steuerberatung '
                            'abstimmen (Spezifikation 14, P-S69).'
                      : 'Als Kleinunternehmer (${tax.smallBusinessLegalRef}) '
                            'brauchst du keine ${form.formName}. Für dich zählen '
                            'die Jahreszahlen unten.',
                )
              else
                SectionCard(
                  title: '${form.formName} – ${_period.label}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tippe auf eine Zeile, um den Betrag zu kopieren.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      for (final line in figures.lines)
                        _KennzahlTile(line: line, onTap: () => _copy(line)),
                      if (form.wholeEuroBases)
                        Text(
                          'Bemessungsgrundlagen in vollen Euro. '
                          '${form.portalName} rechnet die Steuer selbst; '
                          'wenige Cent Abweichung sind normal.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              if (figures.required) ...[
                for (final blocker in figures.fileBlockers) ...[
                  const SizedBox(height: 12),
                  NoticeBanner(
                    icon: Icons.warning_amber_outlined,
                    message: blocker,
                  ),
                ],
                if (offersFile && fastNr == null) ...[
                  const SizedBox(height: 12),
                  const NoticeBanner(
                    icon: Icons.badge_outlined,
                    message:
                        'Für die Datei braucht es die Steuernummer mit '
                        'Finanzamtsnummer (9 Ziffern, z. B. 12 345/6789) im '
                        'Firmenprofil.',
                  ),
                ],
                if (reg != null) ...[
                  const SizedBox(height: 12),
                  NoticeBanner(
                    key: const Key('tax-office-transfer-hint'),
                    icon: Icons.warning_amber_outlined,
                    message: tax.warehouseTransferHint,
                  ),
                ],
                const SizedBox(height: 16),
                _StepsCard(form: form),
              ],
              const SizedBox(height: 16),
              SectionCard(
                title:
                    '${home.annualReturnForm.formName} – Jahr '
                    '${profile.fiscalYear.shortLabel(_year)}',
                child: Column(
                  children: [
                    for (final line in VatReturnCalculator.annual(
                      totals: yearTotals,
                      tax: home,
                      smallBusiness: profile.isSmallBusiness,
                    ))
                      _KennzahlTile(line: line, onTap: () => _copy(line)),
                    if (state.registrations.isNotEmpty)
                      Text(
                        'Alle Steuerländer zusammen: Den Gewinn erklärst du '
                        'nur in ${profile.country.label}.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const NoticeBanner(
                icon: Icons.info_outline,
                message:
                    'Die Zahlen kommen aus deinen Belegen. Die Meldung gibst '
                    'du selbst ab; im Zweifel frag deine Steuerberatung.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KennzahlTile extends StatelessWidget {
  const _KennzahlTile({required this.line, required this.onTap});

  final KennzahlLine line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: 12,
      leading: SizedBox(
        width: 56,
        child: Text(
          line.kz == null ? '' : 'Kz ${line.kz}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      title: Text(line.label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(line.wholeEuros ? '${line.copyText} €' : Fmt.money(line.amount)),
          const SizedBox(width: 8),
          const Icon(Icons.copy, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.form});

  final VatReturnForm form;

  @override
  Widget build(BuildContext context) {
    final steps = form.file == VatReturnFile.u30Xml
        ? [
            'Unten „${form.formName}-Datei teilen“ tippen und die Datei '
                'speichern.',
            '${form.portalName} öffnen und anmelden.',
            'Eingaben → Übermittlungen → Upload – Inhalt UVA wählen.',
            'Datei auswählen, senden und das Protokoll prüfen.',
          ]
        : [
            '${form.portalName} öffnen und anmelden.',
            'Formulare → Umsatzsteuer → Umsatzsteuer-Voranmeldung wählen.',
            'Je Kennzahl hier tippen und im Formular einfügen.',
            'Prüfen und absenden.',
          ];
    return SectionCard(
      title: 'So meldest du',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('${i + 1}. ${steps[i]}'),
            ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => openInBrowser(Uri.parse(form.portalUrl)),
            icon: const Icon(Icons.open_in_new),
            label: Text('${form.portalName} öffnen'),
          ),
        ],
      ),
    );
  }
}
