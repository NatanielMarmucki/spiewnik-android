import 'dart:async';
import 'package:flutter/material.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/view/widgets/empty_state.dart';
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
    final appColors = context.appColors;

    return Column(
      children: [
        Padding(
          // Wyszukiwarka jest widoczna zawsze (docs/DESIGN-SYSTEM.md, sekcja 5).
          padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, child) {
              return ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44.0),
                child: TextField(
                  controller: _controller,
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Szukaj',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    prefixIcon: Icon(Icons.search, size: 15.0, color: appColors.textSecondary),
                    prefixIconConstraints: const BoxConstraints(minWidth: 44.0, minHeight: 44.0),
                    suffixIcon: value.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 15.0),
                            // Cel dotknięcia 48 dp, mimo małej ikony.
                            constraints: const BoxConstraints(minWidth: 48.0, minHeight: 48.0),
                            tooltip: 'Wyczyść wyszukiwanie',
                            onPressed: _clearSearch,
                          ),
                  ),
                  onChanged: _onSearchChanged,
                ),
              );
            },
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<List<Song>>(
            valueListenable: widget.viewModel.filteredSongsNotifier,
            builder: (context, songs, _) {
              if (songs.isEmpty) {
                return EmptyState(
                  icon: Icons.search_off,
                  title: 'Brak wyników',
                  message: 'Żadna pieśń nie pasuje do „${_controller.text.trim()}”. '
                      'Spróbuj innego słowa albo wpisz numer pieśni.',
                  actionLabel: 'Wyczyść wyszukiwanie',
                  onAction: _clearSearch,
                );
              }
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
                    highlight: widget.viewModel.titleMatch(song),
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
