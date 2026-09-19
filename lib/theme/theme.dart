import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/theme/app_text_theme.dart';

/// Themes built from the tokens in docs/DESIGN-SYSTEM.md (sections 1 and 2).
///
/// Colors outside the Material roles live in [AppColors] and enter the theme as an extension.

const ColorScheme _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFE2B872), // accent — saffron
  onPrimary: Color(0xFF191A1D),
  secondary: Color(0xFFE2B872),
  onSecondary: Color(0xFF191A1D),
  error: Color(0xFFF29186), // destructive
  onError: Color(0xFF191A1D),
  surface: Color(0xFF191A1D), // background of screens, app bar and navigation
  onSurface: Color(0xFFF4EFE6), // text — warm white
  onSurfaceVariant: Color(0xFFA8A29B), // secondary text
  surfaceContainerLowest: Color(0xFF191A1D),
  surfaceContainerLow: Color(0xFF1D1F23),
  surfaceContainer: Color(0xFF212328), // surface: search field, pressed row
  surfaceContainerHigh: Color(0xFF262930), // surface +2: dialog, sheet, snackbar
  surfaceContainerHighest: Color(0xFF262930),
  outline: Color(0xFF2E3138), // hairline
  outlineVariant: Color(0xFF45494F), // index dots
  scrim: Color(0x99000000), // rgba(0,0,0,.60)
  inverseSurface: Color(0xFFF7F4EE),
  onInverseSurface: Color(0xFF1B1A17),
);

const ColorScheme _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF7A5518), // accent — dark saffron
  onPrimary: Color(0xFFFFFDF8),
  secondary: Color(0xFF7A5518),
  onSecondary: Color(0xFFFFFDF8),
  error: Color(0xFFA3231B),
  onError: Color(0xFFFFFDF8),
  surface: Color(0xFFF7F4EE), // bone paper, not screen white
  onSurface: Color(0xFF1B1A17), // ink
  onSurfaceVariant: Color(0xFF5C5852), // secondary text
  surfaceContainerLowest: Color(0xFFFFFDF8),
  surfaceContainerLow: Color(0xFFFFFDF8),
  surfaceContainer: Color(0xFFFFFDF8), // surface: search field, dialog, sheet
  surfaceContainerHigh: Color(0xFFEFEAE0), // pressed
  surfaceContainerHighest: Color(0xFFEFEAE0),
  outline: Color(0xFFE2DCD1),
  outlineVariant: Color(0xFFC9C2B5),
  scrim: Color(0x731B1A17), // rgba(27,26,23,.45)
  inverseSurface: Color(0xFF191A1D),
  onInverseSurface: Color(0xFFF4EFE6),
);

ThemeData _buildTheme(ColorScheme scheme, AppColors appColors) {
  final textTheme = buildAppTextTheme(scheme);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    fontFamily: AppFonts.ui,
    textTheme: textTheme,
    extensions: [appColors],
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.headlineSmall,
      contentTextStyle: textTheme.bodyMedium,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12.0))),
      // 24 dp inner padding (section 5 of the document). Title and body get their padding in the dialogs:
      // DialogThemeData has no fields for them.
      actionsPadding: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 24.0),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      // The same 12 dp radius as the dialog; the bottom stays square, because the sheet sits at the edge.
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
      ),
      showDragHandle: false,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      contentTextStyle: textTheme.bodyMedium,
    ),
    dividerTheme: DividerThemeData(color: appColors.line, space: 1.0, thickness: 1.0),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainer,
      hintStyle: textTheme.bodyMedium?.copyWith(color: appColors.textTertiary),
      prefixIconColor: appColors.textSecondary,
      suffixIconColor: appColors.textSecondary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999.0), // pill
        borderSide: BorderSide(color: appColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999.0),
        borderSide: BorderSide(color: appColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999.0),
        borderSide: BorderSide(color: appColors.accent, width: 2.0), // focus: 2 dp outline
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
        textStyle: textTheme.labelLarge,
        shape: const StadiumBorder(),
      ).copyWith(
        // No shadows anywhere (docs/DESIGN-SYSTEM.md). styleFrom(elevation: 0) is not enough: it still
        // raises the button by 2 dp on hover and focus and by 6 dp when pressed.
        elevation: const WidgetStatePropertyAll(0.0),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: appColors.accent,
        textStyle: textTheme.labelLarge,
      ),
    ),
    listTileTheme: ListTileThemeData(
      titleTextStyle: textTheme.titleMedium,
      subtitleTextStyle: textTheme.bodyMedium,
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
