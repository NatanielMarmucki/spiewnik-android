import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/view/screen_wake_lock.dart';
import 'package:spiewnik/view/widgets/song_content.dart';

class SongDetailView extends StatefulWidget {
  final Song song;
  final SongViewModel viewModel;

  const SongDetailView({super.key, required this.song, required this.viewModel});

  @override
  SongDetailViewState createState() => SongDetailViewState();
}

class SongDetailViewState extends State<SongDetailView> {
  late Song song;

  @override
  void initState() {
    super.initState();
    ScreenWakeLock.acquire();
    song = widget.song;
  }

  @override
  void dispose() {
    ScreenWakeLock.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Text(
              '${song.number}. ${song.title}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18.0,
              ),
            ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: InkWell(
                onTap: () {
                  setState(() {
                    widget.viewModel.toggleFavoriteStatus(song);
                  });
                },
                child: Icon(
                  song.favorite ? Icons.favorite : Icons.favorite_border,
                  size: 24.0,
                  color: song.favorite ? context.appColors.favorite : null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: song.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Treść skopiowana do schowka')),
                  );
                },
                child: const Icon(
                  Icons.share,
                  size: 24.0,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: InkWell(
                onTap: () {
                  _showSearchDialog(context);
                },
                child: const Icon(
                  Icons.search,
                  size: 24.0,
                ),
              ),
            ),
          ],
        ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: (details) {
          if (details.delta.dx < -10) {
            _goToNextSong();
          } else if (details.delta.dx > 10) {
            _goToPreviousSong();
          }
        },
        child: SongContent(content: song.content),
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    final appColors = context.appColors;
    final FocusNode focusNode = FocusNode();

    showDialog(
      context: context,
      builder: (context) {
        String input = '';
        final TextEditingController controller = TextEditingController();

        return AlertDialog(
          title: const Text('Przejdź do pieśni'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Podaj numer pieśni, do której chcesz przejść.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                focusNode: focusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                controller: controller,
                decoration: const InputDecoration(hintText: 'Numer pieśni'),
                onChanged: (value) {
                  input = value;
                },
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                ],
              ),
            ],
          ),
          actionsPadding: EdgeInsets.zero,
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: appColors.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                  ),
                  child: const Text('Anuluj'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToSong(context, input);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: appColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                  ),
                  child: const Text('Przejdź'),
                ),
              ],
            ),
          ],
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
    });
  }

  void _showMessageDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Uwaga', textAlign: TextAlign.center),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToSong(BuildContext context, String input) {
    final result = widget.viewModel.goToNumber(input);
    switch (result.outcome) {
      case GoToSongOutcome.found:
        _openSong(context, result.song!);
      case GoToSongOutcome.notFound:
        _showMessageDialog(context, 'Pieśń o podanym numerze nie została znaleziona');
      case GoToSongOutcome.invalidNumber:
        _showMessageDialog(
          context,
          'Podano niepoprawny numer. W śpiewniku znajduje się ${widget.viewModel.songCount} pieśni.',
        );
    }
  }

  void _openSong(BuildContext context, Song song) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => SongDetailView(song: song, viewModel: widget.viewModel)),
    );
  }

  void _goToNextSong() {
    final nextSong = widget.viewModel.findNextSong(song.number);
    if (nextSong != null) {
      _openSong(context, nextSong);
    }
  }

  void _goToPreviousSong() {
    final previousSong = widget.viewModel.findPreviousSong(song.number);
    if (previousSong != null) {
      _openSong(context, previousSong);
    }
  }
}