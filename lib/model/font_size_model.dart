import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/theme/song_text_scale.dart';

/// Song text size and line height, kept in SharedPreferences.
///
/// Ranges and defaults come from [SongTextScale] (docs/DESIGN-SYSTEM.md, section 2).
/// The defaults apply **only on first install**: saved values stay, and those out of range
/// are clamped, never reset. So a user who had 16 and 1.5 keeps their settings, and one who
/// had a line height of 2.4 gets 1.8.
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

  /// Completes when the settings are loaded. Useful in tests.
  late final Future<void> loaded;

  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;

  /// Song text scale for the current settings.
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

    // Saved values out of range are clamped on disk too, so the state in memory and in the
    // settings does not drift apart. A missing key stays missing.
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
