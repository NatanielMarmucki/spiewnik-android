import 'package:flutter/material.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/view/my_song_detail_view.dart';
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
                return const Center(
                  child: Text(
                    'Brak własnych pieśni',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                );
              }
              return ListView.builder(
                itemCount: mySongs.length,
                itemExtent: 70.0,
                itemBuilder: (context, index) {
                  final song = mySongs[index];
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
                              contentPadding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 16.0),
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                child: const Icon(Icons.edit_note, color: Colors.white),
                              ),
                              title: Text(
                                song.title,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MySongDetailView(song: song, viewModel: viewModel),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
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
