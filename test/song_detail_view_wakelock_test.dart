import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/model/font_size_model.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/view/screen_wake_lock.dart';
import 'package:spiewnik/view/song_detail_view.dart';
import 'package:spiewnik/view/widgets/go_to_number_icon.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';

import 'support/platform_fakes.dart';
import 'support/fakes/fake_song_repository.dart';

void main() {
  late SongViewModel viewModel;
  late FakeWakelock wakelock;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    viewModel = SongViewModel(
      FakeSongRepository([
        for (var number = 1; number <= 3; number++)
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

  // Regression tests for #16: the screen does not turn off when switching songs.
  // Then, pushReplacement built the new song screen before disposing the old one, and the old screen's
  // disable came last. Now songs are pages of one screen, but the promise stays the same, whatever the
  // mechanism: switching songs never asks the platform to turn the screen off.
  group('the screen does not turn off when switching songs', () {
    testWidgets('by number', (tester) async {
      await openSong(tester, 1);
      expect(wakelock.toggles, [true]);

      await tester.tap(find.byType(GoToNumberIcon));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '3');
      await tester.pumpAndSettle(); // the title preview enables the button
      await tester.tap(find.text('Przejdź'));
      await tester.pumpAndSettle();

      expect(find.text('3. Pieśń 3'), findsOneWidget);
      expect(wakelock.toggles, isNot(contains(false)), reason: 'toggles: ${wakelock.toggles}');
      expect(wakelock.enabled, isTrue);
    });

    testWidgets('by swiping', (tester) async {
      await openSong(tester, 1);

      await tester.fling(find.text('treść 1'), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('2. Pieśń 2'), findsOneWidget);
      expect(wakelock.toggles, isNot(contains(false)), reason: 'toggles: ${wakelock.toggles}');
      expect(wakelock.enabled, isTrue);
    });

    testWidgets('with the arrows', (tester) async {
      await openSong(tester, 1);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      expect(find.text('1. Pieśń 1'), findsOneWidget);
      expect(wakelock.toggles, isNot(contains(false)), reason: 'toggles: ${wakelock.toggles}');
      expect(wakelock.enabled, isTrue);
    });
  });

  testWidgets('the screen turns off when leaving the song after switching songs', (tester) async {
    await openSong(tester, 1);
    await tester.fling(find.text('treść 1'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(SongDetailView), findsNothing);
    expect(wakelock.toggles.last, isFalse, reason: 'toggles: ${wakelock.toggles}');
    expect(ScreenWakeLock.isHeld, isFalse);
  });
}
