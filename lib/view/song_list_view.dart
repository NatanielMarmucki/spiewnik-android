import 'dart:async';
import 'package:flutter/material.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';
import 'song_detail_view.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:draggable_scrollbar/draggable_scrollbar.dart';

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
              return DraggableScrollbar.semicircle(
                controller: _scrollController,
                backgroundColor: Theme.of(context).colorScheme.primary,
                labelTextBuilder: (double offset) {
                  if (songs.length != 2000) {
                    return const Text('');
                  }
                  final int currentIndex = (offset ~/ 70);
                  return Text('${currentIndex + 1}');
                },

                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: songs.length,
                  itemExtent: 70.0,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 15.0,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(15.0),
                                  bottomLeft: Radius.circular(15.0),
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.center,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: ListTile(
                                contentPadding:
                                const EdgeInsets.symmetric(vertical: 2.0, horizontal: 16.0),
                                leading: CircleAvatar(
                                  backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                                  child: Text(
                                    song.number.toString(),
                                    style:
                                    const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title:
                                Text(song.title, style:
                                const TextStyle(fontWeight:
                                FontWeight.bold), maxLines:
                                1, overflow:
                                TextOverflow.ellipsis),
                                trailing:
                                Column(mainAxisAlignment:
                                MainAxisAlignment.center, children:
                                [if (song.favorite)
                                  const Icon(Icons.favorite, color:
                                  Colors.red)]),
                                onTap:
                                    () {Navigator.push(context, MaterialPageRoute(builder:
                                    (context) => SongDetailView(song:
                                song, viewModel:
                                    widget.viewModel)));},
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
