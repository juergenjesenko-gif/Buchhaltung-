import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../services/app_lock/app_lock_service.dart';
import '../../services/app_lock/platform_app_lock.dart';
import '../../widgets/common.dart';

/// Legt Sperrbildschirm bzw. Abdeckung über die ganze App (FA-1.15, FA-1.17).
/// Die Navigation darunter bleibt erhalten; nach dem Entsperren geht es dort
/// weiter, wo die Nutzerin war.
class AppLockGate extends StatelessWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Stack(
      children: [
        // Unter der Sperre nicht bedienbar und für Screenreader unsichtbar.
        ExcludeSemantics(
          excluding: state.isLocked,
          child: AbsorbPointer(absorbing: state.isLocked, child: child),
        ),
        if (state.isLocked) const Positioned.fill(child: LockScreen()),
        if (state.isObscured && !state.isLocked)
          const Positioned.fill(child: _PrivacyCover()),
      ],
    );
  }
}

class _PrivacyCover extends StatelessWidget {
  const _PrivacyCover();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: Center(
      child: Icon(
        Icons.lock_outline,
        size: 48,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pin = TextEditingController();
  bool _busy = false;
  bool _biometric = false;
  String? _message;
  DateTime? _waitUntil;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    final state = AppScope.of(context);
    final wantBio = await state.appLock.biometricEnabled();
    final canBio = wantBio && await const BiometricUnlock().isAvailable();
    final wait = await state.appLock.waitUntil();
    if (!mounted) return;
    setState(() => _biometric = canBio);
    _setWait(wait);
    if (canBio) await _tryBiometric();
  }

  void _setWait(DateTime? until) {
    _ticker?.cancel();
    _waitUntil = until;
    if (until != null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (!DateTime.now().isBefore(until)) {
          _ticker?.cancel();
          setState(() => _waitUntil = null);
        } else {
          setState(() {});
        }
      });
    }
  }

  Future<void> _tryBiometric() async {
    final state = AppScope.of(context);
    if (await const BiometricUnlock().authenticate()) {
      await state.appLock.biometricSucceeded();
      state.unlock();
    }
  }

  Future<void> _submit() async {
    if (_busy || _waitUntil != null) return;
    final state = AppScope.of(context);
    setState(() => _busy = true);
    final result = await state.appLock.checkPin(_pin.text);
    if (!mounted) return;
    _pin.clear();
    switch (result) {
      case PinAccepted():
        state.unlock();
      case PinRejected(:final failedAttempts, :final waitUntil):
        _message = 'Falsche PIN ($failedAttempts. Fehlversuch).';
        _setWait(waitUntil);
      case PinMustWait(:final waitUntil):
        _setWait(waitUntil);
    }
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final wait = _waitUntil;
    final remaining = wait?.difference(DateTime.now());
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Buchhaltung ist gesperrt',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  PasswordField(
                    controller: _pin,
                    label: 'PIN',
                    digitsOnly: true,
                    autofocus: !_biometric,
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 12),
                  if (remaining != null)
                    Text(
                      'Zu viele Fehlversuche. Nächster Versuch in '
                      '${Fmt.duration(remaining)}.',
                      textAlign: TextAlign.center,
                    )
                  else if (_message != null)
                    Text(_message!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy || wait != null ? null : _submit,
                    child: const Text('Entsperren'),
                  ),
                  if (_biometric) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _tryBiometric,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Fingerabdruck / Face ID'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const AlertDialog(
                        title: Text('PIN vergessen?'),
                        content: Text(forgottenPinText),
                      ),
                    ),
                    child: const Text('PIN vergessen?'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Erklärung beim Einrichten und auf dem Sperrbildschirm (FA-1.18).
const forgottenPinText =
    'Die PIN lässt sich nicht zurücksetzen – auch nicht durch den Anbieter, '
    'denn es gibt kein Konto und keinen Server.\n\n'
    'Ausweg: App-Daten löschen oder die App neu installieren und danach aus '
    'deiner Sicherung wiederherstellen (Kennwort oder Wiederherstellungscode). '
    'Alles, was seit der letzten Sicherung erfasst wurde, geht dabei verloren.';
