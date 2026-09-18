import 'package:flutter/material.dart';
import 'package:spiewnik/view/widgets/dialog_actions.dart';

/// Asks the user to confirm a destructive action. Resolves to true only when confirmed.
///
/// Shape, padding, colors and text styles come from the theme (docs/DESIGN-SYSTEM.md, section 5):
/// both actions sit on the right, "Anuluj" in the secondary text color, the destructive one in the
/// destructive color on a 12% background — never as a filled button.
Future<bool> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        titlePadding: kDialogTitlePadding,
        contentPadding: kDialogContentPadding,
        title: Text(title),
        content: Text(message),
        actions: [
          DialogActions(
            children: [
              dialogQuietButton(
                context,
                label: 'Anuluj',
                onPressed: () => Navigator.pop(context, false),
              ),
              dialogDestructiveButton(
                context,
                label: confirmLabel,
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
