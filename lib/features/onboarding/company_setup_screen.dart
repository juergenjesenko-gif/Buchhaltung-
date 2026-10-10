import 'package:flutter/material.dart';

import '../../services/vat_id/vat_id_format.dart';
import '../../widgets/vat_check_status.dart';
import '../backup/backup_screen.dart';
import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../domain/company_profile.dart';
import '../../domain/country.dart';
import '../../domain/money.dart';
import '../../services/invoice_numbering.dart';
import '../../services/turnover_basis.dart';
import '../../widgets/common.dart';

/// Firmenprofil anlegen und bearbeiten.
///
/// Beim ersten Start läuft der Bildschirm als Onboarding: ohne Firmenname und
/// Land kann die App weder Steuersätze noch Rechnungsangaben bestimmen.
/// Danach ist derselbe Bildschirm die Stammdatenverwaltung.
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
  bool _saving = false;
  bool _initialized = false;

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
      return;
    }

    _country = profile.country;
    _legalForm = profile.legalForm;
    _isSmallBusiness = profile.isSmallBusiness;
    _trackingStart = profile.trackingStart ?? DateTime.now();
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
    _fields['foundingYear']!.text = profile.foundingYear?.toString() ?? '';
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final state = AppScope.read(context);
    final existing = state.profile;
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
      fiscalYearStartMonth: existing?.fiscalYearStartMonth ?? 1,
      trackingStart: existing?.trackingStart ?? _trackingStart,
      foundingYear: _foundingYear,
      // Wird nur von der Datensicherung geschrieben; beim Bearbeiten erhalten.
      lastBackupAt: existing?.lastBackupAt,
      registerNumber: _text('registerNumber'),
      registerCourt: _text('registerCourt'),
      vatCheckEnabled: _vatCheckEnabled,
      vatCheckLastRun: existing?.vatCheckLastRun,
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
      body: Form(
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
                    decoration: const InputDecoration(labelText: 'Inhaber:in'),
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
                    initialValue: _legalForm,
                    decoration: const InputDecoration(labelText: 'Rechtsform'),
                    items: [
                      for (final form in LegalForm.values)
                        DropdownMenuItem(value: form, child: Text(form.label)),
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
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _fields['phone'],
                    decoration: const InputDecoration(labelText: 'Telefon'),
                    keyboardType: TextInputType.phone,
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
                  if (_isSmallBusiness && (_asksPrevious || _asksCurrent)) ...[
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
                ],
              ),
            ),
            const SizedBox(height: 16),

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
                          decoration: const InputDecoration(labelText: 'Bank'),
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
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          8 + MediaQuery.of(context).padding.bottom,
        ),
        child: FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.isOnboarding ? 'Los geht\'s' : 'Speichern'),
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
