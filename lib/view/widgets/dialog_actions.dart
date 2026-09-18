import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_colors.dart';

/// Wnętrze dialogu: 24 dp dookoła (docs/DESIGN-SYSTEM.md, sekcja 5). Tytuł i treść trzymają je
/// same, bo `DialogThemeData` nie ma na nie pól; akcje biorą swój margines z motywu.
const EdgeInsets kDialogTitlePadding = EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 12.0);
const EdgeInsets kDialogContentPadding = EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 20.0);

/// Akcje dialogu (docs/DESIGN-SYSTEM.md, sekcja 5): **jedna przy lewej krawędzi, druga przy
/// prawej**, każda na własnym tle 12% — wycofanie się w kolorze tekstu drugiego, potwierdzenie
/// w akcencie, akcja niszcząca w kolorze niszczącym. Nigdy jako wypełniony przycisk.
///
/// Wysokość celu to 48 dp z `minimumSize`, więc przycisk rośnie z czcionką zamiast się przycinać.
class DialogActions extends StatelessWidget {
  final List<Widget> children;

  const DialogActions({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    // Na całą szerokość dialogu, inaczej spaceBetween rozsuwa akcje tylko w obrębie
    // ich własnej szerokości i obie lądują po prawej.
    return SizedBox(
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: children,
      ),
    );
  }
}

/// Tło akcji: jej własny kolor ściszony do 12%, ten sam chwyt dla wszystkich trzech wariantów.
ButtonStyle _actionStyle(BuildContext context, Color color) {
  return TextButton.styleFrom(
    foregroundColor: color,
    backgroundColor: color.withValues(alpha: 0.12),
    // Wyłączona akcja zostaje widoczna jako kształt, ale na neutralnym tle linii i w tekście
    // trzecim — bez tego wyglądała, jakby przycisku w ogóle nie było.
    disabledForegroundColor: context.appColors.textTertiary,
    disabledBackgroundColor: context.appColors.line,
    minimumSize: const Size(0.0, 48.0),
    padding: const EdgeInsets.symmetric(horizontal: 20.0),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12.0))),
  );
}

/// Wycofanie się z dialogu: tekst drugi.
Widget dialogQuietButton(BuildContext context, {required String label, required VoidCallback? onPressed}) {
  return TextButton(
    onPressed: onPressed,
    style: _actionStyle(context, context.appColors.textSecondary),
    child: Text(label),
  );
}

/// Potwierdzenie zwykłej akcji: akcent.
Widget dialogAccentButton(BuildContext context, {required String label, required VoidCallback? onPressed}) {
  return TextButton(
    onPressed: onPressed,
    style: _actionStyle(context, context.appColors.accent),
    child: Text(label),
  );
}

/// Akcja niszcząca: kolor niszczący, nie wypełnienie.
Widget dialogDestructiveButton(
  BuildContext context, {
  required String label,
  required VoidCallback? onPressed,
}) {
  return TextButton(
    onPressed: onPressed,
    style: _actionStyle(context, context.appColors.destructive),
    child: Text(label),
  );
}
