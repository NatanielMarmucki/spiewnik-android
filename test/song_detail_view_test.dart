import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/model/font_size_model.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/view/song_detail_view.dart';
import 'package:spiewnik/view/widgets/go_to_number_icon.dart';
import 'package:spiewnik/view/widgets/song_bottom_bar.dart';
import 'package:spiewnik/view/screen_wake_lock.dart';
import 'package:spiewnik/view/widgets/song_content.dart';
import 'package:spiewnik/view/widgets/song_options_sheet.dart';
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
    await tester.tap(find.byType(GoToNumberIcon));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), input);
    await tester.pumpAndSettle(); // the title preview enables the button
    await tester.tap(find.text('Przejdź'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens the song with the entered number', (tester) async {
    await openSong(tester, 1);

    await goToNumber(tester, '4');

    expect(find.text('4. Pieśń 4'), findsOneWidget);
    expect(find.textContaining('treść 4'), findsOneWidget);
  });

  testWidgets('shows the song title as soon as a number is entered', (tester) async {
    await openSong(tester, 1);

    await tester.tap(find.byType(GoToNumberIcon));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4');
    await tester.pumpAndSettle();

    expect(find.text('Pieśń 4'), findsOneWidget, reason: 'podgląd tytułu pod polem');
    expect(find.text('1. Pieśń 1'), findsOneWidget, reason: 'wciąż stoimy na pierwszej pieśni');
  });

  testWidgets('the hint shows the number range taken from the database', (tester) async {
    await openSong(tester, 1);

    await tester.tap(find.byType(GoToNumberIcon));
    await tester.pumpAndSettle();

    expect(find.text('1-4'), findsOneWidget);
  });

  testWidgets('an out-of-range number explains what to enter and disables the button', (tester) async {
    await openSong(tester, 1);

    await tester.tap(find.byType(GoToNumberIcon));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '9');
    await tester.pumpAndSettle();

    expect(find.text('Podaj numer od 1 do 4'), findsOneWidget);
    final button = tester.widget<TextButton>(
      find.ancestor(of: find.text('Przejdź'), matching: find.byType(TextButton)),
    );
    expect(button.onPressed, isNull, reason: 'nie ma dokąd przejść');
  });

  testWidgets('a number from a gap in the numbering says there is no such song', (tester) async {
    await openSong(tester, 1);

    await tester.tap(find.byType(GoToNumberIcon));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '3');
    await tester.pumpAndSettle();

    expect(find.text('Nie ma pieśni o tym numerze'), findsOneWidget);
  });

  testWidgets('Enter works like the „Przejdź” button', (tester) async {
    await openSong(tester, 1);

    await tester.tap(find.byType(GoToNumberIcon));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();

    expect(find.text('4. Pieśń 4'), findsOneWidget);
  });

  testWidgets('the field accepts only digits', (tester) async {
    await openSong(tester, 1);

    await tester.tap(find.byType(GoToNumberIcon));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4a');
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, '4');
  });

  group('bottom bar', () {
    testWidgets('arrows go to the neighboring songs and show their numbers', (tester) async {
      await openSong(tester, 4);

      expect(find.byType(SongBottomBar), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      // The numbers are 1, 2, 4, 5: there is a gap before 4, so the left arrow has no number.
      expect(find.text('5'), findsOneWidget, reason: 'numer następnej pieśni');

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(find.text('5. Pieśń 5'), findsOneWidget);
      expect(find.text('4'), findsOneWidget, reason: 'teraz lewa strzałka pokazuje czwórkę');

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.text('4. Pieśń 4'), findsOneWidget);
    });

    testWidgets('at the end the arrow stays in place but is disabled', (tester) async {
      await openSong(tester, 5); // last song

      expect(find.byIcon(Icons.chevron_right), findsOneWidget, reason: 'strzałka zawsze w tym samym miejscu');

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      expect(find.text('5. Pieśń 5'), findsOneWidget, reason: 'nic się nie dzieje');
    });

    testWidgets('a disabled arrow stays visible in the tertiary text color', (tester) async {
      await openSong(tester, 1); // first song: there is no previous one

      final appColors = Theme.of(tester.element(find.byType(SongBottomBar))).extension<AppColors>()!;
      final arrow = tester.widget<Icon>(find.byIcon(Icons.chevron_left));
      final active = tester.widget<Icon>(find.byIcon(Icons.chevron_right));

      expect(arrow.color, appColors.textTertiary, reason: 'kolor linii dawał 1,24:1');
      expect(active.color, appColors.textSecondary, reason: 'aktywna wciąż mocniejsza');
    });

    testWidgets('the middle of the bar is a magnifier with digits in the lens, without the song number', (tester) async {
      await openSong(tester, 4);

      expect(find.byType(GoToNumberIcon), findsOneWidget);
      // The current song number appears only in the top bar, next to the title.
      expect(find.text('4. Pieśń 4'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(SongBottomBar), matching: find.text('4')),
        findsNothing,
      );

      await tester.tap(find.byType(GoToNumberIcon));
      await tester.pumpAndSettle();

      expect(find.text('Przejdź do pieśni'), findsOneWidget);
    });

    testWidgets('the bottom bar keeps its own height instead of stretching to the screen', (tester) async {
      await openSong(tester, 4);

      final bar = tester.getSize(find.byType(SongBottomBar)).height;
      final screen = tester.getSize(find.byType(Scaffold)).height;

      // A magnifier drawn with CustomPaint can stretch the bar if it is allowed to take
      // the full height from the Scaffold.
      expect(bar, lessThan(screen / 4));
      expect(bar, greaterThanOrEqualTo(SongBottomBar.minHeight));
    });

    testWidgets('swipe and bar lead to the same song, and the keep-screen-on count drops to zero', (tester) async {
      await openSong(tester, 4);

      await tester.drag(find.byType(SongContent), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('5. Pieśń 5'), findsOneWidget);
      expect(ScreenWakeLock.holders, 1, reason: 'jeden otwarty ekran po pushReplacement');

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.text('4. Pieśń 4'), findsOneWidget);
      expect(ScreenWakeLock.holders, 1);

      // Closing the screen: instead of the back button (there is nothing to go back to here) we tear down the tree.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(ScreenWakeLock.holders, 0, reason: 'po wyjściu licznik schodzi do zera');
    });
  });

  group('options sheet', () {
    late FakeShare share;

    setUp(() => share = FakeShare()..install());
    tearDown(() => share.uninstall());

    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
    }

    testWidgets('the bar has a heart and three dots, but no share icon anymore', (tester) async {
      await openSong(tester, 1);

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      expect(find.byIcon(Icons.share), findsNothing, reason: 'udostępnianie przeniosło się do arkusza');
    });

    testWidgets('shows three items, with the current value next to text size', (tester) async {
      await openSong(tester, 1);

      await openSheet(tester);

      expect(find.text('Udostępnij pieśń'), findsOneWidget);
      expect(find.text('Rozmiar tekstu'), findsOneWidget);
      expect(find.text('Kopiuj tekst'), findsOneWidget);
      expect(
        find.text('${FontSizeModel.defaultFontSize.round()}'),
        findsOneWidget,
        reason: 'wartość rozmiaru stoi przy pozycji',
      );
    });

    testWidgets('sharing sends the number, title and lyrics', (tester) async {
      await openSong(tester, 4);

      await openSheet(tester);
      await tester.tap(find.text('Udostępnij pieśń'));
      await tester.pumpAndSettle();

      expect(share.shares, hasLength(1));
      expect(share.shares.single['text'], '4. Pieśń 4\n\ntreść 4');
      expect(share.shares.single['subject'], '4. Pieśń 4');
      expect(find.text('Udostępnij pieśń'), findsNothing, reason: 'arkusz zamyka się przed akcją');
    });

    testWidgets('copying puts the lyrics on the clipboard and confirms', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await openSong(tester, 4);

      await openSheet(tester);
      await tester.tap(find.text('Kopiuj tekst'));
      await tester.pumpAndSettle();

      expect(copied, 'treść 4');
      expect(find.text('Treść skopiowana do schowka'), findsOneWidget);
    });

    testWidgets('sheet items are at least 52 dp tall', (tester) async {
      await openSong(tester, 1);

      await openSheet(tester);

      for (final label in ['Udostępnij pieśń', 'Rozmiar tekstu', 'Kopiuj tekst']) {
        final row = find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;
        expect(tester.getSize(row).height, greaterThanOrEqualTo(SongOptionsSheet.minItemHeight));
      }
    });
  });

  testWidgets('swiping left opens the next song, swiping right the previous one', (tester) async {
    await openSong(tester, 4);

    await tester.drag(find.byType(SongContent), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('5. Pieśń 5'), findsOneWidget);

    await tester.drag(find.byType(SongContent), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.text('4. Pieśń 4'), findsOneWidget);
  });

  testWidgets('swiping does nothing at a gap in the numbering', (tester) async {
    // The numbers are 1, 2, 4, 5: there is no 3 after 2, so there is nowhere to go.
    await openSong(tester, 2);

    await tester.drag(find.byType(SongContent), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(find.text('2. Pieśń 2'), findsOneWidget);
  });

  testWidgets('canceling keeps us on the same song', (tester) async {
    await openSong(tester, 1);

    await tester.tap(find.byType(GoToNumberIcon));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4');
    await tester.tap(find.text('Anuluj'));
    await tester.pumpAndSettle();

    expect(find.text('1. Pieśń 1'), findsOneWidget);
  });
}
