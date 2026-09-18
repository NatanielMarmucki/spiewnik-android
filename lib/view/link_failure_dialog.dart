import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spiewnik/view/widgets/dialog_actions.dart';

/// Komunikat, gdy nie udało się otworzyć strony albo poczty.
///
/// Wcześniej takie niepowodzenie kończyło się `print`em w konsoli i użytkownik nie wiedział, że
/// cokolwiek poszło nie tak. Stara aplikacja iOS pokazywała w tym miejscu alert z możliwością
/// skopiowania adresu — to samo robimy tutaj, w kształcie dialogów z systemu wizualnego.
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

/// Komunikat dla nieudanego zgłoszenia błędu: adres zostaje do skopiowania ręcznie.
Future<void> showEmailFailureDialog(BuildContext context, String email) {
  return showLinkFailureDialog(
    context,
    message: 'Nie udało się otworzyć poczty. Napisz na adres:',
    copyValue: email,
    copyConfirmation: 'Adres skopiowany do schowka',
  );
}

/// Komunikat dla nieudanego otwarcia strony.
Future<void> showPageFailureDialog(BuildContext context, String url) {
  return showLinkFailureDialog(
    context,
    message: 'Nie udało się otworzyć strony. Otwórz ją w przeglądarce:',
    copyValue: url,
    copyConfirmation: 'Adres skopiowany do schowka',
  );
}
