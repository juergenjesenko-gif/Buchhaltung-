import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_state.dart';
import '../../l10n/l10n.dart';
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

/// Hauptlogo der Willkommensseite (FA-1.13, endgültig seit 2026-10-19,
/// DESIGN_SPEC 10a): Marineblau auf transparent, im Dunkelmodus dieselben
/// Linien in Hellblau (#EAF2FF), damit sie auf dunklem Grund lesbar bleiben.
/// Erzeugt mit docs/design/logo-final/erzeuge_assets.py (1x/2x/3x).
const brandLogoAsset = 'assets/brand/logo.png';
const brandLogoDarkAsset = 'assets/brand/logo_dark.png';

/// Breite 280 dp; Höhe aus dem Seitenverhältnis des Logos (1435 × 528).
const brandLogoWidth = 280.0;
const brandLogoHeight = 103.0;

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
  static String welcomeSubline(AppLocalizations l10n) =>
      l10n.setupWelcomeSubline;

  /// Was die App kann – nur Gebautes (UWG). Jede Zeile passt auf 360 dp in
  /// eine Zeile (Rückmeldung Auftraggeber zu 0.30.0).
  static List<(IconData, String)> welcomePoints(AppLocalizations l10n) => [
    (Icons.document_scanner_outlined, l10n.setupPointReceipts),
    (Icons.receipt_long_outlined, l10n.setupPointInvoices),
    (Icons.event_note_outlined, l10n.setupPointContracts),
    (Icons.table_chart_outlined, l10n.setupPointReports),
  ];

  const SetupWizard({super.key});

  /// Höhe des Hauptknopfs.
  static const primaryHeight = 56.0;

  /// Abstand zwischen „Später hinzufügen“ und dem Hauptknopf.
  static const gap = 12.0;

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
          if (mounted) showSnack(context, context.l10n.setupDemoFailed);
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
    if (text.isEmpty) return context.l10n.setupOpeningRequired;
    final money = Money.tryParse(text);
    if (money == null) return context.l10n.setupAmountInvalid;
    if (money.isNegative) return context.l10n.setupTurnoverNegative;
    return null;
  }

  String? _validateOptionalOpening(String? value) =>
      (value ?? '').trim().isEmpty ? null : _validateOpening(value);

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
        // Leer heißt hier 0 (Entscheidung Auftraggeber 2026-10-20): Viele
        // kennen den Umsatz nicht und buchen die Belege seit 1. Jänner nach.
        _year: Money.tryParse(_t('openingCurrent')) ?? const Money.zero(),
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
        showSnack(context, context.l10n.setupLogoFailed(error.toString()));
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
          title: context.l10n.setupStepConsent,
          body: ConsentPanel(
            texts: state.missingConsents,
            header: _progress(context),
            onAccepted: _runIntent,
          ),
        ),
        SetupPage.company => _scaffold(
          context,
          title: context.l10n.setupStepCompany,
          body: _companyStep(context),
          primaryLabel: context.l10n.commonNext,
          primaryKey: const Key('setup-next'),
          onPrimary: _saveCompany,
        ),
        SetupPage.details => _scaffold(
          context,
          title: context.l10n.setupStepDetails,
          body: _detailsStep(context),
          primaryLabel: context.l10n.commonNext,
          primaryKey: const Key('setup-next'),
          onPrimary: _saveDetails,
          onSkip: () => _go(SetupPage.extras),
        ),
        SetupPage.extras => _scaffold(
          context,
          title: context.l10n.setupStepExtras,
          body: _extrasStep(context),
          primaryLabel: _hasSubscriptionStep
              ? context.l10n.commonNext
              : context.l10n.commonDone,
          primaryKey: const Key('setup-next'),
          onPrimary: _afterExtras,
          onSkip: _afterExtras,
        ),
        SetupPage.subscription => _scaffold(
          context,
          title: context.l10n.setupStepSubscription,
          body: _subscriptionStep(context),
          primaryLabel: context.l10n.setupSubscribeTrial(
            LicensePolicy.trialDays,
          ),
          primaryKey: const Key('setup-subscribe'),
          onPrimary: () async {
            await openPaywall(context);
            if (!mounted) return;
            if (AppScope.read(this.context).allows(Feature.newBookings)) {
              await _finish();
            }
          },
          skipLabel: context.l10n.setupDecideLater,
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
            context.l10n.setupStepOf(step, _totalSteps),
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
    String? skipLabel,
    Future<void> Function()? onSkip,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          key: const Key('setup-back'),
          tooltip: context.l10n.commonBack,
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
                          child: Text(skipLabel ?? context.l10n.setupLater),
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
                        Text(
                          context.l10n.setupWelcomeTitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: Image.asset(
                            theme.brightness == Brightness.dark
                                ? brandLogoDarkAsset
                                : brandLogoAsset,
                            key: const Key('welcome-logo'),
                            width: brandLogoWidth,
                            height: brandLogoHeight,
                            semanticLabel: 'JeNi bucht',
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.receipt_long, size: 96),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Wortlaut geprüft (UWG § 2 AT / § 5 DE): kein
                        // unbelegbares Qualitätsversprechen („Qualität von
                        // Profis“), nur nachprüfbare Arbeitsweise.
                        Text(
                          SetupWizard.welcomeSubline(context.l10n),
                          key: const Key('welcome-subline'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 40),
                        for (final (icon, text) in SetupWizard.welcomePoints(
                          context.l10n,
                        ))
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
                          context.l10n.setupRestore,
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
                          label: Text(context.l10n.setupDemo),
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
                          child: Text(context.l10n.setupStart),
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
                    label: Text(context.l10n.setupHelperDevice),
                  ),
                ),
                const HelperHelpButton(),
              ],
            ),
            const SizedBox(height: 8),
            Text(context.l10n.setupCountry, style: theme.textTheme.labelLarge),
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
              context.l10n.setupCompanyName,
              hint: context.l10n.setupCompanyNameHint,
              caps: TextCapitalization.words,
              draft: true,
              validator: (v) => (v ?? '').trim().isEmpty
                  ? context.l10n.setupCompanyNameRequired
                  : null,
            ),
            _field(
              'ownerName',
              context.l10n.setupOwner,
              caps: TextCapitalization.words,
              draft: true,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<LegalForm>(
                key: const Key('setup-legal-form'),
                isExpanded: true,
                initialValue: _legalForm,
                decoration: InputDecoration(
                  labelText: context.l10n.setupLegalForm,
                ),
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
              context.l10n.setupStreet,
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
                    context.l10n.setupPostalCode,
                    keyboard: TextInputType.number,
                    draft: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    'city',
                    context.l10n.setupCity,
                    caps: TextCapitalization.words,
                    draft: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(context.l10n.setupTaxation, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              key: const Key('setup-scheme'),
              style: SegmentedButton.styleFrom(minimumSize: const Size(0, 48)),
              segments: [
                ButtonSegment(
                  value: true,
                  label: Text(context.l10n.setupSmallBusiness),
                ),
                ButtonSegment(
                  value: false,
                  label: Text(context.l10n.setupStandardTaxation),
                ),
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
                  ? context.l10n.setupSmallBusinessHelp(
                      tax.smallBusinessLegalRef,
                    )
                  : context.l10n.setupStandardTaxationHelp,
              style: theme.textTheme.bodySmall,
            ),
            if (_smallBusiness) ...[
              const SizedBox(height: 12),
              _field(
                'foundingYear',
                context.l10n.setupFoundingYear,
                helper: context.l10n.setupFoundingYearHelp,
                keyboard: TextInputType.number,
                draft: true,
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return null;
                  final year = int.tryParse(text);
                  if (year == null || year < 1900 || year > _year) {
                    return context.l10n.setupYearMax(_year);
                  }
                  return null;
                },
              ),
              if (_asksPrevious || _asksCurrent) ...[
                Text(
                  context.l10n.setupOpeningTitle,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.setupOpeningHelp(Fmt.date(_trackingStart)),
                  style: theme.textTheme.bodySmall,
                ),
                if (_asksPrevious) ...[
                  const SizedBox(height: 12),
                  MoneyField(
                    key: const Key('setup-opening-previous'),
                    controller: _f['openingPrevious']!,
                    label: context.l10n.setupOpeningPrevious(_year - 1),
                    validator: _validateOpening,
                  ),
                ],
                if (_asksCurrent) ...[
                  const SizedBox(height: 12),
                  MoneyField(
                    key: const Key('setup-opening-current'),
                    controller: _f['openingCurrent']!,
                    label: context.l10n.setupOpeningCurrent(
                      _year,
                      Fmt.date(_trackingStart),
                    ),
                    validator: _validateOptionalOpening,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.setupOpeningCurrentHelp(_year),
                    key: const Key('setup-opening-current-hint'),
                    style: theme.textTheme.bodySmall,
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
              context.l10n.setupDetailsIntro(
                tax.taxNumberLabel,
                tax.vatIdLabel,
              ),
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
              helper: context.l10n.setupRegisterHelp,
              onChanged: (_) => setState(() {}),
            ),
            if (_t('registerNumber').isNotEmpty)
              _field(
                'registerCourt',
                '${tax.registerCourtLabel} *',
                validator: (v) => (v ?? '').trim().isEmpty
                    ? context.l10n.setupRegisterCourtRequired(
                        tax.registerNumberLabel,
                      )
                    : null,
              ),
            _field(
              'email',
              context.l10n.commonEmail,
              keyboard: TextInputType.emailAddress,
              validator: (v) => ContactFormat.checkEmail(v ?? ''),
            ),
            _field(
              'phone',
              context.l10n.commonPhone,
              keyboard: TextInputType.phone,
              validator: (v) => ContactFormat.checkPhone(v ?? ''),
            ),
            _field(
              'iban',
              context.l10n.setupIban,
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
                Expanded(child: _field('bankName', context.l10n.setupBank)),
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
            context.l10n.setupExtrasIntro,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          tile(
            key: const Key('setup-logo'),
            icon: Icons.image_outlined,
            title: profile?.logoPath == null
                ? context.l10n.setupLogoChoose
                : context.l10n.setupLogoChange,
            subtitle: state.allows(Feature.invoiceLogo)
                ? context.l10n.setupLogoHelp
                : logoBasisHint,
            onTap: _pickLogo,
          ),
          tile(
            key: const Key('setup-backup'),
            icon: Icons.cloud_upload_outlined,
            title: context.l10n.setupBackup,
            subtitle: context.l10n.setupBackupHelp,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BackupScreen()),
            ),
          ),
          tile(
            key: const Key('setup-registrations'),
            icon: Icons.add_location_alt_outlined,
            title: context.l10n.setupMoreCountries,
            subtitle: state.registrations.isEmpty
                ? context.l10n.setupMoreCountriesHelp
                : context.l10n.setupRegistrationsCount(
                    state.registrations.length,
                    state.registrations.map((r) => r.shortLabel).join(', '),
                  ),
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
            context.l10n.setupTrialTitle(LicensePolicy.trialDays),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            key: const Key('setup-trial-terms'),
            context.l10n.setupTrialText(LicensePolicy.trialDays),
          ),
          const SizedBox(height: 8),
          Text(context.l10n.setupNoPlan, style: theme.textTheme.bodySmall),
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
