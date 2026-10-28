import '../helper/helper_pair_screen.dart';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../widgets/primary_action_bar.dart';

import '../../services/invoice_texts.dart';
import '../invoices/invoice_edit_screen.dart' show parsePermille, percentText;
import 'package:image_picker/image_picker.dart';

import '../../services/licensing/license_policy.dart';
import '../../services/logo_store.dart';

import '../../services/contact_format.dart';
import '../../services/vat_id/vat_id_format.dart';
import '../../widgets/vat_check_status.dart';
import '../backup/backup_screen.dart';
import '../settings/tax_registration_screen.dart';
import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../domain/company_profile.dart';
import '../../domain/country.dart';
import '../../domain/deadline_rule.dart';
import '../../domain/holidays.dart';
import '../../domain/money.dart';
import '../../services/invoice_numbering.dart';
import '../../services/turnover_basis.dart';
import '../../widgets/common.dart';
import '../../widgets/adaptive.dart';
import '../licensing/feature_gate.dart';
import '../../domain/currency.dart';

/// Firmenprofil anlegen und bearbeiten.
///
/// Beim ersten Start läuft der Bildschirm als Onboarding: ohne Firmenname und
/// Land kann die App weder Steuersätze noch Rechnungsangaben bestimmen.
/// Danach ist derselbe Bildschirm die Stammdatenverwaltung.
/// Hinweis, wenn das Logo mit dem aktuellen Anspruch nicht gedruckt wird
/// (FA-13.12). Das Logo bleibt gespeichert und kommt mit Pro zurück.
const logoBasisHint =
    'Logo (Pro) – wird mit Basis nicht gedruckt. Es bleibt gespeichert und '
    'erscheint wieder, sobald Pro aktiv ist.';

class CompanySetupScreen extends StatefulWidget {
  const CompanySetupScreen({super.key, this.isOnboarding = false});

  final bool isOnboarding;

  @override
  State<CompanySetupScreen> createState() => _CompanySetupScreenState();
}

class _CompanySetupScreenState extends State<CompanySetupScreen> {
  final _formKey = GlobalKey<FormState>();

  late final Map<String, TextEditingController> _fields;
  Country _country = Country.at;
  LegalForm _legalForm = LegalForm.soleTrader;
  bool _isSmallBusiness = true;

  /// Beginn der Erfassung in der App. Bei neuen Profilen heute; bestehende
  /// behalten ihren Wert, damit Eröffnungswerte nicht verrutschen.
  DateTime _trackingStart = DateTime.now();
  bool _vatCheckEnabled = false;

  // Wirtschaftsjahr und Termine (L-24, L-25). Sinnvoll vorbelegt, beim
  // Onboarding nicht abgefragt (Leitprinzip: so wenige Fragen wie möglich).
  int _fiscalYearStartMonth = 1;
  bool _fiscalYearConfirmed = false;
  String _federalState = '';
  VatReturnInterval _vatInterval = VatReturnInterval.auto;
  bool _permanentExtension = false;
  bool _filesEcsl = false;
  bool _oss = false;
  bool _hasTaxAdvisor = false;
  bool _svsInsured = true;

  /// Firmenlogo (L-1.7): relativer Pfad und aufgelöste Datei zur Vorschau.
  String? _logoPath;
  File? _logoFile;
  bool _saving = false;
  bool _initialized = false;
  bool _dunningInterest = false;
  bool _dunningFlatFee = false;

  @override
  void initState() {
    super.initState();
    _fields = {
      for (final key in const [
        'companyName',
        'ownerName',
        'street',
        'postalCode',
        'city',
        'email',
        'phone',
        'website',
        'taxNumber',
        'vatId',
        'iban',
        'bic',
        'bankName',
        'invoicePattern',
        'paymentTerm',
        'invoiceFooter',
        'skontoDays',
        'skontoPercent',
        'termsUrl',
        'dunningFee',
        'dunningPeriod',
        'openingPrevious',
        'foundingYear',
        'registerNumber',
        'registerCourt',
        'openingCurrent',
      ])
        key: TextEditingController(),
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final profile = AppScope.read(context).profile;
    if (profile == null) {
      _fields['invoicePattern']!.text = InvoiceNumbering.defaultPattern;
      _fields['paymentTerm']!.text = '14';
      _fields['dunningFee']!.text = Fmt.amount(const Money(1000));
      _fields['dunningPeriod']!.text = '14';
      return;
    }

    _country = profile.country;
    _legalForm = profile.legalForm;
    _isSmallBusiness = profile.isSmallBusiness;
    _trackingStart = profile.trackingStart ?? DateTime.now();
    _logoPath = profile.logoPath;
    _loadLogo();
    _loadOpenings();
    _fields['companyName']!.text = profile.companyName;
    _fields['ownerName']!.text = profile.ownerName;
    _fields['street']!.text = profile.street;
    _fields['postalCode']!.text = profile.postalCode;
    _fields['city']!.text = profile.city;
    _fields['email']!.text = profile.email;
    _fields['phone']!.text = profile.phone;
    _fields['website']!.text = profile.website;
    _fields['taxNumber']!.text = profile.taxNumber;
    _fields['vatId']!.text = profile.vatId;
    _fields['registerNumber']!.text = profile.registerNumber;
    _fields['registerCourt']!.text = profile.registerCourt;
    _vatCheckEnabled = profile.vatCheckEnabled;
    _fields['iban']!.text = profile.iban;
    _fields['bic']!.text = profile.bic;
    _fields['bankName']!.text = profile.bankName;
    _fields['invoicePattern']!.text = profile.invoiceNumberPattern;
    _fields['paymentTerm']!.text = profile.defaultPaymentTermDays.toString();
    _fields['invoiceFooter']!.text = profile.invoiceFooter;
    if (profile.defaultSkontoDays > 0) {
      _fields['skontoDays']!.text = profile.defaultSkontoDays.toString();
      _fields['skontoPercent']!.text = percentText(
        profile.defaultSkontoPermille,
      );
    }
    _fields['termsUrl']!.text = profile.termsUrl;
    _fields['dunningFee']!.text = Fmt.amount(profile.dunningFee);
    _fields['dunningPeriod']!.text = profile.dunningPeriodDays.toString();
    _dunningInterest = profile.dunningInterest;
    _dunningFlatFee = profile.dunningFlatFee;
    _fields['foundingYear']!.text = profile.foundingYear?.toString() ?? '';
    _fiscalYearStartMonth = profile.fiscalYearStartMonth;
    _fiscalYearConfirmed = profile.fiscalYearConfirmed;
    _federalState = profile.federalState;
    _vatInterval = profile.vatReturnInterval;
    _permanentExtension = profile.vatPermanentExtension;
    _filesEcsl = profile.filesEcsl;
    _oss = profile.ossParticipant;
    _hasTaxAdvisor = profile.hasTaxAdvisor;
    _svsInsured = profile.svsInsured;
  }

  /// Monat ≠ Jänner nur nach einmaliger Bestätigung mit dem Text des Landes
  /// (L-24.3).
  Future<void> _chooseFiscalYearStart(int month) async {
    if (month != 1 && !_fiscalYearConfirmed) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Abweichendes Wirtschaftsjahr'),
          content: Text(_country.taxProfile.fiscalYearConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Trifft zu'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      _fiscalYearConfirmed = true;
    }
    setState(() => _fiscalYearStartMonth = month);
  }

  Widget _deadlineSection() {
    final tax = _country.taxProfile;
    final suggested = AppScope.of(context).suggestedVatInterval;
    return SectionCard(
      title: 'Wirtschaftsjahr und Termine',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int>(
            initialValue: _fiscalYearStartMonth,
            decoration: const InputDecoration(
              labelText: 'Erster Monat Wirtschaftsjahr',
            ),
            items: [
              for (var m = 1; m <= 12; m++)
                DropdownMenuItem(value: m, child: Text(tax.monthNames[m - 1])),
            ],
            onChanged: (value) {
              if (value != null) _chooseFiscalYearStart(value);
            },
          ),
          if (_fiscalYearStartMonth != 1) ...[
            const SizedBox(height: 6),
            Text(
              tax.fiscalYearHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (tax.asksFederalState) ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _federalState,
              decoration: const InputDecoration(
                labelText: 'Bundesland (für Feiertage bei Fristen)',
              ),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Nur bundesweite Feiertage'),
                ),
                for (final (code, name) in germanStates)
                  DropdownMenuItem(value: code, child: Text(name)),
              ],
              onChanged: (value) => setState(() => _federalState = value ?? ''),
            ),
          ],
          if (!_isSmallBusiness) ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<VatReturnInterval>(
              initialValue: _vatInterval,
              decoration: InputDecoration(
                labelText: '${tax.vatReturnLabel}-Rhythmus',
              ),
              items: [
                for (final v in VatReturnInterval.values)
                  DropdownMenuItem(
                    value: v,
                    child: Text(
                      v == VatReturnInterval.auto
                          ? 'Vorschlag: ${suggested.label}'
                          : v.label,
                    ),
                  ),
              ],
              onChanged: (value) => setState(
                () => _vatInterval = value ?? VatReturnInterval.auto,
              ),
            ),
            if (tax.hasPermanentExtension)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dauerfristverlängerung'),
                value: _permanentExtension,
                onChanged: (v) => setState(() => _permanentExtension = v),
              ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Zusammenfassende Meldung (ZM)'),
            subtitle: const Text('Nur bei Leistungen an Firmen im EU-Ausland'),
            value: _filesEcsl,
            onChanged: (v) => setState(() => _filesEcsl = v),
          ),
          SwitchListTile(
            key: const Key('setup-oss'),
            contentPadding: EdgeInsets.zero,
            title: const Text('One-Stop-Shop (OSS)'),
            subtitle: const Text('Verkäufe an Private in anderen EU-Ländern'),
            value: _oss,
            onChanged: (v) => setState(() => _oss = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ich habe eine Steuerberatung'),
            value: _hasTaxAdvisor,
            onChanged: (v) => setState(() => _hasTaxAdvisor = v),
          ),
          if (tax.asksSocialInsurance)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('SVS-Beiträge anzeigen'),
              value: _svsInsured,
              onChanged: (v) => setState(() => _svsInsured = v),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _text(String key) => _fields[key]!.text.trim();

  int get _currentYear => DateTime.now().year;

  int? get _foundingYear => int.tryParse(_text('foundingYear'));

  // Wer dieses Jahr gegründet hat, hatte kein Vorjahr.
  bool get _asksPrevious =>
      _foundingYear != _currentYear &&
      TurnoverBasis.needsOpening(
        year: _currentYear - 1,
        trackingStart: _trackingStart,
      );

  bool get _asksCurrent => TurnoverBasis.needsOpening(
    year: _currentYear,
    trackingStart: _trackingStart,
  );

  Future<void> _loadOpenings() async {
    final state = AppScope.read(context);
    final previous = await state.openingTurnover(_currentYear - 1);
    final current = await state.openingTurnover(_currentYear);
    if (!mounted) return;
    if (previous != null) {
      _fields['openingPrevious']!.text = Fmt.amount(previous);
    }
    if (current != null) {
      _fields['openingCurrent']!.text = Fmt.amount(current);
    }
  }

  /// Eröffnungswerte sind Pflicht, solange die Kleinunternehmerregelung aktiv
  /// ist (Lastenheft L-16.2). Leer ist nicht dasselbe wie 0 – wer noch keinen
  /// Umsatz hatte, trägt ausdrücklich 0 ein.
  String? _validateOpening(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Bitte angeben – 0, wenn es keinen Umsatz gab';
    final money = Money.tryParse(text);
    if (money == null) return 'Bitte einen Betrag eingeben';
    if (money.isNegative) return 'Der Umsatz kann nicht negativ sein';
    return null;
  }

  Future<void> _loadLogo() async {
    final file = await LogoStore.resolve(_logoPath);
    if (mounted) setState(() => _logoFile = file);
  }

  /// Wählt ein Logo aus der Fotobibliothek. Verkleinert wird über dieselbe
  /// Bildauswahl wie bei Belegen; die Datei ist neu und überschreibt nichts.
  Future<void> _pickLogo() async {
    // Wählen geht ohne Abo-Seite, auch im Onboarding (FA-13.12,
    // Entscheidung 2026-10-16); gedruckt wird es nur mit Pro oder Test.
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: LogoStore.maxEdgePx.toDouble(),
        maxHeight: LogoStore.maxEdgePx.toDouble(),
        imageQuality: LogoStore.qualityPercent,
      );
      if (picked == null) return;
      final relative = await LogoStore.store(File(picked.path));
      if (!mounted) return;
      setState(() => _logoPath = relative);
      await _loadLogo();
    } on Exception catch (error) {
      if (mounted) {
        showSnack(context, 'Logo konnte nicht übernommen werden: $error');
      }
    }
  }

  /// Entfernt das Logo aus dem Profil. Die Datei bleibt, weil gestellte
  /// Rechnungen auf sie verweisen können (GR-8).
  void _removeLogo() => setState(() {
    _logoPath = null;
    _logoFile = null;
  });

  int get _skontoDays {
    final days = int.tryParse(_text('skontoDays')) ?? 0;
    return days > 0 && parsePermille(_text('skontoPercent')) > 0 ? days : 0;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // Demo (FA-13.14): nichts speichern.
    if (!await ensureWritable(context)) return;
    if (!mounted) return;
    setState(() => _saving = true);

    final state = AppScope.read(context);
    final existing = state.profile;
    // Einmaliger Hinweis beim ersten Eintragen der AGB-Adresse (L-3.26).
    final termsHint =
        _text('termsUrl').isNotEmpty && !(existing?.termsHintShown ?? false);
    if (termsHint) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Verkaufsbedingungen'),
          content: const Text(InvoiceTexts.termsHint),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Verstanden'),
            ),
          ],
        ),
      );
      if (!mounted) return;
    }
    final profile = CompanyProfile(
      companyName: _text('companyName'),
      ownerName: _text('ownerName'),
      country: _country,
      legalForm: _legalForm,
      street: _text('street'),
      postalCode: _text('postalCode'),
      city: _text('city'),
      email: _text('email'),
      phone: _text('phone'),
      website: _text('website'),
      taxNumber: _text('taxNumber'),
      vatId: _text('vatId'),
      isSmallBusiness: _isSmallBusiness,
      iban: _text('iban'),
      bic: _text('bic'),
      bankName: _text('bankName'),
      invoiceNumberPattern: _text('invoicePattern'),
      // Der Zähler darf beim Bearbeiten der Stammdaten nicht zurückspringen,
      // sonst würden Rechnungsnummern doppelt vergeben.
      nextInvoiceSequence: existing?.nextInvoiceSequence ?? 1,
      defaultPaymentTermDays: int.tryParse(_text('paymentTerm')) ?? 14,
      invoiceFooter: _text('invoiceFooter'),
      fiscalYearStartMonth: _fiscalYearStartMonth,
      fiscalYearConfirmed: _fiscalYearStartMonth != 1 && _fiscalYearConfirmed,
      // Bundesland nur, wo das Land es abfragt (L-25.4).
      federalState: _country.taxProfile.asksFederalState ? _federalState : '',
      vatReturnInterval: _vatInterval,
      vatPermanentExtension: _permanentExtension,
      filesEcsl: _filesEcsl,
      ossParticipant: _oss,
      hasTaxAdvisor: _hasTaxAdvisor,
      svsInsured: _svsInsured,
      trackingStart: existing?.trackingStart ?? _trackingStart,
      foundingYear: _foundingYear,
      // Wird nur von der Datensicherung geschrieben; beim Bearbeiten erhalten.
      lastBackupAt: existing?.lastBackupAt,
      registerNumber: _text('registerNumber'),
      registerCourt: _text('registerCourt'),
      vatCheckEnabled: _vatCheckEnabled,
      vatCheckLastRun: existing?.vatCheckLastRun,
      logoPath: _logoPath,
      defaultSkontoDays: _skontoDays,
      defaultSkontoPermille: _skontoDays > 0
          ? parsePermille(_text('skontoPercent'))
          : 0,
      termsUrl: _text('termsUrl'),
      termsHintShown: (existing?.termsHintShown ?? false) || termsHint,
      dunningFee: Money.tryParse(_text('dunningFee')) ?? const Money(1000),
      dunningInterest: _dunningInterest,
      dunningFlatFee: _dunningFlatFee,
      dunningPeriodDays: int.tryParse(_text('dunningPeriod')) ?? 14,
    );

    // Eröffnungswerte nur schreiben, wenn sie abgefragt wurden. Wer auf
    // Regelbesteuerung wechselt, verliert seine erfassten Werte nicht.
    final openings = <int, Money?>{
      if (_isSmallBusiness && _asksPrevious)
        _currentYear - 1: Money.tryParse(_text('openingPrevious')),
      if (_isSmallBusiness && _asksCurrent)
        _currentYear: Money.tryParse(_text('openingCurrent')),
    };

    await state.saveProfileWithOpenings(profile, openings);
    if (!mounted) return;
    setState(() => _saving = false);
    // Beim Onboarding wechselt _Root automatisch zur Hauptansicht, sobald das
    // Profil gespeichert ist – hier gibt es keinen Bildschirm zum Zurückgehen.
    if (widget.isOnboarding) {
      return;
    }
    Navigator.of(context).pop();
    showSnack(context, 'Stammdaten gespeichert');
  }

  @override
  Widget build(BuildContext context) {
    final tax = _country.taxProfile;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isOnboarding ? 'Willkommen' : 'Stammdaten'),
        automaticallyImplyLeading: !widget.isOnboarding,
      ),
      body: ReadableWidth(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              if (widget.isOnboarding) ...[
                Text(
                  'Ein paar Angaben zu deinem Unternehmen – danach kannst du sofort '
                  'Belege erfassen und Rechnungen schreiben.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                // Neues Gerät: statt neu einzurichten, die Sicherung einlesen.
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BackupScreen()),
                    ),
                    icon: const Icon(Icons.restore),
                    label: const Text(
                      'Aus einer Datensicherung wiederherstellen',
                    ),
                  ),
                ),
                // Mithelfer-Gerät (FA-17.2): nur Belege sammeln, kein Profil.
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('onboarding-helper'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const HelperPairScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Ich helfe mit – Gerät koppeln'),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              SectionCard(
                title: 'Unternehmen',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _fields['companyName'],
                      decoration: const InputDecoration(
                        labelText: 'Firmenname *',
                        hintText: 'z. B. Max Mustermann e.U.',
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Bitte gib einen Firmennamen an'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fields['ownerName'],
                      decoration: const InputDecoration(
                        labelText: 'Inhaber:in',
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Country>(
                      initialValue: _country,
                      decoration: const InputDecoration(
                        labelText: 'Land des Unternehmenssitzes *',
                      ),
                      items: [
                        for (final country in Country.values)
                          DropdownMenuItem(
                            value: country,
                            child: Text(country.label),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _country = value ?? Country.at),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<LegalForm>(
                      // Lange Bezeichnungen umbrechen statt über den Rand
                      // (360 dp, „Freiberufler / Neue Selbständige“).
                      isExpanded: true,
                      initialValue: _legalForm,
                      decoration: const InputDecoration(
                        labelText: 'Rechtsform',
                      ),
                      items: [
                        for (final form in LegalForm.values)
                          DropdownMenuItem(
                            value: form,
                            child: Text(form.label),
                          ),
                      ],
                      onChanged: (value) => setState(
                        () => _legalForm = value ?? LegalForm.soleTrader,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              SectionCard(
                title: 'Anschrift',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _fields['street'],
                      decoration: const InputDecoration(
                        labelText: 'Straße und Hausnummer',
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: TextFormField(
                            controller: _fields['postalCode'],
                            decoration: const InputDecoration(labelText: 'PLZ'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _fields['city'],
                            decoration: const InputDecoration(labelText: 'Ort'),
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fields['email'],
                      decoration: const InputDecoration(labelText: 'E-Mail'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) =>
                          ContactFormat.checkEmail(value ?? ''),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fields['phone'],
                      decoration: const InputDecoration(labelText: 'Telefon'),
                      keyboardType: TextInputType.phone,
                      validator: (value) =>
                          ContactFormat.checkPhone(value ?? ''),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fields['website'],
                      decoration: const InputDecoration(labelText: 'Website'),
                      keyboardType: TextInputType.url,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              SectionCard(
                title: 'Steuer',
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _isSmallBusiness,
                      onChanged: (value) =>
                          setState(() => _isSmallBusiness = value),
                      title: Text(tax.smallBusinessLabel),
                      subtitle: Text(
                        _isSmallBusiness
                            ? 'Rechnungen ohne Umsatzsteuer, dafür mit dem Hinweis nach '
                                  '${tax.smallBusinessLegalRef}.'
                            : 'Regelbesteuerung: Umsatzsteuer wird ausgewiesen und '
                                  'Vorsteuer ist abziehbar.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _fields['taxNumber'],
                      decoration: InputDecoration(
                        labelText: tax.taxNumberLabel,
                        helperText: tax.invoiceRequiresTaxId
                            ? 'Noch beantragt? Leer lassen – für Rechnungen ist '
                                  '${tax.taxNumberLabel} oder ${tax.vatIdLabel} nötig.'
                            : 'Noch beantragt? Einfach später nachtragen.',
                        helperMaxLines: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fields['vatId'],
                      decoration: InputDecoration(
                        labelText: tax.vatIdLabel,
                        hintText: tax.vatIdExample,
                      ),
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) => setState(() {}),
                      // Optional; geprüft wird nur das Format, offline.
                      validator: (value) => VatIdFormat.check(value ?? ''),
                    ),
                    VatCheckStatus(
                      vatId: _text('vatId'),
                      subject: 'company',
                      subjectId: 1,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _vatCheckEnabled,
                      onChanged: (value) =>
                          setState(() => _vatCheckEnabled = value),
                      title: const Text('UID-Nummern wöchentlich prüfen'),
                      subtitle: const Text(
                        'Prüft deine UID und die deiner aktiven Kunden über das '
                        'EU-Prüfsystem VIES, dazu vor jeder Rechnung an einen '
                        'Kunden mit UID. Dabei werden die Nummern an die '
                        'EU-Kommission gesendet. Jederzeit abschaltbar.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fields['registerNumber'],
                      decoration: InputDecoration(
                        labelText: tax.registerNumberLabel,
                        helperText: 'Nur wenn du eingetragen bist',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_text('registerNumber').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _fields['registerCourt'],
                        decoration: InputDecoration(
                          labelText: '${tax.registerCourtLabel} *',
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Mit ${tax.registerNumberLabel} ist auch das Gericht Pflicht'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 12),
                    NoticeBanner(
                      icon: Icons.gavel_outlined,
                      message: _isSmallBusiness
                          ? 'Umsatzgrenze ${_formatLimit(tax)} pro Jahr. Die App warnt dich '
                                'rechtzeitig, bevor du sie erreichst.'
                          : 'Steuersätze in ${_country.label}: '
                                '${tax.vatRates.map((r) => r.display).join(', ')}.',
                    ),
                    if (_isSmallBusiness) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _fields['foundingYear'],
                        decoration: const InputDecoration(
                          labelText: 'Gründungsjahr',
                          helperText:
                              'Im Jahr der Gründung gelten eigene Regeln für die '
                              'Umsatzgrenze.',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          final text = (value ?? '').trim();
                          if (text.isEmpty) return null;
                          final year = int.tryParse(text);
                          if (year == null ||
                              year < 1900 ||
                              year > _currentYear) {
                            return 'Bitte ein Jahr bis $_currentYear eingeben';
                          }
                          return null;
                        },
                      ),
                    ],
                    if (_isSmallBusiness &&
                        (_asksPrevious || _asksCurrent)) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Umsatz vor Nutzung der App',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Die App kennt deine Umsätze erst ab dem '
                        '${Fmt.date(_trackingStart)}. Für die Kleinunternehmergrenze '
                        'braucht sie auch die Zeit davor – sonst würde sie dich '
                        'womöglich in falscher Sicherheit wiegen.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (_asksPrevious) ...[
                        const SizedBox(height: 12),
                        MoneyField(
                          controller: _fields['openingPrevious']!,
                          label: 'Umsatz ${_currentYear - 1} gesamt *',
                          validator: _validateOpening,
                        ),
                      ],
                      if (_asksCurrent) ...[
                        const SizedBox(height: 12),
                        MoneyField(
                          controller: _fields['openingCurrent']!,
                          label:
                              'Umsatz $_currentYear vor dem ${Fmt.date(_trackingStart)} *',
                          validator: _validateOpening,
                        ),
                      ],
                    ],
                    if (!widget.isOnboarding &&
                        (AppScope.of(context).backfill?.confirmed ??
                            false)) ...[
                      const SizedBox(height: 12),
                      // FA-4.16: „Ja, vollständig“ rückgängig machen.
                      Text(
                        'Du hast bestätigt, dass alle Rechnungen vor dem '
                        '${Fmt.date(_trackingStart)} nachgetragen sind. Der '
                        'geschätzte Umsatz vor Nutzung der App zählt nicht mehr.',
                        key: const Key('backfill-confirmed-note'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: const Key('backfill-reset'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: () => AppScope.read(
                            context,
                          ).setBackfillConfirmed(false),
                          child: const Text('Bestätigung zurücksetzen'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (!widget.isOnboarding) ...[
                _deadlineSection(),
                const SizedBox(height: 16),
                const TaxRegistrationsSection(),
                const SizedBox(height: 16),
              ],

              SectionCard(
                title: 'Bankverbindung',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _fields['iban'],
                      decoration: const InputDecoration(labelText: 'IBAN'),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SizedBox(
                          width: 140,
                          child: TextFormField(
                            controller: _fields['bic'],
                            decoration: const InputDecoration(labelText: 'BIC'),
                            textCapitalization: TextCapitalization.characters,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _fields['bankName'],
                            decoration: const InputDecoration(
                              labelText: 'Bank',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              SectionCard(
                title: 'Rechnungen',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 96,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _logoFile == null
                              ? const Text('Kein Logo')
                              : Image.file(_logoFile!, fit: BoxFit.contain),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _pickLogo,
                                icon: const Icon(Icons.image_outlined),
                                label: Text(
                                  _logoPath == null
                                      ? 'Logo wählen'
                                      : 'Logo ändern',
                                ),
                              ),
                              if (_logoPath != null)
                                TextButton.icon(
                                  onPressed: _removeLogo,
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Entfernen'),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppScope.of(context).allows(Feature.invoiceLogo)
                          ? 'Erscheint oben rechts auf neuen Rechnungen und '
                                'Angeboten, zusätzlich zu Name und Anschrift. '
                                'Bereits gestellte Rechnungen behalten ihr '
                                'damaliges Logo.'
                          : logoBasisHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fields['invoicePattern'],
                      decoration: InputDecoration(
                        labelText: 'Muster der Rechnungsnummer',
                        helperText:
                            'Beispiel: '
                            '${InvoiceNumbering.preview(_fields['invoicePattern']!.text, DateTime.now())}',
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (value) =>
                          InvoiceNumbering.isValidPattern(value ?? '')
                          ? null
                          : 'Das Muster braucht eine laufende Nummer, z. B. {NNNN}',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fields['paymentTerm'],
                      decoration: const InputDecoration(
                        labelText: 'Zahlungsziel',
                        suffixText: 'Tage',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _fields['skontoDays'],
                            decoration: const InputDecoration(
                              labelText: 'Skonto innerhalb',
                              suffixText: 'Tagen',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _fields['skontoPercent'],
                            decoration: const InputDecoration(
                              labelText: 'Skonto',
                              suffixText: '%',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vorschlag für neue Rechnungen, z. B. 10 Tage 2 %. Leer '
                      'lassen für Rechnungen ohne Skonto.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fields['termsUrl'],
                      decoration: const InputDecoration(
                        labelText: 'Adresse deiner AGB (optional)',
                        helperText:
                            'Erscheint als Verweis auf neuen Rechnungen',
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Mahnungen',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _fields['dunningFee'],
                            decoration: InputDecoration(
                              labelText: 'Mahnkosten je Mahnung',
                              suffixText: Currency.home.symbol,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _fields['dunningPeriod'],
                            decoration: const InputDecoration(
                              labelText: 'Neue Frist',
                              suffixText: 'Tage',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Die Zahlungserinnerung ist immer kostenlos; Mahnkosten '
                      'gelten ab der 1. Mahnung.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Verzugszinsen vorschlagen'),
                      subtitle: const Text('Gesetzlicher Satz, änderbar'),
                      value: _dunningInterest,
                      onChanged: (value) =>
                          setState(() => _dunningInterest = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('40-€-Pauschale bei Unternehmen'),
                      subtitle: Text(tax.dunning.flatFeeLegalRef),
                      value: _dunningFlatFee,
                      onChanged: (value) =>
                          setState(() => _dunningFlatFee = value),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fields['invoiceFooter'],
                      decoration: const InputDecoration(
                        labelText: 'Fußzeile der Rechnung',
                        helperText:
                            'Leer lassen für die automatische Fußzeile aus den Stammdaten',
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: PrimaryActionBar(
        primary: PrimaryActionBar.filled(
          key: const Key('profile-save'),
          label: widget.isOnboarding ? 'Los geht\'s' : 'Speichern',
          icon: Icons.check,
          busy: _saving,
          onPressed: _save,
        ),
      ),
    );
  }

  String _formatLimit(TaxProfile tax) {
    final euro = tax.currentYearTurnoverLimit.cents ~/ 100;
    final digits = euro.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return '$buffer €';
  }
}
