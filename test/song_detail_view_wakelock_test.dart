import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/model/font_size_model.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/view/screen_wake_lock.dart';
import 'package:spiewnik/view/song_detail_view.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';

import 'support/platform_fakes.dart';
import 'support/test_store.dart';

void main() {
  late TestStore testStore;
  late SongViewModel viewModel;
  late FakeWakelock wakelock;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    testStore = TestStore.open();
    testStore.store.box<Song>().putMany([
      for (var number = 1; number <= 3; number++)
        Song(number: number, title: 'Pieśń $number', content: 'treść $number', favorite: false),
    ]);
    viewModel = SongViewModel(testStore.store);
    wakelock = FakeWakelock()..install();
  });

  tearDown(() {
    wakelock.uninstall();
    testStore.close();
  });

  Future<void> openSong(WidgetTester tester, int number) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => FontSizeModel(),
        child: MaterialApp(
          theme: lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SongDetailView(song: viewModel.findSongByNumber(number)!, viewModel: viewModel),
                  ),
                ),
                child: const Text('Otwórz'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Otwórz'));
    await tester.pumpAndSettle();
  }

  // Regression tests: pushReplacement builds the new screen before the old one is disposed, so a plain
  // enable/disable pair turned the screen off while a song was open. See ScreenWakeLock.
  testWidgets('screen stays on after going to another song by number', (tester) async {
    await openSong(tester, 1);
    expect(wakelock.toggles, [true]);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '2');
    await tester.tap(find.text('Przejdź'));
    await tester.pumpAndSettle();

    expect(find.text('2. Pieśń 2'), findsOneWidget);
    expect(wakelock.toggles.last, isTrue, reason: 'toggles: ${wakelock.toggles}');
  });

  testWidgets('screen stays on after swiping to the next song', (tester) async {
    await openSong(tester, 1);

    await tester.drag(find.text('treść 1'), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(find.text('2. Pieśń 2'), findsOneWidget);
    expect(wakelock.toggles.last, isTrue, reason: 'toggles: ${wakelock.toggles}');
  });

  testWidgets('screen turns off when leaving the song after switching songs', (tester) async {
    await openSong(tester, 1);
    await tester.drag(find.text('treść 1'), const Offset(-300, 0));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(SongDetailView), findsNothing);
    expect(wakelock.toggles.last, isFalse, reason: 'toggles: ${wakelock.toggles}');
    expect(ScreenWakeLock.holders, 0);
  });
}
