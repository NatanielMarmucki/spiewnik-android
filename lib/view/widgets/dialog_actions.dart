import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_colors.dart';

/// Wnętrze dialogu: 24 dp dookoła (docs/DESIGN-SYSTEM.md, sekcja 5). Tytuł i treść trzymają je
/// same, bo `DialogThemeData` nie ma na nie pól; akcje biorą swój margines z motywu.
const EdgeInsets kDialogTitlePadding = EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 12.0);
const EdgeInsets kDialogContentPadding = EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 20.0);

/// Akcje dialogu z docs/DESIGN-SYSTEM.md, sekcja 5: dwie akcje **po prawej**, „Anuluj” przestaje
/// być niebieskie, a akcja niszcząca jest w kolorze niszczącym z tłem 12% — **nigdy** jako
/// wypełniony przycisk.
///
/// Wysokość celu to 48 dp z `minimumSize`, więc przycisk rośnie z czcionką zamiast się przycinać.
class DialogActions extends StatelessWidget {
  final List<Widget> children;

  const DialogActions({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 8.0),
          children[i],
        ],
      ],
    );
  }
}

/// Wycofanie się z dialogu: tekst drugi, bez tła.
Widget dialogQuietButton(BuildContext context, {required String label, required VoidCallback? onPressed}) {
  return TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: context.appColors.textSecondary,
      minimumSize: const Size(0.0, 48.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
    ),
    child: Text(label),
  );
}

/// Potwierdzenie zwykłej akcji: akcent, bez tła.
Widget dialogAccentButton(BuildContext context, {required String label, required VoidCallback? onPressed}) {
  return TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: context.appColors.accent,
      // Domyślny kolor wyłączonego przycisku (onSurface 38%) daje w jasnym motywie 2,31:1.
      // Tekst trzeci trzyma 4,9:1 i wciąż różni się od akcentu.
      disabledForegroundColor: context.appColors.textTertiary,
      minimumSize: const Size(0.0, 48.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
    ),
    child: Text(label),
  );
}

/// Akcja niszcząca: kolor niszczący na własnym tle 12%, nie na wypełnieniu.
Widget dialogDestructiveButton(
  BuildContext context, {
  required String label,
  required VoidCallback? onPressed,
}) {
  final destructive = context.appColors.destructive;

  return TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: destructive,
      backgroundColor: destructive.withValues(alpha: 0.12),
      disabledForegroundColor: context.appColors.textTertiary,
      disabledBackgroundColor: Colors.transparent,
      minimumSize: const Size(0.0, 48.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12.0))),
    ),
    child: Text(label),
  );
}
