import 'package:flutter/material.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/view/confirmation_dialog.dart';
import 'package:spiewnik/viewmodel/my_song_viewmodel.dart';

/// Adds a new user song, or edits [song] when given.
class MySongFormView extends StatefulWidget {
  final MySongViewModel viewModel;
  final MySong? song;

  const MySongFormView({super.key, required this.viewModel, this.song});

  @override
  MySongFormViewState createState() => MySongFormViewState();
}

class MySongFormViewState extends State<MySongFormView> {
  final _formKey = GlobalKey<FormState>();
  late final String _initialTitle;
  late final String _initialContent;
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _initialTitle = widget.song?.title ?? '';
    _initialContent = widget.song?.content ?? '';
    _titleController = TextEditingController(text: _initialTitle)..addListener(_updateHasChanges);
    _contentController = TextEditingController(text: _initialContent)..addListener(_updateHasChanges);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  bool _computeHasChanges() {
    return _titleController.text != _initialTitle || _contentController.text != _initialContent;
  }

  void _updateHasChanges() {
    final hasChanges = _computeHasChanges();
    if (hasChanges != _hasChanges) {
      setState(() => _hasChanges = hasChanges);
    }
  }

  void _handleBlockedPop() {
    // canPop is refreshed on the next frame; check the fields again so the dialog
    // only appears when something really changed.
    if (_computeHasChanges()) {
      _confirmDiscard();
    } else {
      Navigator.of(context).pop(false);
    }
  }

  String? _requireText(String? value, String message) {
    return value == null || value.trim().isEmpty ? message : null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final song = widget.song;
    if (song == null) {
      widget.viewModel.addSong(title: title, content: content);
    } else {
      widget.viewModel.updateSong(song, title: title, content: content);
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _confirmDiscard() async {
    final discard = await showConfirmationDialog(
      context,
      title: 'Odrzucić zmiany?',
      message: 'Wprowadzone zmiany nie zostaną zapisane.',
      confirmLabel: 'Odrzuć',
    );
    if (discard && mounted) {
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contentBorder = Theme.of(context).inputDecorationTheme.border;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBlockedPop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.song == null ? 'Dodaj pieśń' : 'Edytuj pieśń',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'Zapisz',
              onPressed: _save,
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          autovalidateMode: _autovalidateMode,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Tytuł'),
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                validator: (value) => _requireText(value, 'Podaj tytuł pieśni'),
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _contentController,
                decoration: InputDecoration(
                  labelText: 'Treść',
                  alignLabelWithHint: true,
                  border: contentBorder is OutlineInputBorder
                      ? contentBorder.copyWith(borderRadius: BorderRadius.circular(15.0))
                      : null,
                ),
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                minLines: 12,
                maxLines: null,
                validator: (value) => _requireText(value, 'Podaj treść pieśni'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
