import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/view/favorite_songs_view.dart';
import 'package:spiewnik/view/my_songs_view.dart';
import 'package:spiewnik/view/song_list_view.dart';
import 'package:spiewnik/view/widgets/empty_state.dart';
import 'package:spiewnik/viewmodel/my_song_viewmodel.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';

import 'support/fakes/fake_my_song_repository.dart';
import 'support/fakes/fake_song_repository.dart';

void main() {
  Widget wrap(Widget body) => MaterialApp(theme: lightTheme, home: Scaffold(body: body));

  testWidgets('no search results: shows a message and a way to clear the search', (tester) async {
    final repository = FakeSongRepository([
      Song(number: 1, title: 'Alleluja', content: 'treść', favorite: false),
    ]);
    await tester.pumpWidget(wrap(SongListView(viewModel: SongViewModel(repository))));

    await tester.enterText(find.byType(TextField), 'qqqq');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Brak wyników'), findsOneWidget);
    // Zapytanie jest w polu i w komunikacie.
    expect(find.descendant(of: find.byType(EmptyState), matching: find.textContaining('qqqq')), findsOneWidget);

    await tester.tap(find.text('Wyczyść wyszukiwanie'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsNothing);
    expect(find.text('Alleluja'), findsOneWidget);
  });

  testWidgets('no favorites: the message says what to do', (tester) async {
    await tester.pumpWidget(wrap(FavoriteSongsView(viewModel: SongViewModel(FakeSongRepository()))));

    expect(find.text('Brak ulubionych'), findsOneWidget);
    expect(find.textContaining('dotknij serca'), findsOneWidget);
  });

  testWidgets('no user songs: the message says what to do', (tester) async {
    await tester.pumpWidget(wrap(MySongsView(viewModel: MySongViewModel(FakeMySongRepository()))));

    expect(find.text('Brak własnych pieśni'), findsOneWidget);
    expect(find.textContaining('plusem w pasku'), findsOneWidget);
  });

  testWidgets('follows the design system: 26 dp icon in the line color, heading at 21', (tester) async {
    await tester.pumpWidget(
      wrap(const EmptyState(icon: Icons.search_off, title: 'Nagłówek', message: 'Zdanie.')),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.search_off));
    expect(icon.size, 26.0);
    expect(icon.color, AppColors.light.line);

    final title = tester.widget<Text>(find.text('Nagłówek'));
    expect(title.style?.fontSize, 21.0);
    expect(title.style?.fontFamily, 'Newsreader');

    final message = tester.widget<Text>(find.text('Zdanie.'));
    expect(message.style?.fontSize, 14.0);
    expect(message.style?.height, 1.55);
  });

  testWidgets('shows no button without an action', (tester) async {
    await tester.pumpWidget(
      wrap(const EmptyState(icon: Icons.favorite_border, title: 'Tytuł', message: 'Zdanie.')),
    );

    expect(find.byType(ElevatedButton), findsNothing);
  });
}
