import 'package:flutter/material.dart';
import 'helper_help_sheet.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../data/helper_repository.dart';
import '../../services/backup/platform_backup_target.dart';
import '../../services/helper/helper_package.dart';
import '../../services/licensing/license_policy.dart';
import '../../widgets/common.dart';
import '../../widgets/primary_action_bar.dart';
import '../licensing/feature_gate.dart';
import 'inbox_screen.dart';
import 'mail_receive_screen.dart';
import 'qr_view.dart';

/// Einstellungen → Mithelfer-Geräte (FA-17.1, FA-17.5, FA-17.7) auf dem
/// Hauptgerät: Eingang, gemeinsamer Ordner, gekoppelte Geräte.
class HelperDevicesScreen extends StatefulWidget {
  const HelperDevicesScreen({super.key});

  @override
  State<HelperDevicesScreen> createState() => _HelperDevicesScreenState();
}

class _HelperDevicesScreenState extends State<HelperDevicesScreen> {
  List<HelperPairing> _pairings = const [];
  String? _folderLabel;
  String? _mailAddress;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = AppScope.read(context).repositories.helpers;
    final pairings = await repo.pairings();
    final label = await repo.setting('inbox_folder_label');
    if (!mounted) return;
    final address = await AppScope.read(context).receivingAddress();
    if (!mounted) return;
    setState(() {
      _pairings = [
        for (final p in pairings)
          if (!p.isRevoked) p,
      ];
      _folderLabel = label;
      _mailAddress = address;
    });
  }

  Future<void> _add() async {
    if (!await ensureFeature(context, Feature.helperDevices)) return;
    if (!mounted) return;
    final input = await showModalBottomSheet<(String, HelperTransport)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddDeviceSheet(),
    );
    if (input == null || !mounted) return;
    final state = AppScope.read(context);
    var address = await state.receivingAddress();
    if (!mounted) return;
    if (input.$2 == HelperTransport.mail && address == null) {
      // Ohne Empfangsadresse kein Mailweg: erst einrichten, dann weiter.
      showSnack(context, 'Bitte zuerst die Empfangsadresse festlegen.');
      await _openMail();
      if (!mounted) return;
      address = await state.receivingAddress();
      if (address == null || !mounted) return;
    }
    final code = await (await state.helperInbox()).createPairing(
      deviceName: input.$1,
      businessName: state.profile?.companyName ?? '',
      transport: input.$2,
      receivingAddress: address,
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PairingQrScreen(code: code)),
    );
    await _load();
  }

  Future<void> _revoke(HelperPairing p) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${p.deviceName} trennen?'),
        content: const Text(
          'Belege, die dieses Gerät danach sendet, werden abgelehnt. Was '
          'schon im Eingang liegt, bleibt. Zum Weitermachen neu koppeln – '
          'dabei entsteht ein neuer Schlüssel.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Trennen'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await (await AppScope.read(context).helperInbox()).revoke(p.id);
    await _load();
  }

  Future<void> _openMail() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MailReceiveScreen()));
    await _load();
  }

  Future<void> _pickFolder() async {
    final picked = await PlatformBackupTarget.pick();
    if (picked == null || !mounted) return;
    final state = AppScope.read(context);
    await state.repositories.helpers.setSetting('inbox_folder', picked.folder);
    await state.repositories.helpers.setSetting(
      'inbox_folder_label',
      picked.label,
    );
    await state.syncHelperInbox();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mithelfer-Geräte'),
        actions: const [HelperHelpButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          SectionCard(
            child: Column(
              children: [
                ListTile(
                  key: const Key('helper-inbox'),
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: 56,
                  leading: const Icon(Icons.move_to_inbox_outlined),
                  title: const Text('Eingang'),
                  subtitle: Text(
                    state.inboxCount == 0
                        ? 'Keine offenen Belege'
                        : '${state.inboxCount} Belege warten',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const InboxScreen(),
                    ),
                  ),
                ),
                ListTile(
                  key: const Key('helper-mail'),
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: 56,
                  leading: const Icon(Icons.mail_outline),
                  title: const Text('Empfang per E-Mail'),
                  subtitle: Text(
                    _mailAddress ??
                        'Noch keine Adresse – Standardweg für Mithelfer',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openMail,
                ),
                ListTile(
                  key: const Key('helper-folder'),
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: 56,
                  leading: const Icon(Icons.folder_shared_outlined),
                  title: const Text('Gemeinsamer Ordner „Eingang“ (optional)'),
                  subtitle: Text(
                    '${_folderLabel ?? 'Nicht gewählt – nur nötig, wenn Geräte '
                            'über einen Cloud-Ordner senden'}\n$helperFolderHint',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickFolder,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Gekoppelte Geräte',
            child: _pairings.isEmpty
                ? const Text(
                    'Noch kein Gerät. Mit „Gerät hinzufügen“ zeigt die App '
                    'einen QR-Code, den das andere Handy fotografiert.',
                  )
                : Column(
                    children: [
                      for (final p in _pairings)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          minTileHeight: 56,
                          leading: const Icon(Icons.smartphone),
                          title: Text(p.deviceName),
                          subtitle: Text(
                            '${p.transport.label} · seit '
                            '${Fmt.date(p.createdAt)}',
                          ),
                          trailing: TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed: () => _revoke(p),
                            child: const Text('Trennen'),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Du bleibst verantwortlich für deine Buchhaltung: Mithelfer '
            'senden nur Vorschläge, gebucht wird erst hier mit '
            '„Übernehmen“.',
          ),
        ],
      ),
      bottomNavigationBar: PrimaryActionBar(
        primary: PrimaryActionBar.filled(
          key: const Key('helper-add'),
          label: 'Gerät hinzufügen',
          icon: Icons.qr_code_2,
          onPressed: _add,
        ),
      ),
    );
  }
}

class _AddDeviceSheet extends StatefulWidget {
  const _AddDeviceSheet();

  @override
  State<_AddDeviceSheet> createState() => _AddDeviceSheetState();
}

class _AddDeviceSheetState extends State<_AddDeviceSheet> {
  final _name = TextEditingController();
  HelperTransport _transport = HelperTransport.mail;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      // Scrollbar, damit „QR-Code zeigen“ auch auf kleinen Telefonen und mit
      // Tastatur erreichbar bleibt (UX-Prüfung 0.24.0).
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Gerät hinzufügen',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const HelperHelpButton(),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('helper-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name des Geräts',
                hintText: 'z. B. Handy Anna',
              ),
            ),
            const SizedBox(height: 12),
            const Text('Wie kommen die Belege zu dir?'),
            // Datei teilen ist nur noch Notweg („Exportieren“ beim Mithelfer),
            // nicht mehr als Weg angeboten (Entscheidung 2026-10-17).
            for (final t in const [
              HelperTransport.mail,
              HelperTransport.folder,
            ])
              RadioListTile<HelperTransport>(
                key: Key('helper-transport-${t.name}'),
                contentPadding: EdgeInsets.zero,
                value: t,
                // ignore: deprecated_member_use
                groupValue: _transport,
                // ignore: deprecated_member_use
                onChanged: (v) => setState(() => _transport = v!),
                title: Text(t.label),
                subtitle: Text(
                  t == HelperTransport.mail
                      ? 'Empfohlen – Belege kommen verschlüsselt an deine '
                            'Empfangsadresse und landen von selbst im Eingang'
                      : 'Über einen Cloud-Ordner, den ihr beide öffnen könnt',
                ),
              ),
            const SizedBox(height: 12),
            PrimaryActionBar.filled(
              key: const Key('helper-show-qr'),
              label: 'QR-Code zeigen',
              icon: Icons.qr_code_2,
              onPressed: () => Navigator.of(context).pop((
                _name.text.trim().isEmpty ? 'Mithelfer' : _name.text.trim(),
                _transport,
              )),
            ),
          ],
        ),
      ),
    );
  }
}

/// Zeigt den Kopplungscode. Er enthält den Schlüssel: nur dem eigenen
/// Mithelfer zeigen, nicht fotografieren lassen oder teilen (P-R46).
class PairingQrScreen extends StatelessWidget {
  const PairingQrScreen({super.key, required this.code});

  final HelperPairingCode code;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${code.deviceName} koppeln')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(child: QrView(data: code.encode())),
          const SizedBox(height: 16),
          const Text(
            '1. Auf dem anderen Handy JeNi bucht installieren und öffnen.\n'
            '2. „Los geht’s“ und dann „Dieses Gerät ist ein '
            'Mithelfer-Gerät (koppeln)“ tippen.\n'
            '3. „QR-Code fotografieren“ und diesen Code aufnehmen.',
          ),
          const SizedBox(height: 12),
          const NoticeBanner(
            icon: Icons.lock_outline,
            message:
                'Der Code ist der Schlüssel zu deinem Eingang. Zeig ihn nur '
                'dem Gerät, das du koppeln willst – nicht fotografieren und '
                'verschicken.',
          ),
        ],
      ),
      bottomNavigationBar: PrimaryActionBar(
        primary: PrimaryActionBar.filled(
          key: const Key('helper-qr-done'),
          label: 'Fertig',
          icon: Icons.check,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
