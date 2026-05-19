// ThemeController — manages dark/light/system theme mode.
// Persists preference to Hive so it survives app restarts.

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class ThemeController extends ChangeNotifier {
  static const String _key = 'themeMode';
  final Box _box = Hive.box('app_settings');

  ThemeController() {
    _load();
  }

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  void _load() {
    final stored = _box.get(_key, defaultValue: 'system') as String;
    _themeMode = _parseMode(stored);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _box.put(_key, mode.name);
    notifyListeners();
  }

  /// Cycle: system → light → dark → system
  Future<void> toggleTheme() async {
    switch (_themeMode) {
      case ThemeMode.system:
        await setThemeMode(ThemeMode.light);
        break;
      case ThemeMode.light:
        await setThemeMode(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        await setThemeMode(ThemeMode.system);
        break;
    }
  }

  bool get isDark => _themeMode == ThemeMode.dark;
  bool get isLight => _themeMode == ThemeMode.light;
  bool get isSystem => _themeMode == ThemeMode.system;

  String get label {
    switch (_themeMode) {
      case ThemeMode.system: return 'System';
      case ThemeMode.light:  return 'Light';
      case ThemeMode.dark:   return 'Dark';
    }
  }

  IconData get icon {
    switch (_themeMode) {
      case ThemeMode.system: return Icons.brightness_auto;
      case ThemeMode.light:  return Icons.light_mode;
      case ThemeMode.dark:   return Icons.dark_mode;
    }
  }

  static ThemeMode _parseMode(String s) {
    switch (s) {
      case 'light':  return ThemeMode.light;
      case 'dark':   return ThemeMode.dark;
      default:       return ThemeMode.system;
    }
  }
}
