import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../domain/company_profile.dart';
import '../../domain/country.dart';
import '../../services/invoice_numbering.dart';
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
    _fields['iban']!.text = profile.iban;
    _fields['bic']!.text = profile.bic;
    _fields['bankName']!.text = profile.bankName;
    _fields['invoicePattern']!.text = profile.invoiceNumberPattern;
    _fields['paymentTerm']!.text = profile.defaultPaymentTermDays.toString();
    _fields['invoiceFooter']!.text = profile.invoiceFooter;
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _text(String key) => _fields[key]!.text.trim();

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
    );

    await state.saveProfile(profile);
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
              const SizedBox(height: 20),
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
                    decoration: InputDecoration(labelText: tax.taxNumberLabel),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _fields['vatId'],
                    decoration: InputDecoration(
                      labelText: tax.vatIdLabel,
                      hintText: _country == Country.at
                          ? 'ATU12345678'
                          : 'DE123456789',
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (!_isSmallBusiness && text.isEmpty) {
                        return 'Wer Umsatzsteuer ausweist, braucht eine ${tax.vatIdLabel}';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  NoticeBanner(
                    icon: Icons.gavel_outlined,
                    message: _isSmallBusiness
                        ? 'Umsatzgrenze ${_formatLimit(tax)} pro Jahr. Die App warnt dich '
                              'rechtzeitig, bevor du sie erreichst.'
                        : 'Steuersätze in ${_country.label}: '
                              '${tax.vatRates.map((r) => r.display).join(', ')}.',
                  ),
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
