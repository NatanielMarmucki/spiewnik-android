import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/model/font_size_model.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/view/song_detail_view.dart';
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
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), input);
    await tester.pumpAndSettle(); // podgląd tytułu odblokowuje przycisk
    await tester.tap(find.text('Przejdź'));
    await tester.pumpAndSettle();
  }

  testWidgets('otwiera pieśń o wpisanym numerze', (tester) async {
    await openSong(tester, 1);

    await goToNumber(tester, '4');

    expect(find.text('4. Pieśń 4'), findsOneWidget);
    expect(find.textContaining('treść 4'), findsOneWidget);
  });

  testWidgets('pokazuje tytuł pieśni od razu po wpisaniu numeru', (tester) async {
    await openSong(tester, 1);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4');
    await tester.pumpAndSettle();

    expect(find.text('Pieśń 4'), findsOneWidget, reason: 'podgląd tytułu pod polem');
    expect(find.text('1. Pieśń 1'), findsOneWidget, reason: 'wciąż stoimy na pierwszej pieśni');
  });

  testWidgets('podpowiedź pokazuje zakres liczony z bazy', (tester) async {
    await openSong(tester, 1);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.text('1-4'), findsOneWidget);
  });

  testWidgets('numer spoza zakresu tłumaczy, co wpisać, i blokuje przejście', (tester) async {
    await openSong(tester, 1);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '9');
    await tester.pumpAndSettle();

    expect(find.text('Podaj numer od 1 do 4'), findsOneWidget);
    final button = tester.widget<TextButton>(
      find.ancestor(of: find.text('Przejdź'), matching: find.byType(TextButton)),
    );
    expect(button.onPressed, isNull, reason: 'nie ma dokąd przejść');
  });

  testWidgets('numer z dziury w numeracji mówi, że takiej pieśni nie ma', (tester) async {
    await openSong(tester, 1);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '3');
    await tester.pumpAndSettle();

    expect(find.text('Nie ma pieśni o tym numerze'), findsOneWidget);
  });

  testWidgets('Enter działa jak przycisk Przejdź', (tester) async {
    await openSong(tester, 1);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();

    expect(find.text('4. Pieśń 4'), findsOneWidget);
  });

  testWidgets('pole przyjmuje tylko cyfry', (tester) async {
    await openSong(tester, 1);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4a');
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, '4');
  });

  group('pasek pod treścią', () {
    testWidgets('strzałki prowadzą do sąsiednich pieśni i pokazują ich numery', (tester) async {
      await openSong(tester, 4);

      expect(find.byType(SongBottomBar), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      // Numery to 1, 2, 4, 5: przed czwórką jest dziura, więc lewa strzałka nie ma numeru.
      expect(find.text('5'), findsOneWidget, reason: 'numer następnej pieśni');

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(find.text('5. Pieśń 5'), findsOneWidget);
      expect(find.text('4'), findsOneWidget, reason: 'teraz lewa strzałka pokazuje czwórkę');

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.text('4. Pieśń 4'), findsOneWidget);
    });

    testWidgets('na krańcu strzałka zostaje na miejscu, ale jest nieaktywna', (tester) async {
      await openSong(tester, 5); // ostatnia pieśń

      expect(find.byIcon(Icons.chevron_right), findsOneWidget, reason: 'strzałka zawsze w tym samym miejscu');

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      expect(find.text('5. Pieśń 5'), findsOneWidget, reason: 'nic się nie dzieje');
    });

    testWidgets('środek paska otwiera przejście do numeru', (tester) async {
      await openSong(tester, 1);

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(find.text('Przejdź do pieśni'), findsOneWidget);
    });

    testWidgets('gest i pasek prowadzą do tej samej pieśni, a blokada ekranu schodzi do zera', (tester) async {
      await openSong(tester, 4);

      await tester.drag(find.byType(SongContent), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('5. Pieśń 5'), findsOneWidget);
      expect(ScreenWakeLock.holders, 1, reason: 'jeden otwarty ekran po pushReplacement');

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.text('4. Pieśń 4'), findsOneWidget);
      expect(ScreenWakeLock.holders, 1);

      // Zamknięcie ekranu: zamiast przycisku wstecz (tu nie ma nad czym wracać) niszczymy drzewo.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(ScreenWakeLock.holders, 0, reason: 'po wyjściu licznik schodzi do zera');
    });
  });

  group('arkusz opcji', () {
    late FakeShare share;

    setUp(() => share = FakeShare()..install());
    tearDown(() => share.uninstall());

    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
    }

    testWidgets('pasek ma serce i trzy kropki, a ikony udostępniania już nie', (tester) async {
      await openSong(tester, 1);

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      expect(find.byIcon(Icons.share), findsNothing, reason: 'udostępnianie przeniosło się do arkusza');
    });

    testWidgets('pokazuje trzy pozycje, a przy rozmiarze tekstu bieżącą wartość', (tester) async {
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

    testWidgets('udostępnianie wysyła numer, tytuł i treść', (tester) async {
      await openSong(tester, 4);

      await openSheet(tester);
      await tester.tap(find.text('Udostępnij pieśń'));
      await tester.pumpAndSettle();

      expect(share.shares, hasLength(1));
      expect(share.shares.single['text'], '4. Pieśń 4\n\ntreść 4');
      expect(share.shares.single['subject'], '4. Pieśń 4');
      expect(find.text('Udostępnij pieśń'), findsNothing, reason: 'arkusz zamyka się przed akcją');
    });

    testWidgets('kopiowanie wkłada treść do schowka i potwierdza', (tester) async {
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

    testWidgets('pozycje arkusza mają wysokość co najmniej 52 dp', (tester) async {
      await openSong(tester, 1);

      await openSheet(tester);

      for (final label in ['Udostępnij pieśń', 'Rozmiar tekstu', 'Kopiuj tekst']) {
        final row = find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;
        expect(tester.getSize(row).height, greaterThanOrEqualTo(SongOptionsSheet.minItemHeight));
      }
    });
  });

  testWidgets('przeciągnięcie w lewo otwiera następną pieśń, w prawo poprzednią', (tester) async {
    await openSong(tester, 4);

    await tester.drag(find.byType(SongContent), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('5. Pieśń 5'), findsOneWidget);

    await tester.drag(find.byType(SongContent), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.text('4. Pieśń 4'), findsOneWidget);
  });

  testWidgets('przy dziurze w numeracji przeciągnięcie nic nie robi', (tester) async {
    // Numery to 1, 2, 4, 5: po dwójce nie ma trójki, więc nie ma dokąd przejść.
    await openSong(tester, 2);

    await tester.drag(find.byType(SongContent), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(find.text('2. Pieśń 2'), findsOneWidget);
  });

  testWidgets('anulowanie zostawia nas na tej samej pieśni', (tester) async {
    await openSong(tester, 1);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4');
    await tester.tap(find.text('Anuluj'));
    await tester.pumpAndSettle();

    expect(find.text('1. Pieśń 1'), findsOneWidget);
  });
}
