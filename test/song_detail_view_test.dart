import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/model/font_size_model.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/view/song_detail_view.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';

import 'support/fakes/fake_song_repository.dart';
import 'support/platform_fakes.dart';

void main() {
  late SongViewModel viewModel;
  late FakeWakelock wakelock;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Numbers 1, 2, 4 and 5: 3 is a gap in the numbering, so the songbook has 4 songs.
    viewModel = SongViewModel(
      FakeSongRepository([
        for (final number in [1, 2, 4, 5])
          Song(number: number, title: 'Pieśń $number', content: 'treść $number', favorite: false),
      ]),
    );
    wakelock = FakeWakelock()..install();
  });

  tearDown(() => wakelock.uninstall());

  Future<void> openSong(WidgetTester tester, int number) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => FontSizeModel(),
        child: MaterialApp(
          theme: lightTheme,
          home: SongDetailView(song: viewModel.findSongByNumber(number)!, viewModel: viewModel),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> goToNumber(WidgetTester tester, String input) async {
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), input);
    await tester.tap(find.text('Przejdź'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens the song with the typed number', (tester) async {
    await openSong(tester, 1);

    await goToNumber(tester, '4');

    expect(find.text('4. Pieśń 4'), findsOneWidget);
    expect(find.text('treść 4'), findsOneWidget);
  });

  testWidgets('shows how many songs there are when the number is outside the songbook', (tester) async {
    await openSong(tester, 1);

    await goToNumber(tester, '9');

    expect(find.text('Podano niepoprawny numer. W śpiewniku znajduje się 4 pieśni.'), findsOneWidget);
    expect(find.text('1. Pieśń 1'), findsOneWidget);
  });

  testWidgets('shows a message for a number that is missing from the songbook', (tester) async {
    await openSong(tester, 1);

    await goToNumber(tester, '3');

    expect(find.text('Pieśń o podanym numerze nie została znaleziona'), findsOneWidget);
  });

  testWidgets('cancelling the dialog stays on the song', (tester) async {
    await openSong(tester, 1);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4');
    await tester.tap(find.text('Anuluj'));
    await tester.pumpAndSettle();

    expect(find.text('1. Pieśń 1'), findsOneWidget);
  });
}
