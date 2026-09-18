import 'package:flutter/material.dart';

/// Rodziny krojów z assets (patrz pubspec.yaml i tools/build_fonts.py).
class AppFonts {
  /// Newsreader: tekst pieśni, tytuły, numery.
  static const String serif = 'Newsreader';

  /// Schibsted Grotesk: interfejs, etykiety, przyciski, nawigacja.
  static const String ui = 'SchibstedGrotesk';

  const AppFonts._();
}

/// Cyfry tabelaryczne: numery pieśni mają trzymać kolumnę.
const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];

/// Skala interfejsu z docs/DESIGN-SYSTEM.md, sekcja 2, przypisana do ról Material.
///
/// | rola w dokumencie | slot TextTheme |
/// |---|---|
/// | tytuł ekranu 20 / 1,05 Newsreader | titleLarge |
/// | tytuł pieśni na liście 17 / 1,2 Newsreader | titleMedium |
/// | numer na liście 15 / 1 Newsreader, tabelarycznie | titleSmall |
/// | tytuł dialogu 19 / 1,3 Grotesk 500 | headlineSmall |
/// | treść dialogu, arkusz, stan pusty 15 / 1,5 Grotesk 400 | bodyMedium |
/// | przycisk tekstowy 15 / 1,2 Grotesk 600 | labelLarge |
/// | etykieta zakładki 10,5 / 1 Grotesk 500 | labelSmall |
/// | wersalik sekcji 8,5 + odstęp liter 0,26 em Grotesk 500 | labelMedium |
TextTheme buildAppTextTheme(ColorScheme scheme) {
  final onSurface = scheme.onSurface;
  final onSurfaceVariant = scheme.onSurfaceVariant;

  return TextTheme(
    titleLarge: TextStyle(
      fontFamily: AppFonts.serif,
      fontSize: 20.0,
      height: 1.05,
      fontWeight: FontWeight.w400,
      color: onSurface,
    ),
    titleMedium: TextStyle(
      fontFamily: AppFonts.serif,
      fontSize: 17.0,
      height: 1.2,
      fontWeight: FontWeight.w400,
      color: onSurface,
    ),
    titleSmall: TextStyle(
      fontFamily: AppFonts.serif,
      fontSize: 15.0,
      height: 1.0,
      fontWeight: FontWeight.w400,
      fontFeatures: tabularFigures,
      color: onSurfaceVariant,
    ),
    headlineSmall: TextStyle(
      fontFamily: AppFonts.ui,
      fontSize: 19.0,
      height: 1.3,
      fontWeight: FontWeight.w500,
      color: onSurface,
    ),
    bodyLarge: TextStyle(
      fontFamily: AppFonts.serif,
      fontSize: 17.0,
      height: 1.62,
      fontWeight: FontWeight.w400,
      color: onSurface,
    ),
    bodyMedium: TextStyle(
      fontFamily: AppFonts.ui,
      fontSize: 15.0,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: onSurface,
    ),
    bodySmall: TextStyle(
      fontFamily: AppFonts.ui,
      fontSize: 13.0,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: onSurfaceVariant,
    ),
    labelLarge: TextStyle(
      fontFamily: AppFonts.ui,
      fontSize: 15.0,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: onSurface,
    ),
    labelMedium: TextStyle(
      fontFamily: AppFonts.ui,
      fontSize: 8.5,
      height: 1.0,
      fontWeight: FontWeight.w500,
      letterSpacing: 8.5 * 0.26, // 0,26 em
      color: onSurfaceVariant,
    ),
    labelSmall: TextStyle(
      fontFamily: AppFonts.ui,
      fontSize: 10.5,
      height: 1.0,
      fontWeight: FontWeight.w500,
      color: onSurfaceVariant,
    ),
  );
}
