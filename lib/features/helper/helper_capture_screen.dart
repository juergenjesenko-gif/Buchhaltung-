import 'dart:io';

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../data/app_database.dart';
import '../../domain/country.dart';
import '../../domain/money.dart';
import '../../services/backup/platform_backup_target.dart';
import '../../services/helper/helper_exchange.dart';
import '../../services/helper/helper_package.dart';
import '../../services/receipt_scan/platform_text_recognizer.dart';
import '../../services/receipt_scan/receipt_classifier.dart';
import '../../services/receipt_scan/receipt_text_parser.dart';
import '../../services/share_service.dart';
import '../../widgets/common.dart';
import '../../widgets/dictation_button.dart';
import '../../widgets/primary_action_bar.dart';

/// Kurz bestätigen und senden (FA-17.3): Betrag, Lieferant, Datum,
/// Kategorie als Vorschläge aus der Texterkennung, Kommentar optional.
class HelperCaptureScreen extends StatefulWidget {
  const HelperCaptureScreen({super.key, required this.pages});

  final List<File> pages;

  /// Kategorien, die der Mithelfer vorschlagen kann: die Startkategorien
  /// für Ausgaben (die Bücher des Betriebs sieht er nicht).
  static final categoryNames = [
    for (final (name, direction, _) in AppDatabase.seedCategories)
      if (direction == 'expense') name,
  ];

  @override
  State<HelperCaptureScreen> createState() => _HelperCaptureScreenState();
}

class _HelperCaptureScreenState extends State<HelperCaptureScreen> {
  final _gross = TextEditingController();
  final _supplier = TextEditingController();
  final _description = TextEditingController();
  final _comment = TextEditingController();
  DateTime _date = DateTime.now();
  String? _category;
  bool _busy = false;
  bool _reading = true;

  @override
  void initState() {
    super.initState();
    _recognize();
  }

  @override
  void dispose() {
    _gross.dispose();
    _supplier.dispose();
    _description.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _recognize() async {
    try {
      const recognizer = PlatformReceiptTextRecognizer();
      if (!await recognizer.isAvailable()) return;
      final doc = await recognizer.recognize([
        for (final p in widget.pages) p.path,
      ]);
      final r = ReceiptTextParser(
        TaxProfile.austria,
        now: DateTime.now(),
      ).parse(doc);
      final c = ReceiptClassifier.classify(doc.rows, r);
      if (!mounted) return;
      setState(() {
        if ((r.gross?.confidence ?? 0) >= 40 && r.currency.value == 'EUR') {
          _gross.text = Fmt.amount(r.gross!.value);
        }
        if ((r.merchant?.confidence ?? 0) >= 40) {
          _supplier.text = r.merchant!.value;
        }
        if ((r.date?.confidence ?? 0) >= 40) _date = r.date!.value;
        if (c.description != null) _description.text = c.description!;
        if (HelperCaptureScreen.categoryNames.contains(c.categoryName)) {
          _category = c.categoryName;
        }
      });
    } on Object {
      // Ohne Erkennung tippt die Nutzerin selbst.
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _send() async {
    final state = AppScope.read(context);
    final link = state.helperLink!;
    setState(() => _busy = true);
    try {
      final gross = Money.tryParse(_gross.text);
      final receipt = HelperReceipt(
        uuid: HelperPackage.newUuid(),
        deviceName: link.deviceName,
        createdAt: DateTime.now(),
        date: _date,
        grossCents: gross?.cents,
        counterparty: _supplier.text.trim(),
        categoryName: _category,
        description: _description.text.trim(),
        comment: _comment.text.trim(),
        pages: [for (final p in widget.pages) await p.readAsBytes()],
      );
      final summary = [
        if (gross != null) Fmt.money(gross),
        if (receipt.counterparty.isNotEmpty) receipt.counterparty,
      ].join(' · ');
      await HelperOutbox(state.repositories.helpers).send(
        link: link,
        receipt: receipt,
        summary: summary.isEmpty ? 'Beleg' : summary,
        folder: link.folder == null ? null : PlatformBackupTarget(link.folder!),
        share: (name, bytes) => ShareService.shareHelperPackage(
          fileName: name,
          bytes: bytes,
          businessName: link.businessName,
        ),
        deleteAfter: widget.pages,
      );
      if (!mounted) return;
      showSnack(context, 'Beleg gesendet.');
      Navigator.of(context).pop(true);
    } on HelperSendException catch (e) {
      if (mounted) showSnack(context, e.message);
    } on Exception catch (e) {
      if (mounted) showSnack(context, 'Senden fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Beleg senden')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          if (_reading) const LinearProgressIndicator(),
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final p in widget.pages)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Image.file(p, height: 120, fit: BoxFit.cover),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          MoneyField(controller: _gross, label: 'Betrag (brutto)'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('helper-supplier'),
            controller: _supplier,
            decoration: const InputDecoration(labelText: 'Lieferant'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            minTileHeight: 56,
            leading: const Icon(Icons.event),
            title: const Text('Datum'),
            subtitle: Text(Fmt.date(_date)),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          DropdownButtonFormField<String>(
            key: const Key('helper-category'),
            initialValue: _category,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Kategorie (Vorschlag)',
            ),
            items: [
              for (final n in HelperCaptureScreen.categoryNames)
                DropdownMenuItem(value: n, child: Text(n)),
            ],
            onChanged: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            decoration: const InputDecoration(
              labelText: 'Was wurde gekauft? (optional)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('helper-comment'),
            controller: _comment,
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(
              labelText: 'Kommentar (optional)',
              suffixIcon: DictationButton(controller: _comment),
            ),
          ),
        ],
      ),
      bottomNavigationBar: PrimaryActionBar(
        primary: PrimaryActionBar.filled(
          key: const Key('helper-send'),
          label: 'Senden',
          icon: Icons.send,
          busy: _busy,
          onPressed: _send,
        ),
      ),
    );
  }
}
