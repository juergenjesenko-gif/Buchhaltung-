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

/// Kleiner runder Nebenknopf neben dem Aufnahmeknopf (DESIGN_SPEC 5a,
/// Regel 13): Kreis [diameter] dp, Symbol, Beschriftung darunter.
class SecondaryCaptureButton extends StatelessWidget {
  const SecondaryCaptureButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.semanticLabel,
    this.heroTag,
  });

  /// Durchmesser, über `touch.min` (48 dp), kleiner als der Hauptknopf.
  static const double diameter = 56;

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final String semanticLabel;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: diameter,
            child: FloatingActionButton(
              heroTag: heroTag,
              shape: const CircleBorder(),
              elevation: 2,
              backgroundColor: theme.colorScheme.secondaryContainer,
              foregroundColor: theme.colorScheme.onSecondaryContainer,
              onPressed: onPressed,
              child: Icon(icon, size: 26),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.labelLarge),
        ],
      ),
    );
  }
}

/// Aufnahmeleiste für Übersicht und Belegliste (DESIGN_SPEC 5a, Regel 13;
/// Entscheidung Auftraggeberin 2026-10-16): in der Mitte groß „Beleg“
/// (Kamera/Scanner), links „Foto“ (Galerie), rechts „Datei“ (PDF,
/// E-Rechnung, Bild). Spiegelgleich, damit linke und rechte Hand gleich weit
/// greifen; zwischen den Kreisen je [gap] dp, damit kein Nachbar getroffen
/// wird. Jeder Knopf öffnet ein neues Belegformular mit den Seiten.
class CaptureBar extends StatelessWidget {
  const CaptureBar({
    super.key,
    required this.onCamera,
    required this.onPhoto,
    required this.onFile,
    required this.cameraKey,
    this.keyPrefix = 'capture',
  });

  /// Schlüssel des Hauptknopfs (bestehende Tests und Gerätetests).
  final Key cameraKey;

  /// Abstand zwischen den Kreisen (≥ 48 dp, `touch.capture_gap`).
  static const double gap = 48;

  final VoidCallback onCamera;
  final VoidCallback onPhoto;
  final VoidCallback onFile;

  /// Präfix für Schlüssel und Hero-Tags, je Bildschirm eindeutig.
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: SecondaryCaptureButton.diameter,
          child: SecondaryCaptureButton(
            key: Key('$keyPrefix-gallery'),
            heroTag: '$keyPrefix-gallery',
            icon: Icons.photo_library_outlined,
            label: 'Foto',
            semanticLabel: 'Foto aus der Galerie als Beleg',
            onPressed: onPhoto,
          ),
        ),
        const SizedBox(width: gap),
        SizedBox(
          width: CaptureButton.diameter,
          child: CaptureButton(
            key: cameraKey,
            heroTag: '$keyPrefix-camera',
            onPressed: onCamera,
          ),
        ),
        const SizedBox(width: gap),
        SizedBox(
          width: SecondaryCaptureButton.diameter,
          child: SecondaryCaptureButton(
            key: Key('$keyPrefix-file'),
            heroTag: '$keyPrefix-file',
            icon: Icons.upload_file_outlined,
            label: 'Datei',
            semanticLabel: 'Datei als Beleg wählen, PDF oder E-Rechnung',
            onPressed: onFile,
          ),
        ),
      ],
    );
  }
}
