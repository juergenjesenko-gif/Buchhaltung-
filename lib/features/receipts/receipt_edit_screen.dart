import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../domain/country.dart';
import '../../domain/money.dart';
import '../../domain/receipt.dart';
import '../../services/receipt_image_store.dart';
import '../../services/vat_calculator.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Beleg erfassen oder bearbeiten.
///
/// Der Betrag wird brutto eingegeben – das ist die Zahl, die auf dem Beleg
/// steht. Netto und Umsatzsteuer rechnet die App heraus und zeigt sie live an,
/// damit der Nutzer den Steuersatz sofort kontrollieren kann.
class ReceiptEditScreen extends StatefulWidget {
  const ReceiptEditScreen({super.key, required this.direction, this.existing});

  final BookingDirection direction;
  final Receipt? existing;

  @override
  State<ReceiptEditScreen> createState() => _ReceiptEditScreenState();
}

class _ReceiptEditScreenState extends State<ReceiptEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _grossController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _counterpartyController = TextEditingController();
  final _noteController = TextEditingController();

  late BookingDirection _direction;
  DateTime _date = DateTime.now();
  int _vatPermille = 0;
  int? _categoryId;
  PaymentMethod _paymentMethod = PaymentMethod.bank;
  String? _imagePath;
  File? _imageFile;
  bool _saving = false;
  bool _initialized = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _direction = widget.direction;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final state = AppScope.read(context);
    final existing = widget.existing;

    if (existing != null) {
      _direction = existing.direction;
      _date = existing.date;
      _vatPermille = existing.vatPermille;
      _categoryId = existing.categoryId;
      _paymentMethod = existing.paymentMethod;
      _imagePath = existing.imagePath;
      _grossController.text = Fmt.amount(existing.gross);
      _descriptionController.text = existing.description;
      _counterpartyController.text = existing.counterparty;
      _noteController.text = existing.note;
      _loadImage();
    } else {
      _vatPermille = state.defaultVatPermille;
      final categories = state.categoriesFor(_direction);
      if (categories.isNotEmpty) _categoryId = categories.first.id;
    }
  }

  @override
  void dispose() {
    _grossController.dispose();
    _descriptionController.dispose();
    _counterpartyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    final file = await ReceiptImageStore.resolve(_imagePath);
    if (mounted) setState(() => _imageFile = file);
  }

  Money? get _gross => Money.tryParse(_grossController.text);

  VatSplit? get _split {
    final gross = _gross;
    if (gross == null) return null;
    return VatCalculator.fromGross(gross, _vatPermille);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        // 2000 px Kantenlänge und 85 % Qualität: gut lesbar, aber ein Beleg
        // belegt nicht mehrere Megabyte auf dem Telefon.
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 85,
      );
      if (picked == null) return;
      final relative = await ReceiptImageStore.store(File(picked.path));
      if (!mounted) return;
      setState(() => _imagePath = relative);
      await _loadImage();
    } on Exception catch (error) {
      if (mounted) {
        showSnack(context, 'Foto konnte nicht übernommen werden: $error');
      }
    }
  }

  Future<void> _removeImage() async {
    await ReceiptImageStore.delete(_imagePath);
    if (!mounted) return;
    setState(() {
      _imagePath = null;
      _imageFile = null;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      // Belege aus der Zukunft sind kein sinnvoller Fall, ein paar Jahre
      // rückwärts dagegen schon – Nachbuchungen passieren.
      firstDate: DateTime(DateTime.now().year - 8),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('de'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final split = _split;
    if (split == null) return;

    setState(() => _saving = true);
    final state = AppScope.read(context);

    final receipt = Receipt(
      id: widget.existing?.id,
      date: _date,
      direction: _direction,
      description: _descriptionController.text.trim(),
      counterparty: _counterpartyController.text.trim(),
      net: split.net,
      vat: split.vat,
      gross: split.gross,
      vatPermille: _vatPermille,
      categoryId: _categoryId,
      paymentMethod: _paymentMethod,
      imagePath: _imagePath,
      note: _noteController.text.trim(),
      createdAt: widget.existing?.createdAt,
    );

    await state.repositories.receipts.save(receipt);
    await state.onBookingsChanged();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final id = widget.existing?.id;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Beleg löschen?'),
        content: const Text(
          'Der Beleg wird aus der Buchhaltung entfernt. Die Löschung wird im '
          'Änderungsprotokoll vermerkt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final state = AppScope.read(context);
    await state.repositories.receipts.delete(id);
    await ReceiptImageStore.delete(_imagePath);
    await state.onBookingsChanged();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final profile = state.profile;
    final tax = profile?.taxProfile ?? TaxProfile.austria;
    final categories = state.categoriesFor(_direction);
    final split = _split;
    final isIncome = _direction == BookingDirection.income;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? 'Beleg bearbeiten'
              : isIncome
              ? 'Einnahme erfassen'
              : 'Ausgabe erfassen',
        ),
        actions: [
          if (_isEditing)
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
              title: 'Betrag',
              child: Column(
                children: [
                  SegmentedButton<BookingDirection>(
                    segments: const [
                      ButtonSegment(
                        value: BookingDirection.expense,
                        label: Text('Ausgabe'),
                        icon: Icon(Icons.north_east),
                      ),
                      ButtonSegment(
                        value: BookingDirection.income,
                        label: Text('Einnahme'),
                        icon: Icon(Icons.south_west),
                      ),
                    ],
                    selected: {_direction},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _direction = selection.first;
                        // Kategorien sind richtungsabhängig – die alte Auswahl
                        // wäre nach dem Wechsel unsinnig.
                        final next = state.categoriesFor(_direction);
                        _categoryId = next.isEmpty ? null : next.first.id;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  MoneyField(
                    controller: _grossController,
                    label: 'Bruttobetrag (wie auf dem Beleg)',
                    autofocus: !_isEditing,
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      final money = Money.tryParse(value ?? '');
                      if (money == null) return 'Bitte gib einen Betrag ein';
                      if (money.isZero) return 'Der Betrag darf nicht 0 sein';
                      if (money.isNegative) {
                        return 'Bitte positiv eingeben und oben Einnahme/Ausgabe wählen';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: _vatPermille,
                    decoration: const InputDecoration(
                      labelText: 'Umsatzsteuersatz',
                    ),
                    items: [
                      for (final rate in tax.vatRates)
                        DropdownMenuItem(
                          value: rate.permille,
                          child: Text('${rate.display} – ${rate.label}'),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _vatPermille = value ?? 0),
                  ),
                  if (split != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          LabeledValue(
                            label: 'Netto',
                            value: Fmt.money(split.net),
                          ),
                          LabeledValue(
                            label: 'Umsatzsteuer ${Fmt.vatRate(_vatPermille)}',
                            value: Fmt.money(split.vat),
                          ),
                          LabeledValue(
                            label: 'Brutto',
                            value: Fmt.money(split.gross),
                            emphasize: true,
                            valueColor: AppTheme.amountColor(isIncome, context),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (profile != null &&
                      profile.isSmallBusiness &&
                      _vatPermille > 0) ...[
                    const SizedBox(height: 12),
                    NoticeBanner(
                      icon: Icons.info_outline,
                      color: AppTheme.warning,
                      message:
                          'Du bist als Kleinunternehmer eingestellt. Auf deinen '
                          'eigenen Rechnungen darf keine Umsatzsteuer stehen; bei '
                          'Ausgaben ist die Vorsteuer nicht abziehbar.',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            SectionCard(
              title: 'Beleg',
              child: Column(
                children: [
                  if (_imageFile != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        _imageFile!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _removeImage,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Foto entfernen'),
                      ),
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('Fotografieren'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Auswählen'),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Belege sind ${tax.retentionYears} Jahre aufzubewahren. '
                    'Das Foto bleibt auf diesem Gerät – denk an ein Backup.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            SectionCard(
              title: 'Details',
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Belegdatum'),
                    subtitle: Text(Fmt.date(_date)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickDate,
                  ),
                  const Divider(height: 8),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Beschreibung',
                      hintText: 'z. B. Bürostuhl, Tankrechnung',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Eine Beschreibung ist Pflicht – ohne sie ist der Beleg '
                              'später nicht nachvollziehbar'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _counterpartyController,
                    decoration: InputDecoration(
                      labelText: isIncome ? 'Kunde' : 'Lieferant',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: _categoryId,
                    decoration: const InputDecoration(labelText: 'Kategorie'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Nicht zugeordnet'),
                      ),
                      for (final category in categories)
                        DropdownMenuItem<int?>(
                          value: category.id,
                          child: Text(category.name),
                        ),
                    ],
                    onChanged: (value) => setState(() => _categoryId = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PaymentMethod>(
                    initialValue: _paymentMethod,
                    decoration: const InputDecoration(labelText: 'Zahlungsart'),
                    items: [
                      for (final method in PaymentMethod.values)
                        DropdownMenuItem(
                          value: method,
                          child: Text(method.label),
                        ),
                    ],
                    onChanged: (value) => setState(
                      () => _paymentMethod = value ?? PaymentMethod.bank,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _noteController,
                    decoration: const InputDecoration(labelText: 'Notiz'),
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
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
              : Text(_isEditing ? 'Änderungen speichern' : 'Beleg speichern'),
        ),
      ),
    );
  }
}
