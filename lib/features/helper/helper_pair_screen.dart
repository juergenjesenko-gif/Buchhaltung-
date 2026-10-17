import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../data/helper_repository.dart';
import '../../services/backup/platform_backup_target.dart';
import '../../services/helper/helper_package.dart';
import '../../services/receipt_scan/platform_text_recognizer.dart';
import '../../widgets/common.dart';
import '../../widgets/primary_action_bar.dart';
import 'helper_capture.dart';

/// Mithelfer-Gerät koppeln (FA-17.2): QR-Code des Hauptgeräts fotografieren.
/// Danach zeigt die App nur noch die Belegerfassung.
class HelperPairScreen extends StatefulWidget {
  const HelperPairScreen({super.key});

  @override
  State<HelperPairScreen> createState() => _HelperPairScreenState();
}

class _HelperPairScreenState extends State<HelperPairScreen> {
  final _manual = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  Future<void> _photo() async {
    setState(() => _busy = true);
    try {
      final pages = await captureHelperPages(HelperSource.camera);
      if (pages.isEmpty || !mounted) return;
      final doc = await const PlatformReceiptTextRecognizer().recognize([
        for (final p in pages) p.path,
      ]);
      for (final f in pages) {
        if (await f.exists()) await f.delete();
      }
      HelperPairingCode? code;
      for (final raw in doc.codes) {
        code ??= HelperPairingCode.tryParse(raw);
      }
      if (!mounted) return;
      if (code == null) {
        showSnack(
          context,
          'Kein Kopplungscode erkannt. Bitte den QR-Code bildfüllend und '
          'scharf aufnehmen.',
        );
        return;
      }
      await _pair(code);
    } on Exception catch (e) {
      if (mounted) showSnack(context, 'Aufnahme fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pair(HelperPairingCode code) async {
    var link = HelperLink(
      pairingId: code.pairingId,
      key: code.key,
      businessName: code.businessName,
      deviceName: code.deviceName,
      transport: code.transport,
      receivingAddress: code.receivingAddress,
    );
    if (code.transport == HelperTransport.folder) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Gemeinsamen Ordner wählen'),
          content: Text(
            'Wähle den Ordner „Eingang“, den ${code.businessName} mit dir '
            'teilt (Google Drive, iCloud Drive …).',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Ordner wählen'),
            ),
          ],
        ),
      );
      if (ok == true) {
        final picked = await PlatformBackupTarget.pick();
        if (picked != null) link = link.withFolder(picked.folder, picked.label);
      }
    }
    if (!mounted) return;
    await AppScope.read(context).setHelperLink(link);
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ich helfe mit')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Mit diesem Handy fotografierst du Belege für einen Betrieb. Die '
            'Buchhaltung bleibt auf dem Hauptgerät; hier wird nichts gebucht. '
            'Gesendete Belege bleiben verschlüsselt auf diesem Handy, bis die '
            'Aufbewahrungsfrist abläuft.\n\n'
            '1. Auf dem Hauptgerät: Einstellungen → Mithelfer-Geräte → '
            '„Gerät hinzufügen“.\n'
            '2. Hier „QR-Code fotografieren“ tippen und den Code aufnehmen.',
          ),
          const SizedBox(height: 24),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Code von Hand einfügen'),
            children: [
              TextField(
                key: const Key('helper-pair-manual'),
                controller: _manual,
                decoration: const InputDecoration(
                  labelText: 'Kopplungscode (beginnt mit JENIBELEG1:)',
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('helper-pair-manual-ok'),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () {
                    final code = HelperPairingCode.tryParse(_manual.text);
                    if (code == null) {
                      showSnack(context, 'Das ist kein gültiger Code.');
                      return;
                    }
                    _pair(code);
                  },
                  child: const Text('Koppeln'),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: PrimaryActionBar(
        primary: PrimaryActionBar.filled(
          key: const Key('helper-pair-photo'),
          label: 'QR-Code fotografieren',
          icon: Icons.qr_code_scanner,
          busy: _busy,
          onPressed: _photo,
        ),
      ),
    );
  }
}
