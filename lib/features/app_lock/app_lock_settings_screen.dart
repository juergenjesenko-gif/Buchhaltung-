import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../services/app_lock/app_lock_service.dart';
import '../../services/app_lock/platform_app_lock.dart';
import '../../widgets/common.dart';
import '../backup/backup_screen.dart';
import 'lock_screen.dart';

/// Einstellungen → App-Sperre (FA-1.13 bis FA-1.18).
class AppLockSettingsScreen extends StatefulWidget {
  const AppLockSettingsScreen({super.key});

  @override
  State<AppLockSettingsScreen> createState() => _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  bool _loading = true;
  bool _enabled = false;
  bool _biometric = false;
  bool _biometricAvailable = false;
  bool _hasBackup = true;
  bool _understood = false;
  int _timeout = AppLockPolicy.defaultTimeoutSeconds;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  @override
  void dispose() {
    _pin.dispose();
    _pin2.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final state = AppScope.of(context);
    final lock = state.appLock;
    final enabled = await lock.isEnabled();
    final bio = await lock.biometricEnabled();
    final timeout = await lock.timeoutSeconds();
    final available = await const BiometricUnlock().isAvailable();
    final hasBackup = await state.hasAnyBackup();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _biometric = bio;
      _timeout = timeout;
      _biometricAvailable = available;
      _hasBackup = hasBackup;
      _loading = false;
    });
  }

  Future<void> _enable() async {
    if (!_formKey.currentState!.validate()) return;
    final state = AppScope.of(context);
    await state.appLock.enable(
      _pin.text,
      biometric: _biometric && _biometricAvailable,
      timeoutSeconds: _timeout,
    );
    await state.appLockChanged();
    _pin.clear();
    _pin2.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('App-Sperre eingeschaltet')));
    await _load();
  }

  /// Fragt die aktuelle PIN ab; Ausschalten und Ändern nur damit.
  Future<bool> _confirmCurrentPin() async {
    final state = AppScope.of(context);
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aktuelle PIN'),
        content: PasswordField(
          controller: controller,
          label: 'PIN',
          digitsOnly: true,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Weiter'),
          ),
        ],
      ),
    );
    final pin = controller.text;
    controller.dispose();
    if (ok != true) return false;
    final result = await state.appLock.checkPin(pin);
    if (result is PinAccepted) return true;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result is PinRejected && result.waitUntil == null
                ? 'Falsche PIN'
                : 'Zu viele Fehlversuche, bitte später erneut versuchen',
          ),
        ),
      );
    }
    return false;
  }

  Future<void> _disable() async {
    if (!await _confirmCurrentPin()) return;
    if (!mounted) return;
    final state = AppScope.of(context);
    await state.appLock.disable();
    await state.appLockChanged();
    await _load();
  }

  Future<void> _changePin() async {
    if (!await _confirmCurrentPin()) return;
    if (!mounted) return;
    final state = AppScope.of(context);
    await state.appLock.disable();
    await state.appLockChanged();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App-Sperre')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: _enabled ? _enabledView() : _setupView(),
            ),
    );
  }

  Widget _timeoutPicker(ValueChanged<int> onChanged) {
    String label(int s) => s == 0 ? 'sofort' : 'nach ${s ~/ 60} min';
    return DropdownButtonFormField<int>(
      initialValue: _timeout,
      decoration: const InputDecoration(labelText: 'Sperren im Hintergrund'),
      items: [
        for (final s in AppLockPolicy.timeoutChoicesSeconds)
          DropdownMenuItem(value: s, child: Text(label(s))),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget? _biometricSwitch(ValueChanged<bool> onChanged) {
    if (!_biometricAvailable) return null;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Fingerabdruck / Face ID'),
      subtitle: const Text(
        'Das Gerät prüft, die App erhält keine biometrischen Daten. '
        'Die PIN bleibt immer als Rückfall.',
      ),
      value: _biometric,
      onChanged: onChanged,
    );
  }

  List<Widget> _enabledView() {
    final state = AppScope.of(context);
    return [
      SectionCard(
        title: 'App-Sperre ist eingeschaltet',
        child: Column(
          children: [
            ?_biometricSwitch((v) async {
              await state.appLock.setBiometric(v);
              setState(() => _biometric = v);
            }),
            _timeoutPicker((v) async {
              await state.appLock.setTimeoutSeconds(v);
              await state.initAppLock();
              state.unlock();
              setState(() => _timeout = v);
            }),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton(
                  onPressed: _changePin,
                  child: const Text('PIN ändern'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _disable,
                  child: const Text('Ausschalten'),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const SectionCard(title: 'PIN vergessen?', child: Text(forgottenPinText)),
    ];
  }

  List<Widget> _setupView() {
    return [
      SectionCard(
        title: 'Schutz beim Öffnen',
        child: const Text(
          'Mit der App-Sperre fragt die App beim Start und nach einer Zeit im '
          'Hintergrund nach deiner PIN oder deinem Fingerabdruck bzw. Face ID. '
          'Im App-Umschalter wird der Inhalt verdeckt.',
        ),
      ),
      const SizedBox(height: 12),
      SectionCard(
        title: 'Wichtig: Die PIN kann niemand zurücksetzen',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(forgottenPinText),
            if (!_hasBackup) ...[
              const SizedBox(height: 12),
              Text(
                'Du hast noch keine Sicherung. Ohne Sicherung wären deine '
                'Daten bei vergessener PIN verloren. Lege bitte zuerst eine an.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BackupScreen()),
                  );
                  if (mounted) await _load();
                },
                icon: const Icon(Icons.backup_outlined),
                label: const Text('Zur Datensicherung'),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      SectionCard(
        title: 'PIN festlegen',
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              PasswordField(
                controller: _pin,
                label: 'PIN',
                digitsOnly: true,
                helperText:
                    '${AppLockPolicy.pinMinDigits} bis '
                    '${AppLockPolicy.pinMaxDigits} Ziffern',
                validator: (v) => AppLockPolicy.pinError(v ?? ''),
              ),
              const SizedBox(height: 8),
              PasswordField(
                controller: _pin2,
                label: 'PIN wiederholen',
                digitsOnly: true,
                validator: (v) =>
                    v == _pin.text ? null : 'Stimmt nicht überein',
              ),
              ?_biometricSwitch((v) => setState(() => _biometric = v)),
              _timeoutPicker((v) => setState(() => _timeout = v)),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _understood,
                onChanged: (v) => setState(() => _understood = v ?? false),
                title: const Text(
                  'Ich habe verstanden, dass eine vergessene PIN nur über '
                  'Neuinstallation und Wiederherstellung aus der Sicherung '
                  'zu lösen ist.',
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _understood ? _enable : null,
                  child: const Text('App-Sperre einschalten'),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }
}
