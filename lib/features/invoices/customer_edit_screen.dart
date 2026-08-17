import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../domain/country.dart';
import '../../domain/customer.dart';
import '../../widgets/common.dart';

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
  final _email = TextEditingController();
  final _note = TextEditingController();

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
    _email.text = existing.email;
    _note.text = existing.note;
    _country = existing.country;
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
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
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
    );

    final state = AppScope.read(context);
    final id = await state.repositories.customers.save(customer);
    if (!mounted) return;
    Navigator.of(context).pop(customer.copyWith(id: id));
  }

  Future<void> _delete() async {
    final id = widget.existing?.id;
    if (id == null) return;

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

  @override
  Widget build(BuildContext context) {
    final vatLabel = _country.taxProfile.vatIdLabel;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Neuer Kunde' : 'Kunde bearbeiten',
        ),
        actions: [
          if (widget.existing != null)
            IconButton(
              tooltip: 'Löschen',
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: Form(
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
          child: const Text('Speichern'),
        ),
      ),
    );
  }
}
