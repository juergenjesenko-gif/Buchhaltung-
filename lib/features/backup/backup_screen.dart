import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../data/app_database.dart';
import '../../domain/company_profile.dart';
import '../../services/backup/backup_archive.dart';
import '../../services/backup/backup_crypto.dart';
import '../../services/backup/backup_service.dart';
import '../../widgets/common.dart';

/// Datensicherung erstellen und wiederherstellen (Lastenheft L-7).
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;

  Future<BackupService> _service() async => BackupService(
    db: await AppDatabase.instance.database,
    documentsDir: await getApplicationDocumentsDirectory(),
    tempDir: await getTemporaryDirectory(),
  );

  Future<void> _create() async {
    final passphrase = await showDialog<String>(
      context: context,
      builder: (_) => const _NewPassphraseDialog(),
    );
    if (passphrase == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final file = await (await _service()).create(passphrase);
      if (!mounted) return;
      await AppScope.read(context).reload();
      // Ablageort wählt die Nutzerin: iCloud Drive, Google Drive, Dateien …
      await Share.shareXFiles([
        XFile(file.path),
      ], subject: 'Datensicherung Buchhaltung');
      if (mounted) {
        showSnack(
          context,
          'Sicherung erstellt. Leg sie in deinem Cloud-Speicher ab.',
        );
      }
    } catch (error) {
      if (mounted) showSnack(context, 'Sicherung fehlgeschlagen: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final picked = await FilePicker.pickFiles(withData: true);
    final bytes = picked?.files.single.bytes;
    if (bytes == null || !mounted) return;

    final passphrase = await showDialog<String>(
      context: context,
      builder: (_) => const _PassphraseDialog(),
    );
    if (passphrase == null || !mounted) return;

    setState(() => _busy = true);
    BackupContent content;
    try {
      content = await BackupService.open(bytes, passphrase);
    } on BackupPassphraseException catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, error.toString());
      }
      return;
    } on BackupFormatException catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, error.message);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _RestorePreview(manifest: content.manifest),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await (await _service()).restore(content);
      if (!mounted) return;
      await AppScope.read(context).reload();
      if (mounted) showSnack(context, 'Sicherung wiederhergestellt.');
    } catch (error) {
      if (mounted) {
        showSnack(context, 'Wiederherstellung fehlgeschlagen: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = AppScope.of(context).profile;
    final last = profile?.lastBackupAt;
    return Scaffold(
      appBar: AppBar(title: const Text('Datensicherung')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          SectionCard(
            title: 'Sicherung',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  last == null
                      ? 'Noch keine Sicherung erstellt.'
                      : 'Letzte Sicherung: ${Fmt.date(last)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Die Sicherung enthält alle Daten und Belegfotos in einer '
                  'verschlüsselten Datei. Nur wer das Kennwort kennt, kann sie '
                  'öffnen – auch wir nicht. Speichere sie in deinem eigenen '
                  'Cloud-Speicher (iCloud Drive, Google Drive) oder auf einem '
                  'anderen Gerät.',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _create,
                  icon: const Icon(Icons.backup_outlined),
                  label: const Text('Sicherung erstellen'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Wiederherstellen',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Liest eine Sicherung ein, zum Beispiel auf einem neuen '
                  'Gerät. Alle Daten auf diesem Gerät werden dabei durch die '
                  'der Sicherung ersetzt. Vorher siehst du, was die Sicherung '
                  'enthält.',
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _restore,
                  icon: const Icon(Icons.restore),
                  label: const Text('Sicherung wiederherstellen'),
                ),
              ],
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}

class _NewPassphraseDialog extends StatefulWidget {
  const _NewPassphraseDialog();

  @override
  State<_NewPassphraseDialog> createState() => _NewPassphraseDialogState();
}

class _NewPassphraseDialogState extends State<_NewPassphraseDialog> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _second = TextEditingController();

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kennwort für die Sicherung'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Schreib dir das Kennwort auf und bewahre es sicher auf. '
              'Ohne Kennwort lässt sich die Sicherung nicht öffnen – '
              'niemand kann es zurücksetzen.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _first,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Kennwort'),
              validator: (value) =>
                  (value ?? '').length < BackupCrypto.minPassphraseLength
                  ? 'Mindestens ${BackupCrypto.minPassphraseLength} Zeichen'
                  : null,
            ),
            TextFormField(
              controller: _second,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Kennwort wiederholen',
              ),
              validator: (value) => value != _first.text
                  ? 'Die Kennwörter stimmen nicht überein'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.of(context).pop(_first.text);
            }
          },
          child: const Text('Sichern'),
        ),
      ],
    );
  }
}

class _PassphraseDialog extends StatefulWidget {
  const _PassphraseDialog();

  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kennwort der Sicherung'),
      content: TextField(
        controller: _controller,
        obscureText: true,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Kennwort'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Öffnen'),
        ),
      ],
    );
  }
}

class _RestorePreview extends StatelessWidget {
  const _RestorePreview({required this.manifest});

  final BackupManifest manifest;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Diese Sicherung wiederherstellen?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Unternehmen: ${manifest.companyName}'),
          Text('Erstellt am: ${Fmt.date(manifest.createdAt)}'),
          Text('Belege: ${manifest.receiptCount}'),
          Text('Rechnungen: ${manifest.invoiceCount}'),
          Text('Kunden: ${manifest.customerCount}'),
          Text('Belegfotos: ${manifest.imageCount}'),
          const SizedBox(height: 12),
          const Text(
            'Alle Daten auf diesem Gerät werden ersetzt. Das lässt sich nicht '
            'rückgängig machen.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Wiederherstellen'),
        ),
      ],
    );
  }
}

/// Erinnerung auf der Übersicht (L-7.4).
class BackupReminder extends StatelessWidget {
  const BackupReminder({super.key, required this.profile});

  final CompanyProfile profile;

  @override
  Widget build(BuildContext context) {
    final last = profile.lastBackupAt;
    return NoticeBanner(
      icon: Icons.backup_outlined,
      color: Theme.of(context).colorScheme.tertiary,
      message: last == null
          ? 'Du hast noch keine Datensicherung. Geht dein Handy verloren, '
                'sind sonst alle Belege weg.'
          : 'Deine letzte Datensicherung ist vom ${Fmt.date(last)}. '
                'Zeit für eine neue.',
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const BackupScreen())),
    );
  }
}
