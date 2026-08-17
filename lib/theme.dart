import 'package:flutter/material.dart';

/// Farbwelt der App. Ein ruhiges Blau als Grundton – Buchhaltung soll nicht
/// aufregend aussehen, sondern verlässlich.
class AppTheme {
  AppTheme._();

  static const seed = Color(0xFF1B4965);

  /// Grün für Einnahmen, Rot für Ausgaben. Zusätzlich zur Farbe steht überall
  /// ein Vorzeichen oder ein Icon – Farbe allein wäre für farbenblinde Nutzer
  /// keine Information.
  static const income = Color(0xFF1B7F5A);
  static const expense = Color(0xFFB3261E);
  static const warning = Color(0xFFB26A00);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
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
