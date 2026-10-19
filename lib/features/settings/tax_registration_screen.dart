import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../domain/country.dart';
import '../../domain/tax_registration.dart';
import '../../services/vat_id/eu_sme_id_format.dart';
import '../../services/vat_id/vat_id_format.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/common.dart';
import '../../widgets/danger_zone.dart';
import '../../widgets/primary_action_bar.dart';
import '../licensing/feature_gate.dart';

/// Abschnitt „Steuerliche Registrierungen“ in den Stammdaten (FA-18.1):
/// Heimatland plus „Weitere Länder“ und „Land hinzufügen“.
class TaxRegistrationsSection extends StatelessWidget {
  const TaxRegistrationsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final profile = state.profile;
    if (profile == null) return const SizedBox.shrink();
    return SectionCard(
      title: 'Steuerliche Registrierungen',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            minTileHeight: 56,
            leading: _CountryBadge(profile.country.code),
            title: Text('${profile.country.label} (Heimat)'),
            subtitle: Text(
              profile.isSmallBusiness ? 'Kleinunternehmer' : 'Regelbesteuerung',
            ),
          ),
          for (final r in state.registrations)
            ListTile(
              key: Key('registration-${r.id}'),
              contentPadding: EdgeInsets.zero,
              minTileHeight: 56,
              leading: _CountryBadge(r.country.code),
              title: Text(r.country.label),
              subtitle: Text(
                [
                  r.scheme.label,
                  if (r.scheme == VatScheme.standard) r.interval.label,
                  if (r.vatId.isNotEmpty) r.vatId,
                  if (r.validTo != null) 'bis ${Fmt.date(r.validTo!)}',
                ].join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TaxRegistrationScreen(registration: r),
                ),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            key: const Key('registration-add'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            onPressed: () => addRegistration(context),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Land hinzufügen'),
          ),
          const SizedBox(height: 4),
          Text(
            'Zum Beispiel eine deutsche USt-Nummer wegen eines '
            'Amazon-Lagers. Belege und Termine laufen dann je Land.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  /// Länderauswahl als Bottom-Sheet (Daumenbereich), dann das Formular.
  static Future<void> addRegistration(BuildContext context) async {
    final state = AppScope.read(context);
    final home = state.profile!.country;
    final taken = {for (final r in state.registrations) r.country};
    final country = await showModalBottomSheet<Country>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in Country.values)
                if (c != home)
                  ListTile(
                    key: Key('registration-country-${c.code}'),
                    minTileHeight: 56,
                    leading: _CountryBadge(c.code),
                    title: Text(c.label),
                    enabled: !taken.contains(c),
                    subtitle: taken.contains(c)
                        ? const Text('schon angelegt')
                        : null,
                    onTap: () => Navigator.of(context).pop(c),
                  ),
              for (final (code, name) in upcomingRegistrationCountries)
                ListTile(
                  minTileHeight: 56,
                  enabled: false,
                  leading: _CountryBadge(code),
                  title: Text(name),
                  trailing: const Text('bald'),
                ),
            ],
          ),
        ),
      ),
    );
    if (country == null || !context.mounted) return;
    final tax = country.taxProfile;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaxRegistrationScreen(
          registration: TaxRegistration(
            country: country,
            taxOffice: tax.foreignTaxOffices[home.code] ?? '',
          ),
        ),
      ),
    );
  }
}

class _CountryBadge extends StatelessWidget {
  const _CountryBadge(this.code);
  final String code;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 18,
    child: Text(code, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}

/// Formular einer weiteren Registrierung (FA-18.2).
class TaxRegistrationScreen extends StatefulWidget {
  const TaxRegistrationScreen({super.key, required this.registration});

  final TaxRegistration registration;

  @override
  State<TaxRegistrationScreen> createState() => _TaxRegistrationScreenState();
}

class _TaxRegistrationScreenState extends State<TaxRegistrationScreen> {
  final _form = GlobalKey<FormState>();
  late final _vatId = TextEditingController(text: widget.registration.vatId);

  /// EU-KU-Nummer (FA-18.10): gehört zum Unternehmen, nicht zum Land, und
  /// steht deshalb im Firmenprofil getrennt von der UID.
  final _euSmeId = TextEditingController();

  @override
  void initState() {
    super.initState();
    _euSmeId.text = AppScope.read(context).profile?.euSmeId ?? '';
  }

  late final _taxNumber = TextEditingController(
    text: widget.registration.taxNumber,
  );
  late final _taxOffice = TextEditingController(
    text: widget.registration.taxOffice,
  );
  late VatScheme _scheme = widget.registration.scheme;
  late FilingInterval _interval = widget.registration.interval;
  late bool _extension = widget.registration.permanentExtension;
  late DateTime? _from = widget.registration.validFrom;
  late DateTime? _to = widget.registration.validTo;
  bool _saving = false;

  Country get _country => widget.registration.country;

  @override
  void dispose() {
    _vatId.dispose();
    _euSmeId.dispose();
    _taxNumber.dispose();
    _taxOffice.dispose();
    super.dispose();
  }

  /// UID-Format wie überall (VatIdFormat) und Länderpräfix passend zum Land.
  String? _validateVatId(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    final error = VatIdFormat.check(v);
    if (error != null) return error;
    final code = VatIdFormat.countryCode(VatIdFormat.normalize(v));
    if (code != _country.code) {
      return 'Die Nummer muss mit ${_country.code} beginnen.';
    }
    return null;
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (start ? _from : _to) ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() => start ? _from = picked : _to = picked);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    // Demo (FA-13.14): nichts speichern.
    if (!await ensureWritable(context)) return;
    if (!mounted) return;
    setState(() => _saving = true);
    final state = AppScope.read(context);
    final eu = _scheme == VatScheme.euSmallBusiness;
    final profile = state.profile;
    final euSmeId = EuSmeIdFormat.normalize(_euSmeId.text.trim());
    if (eu && profile != null && profile.euSmeId != euSmeId) {
      await state.saveProfile(profile.copyWith(euSmeId: euSmeId));
    }
    await state.saveRegistration(
      widget.registration.copyWith(
        // Im EU-KU-Verfahren gibt es im anderen Land keine eigene UID.
        vatId: eu ? '' : VatIdFormat.normalize(_vatId.text.trim()),
        taxNumber: _taxNumber.text.trim(),
        taxOffice: _taxOffice.text.trim(),
        scheme: _scheme,
        interval: _scheme == VatScheme.standard
            ? _interval
            : FilingInterval.none,
        permanentExtension: _scheme == VatScheme.standard && _extension,
        validFrom: _from,
        clearValidFrom: _from == null,
        validTo: _to,
        clearValidTo: _to == null,
      ),
    );
    if (!mounted) return;
    showSnack(context, '${_country.label} gespeichert');
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final id = widget.registration.id;
    if (id == null) return;
    final ok = await confirmDestructive(
      context,
      title: '${_country.label} entfernen?',
      message: 'Termine für dieses Land verschwinden.',
      verb: 'Entfernen',
    );
    if (!ok || !mounted) return;
    final deleted = await AppScope.read(context).deleteRegistration(id);
    if (!mounted) return;
    if (!deleted) {
      showSnack(
        context,
        'Es gibt Belege mit diesem Steuerland. Bitte stattdessen ein '
        'Ende-Datum setzen.',
      );
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final home = state.profile?.country ?? Country.at;
    final tax = _country.taxProfile;
    final suggestion = tax.foreignTaxOffices[home.code];
    return Scaffold(
      appBar: AppBar(title: Text('Registrierung ${_country.label}')),
      bottomNavigationBar: PrimaryActionBar(
        primary: PrimaryActionBar.filled(
          key: const Key('registration-save'),
          label: 'Speichern',
          icon: Icons.check,
          busy: _saving,
          onPressed: _saving ? null : _save,
        ),
      ),
      body: ReadableWidth(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              DropdownButtonFormField<VatScheme>(
                key: const Key('registration-scheme'),
                initialValue: _scheme,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Besteuerung in diesem Land',
                ),
                items: [
                  for (final s in VatScheme.values)
                    DropdownMenuItem(value: s, child: Text(s.label)),
                ],
                onChanged: (v) => setState(() => _scheme = v ?? _scheme),
              ),
              const SizedBox(height: 6),
              Text(
                _scheme == VatScheme.standard
                    ? 'Üblich bei einem Lager im Ausland (z. B. Amazon FBA): '
                          'dort Umsatzsteuer ausweisen und melden.'
                    : 'Nur nach Rücksprache mit der Steuerberatung – für '
                          'Unternehmen aus dem Ausland oft nicht möglich.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              if (_scheme == VatScheme.euSmallBusiness)
                TextFormField(
                  key: const Key('registration-eu-sme-id'),
                  controller: _euSmeId,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'EU-KU-Nummer (EX)',
                    hintText: EuSmeIdFormat.example(home),
                    helperText:
                        'Vergibt dein Finanzamt in ${home.label}. Getrennt '
                        'von deiner UID; erscheint auf Rechnungen an Kunden '
                        'in ${_country.label}.',
                    helperMaxLines: 3,
                  ),
                  validator: (v) => EuSmeIdFormat.check(v ?? '', home: home),
                )
              else
                TextFormField(
                  key: const Key('registration-vat-id'),
                  controller: _vatId,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: tax.vatIdLabel,
                    hintText: tax.vatIdExample,
                  ),
                  validator: _validateVatId,
                ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _taxNumber,
                decoration: InputDecoration(labelText: tax.taxNumberLabel),
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('registration-tax-office'),
                controller: _taxOffice,
                decoration: InputDecoration(
                  labelText: 'Finanzamt',
                  helperText: suggestion == null
                      ? null
                      : 'Vorschlag: $suggestion (${tax.foreignTaxOfficeLegalRef})',
                  helperMaxLines: 2,
                ),
              ),
              if (_scheme == VatScheme.standard) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<FilingInterval>(
                  key: const Key('registration-interval'),
                  initialValue: _interval == FilingInterval.none
                      ? FilingInterval.monthly
                      : _interval,
                  decoration: InputDecoration(
                    labelText: '${tax.vatReturnLabel}: Zeitraum',
                  ),
                  items: [
                    for (final i in FilingInterval.values)
                      if (i != FilingInterval.none)
                        DropdownMenuItem(value: i, child: Text(i.label)),
                  ],
                  onChanged: (v) => setState(() => _interval = v ?? _interval),
                ),
                if (tax.hasPermanentExtension &&
                    _interval != FilingInterval.annual)
                  SwitchListTile(
                    key: const Key('registration-extension'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Dauerfristverlängerung'),
                    subtitle: const Text('Abgabe einen Monat später'),
                    value: _extension,
                    onChanged: (v) => setState(() => _extension = v),
                  ),
              ],
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                minTileHeight: 56,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Beginn'),
                subtitle: Text(_from == null ? 'offen' : Fmt.date(_from!)),
                onTap: () => _pickDate(start: true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                minTileHeight: 56,
                leading: const Icon(Icons.event_busy_outlined),
                title: const Text('Ende'),
                subtitle: Text(_to == null ? 'offen' : Fmt.date(_to!)),
                onTap: () => _pickDate(start: false),
              ),
              if (widget.registration.id != null)
                DangerZone(
                  buttonKey: const Key('registration-delete'),
                  label: 'Land entfernen',
                  icon: Icons.delete_outline,
                  explanation:
                      'Nur möglich, solange keine Belege dieses Land haben.',
                  onPressed: _delete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
