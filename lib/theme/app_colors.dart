import 'package:flutter/material.dart';

/// Kolory z docs/DESIGN-SYSTEM.md, dla których Material nie ma własnej roli.
///
/// Widoki biorą je przez `Theme.of(context).extension<AppColors>()!` albo krócej,
/// przez [AppColorsContext.appColors]. W widokach nie wolno pisać literałów kolorów
/// ani sprawdzać jasności motywu (reguła 4 z sekcji 7 dokumentu).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  /// Szafran: inicjał, wersaliki, znaki powtórzenia, aktywna zakładka.
  final Color accent;

  /// Tekst i ikony leżące na [accent].
  final Color onAccent;

  /// Akcja niszcząca (usuwanie).
  final Color destructive;

  /// Serce ulubionej pieśni.
  final Color favorite;

  /// Hairline 1 dp.
  final Color line;

  /// Linia wiodąca z kropek w wierszu listy.
  final Color indexDots;

  /// Tło wiersza w reakcji na dotknięcie.
  final Color pressedSurface;

  /// Tekst drugiego planu: numer pieśni, opisy.
  final Color textSecondary;

  /// Tekst trzeciego planu: nieaktywna zakładka.
  final Color textTertiary;

  const AppColors({
    required this.accent,
    required this.onAccent,
    required this.destructive,
    required this.favorite,
    required this.line,
    required this.indexDots,
    required this.pressedSurface,
    required this.textSecondary,
    required this.textTertiary,
  });

  /// Motyw ciemny, wobec tła #191A1D.
  static const AppColors dark = AppColors(
    accent: Color(0xFFE2B872),
    onAccent: Color(0xFF191A1D),
    destructive: Color(0xFFF29186),
    favorite: Color(0xFFE39AAF),
    line: Color(0xFF2E3138),
    indexDots: Color(0xFF45494F),
    pressedSurface: Color(0xFF212328),
    textSecondary: Color(0xFFA8A29B),
    textTertiary: Color(0xFF938F87),
  );

  /// Motyw jasny, wobec tła #F7F4EE.
  static const AppColors light = AppColors(
    accent: Color(0xFF1B7A18), // TYMCZASOWO: zielony zamiast szafranu, test CI
    onAccent: Color(0xFFFFFDF8),
    destructive: Color(0xFFA3231B),
    favorite: Color(0xFF8C2F4F),
    line: Color(0xFFE2DCD1),
    indexDots: Color(0xFFC9C2B5),
    pressedSurface: Color(0xFFEFEAE0),
    textSecondary: Color(0xFF5C5852),
    textTertiary: Color(0xFF6E6A62),
  );

  @override
  AppColors copyWith({
    Color? accent,
    Color? onAccent,
    Color? destructive,
    Color? favorite,
    Color? line,
    Color? indexDots,
    Color? pressedSurface,
    Color? textSecondary,
    Color? textTertiary,
  }) {
    return AppColors(
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      destructive: destructive ?? this.destructive,
      favorite: favorite ?? this.favorite,
      line: line ?? this.line,
      indexDots: indexDots ?? this.indexDots,
      pressedSurface: pressedSurface ?? this.pressedSurface,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
    );
  }

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) {
      return this;
    }
    return AppColors(
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      favorite: Color.lerp(favorite, other.favorite, t)!,
      line: Color.lerp(line, other.line, t)!,
      indexDots: Color.lerp(indexDots, other.indexDots, t)!,
      pressedSurface: Color.lerp(pressedSurface, other.pressedSurface, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  /// Skrót do kolorów spoza ColorScheme.
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
