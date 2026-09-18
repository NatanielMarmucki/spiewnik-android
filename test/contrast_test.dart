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
      (what: 'tekst główny na tle', foreground: colors.onSurface, background: surface, min: 4.5),
      (what: 'tekst drugi na tle', foreground: app.textSecondary, background: surface, min: 4.5),
      (what: 'tekst trzeci na tle (zakładka nieaktywna)', foreground: app.textTertiary, background: surface, min: 3.0),
      (what: 'akcent na tle (trafienie wyszukiwania, wybrany wiersz)', foreground: app.accent, background: surface, min: 4.5),
      (what: 'tekst na akcencie (przycisk)', foreground: app.onAccent, background: app.accent, min: 4.5),
      (what: 'kolor niszczący na tle', foreground: app.destructive, background: surface, min: 4.5),
      (what: 'kolor niszczący na własnym tle 12% w dialogu',
        foreground: app.destructive,
        background: Color.alphaBlend(app.destructive.withValues(alpha: 0.12), sheet),
        min: 4.5),
      (what: 'serce ulubionej na tle', foreground: app.favorite, background: surface, min: 3.0),
      (what: 'tekst główny w arkuszu i dialogu', foreground: colors.onSurface, background: sheet, min: 4.5),
      (what: 'tekst drugi w arkuszu (ikony pozycji)', foreground: app.textSecondary, background: sheet, min: 4.5),
      (what: 'tekst w polu wyszukiwania', foreground: colors.onSurface, background: colors.surfaceContainer, min: 4.5),
      (what: 'podpowiedź w polu wyszukiwania', foreground: app.textTertiary, background: colors.surfaceContainer, min: 3.0),
      (what: 'hairline na tle', foreground: app.line, background: surface, min: 1.0),
      (what: 'kropki indeksu na tle', foreground: app.indexDots, background: surface, min: 1.0),
      (what: 'wiersz wciśnięty wobec tła', foreground: app.pressedSurface, background: surface, min: 1.0),
      // Stany nieaktywne: mają być widoczne, ale odróżnialne od aktywnych.
      (what: 'NIEAKTYWNA strzałka paska pieśni', foreground: app.textTertiary, background: surface, min: 3.0),
      (what: 'NIEAKTYWNA zakładka nawigacji', foreground: app.textTertiary, background: surface, min: 3.0),
      (what: 'ZABLOKOWANY przycisk „Przejdź” w dialogu', foreground: app.textTertiary, background: sheet, min: 3.0),
    ];
  }

  for (final theme in [('jasny', lightTheme), ('ciemny', darkTheme)]) {
    group('motyw ${theme.$1}', () {
      for (final pair in pairsFor(theme.$2)) {
        test('${pair.what} ma co najmniej ${pair.min}:1', () {
          final ratio = contrast(pair.foreground, pair.background);
          expect(
            ratio,
            greaterThanOrEqualTo(pair.min),
            reason: '${pair.what}: ${ratio.toStringAsFixed(2)}:1',
          );
        });
      }
    });

    test('tabela kontrastu — motyw ${theme.$1}', () {
      final rows = pairsFor(theme.$2)
          .map((p) => '${contrast(p.foreground, p.background).toStringAsFixed(2).padLeft(6)}:1  '
              '(próg ${p.min})  ${p.what}')
          .join('\n');
      debugPrint('### motyw ${theme.$1}\n$rows');
    });
  }
}
