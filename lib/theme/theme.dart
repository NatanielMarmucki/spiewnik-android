import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_colors.dart';

/// Motywy zbudowane z tokenów z docs/DESIGN-SYSTEM.md (sekcje 1 i 2).
///
/// Kolory spoza ról Material siedzą w [AppColors] i wchodzą do motywu jako rozszerzenie.

const ColorScheme _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFE2B872), // akcent — szafran
  onPrimary: Color(0xFF191A1D),
  secondary: Color(0xFFE2B872),
  onSecondary: Color(0xFF191A1D),
  error: Color(0xFFF29186), // niszczący
  onError: Color(0xFF191A1D),
  surface: Color(0xFF191A1D), // tło ekranów, paska i nawigacji
  onSurface: Color(0xFFF4EFE6), // tekst — ciepła biel
  onSurfaceVariant: Color(0xFFA8A29B), // tekst drugi
  surfaceContainerLowest: Color(0xFF191A1D),
  surfaceContainerLow: Color(0xFF1D1F23),
  surfaceContainer: Color(0xFF212328), // powierzchnia: pole szukania, wiersz wciśnięty
  surfaceContainerHigh: Color(0xFF262930), // powierzchnia +2: dialog, arkusz, snackbar
  surfaceContainerHighest: Color(0xFF262930),
  outline: Color(0xFF2E3138), // hairline
  outlineVariant: Color(0xFF45494F), // kropki indeksu
  scrim: Color(0x99000000), // rgba(0,0,0,.60)
  inverseSurface: Color(0xFFF7F4EE),
  onInverseSurface: Color(0xFF1B1A17),
);

const ColorScheme _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF7A5518), // akcent — szafran ciemny
  onPrimary: Color(0xFFFFFDF8),
  secondary: Color(0xFF7A5518),
  onSecondary: Color(0xFFFFFDF8),
  error: Color(0xFFA3231B),
  onError: Color(0xFFFFFDF8),
  surface: Color(0xFFF7F4EE), // papier kostny, nie biel ekranowa
  onSurface: Color(0xFF1B1A17), // atrament
  onSurfaceVariant: Color(0xFF5C5852), // tekst drugi
  surfaceContainerLowest: Color(0xFFFFFDF8),
  surfaceContainerLow: Color(0xFFFFFDF8),
  surfaceContainer: Color(0xFFFFFDF8), // powierzchnia: pole szukania, dialog, arkusz
  surfaceContainerHigh: Color(0xFFEFEAE0), // wciśnięta
  surfaceContainerHighest: Color(0xFFEFEAE0),
  outline: Color(0xFFE2DCD1),
  outlineVariant: Color(0xFFC9C2B5),
  scrim: Color(0x731B1A17), // rgba(27,26,23,.45)
  inverseSurface: Color(0xFF191A1D),
  onInverseSurface: Color(0xFFF4EFE6),
);

ThemeData _buildTheme(ColorScheme scheme, AppColors appColors) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    extensions: [appColors],
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12.0))),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
    ),
    dividerTheme: DividerThemeData(color: appColors.line, space: 1.0, thickness: 1.0),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainer,
      hintStyle: TextStyle(color: appColors.textTertiary),
      prefixIconColor: appColors.textSecondary,
      suffixIconColor: appColors.textSecondary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999.0), // pastylka
        borderSide: BorderSide(color: appColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999.0),
        borderSide: BorderSide(color: appColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999.0),
        borderSide: BorderSide(color: appColors.accent, width: 2.0), // fokus: obwódka 2 dp
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999.0),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999.0),
        borderSide: BorderSide(color: scheme.error, width: 2.0),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: appColors.onAccent,
        backgroundColor: appColors.accent,
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: appColors.accent,
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: appColors.textSecondary,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: appColors.accent,
      thumbColor: appColors.accent,
      inactiveTrackColor: appColors.line,
    ),
    iconTheme: IconThemeData(color: scheme.onSurface),
  );
}

final ThemeData lightTheme = _buildTheme(_lightScheme, AppColors.light);

final ThemeData darkTheme = _buildTheme(_darkScheme, AppColors.dark);
