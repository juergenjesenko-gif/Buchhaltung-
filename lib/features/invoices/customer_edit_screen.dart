import 'package:flutter/material.dart';

import '../../widgets/danger_zone.dart';
import '../../widgets/primary_action_bar.dart';

import '../../services/contact_format.dart';
import '../../services/vat_id/vat_id_format.dart';
import '../../widgets/vat_check_status.dart';
import '../../app_state.dart';
import '../../domain/country.dart';
import '../../domain/customer.dart';
import '../../widgets/common.dart';
import '../../widgets/adaptive.dart';
import '../licensing/feature_gate.dart';

/// Kunde anlegen oder bearbeiten.
class CustomerEditScreen extends StatefulWidget {
  const CustomerEditScreen({super.key, this.existing});

  final Customer? existing;

  @override
  State<CustomerEditScreen> createState() => _CustomerEditScreenState();
}

class _CustomerEditScreenState extends State<CustomerEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _street = TextEditingController();
  final _postalCode = TextEditingController();
  final _city = TextEditingController();
  final _vatId = TextEditingController();

  /// Unternehmen (B2B); folgt der UID, bis die Nutzerin selbst schaltet.
  bool _isBusiness = false;
  bool _businessTouched = false;
  final _email = TextEditingController();
  final _note = TextEditingController();
  final _buyerReference = TextEditingController();
  final _supplierNumber = TextEditingController();
  EInvoiceFormat _eInvoiceFormat = EInvoiceFormat.zugferd;

  Country _country = Country.at;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) return;
    _name.text = existing.name;
    _contact.text = existing.contactPerson;
    _street.text = existing.street;
    _postalCode.text = existing.postalCode;
    _city.text = existing.city;
    _vatId.text = existing.vatId;
    _isBusiness = existing.isBusiness;
    _businessTouched = true;
    _email.text = existing.email;
    _note.text = existing.note;
    _country = existing.country;
    _buyerReference.text = existing.buyerReference;
    _supplierNumber.text = existing.supplierNumber;
    _eInvoiceFormat = existing.eInvoiceFormat;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _contact,
      _street,
      _postalCode,
      _city,
      _vatId,
      _email,
      _note,
      _buyerReference,
      _supplierNumber,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // Demo (FA-13.14): nichts speichern.
    if (!await ensureWritable(context)) return;
    if (!mounted) return;
    setState(() => _saving = true);

    final customer = Customer(
      id: widget.existing?.id,
      name: _name.text.trim(),
      contactPerson: _contact.text.trim(),
      street: _street.text.trim(),
      postalCode: _postalCode.text.trim(),
      city: _city.text.trim(),
      country: _country,
      vatId: _vatId.text.trim(),
      email: _email.text.trim(),
      note: _note.text.trim(),
      isBusiness: _isBusiness,
      buyerReference: _buyerReference.text.trim(),
      supplierNumber: _supplierNumber.text.trim(),
      eInvoiceFormat: _eInvoiceFormat,
    );

    final state = AppScope.read(context);
    final id = await state.repositories.customers.save(customer);
    if (!mounted) return;
    Navigator.of(context).pop(customer.copyWith(id: id));
  }

  Future<void> _delete() async {
    final id = widget.existing?.id;
    if (id == null) return;

    final ok = await confirmDestructive(
      context,
      title: 'Kunde löschen?',
      message: '${_name.text.trim()} wird aus deinem Kundenstamm entfernt.',
      verb: 'Löschen',
    );
    if (!ok || !mounted) return;
    final state = AppScope.read(context);
    final deleted = await state.repositories.customers.delete(id);
    if (!mounted) return;

    if (!deleted) {
      showSnack(
        context,
        'Der Kunde hat bereits Rechnungen und kann deshalb nicht gelöscht werden.',
      );
      return;
    }
    Navigator.of(context).pop();
  }

  /// E-Rechnung (FA-5.49): Standard ZUGFeRD-PDF ohne weitere Angaben;
  /// Behörden wählen XRechnung bzw. ebInterface, dann erscheint das Feld
  /// für Leitweg-ID bzw. Auftragsreferenz (UX: ganze Zeile 56 dp tippbar,
  /// keine Pflichtfelder für den Normalfall).
  Widget _eInvoiceSection(BuildContext context) {
    final format = _eInvoiceFormat;
    return SectionCard(
      title: 'E-Rechnung',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RadioGroup<EInvoiceFormat>(
            groupValue: format,
            onChanged: (v) =>
                setState(() => _eInvoiceFormat = v ?? EInvoiceFormat.zugferd),
            child: Column(
              children: [
                for (final f in EInvoiceFormat.values)
                  RadioListTile<EInvoiceFormat>(
                    key: Key('customer-einvoice-${f.name}'),
                    contentPadding: EdgeInsets.zero,
                    value: f,
                    title: Text(f.label),
                    subtitle: Text(f.hint),
                  ),
              ],
            ),
          ),
          if (format.isXml) ...[
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('customer-buyer-reference'),
              controller: _buyerReference,
              decoration: InputDecoration(
                labelText: format == EInvoiceFormat.xrechnung
                    ? 'Leitweg-ID'
                    : 'Auftragsreferenz',
                helperText: format == EInvoiceFormat.xrechnung
                    ? 'Steht in der Bestellung der Behörde, z. B. '
                          '04011000-12345-67'
                    : 'Bestellnummer bzw. Auftragsreferenz der Dienststelle',
                helperMaxLines: 2,
              ),
            ),
          ],
          if (format == EInvoiceFormat.ebInterface) ...[
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('customer-supplier-number'),
              controller: _supplierNumber,
              decoration: const InputDecoration(
                labelText: 'Deine Lieferantennummer',
                helperText: 'Vom Bund bei der Registrierung im USP vergeben',
              ),
            ),
          ],
          if (!format.isXml) ...[
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('customer-buyer-reference'),
              controller: _buyerReference,
              decoration: const InputDecoration(
                labelText: 'Käuferreferenz (optional)',
                helperText: 'Nur wenn die Kundin eine verlangt',
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vatLabel = _country.taxProfile.vatIdLabel;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Neuer Kunde' : 'Kunde bearbeiten',
        ),
      ),
      body: ReadableWidth(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              SectionCard(
                title: 'Kunde',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _name,
                      autofocus: widget.existing == null,
                      decoration: const InputDecoration(
                        labelText: 'Name / Firma *',
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Der Name ist Pflicht'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contact,
                      decoration: const InputDecoration(
                        labelText: 'Ansprechpartner:in',
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(labelText: 'E-Mail'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) =>
                          ContactFormat.checkEmail(value ?? ''),
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
                      controller: _street,
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
                            controller: _postalCode,
                            decoration: const InputDecoration(labelText: 'PLZ'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _city,
                            decoration: const InputDecoration(labelText: 'Ort'),
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Country>(
                      initialValue: _country,
                      decoration: const InputDecoration(labelText: 'Land'),
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
                    TextFormField(
                      controller: _vatId,
                      decoration: InputDecoration(
                        labelText: vatLabel,
                        helperText:
                            'Bei Kunden aus dem EU-Ausland für Reverse Charge nötig',
                      ),
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (value) => setState(() {
                        if (!_businessTouched) {
                          _isBusiness = value.trim().isNotEmpty;
                        }
                      }),
                      validator: (value) => VatIdFormat.check(value ?? ''),
                    ),
                    VatCheckStatus(
                      vatId: _vatId.text,
                      subject: 'customer',
                      subjectId: widget.existing?.id,
                    ),
                    SwitchListTile(
                      key: const Key('customerIsBusiness'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Unternehmen'),
                      subtitle: const Text(
                        'Aus: Privatkunde. Wichtig für Mahnkosten und Zinsen',
                      ),
                      value: _isBusiness,
                      onChanged: (value) => setState(() {
                        _isBusiness = value;
                        _businessTouched = true;
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _note,
                      decoration: const InputDecoration(labelText: 'Notiz'),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _eInvoiceSection(context),
              if (widget.existing != null)
                DangerZone(
                  buttonKey: const Key('customer-delete'),
                  label: 'Kunde löschen',
                  icon: Icons.delete_outline,
                  explanation:
                      'Nur möglich, solange es keine Rechnungen an diesen '
                      'Kunden gibt.',
                  onPressed: _saving ? null : _delete,
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: PrimaryActionBar(
        primary: PrimaryActionBar.filled(
          key: const Key('customer-save'),
          label: 'Speichern',
          icon: Icons.check,
          busy: _saving,
          onPressed: _save,
        ),
      ),
    );
  }
}
