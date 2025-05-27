import 'package:flutter/material.dart';
import '../utils/theme_utils.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode;

  ThemeProvider(this._themeMode);

  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(ThemeMode themeMode) async {
    if (_themeMode == themeMode) return;
    
    _themeMode = themeMode;
    await ThemeUtils.saveThemeMode(themeMode);
    notifyListeners();
  }

  Future<void> toggleThemeMode() async {
    ThemeMode newThemeMode;
    
    switch (_themeMode) {
      case ThemeMode.light:
        newThemeMode = ThemeMode.dark;
        break;
      case ThemeMode.dark:
        newThemeMode = ThemeMode.system;
        break;
      case ThemeMode.system:
      default:
        newThemeMode = ThemeMode.light;
        break;
    }
    
    await setThemeMode(newThemeMode);
  }

  String getThemeModeText() {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
      default:
        return 'System';
    }
  }

  IconData getThemeModeIcon() {
    switch (_themeMode) {
      case ThemeMode.light:
        return Icons.wb_sunny_outlined;
      case ThemeMode.dark:
        return Icons.nightlight_round;
      case ThemeMode.system:
        return Icons.settings_brightness;
      default:
        return Icons.settings_brightness;
    }
  }
}
