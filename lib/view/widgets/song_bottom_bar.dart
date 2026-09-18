import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_colors.dart';

/// Pasek pod treścią pieśni z docs/DESIGN-SYSTEM.md, sekcja 5: strzałka w lewo z numerem
/// poprzedniej pieśni, numer bieżącej z lupką w środku jako najszerszy cel i strzałka w prawo
/// z numerem następnej.
///
/// Strzałki stoją **zawsze w tym samym miejscu**, także na krańcach śpiewnika: wtedy są wygaszone
/// i nieaktywne, żeby pasek nie skakał. Wysokość jest minimalna, więc rośnie z czcionką systemową.
class SongBottomBar extends StatelessWidget {
  /// Numer bieżącej pieśni.
  final int number;

  /// Numer poprzedniej pieśni albo null, gdy nie ma dokąd wrócić.
  final int? previousNumber;

  /// Numer następnej pieśni albo null.
  final int? nextNumber;

  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onGoToNumber;

  const SongBottomBar({
    super.key,
    required this.number,
    required this.previousNumber,
    required this.nextNumber,
    required this.onPrevious,
    required this.onNext,
    required this.onGoToNumber,
  });

  static const double minHeight = 48.0;
  static const double iconSize = 17.0;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: appColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minHeight),
          child: Row(
            children: [
              _Arrow(
                icon: Icons.chevron_left,
                label: 'Poprzednia pieśń',
                number: previousNumber,
                onTap: onPrevious,
              ),
              Expanded(child: _GoToNumber(number: number, onTap: onGoToNumber)),
              _Arrow(
                icon: Icons.chevron_right,
                label: 'Następna pieśń',
                number: nextNumber,
                onTap: onNext,
                numberFirst: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? number;
  final VoidCallback? onTap;
  final bool numberFirst;

  const _Arrow({
    required this.icon,
    required this.label,
    required this.number,
    required this.onTap,
    this.numberFirst = true,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final enabled = number != null && onTap != null;
    final color = enabled ? appColors.textSecondary : appColors.line;
    final numberText = Text(
      number == null ? '' : '$number',
      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color),
    );
    final arrow = Icon(icon, size: SongBottomBar.iconSize, color: color);

    return Semantics(
      button: true,
      enabled: enabled,
      label: number == null ? label : '$label, numer $number',
      container: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          // Cel dotknięcia 40 x 48 dp (sekcja 6 dokumentu).
          constraints: const BoxConstraints(minWidth: 56.0, minHeight: SongBottomBar.minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: numberFirst
                  ? [arrow, const SizedBox(width: 4.0), numberText]
                  : [numberText, const SizedBox(width: 4.0), arrow],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoToNumber extends StatelessWidget {
  final int number;
  final VoidCallback onTap;

  const _GoToNumber({required this.number, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    return Semantics(
      button: true,
      label: 'Przejdź do pieśni, teraz numer $number',
      container: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: SongBottomBar.minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search, size: SongBottomBar.iconSize, color: appColors.textSecondary),
                const SizedBox(width: 8.0),
                Text(
                  '$number',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: appColors.accent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
