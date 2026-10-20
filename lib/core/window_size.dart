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

  /// Fensterhöhe in dp, unter der die Höhe „compact“ ist (Material 3:
  /// Telefon quer). Dann gibt es höchstens medium – keine ausgeklappte
  /// Navigation und kein Liste-Detail, sonst zerfällt der Bildschirm in
  /// drei schmale Spalten (Gerätetest 2026-10-20).
  static const double compactMaxHeight = 480;

  static WindowSizeClass fromWidth(double width) {
    if (width >= expandedMinWidth) return expanded;
    if (width >= mediumMinWidth) return medium;
    return compact;
  }

  /// Klasse des aktuellen Fensters (nicht des Bildschirms: im geteilten
  /// Bildschirm zählt die Fensterbreite).
  static WindowSizeClass of(BuildContext context) =>
      fromSize(MediaQuery.sizeOf(context));

  /// Wie [fromWidth], bei niedriger Höhe aber höchstens medium.
  static WindowSizeClass fromSize(Size size) {
    final byWidth = fromWidth(size.width);
    if (byWidth == expanded && size.height < compactMaxHeight) return medium;
    return byWidth;
  }

  bool get isCompact => this == compact;
  bool get isExpanded => this == expanded;
}
