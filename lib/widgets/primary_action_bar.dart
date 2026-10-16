import 'package:flutter/material.dart';

import '../core/window_size.dart';

/// Unten fixierte Aktionsleiste mit einer Primäraktion (UX-Vorgabe,
/// abgeleitet aus der Speicherleiste des Belegformulars):
/// Primärknopf 56 dp hoch, auf dem Telefon volle Breite, ab 600 dp
/// rechtsbündig; bleibt über der Bildschirmtastatur (viewInsets).
class PrimaryActionBar extends StatelessWidget {
  const PrimaryActionBar({
    super.key,
    required this.primary,
    this.secondary,
    this.note,
    this.capture,
  });

  /// Mindesthöhe der Knöpfe, über die 48-dp-Zielfläche hinaus.
  static const double height = 56;

  final Widget primary;
  final Widget? secondary;

  /// Runder Aufnahmeknopf mittig über der Leiste (DESIGN_SPEC 5a, Regel 13).
  final Widget? capture;

  /// Erklärzeile über den Knöpfen, z. B. was das Tippen bestätigt.
  final String? note;

  /// Primärknopf im Stil der Leiste.
  static Widget filled({
    required Key key,
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool busy = false,
    TextStyle? textStyle,
  }) => FilledButton.icon(
    key: key,
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, height),
      textStyle: textStyle,
    ),
    onPressed: busy ? null : onPressed,
    icon: busy
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon),
    label: Text(label, textAlign: TextAlign.center),
  );

  /// Sekundärknopf im Stil der Leiste.
  static Widget outlined({
    required Key key,
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) => OutlinedButton.icon(
    key: key,
    style: OutlinedButton.styleFrom(minimumSize: const Size(0, height)),
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(label),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final wide =
        WindowSizeClass.fromWidth(media.size.width) != WindowSizeClass.compact;

    final buttons = Row(
      children: [
        if (wide) const Spacer(),
        if (secondary != null) ...[secondary!, const SizedBox(width: 12)],
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
            if (capture != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Center(child: capture),
              ),
            if (note != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  note!,
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
