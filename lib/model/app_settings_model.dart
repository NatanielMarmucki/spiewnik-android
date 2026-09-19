import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/view/screen_wake_lock.dart';

/// App settings outside reading: theme and keep-screen-on (wakelock).
///
/// Kept separate from [FontSizeModel], because „Przywróć ustawienia domyślne” (restore defaults)
/// applies **only** to text size and line height — theme and keep-screen-on must come out of it untouched.
///
/// The keys are new (`themeMode`, `keepScreenOn`), so they overwrite nothing on users' devices.
/// A missing key means the default value: system theme and keep-screen-on enabled,
/// which is how the app has behaved so far.
class AppSettingsModel with ChangeNotifier {
  static const String themeModeKey = 'themeMode';
  static const String keepScreenOnKey = 'keepScreenOn';

  static const ThemeMode defaultThemeMode = ThemeMode.system;
  static const bool defaultKeepScreenOn = true;

  ThemeMode _themeMode = defaultThemeMode;
  bool _keepScreenOn = defaultKeepScreenOn;

  /// Completes when the settings are loaded. Useful in tests.
  late final Future<void> loaded;

  ThemeMode get themeMode => _themeMode;
  bool get keepScreenOn => _keepScreenOn;

  AppSettingsModel() {
    loaded = _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = _themeModeFromName(prefs.getString(themeModeKey));
    _keepScreenOn = prefs.getBool(keepScreenOnKey) ?? defaultKeepScreenOn;
    ScreenWakeLock.enabled = _keepScreenOn;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(themeModeKey, mode.name);
  }

  Future<void> setKeepScreenOn(bool value) async {
    _keepScreenOn = value;
    // Takes effect right away, also when the settings were opened from an open song.
    ScreenWakeLock.enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keepScreenOnKey, value);
  }

  /// An unknown or missing name gives the system theme instead of an exception.
  static ThemeMode _themeModeFromName(String? name) {
    return ThemeMode.values.firstWhere((mode) => mode.name == name, orElse: () => defaultThemeMode);
  }
}
