import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/view/delete_my_song_dialog.dart';
import 'package:spiewnik/view/my_song_form_view.dart';
import 'package:spiewnik/viewmodel/my_song_viewmodel.dart';
import 'package:spiewnik/view/screen_wake_lock.dart';
import 'package:spiewnik/view/widgets/song_content.dart';

class MySongDetailView extends StatefulWidget {
  final MySong song;
  final MySongViewModel viewModel;

  const MySongDetailView({super.key, required this.song, required this.viewModel});

  @override
  MySongDetailViewState createState() => MySongDetailViewState();
}

class MySongDetailViewState extends State<MySongDetailView> {
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

  Future<void> _share(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
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

  Widget _buildAction({required IconData icon, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: InkWell(
        onTap: onTap,
        child: Icon(icon, size: 24.0),
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
          Builder(
            builder: (buttonContext) => _buildAction(icon: Icons.share, onTap: () => _share(buttonContext)),
          ),
          _buildAction(icon: Icons.edit, onTap: _edit),
          _buildAction(icon: Icons.delete, onTap: _delete),
        ],
      ),
      body: SongContent(content: widget.song.content),
    );
  }
}
