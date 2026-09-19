import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_text_theme.dart';

/// Song text scale from docs/DESIGN-SYSTEM.md, section 2.
///
/// Everything is computed from [size] (`S` in the document), the size set with the slider.
/// Line height stays a multiplier, so [lineHeightMultiplier] is a separate value
/// from the settings (range 1.4–1.8, default 1.62).
///
/// The class only computes dimensions. System font scaling is applied on top of this separately,
/// through `textScaler`, never instead of it (rule 5 from section 7 of the document).
@immutable
class SongTextScale {
  /// Smallest and largest size on the slider.
  static const double minSize = 10.0;
  static const double maxSize = 30.0;
  static const double defaultSize = 19.0;

  /// Range of the line height multiplier.
  static const double minLineHeight = 1.4;
  static const double maxLineHeight = 1.8;
  static const double defaultLineHeight = 1.62;

  /// Side margin of the text column: fixed, independent of [size].
  static const double sideMargin = 22.0;

  static const double _blockGapRatio = 1.26;
  static const double _refrainIndentRatio = 0.74;
  static const double _initialRatio = 2.16;
  static const double _verseNumberRatio = 0.74;
  static const double _maxColumnWidthRatio = 34.0;
  static const double _verseRuleRatio = 1.5;

  /// Song text size in dp.
  final double size;

  /// Line height multiplier.
  final double lineHeightMultiplier;

  const SongTextScale({this.size = defaultSize, this.lineHeightMultiplier = defaultLineHeight});

  /// Line height in dp.
  double get lineHeight => lineHeightMultiplier * size;

  /// Gap between blocks (verses), instead of empty lines.
  double get blockGap => _blockGapRatio * size;

  /// Chorus indent.
  double get refrainIndent => _refrainIndentRatio * size;

  /// Drop cap of the first verse.
  double get initialSize => _initialRatio * size;

  /// Number of each following verse.
  double get verseNumberSize => _verseNumberRatio * size;

  /// Maximum width of the text column.
  double get maxColumnWidth => _maxColumnWidthRatio * size;

  /// Length of the rule next to the verse number and the chorus uppercase label.
  double get verseRuleWidth => _verseRuleRatio * size;

  /// Song text style: Newsreader at [size] with line height [lineHeightMultiplier].
  TextStyle textStyle({Color? color}) {
    return TextStyle(
      fontFamily: AppFonts.serif,
      fontSize: size,
      height: lineHeightMultiplier,
      fontWeight: FontWeight.w400,
      color: color,
    );
  }

  /// Scale from the values saved in the settings, clamped to the ranges.
  factory SongTextScale.fromSettings({required double size, required double lineHeight}) {
    return SongTextScale(
      size: size.clamp(minSize, maxSize),
      lineHeightMultiplier: lineHeight.clamp(minLineHeight, maxLineHeight),
    );
  }
}
