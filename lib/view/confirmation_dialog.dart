import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_colors.dart';

/// Asks the user to confirm a destructive action. Resolves to true only when confirmed.
///
/// Shape, colors and text styles come from the theme; the destructive action uses the
/// destructive token, "Anuluj" the secondary text color.
Future<bool> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final appColors = context.appColors;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message),
        actionsPadding: EdgeInsets.zero,
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  foregroundColor: appColors.textSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                ),
                child: const Text('Anuluj'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  foregroundColor: appColors.destructive,
                  padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                ),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
