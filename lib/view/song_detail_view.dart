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

/// A song screen: the song text is a page in a [PageView] over the whole songbook, so moving to the
/// previous or next song turns the page under the bars instead of replacing the screen.
class SongDetailView extends StatefulWidget {
  final Song song;
  final SongViewModel viewModel;

  const SongDetailView({super.key, required this.song, required this.viewModel});

  @override
  SongDetailViewState createState() => SongDetailViewState();
}

class SongDetailViewState extends State<SongDetailView> {
  late final PageController _pageController;

  /// Position of the shown song in [SongViewModel.allSongsNotifier], which lists songs by number.
  late int _index;

  /// Anchor for the share sheet on iPad, where it is a popover next to the button.
  final GlobalKey _optionsButtonKey = GlobalKey();

  List<Song> get _songs => widget.viewModel.allSongsNotifier.value;

  Song get song => _songs[_index];

  @override
  void initState() {
    super.initState();
    ScreenWakeLock.acquire();
    _index = _indexOf(widget.song);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    ScreenWakeLock.release();
    super.dispose();
  }

  int _indexOf(Song song) => _songs.indexWhere((s) => s.number == song.number);

  @override
  Widget build(BuildContext context) {
    // Toggling a favorite reloads the list with new Song objects; order and length stay the same.
    return ValueListenableBuilder<List<Song>>(
      valueListenable: widget.viewModel.allSongsNotifier,
      builder: (context, songs, _) {
        final song = songs[_index];
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
                onPressed: () => widget.viewModel.toggleFavoriteStatus(song),
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
          // Only the text moves; the bars stay (docs/DESIGN-SYSTEM.md, section 5, "Moving between songs").
          // The builder keeps only the shown page alive (two while dragging), not 2000.
          body: PageView.builder(
            controller: _pageController,
            itemCount: songs.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) => SongContent(
              key: ValueKey(songs[index].number),
              content: songs[index].content,
            ),
          ),
          bottomNavigationBar: SongBottomBar(
            previousNumber: _index > 0 ? songs[_index - 1].number : null,
            nextNumber: _index < songs.length - 1 ? songs[_index + 1].number : null,
            onPrevious: () => _turnTo(_index - 1),
            onNext: () => _turnTo(_index + 1),
            onGoToNumber: _showSearchDialog,
          ),
        );
      },
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
    final target = await showGoToSongDialog(context, widget.viewModel);
    if (!mounted || target == null) {
      return;
    }
    // Opening the book at a page, not turning through the pages in between: no animation.
    _pageController.jumpToPage(_indexOf(target));
  }

  /// Turns to the neighboring page like the swipe does; without animation when the system asks for less motion.
  void _turnTo(int index) {
    if (index < 0 || index >= _songs.length) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(index);
    } else {
      _pageController.animateToPage(index, duration: Durations.medium2, curve: Easing.standard);
    }
  }
}
