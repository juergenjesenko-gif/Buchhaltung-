import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../core/window_size.dart';
import '../../domain/company_profile.dart';
import '../../domain/country.dart';
import '../../domain/money.dart';
import '../../services/contact_format.dart';
import '../../services/invoice_numbering.dart';
import '../../services/licensing/license_policy.dart';
import '../../services/logo_store.dart';
import '../../services/turnover_basis.dart';
import '../../services/vat_id/vat_id_format.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/common.dart';
import '../backup/backup_screen.dart';
import '../demo/demo_screens.dart';
import '../demo/demo_sheet.dart';
import '../helper/helper_help_sheet.dart';
import '../helper/helper_pair_screen.dart';
import '../settings/tax_registration_screen.dart';
import 'company_setup_screen.dart' show logoBasisHint;
import 'consent_screen.dart';

/// Austauschbares Logo der Willkommensseite (FA-1.13). Das endgültige Logo
/// ersetzt nur diese Datei; Platzhalter ist Icon-Entwurf 1.
const brandLogoAsset = 'assets/brand/logo.png';

/// Seiten der Ersteinrichtung. [welcome] zählt nicht als Schritt.
enum SetupPage { welcome, consent, company, details, extras, subscription }

/// Was nach den Bestätigungen geschieht, je nach Knopf auf der
/// Willkommensseite.
enum _Intent { setup, demo, restore, helper }

/// Geführte Ersteinrichtung (FA-1.13, Rückmeldung Auftraggeber 2026-10-19):
/// Willkommensseite, dann bis zu fünf Schritte. Ein großer Knopf unten
/// (56 dp), „Später hinzufügen“ darüber getrennt (48 dp, 12 dp Abstand),
/// Zurück über die Kopfzeile und die Systemgeste. Der Schritt wird
/// gespeichert; nach dem Schließen geht es dort weiter.
///
/// Nach der Einrichtung bleiben Stammdaten und Einstellungen der Ort zum
/// Bearbeiten (unverändert).
class SetupWizard extends StatefulWidget {
  /// Unterzeile der Willkommensseite (Entscheidung 2026-10-19).
  static const welcomeSubline =
      'Rechnungswesen und Buchhaltung leicht gemacht. Ohne Vorwissen, nach '
      'den Regeln, die auch Profis anwenden.';

  /// Was die App kann – nur Gebautes (UWG). Jede Zeile passt auf 360 dp in
  /// eine Zeile (Rückmeldung Auftraggeber zu 0.30.0).
  static const welcomePoints = [
    (Icons.document_scanner_outlined, 'Belege scannen und auslesen'),
    (Icons.receipt_long_outlined, 'Rechnungen & E-Rechnungen schreiben'),
    (Icons.event_note_outlined, 'Verträge und Fristen im Blick'),
    (Icons.table_chart_outlined, 'Saldenliste und Jahresübersicht'),
  ];

  const SetupWizard({super.key});

  /// Höhe des Hauptknopfs.
  static const primaryHeight = 56.0;

  /// Abstand zwischen „Später hinzufügen“ und dem Hauptknopf.
  static const gap = 12.0;

  static const skipLabel = 'Später hinzufügen';

  /// Schritte mit Abo-Auswahl (`spec.setup_steps`); ohne sie einer weniger.
  static const steps = 5;

  @override
  State<SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends State<SetupWizard> {
  SetupPage _page = SetupPage.welcome;
  _Intent _intent = _Intent.setup;
  bool _initialized = false;
  bool _busy = false;

  final _companyForm = GlobalKey<FormState>();
  final _detailsForm = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _f = {
    for (final k in const [
      'companyName',
      'ownerName',
      'street',
      'postalCode',
      'city',
      'foundingYear',
      'openingPrevious',
      'openingCurrent',
      'vatId',
      'taxNumber',
      'registerNumber',
      'registerCourt',
      'email',
      'phone',
      'iban',
      'bic',
      'bankName',
    ])
      k: TextEditingController(),
  };
  Country _country = Country.at;
  LegalForm _legalForm = LegalForm.soleTrader;
  bool _smallBusiness = true;
  final DateTime _trackingStart = DateTime.now();
  Timer? _draftTimer;

  static const _draftKeys = [
    'companyName',
    'ownerName',
    'street',
    'postalCode',
    'city',
    'foundingYear',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final state = AppScope.read(context);
    final step = state.setupStep;
    if (step != null && !state.needsOnboarding) {
      _page = SetupPage.values[step.clamp(2, 5)];
      _fillFromProfile(state.profile!);
    }
    unawaited(_loadDraft());
  }

  Future<void> _loadDraft() async {
    final raw = await AppScope.read(context).loadSetupDraft();
    if (raw == null || !mounted) return;
    try {
      final map = (jsonDecode(raw) as Map).cast<String, Object?>();
      setState(() {
        // Entwurf vorhanden und schon bestätigt: bei Schritt 2 weitermachen.
        if (_page == SetupPage.welcome &&
            AppScope.read(context).missingConsents.isEmpty) {
          _page = SetupPage.company;
        }
        for (final k in _draftKeys) {
          final v = map[k];
          if (v is String && _f[k]!.text.isEmpty) _f[k]!.text = v;
        }
        _country = Country.fromCode(map['country'] as String? ?? 'AT');
        _legalForm = LegalForm.values.firstWhere(
          (l) => l.name == map['legalForm'],
          orElse: () => LegalForm.soleTrader,
        );
        _smallBusiness = map['smallBusiness'] as bool? ?? true;
      });
    } on Object {
      // Unlesbarer Entwurf: leer beginnen.
    }
  }

  /// Entwurf von Schritt 2 sichern, damit eine geschlossene App die Eingaben
  /// nicht verliert (gebündelt, nicht bei jedem Tastendruck).
  void _scheduleDraft() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 500), _writeDraft);
  }

  Future<void> _writeDraft() async {
    if (!mounted) return;
    await AppScope.read(context).saveSetupDraft(
      jsonEncode({
        for (final k in _draftKeys) k: _f[k]!.text,
        'country': _country.code,
        'legalForm': _legalForm.name,
        'smallBusiness': _smallBusiness,
      }),
    );
  }

  void _fillFromProfile(CompanyProfile p) {
    _country = p.country;
    _legalForm = p.legalForm;
    _smallBusiness = p.isSmallBusiness;
    final values = {
      'companyName': p.companyName,
      'ownerName': p.ownerName,
      'street': p.street,
      'postalCode': p.postalCode,
      'city': p.city,
      'foundingYear': p.foundingYear?.toString() ?? '',
      'vatId': p.vatId,
      'taxNumber': p.taxNumber,
      'registerNumber': p.registerNumber,
      'registerCourt': p.registerCourt,
      'email': p.email,
      'phone': p.phone,
      'iban': p.iban,
      'bic': p.bic,
      'bankName': p.bankName,
    };
    values.forEach((k, v) => _f[k]!.text = v);
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    for (final c in _f.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _t(String key) => _f[key]!.text.trim();

  // ------------------------------------------------------------ Navigation

  bool get _hasSubscriptionStep {
    final state = AppScope.read(context);
    // Testbuild ohne Lizenzprüfung: Schritt entfällt automatisch.
    return state.license.enabled && !state.allows(Feature.newBookings);
  }

  int get _totalSteps =>
      _hasSubscriptionStep ? SetupWizard.steps : SetupWizard.steps - 1;

  Future<void> _go(SetupPage page) async {
    final state = AppScope.read(context);
    if (page.index >= SetupPage.details.index) {
      await state.setSetupStep(page.index);
    }
    if (!mounted) return;
    setState(() => _page = page);
  }

  Future<void> _back() async {
    switch (_page) {
      case SetupPage.welcome:
        return;
      case SetupPage.consent:
      case SetupPage.company:
        setState(() => _page = SetupPage.welcome);
      case SetupPage.details:
        setState(() => _page = SetupPage.company);
      case SetupPage.extras:
        await _go(SetupPage.details);
      case SetupPage.subscription:
        await _go(SetupPage.extras);
    }
  }

  Future<void> _finish() async {
    final state = AppScope.read(context);
    await state.saveSetupDraft(null);
    await state.setSetupStep(null);
  }

  Future<void> _afterExtras() async {
    if (_hasSubscriptionStep) {
      await _go(SetupPage.subscription);
    } else {
      await _finish();
    }
  }

  void _choose(_Intent intent) {
    _intent = intent;
    if (AppScope.read(context).missingConsents.isNotEmpty) {
      setState(() => _page = SetupPage.consent);
    } else {
      _runIntent();
    }
  }

  Future<void> _runIntent() async {
    switch (_intent) {
      case _Intent.setup:
        setState(() => _page = SetupPage.company);
      case _Intent.demo:
        setState(() {
          _page = SetupPage.welcome;
          _busy = true;
        });
        try {
          final state = AppScope.read(context);
          await startDemo(context, fromSettings: !state.license.enabled);
        } on Object {
          if (mounted) showSnack(context, 'Die Demo ließ sich nicht öffnen.');
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      case _Intent.restore:
        setState(() => _page = SetupPage.welcome);
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const BackupScreen()));
      case _Intent.helper:
        // Aus Schritt 2 heraus: der Assistent bleibt dort stehen.
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const HelperPairScreen()),
        );
    }
  }

  // ------------------------------------------------------------- Speichern

  int get _year => DateTime.now().year;
  int? get _foundingYear => int.tryParse(_t('foundingYear'));
  bool get _asksPrevious =>
      _foundingYear != _year &&
      TurnoverBasis.needsOpening(
        year: _year - 1,
        trackingStart: _trackingStart,
      );
  bool get _asksCurrent =>
      TurnoverBasis.needsOpening(year: _year, trackingStart: _trackingStart);

  String? _validateOpening(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Bitte angeben – 0, wenn es keinen Umsatz gab';
    final money = Money.tryParse(text);
    if (money == null) return 'Bitte einen Betrag eingeben';
    if (money.isNegative) return 'Der Umsatz kann nicht negativ sein';
    return null;
  }

  Future<void> _saveCompany() async {
    if (!_companyForm.currentState!.validate()) return;
    setState(() => _busy = true);
    final state = AppScope.read(context);
    final existing = state.profile;
    final base =
        existing ??
        CompanyProfile(
          companyName: '',
          country: _country,
          invoiceNumberPattern: InvoiceNumbering.defaultPattern,
          trackingStart: _trackingStart,
        );
    final profile = base.copyWith(
      companyName: _t('companyName'),
      ownerName: _t('ownerName'),
      country: _country,
      legalForm: _legalForm,
      street: _t('street'),
      postalCode: _t('postalCode'),
      city: _t('city'),
      isSmallBusiness: _smallBusiness,
      foundingYear: _foundingYear,
    );
    final openings = <int, Money?>{
      if (_smallBusiness && _asksPrevious)
        _year - 1: Money.tryParse(_t('openingPrevious')),
      if (_smallBusiness && _asksCurrent)
        _year: Money.tryParse(_t('openingCurrent')),
    };
    // Erst den Schritt merken, dann speichern: so bleibt die Einrichtung
    // sichtbar, sobald das Profil existiert.
    await state.setSetupStep(SetupPage.details.index);
    await state.saveProfileWithOpenings(profile, openings);
    _draftTimer?.cancel();
    await state.saveSetupDraft(null);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _page = SetupPage.details;
    });
  }

  Future<void> _saveDetails() async {
    if (!_detailsForm.currentState!.validate()) return;
    setState(() => _busy = true);
    final state = AppScope.read(context);
    await state.saveProfile(
      state.profile!.copyWith(
        vatId: VatIdFormat.normalize(_t('vatId')),
        taxNumber: _t('taxNumber'),
        registerNumber: _t('registerNumber'),
        registerCourt: _t('registerCourt'),
        email: _t('email'),
        phone: _t('phone'),
        iban: _t('iban').toUpperCase().replaceAll(' ', ''),
        bic: _t('bic').toUpperCase(),
        bankName: _t('bankName'),
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    await _go(SetupPage.extras);
  }

  Future<void> _pickLogo() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: LogoStore.maxEdgePx.toDouble(),
        maxHeight: LogoStore.maxEdgePx.toDouble(),
        imageQuality: LogoStore.qualityPercent,
      );
      if (picked == null || !mounted) return;
      final relative = await LogoStore.store(File(picked.path));
      if (!mounted) return;
      final state = AppScope.read(context);
      await state.saveProfile(state.profile!.copyWith(logoPath: relative));
    } on Exception catch (error) {
      if (mounted) {
        showSnack(context, 'Logo konnte nicht übernommen werden: $error');
      }
    }
  }

  // ----------------------------------------------------------------- Bauen

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return PopScope(
      canPop: _page == SetupPage.welcome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: switch (_page) {
        SetupPage.welcome => _welcome(context),
        SetupPage.consent => _scaffold(
          context,
          title: 'Bestätigungen',
          body: ConsentPanel(
            texts: state.missingConsents,
            header: _progress(context),
            onAccepted: _runIntent,
          ),
        ),
        SetupPage.company => _scaffold(
          context,
          title: 'Dein Unternehmen',
          body: _companyStep(context),
          primaryLabel: 'Weiter',
          primaryKey: const Key('setup-next'),
          onPrimary: _saveCompany,
        ),
        SetupPage.details => _scaffold(
          context,
          title: 'Zusatzdaten',
          body: _detailsStep(context),
          primaryLabel: 'Weiter',
          primaryKey: const Key('setup-next'),
          onPrimary: _saveDetails,
          onSkip: () => _go(SetupPage.extras),
        ),
        SetupPage.extras => _scaffold(
          context,
          title: 'Extras',
          body: _extrasStep(context),
          primaryLabel: _hasSubscriptionStep ? 'Weiter' : 'Fertig',
          primaryKey: const Key('setup-next'),
          onPrimary: _afterExtras,
          onSkip: _afterExtras,
        ),
        SetupPage.subscription => _scaffold(
          context,
          title: 'Abo wählen',
          body: _subscriptionStep(context),
          primaryLabel:
              'Abo wählen – ${LicensePolicy.trialDays} Tage kostenlos',
          primaryKey: const Key('setup-subscribe'),
          onPrimary: () async {
            await openPaywall(context);
            if (!mounted) return;
            if (AppScope.read(this.context).allows(Feature.newBookings)) {
              await _finish();
            }
          },
          skipLabel: 'Später entscheiden',
          onSkip: _finish,
        ),
      },
    );
  }

  Widget _progress(BuildContext context) {
    final step = _page.index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schritt $step von $_totalSteps',
            key: const Key('setup-progress'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: step / _totalSteps),
        ],
      ),
    );
  }

  Widget _scaffold(
    BuildContext context, {
    required String title,
    required Widget body,
    String? primaryLabel,
    Key? primaryKey,
    Future<void> Function()? onPrimary,
    String skipLabel = SetupWizard.skipLabel,
    Future<void> Function()? onSkip,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          key: const Key('setup-back'),
          tooltip: 'Zurück',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: _back,
          icon: const BackButtonIcon(),
        ),
      ),
      body: body,
      bottomNavigationBar: primaryLabel == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _BarWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (onSkip != null) ...[
                        TextButton(
                          key: const Key('setup-skip'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: _busy ? null : onSkip,
                          child: Text(skipLabel),
                        ),
                        const SizedBox(height: SetupWizard.gap),
                      ],
                      FilledButton(
                        key: primaryKey,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(
                            SetupWizard.primaryHeight,
                          ),
                        ),
                        onPressed: _busy || onPrimary == null
                            ? null
                            : onPrimary,
                        child: _busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(primaryLabel),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _welcome(BuildContext context) {
    final theme = Theme.of(context);
    Widget link(Key key, IconData icon, String label, _Intent intent) =>
        TextButton.icon(
          key: key,
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _busy ? null : () => _choose(intent),
          icon: Icon(icon),
          label: Text(label, textAlign: TextAlign.center),
        );
    return Scaffold(
      body: SafeArea(
        child: ReadableWidth(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Image.asset(
                              brandLogoAsset,
                              key: const Key('welcome-logo'),
                              width: 96,
                              height: 96,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.receipt_long, size: 96),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Willkommen bei JeNi bucht',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 20),
                        // Wortlaut geprüft (UWG § 2 AT / § 5 DE): kein
                        // unbelegbares Qualitätsversprechen („Qualität von
                        // Profis“), nur nachprüfbare Arbeitsweise.
                        Text(
                          SetupWizard.welcomeSubline,
                          key: const Key('welcome-subline'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 32),
                        for (final (icon, text) in SetupWizard.welcomePoints)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Icon(
                                  icon,
                                  size: 22,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    text,
                                    key: Key('welcome-point-$text'),
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const Spacer(),
                        const SizedBox(height: 16),
                        link(
                          const Key('welcome-restore'),
                          Icons.restore,
                          'Sicherung wiederherstellen',
                          _Intent.restore,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          key: const Key('welcome-demo'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(
                              SetupWizard.primaryHeight,
                            ),
                          ),
                          onPressed: _busy ? null : () => _choose(_Intent.demo),
                          icon: _busy
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.visibility_outlined),
                          label: const Text('Erst ansehen (Demo)'),
                        ),
                        const SizedBox(height: SetupWizard.gap),
                        FilledButton(
                          key: const Key('welcome-start'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(
                              SetupWizard.primaryHeight,
                            ),
                          ),
                          onPressed: _busy
                              ? null
                              : () => _choose(_Intent.setup),
                          child: const Text('Los geht\'s'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    String key,
    String label, {
    String? hint,
    String? helper,
    TextInputType? keyboard,
    TextCapitalization caps = TextCapitalization.none,
    String? Function(String?)? validator,
    bool draft = false,
    ValueChanged<String>? onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: Key('setup-$key'),
      controller: _f[key],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 2,
      ),
      keyboardType: keyboard,
      textCapitalization: caps,
      textInputAction: TextInputAction.next,
      validator: validator,
      onChanged: (v) {
        if (draft) _scheduleDraft();
        onChanged?.call(v);
      },
    ),
  );

  Widget _companyStep(BuildContext context) {
    final tax = _country.taxProfile;
    final theme = Theme.of(context);
    return Form(
      key: _companyForm,
      child: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _progress(context),
            // Mithelfer-Gerät: kleine Nebenoption statt Pflichtfrage – die
            // meisten richten ein Hauptgerät ein (UX-Instanz 0.31.0).
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    key: const Key('setup-helper'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      alignment: Alignment.centerLeft,
                    ),
                    onPressed: _busy ? null : () => _choose(_Intent.helper),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text(
                      'Dieses Gerät ist ein Mithelfer-Gerät (koppeln)',
                    ),
                  ),
                ),
                const HelperHelpButton(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Land des Unternehmenssitzes',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            SegmentedButton<Country>(
              key: const Key('setup-country'),
              style: SegmentedButton.styleFrom(minimumSize: const Size(0, 48)),
              segments: [
                for (final c in Country.values)
                  ButtonSegment(value: c, label: Text(c.label)),
              ],
              selected: {_country},
              onSelectionChanged: (s) {
                setState(() => _country = s.first);
                _scheduleDraft();
              },
            ),
            const SizedBox(height: 16),
            _field(
              'companyName',
              'Name oder Firma *',
              hint: 'z. B. Max Mustermann e.U.',
              caps: TextCapitalization.words,
              draft: true,
              validator: (v) => (v ?? '').trim().isEmpty
                  ? 'Bitte gib einen Namen oder eine Firma an'
                  : null,
            ),
            _field(
              'ownerName',
              'Inhaber:in',
              caps: TextCapitalization.words,
              draft: true,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<LegalForm>(
                key: const Key('setup-legal-form'),
                isExpanded: true,
                initialValue: _legalForm,
                decoration: const InputDecoration(labelText: 'Rechtsform'),
                items: [
                  for (final form in LegalForm.values)
                    DropdownMenuItem(value: form, child: Text(form.label)),
                ],
                onChanged: (v) {
                  setState(() => _legalForm = v ?? LegalForm.soleTrader);
                  _scheduleDraft();
                },
              ),
            ),
            _field(
              'street',
              'Straße und Hausnummer',
              caps: TextCapitalization.words,
              draft: true,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: _field(
                    'postalCode',
                    'PLZ',
                    keyboard: TextInputType.number,
                    draft: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    'city',
                    'Ort',
                    caps: TextCapitalization.words,
                    draft: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Besteuerung', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              key: const Key('setup-scheme'),
              style: SegmentedButton.styleFrom(minimumSize: const Size(0, 48)),
              segments: const [
                ButtonSegment(value: true, label: Text('Kleinunternehmer')),
                ButtonSegment(value: false, label: Text('Regelbesteuerung')),
              ],
              selected: {_smallBusiness},
              onSelectionChanged: (s) {
                setState(() => _smallBusiness = s.first);
                _scheduleDraft();
              },
            ),
            const SizedBox(height: 6),
            Text(
              _smallBusiness
                  ? 'Rechnungen ohne Umsatzsteuer, mit dem Hinweis nach '
                        '${tax.smallBusinessLegalRef}. Nicht sicher? Lass es '
                        'so – du kannst es in den Stammdaten ändern.'
                  : 'Umsatzsteuer wird ausgewiesen, Vorsteuer ist abziehbar.',
              style: theme.textTheme.bodySmall,
            ),
            if (_smallBusiness) ...[
              const SizedBox(height: 12),
              _field(
                'foundingYear',
                'Gründungsjahr',
                helper:
                    'Im Jahr der Gründung gelten eigene Regeln für die '
                    'Umsatzgrenze.',
                keyboard: TextInputType.number,
                draft: true,
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return null;
                  final year = int.tryParse(text);
                  if (year == null || year < 1900 || year > _year) {
                    return 'Bitte ein Jahr bis $_year eingeben';
                  }
                  return null;
                },
              ),
              if (_asksPrevious || _asksCurrent) ...[
                Text(
                  'Umsatz vor Nutzung der App',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Für die Kleinunternehmergrenze braucht die App auch die '
                  'Zeit vor dem ${Fmt.date(_trackingStart)}.',
                  style: theme.textTheme.bodySmall,
                ),
                if (_asksPrevious) ...[
                  const SizedBox(height: 12),
                  MoneyField(
                    key: const Key('setup-opening-previous'),
                    controller: _f['openingPrevious']!,
                    label: 'Umsatz ${_year - 1} gesamt *',
                    validator: _validateOpening,
                  ),
                ],
                if (_asksCurrent) ...[
                  const SizedBox(height: 12),
                  MoneyField(
                    key: const Key('setup-opening-current'),
                    controller: _f['openingCurrent']!,
                    label:
                        'Umsatz $_year vor dem ${Fmt.date(_trackingStart)} *',
                    validator: _validateOpening,
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailsStep(BuildContext context) {
    final tax = _country.taxProfile;
    final theme = Theme.of(context);
    return Form(
      key: _detailsForm,
      child: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _progress(context),
            Text(
              'Alles optional – für Rechnungen brauchst du später '
              '${tax.taxNumberLabel} oder ${tax.vatIdLabel}.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _field(
              'vatId',
              tax.vatIdLabel,
              hint: tax.vatIdExample,
              caps: TextCapitalization.characters,
              validator: (v) => VatIdFormat.check(v ?? ''),
            ),
            _field('taxNumber', tax.taxNumberLabel),
            _field(
              'registerNumber',
              tax.registerNumberLabel,
              helper: 'Nur wenn du eingetragen bist',
              onChanged: (_) => setState(() {}),
            ),
            if (_t('registerNumber').isNotEmpty)
              _field(
                'registerCourt',
                '${tax.registerCourtLabel} *',
                validator: (v) => (v ?? '').trim().isEmpty
                    ? 'Mit ${tax.registerNumberLabel} ist auch das Gericht Pflicht'
                    : null,
              ),
            _field(
              'email',
              'E-Mail',
              keyboard: TextInputType.emailAddress,
              validator: (v) => ContactFormat.checkEmail(v ?? ''),
            ),
            _field(
              'phone',
              'Telefon',
              keyboard: TextInputType.phone,
              validator: (v) => ContactFormat.checkPhone(v ?? ''),
            ),
            _field(
              'iban',
              'IBAN (für Rechnungen)',
              caps: TextCapitalization.characters,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 140,
                  child: _field(
                    'bic',
                    'BIC',
                    caps: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _field('bankName', 'Bank')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _extrasStep(BuildContext context) {
    final state = AppScope.of(context);
    final profile = state.profile;
    final theme = Theme.of(context);
    Widget tile({
      required Key key,
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) => ListTile(
      key: key,
      contentPadding: EdgeInsets.zero,
      minTileHeight: 64,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
    return ReadableWidth(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _progress(context),
          Text(
            'Jedes davon kannst du überspringen und später in den '
            'Einstellungen nachholen.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          tile(
            key: const Key('setup-logo'),
            icon: Icons.image_outlined,
            title: profile?.logoPath == null ? 'Logo wählen' : 'Logo ändern',
            subtitle: state.allows(Feature.invoiceLogo)
                ? 'Erscheint oben rechts auf Rechnungen und Angeboten.'
                : logoBasisHint,
            onTap: _pickLogo,
          ),
          tile(
            key: const Key('setup-backup'),
            icon: Icons.cloud_upload_outlined,
            title: 'Datensicherung einrichten',
            subtitle:
                'Automatisch sichern und Wiederherstellungscode notieren – '
                'falls das Handy verloren geht.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BackupScreen()),
            ),
          ),
          tile(
            key: const Key('setup-registrations'),
            icon: Icons.add_location_alt_outlined,
            title: 'Weitere Länder',
            subtitle: state.registrations.isEmpty
                ? 'Nur nötig bei Registrierung im Ausland, z. B. '
                      'Amazon-Lager oder EU-Kleinunternehmer-Verfahren.'
                : '${state.registrations.length} angelegt: '
                      '${state.registrations.map((r) => r.shortLabel).join(', ')}',
            onTap: () => TaxRegistrationsSection.addRegistration(context),
          ),
        ],
      ),
    );
  }

  Widget _subscriptionStep(BuildContext context) {
    final theme = Theme.of(context);
    return ReadableWidth(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _progress(context),
          Text(
            '${LicensePolicy.trialDays} Tage kostenlos testen',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            key: const Key('setup-trial-terms'),
            '${LicensePolicy.trialDays} Tage kostenlos testen – mit allen '
            'Pro-Funktionen. Danach gilt dein gewähltes Abo (Preis aus dem '
            'Store). Jederzeit vorher im Store kündbar.',
          ),
          const SizedBox(height: 8),
          Text(
            'Ohne Abo bleiben deine Angaben gespeichert; Buchen geht erst '
            'mit Abo.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Wie [ReadableWidth], aber ohne die Höhe zu füllen (Leiste unten).
class _BarWidth extends StatelessWidget {
  const _BarWidth({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: WindowSizeClass.maxContentWidth,
      ),
      child: child,
    ),
  );
}
