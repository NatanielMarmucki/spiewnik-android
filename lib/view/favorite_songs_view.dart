import 'package:flutter/material.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';
import 'package:spiewnik/view/widgets/empty_state.dart';
import 'package:spiewnik/view/widgets/song_list_tile.dart';
import 'song_detail_view.dart';
import 'package:spiewnik/model/song_model.dart';

class FavoriteSongsView extends StatelessWidget {
  final SongViewModel viewModel;

  const FavoriteSongsView({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ValueListenableBuilder<List<Song>>(
            valueListenable: viewModel.favoriteSongsNotifier,
            builder: (context, favoriteSongs, _) {
              if (favoriteSongs.isEmpty) {
                return const EmptyState(
                  icon: Icons.favorite_border,
                  title: 'Brak ulubionych',
                  message: 'Otwórz pieśń i dotknij serca w pasku, żeby trzymać ją pod ręką.',
                );
              }
              return ListView.builder(
                itemCount: favoriteSongs.length,
                itemBuilder: (context, index) {
                  final song = favoriteSongs[index];
                  return SongListTile(
                    title: song.title,
                    number: song.number,
                    isFavorite: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SongDetailView(song: song, viewModel: viewModel)),
                      );
                    },
                  );
                },
              );
            },
          ),
        )
      ],
    );
  }
}