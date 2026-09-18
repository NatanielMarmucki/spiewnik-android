import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/model/font_size_model.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/view/my_song_detail_view.dart';
import 'package:spiewnik/view/my_song_form_view.dart';
import 'package:spiewnik/view/my_songs_view.dart';
import 'package:spiewnik/viewmodel/my_song_viewmodel.dart';

import 'support/fakes/fake_my_song_repository.dart';
import 'support/platform_fakes.dart';

void main() {
  late FakeMySongRepository repository;
  late MySongViewModel viewModel;
  late FakeWakelock wakelock;
  late FakeShare share;

  setUp(() {
    SharedPreferences.setMockInitialValues({'fontSize': 22.0, 'lineHeight': 1.75});
    repository = FakeMySongRepository();
    viewModel = MySongViewModel(repository);
    wakelock = FakeWakelock()..install();
    share = FakeShare()..install();
  });

  tearDown(() {
    wakelock.uninstall();
    share.uninstall();
  });

  /// Shows the user songs list; songs are opened by tapping them, like in the app.
  Future<void> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => FontSizeModel(),
        child: MaterialApp(theme: lightTheme, home: Scaffold(body: MySongsView(viewModel: viewModel))),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSong(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  testWidgets('opens a user song from the list and shows its title and content', (tester) async {
    viewModel.addSong(title: 'Moja pieśń', content: '1. Pierwsza zwrotka\n\n2. Druga zwrotka');
    await pumpList(tester);

    await openSong(tester, 'Moja pieśń');

    expect(find.byType(MySongDetailView), findsOneWidget);
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('Moja pieśń')), findsOneWidget);
    expect(find.text('1. Pierwsza zwrotka\n\n2. Druga zwrotka'), findsOneWidget);
  });

  testWidgets('shows the content with the font size and line height from settings', (tester) async {
    viewModel.addSong(title: 'Moja pieśń', content: 'Treść pieśni');
    await pumpList(tester);

    await openSong(tester, 'Moja pieśń');

    final style = tester.widget<Text>(find.text('Treść pieśni')).style!;
    expect(style.fontSize, 22.0);
    expect(style.height, 1.75);
  });

  testWidgets('keeps the screen on while the song is open and releases it after leaving', (tester) async {
    viewModel.addSong(title: 'Moja pieśń', content: 'Treść');
    await pumpList(tester);

    await openSong(tester, 'Moja pieśń');
    expect(wakelock.toggles, [true]);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(wakelock.toggles, [true, false]);
  });

  testWidgets('shares the song content through the system share sheet', (tester) async {
    viewModel.addSong(title: 'Moja pieśń', content: '1. Zwrotka do udostępnienia');
    await pumpList(tester);
    await openSong(tester, 'Moja pieśń');

    await tester.tap(find.byIcon(Icons.share));
    await tester.pumpAndSettle();

    expect(share.shares, hasLength(1));
    expect(share.shares.single['text'], '1. Zwrotka do udostępnienia');
    expect(share.shares.single['subject'], 'Moja pieśń');
    expect(share.shares.single['originWidth'], greaterThan(0));
  });

  group('deleting from the preview', () {
    testWidgets('asks for confirmation and keeps the song when cancelled', (tester) async {
      final song = viewModel.addSong(title: 'Moja pieśń', content: 'Treść');
      await pumpList(tester);
      await openSong(tester, 'Moja pieśń');

      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();
      expect(find.text('Usunąć pieśń?'), findsOneWidget);
      expect(find.text('Pieśń „Moja pieśń” zostanie trwale usunięta.'), findsOneWidget);
      await tester.tap(find.text('Anuluj'));
      await tester.pumpAndSettle();

      expect(find.byType(MySongDetailView), findsOneWidget);
      expect(repository.byId(song.id), isNotNull);
    });

    testWidgets('deletes the song after confirmation and returns to the list', (tester) async {
      final song = viewModel.addSong(title: 'Moja pieśń', content: 'Treść');
      await pumpList(tester);
      await openSong(tester, 'Moja pieśń');

      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usuń'));
      await tester.pumpAndSettle();

      expect(find.byType(MySongDetailView), findsNothing);
      expect(repository.byId(song.id), isNull);
      expect(find.text('Brak własnych pieśni'), findsOneWidget);
      expect(wakelock.toggles, [true, false]);
    });
  });

  testWidgets('edits the open song and shows the saved changes', (tester) async {
    final song = viewModel.addSong(title: 'Przed edycją', content: 'Stara treść');
    await pumpList(tester);
    await openSong(tester, 'Przed edycją');

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
    expect(find.byType(MySongFormView), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Tytuł'), 'Po edycji');
    await tester.enterText(find.widgetWithText(TextFormField, 'Treść'), 'Nowa treść');
    await tester.pump();
    await tester.tap(find.byTooltip('Zapisz'));
    await tester.pumpAndSettle();

    expect(find.byType(MySongDetailView), findsOneWidget);
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('Po edycji')), findsOneWidget);
    expect(find.text('Nowa treść'), findsOneWidget);
    expect(repository.byId(song.id)!.content, 'Nowa treść');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Po edycji'), findsOneWidget);
    expect(find.text('Przed edycją'), findsNothing);
  });
}
