import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_colors.dart';

/// Arkusz opcji z docs/DESIGN-SYSTEM.md, sekcja 5: uchwyt 34 × 3 dp, pozycje 52 dp,
/// sekcja niszcząca odcięta hairline'em.
///
/// Wysokość pozycji jest **minimalna**, więc rośnie razem z czcionką systemową.
class SongOptionsSheet extends StatelessWidget {
  final List<SongOption> options;

  const SongOptionsSheet({super.key, required this.options});

  static const double handleWidth = 34.0;
  static const double handleHeight = 3.0;
  static const double minItemHeight = 52.0;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Container(
              width: handleWidth,
              height: handleHeight,
              decoration: BoxDecoration(
                color: appColors.line,
                borderRadius: BorderRadius.circular(handleHeight),
              ),
            ),
          ),
          for (var i = 0; i < options.length; i++) ...[
            // Hairline odcina sekcję niszczącą od reszty, żeby usunięcie nie stało w jednym ciągu
            // z udostępnianiem.
            if (options[i].destructive && (i == 0 || !options[i - 1].destructive))
              Divider(color: appColors.line, height: 1.0),
            _Option(option: options[i]),
          ],
          const SizedBox(height: 8.0),
        ],
      ),
    );
  }
}

/// Pozycja arkusza: ikona, tytuł i opcjonalna wartość po prawej (np. bieżący rozmiar tekstu).
class SongOption {
  final IconData icon;
  final String label;
  final String? value;

  /// Akcja nieodwracalna: kolor niszczący i hairline odcinający ją od reszty.
  final bool destructive;

  final VoidCallback onTap;

  const SongOption({
    required this.icon,
    required this.label,
    this.value,
    this.destructive = false,
    required this.onTap,
  });
}

class _Option extends StatelessWidget {
  final SongOption option;

  const _Option({required this.option});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final color = option.destructive ? appColors.destructive : null;

    return Semantics(
      button: true,
      label: option.value == null ? option.label : '${option.label}, ${option.value}',
      onTap: option.onTap,
      container: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: option.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: SongOptionsSheet.minItemHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Row(
              children: [
                Icon(option.icon, size: 17.0, color: color ?? appColors.textSecondary),
                const SizedBox(width: 16.0),
                Expanded(child: Text(option.label, style: textTheme.bodyMedium?.copyWith(color: color))),
                if (option.value != null)
                  Text(option.value!, style: textTheme.bodyMedium?.copyWith(color: appColors.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
