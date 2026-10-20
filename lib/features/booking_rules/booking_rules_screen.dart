import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../domain/booking_rule.dart';
import '../../domain/receipt.dart';
import '../../services/licensing/license_policy.dart';
import '../../services/receipt_image_store.dart';
import '../../services/receipt_scan/document_picker.dart';
import '../../services/receipt_scan/document_scanner.dart'
    show DocumentScanException;
import '../../widgets/adaptive.dart';
import '../../widgets/common.dart';
import '../../widgets/primary_action_bar.dart';
import '../licensing/feature_gate.dart';

/// Liste der Buchungsregeln (FA-20.1, Bildschirm „Buchungsregeln“).
class BookingRulesScreen extends StatefulWidget {
  const BookingRulesScreen({super.key});

  @override
  State<BookingRulesScreen> createState() => _BookingRulesScreenState();
}

class _BookingRulesScreenState extends State<BookingRulesScreen> {
  List<BookingRule>? _rules;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final rules = await AppScope.read(context).repositories.bookingRules.all();
    if (mounted) setState(() => _rules = rules);
  }

  Future<void> _open([BookingRule? rule]) async {
    await openBookingRule(context, rule: rule);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final rules = _rules;
    return Scaffold(
      appBar: AppBar(title: const Text('Buchungsregeln')),
      bottomNavigationBar: PrimaryActionBar(
        primary: PrimaryActionBar.filled(
          key: const Key('booking-rule-new'),
          label: proLabel(context, Feature.bookingRules, 'Regel anlegen'),
          icon: Icons.add,
          onPressed: () => _open(),
        ),
      ),
      body: ReadableWidth(
        child: rules == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Für gemischt genutzte Ausgaben, z. B. Privat-PKW oder '
                    'Büro in der Wohnung: nur der betriebliche Anteil zählt, '
                    'der Rest ist Privatanteil. Grundlage für die '
                    'Steuerberatung – ersetzt keine individuelle Beratung.',
                  ),
                  const SizedBox(height: 12),
                  if (rules.isEmpty)
                    const EmptyState(
                      icon: Icons.rule,
                      title: 'Noch keine Regel',
                      message:
                          'Vorlagen mit Beispielen findest du in der Hilfe.',
                    ),
                  for (final r in rules)
                    ListTile(
                      key: Key('booking-rule-${r.id}'),
                      minTileHeight: 56,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.rule),
                      title: Text(r.shortLabel),
                      subtitle: Text(
                        '${r.basis.label} · ab ${Fmt.date(r.validFrom)}'
                        '${r.validTo == null ? '' : ' bis ${Fmt.date(r.validTo!)}'}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(r),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Öffnet eine Regel bzw. ein neues Formular, optional mit [template].
Future<void> openBookingRule(
  BuildContext context, {
  BookingRule? rule,
  BookingRule? template,
}) async {
  if (rule == null && !await ensureFeature(context, Feature.bookingRules)) {
    return;
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => BookingRuleEditScreen(rule: rule ?? template),
    ),
  );
}

/// Formular einer Buchungsregel (FA-20.1, FA-20.2).
class BookingRuleEditScreen extends StatefulWidget {
  const BookingRuleEditScreen({super.key, this.rule});

  /// Bestehende Regel (mit ID) oder Vorlage (ohne ID).
  final BookingRule? rule;

  @override
  State<BookingRuleEditScreen> createState() => _BookingRuleEditScreenState();
}

class _BookingRuleEditScreenState extends State<BookingRuleEditScreen> {
  final _name = TextEditingController();
  final _percent = TextEditingController();
  final _part = TextEditingController();
  final _total = TextEditingController();
  final _supplier = TextEditingController();
  final _comment = TextEditingController();
  var _type = BookingRuleType.businessShare;
  var _basis = BookingRuleBasis.estimate;
  var _registration = BookingRuleRegistration.all;
  var _categories = <int>{};
  var _from = DateTime(DateTime.now().year, 1, 1);
  DateTime? _to;
  int? _id;
  var _busy = false;
  List<BookingRuleAttachment> _attachments = const [];
  List<BookingRuleLogEntry> _log = const [];

  @override
  void initState() {
    super.initState();
    final r = widget.rule;
    if (r != null) {
      _id = r.id;
      _name.text = r.name;
      _type = r.type;
      _basis = r.basis;
      _registration = r.registration == BookingRuleRegistration.one
          ? BookingRuleRegistration.all
          : r.registration;
      _categories = {...r.categoryIds};
      _supplier.text = r.supplier;
      _comment.text = r.comment;
      _from = r.validFrom;
      _to = r.validTo;
      final shown = r.type == BookingRuleType.privateShare
          ? r.privatePermille
          : r.businessPermille;
      _percent.text = formatPermille(shown).replaceAll(' %', '');
      if (r.basisPartMilli != null) _part.text = _milli(r.basisPartMilli!);
      if (r.basisTotalMilli != null) _total.text = _milli(r.basisTotalMilli!);
    }
    _part.addListener(_recompute);
    _total.addListener(_recompute);
    _loadExtras();
  }

  static String _milli(int v) {
    final whole = v ~/ 1000;
    final frac = v % 1000;
    if (frac == 0) return '$whole';
    var f = frac.toString().padLeft(3, '0');
    while (f.endsWith('0')) {
      f = f.substring(0, f.length - 1);
    }
    return '$whole,$f';
  }

  /// „12,5“ → 12500 (Tausendstel); `null` bei ungültiger Eingabe.
  static int? parseMilli(String text) {
    final t = text.trim().replaceAll('.', '').replaceAll(' ', '');
    final m = RegExp(r'^(\d+)(?:,(\d{1,3}))?$').firstMatch(t);
    if (m == null) return null;
    final frac = (m.group(2) ?? '').padRight(3, '0');
    return int.parse(m.group(1)!) * 1000 + int.parse(frac);
  }

  /// Prozent „12,5“ → 125 Promille.
  static int? parsePercent(String text) {
    final milli = parseMilli(text);
    if (milli == null || milli % 100 != 0) return null;
    return milli ~/ 100;
  }

  void _recompute() {
    if (!_basis.computesShare) return;
    final share = BookingRule.shareFromBasis(
      parseMilli(_part.text),
      parseMilli(_total.text),
    );
    if (share == null) return;
    final shown = _type == BookingRuleType.privateShare ? 1000 - share : share;
    final text = formatPermille(shown).replaceAll(' %', '');
    if (_percent.text != text) setState(() => _percent.text = text);
  }

  Future<void> _loadExtras() async {
    final id = _id;
    if (id == null) return;
    final repo = AppScope.read(context).repositories.bookingRules;
    final a = await repo.attachments(id);
    final l = await repo.log(id);
    if (mounted) {
      setState(() {
        _attachments = a;
        _log = l;
      });
    }
  }

  BookingRule? _build() {
    final shown = parsePercent(_percent.text);
    if (shown == null) return null;
    final business = _type == BookingRuleType.privateShare
        ? 1000 - shown
        : shown;
    return BookingRule(
      id: _id,
      name: _name.text,
      type: _type,
      categoryIds: _categories,
      supplier: _supplier.text,
      registration: _registration,
      businessPermille: business,
      basis: _basis,
      basisPartMilli: parseMilli(_part.text),
      basisTotalMilli: parseMilli(_total.text),
      validFrom: _from,
      validTo: _to,
      comment: _comment.text,
    );
  }

  Future<void> _save() async {
    if (!await ensureFeature(context, Feature.bookingRules)) return;
    if (!mounted) return;
    final rule = _build();
    if (rule == null) {
      showSnack(context, 'Bitte den Anteil in Prozent eingeben, z. B. 30.');
      return;
    }
    final errors = rule.validate();
    if (errors.isNotEmpty) {
      showSnack(context, errors.first);
      return;
    }
    setState(() => _busy = true);
    try {
      final saved = await AppScope.read(
        context,
      ).repositories.bookingRules.save(rule);
      if (!mounted) return;
      AppScope.read(context).reload();
      setState(() => _id = saved.id);
      await _loadExtras();
      if (mounted) showSnack(context, 'Regel gespeichert');
    } on Exception catch (e) {
      if (mounted) showSnack(context, 'Nicht gespeichert: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addAttachment(bool camera) async {
    final id = _id;
    if (id == null) {
      showSnack(context, 'Bitte die Regel zuerst speichern.');
      return;
    }
    if (!await ensureFeature(context, Feature.bookingRules)) return;
    List<File> files;
    try {
      if (camera) {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.camera,
          maxWidth: 2000,
          maxHeight: 2000,
          imageQuality: 85,
        );
        files = picked == null ? [] : [File(picked.path)];
      } else {
        files = await const DocumentPicker().pick();
      }
    } on DocumentScanException catch (e) {
      if (mounted) showSnack(context, e.message);
      return;
    }
    if (files.isEmpty || !mounted) return;
    final note = await _askNote();
    if (!mounted) return;
    final repo = AppScope.read(context).repositories.bookingRules;
    for (final f in files) {
      final rel = await ReceiptImageStore.store(f);
      await repo.addAttachment(
        ruleId: id,
        filePath: rel,
        fileName: f.uri.pathSegments.last,
        note: note ?? '',
      );
    }
    await _loadExtras();
  }

  Future<String?> _askNote() {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notiz zum Anhang'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'z. B. Büro im Grundriss rot markiert',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Ohne Notiz'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(bool from) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? _from : (_to ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => from ? _from = picked : _to = picked);
  }

  @override
  void dispose() {
    for (final c in [_name, _percent, _part, _total, _supplier, _comment]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final expenseCategories = state.categories
        .where((c) => c.direction == BookingDirection.expense)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(_id == null ? 'Neue Buchungsregel' : 'Buchungsregel'),
      ),
      bottomNavigationBar: PrimaryActionBar(
        primary: PrimaryActionBar.filled(
          key: const Key('booking-rule-save'),
          label: 'Speichern',
          icon: Icons.check,
          busy: _busy,
          onPressed: _save,
        ),
      ),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              key: const Key('booking-rule-name'),
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Name, z. B. PKW oder Büro',
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<BookingRuleType>(
              segments: [
                for (final t in BookingRuleType.values)
                  ButtonSegment(value: t, label: Text(t.label)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                final old = parsePercent(_percent.text);
                _type = s.first;
                if (old != null) {
                  _percent.text = formatPermille(
                    1000 - old,
                  ).replaceAll(' %', '');
                }
              }),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<BookingRuleBasis>(
              initialValue: _basis,
              decoration: const InputDecoration(labelText: 'Grundlage'),
              items: [
                for (final b in BookingRuleBasis.values)
                  DropdownMenuItem(value: b, child: Text(b.label)),
              ],
              onChanged: (b) => setState(() {
                _basis = b ?? _basis;
                _recompute();
              }),
            ),
            if (_basis != BookingRuleBasis.estimate) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('booking-rule-part'),
                      controller: _part,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(labelText: _basis.partLabel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      key: const Key('booking-rule-total'),
                      controller: _total,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(labelText: _basis.totalLabel),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              key: const Key('booking-rule-percent'),
              controller: _percent,
              readOnly: _basis.computesShare,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: '${_type.label} in %',
                suffixText: '%',
                helperText: _basis.computesShare
                    ? 'Aus den Zahlen berechnet'
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Text('Gilt für Kategorien', style: _label(context)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in expenseCategories)
                  FilterChip(
                    label: Text(c.name),
                    selected: _categories.contains(c.id),
                    onSelected: (on) => setState(
                      () => on
                          ? _categories.add(c.id!)
                          : _categories.remove(c.id),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _supplier,
              decoration: const InputDecoration(
                labelText: 'Nur Lieferant (freiwillig)',
                hintText: 'z. B. OMV',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<BookingRuleRegistration>(
              initialValue: _registration,
              decoration: const InputDecoration(labelText: 'Steuerland'),
              items: const [
                DropdownMenuItem(
                  value: BookingRuleRegistration.all,
                  child: Text('Alle Steuerländer'),
                ),
                DropdownMenuItem(
                  value: BookingRuleRegistration.home,
                  child: Text('Nur Heimatland'),
                ),
              ],
              onChanged: (r) =>
                  setState(() => _registration = r ?? _registration),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () => _pickDate(true),
                    child: Text('Ab ${Fmt.date(_from)}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () => _pickDate(false),
                    onLongPress: () => setState(() => _to = null),
                    child: Text(
                      _to == null ? 'Unbefristet' : 'Bis ${Fmt.date(_to!)}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('booking-rule-comment'),
              controller: _comment,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Begründung (für die Steuerberatung)',
              ),
            ),
            const SizedBox(height: 16),
            Text('Anhänge', style: _label(context)),
            for (final a in _attachments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.attach_file),
                title: Text(a.fileName),
                subtitle: a.note.isEmpty ? null : Text(a.note),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () => _addAttachment(true),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Foto'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () => _addAttachment(false),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Datei'),
                  ),
                ),
              ],
            ),
            if (_log.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Verlauf', style: _label(context)),
              for (final e in _log)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('${Fmt.dateTime(e.createdAt)}: ${e.text}'),
                ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Grundlage für die Steuerberatung – ersetzt keine individuelle '
              'Beratung.',
            ),
          ],
        ),
      ),
    );
  }

  TextStyle? _label(BuildContext context) =>
      Theme.of(context).textTheme.titleSmall;
}
