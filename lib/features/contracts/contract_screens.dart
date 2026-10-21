import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../domain/contract.dart';
import '../../domain/money.dart';
import '../../domain/receipt.dart';
import '../../services/contracts/contract_ocr.dart';
import '../../services/contracts/contract_schedule.dart';
import '../../services/contracts/contract_text_extractor.dart';
import '../../services/licensing/license_policy.dart';
import '../../services/receipt_image_store.dart';
import '../../services/receipt_scan/document_import.dart';
import '../../services/receipt_scan/document_scanner.dart';
import '../../services/receipt_scan/platform_text_recognizer.dart';
import '../../services/share_in/share_in_service.dart';
import '../../widgets/dictation_button.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/common.dart';
import '../../widgets/danger_zone.dart';
import '../../widgets/page_image_dialog.dart';
import '../../widgets/primary_action_bar.dart';
import '../help/help_screen.dart';
import '../licensing/feature_gate.dart';
import '../pdf_viewer/pdf_viewer_screen.dart';

String _amountText(Money m) =>
    '${m.cents ~/ 100},${(m.cents % 100).toString().padLeft(2, '0')}';

/// Vertragsarchiv (FA-16.1): Liste mit nächstem Termin.
/// Hinweis bei Dienstverträgen (L-23.8, Rückmeldung 2026-10-19).
const employeeContractHint =
    'Dienstverträge enthalten Daten deiner Mitarbeiter:innen. Sie bleiben '
    'nur auf diesem Gerät (und in deiner verschlüsselten Sicherung) und '
    'werden nie an eine KI oder an den Anbieter übertragen. Lege nur ab, was '
    'du für die Buchhaltung brauchst.';

class ContractListScreen extends StatefulWidget {
  const ContractListScreen({super.key});

  @override
  State<ContractListScreen> createState() => _ContractListScreenState();
}

class _ContractListScreenState extends State<ContractListScreen> {
  List<Contract>? _contracts;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final list = await AppScope.read(context).repositories.contracts.all();
    if (mounted) setState(() => _contracts = list);
  }

  Future<void> _open([Contract? c]) async {
    if (c == null && !await ensureFeature(context, Feature.newBookings)) {
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ContractEditScreen(contract: c)),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final list = _contracts;
    final today = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verträge'),
        actions: const [HelpButton()],
      ),
      bottomNavigationBar: PrimaryActionBar(
        primary: PrimaryActionBar.filled(
          key: const Key('contract-new'),
          label: 'Vertrag ablegen',
          icon: Icons.add_a_photo_outlined,
          onPressed: () => _open(),
        ),
      ),
      body: ReadableWidth(
        child: list == null
            ? const Center(child: CircularProgressIndicator())
            : list.isEmpty
            ? const EmptyState(
                icon: Icons.description_outlined,
                title: 'Noch keine Verträge',
                message:
                    'Miete, Pacht, Leasing, Versicherung, Darlehen: Vertrag '
                    'fotografieren, Rate und Fristen eintragen – die App '
                    'erinnert in der Übersicht.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  for (final c in list)
                    Card(
                      child: ListTile(
                        minVerticalPadding: 12,
                        title: Text(c.title),
                        subtitle: Text(
                          [
                            c.type.label,
                            if (c.partner.isNotEmpty) c.partner,
                            ?_nextLabel(c, today),
                          ].join(' · '),
                        ),
                        trailing: c.rate.isZero
                            ? null
                            : Text(
                                '${Fmt.money(c.rate)}\n${c.rhythm.label}',
                                textAlign: TextAlign.right,
                              ),
                        onTap: () => _open(c),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Nächster Termin eines Vertrags für die Liste, z. B. „Kündigen bis 1.3.“.
String? _nextLabel(Contract c, DateTime today) {
  final next = ContractSchedule.deadlines([c], today);
  if (next.isEmpty) return null;
  return '${next.first.label.split(':').first} ${Fmt.date(next.first.date)}';
}

/// Vertrag ablegen bzw. ansehen (FA-16.1 bis FA-16.8).
class ContractEditScreen extends StatefulWidget {
  const ContractEditScreen({
    super.key,
    this.contract,
    this.sharedFiles = const [],
  });

  final Contract? contract;

  /// Über „Teilen“ empfangene Dateien (aus dem Belegformular weitergereicht).
  final List<File> sharedFiles;

  @override
  State<ContractEditScreen> createState() => _ContractEditScreenState();
}

class _ContractEditScreenState extends State<ContractEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late Contract _c;
  late final TextEditingController _title;
  late final TextEditingController _partner;
  late final TextEditingController _notice;
  late final TextEditingController _rate;
  late final TextEditingController _indexation;
  late final TextEditingController _comment;
  final List<String> _newPages = [];

  /// Aufgelöste Seitendateien für die Miniaturen (relativer Pfad → Datei).
  final Map<String, File> _pageFiles = {};
  String? _original;
  bool _saving = false;
  bool _scanning = false;
  List<Receipt> _linked = const [];

  @override
  void initState() {
    super.initState();
    _c =
        widget.contract ??
        Contract(
          type: ContractType.rent,
          title: '',
          startDate: DateTime.now(),
          vatPermille: AppScope.read(context).defaultVatPermille,
        );
    _title = TextEditingController(text: _c.title);
    _partner = TextEditingController(text: _c.partner);
    _notice = TextEditingController(text: _c.noticeValue?.toString() ?? '');
    _rate = TextEditingController(
      text: _c.rate.isZero ? '' : _amountText(_c.rate),
    );
    _indexation = TextEditingController(text: _c.indexation);
    _comment = TextEditingController(text: _c.comment);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.sharedFiles.isNotEmpty) await _addFiles(widget.sharedFiles);
      await _resolvePages();
      await _loadLinked();
    });
  }

  @override
  void dispose() {
    for (final c in [_title, _partner, _notice, _rate, _indexation, _comment]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _allPages => [..._c.pages, ..._newPages];

  /// Löst die Seitenpfade für die Vorschau auf (gespeicherte und neue).
  Future<void> _resolvePages() async {
    for (final rel in _allPages) {
      if (_pageFiles.containsKey(rel)) continue;
      final f = await ReceiptImageStore.resolve(rel);
      if (f != null && mounted) setState(() => _pageFiles[rel] = f);
    }
  }

  void _addPage(String rel) {
    setState(() => _newPages.add(rel));
    _resolvePages();
  }

  /// Antippen einer Miniatur: gespeicherte Seite gleich groß zeigen, neue
  /// Seite ansehen oder entfernen (wie beim Beleg, DESIGN_SPEC 5a).
  /// Gespeicherte Seiten bleiben (Aufbewahrung, nur Anhängen wie bei Belegen).
  Future<void> _pageTapped(int index) async {
    final pages = _allPages;
    final rel = pages[index];
    final isNew = index >= _c.pages.length;
    if (!isNew) return _showPage(index);
    final error = Theme.of(context).colorScheme.error;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.zoom_in),
              title: Text('Seite ${index + 1} ansehen'),
              onTap: () => Navigator.of(context).pop('show'),
            ),
            const Divider(height: 24),
            ListTile(
              key: const Key('contract-page-delete'),
              leading: Icon(Icons.delete_outline, color: error),
              title: Text('Seite entfernen', style: TextStyle(color: error)),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'show') _showPage(index);
    if (action == 'delete') {
      final ok = await confirmDestructive(
        context,
        title: 'Seite ${index + 1} entfernen?',
        message: 'Die noch nicht gespeicherte Seite wird entfernt.',
        verb: 'Entfernen',
      );
      if (!ok || !mounted) return;
      setState(() {
        _newPages.remove(rel);
        _pageFiles.remove(rel);
      });
      await ReceiptImageStore.delete(rel);
    }
  }

  void _showPage(int index) {
    final pages = _allPages;
    showPageImageDialog(
      context,
      files: [for (final p in pages) _pageFiles[p]],
      initialIndex: index,
    );
  }

  /// Gespeichertes Original (PDF) im Betrachter öffnen.
  Future<void> _openOriginal() async {
    final rel = _original ?? _c.originalPath;
    final file = await ReceiptImageStore.resolve(rel);
    if (!mounted) return;
    if (file == null) {
      showSnack(context, 'Originaldatei nicht gefunden.');
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final name = _title.text.trim().isEmpty ? 'Vertrag' : _title.text.trim();
    await openPdfViewer(
      context,
      title: name,
      fileName:
          '${name.replaceAll(RegExp(r'[^A-Za-z0-9ÄÖÜäöüß\-_]'), '_')}.pdf',
      bytes: bytes,
    );
  }

  Future<void> _loadLinked() async {
    final id = _c.id;
    if (id == null) return;
    final linked = await AppScope.read(
      context,
    ).repositories.contracts.linkedReceipts(id);
    if (mounted) setState(() => _linked = linked);
  }

  Contract _current() => _c.copyWith(
    title: _title.text.trim(),
    partner: _partner.text.trim(),
    noticeValue: int.tryParse(_notice.text.trim()),
    clearNotice: int.tryParse(_notice.text.trim()) == null,
    rate: Money.tryParse(_rate.text) ?? const Money.zero(),
    indexation: _indexation.text.trim(),
    comment: _comment.text.trim(),
    originalPath: _original ?? _c.originalPath,
  );

  Future<void> _addPhoto(ImageSource source) async {
    // Dokumentenscanner zuerst (FA-2.51), sonst automatisch die Kamera.
    if (source == ImageSource.camera) {
      final outcome = await ScanIntake.run(
        store: ReceiptImageStore.store,
        onPage: (rel) {
          if (!mounted) return false;
          _addPage(rel);
          return true;
        },
        afterPages: () async {},
        onError: (message) {
          if (mounted) showSnack(context, message);
        },
      );
      if (outcome != ScanIntakeOutcome.unavailable) return;
    }
    try {
      final picker = ImagePicker();
      final files = source == ImageSource.camera
          ? [
              ?await picker.pickImage(
                source: source,
                maxWidth: 2400,
                maxHeight: 2400,
                imageQuality: 85,
              ),
            ]
          : await picker.pickMultiImage(
              maxWidth: 2400,
              maxHeight: 2400,
              imageQuality: 85,
            );
      for (final f in files) {
        final rel = await ReceiptImageStore.store(File(f.path));
        if (!mounted) return;
        _addPage(rel);
      }
    } on Exception catch (e) {
      if (mounted) showSnack(context, 'Foto nicht übernommen: $e');
    }
  }

  /// Bilder als Seiten, PDF als Original mit Seitenbildern (wie Belege).
  Future<void> _addFiles(List<File> files) async {
    for (final file in files) {
      try {
        if (sharedKindOf(file.path) == SharedKind.image) {
          final rel = await ReceiptImageStore.store(file);
          if (mounted) _addPage(rel);
          continue;
        }
        final doc = await const DocumentImporter().import(file);
        _original = await ReceiptImageStore.store(file);
        for (final page in doc.pageImages) {
          final rel = await ReceiptImageStore.store(page);
          if (mounted) _addPage(rel);
        }
      } on Exception catch (e) {
        if (mounted) showSnack(context, 'Datei nicht übernommen: $e');
      }
    }
  }

  /// Texterkennung auf dem Gerät und Kurzübersicht (Pro, FA-16.3).
  Future<void> _scan() async {
    if (!await ensureFeature(context, Feature.contractSummary)) return;
    if (_allPages.isEmpty) {
      if (mounted) showSnack(context, 'Erst eine Seite fotografieren.');
      return;
    }
    setState(() => _scanning = true);
    try {
      const recognizer = PlatformReceiptTextRecognizer();
      if (!await recognizer.isAvailable()) {
        if (mounted) showSnack(context, 'Texterkennung hier nicht verfügbar.');
        return;
      }
      final outcome = await ContractOcr.run(
        pages: _allPages,
        resolve: ReceiptImageStore.resolve,
        recognizer: recognizer,
      );
      if (!mounted) return;
      // Leeres Ergebnis überschreibt keinen früher erkannten Text.
      if (outcome.hasText) {
        setState(() => _c = _c.copyWith(ocrText: outcome.text));
      }
      showSnack(context, outcome.message);
    } on Exception catch (e) {
      if (mounted) showSnack(context, 'Texterkennung fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _apply(ContractHint h) {
    setState(() {
      switch (h.field) {
        case ContractField.startDate:
          _c = _c.copyWith(startDate: h.date);
        case ContractField.endDate:
          _c = _c.copyWith(endDate: h.date);
        case ContractField.date:
          _c = _c.copyWith(endDate: h.date);
        case ContractField.duration:
          final start = _c.startDate;
          if (start != null && h.number != null) {
            final months = h.unit == 'years'
                ? h.number! * 12
                : h.unit == 'months'
                ? h.number!
                : 0;
            if (months > 0) {
              _c = _c.copyWith(
                endDate: DateTime(
                  start.year,
                  start.month + months,
                  start.day,
                ).subtract(const Duration(days: 1)),
              );
            }
          }
        case ContractField.notice:
          _notice.text = '${h.number}';
          _c = _c.copyWith(
            noticeUnit: switch (h.unit) {
              'days' => NoticeUnit.days,
              'weeks' => NoticeUnit.weeks,
              _ => NoticeUnit.months,
            },
          );
        case ContractField.rate:
          if (h.amount != null) _rate.text = _amountText(h.amount!);
        case ContractField.indexation:
          _indexation.text = h.excerpt;
      }
    });
    showSnack(context, 'Übernommen aus ${h.source}');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!await ensureFeature(context, Feature.newBookings)) return;
    if (!mounted) return;
    setState(() => _saving = true);
    final state = AppScope.read(context);
    final id = await state.repositories.contracts.save(
      _current(),
      newPages: _newPages,
    );
    await state.onBookingsChanged();
    await state.reload();
    if (!mounted) return;
    if (widget.contract == null) {
      Navigator.of(context).pop();
      return;
    }
    final fresh = await state.repositories.contracts.byId(id);
    if (!mounted) return;
    setState(() {
      _c = fresh ?? _c;
      _newPages.clear();
      _saving = false;
    });
    showSnack(context, 'Gespeichert');
  }

  Future<void> _book(DateTime due) async {
    if (!await ensureFeature(context, Feature.newBookings)) return;
    if (!mounted) return;
    final state = AppScope.read(context);
    final receipt = ContractSchedule.suggestedBooking(_current(), due);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rate buchen?'),
        content: Text(
          '${receipt.description}\n${Fmt.date(due)} · ${Fmt.money(receipt.gross)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Buchen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final rid = await state.repositories.receipts.save(receipt);
    await state.repositories.contracts.link(_c.id!, rid);
    await state.onBookingsChanged();
    await _loadLinked();
  }

  Future<void> _linkReceipt() async {
    final state = AppScope.read(context);
    final now = DateTime.now();
    final receipts = await state.repositories.receipts.query(
      from: DateTime(now.year - 2, now.month, now.day),
      to: now,
      direction: BookingDirection.expense,
      limit: 200,
    );
    final partner = _partner.text.trim().toLowerCase();
    receipts.sort((a, b) {
      final am =
          partner.isNotEmpty && a.counterparty.toLowerCase().contains(partner);
      final bm =
          partner.isNotEmpty && b.counterparty.toLowerCase().contains(partner);
      if (am != bm) return am ? -1 : 1;
      return b.date.compareTo(a.date);
    });
    if (!mounted) return;
    final picked = await showModalBottomSheet<Receipt>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (ctx, controller) => ListView(
          controller: controller,
          children: [
            const ListTile(title: Text('Beleg verknüpfen')),
            for (final r in receipts.take(60))
              ListTile(
                minVerticalPadding: 12,
                title: Text(
                  r.counterparty.isEmpty ? r.description : r.counterparty,
                ),
                subtitle: Text('${Fmt.date(r.date)} · ${r.description}'),
                trailing: Text(Fmt.money(r.gross)),
                onTap: () => Navigator.pop(ctx, r),
              ),
          ],
        ),
      ),
    );
    if (picked?.id == null) return;
    await state.repositories.contracts.link(_c.id!, picked!.id!);
    await _loadLinked();
  }

  Future<void> _delete() async {
    final state = AppScope.read(context);
    final years = state.profile?.taxProfile.retentionYears ?? 10;
    final last = _linked.isEmpty ? null : _linked.last.date;
    final until = ContractSchedule.retentionUntil(_c, last, years);
    final today = DateTime.now();
    final inRetention = until == null || !until.isBefore(today);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vertrag löschen?'),
        content: Text(
          inRetention
              ? (until == null
                    ? 'Der Vertrag läuft noch. Verträge, auf denen Buchungen '
                          'beruhen, musst du aufbewahren. Trotzdem löschen?'
                    : 'Aufbewahrungspflicht bis ${Fmt.date(until)}. '
                          'Trotzdem löschen?')
              : 'Die Aufbewahrungsfrist ist abgelaufen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Behalten'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await state.repositories.contracts.delete(_c.id!);
    for (final p in [..._c.pages, ?_c.originalPath]) {
      await ReceiptImageStore.delete(p);
    }
    await state.reload();
    if (mounted) Navigator.of(context).pop();
  }

  Future<DateTime?> _pickDate(DateTime? initial) => showDatePicker(
    context: context,
    initialDate: initial ?? DateTime.now(),
    firstDate: DateTime(1980),
    lastDate: DateTime(2100),
  );

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final current = _current();
    final hints = ContractTextExtractor.extract(_c.ocrText);
    final today = DateTime.now();
    final notice = ContractSchedule.noticeDeadline(current);
    final payments = _c.id == null
        ? const <ExpectedPayment>[]
        : ContractSchedule.match(current, _linked, today);
    final nextDue = _c.id == null
        ? null
        : ContractSchedule.nextDue(current, today);
    final retention = ContractSchedule.retentionUntil(
      current,
      _linked.isEmpty ? null : _linked.last.date,
      state.profile?.taxProfile.retentionYears ?? 10,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contract == null ? 'Vertrag ablegen' : 'Vertrag'),
        actions: const [HelpButton()],
      ),
      bottomNavigationBar: PrimaryActionBar(
        primary: PrimaryActionBar.filled(
          key: const Key('contract-save'),
          label: 'Speichern',
          icon: Icons.check,
          busy: _saving,
          onPressed: _save,
        ),
      ),
      body: ReadableWidth(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              SectionCard(
                title: 'Seiten (${_allPages.length})',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_allPages.isNotEmpty) ...[
                      SizedBox(
                        height: 104,
                        child: ListView.separated(
                          key: const Key('contract-pages'),
                          scrollDirection: Axis.horizontal,
                          itemCount: _allPages.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, i) => _PageThumb(
                            index: i,
                            file: _pageFiles[_allPages[i]],
                            isNew: i >= _c.pages.length,
                            onTap: () => _pageTapped(i),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_c.originalPath != null || _original != null) ...[
                      OutlinedButton.icon(
                        key: const Key('contract-original'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: _openOriginal,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Original-PDF öffnen'),
                      ),
                      const SizedBox(height: 8),
                    ],
                    // Zwei gleich breite Knöpfe, darunter der dritte über die
                    // volle Breite: bündig an beiden Rändern.
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('contract-photo'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                            ),
                            onPressed: () => _addPhoto(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('Scannen'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                            ),
                            onPressed: () => _addPhoto(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Galerie'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('contract-scan'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: _scanning ? null : _scan,
                      icon: const Icon(Icons.text_snippet_outlined),
                      label: Text(
                        proLabel(
                          context,
                          Feature.contractSummary,
                          _c.ocrText.isEmpty
                              ? 'Text erkennen und Kurzübersicht'
                              : 'Text neu erkennen',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (hints.isNotEmpty) ...[
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Kurzübersicht aus dem Text',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nur Fundstellen aus deinem Vertrag, keine '
                        'rechtliche Prüfung. Tippen übernimmt den Wert.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      for (final h in hints.take(20))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          minVerticalPadding: 12,
                          title: Text('${_hintLabel(h.field)}: ${h.value}'),
                          subtitle: Text('${h.source} · „${h.excerpt}“'),
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () => _apply(h),
                        ),
                    ],
                  ),
                ),
              ],
              if (_c.ocrText.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  child: ExpansionTile(
                    key: const Key('contract-ocr-text'),
                    title: Text(
                      'Erkannter Text '
                      '(${'\n'.allMatches(_c.ocrText).length + 1} Zeilen)',
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      SelectableText(
                        _c.ocrText.replaceAll(
                          RegExp(r'^\[S\.\d+\] ', multiLine: true),
                          '',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SectionCard(
                title: 'Vertrag',
                child: Column(
                  // 12 dp zwischen allen Feldern: die schwebenden Beschriftungen
                  // überlappten sonst das Feld darüber (Gerätetest 2026-10-21).
                  spacing: 12,
                  children: [
                    DropdownButtonFormField<ContractType>(
                      isExpanded: true,
                      initialValue: _c.type,
                      decoration: const InputDecoration(labelText: 'Art'),
                      items: [
                        for (final t in ContractType.values)
                          DropdownMenuItem(value: t, child: Text(t.label)),
                      ],
                      onChanged: (v) =>
                          setState(() => _c = _c.copyWith(type: v)),
                    ),
                    if (_c.type.hasEmployeeData)
                      const NoticeBanner(
                        key: Key('contract-employee-hint'),
                        icon: Icons.shield_outlined,
                        message: employeeContractHint,
                      ),
                    TextFormField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: 'Bezeichnung',
                        hintText: 'z. B. Büromiete Hauptstraße',
                      ),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Bitte eine Bezeichnung eingeben'
                          : null,
                    ),
                    TextFormField(
                      controller: _partner,
                      decoration: const InputDecoration(
                        labelText: 'Vertragspartner',
                      ),
                    ),
                    _DateTile(
                      label: 'Beginn',
                      date: _c.startDate,
                      onTap: () async {
                        final d = await _pickDate(_c.startDate);
                        if (d != null) {
                          setState(() => _c = _c.copyWith(startDate: d));
                        }
                      },
                    ),
                    _DateTile(
                      label: 'Ende (leer = unbefristet)',
                      date: _c.endDate,
                      onTap: () async {
                        final d = await _pickDate(_c.endDate ?? _c.startDate);
                        if (d != null) {
                          setState(() => _c = _c.copyWith(endDate: d));
                        }
                      },
                      onClear: _c.endDate == null
                          ? null
                          : () => setState(
                              () => _c = _c.copyWith(clearEnd: true),
                            ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _notice,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Kündigungsfrist',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<NoticeUnit>(
                            initialValue: _c.noticeUnit,
                            isExpanded: true,
                            items: [
                              for (final u in NoticeUnit.values)
                                DropdownMenuItem(
                                  value: u,
                                  child: Text(u.label),
                                ),
                            ],
                            onChanged: (v) =>
                                setState(() => _c = _c.copyWith(noticeUnit: v)),
                          ),
                        ),
                      ],
                    ),
                    if (notice != null)
                      LabeledValue(
                        label: 'Kündigen bis',
                        value: Fmt.date(notice),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Zahlung',
                child: Column(
                  spacing: 12,
                  children: [
                    MoneyField(
                      controller: _rate,
                      label: 'Rate brutto',
                      onChanged: (_) => setState(() {}),
                    ),
                    DropdownButtonFormField<PaymentRhythm>(
                      isExpanded: true,
                      initialValue: _c.rhythm,
                      decoration: const InputDecoration(labelText: 'Rhythmus'),
                      items: [
                        for (final r in PaymentRhythm.values)
                          DropdownMenuItem(value: r, child: Text(r.label)),
                      ],
                      onChanged: (v) =>
                          setState(() => _c = _c.copyWith(rhythm: v)),
                    ),
                    TextFormField(
                      controller: _indexation,
                      decoration: const InputDecoration(
                        labelText: 'Wertsicherung / Indexierung (optional)',
                        hintText: 'z. B. VPI 2020, jährlich im Jänner',
                      ),
                    ),
                    _DateTile(
                      label: 'Nächste Indexanpassung',
                      date: _c.nextIndexDate,
                      onTap: () async {
                        final d = await _pickDate(_c.nextIndexDate);
                        if (d != null) {
                          setState(() => _c = _c.copyWith(nextIndexDate: d));
                        }
                      },
                      onClear: _c.nextIndexDate == null
                          ? null
                          : () => setState(
                              () => _c = _c.copyWith(clearIndexDate: true),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Kommentar',
                child: TextFormField(
                  controller: _comment,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Tippen oder diktieren',
                    suffixIcon: DictationButton(controller: _comment),
                    suffixIconConstraints: const BoxConstraints(),
                  ),
                ),
              ),
              if (_c.id != null) ...[
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Zahlungen und Belege',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final p in payments.reversed)
                        LabeledValue(
                          label: Fmt.date(p.due),
                          value: switch (p.status) {
                            PaymentStatus.paid => 'gebucht ✓',
                            PaymentStatus.differs =>
                              'gebucht ${Fmt.money(p.receipt!.gross)} ≠ Rate',
                            PaymentStatus.missing => 'kein Beleg',
                          },
                        ),
                      if (nextDue != null && !current.rate.isZero)
                        OutlinedButton.icon(
                          key: const Key('contract-book'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                          onPressed: () => _book(nextDue),
                          icon: const Icon(Icons.playlist_add),
                          label: Text(
                            'Rate ${Fmt.date(nextDue)} buchen (Vorschlag)',
                          ),
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: _linkReceipt,
                        icon: const Icon(Icons.link),
                        label: Text('Beleg verknüpfen (${_linked.length})'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                NoticeBanner(
                  icon: Icons.inventory_outlined,
                  message: retention == null
                      ? 'Aufbewahren: solange der Vertrag läuft, danach '
                            '${state.profile?.taxProfile.retentionYears ?? 10} '
                            'Jahre.'
                      : 'Aufbewahren bis ${Fmt.date(retention)}.',
                ),
                DangerZone(
                  buttonKey: const Key('contract-delete'),
                  label: 'Vertrag löschen',
                  icon: Icons.delete_outline,
                  explanation:
                      'Vor Ablauf der Aufbewahrungsfrist nur mit Warnung.',
                  onPressed: _delete,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _hintLabel(ContractField f) => switch (f) {
    ContractField.startDate => 'Beginn',
    ContractField.endDate => 'Ende',
    ContractField.date => 'Datum',
    ContractField.duration => 'Laufzeit',
    ContractField.notice => 'Kündigungsfrist',
    ContractField.rate => 'Betrag',
    ContractField.indexation => 'Wertsicherung',
  };
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.date,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    minVerticalPadding: 12,
    title: Text(label),
    subtitle: Text(date == null ? '–' : Fmt.date(date!)),
    trailing: onClear == null
        ? const Icon(Icons.calendar_today_outlined)
        : IconButton(
            tooltip: 'Leeren',
            icon: const Icon(Icons.clear),
            onPressed: onClear,
          ),
    onTap: onTap,
  );
}

/// Miniatur einer Vertragsseite, 72 × 104 dp (Touchfläche ≥ 48 dp).
class _PageThumb extends StatelessWidget {
  const _PageThumb({
    required this.index,
    required this.file,
    required this.isNew,
    required this.onTap,
  });

  final int index;
  final File? file;
  final bool isNew;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Seite ${index + 1} ansehen',
      child: InkWell(
        key: Key('contract-page-$index'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 72,
          decoration: BoxDecoration(
            border: Border.all(
              color: isNew ? scheme.primary : scheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (file != null)
                Image.file(
                  file!,
                  fit: BoxFit.cover,
                  cacheWidth: 216,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined),
                )
              else
                const Icon(Icons.description_outlined),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  color: scheme.surface.withValues(alpha: 0.85),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${index + 1}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
