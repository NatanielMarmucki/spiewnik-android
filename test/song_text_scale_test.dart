import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/theme/app_text_theme.dart';
import 'package:spiewnik/theme/song_text_scale.dart';

/// Wartości z tabeli „Skala pieśni — proporcje od S” w docs/DESIGN-SYSTEM.md.
void main() {
  group('proporcje od S', () {
    test('S = 10 (najmniejszy rozmiar z suwaka)', () {
      const scale = SongTextScale(size: 10.0);

      expect(scale.lineHeight, closeTo(16.2, 0.001));
      expect(scale.blockGap, closeTo(12.6, 0.001));
      expect(scale.refrainIndent, closeTo(7.4, 0.001));
      expect(scale.initialSize, closeTo(21.6, 0.001));
      expect(scale.verseNumberSize, closeTo(7.4, 0.001));
      expect(scale.maxColumnWidth, closeTo(340.0, 0.001));
      expect(SongTextScale.sideMargin, 22.0);
    });

    test('S = 19 (domyślny rozmiar, wartości z dokumentu)', () {
      const scale = SongTextScale(size: 19.0);

      expect(scale.lineHeight, closeTo(30.78, 0.001)); // dokument: 30,8
      expect(scale.blockGap, closeTo(23.94, 0.001)); // dokument: 24
      expect(scale.refrainIndent, closeTo(14.06, 0.001)); // dokument: 14
      expect(scale.initialSize, closeTo(41.04, 0.001)); // dokument: 41
      expect(scale.verseNumberSize, closeTo(14.06, 0.001)); // dokument: 14
      expect(scale.maxColumnWidth, closeTo(646.0, 0.001));
    });

    test('S = 30 (największy rozmiar z suwaka)', () {
      const scale = SongTextScale(size: 30.0);

      expect(scale.lineHeight, closeTo(48.6, 0.001));
      expect(scale.blockGap, closeTo(37.8, 0.001));
      expect(scale.refrainIndent, closeTo(22.2, 0.001));
      expect(scale.initialSize, closeTo(64.8, 0.001));
      expect(scale.verseNumberSize, closeTo(22.2, 0.001));
      expect(scale.maxColumnWidth, closeTo(1020.0, 0.001));
    });
  });

  group('interlinia', () {
    test('domyślny mnożnik to 1,62', () {
      expect(const SongTextScale().lineHeightMultiplier, 1.62);
      expect(const SongTextScale().size, 19.0);
    });

    test('inny mnożnik zmienia tylko wysokość wiersza', () {
      const scale = SongTextScale(size: 19.0, lineHeightMultiplier: 1.4);

      expect(scale.lineHeight, closeTo(26.6, 0.001));
      expect(scale.blockGap, closeTo(23.94, 0.001));
    });
  });

  group('fromSettings', () {
    test('przycina rozmiar i interlinię do zakresów', () {
      final small = SongTextScale.fromSettings(size: 4.0, lineHeight: 1.0);
      final big = SongTextScale.fromSettings(size: 44.0, lineHeight: 3.0);

      expect(small.size, 10.0);
      expect(small.lineHeightMultiplier, 1.4);
      expect(big.size, 30.0);
      expect(big.lineHeightMultiplier, 1.8);
    });

    test('wartości w zakresie zostają bez zmian', () {
      final scale = SongTextScale.fromSettings(size: 22.0, lineHeight: 1.7);

      expect(scale.size, 22.0);
      expect(scale.lineHeightMultiplier, 1.7);
    });
  });

  test('styl tekstu używa Newsreadera i mnożnika interlinii', () {
    final style = const SongTextScale(size: 19.0).textStyle();

    expect(style.fontFamily, AppFonts.serif);
    expect(style.fontSize, 19.0);
    expect(style.height, 1.62);
    expect(style.fontWeight, FontWeight.w400);
  });
}
