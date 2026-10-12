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
  final _commentController = TextEditingController();

  late BookingDirection _direction;
  DateTime _date = DateTime.now();
  int _vatPermille = 0;
  int? _categoryId;
  PaymentMethod _paymentMethod = PaymentMethod.bank;

  /// Seiten des Belegs in fester Reihenfolge (L-2.15), relative Pfade.
  final List<String> _pages = [];

  /// Aufgelöste Dateien zur Vorschau, je relativem Pfad.
  final Map<String, File> _pageFiles = {};

  /// So viele Seiten sind bereits gespeichert und damit fest: sie lassen sich
  /// weder löschen noch umsortieren, nur ergänzen.
  int _savedPageCount = 0;

  /// Vollständigkeitsbestätigung vor dem Buchen neuer Seiten (L-2.16).
  bool _pagesConfirmed = false;

  List<ReceiptComment> _comments = const [];
  bool _saving = false;
  bool _initialized = false;

  bool get _isEditing => widget.existing != null;

  bool get _isCancelled => widget.existing?.isCancelled ?? false;

  bool get _hasNewPages => _pages.length > _savedPageCount;

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
      _grossController.text = Fmt.amount(existing.gross);
      _descriptionController.text = existing.description;
      _counterpartyController.text = existing.counterparty;
      _noteController.text = existing.note;
      _loadPagesAndComments(existing);
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
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadPagesAndComments(Receipt existing) async {
    final repo = AppScope.read(context).repositories.receipts;
    final id = existing.id!;
    final pages = await repo.pages(id);
    final comments = await repo.comments(id);
    // Belege vor Schema 8 ohne Seiteneintrag: das Einzelfoto zählt als Seite.
    final paths = pages.isEmpty && existing.hasImage
        ? [existing.imagePath!]
        : [for (final page in pages) page.imagePath];
    if (!mounted) return;
    setState(() {
      _pages
        ..clear()
        ..addAll(paths);
      _savedPageCount = paths.length;
      _comments = comments;
    });
    await _resolveFiles();
  }

  Future<void> _resolveFiles() async {
    for (final path in _pages) {
      if (_pageFiles.containsKey(path)) continue;
      final file = await ReceiptImageStore.resolve(path);
      if (file != null) _pageFiles[path] = file;
    }
    if (mounted) setState(() {});
  }

  Money? get _gross => Money.tryParse(_grossController.text);

  VatSplit? get _split {
    final gross = _gross;
    if (gross == null) return null;
    return VatCalculator.fromGross(gross, _vatPermille);
  }

  /// Nimmt eine weitere Seite auf und hängt sie hinten an.
  Future<void> _addPage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        // 2000 px Kantenlänge und 85 % Qualität: gut lesbar, aber ein Beleg
        // belegt nicht mehrere Megabyte auf dem Telefon. Danach wird die
        // gespeicherte Aufnahme nie mehr verändert (L-2.15).
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 85,
      );
      if (picked == null) return;
      final relative = await ReceiptImageStore.store(File(picked.path));
      if (!mounted) return;
      setState(() {
        _pages.add(relative);
        _pagesConfirmed = false;
      });
      await _resolveFiles();
    } on Exception catch (error) {
      if (mounted) {
        showSnack(context, 'Foto konnte nicht übernommen werden: $error');
      }
    }
  }

  /// Verschiebt eine noch nicht gespeicherte Seite um [delta] Plätze.
  void _movePage(int index, int delta) {
    final target = index + delta;
    if (index < _savedPageCount ||
        target < _savedPageCount ||
        target >= _pages.length) {
      return;
    }
    setState(() {
      final page = _pages.removeAt(index);
      _pages.insert(target, page);
    });
  }

  /// Löscht eine noch nicht gespeicherte Seite samt Datei.
  Future<void> _removePage(int index) async {
    if (index < _savedPageCount) return;
    final path = _pages[index];
    setState(() {
      _pages.removeAt(index);
      _pageFiles.remove(path);
      _pagesConfirmed = false;
    });
    await ReceiptImageStore.delete(path);
  }

  void _showPage(int index) {
    final file = _pageFiles[_pages[index]];
    if (file == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('Seite ${index + 1} von ${_pages.length}'),
            ),
            Flexible(
              child: InteractiveViewer(
                maxScale: 5,
                child: Image.file(file, fit: BoxFit.contain),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Schließen'),
            ),
          ],
        ),
      ),
    );
  }

  /// Hängt einen Kommentar an einen gespeicherten Beleg an – auch wenn er
  /// gebucht oder storniert ist (L-2.17).
  Future<void> _appendComment() async {
    final id = widget.existing?.id;
    final text = _commentController.text.trim();
    if (id == null || text.isEmpty) return;
    final repo = AppScope.read(context).repositories.receipts;
    await repo.addComment(id, text);
    final comments = await repo.comments(id);
    if (!mounted) return;
    _commentController.clear();
    setState(() => _comments = comments);
    showSnack(context, 'Kommentar angehängt');
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
    if (_isCancelled) return;
    if (!_formKey.currentState!.validate()) return;
    final split = _split;
    if (split == null) return;
    if (_hasNewPages && !_pagesConfirmed) {
      showSnack(
        context,
        'Bitte bestätige, dass alle Seiten des Belegs erfasst sind.',
      );
      return;
    }

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
      imagePath: _pages.isEmpty ? null : _pages.first,
      note: _noteController.text.trim(),
      createdAt: widget.existing?.createdAt,
    );

    await state.repositories.receipts.save(
      receipt,
      pages: List.of(_pages),
      // Beim Erfassen wird das Kommentarfeld zum ersten Kommentar; bei einem
      // gespeicherten Beleg hängt man Kommentare über die eigene Schaltfläche an.
      comment: _isEditing ? null : _commentController.text,
    );
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
        title: const Text('Beleg stornieren?'),
        content: const Text(
          'Der Beleg zählt danach in keiner Auswertung mehr. Er wird aber nicht '
          'gelöscht, sondern bleibt mit Foto aufbewahrt, weil Belege einer '
          'gesetzlichen Aufbewahrungspflicht unterliegen. Die Stornierung wird '
          'im Änderungsprotokoll vermerkt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Stornieren'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final state = AppScope.read(context);
    await state.repositories.receipts.cancel(id);
    await state.onBookingsChanged();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Widget _buildPages(BuildContext context, TaxProfile tax) {
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_pages.isNotEmpty)
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _pages.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final file = _pageFiles[_pages[index]];
                final editable = index >= _savedPageCount && !_isCancelled;
                return SizedBox(
                  width: 120,
                  child: Column(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _showPage(index),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: file == null
                                ? const ColoredBox(
                                    color: Colors.black12,
                                    child: Center(
                                      child: Icon(Icons.broken_image_outlined),
                                    ),
                                  )
                                : Image.file(
                                    file,
                                    width: 120,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                      ),
                      Text('Seite ${index + 1}', style: muted),
                      if (editable)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Nach vorne',
                              icon: const Icon(Icons.chevron_left),
                              onPressed: index > _savedPageCount
                                  ? () => _movePage(index, -1)
                                  : null,
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Seite löschen',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _removePage(index),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Nach hinten',
                              icon: const Icon(Icons.chevron_right),
                              onPressed: index < _pages.length - 1
                                  ? () => _movePage(index, 1)
                                  : null,
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        if (!_isCancelled) ...[
          if (_pages.isNotEmpty) const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _addPage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(
                    _pages.isEmpty ? 'Fotografieren' : 'Seite fotografieren',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _addPage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(_pages.isEmpty ? 'Auswählen' : 'Seite wählen'),
                ),
              ),
            ],
          ),
        ],
        if (_hasNewPages && !_isCancelled)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _pagesConfirmed,
            onChanged: (value) =>
                setState(() => _pagesConfirmed = value ?? false),
            title: const Text(
              'Alle Seiten inkl. beschriebener Rückseiten erfasst',
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'Belege sind ${tax.retentionYears} Jahre aufzubewahren. '
          'Die Fotos bleiben auf diesem Gerät – denk an ein Backup. '
          'Gespeicherte Seiten lassen sich nur noch ergänzen, nicht löschen.',
          style: muted,
        ),
      ],
    );
  }

  Widget _buildComments(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final comment in _comments) ...[
          Text(Fmt.dateTime(comment.createdAt), style: muted),
          Text(comment.text),
          const SizedBox(height: 10),
        ],
        if (_isEditing && _comments.isEmpty) ...[
          Text('Noch keine Kommentare.', style: muted),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: _commentController,
          minLines: 1,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: _isEditing ? 'Kommentar anhängen' : 'Kommentar',
            hintText: 'Tippen oder über das Mikrofon der Tastatur diktieren',
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (_isEditing) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: _commentController.text.trim().isEmpty
                  ? null
                  : _appendComment,
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('Anhängen'),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Kommentare werden mit Datum und Uhrzeit gespeichert und lassen sich '
          'danach nicht mehr ändern oder löschen; eine Korrektur ist ein neuer '
          'Kommentar. Diktieren übernimmt die Tastatur deines Geräts – je nach '
          'Einstellung kann sie die Sprache an Google oder Apple senden. Die '
          'App selbst überträgt nichts.',
          style: muted,
        ),
      ],
    );
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
          _isCancelled
              ? 'Stornierter Beleg'
              : _isEditing
              ? 'Beleg bearbeiten'
              : isIncome
              ? 'Einnahme erfassen'
              : 'Ausgabe erfassen',
        ),
        actions: [
          if (_isEditing && !_isCancelled)
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
            if (_isCancelled) ...[
              NoticeBanner(
                icon: Icons.block,
                color: AppTheme.warning,
                message:
                    'Dieser Beleg wurde am '
                    '${Fmt.date(widget.existing!.cancelledAt!)} storniert. Er '
                    'bleibt lesbar und zählt in keiner Auswertung. Kommentare '
                    'kannst du weiter anhängen.',
              ),
              const SizedBox(height: 16),
            ],
            IgnorePointer(
              ignoring: _isCancelled,
              child: SectionCard(
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
                              label:
                                  'Umsatzsteuer ${Fmt.vatRate(_vatPermille)}',
                              value: Fmt.money(split.vat),
                            ),
                            LabeledValue(
                              label: 'Brutto',
                              value: Fmt.money(split.gross),
                              emphasize: true,
                              valueColor: AppTheme.amountColor(
                                isIncome,
                                context,
                              ),
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
            ),
            const SizedBox(height: 16),

            SectionCard(
              title: _pages.length > 1
                  ? 'Beleg (${_pages.length} Seiten)'
                  : 'Beleg',
              child: _buildPages(context, tax),
            ),
            const SizedBox(height: 16),

            IgnorePointer(
              ignoring: _isCancelled,
              child: SectionCard(
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
                      decoration: const InputDecoration(
                        labelText: 'Zahlungsart',
                      ),
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
            ),
            const SizedBox(height: 16),
            SectionCard(title: 'Kommentare', child: _buildComments(context)),
          ],
        ),
      ),
      bottomNavigationBar: _isCancelled
          ? null
          : Padding(
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
                    : Text(
                        _isEditing ? 'Änderungen speichern' : 'Beleg speichern',
                      ),
              ),
            ),
    );
  }
}
