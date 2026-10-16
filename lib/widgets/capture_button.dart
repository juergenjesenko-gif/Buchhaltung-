import 'package:flutter/material.dart';

/// Runder, großer Aufnahmeknopf „Beleg“ (DESIGN_SPEC 5a, Entscheidung
/// Auftraggeberin 2026-10-16): die wichtigste Funktion der App, blind mit dem
/// Daumen erreichbar. Immer unten in der Mitte – auf der Übersicht, in der
/// Belegliste und im Belegformular an derselben Stelle, damit die Hand sich
/// den Ort merkt. Kreis [diameter] dp mit Kamerasymbol, Beschriftung
/// darunter, Semantik „[label] fotografieren“.
class CaptureButton extends StatelessWidget {
  const CaptureButton({
    super.key,
    required this.onPressed,
    this.label = 'Beleg',
    this.heroTag,
  });

  /// Durchmesser des Kreises, deutlich über 48 dp (`touch.capture`).
  static const double diameter = 76;

  final VoidCallback? onPressed;
  final String label;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '$label fotografieren',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: diameter,
            child: FloatingActionButton.large(
              heroTag: heroTag,
              shape: const CircleBorder(),
              onPressed: onPressed,
              child: const Icon(Icons.photo_camera, size: 36),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
