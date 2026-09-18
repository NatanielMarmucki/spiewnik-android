import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/view/delete_my_song_dialog.dart';
import 'package:spiewnik/view/my_song_form_view.dart';
import 'package:spiewnik/viewmodel/my_song_viewmodel.dart';
import 'package:spiewnik/view/screen_wake_lock.dart';
import 'package:spiewnik/view/widgets/song_content.dart';
import 'package:spiewnik/view/widgets/song_options_sheet.dart';

class MySongDetailView extends StatefulWidget {
  final MySong song;
  final MySongViewModel viewModel;

  const MySongDetailView({super.key, required this.song, required this.viewModel});

  @override
  MySongDetailViewState createState() => MySongDetailViewState();
}

class MySongDetailViewState extends State<MySongDetailView> {
  /// Kotwica arkusza udostępniania na iPadzie, gdzie jest to dymek przy przycisku.
  final GlobalKey _optionsButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    ScreenWakeLock.acquire();
  }

  @override
  void dispose() {
    ScreenWakeLock.release();
    super.dispose();
  }

  Future<void> _share() async {
    final box = _optionsButtonKey.currentContext?.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: widget.song.content,
        subject: widget.song.title,
        // Required on iPad, where the share sheet is a popover anchored to the button.
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Future<void> _edit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MySongFormView(viewModel: widget.viewModel, song: widget.song)),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _delete() async {
    final confirmed = await confirmMySongDeletion(context, widget.song);
    if (!confirmed || !mounted) {
      return;
    }
    widget.viewModel.deleteSong(widget.song);
    Navigator.pop(context);
  }

  /// Arkusz opcji spod trzech kropek, tak samo jak w podglądzie pieśni ze śpiewnika.
  /// Pozycje zamykają arkusz **przed** akcją, żeby systemowy arkusz udostępniania ani formularz
  /// nie otwierały się na naszym.
  Future<void> _showOptions() async {
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
            icon: Icons.edit,
            label: 'Edytuj pieśń',
            onTap: () {
              Navigator.pop(sheetContext);
              _edit();
            },
          ),
          SongOption(
            icon: Icons.delete_outline,
            label: 'Usuń pieśń',
            destructive: true,
            onTap: () {
              Navigator.pop(sheetContext);
              _delete();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(
          widget.song.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18.0,
          ),
        ),
        actions: [
          IconButton(
            key: _optionsButtonKey,
            tooltip: 'Opcje pieśni',
            onPressed: _showOptions,
            icon: const Icon(Icons.more_vert, size: 24.0),
          ),
        ],
      ),
      body: SongContent(content: widget.song.content),
    );
  }
}
