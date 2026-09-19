import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spiewnik/view/widgets/dialog_actions.dart';

/// Message shown when a web page or the mail app could not be opened.
///
/// Before, such a failure ended with a `print` in the console and the user did not know that
/// anything went wrong. The old iOS app showed an alert here with an option to copy the
/// address — we do the same here, in the shape of the dialogs from the design system.
Future<void> showLinkFailureDialog(
  BuildContext context, {
  required String message,
  required String copyValue,
  required String copyConfirmation,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      titlePadding: kDialogTitlePadding,
      contentPadding: kDialogContentPadding,
      title: const Text('Nie udało się otworzyć'),
      content: Text('$message\n\n$copyValue'),
      actions: [
        DialogActions(
          children: [
            dialogQuietButton(
              dialogContext,
              label: 'Zamknij',
              onPressed: () => Navigator.pop(dialogContext),
            ),
            dialogAccentButton(
              dialogContext,
              label: 'Kopiuj adres',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: copyValue));
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(copyConfirmation)));
              },
            ),
          ],
        ),
      ],
    ),
  );
}

/// Message for a failed bug report: the address is left to copy by hand.
Future<void> showEmailFailureDialog(BuildContext context, String email) {
  return showLinkFailureDialog(
    context,
    message: 'Nie udało się otworzyć poczty. Napisz na adres:',
    copyValue: email,
    copyConfirmation: 'Adres skopiowany do schowka',
  );
}

/// Message for a web page that failed to open.
Future<void> showPageFailureDialog(BuildContext context, String url) {
  return showLinkFailureDialog(
    context,
    message: 'Nie udało się otworzyć strony. Otwórz ją w przeglądarce:',
    copyValue: url,
    copyConfirmation: 'Adres skopiowany do schowka',
  );
}
