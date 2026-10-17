import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../data/helper_repository.dart';
import '../../services/backup/platform_backup_target.dart';
import '../../services/helper/helper_exchange.dart';
import '../../services/helper/helper_mail.dart';
import '../../services/helper/helper_mail_platform.dart';
import '../../services/helper/helper_mail_schedule.dart';
import '../../services/helper/helper_package.dart';
import '../../services/mail/mail_server.dart';
import '../../services/share_service.dart';
import '../../widgets/capture_button.dart';
import '../../widgets/common.dart';
import 'helper_capture.dart';
import 'helper_capture_screen.dart';
import 'helper_mail_setup_screen.dart';

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
  bool _smtp = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    LocalHelperNotifier.instance.sendRequested.addListener(_onNotification);
  }

  @override
  void dispose() {
    LocalHelperNotifier.instance.sendRequested.removeListener(_onNotification);
    super.dispose();
  }

  /// Mitteilung „Belege senden“ angetippt: Mailfenster öffnen.
  void _onNotification() {
    if (!LocalHelperNotifier.instance.sendRequested.value) return;
    LocalHelperNotifier.instance.sendRequested.value = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendNow());
  }

  bool _needsMailSetup(HelperLink link) =>
      link.transport == HelperTransport.mail && !_smtp;

  int get _pending =>
      _sent.where((e) => e.status == OutboxStatus.queued).length;

  /// „Jetzt senden“: eigenes Postfach, sonst Mail-App mit Anhang.
  Future<void> _sendNow() async {
    if (_sending || !mounted) return;
    final state = AppScope.read(context);
    final link = state.helperLink;
    if (link == null) return;
    setState(() => _sending = true);
    try {
      final outbox = (await state.mailSync()).outbox;
      final int n;
      if (await outbox.smtpConfigured()) {
        n = await outbox.sendPending(link);
      } else {
        n = await outbox.handOver(
          link,
          (b, text) => MailComposer.compose(
            to: link.receivingAddress ?? '',
            subject: b.subject,
            text: text,
            fileName: b.fileName,
            bytes: b.bytes,
          ),
        );
      }
      if (mounted && n > 0) {
        showSnack(context, n == 1 ? 'Beleg gesendet.' : '$n Belege gesendet.');
      }
    } on MailException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
      await _load();
    }
  }

  Future<void> _setupMail() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const HelperMailSetupScreen()),
    );
    await _load();
  }

  /// Notweg: alle noch gespeicherten Belege als eine Datei teilen.
  Future<void> _export() async {
    final state = AppScope.read(context);
    final link = state.helperLink!;
    final b = await (await state.mailSync()).outbox.export(link);
    if (!mounted) return;
    if (b == null) {
      showSnack(context, 'Keine gespeicherten Belege zum Exportieren.');
      return;
    }
    await ShareService.shareHelperPackage(
      fileName: b.fileName,
      bytes: b.bytes,
      businessName: link.businessName,
    );
  }

  Future<void> _retention() async {
    final state = AppScope.read(context);
    final repo = state.repositories.helpers;
    final current =
        int.tryParse(await repo.setting(MailSettingKeys.retentionDays) ?? '') ??
        HelperMailSchedule.defaultRetentionDays;
    if (!mounted) return;
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Gesendete Belege aufbewahren'),
              subtitle: Text(
                'Verschlüsselt auf diesem Handy, danach gelöscht. Noch nicht '
                'gesendete Belege bleiben immer.',
              ),
            ),
            for (final d in HelperMailSchedule.retentionChoices)
              ListTile(
                key: Key('retention-$d'),
                minTileHeight: 56,
                leading: Icon(
                  d == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text('$d Tage'),
                onTap: () => Navigator.of(context).pop(d),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await repo.setSetting(MailSettingKeys.retentionDays, '$picked');
    await (await state.mailSync()).outbox.prune(days: picked);
    await _load();
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
    var smtp = false;
    if (link?.transport == HelperTransport.mail) {
      try {
        smtp = await (await state.mailSync()).outbox.smtpConfigured();
      } on Object {
        smtp = false;
      }
    }
    if (mounted) {
      setState(() {
        _sent = sent;
        _smtp = smtp;
      });
    }
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
    switch (action) {
      case 'mail':
        await _setupMail();
        return;
      case 'export':
        await _export();
        return;
      case 'retention':
        await _retention();
        return;
    }
    if (action == 'folder') {
      final picked = await PlatformBackupTarget.pick();
      if (picked == null) return;
      await state.setHelperLink(link.withFolder(picked.folder, picked.label));
      if (mounted) showSnack(context, helperFolderHint);
      return;
    }
    if (!mounted) return;
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
              if (link.transport == HelperTransport.mail) ...[
                const PopupMenuItem(value: 'mail', child: Text('E-Mail-Konto')),
                const PopupMenuItem(
                  value: 'retention',
                  child: Text('Aufbewahrung'),
                ),
              ],
              const PopupMenuItem(value: 'export', child: Text('Exportieren')),
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
      body: _sent.isEmpty && !_needsMailSetup(link)
          ? EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Beleg fotografieren',
              message:
                  'Tippe unten auf „Beleg“. Du bestätigst kurz Betrag, '
                  'Lieferant und Datum, dann geht der Beleg '
                  '${switch (link.transport) {
                    HelperTransport.folder => 'in den gemeinsamen Ordner',
                    HelperTransport.mail => 'per E-Mail',
                    HelperTransport.share => 'per Messenger oder Mail',
                  }} '
                  'an ${link.businessName}.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
                children: [
                  if (_needsMailSetup(link))
                    _Banner(
                      key: const Key('helper-mail-setup'),
                      icon: Icons.mail_outline,
                      text:
                          'Einmal einrichten, dann gehen deine Belege von '
                          'selbst an ${link.businessName}.',
                      label: 'Mit deinem E-Mail-Konto senden',
                      onPressed: _setupMail,
                    ),
                  if (_pending > 0)
                    _Banner(
                      key: const Key('helper-send-now'),
                      icon: Icons.schedule_send_outlined,
                      text: _pending == 1
                          ? 'Ein Beleg wartet auf den Versand.'
                          : '$_pending Belege warten auf den Versand.',
                      label: _smtp ? 'Jetzt senden' : 'Per Mail-App senden',
                      busy: _sending,
                      onPressed: _sendNow,
                    ),
                  for (final e in _sent)
                    ListTile(
                      minTileHeight: 56,
                      leading: Icon(switch (e.status) {
                        OutboxStatus.accepted => Icons.done_all,
                        OutboxStatus.sent => Icons.done,
                        OutboxStatus.queued => Icons.schedule,
                      }),
                      title: Text(e.summary),
                      subtitle: Text(
                        '${Fmt.date(e.createdAt)} · ${e.status.label}',
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

/// Hinweis mit Knopf (volle Breite, 48 dp) über der Liste.
class _Banner extends StatelessWidget {
  const _Banner({
    super.key,
    required this.icon,
    required this.text,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final IconData icon;
  final String text;
  final String label;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(child: Text(text)),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: busy ? null : onPressed,
            child: Text(label),
          ),
        ],
      ),
    ),
  );
}
