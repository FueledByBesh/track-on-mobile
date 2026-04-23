import 'package:flutter/material.dart';

/// Centralized theme builder. Generates Material 3 ThemeData from a
/// single accent color for both light and dark modes. All semantic
/// colors (surface, onSurface, outline, error, etc.) are derived
/// automatically via ColorScheme.fromSeed.
class AppTheme {
  AppTheme._();

  static const defaultAccent = Color(0xFF6B5FFF);

  /// Predefined accent choices for the settings picker.
  static const accentOptions = <Color>[
    Color(0xFF6B5FFF), // Purple (default)
    Color(0xFF2196F3), // Blue
    Color(0xFF009688), // Teal
    Color(0xFF4CAF50), // Green
    Color(0xFFFF9800), // Orange
    Color(0xFFF44336), // Red
    Color(0xFFE91E63), // Pink
  ];

  static const accentLabels = <String>[
    'Purple',
    'Blue',
    'Teal',
    'Green',
    'Orange',
    'Red',
    'Pink',
  ];

  static ThemeData light(Color accent) {
    // fromSeed derives surfaces/outlines/errors from the accent, but
    // mangles the primary into a tone-40 version that looks nothing like
    // the original (orange → brown, red → brick). Override primary +
    // onPrimary so the user gets the exact color they picked.
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
    ).copyWith(
      primary: accent,
      onPrimary: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFFAFBFC),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFFAFBFC),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        thickness: 0.5,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: scheme.primary,
        unselectedItemColor: Colors.grey,
        elevation: 0,
      ),
    );
  }

  static ThemeData dark(Color accent) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: const Color(0xFF1C1C1E),
      onSurface: const Color(0xFFE5E5EA),
    ).copyWith(
      primary: accent,
      onPrimary: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF1C1C1E),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF2C2C2E),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade700),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade700,
        thickness: 0.5,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: scheme.primary,
        unselectedItemColor: Colors.grey.shade500,
        elevation: 0,
      ),
    );
  }
}
