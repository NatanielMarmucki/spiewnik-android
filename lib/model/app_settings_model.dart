import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/view/screen_wake_lock.dart';

/// Ustawienia aplikacji spoza czytania: motyw i blokada wygaszania ekranu.
///
/// Trzymane osobno od [FontSizeModel], bo „Przywróć ustawienia domyślne” dotyczy **tylko**
/// rozmiaru tekstu i interlinii — motyw i blokada ekranu mają z niego wyjść nietknięte.
///
/// Klucze są nowe (`themeMode`, `keepScreenOn`), więc nic nie nadpisują na urządzeniach
/// użytkowników. Brak klucza oznacza wartość domyślną: motyw systemowy i blokada włączona,
/// czyli dotychczasowe zachowanie aplikacji.
class AppSettingsModel with ChangeNotifier {
  static const String themeModeKey = 'themeMode';
  static const String keepScreenOnKey = 'keepScreenOn';

  static const ThemeMode defaultThemeMode = ThemeMode.system;
  static const bool defaultKeepScreenOn = true;

  ThemeMode _themeMode = defaultThemeMode;
  bool _keepScreenOn = defaultKeepScreenOn;

  /// Kończy się, gdy ustawienia są wczytane. Przydatne w testach.
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
    // Działa od razu, także gdy ustawienia otwarto z otwartej pieśni.
    ScreenWakeLock.enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keepScreenOnKey, value);
  }

  /// Nieznana albo brakująca nazwa daje motyw systemowy zamiast wyjątku.
  static ThemeMode _themeModeFromName(String? name) {
    return ThemeMode.values.firstWhere((mode) => mode.name == name, orElse: () => defaultThemeMode);
  }
}
