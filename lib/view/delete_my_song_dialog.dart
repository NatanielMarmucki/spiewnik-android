import 'package:flutter/material.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/view/confirmation_dialog.dart';

/// Confirmation shown before deleting a user song, from the preview and from the list.
Future<bool> confirmMySongDeletion(BuildContext context, MySong song) {
  return showConfirmationDialog(
    context,
    title: 'Usunąć pieśń?',
    message: 'Pieśń „${song.title}” zostanie trwale usunięta.',
    confirmLabel: 'Usuń',
  );
}
