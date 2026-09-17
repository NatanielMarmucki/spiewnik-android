import 'package:flutter/material.dart';

/// Asks the user to confirm a destructive action. Resolves to true only when confirmed.
///
/// Same shape, colors and button layout as the dialogs in SongDetailView; the destructive
/// action is red and the cancel action blue.
Future<bool> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 16),
        ),
        actionsPadding: EdgeInsets.zero,
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                ),
                child: const Text('Anuluj', style: TextStyle(fontSize: 18)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                ),
                child: Text(confirmLabel, style: const TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
