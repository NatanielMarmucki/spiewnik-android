import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:spiewnik/model/font_size_model.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/view/screen_wake_lock.dart';
import 'package:spiewnik/view/settings_view.dart';
import 'package:spiewnik/view/widgets/go_to_song_dialog.dart';
import 'package:spiewnik/view/widgets/song_bottom_bar.dart';
import 'package:spiewnik/view/widgets/song_content.dart';
import 'package:spiewnik/view/widgets/song_options_sheet.dart';

class SongDetailView extends StatefulWidget {
  final Song song;
  final SongViewModel viewModel;

  const SongDetailView({super.key, required this.song, required this.viewModel});

  @override
  SongDetailViewState createState() => SongDetailViewState();
}

class SongDetailViewState extends State<SongDetailView> {
  late Song song;

  /// Anchor for the share sheet on iPad, where it is a popover next to the button.
  final GlobalKey _optionsButtonKey = GlobalKey();

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
            IconButton(
              tooltip: song.favorite ? 'Usuń z ulubionych' : 'Dodaj do ulubionych',
              onPressed: () {
                setState(() {
                  widget.viewModel.toggleFavoriteStatus(song);
                });
              },
              icon: Icon(
                song.favorite ? Icons.favorite : Icons.favorite_border,
                size: 24.0,
                color: song.favorite ? context.appColors.favorite : null,
              ),
            ),
            IconButton(
              key: _optionsButtonKey,
              tooltip: 'Opcje pieśni',
              onPressed: _showOptions,
              icon: const Icon(Icons.more_vert, size: 24.0),
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
        previousNumber: widget.viewModel.findPreviousSong(song.number)?.number,
        nextNumber: widget.viewModel.findNextSong(song.number)?.number,
        onPrevious: _goToPreviousSong,
        onNext: _goToNextSong,
        onGoToNumber: _showSearchDialog,
      ),
    );
  }

  /// Options sheet from the three dots. Items close the sheet **before** their action,
  /// so the system share sheet does not open on top of ours.
  Future<void> _showOptions() async {
    final fontSizeModel = context.read<FontSizeModel>();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      builder: (sheetContext) => SongOptionsSheet(
        options: [
          SongOption(
            icon: Icons.ios_share,
            label: 'Udostępnij pieśń',
            onTap: () {
              Navigator.pop(sheetContext);
              _share();
            },
          ),
          SongOption(
            icon: Icons.text_fields,
            label: 'Rozmiar tekstu',
            value: '${fontSizeModel.fontSize.round()}',
            onTap: () {
              Navigator.pop(sheetContext);
              _openSettings();
            },
          ),
          SongOption(
            icon: Icons.content_copy,
            label: 'Kopiuj tekst',
            onTap: () {
              Navigator.pop(sheetContext);
              _copyText();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _share() async {
    final box = _optionsButtonKey.currentContext?.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: '${song.number}. ${song.title}\n\n${song.content}',
        subject: '${song.number}. ${song.title}',
        // Required on iPad, where the system sheet is a popover anchored to the button.
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  void _copyText() {
    Clipboard.setData(ClipboardData(text: song.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Treść skopiowana do schowka')),
    );
  }

  void _openSettings() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsView()));
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