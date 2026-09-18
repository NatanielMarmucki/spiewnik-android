import 'dart:async';
import 'package:flutter/material.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';
import 'package:spiewnik/view/widgets/song_list_tile.dart';
import 'song_detail_view.dart';
import 'package:spiewnik/model/song_model.dart';

@immutable
class SongListView extends StatefulWidget {
  final SongViewModel viewModel;

  const SongListView({
    super.key,
    required this.viewModel,
  });

  @override
  SongListViewState createState() => SongListViewState();
}

class SongListViewState extends State<SongListView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      setState(() {
        widget.viewModel.searchText = value;
      });
    });
  }

  void _clearSearch() {
    _controller.clear();
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
    _onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, child) {
              return TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Szukaj',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: value.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.cancel),
                          onPressed: _clearSearch,
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: Theme.of(context)
                            .inputDecorationTheme
                            .border
                            ?.borderSide ??
                        BorderSide.none,
                  ),
                ),
                onChanged: _onSearchChanged,
              );
            },
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<List<Song>>(
            valueListenable: widget.viewModel.filteredSongsNotifier,
            builder: (context, songs, _) {
              // itemExtent null: wiersz rośnie razem z systemowym powiększeniem czcionki.
              return ListView.builder(
                controller: _scrollController,
                itemCount: songs.length,
                itemBuilder: (context, index) {
                  final song = songs[index];
                  return SongListTile(
                    title: song.title,
                    number: song.number,
                    isFavorite: song.favorite,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SongDetailView(song: song, viewModel: widget.viewModel),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
