import 'package:flutter/material.dart';

/// Eigener Bereich am Formularende für eine zerstörende Aktion
/// (DESIGN_SPEC 5a, Regel 3): rot umrandet, volle Breite, Fehlerfarbe,
/// mit Abstand zu Speichern und Teilen.
class DangerZone extends StatelessWidget {
  const DangerZone({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.explanation,
    this.buttonKey,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final String? explanation;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 24),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: error.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (explanation != null) ...[
              Text(explanation!, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              key: buttonKey,
              style: OutlinedButton.styleFrom(
                foregroundColor: error,
                side: BorderSide(color: error),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bestätigung einer zerstörenden Aktion: Abbrechen links, Verb rechts in
/// Fehlerfarbe (DESIGN_SPEC 5a, Regel 6).
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String verb,
}) async {
  final error = Theme.of(context).colorScheme.error;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const Key('confirmDestructive'),
          style: FilledButton.styleFrom(
            backgroundColor: error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(verb),
        ),
      ],
    ),
  );
  return ok ?? false;
}
