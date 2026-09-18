import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/theme/app_text_theme.dart';

/// Dolna nawigacja z docs/DESIGN-SYSTEM.md, sekcja 5.
///
/// Trzy zakładki, ikona kreskowa 17 dp i podpis w jednej linii. Aktywna: kreska 2 dp w akcencie
/// nad pozycją, ikona w akcencie, podpis w kolorze tekstu i w wadze 600. Nieaktywna: tekst trzeci.
///
/// Wysokość to **minimum** 48 dp, a nie wartość stała: podpis rośnie razem z systemowym
/// powiększeniem czcionki (reguła 1 z sekcji 7 dokumentu).
class AppNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const AppNavigationBar({super.key, required this.selectedIndex, required this.onSelected});

  static const double minHeight = 48.0;
  static const double iconSize = 17.0;
  static const double indicatorHeight = 2.0;

  static const List<({IconData icon, String label})> destinations = [
    (icon: Icons.menu_book, label: 'Śpiewnik'),
    (icon: Icons.favorite, label: 'Ulubione'),
    (icon: Icons.edit_note, label: 'Moje pieśni'),
  ];

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: appColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minHeight),
          child: Row(
            children: [
              for (var index = 0; index < destinations.length; index++)
                Expanded(
                  child: _Destination(
                    destination: destinations[index],
                    isSelected: index == selectedIndex,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  final ({IconData icon, String label}) destination;
  final bool isSelected;
  final VoidCallback onTap;

  const _Destination({required this.destination, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final colors = Theme.of(context).colorScheme;
    final labelStyle = TextStyle(
      fontFamily: AppFonts.ui,
      fontSize: 10.5,
      height: 1.2,
      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      color: isSelected ? colors.onSurface : appColors.textTertiary,
    );

    return Semantics(
      button: true,
      selected: isSelected,
      label: destination.label,
      // Akcja musi być na węźle: excludeSemantics ucina ją z InkWella, a czytnik ekranu
      // aktywuje wtedy pustkę.
      onTap: onTap,
      // Jeden węzeł na zakładkę: czytnik ekranu czyta podpis raz, nie osobno ikonę i tekst.
      container: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Kreska aktywnej zakładki; nieaktywna trzyma tę samą wysokość, żeby nic nie skakało.
            Container(
              height: AppNavigationBar.indicatorHeight,
              color: isSelected ? appColors.accent : colors.surface,
            ),
            const SizedBox(height: 6.0),
            Icon(
              destination.icon,
              size: AppNavigationBar.iconSize,
              color: isSelected ? appColors.accent : appColors.textTertiary,
            ),
            const SizedBox(height: 4.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                destination.label,
                style: labelStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 6.0),
          ],
        ),
      ),
    );
  }
}
