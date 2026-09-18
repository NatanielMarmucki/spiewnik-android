import 'package:flutter/material.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/view/delete_my_song_dialog.dart';
import 'package:spiewnik/view/my_song_detail_view.dart';
import 'package:spiewnik/view/widgets/empty_state.dart';
import 'package:spiewnik/view/widgets/song_list_tile.dart';
import 'package:spiewnik/viewmodel/my_song_viewmodel.dart';

class MySongsView extends StatelessWidget {
  final MySongViewModel viewModel;

  const MySongsView({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ValueListenableBuilder<List<MySong>>(
            valueListenable: viewModel.mySongsNotifier,
            builder: (context, mySongs, _) {
              if (mySongs.isEmpty) {
                return const EmptyState(
                  icon: Icons.edit_note,
                  title: 'Brak własnych pieśni',
                  message: 'Dodaj własny tekst plusem w pasku u góry. Zostanie tylko na tym urządzeniu.',
                );
              }
              return ListView.builder(
                itemCount: mySongs.length,
                itemBuilder: (context, index) {
                  final song = mySongs[index];
                  return Dismissible(
                    key: ValueKey(song.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) => confirmMySongDeletion(context, song),
                    onDismissed: (_) => viewModel.deleteSong(song),
                    background: Container(
                      padding: const EdgeInsets.only(right: 16.0),
                      alignment: Alignment.centerRight,
                      color: Theme.of(context).colorScheme.error,
                      child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
                    ),
                    child: SongListTile(
                      title: song.title,
                      badge: 'MOJA',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MySongDetailView(song: song, viewModel: viewModel),
                          ),
                        );
                      },
                    ),
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
