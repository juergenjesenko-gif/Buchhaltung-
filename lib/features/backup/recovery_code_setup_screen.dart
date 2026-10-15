import 'package:flutter/material.dart';

import '../../services/backup/recovery_code_sheet.dart';
import '../../services/share_service.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/common.dart';
import '../../widgets/primary_action_bar.dart';

/// Wiederherstellungscode beim Einrichten der automatischen Sicherung
/// (L-22.21, L-22.22). Zwei Schritte auf einer Seite, Knöpfe unten in der
/// Daumenzone (DESIGN_SPEC 5a):
///
/// 1. Druckblatt (PDF mit Code und QR-Code) teilen oder drucken. Die App
///    zeigt den Code nicht an und behält keine Kopie.
/// 2. Zwei zufällige Blöcke vom Druckblatt abtippen. Erst dann geht es
///    weiter.
///
/// Liefert `true`, wenn bestätigt.
class RecoveryCodeSetupScreen extends StatefulWidget {
  const RecoveryCodeSetupScreen({
    super.key,
    required this.code,
    this.owner = '',
    this.share,
  });

  final String code;
  final String owner;

  /// Für Tests austauschbar; Standard: Teilen-Dialog des Systems.
  final Future<void> Function(List<int> bytes)? share;

  @override
  State<RecoveryCodeSetupScreen> createState() =>
      _RecoveryCodeSetupScreenState();
}

class _RecoveryCodeSetupScreenState extends State<RecoveryCodeSetupScreen> {
  late final RecoveryCodeChallenge _challenge = RecoveryCodeChallenge(
    widget.code,
  );
  final _first = TextEditingController();
  final _second = TextEditingController();
  bool _shared = false;
  bool _busy = false;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  Future<void> _shareSheet() async {
    setState(() => _busy = true);
    try {
      final bytes = await RecoveryCodeSheet.build(
        code: widget.code,
        createdAt: DateTime.now(),
        owner: widget.owner,
      );
      final share = widget.share;
      if (share != null) {
        await share(bytes);
      } else {
        await ShareService.sharePdf(
          fileName: RecoveryCodeSheet.fileName,
          bytes: bytes,
          subject: 'Wiederherstellungscode',
        );
      }
      if (mounted) setState(() => _shared = true);
    } on Exception catch (error) {
      if (mounted) showSnack(context, 'Druckblatt ging nicht: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _ok => _challenge.confirmed(_first.text, _second.text);

  Widget _blockField(int block, TextEditingController controller, Key key) {
    final done = _challenge.matches(block, controller.text);
    return TextField(
      key: key,
      controller: controller,
      maxLength: 4,
      textCapitalization: TextCapitalization.characters,
      autocorrect: false,
      enableSuggestions: false,
      style: const TextStyle(fontSize: 20, letterSpacing: 4),
      decoration: InputDecoration(
        labelText: 'Block $block',
        counterText: '',
        suffixIcon: done ? const Icon(Icons.check_circle_outline) : null,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (a, b) = _challenge.blocks;
    return Scaffold(
      appBar: AppBar(title: const Text('Wiederherstellungscode')),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const Text(
              'Deine Sicherung wird mit einem Schlüssel verschlüsselt, der '
              'nur auf diesem Handy liegt. Für ein neues Handy brauchst du '
              'den Wiederherstellungscode. Wir haben keine Kopie – geht er '
              'verloren, kann niemand die Sicherung öffnen.',
            ),
            const SizedBox(height: 16),
            const Text(
              '1. Tippe auf „Druckblatt teilen“ und drucke es aus oder '
              'speichere es in deinem Passwortmanager – nicht nur auf '
              'diesem Handy.',
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('recoveryShare'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(PrimaryActionBar.height),
              ),
              onPressed: _busy ? null : _shareSheet,
              icon: const Icon(Icons.print_outlined),
              label: Text(
                _shared ? 'Druckblatt noch einmal teilen' : 'Druckblatt teilen',
              ),
            ),
            if (_shared) ...[
              const SizedBox(height: 24),
              Text(
                '2. Zur Kontrolle: Schau aufs Druckblatt und tippe Block $a '
                'und Block $b ab.',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _blockField(a, _first, const Key('recoveryBlockA')),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _blockField(b, _second, const Key('recoveryBlockB')),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: PrimaryActionBar(
        note: _shared
            ? (_ok ? null : 'Beide Blöcke müssen stimmen.')
            : 'Zuerst das Druckblatt teilen.',
        primary: PrimaryActionBar.filled(
          key: const Key('recoveryConfirm'),
          label: 'Code ist aufbewahrt',
          icon: Icons.check,
          onPressed: _shared && _ok
              ? () => Navigator.of(context).pop(true)
              : null,
        ),
      ),
    );
  }
}
