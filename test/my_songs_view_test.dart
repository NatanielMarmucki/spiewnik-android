import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/view/my_songs_view.dart';
import 'package:spiewnik/view/song_list_view.dart';
import 'package:spiewnik/viewmodel/my_song_viewmodel.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';

import 'support/test_store.dart';

void main() {
  late TestStore testStore;

  setUp(() => testStore = TestStore.open());
  tearDown(() => testStore.close());

  Widget wrap(Widget body) => MaterialApp(theme: lightTheme, home: Scaffold(body: body));

  void putMySongs(List<String> titlesOldestFirst) {
    var day = 1;
    testStore.store.box<MySong>().putMany([
      for (final title in titlesOldestFirst)
        MySong(title: title, content: '1. $title', createdAt: DateTime(2026, 1, day), updatedAt: DateTime(2026, 1, day++)),
    ]);
  }

  testWidgets('shows a message when there are no user songs', (tester) async {
    await tester.pumpWidget(wrap(MySongsView(viewModel: MySongViewModel(testStore.store))));

    expect(find.text('Brak własnych pieśni'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('lists user songs newest first', (tester) async {
    putMySongs(['Pierwsza dodana', 'Druga dodana', 'Trzecia dodana']);

    await tester.pumpWidget(wrap(MySongsView(viewModel: MySongViewModel(testStore.store))));

    final titles = tester.widgetList<ListTile>(find.byType(ListTile)).map((tile) => (tile.title as Text).data);
    expect(titles, ['Trzecia dodana', 'Druga dodana', 'Pierwsza dodana']);
    expect(find.text('Brak własnych pieśni'), findsNothing);
  });

  group('deleting with a swipe', () {
    Future<void> swipeLeft(WidgetTester tester, String title) async {
      await tester.drag(find.text(title), const Offset(-600, 0));
      await tester.pumpAndSettle();
    }

    testWidgets('asks for confirmation and keeps the song when cancelled', (tester) async {
      putMySongs(['Zostaje']);
      await tester.pumpWidget(wrap(MySongsView(viewModel: MySongViewModel(testStore.store))));

      await swipeLeft(tester, 'Zostaje');
      expect(find.text('Usunąć pieśń?'), findsOneWidget);
      expect(find.text('Pieśń „Zostaje” zostanie trwale usunięta.'), findsOneWidget);
      await tester.tap(find.text('Anuluj'));
      await tester.pumpAndSettle();

      expect(find.text('Zostaje'), findsOneWidget);
      expect(tester.getTopLeft(find.byType(ListTile)).dx, greaterThan(0));
      expect(testStore.store.box<MySong>().count(), 1);
    });

    testWidgets('deletes only the swiped song after confirmation', (tester) async {
      putMySongs(['Starsza', 'Do usunięcia']);
      await tester.pumpWidget(wrap(MySongsView(viewModel: MySongViewModel(testStore.store))));

      await swipeLeft(tester, 'Do usunięcia');
      await tester.tap(find.text('Usuń'));
      await tester.pumpAndSettle();

      expect(find.text('Do usunięcia'), findsNothing);
      expect(find.text('Starsza'), findsOneWidget);
      expect(testStore.store.box<MySong>().getAll().map((song) => song.title), ['Starsza']);
    });

    testWidgets('shows the empty list message after deleting the last song', (tester) async {
      putMySongs(['Jedyna']);
      await tester.pumpWidget(wrap(MySongsView(viewModel: MySongViewModel(testStore.store))));

      await swipeLeft(tester, 'Jedyna');
      await tester.tap(find.text('Usuń'));
      await tester.pumpAndSettle();

      expect(find.text('Brak własnych pieśni'), findsOneWidget);
    });

    testWidgets('ignores a swipe to the right', (tester) async {
      putMySongs(['Zostaje']);
      await tester.pumpWidget(wrap(MySongsView(viewModel: MySongViewModel(testStore.store))));

      await tester.drag(find.text('Zostaje'), const Offset(600, 0));
      await tester.pumpAndSettle();

      expect(find.text('Usunąć pieśń?'), findsNothing);
      expect(testStore.store.box<MySong>().count(), 1);
    });
  });

  testWidgets('user song rows have the same size and spacing as song list rows', (tester) async {
    testStore.store.box<Song>().put(Song(number: 1, title: 'Pieśń', content: 'treść', favorite: false));
    putMySongs(['Moja pieśń']);

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

    await tester.pumpWidget(wrap(SongListView(viewModel: SongViewModel(testStore.store))));
    final songRow = measureFirstRow();
    await tester.pumpWidget(wrap(MySongsView(viewModel: MySongViewModel(testStore.store))));
    final mySongRow = measureFirstRow();

    expect(mySongRow, songRow);
  });
}
