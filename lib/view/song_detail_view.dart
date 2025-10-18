import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';
import 'package:provider/provider.dart';
import 'package:spiewnik/model/font_size_model.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
    WakelockPlus.enable();
    song = widget.song;
  }

  @override
  void dispose() {
    WakelockPlus.disable();
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
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                child: Icon(
                  song.favorite ? Icons.favorite : Icons.favorite_border,
                  size: 24.0,
                  color: song.favorite ? Colors.red : null,
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
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
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
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
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
              print('Swipe left');
              _goToNextSong();
            } else if (details.delta.dx > 10) {
              print('Swipe right');
              _goToPreviousSong();
            }
          },
        child: SizedBox.expand(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
              child: Consumer<FontSizeModel>(
            builder: (context, fontSizeModel, child) {
              return SingleChildScrollView(
                child: Text(
                  song.content,
                  style: TextStyle(
                    fontSize: fontSizeModel.fontSize,
                    height: fontSizeModel.lineHeight,
                  ),
                ),
              );
            },
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, Color? color, required VoidCallback onPressed}) {
    return IconButton(
      icon: Icon(icon, color: color),
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      onPressed: onPressed,
    );
  }

  void _showSearchDialog(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final FocusNode focusNode = FocusNode();

    showDialog(
      context: context,
      builder: (context) {
        String input = '';
        final TextEditingController controller = TextEditingController();

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
          title: Text(
            'Przejdź do pieśni',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Podaj numer pieśni, do której chcesz przejść.',
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                focusNode: focusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Numer pieśni',
                  hintStyle: TextStyle(color: isDarkMode ? Colors.white38 : Colors.black38),
                  filled: true,
                  fillColor: isDarkMode ? Colors.black54 : Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide.none,
                  ),
                ),
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
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                  ),
                  child: const Text('Anuluj', style: TextStyle(fontSize: 18)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToSong(context, int.tryParse(input));
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                  ),
                  child: const Text('Przejdź', style: TextStyle(fontSize: 18)),
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
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
          title: Text(
            'Uwaga',
            textAlign: TextAlign.center,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          content: Text(
            message,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK', style: TextStyle(color: Colors.blue)),
            ),
          ],
        );
      },
    );
  }

  void _navigateToSong(BuildContext context, int? number) {
    if (number != null && number >= 1 && number <= 2000) {
      final foundSong = widget.viewModel.findSongByNumber(number);
      if (foundSong != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => SongDetailView(song: foundSong, viewModel: widget.viewModel)),
        );
      } else {
        _showMessageDialog(context, 'Pieśń o podanym numerze nie została znaleziona');
      }
    } else {
      _showMessageDialog(context, 'Podano niepoprawny numer. W śpiewniku znajduje się 2000 pieśni.');
    }
  }

  void _goToNextSong() {
    final nextSong = widget.viewModel.findNextSong(song.number);
    if (nextSong != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SongDetailView(song: nextSong, viewModel: widget.viewModel)),
      );
    }
  }

  void _goToPreviousSong() {
    final previousSong = widget.viewModel.findPreviousSong(song.number);
    if (previousSong != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SongDetailView(song: previousSong, viewModel: widget.viewModel)),
      );
    }
  }
}