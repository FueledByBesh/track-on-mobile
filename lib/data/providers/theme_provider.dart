import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ui/theme/app_theme.dart';

/// Persisted user preference for theme mode + accent color.
/// MaterialApp watches this via Consumer/context.watch; every other
/// widget reads Theme.of(context) which rebuilds automatically when
/// ThemeProvider changes.
class ThemeProvider extends ChangeNotifier {
  static const _keyMode = 'theme_mode';
  static const _keyAccent = 'accent_color';

  ThemeMode _mode = ThemeMode.system;
  Color _accent = AppTheme.defaultAccent;

  ThemeMode get mode => _mode;
  Color get accent => _accent;

  ThemeData get lightTheme => AppTheme.light(_accent);
  ThemeData get darkTheme => AppTheme.dark(_accent);

  /// Load persisted preferences. Call once before runApp so the first
  /// frame renders with the right theme (no flash of wrong colors).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString(_keyMode);
    if (modeStr != null) {
      _mode = _parseMode(modeStr);
    }
    final accentValue = prefs.getInt(_keyAccent);
    if (accentValue != null) {
      _accent = Color(accentValue);
    }
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMode, _modeToString(mode));
  }

  Future<void> setAccent(Color color) async {
    if (_accent.value == color.value) return;
    _accent = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAccent, color.value);
  }

  static ThemeMode _parseMode(String s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _modeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
