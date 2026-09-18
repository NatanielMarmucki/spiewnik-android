import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/view/my_songs_view.dart';
import 'package:spiewnik/view/widgets/song_list_tile.dart';
import 'package:spiewnik/viewmodel/my_song_viewmodel.dart';

import 'support/fakes/fake_my_song_repository.dart';

void main() {
  late FakeMySongRepository repository;

  setUp(() => repository = FakeMySongRepository());

  Widget wrap(Widget body) => MaterialApp(theme: lightTheme, home: Scaffold(body: body));

  void putMySongs(List<String> titlesOldestFirst) {
    var day = 1;
    repository.saveAll([
      for (final title in titlesOldestFirst)
        MySong(title: title, content: '1. $title', createdAt: DateTime(2026, 1, day), updatedAt: DateTime(2026, 1, day++)),
    ]);
  }

  testWidgets('shows a message when there are no user songs', (tester) async {
    await tester.pumpWidget(wrap(MySongsView(viewModel: MySongViewModel(repository))));

    expect(find.text('Brak własnych pieśni'), findsOneWidget);
    expect(find.byType(SongListTile), findsNothing);
  });

  testWidgets('lists user songs alphabetically by title', (tester) async {
    putMySongs(['Żniwo', 'Łaska', 'Modlitwa']);

    await tester.pumpWidget(wrap(MySongsView(viewModel: MySongViewModel(repository))));

    final titles = tester.widgetList<SongListTile>(find.byType(SongListTile)).map((tile) => tile.title);
    expect(titles, ['Łaska', 'Modlitwa', 'Żniwo']);
    expect(find.text('Brak własnych pieśni'), findsNothing);
  });

  group('deleting with a swipe', () {
    Future<void> swipeLeft(WidgetTester tester, String title) async {
      await tester.drag(find.text(title), const Offset(-600, 0));
      await tester.pumpAndSettle();
    }

    testWidgets('asks for confirmation and keeps the song when cancelled', (tester) async {
      putMySongs(['Zostaje']);
      await tester.pumpWidget(wrap(MySongsView(viewModel: MySongViewModel(repository))));

      await swipeLeft(tester, 'Zostaje');
      expect(find.text('Usunąć pieśń?'), findsOneWidget);
      expect(find.text('Pieśń „Zostaje” zostanie trwale usunięta.'), findsOneWidget);
      await tester.tap(find.text('Anuluj'));
      await tester.pumpAndSettle();

      expect(find.text('Zostaje'), findsOneWidget);
      expect(tester.getTopLeft(find.byType(SongListTile)).dx, 0.0, reason: 'wiersz wraca na miejsce');
      expect(repository.songs.length, 1);
    });

    testWidgets('deletes only the swiped song after confirmation', (tester) async {
      putMySongs(['Starsza', 'Do usunięcia']);
      await tester.pumpWidget(wrap(MySongsView(viewModel: MySongViewModel(repository))));

      await swipeLeft(tester, 'Do usunięcia');
      await tester.tap(find.text('Usuń'));
      await tester.pumpAndSettle();

      expect(find.text('Do usunięcia'), findsNothing);
      expect(find.text('Starsza'), findsOneWidget);
      expect(repository.songs.map((song) => song.title), ['Starsza']);
    });

    testWidgets('shows the empty list message after deleting the last song', (tester) async {
      putMySongs(['Jedyna']);
      await tester.pumpWidget(wrap(MySongsView(viewModel: MySongViewModel(repository))));

      await swipeLeft(tester, 'Jedyna');
      await tester.tap(find.text('Usuń'));
      await tester.pumpAndSettle();

      expect(find.text('Brak własnych pieśni'), findsOneWidget);
    });

    testWidgets('ignores a swipe to the right', (tester) async {
      putMySongs(['Zostaje']);
      await tester.pumpWidget(wrap(MySongsView(viewModel: MySongViewModel(repository))));

      await tester.drag(find.text('Zostaje'), const Offset(600, 0));
      await tester.pumpAndSettle();

      expect(find.text('Usunąć pieśń?'), findsNothing);
      expect(repository.songs.length, 1);
    });
  });
}
