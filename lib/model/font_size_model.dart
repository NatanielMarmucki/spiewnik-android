import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FontSizeModel with ChangeNotifier {
  static const String _fontSizeKey = 'fontSize';
  static const String _lineHeightKey = 'lineHeight';

  double _fontSize = 16.0;
  double _lineHeight = 1.5;

  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;

  FontSizeModel() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _fontSize = prefs.getDouble(_fontSizeKey) ?? 16.0;
    _lineHeight = prefs.getDouble(_lineHeightKey) ?? 1.5;
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, _fontSize);
    await prefs.setDouble(_lineHeightKey, _lineHeight);
  }

  void setFontSize(double newSize) {
    _fontSize = newSize;
    _saveSettings();
    notifyListeners();
  }

  void setLineHeight(double newHeight) {
    _lineHeight = newHeight;
    _saveSettings();
    notifyListeners();
  }

  void resetToDefaults() {
    _fontSize = 16.0;
    _lineHeight = 1.5;
    _saveSettings();
    notifyListeners();
  }
}