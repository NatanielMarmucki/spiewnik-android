import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/view/screen_wake_lock.dart';
import 'package:spiewnik/view/widgets/go_to_song_dialog.dart';
import 'package:spiewnik/view/widgets/song_bottom_bar.dart';
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
      bottomNavigationBar: SongBottomBar(
        number: song.number,
        previousNumber: widget.viewModel.findPreviousSong(song.number)?.number,
        nextNumber: widget.viewModel.findNextSong(song.number)?.number,
        onPrevious: _goToPreviousSong,
        onNext: _goToNextSong,
        onGoToNumber: _showSearchDialog,
      ),
    );
  }

  Future<void> _showSearchDialog() async {
    final song = await showGoToSongDialog(context, widget.viewModel);
    if (!mounted || song == null) {
      return;
    }
    _openSong(context, song);
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