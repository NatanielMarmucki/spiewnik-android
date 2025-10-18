import 'package:flutter/material.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';
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
                return const Center(
                  child: Text(
                    'Brak ulubionych pieśni',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                );
              }
              return ListView.builder(
                itemCount: favoriteSongs.length,
                itemBuilder: (context, index) {
                  final song = favoriteSongs[index];
                  return Padding(
                    padding: EdgeInsets.only(top: index == 0 ? 24.0 : 0.0, left: 12.0, right: 12.0, bottom: 1.0),
                    child: Card(
                      shape: RoundedRectangleBorder(
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
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: ListTile(
                              contentPadding:
                              const EdgeInsets.symmetric(vertical: 2.0, horizontal: 16.0),
                              leading: CircleAvatar(
                                backgroundColor:
                                Theme.of(context).colorScheme.primary,
                                child: Text(
                                  song.number.toString(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(
                                song.title,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder:
                                          (context) => SongDetailView(song:
                                      song, viewModel:
                                      viewModel)),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
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