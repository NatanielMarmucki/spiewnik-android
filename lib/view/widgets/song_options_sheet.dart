import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_colors.dart';

/// Arkusz opcji z docs/DESIGN-SYSTEM.md, sekcja 5: uchwyt 34 × 3 dp, pozycje 52 dp.
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
          for (final option in options) _Option(option: option),
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
  final VoidCallback onTap;

  const SongOption({required this.icon, required this.label, this.value, required this.onTap});
}

class _Option extends StatelessWidget {
  final SongOption option;

  const _Option({required this.option});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

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
                Icon(option.icon, size: 17.0, color: appColors.textSecondary),
                const SizedBox(width: 16.0),
                Expanded(child: Text(option.label, style: textTheme.bodyMedium)),
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
