import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/theme/theme.dart';

/// Krok 5d: kontrast każdej pary kolorów w obu motywach (docs/DESIGN-SYSTEM.md, sekcja 6).
///
/// Progi WCAG 2.1: tekst 4,5:1, duży tekst (≥ 18,66 dp półgruby lub ≥ 24 dp) 3:1,
/// elementy interfejsu i stany nieaktywne 3:1. Stan wyłączony ma być **widoczny, ale
/// odróżnialny**, więc nie zwalnia z progu 3:1 — sprawdzamy go osobno.
double contrast(Color foreground, Color background) {
  // Kolor półprzezroczysty liczy się po nałożeniu na tło, nie sam z siebie.
  final over = Color.alphaBlend(foreground, background);
  final a = over.computeLuminance();
  final b = background.computeLuminance();
  final lighter = a > b ? a : b;
  final darker = a > b ? b : a;
  return (lighter + 0.05) / (darker + 0.05);
}

typedef Pair = ({String what, Color foreground, Color background, double min});

void main() {
  List<Pair> pairsFor(ThemeData theme) {
    final colors = theme.colorScheme;
    final app = theme.extension<AppColors>()!;
    final surface = colors.surface;
    final sheet = colors.surfaceContainerHigh;

    return [
      (what: 'primary text on background', foreground: colors.onSurface, background: surface, min: 4.5),
      (what: 'secondary text on background', foreground: app.textSecondary, background: surface, min: 4.5),
      (what: 'tertiary text on background (inactive tab)', foreground: app.textTertiary, background: surface, min: 3.0),
      (what: 'accent on background (search hit, selected row)', foreground: app.accent, background: surface, min: 4.5),
      (what: 'text on accent (button)', foreground: app.onAccent, background: app.accent, min: 4.5),
      (what: 'destructive color on background', foreground: app.destructive, background: surface, min: 4.5),
      (what: 'accent on its own 12% background in a dialog',
        foreground: app.accent,
        background: Color.alphaBlend(app.accent.withValues(alpha: 0.12), sheet),
        min: 4.5),
      (what: 'secondary text on its own 12% background in a dialog',
        foreground: app.textSecondary,
        background: Color.alphaBlend(app.textSecondary.withValues(alpha: 0.12), sheet),
        min: 4.5),
      (what: 'destructive color on its own 12% background in a dialog',
        foreground: app.destructive,
        background: Color.alphaBlend(app.destructive.withValues(alpha: 0.12), sheet),
        min: 4.5),
      (what: 'favorite heart on background', foreground: app.favorite, background: surface, min: 3.0),
      (what: 'primary text in a sheet and dialog', foreground: colors.onSurface, background: sheet, min: 4.5),
      (what: 'secondary text in a sheet (item icons)', foreground: app.textSecondary, background: sheet, min: 4.5),
      (what: 'text in the search field', foreground: colors.onSurface, background: colors.surfaceContainer, min: 4.5),
      (what: 'hint in the search field', foreground: app.textTertiary, background: colors.surfaceContainer, min: 3.0),
      (what: 'hairline on background', foreground: app.line, background: surface, min: 1.0),
      (what: 'index dots on background', foreground: app.indexDots, background: surface, min: 1.0),
      (what: 'pressed row against background', foreground: app.pressedSurface, background: surface, min: 1.0),
      // Stany nieaktywne: mają być widoczne, ale odróżnialne od aktywnych.
      (what: 'DISABLED song bar arrow', foreground: app.textTertiary, background: surface, min: 3.0),
      (what: 'INACTIVE navigation tab', foreground: app.textTertiary, background: surface, min: 3.0),
      (what: 'DISABLED „Przejdź” button in the dialog (on the line color)',
        foreground: app.textTertiary,
        background: Color.alphaBlend(app.line, sheet),
        min: 3.0),
    ];
  }

  for (final theme in [('light', lightTheme), ('dark', darkTheme)]) {
    group('${theme.$1} theme', () {
      for (final pair in pairsFor(theme.$2)) {
        test('${pair.what} has at least ${pair.min}:1', () {
          final ratio = contrast(pair.foreground, pair.background);
          expect(
            ratio,
            greaterThanOrEqualTo(pair.min),
            reason: '${pair.what}: ${ratio.toStringAsFixed(2)}:1',
          );
        });
      }
    });

    test('contrast table — ${theme.$1} theme', () {
      final rows = pairsFor(theme.$2)
          .map((p) => '${contrast(p.foreground, p.background).toStringAsFixed(2).padLeft(6)}:1  '
              '(min ${p.min})  ${p.what}')
          .join('\n');
      debugPrint('### ${theme.$1} theme\n$rows');
    });
  }
}
