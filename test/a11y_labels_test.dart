import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/view/my_song_detail_view.dart';
import 'package:spiewnik/view/my_song_form_view.dart';
import 'package:spiewnik/view/my_songs_view.dart';
import 'package:spiewnik/view/settings_view.dart';
import 'package:spiewnik/view/song_detail_view.dart';
import 'package:spiewnik/view/song_list_view.dart';
import 'package:spiewnik/viewmodel/my_song_viewmodel.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';

import 'support/fakes/fake_my_song_repository.dart';
import 'support/fakes/fake_song_repository.dart';
import 'support/platform_fakes.dart';
import 'support/screen_harness.dart';

/// Krok 5a: każda ikona-akcja ma etykietę po polsku, a ikony ozdobne nie mają żadnej.
///
/// `labeledTapTargetGuideline` pilnuje, żeby żaden cel dotknięcia nie został niemy —
/// to jest właściwy test, bo łapie też rzeczy dodane później.
void main() {
  late FakeWakelock wakelock;
  late FakeShare share;

  setUp(() {
    wakelock = FakeWakelock()..install();
    share = FakeShare()..install();
  });

  tearDown(() {
    wakelock.uninstall();
    share.uninstall();
  });

  SongViewModel songs() => SongViewModel(
    FakeSongRepository([
      Song(number: 1, title: 'Alleluja, chwalcie Pana', content: 'treść 1', favorite: false),
      Song(number: 2, title: 'Barankowi chwałę', content: 'treść 2', favorite: true),
    ]),
  );

  MySongViewModel mySongs() {
    final repository = FakeMySongRepository();
    final now = DateTime(2026, 9, 18, 12);
    repository.save(MySong(title: 'Wieczorna modlitwa', content: 'treść', createdAt: now, updatedAt: now));
    return MySongViewModel(repository);
  }

  group('every tap target has a label', () {
    testWidgets('song list', (tester) async {
      final handle = tester.ensureSemantics();
      final viewModel = songs();
      await pumpScreen(tester, (context) => Scaffold(body: SongListView(viewModel: viewModel)));
      await tester.enterText(find.byType(TextField), 'Alleluja');
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('song detail with the options sheet', (tester) async {
      final handle = tester.ensureSemantics();
      final viewModel = songs();
      await pumpScreen(
        tester,
        (context) => SongDetailView(song: viewModel.findSongByNumber(1)!, viewModel: viewModel),
      );

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('user songs list, preview and form', (tester) async {
      final handle = tester.ensureSemantics();
      final viewModel = mySongs();
      await pumpScreen(tester, (context) => Scaffold(body: MySongsView(viewModel: viewModel)));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      await pumpScreen(
        tester,
        (context) => MySongDetailView(song: viewModel.getMySongs().first, viewModel: viewModel),
      );
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      await pumpScreen(tester, (context) => MySongFormView(viewModel: viewModel));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('settings', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester, (context) => const SettingsView());

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  group('labels are in Polish and say what the action does', () {
    testWidgets('song app bar and bottom bar', (tester) async {
      final handle = tester.ensureSemantics();
      final viewModel = songs();
      await pumpScreen(
        tester,
        (context) => SongDetailView(song: viewModel.findSongByNumber(1)!, viewModel: viewModel),
      );

      // Przyciski paska niosą etykietę jako podpowiedź (`tooltip`), którą czytnik ekranu czyta.
      expect(find.byTooltip('Dodaj do ulubionych'), findsOneWidget);
      expect(find.byTooltip('Opcje pieśni'), findsOneWidget);
      expect(find.bySemanticsLabel('Poprzednia pieśń'), findsOneWidget, reason: 'pierwsza pieśń: bez numeru');
      expect(find.bySemanticsLabel('Następna pieśń, numer 2'), findsOneWidget);
      expect(find.bySemanticsLabel('Przejdź do pieśni'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('options sheet items', (tester) async {
      final handle = tester.ensureSemantics();
      final viewModel = songs();
      await pumpScreen(
        tester,
        (context) => SongDetailView(song: viewModel.findSongByNumber(1)!, viewModel: viewModel),
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Udostępnij pieśń'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Rozmiar tekstu, ')), findsOneWidget);
      expect(find.bySemanticsLabel('Kopiuj tekst'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('user song actions', (tester) async {
      final handle = tester.ensureSemantics();
      final viewModel = mySongs();
      await pumpScreen(
        tester,
        (context) => MySongDetailView(song: viewModel.getMySongs().first, viewModel: viewModel),
      );

      expect(find.byTooltip('Opcje pieśni'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Udostępnij pieśń'), findsOneWidget);
      expect(find.bySemanticsLabel('Edytuj pieśń'), findsOneWidget);
      expect(find.bySemanticsLabel('Usuń pieśń'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('list row reads number, title and favorite as one label', (tester) async {
      final handle = tester.ensureSemantics();
      final viewModel = songs();
      await pumpScreen(tester, (context) => Scaffold(body: SongListView(viewModel: viewModel)));

      expect(find.bySemanticsLabel('2, Barankowi chwałę, ulubiona'), findsOneWidget);
      handle.dispose();
    });
  });

  testWidgets('empty state icon is decorative and is not read separately', (tester) async {
    final handle = tester.ensureSemantics();
    final viewModel = MySongViewModel(FakeMySongRepository());
    await pumpScreen(tester, (context) => Scaffold(body: MySongsView(viewModel: viewModel)));

    final semantics = tester.getSemantics(find.byType(Icon).first);
    expect(semantics.label, isEmpty);
    handle.dispose();
  });
}
