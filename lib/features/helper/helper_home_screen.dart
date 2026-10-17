import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../data/helper_repository.dart';
import '../../services/backup/platform_backup_target.dart';
import '../../services/helper/helper_exchange.dart';
import '../../services/helper/helper_package.dart';
import '../../widgets/capture_button.dart';
import '../../widgets/common.dart';
import 'helper_capture.dart';
import 'helper_capture_screen.dart';

/// Startbildschirm des Mithelfer-Geräts (FA-17.2, FA-17.3): großer
/// Aufnahmeknopf unten mittig, darüber die gesendeten Belege mit Status.
/// Keine Buchungen, Rechnungen oder Berichte.
class HelperHomeScreen extends StatefulWidget {
  const HelperHomeScreen({super.key});

  @override
  State<HelperHomeScreen> createState() => _HelperHomeScreenState();
}

class _HelperHomeScreenState extends State<HelperHomeScreen> {
  List<OutboxEntry> _sent = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final state = AppScope.read(context);
    final link = state.helperLink;
    final repo = state.repositories.helpers;
    if (link?.folder != null) {
      try {
        await HelperOutbox(repo).refresh(PlatformBackupTarget(link!.folder!));
      } on Object {
        // Ordner nicht erreichbar: Status bleibt „gesendet“.
      }
    }
    final sent = await repo.outbox();
    if (mounted) setState(() => _sent = sent);
  }

  Future<void> _capture(HelperSource source) async {
    try {
      final pages = await captureHelperPages(source);
      if (pages.isEmpty || !mounted) return;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => HelperCaptureScreen(pages: pages)),
      );
      await _load();
    } on Exception catch (e) {
      if (mounted) showSnack(context, 'Aufnahme fehlgeschlagen: $e');
    }
  }

  Future<void> _menu(String action) async {
    final state = AppScope.read(context);
    final link = state.helperLink!;
    if (action == 'folder') {
      final picked = await PlatformBackupTarget.pick();
      if (picked == null) return;
      await state.setHelperLink(link.withFolder(picked.folder, picked.label));
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kopplung aufheben?'),
        content: const Text(
          'Danach kann dieses Handy keine Belege mehr senden. Bereits '
          'gesendete Belege bleiben beim Betrieb.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Aufheben'),
          ),
        ],
      ),
    );
    if (yes == true) await state.setHelperLink(null);
  }

  @override
  Widget build(BuildContext context) {
    final link = AppScope.of(context).helperLink!;
    return Scaffold(
      appBar: AppBar(
        title: Text('Belege für ${link.businessName}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: _menu,
            itemBuilder: (_) => [
              if (link.transport == HelperTransport.folder)
                const PopupMenuItem(
                  value: 'folder',
                  child: Text('Gemeinsamen Ordner wählen'),
                ),
              const PopupMenuItem(
                value: 'unlink',
                child: Text('Kopplung aufheben'),
              ),
            ],
          ),
        ],
      ),
      body: _sent.isEmpty
          ? EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Beleg fotografieren',
              message:
                  'Tippe unten auf „Beleg“. Du bestätigst kurz Betrag, '
                  'Lieferant und Datum, dann geht der Beleg '
                  '${link.transport == HelperTransport.folder ? 'in den gemeinsamen Ordner' : 'per Messenger oder Mail'} '
                  'an ${link.businessName}.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
                children: [
                  for (final e in _sent)
                    ListTile(
                      minTileHeight: 56,
                      leading: Icon(
                        e.status == OutboxStatus.accepted
                            ? Icons.done_all
                            : Icons.done,
                      ),
                      title: Text(e.summary),
                      subtitle: Text(
                        '${Fmt.date(e.createdAt)} · '
                        '${e.status == OutboxStatus.accepted ? 'übernommen' : 'gesendet'}',
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: CaptureBar(
        cameraKey: const Key('helper-camera'),
        keyPrefix: 'helper',
        onCamera: () => _capture(HelperSource.camera),
        onPhoto: () => _capture(HelperSource.gallery),
        onFile: () => _capture(HelperSource.file),
      ),
    );
  }
}
