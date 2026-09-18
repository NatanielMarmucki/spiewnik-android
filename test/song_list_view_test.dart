import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/view/song_list_view.dart';
import 'package:spiewnik/view/widgets/song_list_tile.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';

import 'support/fakes/fake_song_repository.dart';

void main() {
  late FakeSongRepository repository;

  setUp(() {
    repository = FakeSongRepository([
      Song(number: 1, title: 'Alleluja, chwalcie Pana', content: 'treść 1', favorite: false),
      Song(number: 2, title: 'Barankowi chwałę', content: 'treść 2', favorite: true),
      Song(number: 3, title: 'Źródło', content: 'treść 3', favorite: false),
    ]);
  });

  Future<void> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: Scaffold(body: SongListView(viewModel: SongViewModel(repository))),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  List<SongListTile> tiles(WidgetTester tester) =>
      tester.widgetList<SongListTile>(find.byType(SongListTile)).toList();

  testWidgets('wyszukiwarka jest widoczna od razu, z podpowiedzią z systemu wizualnego', (tester) async {
    await pumpList(tester);

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Numer albo tytuł'), findsOneWidget);
    expect(tester.getSize(find.byType(TextField)).height, greaterThanOrEqualTo(44.0));
  });

  testWidgets('pokazuje pieśni w kolejności numerów', (tester) async {
    await pumpList(tester);

    expect(tiles(tester).map((tile) => tile.number), [1, 2, 3]);
  });

  testWidgets('filtruje po tytule i podświetla trafienie', (tester) async {
    await pumpList(tester);

    await search(tester, 'zrodlo');

    expect(tiles(tester).map((tile) => tile.title), ['Źródło']);
    expect(tiles(tester).single.highlight, 'Źródło');
  });

  testWidgets('filtruje po numerze', (tester) async {
    await pumpList(tester);

    await search(tester, '2');

    expect(tiles(tester).map((tile) => tile.number), [2]);
  });

  testWidgets('krzyżyk pojawia się dopiero przy tekście i czyści wyszukiwanie', (tester) async {
    await pumpList(tester);
    expect(find.byIcon(Icons.close), findsNothing);

    await search(tester, 'zrodlo');
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(tiles(tester).map((tile) => tile.number), [1, 2, 3]);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('filtr czeka na przerwę w pisaniu', (tester) async {
    await pumpList(tester);

    await tester.enterText(find.byType(TextField), 'zrodlo');
    await tester.pump(const Duration(milliseconds: 100));
    expect(tiles(tester), hasLength(3), reason: 'przed upływem debounce lista bez zmian');

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(tiles(tester), hasLength(1));
  });

  testWidgets('serce ulubionej trafia do wiersza', (tester) async {
    await pumpList(tester);

    expect(tiles(tester).firstWhere((tile) => tile.number == 2).isFavorite, isTrue);
    expect(tiles(tester).firstWhere((tile) => tile.number == 1).isFavorite, isFalse);
  });
}
