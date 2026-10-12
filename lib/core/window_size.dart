/// Breitenklassen nach Material 3 („window size classes“).
///
/// Einzige Stelle, an der die Schwellen stehen. Widgets fragen
/// [WindowSizeClass.of] bzw. [WindowSizeClass.fromWidth] und vergleichen nie
/// selbst mit Pixelzahlen. Quelle: Material Design 3, „Applying layout –
/// Window size classes“ (m3.material.io/foundations/layout/applying-layout/
/// window-size-classes); Vorgabe DESIGN_SPEC D-5, Spezifikation 5.7.
library;

import 'package:flutter/widgets.dart';

enum WindowSizeClass {
  /// Telefon hochkant: unter [mediumMinWidth] dp.
  compact,

  /// Kleines Tablet hochkant, Telefon quer, geteilter Bildschirm.
  medium,

  /// Tablet quer, großes Tablet: ab [expandedMinWidth] dp.
  expanded;

  /// Untergrenze von medium in dp (Material 3).
  static const double mediumMinWidth = 600;

  /// Untergrenze von expanded in dp (Material 3).
  static const double expandedMinWidth = 840;

  /// Größte Breite für Formulare und Lesetext in dp (DESIGN_SPEC D-5:
  /// „ca. 640 dp, lesbare Zeilenlänge“).
  static const double maxContentWidth = 640;

  static WindowSizeClass fromWidth(double width) {
    if (width >= expandedMinWidth) return expanded;
    if (width >= mediumMinWidth) return medium;
    return compact;
  }

  /// Klasse des aktuellen Fensters (nicht des Bildschirms: im geteilten
  /// Bildschirm zählt die Fensterbreite).
  static WindowSizeClass of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  bool get isCompact => this == compact;
  bool get isExpanded => this == expanded;
}
