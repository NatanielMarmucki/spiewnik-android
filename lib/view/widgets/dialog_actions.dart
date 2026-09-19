import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_colors.dart';

/// Dialog interior: 24 dp all around (docs/DESIGN-SYSTEM.md, section 5). The title and content hold
/// it themselves, because `DialogThemeData` has no fields for them; the actions take their margin
/// from the theme.
const EdgeInsets kDialogTitlePadding = EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 12.0);
const EdgeInsets kDialogContentPadding = EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 20.0);

/// Dialog actions (docs/DESIGN-SYSTEM.md, section 5): **one at the left edge, the other at the
/// right**, each on its own 12% background — backing out in the secondary text color, confirmation
/// in the accent, a destructive action in the destructive color. Never as a filled button.
///
/// The target height is 48 dp from `minimumSize`, so the button grows with the font instead of
/// being clipped.
class DialogActions extends StatelessWidget {
  final List<Widget> children;

  const DialogActions({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    // Full dialog width; otherwise spaceBetween spreads the actions only within
    // their own width and both end up on the right.
    return SizedBox(
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: children,
      ),
    );
  }
}

/// Action background: its own color toned down to 12%, the same trick for all three variants.
ButtonStyle _actionStyle(BuildContext context, Color color) {
  return TextButton.styleFrom(
    foregroundColor: color,
    backgroundColor: color.withValues(alpha: 0.12),
    // A disabled action stays visible as a shape, but on the neutral line background and in
    // tertiary text — without this it looked as if there were no button at all.
    disabledForegroundColor: context.appColors.textTertiary,
    disabledBackgroundColor: context.appColors.line,
    minimumSize: const Size(0.0, 48.0),
    padding: const EdgeInsets.symmetric(horizontal: 20.0),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12.0))),
  );
}

/// Backing out of the dialog: secondary text.
Widget dialogQuietButton(BuildContext context, {required String label, required VoidCallback? onPressed}) {
  return TextButton(
    onPressed: onPressed,
    style: _actionStyle(context, context.appColors.textSecondary),
    child: Text(label),
  );
}

/// Confirming a regular action: accent.
Widget dialogAccentButton(BuildContext context, {required String label, required VoidCallback? onPressed}) {
  return TextButton(
    onPressed: onPressed,
    style: _actionStyle(context, context.appColors.accent),
    child: Text(label),
  );
}

/// Destructive action: the destructive color, not a fill.
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
