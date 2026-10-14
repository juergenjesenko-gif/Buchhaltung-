import 'package:flutter/material.dart';

import '../../core/window_size.dart';

/// Unten fixierte Speicherleiste des Belegformulars.
///
/// Sind neue Seiten hinzugekommen, ist Speichern zugleich die
/// Vollständigkeitsbestätigung (L-2.16, FA-2.14): der Primärknopf heißt
/// „Vollständig – Beleg speichern“ und nennt die Seitenzahl, darüber steht,
/// was das Tippen bestätigt. Ein eigenes Häkchen gibt es nicht mehr
/// (Prüfpunkt P-S31).
///
/// Die Leiste bleibt über der Bildschirmtastatur sichtbar und liegt im
/// Daumenbereich: auf dem Telefon volle Breite, ab 600 dp rechtsbündig.
class ReceiptSaveBar extends StatelessWidget {
  const ReceiptSaveBar({
    super.key,
    required this.totalPages,
    required this.hasNewPages,
    required this.editing,
    required this.saving,
    required this.onSave,
    this.onAddPage,
  });

  final int totalPages;

  /// Neue, noch nicht gespeicherte Seiten: dann bestätigt Speichern die
  /// Vollständigkeit.
  final bool hasNewPages;
  final bool editing;
  final bool saving;
  final VoidCallback onSave;

  /// Sekundäre Aktion bei nur einer Seite: beschriebene Rückseite ergänzen.
  final VoidCallback? onAddPage;

  /// Mindesthöhe des Primärknopfs, über `touch.min` (48 dp) hinaus.
  static const double primaryHeight = 56;

  static String pagesLabel(int count) =>
      count == 1 ? '1 Seite' : '$count Seiten';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final wide =
        WindowSizeClass.fromWidth(media.size.width) != WindowSizeClass.compact;
    final confirms = hasNewPages;

    final primary = FilledButton.icon(
      key: const ValueKey('receipt-save'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, primaryHeight),
        textStyle: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      onPressed: saving ? null : onSave,
      icon: saving
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(confirms ? Icons.task_alt : Icons.check),
      label: Text(
        confirms
            ? 'Vollständig – Beleg speichern (${pagesLabel(totalPages)})'
            : (editing ? 'Änderungen speichern' : 'Beleg speichern'),
        textAlign: TextAlign.center,
      ),
    );

    final secondary = confirms && totalPages == 1 && onAddPage != null
        ? OutlinedButton.icon(
            key: const ValueKey('receipt-add-back'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, primaryHeight),
            ),
            onPressed: saving ? null : onAddPage,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Rückseite?'),
          )
        : null;

    final buttons = Row(
      children: [
        if (wide) const Spacer(),
        if (secondary != null) ...[secondary, const SizedBox(width: 12)],
        if (wide)
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 320, maxWidth: 440),
            child: primary,
          )
        else
          Expanded(child: primary),
      ],
    );

    return Material(
      color: theme.colorScheme.surfaceContainer,
      elevation: 3,
      child: Padding(
        // Über der Tastatur bleiben (viewInsets), sonst über dem Home-Balken.
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          8 +
              (media.viewInsets.bottom > 0
                  ? media.viewInsets.bottom
                  : media.padding.bottom),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: wide
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.stretch,
          children: [
            if (confirms)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Mit Speichern bestätigst du, dass alle Seiten '
                  'inkl. beschriebener Rückseiten erfasst sind.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: wide ? TextAlign.end : TextAlign.start,
                ),
              ),
            buttons,
          ],
        ),
      ),
    );
  }
}
