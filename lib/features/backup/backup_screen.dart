import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../widgets/danger_zone.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../data/app_database.dart';
import '../../domain/company_profile.dart';
import '../../services/backup/auto_backup_service.dart';
import '../../services/backup/backup_archive.dart';
import '../../services/backup/backup_crypto.dart';
import '../../data/auto_backup_settings.dart';
import '../../services/backup/backup_retention.dart';
import '../../services/backup/backup_service.dart';
import '../../services/backup/platform_backup_target.dart';
import '../../widgets/common.dart';
import '../../widgets/adaptive.dart';
import '../demo/demo_screens.dart';
import 'recovery_code_setup_screen.dart';

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
      ], subject: 'Datensicherung JeNi bucht');
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
    final bytes = await PlatformBackupTarget.pickFile();
    if (bytes == null || !mounted) return;
    await _restoreBytes(bytes);
  }

  /// Gemeinsamer Weg für gewählte Datei und Liste der automatischen
  /// Sicherungen (FA-7.16): erst mit dem Schlüssel dieses Geräts, sonst mit
  /// Kennwort oder Wiederherstellungscode.
  Future<void> _restoreBytes(Uint8List bytes) async {
    BackupContent? content;
    final key = await const SecureBackupKeyStore().read();
    if (key != null) {
      try {
        content = await BackupService.openWithKey(bytes, key);
      } on Object {
        content = null;
      }
    }
    if (!mounted) return;
    if (content == null) {
      final passphrase = await showDialog<String>(
        context: context,
        builder: (_) => const _PassphraseDialog(),
      );
      if (passphrase == null || !mounted) return;
      content = await _openWithPassphrase(bytes, passphrase);
      if (content == null || !mounted) return;
    }
    await _confirmAndRestore(content);
  }

  Future<BackupContent?> _openWithPassphrase(
    Uint8List bytes,
    String passphrase,
  ) async {
    setState(() => _busy = true);
    BackupContent content;
    try {
      content = await BackupService.open(bytes, passphrase);
    } on BackupPassphraseException catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, error.toString());
      }
      return null;
    } on BackupFormatException catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, error.message);
      }
      return null;
    }
    if (mounted) setState(() => _busy = false);
    return content;
  }

  Future<void> _confirmAndRestore(BackupContent content) async {
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
    // Demo (FA-13.14): keine Sicherung, keine Wiederherstellung.
    if (AppScope.of(context).isDemo) {
      return const DemoUnavailable(title: 'Datensicherung');
    }
    final profile = AppScope.of(context).profile;
    final last = profile?.lastBackupAt;
    return Scaffold(
      appBar: AppBar(title: const Text('Datensicherung')),
      body: ReadableWidth(
        child: ListView(
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
            _AutoBackupSection(onRestore: _restoreBytes),
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
            PasswordField(
              controller: _first,
              label: 'Kennwort',
              validator: (value) =>
                  (value ?? '').length < BackupCrypto.minPassphraseLength
                  ? 'Mindestens ${BackupCrypto.minPassphraseLength} Zeichen'
                  : null,
            ),
            PasswordField(
              controller: _second,
              label: 'Kennwort wiederholen',
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
      content: PasswordField(
        controller: _controller,
        autofocus: true,
        label: 'Kennwort oder Wiederherstellungscode',
        helperText: 'Automatische Sicherungen öffnest du mit dem Code',
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
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
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

/// Automatische Sicherung in einen einmal gewählten Ordner (L-7.2, L-7.6 ff.).
class _AutoBackupSection extends StatefulWidget {
  const _AutoBackupSection({required this.onRestore});

  /// Gewählte Sicherung aus der Liste wiederherstellen (FA-7.16).
  final Future<void> Function(Uint8List bytes) onRestore;

  @override
  State<_AutoBackupSection> createState() => _AutoBackupSectionState();
}

class _AutoBackupSectionState extends State<_AutoBackupSection> {
  AutoBackupSettings? _settings;
  bool _busy = false;

  /// iCloud-Container verfügbar (nur iOS, FA-7.16).
  bool _icloud = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = AutoBackupSettings.load(
      await AppDatabase.instance.database,
    );
    final loaded = await settings;
    final icloud = await PlatformBackupTarget.icloudAvailable();
    if (mounted) {
      setState(() {
        _settings = loaded;
        _icloud = icloud;
      });
    }
  }

  /// Einrichten: unter iOS mit iCloud ohne Ordnerwahl in den App-Container
  /// (L-7.17); sonst oder mit [chooseFolder] über die Ordnerauswahl (L-7.18).
  Future<void> _enable({bool chooseFolder = false}) async {
    final useIcloud = !chooseFolder && _icloud;
    final agreed = await showDialog<bool>(
      context: context,
      builder: (_) => _AutoBackupExplanation(icloud: useIcloud),
    );
    if (agreed != true || !mounted) return;

    final picked = useIcloud
        ? (
            folder: PlatformBackupTarget.icloud,
            label: PlatformBackupTarget.icloudLabel,
          )
        : await PlatformBackupTarget.pick();
    if (picked == null || !mounted) return;

    final key = RecoveryCode.newKey();
    final owner = AppScope.read(context).profile?.companyName ?? '';
    final confirmed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RecoveryCodeSetupScreen(
          code: RecoveryCode.encode(key),
          owner: owner,
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await const SecureBackupKeyStore().write(key);
      await AutoBackupSettings.enable(
        await AppDatabase.instance.database,
        folder: picked.folder,
        label: picked.label,
      );
      if (!mounted) return;
      final service = await AppScope.read(context).autoBackupService();
      final outcome = await service?.run();
      if (mounted) {
        showSnack(
          context,
          outcome?.error ?? 'Automatische Sicherung eingerichtet.',
        );
      }
    } finally {
      await _load();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runNow() async {
    setState(() => _busy = true);
    try {
      final service = await AppScope.read(context).autoBackupService();
      final outcome = await service?.run();
      if (mounted) {
        showSnack(
          context,
          outcome?.error ?? 'Sicherung gespeichert und geprüft.',
        );
      }
    } finally {
      await _load();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    try {
      final service = await AppScope.read(context).autoBackupService();
      final manifest = await service!.verifyLatest();
      if (mounted) {
        showSnack(
          context,
          'Lesbar: Sicherung vom ${Fmt.date(manifest.createdAt)} mit '
          '${manifest.receiptCount} Belegen.',
        );
      }
    } catch (error) {
      if (mounted) showSnack(context, 'Prüfung fehlgeschlagen: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Liste der automatischen Sicherungen im Ordner; ein Tipp stellt wieder
  /// her (nach Vorschau und Bestätigung).
  Future<void> _pickBackup() async {
    setState(() => _busy = true);
    List<String> names;
    AutoBackupService? service;
    try {
      service = await AppScope.read(context).autoBackupService();
      names = await service?.backups() ?? const [];
    } catch (error) {
      if (mounted) showSnack(context, 'Ordner nicht lesbar: $error');
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (names.isEmpty) {
      showSnack(context, 'Im Ordner liegt keine automatische Sicherung.');
      return;
    }
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final name in names)
              ListTile(
                minTileHeight: 56,
                leading: const Icon(Icons.restore),
                title: Text(
                  'Sicherung vom ${Fmt.date(BackupRetention.parse(name)!)}',
                ),
                subtitle: Text(name),
                onTap: () => Navigator.of(context).pop(name),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() => _busy = true);
    Uint8List bytes;
    try {
      bytes = await service!.target.read(chosen);
    } catch (error) {
      if (mounted) showSnack(context, 'Sicherung nicht lesbar: $error');
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await widget.onRestore(bytes);
  }

  Future<void> _disable() async {
    final sure = await confirmDestructive(
      context,
      title: 'Automatische Sicherung ausschalten?',
      message:
          'Vorhandene Sicherungen im Ordner bleiben erhalten. Der Schlüssel '
          'wird von diesem Gerät gelöscht – öffnen kannst du sie danach nur '
          'noch mit dem Wiederherstellungscode.',
      verb: 'Ausschalten',
    );
    if (sure != true) return;
    await const SecureBackupKeyStore().delete();
    await AutoBackupSettings.disable(await AppDatabase.instance.database);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Automatische Sicherung',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (settings == null)
            const LinearProgressIndicator()
          else if (!settings.enabled) ...[
            const Text(
              'Sichert nach jeder Änderung höchstens einmal täglich in einen '
              'Ordner deiner Wahl, etwa in Google Drive, unter iOS in dein iCloud Drive. '
              'Standardmäßig aus.',
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _enable,
              icon: const Icon(Icons.cloud_sync_outlined),
              label: const Text('Einrichten'),
            ),
          ] else ...[
            Text(
              'Ordner: ${settings.displayLabel}',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              settings.lastAt == null
                  ? 'Noch keine automatische Sicherung.'
                  : 'Letzte geprüfte Sicherung: ${Fmt.date(settings.lastAt!)}',
            ),
            if (settings.lastError != null) ...[
              const SizedBox(height: 8),
              NoticeBanner(
                icon: Icons.error_outline,
                color: theme.colorScheme.error,
                message: settings.lastError!,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _busy ? null : _runNow,
                  child: const Text('Jetzt sichern'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _verify,
                  child: const Text('Sicherung prüfen'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _pickBackup,
                  child: const Text('Wiederherstellen'),
                ),
                if (_icloud && settings.folder != PlatformBackupTarget.icloud)
                  OutlinedButton(
                    onPressed: _busy ? null : _enable,
                    child: const Text('In iCloud sichern'),
                  ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _enable(chooseFolder: true),
                  child: const Text('Ordner ändern'),
                ),
                TextButton(
                  onPressed: _busy ? null : _disable,
                  child: const Text('Ausschalten'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Aufbewahrt werden die letzten 7 Sicherungen, je Monat eine für '
              '12 Monate und je Jahr eine dauerhaft. Dateien heißen '
              '${BackupRetention.prefix}… – andere Dateien im Ordner fasst die '
              'App nicht an.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// Erklärseite vor dem Einschalten (Prüfinstanzen Rechtsanwalt, Steuerberater).
class _AutoBackupExplanation extends StatelessWidget {
  const _AutoBackupExplanation({this.icloud = false});

  /// Ziel ist der iCloud-Container (FA-7.16) statt eines gewählten Ordners.
  final bool icloud;

  String get _where => icloud
      ? '• Die Sicherung enthält alle Daten und Belegfotos – auch Angaben '
            'deiner Kunden und Lieferanten. Sie landet in deinem iCloud Drive '
            'im Ordner „JeNi bucht“ (in der Dateien-App sichtbar), bei Apple '
            'und unter dessen Bedingungen, auch außerhalb der EU. Ausschalten '
            'kannst du sie hier jederzeit.'
      : '• Die Sicherung enthält alle Daten und Belegfotos – auch Angaben '
            'deiner Kunden und Lieferanten. Sie landet in dem Ordner, den du '
            'gleich wählst, bei einem Dienst deiner Wahl und unter dessen '
            'Bedingungen. Viele dieser Dienste speichern außerhalb der EU.';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Automatische Sicherung'),
      content: SingleChildScrollView(
        child: Text(
          '$_where\n\n'
          '• Die Datei ist verschlüsselt (AES-256). Der Dienst sieht nur Name, '
          'Größe und Zeitpunkt; wir sehen nichts.\n\n'
          '• Der Schlüssel bleibt auf diesem Gerät. Du bekommst gleich einen '
          'Wiederherstellungscode als Druckblatt. Ohne ihn kann niemand die Sicherung auf '
          'einem anderen Gerät öffnen – auch du nicht.\n\n'
          '• Die Sicherung ersetzt nicht deine gesetzliche Aufbewahrungspflicht '
          '(7 Jahre in Österreich, 8 bzw. 10 Jahre in Deutschland). Geht dein '
          'Gerät verloren, stell die Daten bald auf einem neuen Gerät wieder '
          'her.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(icloud ? 'In iCloud sichern' : 'Ordner wählen'),
        ),
      ],
    );
  }
}
