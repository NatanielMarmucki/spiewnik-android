import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/view/widgets/dialog_actions.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';

/// The „Przejdź do pieśni” (Go to song) modal from docs/DESIGN-SYSTEM.md, section 5.
///
/// A numeric field with the **system keyboard**, a hint with the range computed from the database,
/// and the song title shown right below the field. Enter works like „Przejdź” (Go). Colors and
/// shape come from the tokens.
///
/// Returns the chosen song, or null when the user cancels.
Future<Song?> showGoToSongDialog(BuildContext context, SongViewModel viewModel) {
  return showDialog<Song>(
    context: context,
    builder: (context) => _GoToSongDialog(viewModel: viewModel),
  );
}

class _GoToSongDialog extends StatefulWidget {
  final SongViewModel viewModel;

  const _GoToSongDialog({required this.viewModel});

  @override
  State<_GoToSongDialog> createState() => _GoToSongDialogState();
}

class _GoToSongDialogState extends State<_GoToSongDialog> {
  final TextEditingController _controller = TextEditingController();
  GoToSongResult? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() => _result = value.isEmpty ? null : widget.viewModel.goToNumber(value));
  }

  void _submit() {
    final result = widget.viewModel.goToNumber(_controller.text);
    if (result.outcome == GoToSongOutcome.found) {
      Navigator.pop(context, result.song);
    } else {
      setState(() => _result = result);
    }
  }

  /// Preview below the field: the title of the matched song or the reason nothing was found.
  Widget _preview(BuildContext context) {
    final appColors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final result = _result;

    final (String text, Color color) = switch (result?.outcome) {
      null => ('', appColors.textSecondary),
      GoToSongOutcome.found => (result!.song!.title, Theme.of(context).colorScheme.onSurface),
      GoToSongOutcome.notFound => ('Nie ma pieśni o tym numerze', appColors.textSecondary),
      GoToSongOutcome.invalidNumber => (
        'Podaj numer od 1 do ${widget.viewModel.songCount}',
        appColors.textSecondary,
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Text(
        text,
        style: textTheme.bodyMedium?.copyWith(color: color),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final found = _result?.outcome == GoToSongOutcome.found;

    return AlertDialog(
      titlePadding: kDialogTitlePadding,
      contentPadding: kDialogContentPadding,
      title: const Text('Przejdź do pieśni'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            // System keyboard, no custom keypad.
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.go,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(hintText: '1-${widget.viewModel.songCount}'),
            onChanged: _onChanged,
            onSubmitted: (_) => _submit(),
          ),
          _preview(context),
        ],
      ),
      actions: [
        DialogActions(
          children: [
            dialogQuietButton(context, label: 'Anuluj', onPressed: () => Navigator.pop(context)),
            dialogAccentButton(context, label: 'Przejdź', onPressed: found ? _submit : null),
          ],
        ),
      ],
    );
  }
}
