import 'package:flutter/material.dart';

class FontSizeModel with ChangeNotifier {
  double _fontSize = 16.0;
  double _lineHeight = 1.5;

  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;

  void setFontSize(double newSize) {
    _fontSize = newSize;
    notifyListeners();
  }

  void setLineHeight(double newHeight) {
    _lineHeight = newHeight;
    notifyListeners();
  }

  void resetToDefaults() {
    _fontSize = 16.0;
    _lineHeight = 1.5;
    notifyListeners();
  }
}