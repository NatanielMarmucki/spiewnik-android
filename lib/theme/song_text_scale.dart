import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_text_theme.dart';

/// Skala tekstu pieśni z docs/DESIGN-SYSTEM.md, sekcja 2.
///
/// Wszystko liczy się z [size] (w dokumencie `S`), czyli rozmiaru ustawionego suwakiem.
/// Interlinia zostaje mnożnikiem, więc [lineHeightMultiplier] jest osobną wartością
/// z ustawień (zakres 1,4–1,8, domyślnie 1,62).
///
/// Klasa liczy tylko wymiary. Systemowe powiększenie czcionki nakłada się na to osobno,
/// przez `textScaler`, nigdy zamiast tego (reguła 5 z sekcji 7 dokumentu).
@immutable
class SongTextScale {
  /// Najmniejszy i największy rozmiar z suwaka.
  static const double minSize = 10.0;
  static const double maxSize = 30.0;
  static const double defaultSize = 19.0;

  /// Zakres mnożnika interlinii.
  static const double minLineHeight = 1.4;
  static const double maxLineHeight = 1.8;
  static const double defaultLineHeight = 1.62;

  /// Margines boczny kolumny tekstu: stały, niezależny od [size].
  static const double sideMargin = 22.0;

  static const double _blockGapRatio = 1.26;
  static const double _refrainIndentRatio = 0.74;
  static const double _initialRatio = 2.16;
  static const double _verseNumberRatio = 0.74;
  static const double _maxColumnWidthRatio = 34.0;

  /// Rozmiar tekstu pieśni w dp.
  final double size;

  /// Mnożnik interlinii.
  final double lineHeightMultiplier;

  const SongTextScale({this.size = defaultSize, this.lineHeightMultiplier = defaultLineHeight});

  /// Wysokość wiersza w dp.
  double get lineHeight => lineHeightMultiplier * size;

  /// Odstęp między blokami (zwrotkami), zamiast pustych wierszy.
  double get blockGap => _blockGapRatio * size;

  /// Wcięcie refrenu.
  double get refrainIndent => _refrainIndentRatio * size;

  /// Inicjał pierwszej zwrotki.
  double get initialSize => _initialRatio * size;

  /// Cyfra kolejnej zwrotki.
  double get verseNumberSize => _verseNumberRatio * size;

  /// Maksymalna szerokość kolumny tekstu.
  double get maxColumnWidth => _maxColumnWidthRatio * size;

  /// Styl tekstu pieśni: Newsreader w rozmiarze [size] z interlinią [lineHeightMultiplier].
  TextStyle textStyle({Color? color}) {
    return TextStyle(
      fontFamily: AppFonts.serif,
      fontSize: size,
      height: lineHeightMultiplier,
      fontWeight: FontWeight.w400,
      color: color,
    );
  }

  /// Skala z wartości zapisanych w ustawieniach, przyciętych do zakresów.
  factory SongTextScale.fromSettings({required double size, required double lineHeight}) {
    return SongTextScale(
      size: size.clamp(minSize, maxSize),
      lineHeightMultiplier: lineHeight.clamp(minLineHeight, maxLineHeight),
    );
  }
}
