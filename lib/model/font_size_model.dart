import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/theme/song_text_scale.dart';

/// Rozmiar tekstu pieśni i interlinia, trzymane w SharedPreferences.
///
/// Zakresy i domyślne pochodzą z [SongTextScale] (docs/DESIGN-SYSTEM.md, sekcja 2).
/// Domyślne obowiązują **tylko przy pierwszej instalacji**: zapisane wartości zostają,
/// a te spoza zakresu są przycinane, nigdy resetowane. Dzięki temu użytkownik, który miał
/// 16 i 1,5, zachowuje swoje ustawienia, a ten, który miał interlinię 2,4, dostaje 1,8.
class FontSizeModel with ChangeNotifier {
  static const String fontSizeKey = 'fontSize';
  static const String lineHeightKey = 'lineHeight';

  static const double minFontSize = SongTextScale.minSize;
  static const double maxFontSize = SongTextScale.maxSize;
  static const double defaultFontSize = SongTextScale.defaultSize;

  static const double minLineHeight = SongTextScale.minLineHeight;
  static const double maxLineHeight = SongTextScale.maxLineHeight;
  static const double defaultLineHeight = SongTextScale.defaultLineHeight;

  double _fontSize = defaultFontSize;
  double _lineHeight = defaultLineHeight;

  /// Kończy się, gdy ustawienia są wczytane. Przydatne w testach.
  late final Future<void> loaded;

  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;

  /// Skala tekstu pieśni dla obecnych ustawień.
  SongTextScale get songTextScale => SongTextScale(size: _fontSize, lineHeightMultiplier: _lineHeight);

  FontSizeModel() {
    loaded = _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final storedFontSize = prefs.getDouble(fontSizeKey);
    final storedLineHeight = prefs.getDouble(lineHeightKey);

    _fontSize = storedFontSize == null ? defaultFontSize : storedFontSize.clamp(minFontSize, maxFontSize);
    _lineHeight = storedLineHeight == null ? defaultLineHeight : storedLineHeight.clamp(minLineHeight, maxLineHeight);

    // Zapisane wartości spoza zakresu zostają przycięte także na dysku, żeby stan w pamięci
    // i w ustawieniach się nie rozjeżdżał. Brakujący klucz zostaje brakującym.
    if (storedFontSize != null && storedFontSize != _fontSize) {
      await prefs.setDouble(fontSizeKey, _fontSize);
    }
    if (storedLineHeight != null && storedLineHeight != _lineHeight) {
      await prefs.setDouble(lineHeightKey, _lineHeight);
    }

    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(fontSizeKey, _fontSize);
    await prefs.setDouble(lineHeightKey, _lineHeight);
  }

  void setFontSize(double newSize) {
    _fontSize = newSize.clamp(minFontSize, maxFontSize);
    _saveSettings();
    notifyListeners();
  }

  void setLineHeight(double newHeight) {
    _lineHeight = newHeight.clamp(minLineHeight, maxLineHeight);
    _saveSettings();
    notifyListeners();
  }

  void resetToDefaults() {
    _fontSize = defaultFontSize;
    _lineHeight = defaultLineHeight;
    _saveSettings();
    notifyListeners();
  }
}
