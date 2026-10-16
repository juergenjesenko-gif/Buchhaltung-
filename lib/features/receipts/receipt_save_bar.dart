import 'package:flutter/material.dart';

import '../../widgets/capture_button.dart';
import '../../widgets/primary_action_bar.dart';

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

  /// Weitere Seite fotografieren: runder Aufnahmeknopf mittig über dem
  /// Speichern-Knopf, an derselben Stelle wie auf Übersicht und Belegliste
  /// (DESIGN_SPEC 5a, Regel 13). Mit offener Tastatur ausgeblendet, damit
  /// das aktive Feld sichtbar bleibt (Regel 5).
  final VoidCallback? onAddPage;

  /// Mindesthöhe des Primärknopfs, über `touch.min` (48 dp) hinaus.
  static const double primaryHeight = PrimaryActionBar.height;

  static String pagesLabel(int count) =>
      count == 1 ? '1 Seite' : '$count Seiten';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confirms = hasNewPages;
    return PrimaryActionBar(
      note: confirms
          ? 'Mit Speichern bestätigst du, dass alle Seiten '
                'inkl. beschriebener Rückseiten erfasst sind.'
          : null,
      capture:
          onAddPage != null && MediaQuery.of(context).viewInsets.bottom == 0
          ? CaptureButton(
              key: const ValueKey('receipt-add-page'),
              heroTag: 'receipt-add-page',
              label: totalPages == 0
                  ? 'Beleg'
                  : (totalPages == 1 && confirms ? 'Rückseite?' : 'Seite'),
              onPressed: saving ? null : onAddPage,
            )
          : null,
      primary: PrimaryActionBar.filled(
        key: const ValueKey('receipt-save'),
        label: confirms
            ? 'Vollständig – Beleg speichern (${pagesLabel(totalPages)})'
            : (editing ? 'Änderungen speichern' : 'Beleg speichern'),
        icon: confirms ? Icons.task_alt : Icons.check,
        onPressed: onSave,
        busy: saving,
        textStyle: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
