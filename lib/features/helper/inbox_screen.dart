import 'dart:io';

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../data/helper_repository.dart';
import '../../domain/money.dart';
import '../../domain/receipt.dart';
import '../../services/backup/platform_backup_target.dart';
import '../../widgets/common.dart';
import '../../widgets/primary_action_bar.dart';
import '../receipts/receipt_edit_screen.dart';

/// Eingang des Hauptgeräts (FA-17.5): Belege der Mithelfer. Antippen öffnet
/// das normale Belegformular, vorbelegt und „von ‹Gerät›“ markiert;
/// „Beleg speichern“ übernimmt ihn.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  List<InboxEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = AppScope.read(context);
    await state.syncHelperInbox();
    final entries = await state.repositories.helpers.inbox();
    if (mounted) setState(() => _entries = entries);
  }

  Future<void> _open(InboxEntry e) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReceiptEditScreen(
          direction: BookingDirection.expense,
          helperEntry: e,
        ),
      ),
    );
    if (saved != true || !mounted) return;
    await _close(e, InboxStatus.accepted);
    if (mounted) showSnack(context, 'Beleg von ${e.deviceName} übernommen.');
  }

  Future<void> _close(
    InboxEntry e,
    InboxStatus status, {
    String reason = '',
  }) async {
    final state = AppScope.read(context);
    await (await state.helperInbox()).close(
      e,
      status,
      reason: reason,
      folder: await state.inboxFolder(),
    );
    await state.refreshInboxCount();
    await _load();
  }

  Future<void> _reject(InboxEntry e) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Beleg ablehnen'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Grund',
            hintText: 'z. B. privat, doppelt, unleserlich',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Ablehnen'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;
    await _close(e, InboxStatus.rejected, reason: reason);
  }

  Future<void> _openFile() async {
    final bytes = await PlatformBackupTarget.pickFile();
    if (bytes == null || !mounted) return;
    final result = await (await AppScope.read(
      context,
    ).helperInbox()).importBytes(bytes);
    if (!mounted) return;
    showSnack(context, result.message);
    await AppScope.read(context).refreshInboxCount();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eingang')),
      body: _entries.isEmpty
          ? const EmptyState(
              icon: Icons.move_to_inbox_outlined,
              title: 'Keine Belege im Eingang',
              message:
                  'Belege von Mithelfer-Geräten erscheinen hier – aus dem '
                  'gemeinsamen Ordner automatisch, aus Messenger oder Mail '
                  'über „Teilen“ an JeNi bucht oder „Belegpaket öffnen“.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                for (final e in _entries)
                  Card(
                    child: ListTile(
                      key: Key('inbox-${e.uuid}'),
                      minTileHeight: 64,
                      leading: e.pagePaths.isEmpty
                          ? const Icon(Icons.receipt_long_outlined)
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.file(
                                File(e.pagePaths.first),
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.receipt_long_outlined),
                              ),
                            ),
                      title: Text(
                        [
                          if (e.receipt.grossCents != null)
                            Fmt.money(Money(e.receipt.grossCents!)),
                          if (e.receipt.counterparty.isNotEmpty)
                            e.receipt.counterparty,
                        ].join(' · ').ifEmpty('Beleg'),
                      ),
                      subtitle: Text(
                        'von ${e.deviceName} · '
                        '${Fmt.date(e.receipt.date ?? e.receivedAt)}',
                      ),
                      onTap: () => _open(e),
                      trailing: IconButton(
                        tooltip: 'Ablehnen',
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        icon: const Icon(Icons.block),
                        onPressed: () => _reject(e),
                      ),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: PrimaryActionBar(
        primary: PrimaryActionBar.outlined(
          key: const Key('inbox-open-file'),
          label: 'Belegpaket öffnen',
          icon: Icons.file_open_outlined,
          onPressed: _openFile,
        ),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
