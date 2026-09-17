import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/view/my_songs_view.dart';
import 'package:spiewnik/view/song_list_view.dart';
import 'package:spiewnik/viewmodel/my_song_viewmodel.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';

import 'support/fakes/fake_my_song_repository.dart';
import 'support/fakes/fake_song_repository.dart';

// Both lists must look the same until the redesign replaces them with one shared widget.
void main() {
  late FakeMySongRepository repository;
  late FakeSongRepository songRepository;

  setUp(() {
    repository = FakeMySongRepository();
    songRepository = FakeSongRepository();
  });

  Widget wrap(Widget body) => MaterialApp(theme: lightTheme, home: Scaffold(body: body));

  testWidgets('user song rows have the same size and spacing as song list rows', (tester) async {
    songRepository.songs.add(Song(number: 1, title: 'Pieśń', content: 'treść', favorite: false));
    repository.save(
      MySong(title: 'Moja pieśń', content: '1. Moja pieśń', createdAt: DateTime(2026), updatedAt: DateTime(2026)),
    );

    Map<String, Rect> measureFirstRow() {
      final tile = tester.getRect(find.byType(ListTile).first);
      final avatar = tester.getRect(find.byType(CircleAvatar).first);
      final title = tester.getRect(find.descendant(of: find.byType(ListTile).first, matching: find.byType(Text)).last);
      return {
        'tile': Rect.fromLTWH(tile.left, 0, tile.width, tile.height),
        'avatar': avatar.shift(-tile.topLeft),
        'titleLeft': Rect.fromLTWH(title.left - tile.left, 0, 0, 0),
      };
    }

    await tester.pumpWidget(wrap(SongListView(viewModel: SongViewModel(songRepository))));
    final songRow = measureFirstRow();
    await tester.pumpWidget(wrap(MySongsView(viewModel: MySongViewModel(repository))));
    final mySongRow = measureFirstRow();

    expect(mySongRow, songRow);
  });
}
