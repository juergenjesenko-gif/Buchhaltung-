import 'package:flutter/material.dart';

/// Farbwelt der App: Markenfarben Marineblau #0B3A67 und Hellblau #EAF2FF
/// (endgültiges Logo 2026-10-19, DESIGN_SPEC 2). Kontrast WCAG AA:
/// Weiß auf Marineblau 11,6 : 1, Marineblau auf Hellblau 10,3 : 1.
class AppTheme {
  AppTheme._();

  static const seed = Color(0xFF0B3A67);

  /// Hellblau als Akzentfläche (Container) im hellen Modus.
  static const accentLight = Color(0xFFEAF2FF);

  /// Grün für Einnahmen, Rot für Ausgaben. Zusätzlich zur Farbe steht überall
  /// ein Vorzeichen oder ein Icon – Farbe allein wäre für farbenblinde Nutzer
  /// keine Information.
  static const income = Color(0xFF1B7F5A);
  static const expense = Color(0xFFB3261E);
  static const warning = Color(0xFFB26A00);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final base = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    // Hell: Marineblau exakt als Primärfarbe, Hellblau als Container.
    // Dunkel: die hellen Töne aus dem Seed, damit Text lesbar bleibt.
    final scheme = brightness == Brightness.light
        ? base.copyWith(
            primary: seed,
            onPrimary: Colors.white,
            primaryContainer: accentLight,
            onPrimaryContainer: seed,
          )
        : base;
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  /// Farbe für einen Betrag – Einnahme oder Ausgabe.
  static Color amountColor(bool isIncome, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isIncome) return isDark ? const Color(0xFF4CC38A) : income;
    return isDark ? const Color(0xFFF2827A) : expense;
  }
}
