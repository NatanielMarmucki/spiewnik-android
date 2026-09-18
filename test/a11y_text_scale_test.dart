import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/view/favorite_songs_view.dart';
import 'package:spiewnik/view/my_song_detail_view.dart';
import 'package:spiewnik/view/my_song_form_view.dart';
import 'package:spiewnik/view/my_songs_view.dart';
import 'package:spiewnik/view/settings_view.dart';
import 'package:spiewnik/view/song_detail_view.dart';
import 'package:spiewnik/view/song_list_view.dart';
import 'package:spiewnik/view/widgets/app_navigation_bar.dart';
import 'package:spiewnik/viewmodel/my_song_viewmodel.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';

import 'support/fakes/fake_my_song_repository.dart';
import 'support/fakes/fake_song_repository.dart';
import 'support/platform_fakes.dart';
import 'support/screen_harness.dart';

/// Krok 5c: wszystko działa przy systemowym powiększeniu czcionki ×1,3 i ×2,0
/// (docs/DESIGN-SYSTEM.md, sekcja 6).
///
/// „Działa” znaczy: nic się nie przepełnia (przepełnienie jest w teście wyjątkiem),
/// a treść i akcje wciąż są na ekranie.
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
          Song(number: 1, title: 'Alleluja, chwalcie Pana', content: 'treść pierwszej pieśni', favorite: true),
          Song(number: 1234, title: 'Czego chcesz od nas Panie, za Twe hojne dary', content: 'treść', favorite: false),
        ]),
      );

  MySongViewModel mySongs({bool empty = false}) {
    final repository = FakeMySongRepository();
    if (!empty) {
      final now = DateTime(2026, 9, 18, 12);
      repository.save(MySong(title: 'Wieczorna modlitwa', content: 'treść', createdAt: now, updatedAt: now));
    }
    return MySongViewModel(repository);
  }

  for (final scale in [1.3, 2.0]) {
    group('powiększenie ×$scale', () {
      testWidgets('lista pieśni z wyszukiwarką', (tester) async {
        final viewModel = songs();
        await pumpScreen(
          tester,
          (context) => Scaffold(body: SongListView(viewModel: viewModel)),
          textScale: scale,
        );

        expect(find.text('Alleluja, chwalcie Pana'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('ulubione i moje pieśni, też puste', (tester) async {
        final viewModel = songs();
        await pumpScreen(
          tester,
          (context) => Scaffold(body: FavoriteSongsView(viewModel: viewModel)),
          textScale: scale,
        );
        expect(tester.takeException(), isNull);

        await pumpScreen(
          tester,
          (context) => Scaffold(body: MySongsView(viewModel: mySongs())),
          textScale: scale,
        );
        expect(tester.takeException(), isNull);

        await pumpScreen(
          tester,
          (context) => Scaffold(body: MySongsView(viewModel: mySongs(empty: true))),
          textScale: scale,
        );
        expect(find.text('Brak własnych pieśni'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('dolna nawigacja mieści trzy podpisy', (tester) async {
        await pumpScreen(
          tester,
          (context) => Scaffold(
            body: const SizedBox.shrink(),
            bottomNavigationBar: AppNavigationBar(selectedIndex: 0, onSelected: (_) {}),
          ),
          textScale: scale,
        );

        for (final destination in AppNavigationBar.destinations) {
          expect(find.text(destination.label), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('szczegóły pieśni z paskiem, arkuszem i modalem', (tester) async {
        final viewModel = songs();
        await pumpScreen(
          tester,
          (context) => SongDetailView(song: viewModel.findSongByNumber(1234)!, viewModel: viewModel),
          textScale: scale,
          // Największy rozmiar tekstu pieśni razem z systemowym powiększeniem.
          preferences: const {'fontSize': 30.0, 'lineHeight': 1.8},
        );
        expect(tester.takeException(), isNull, reason: 'pasek z numerami sąsiadów');

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        expect(find.text('Kopiuj tekst'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'arkusz opcji');

        await tester.tapAt(const Offset(200, 50)); // zamknięcie arkusza dotknięciem tła
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.search), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.text('Przejdź do pieśni'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'modal przejścia do numeru');
      });

      testWidgets('podgląd i formularz własnej pieśni', (tester) async {
        final viewModel = mySongs();
        await pumpScreen(
          tester,
          (context) => MySongDetailView(song: viewModel.getMySongs().first, viewModel: viewModel),
          textScale: scale,
        );
        expect(tester.takeException(), isNull);

        await pumpScreen(tester, (context) => MySongFormView(viewModel: viewModel), textScale: scale);
        expect(find.byType(TextFormField), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      });

      testWidgets('ustawienia przy największym rozmiarze tekstu', (tester) async {
        await pumpScreen(
          tester,
          (context) => const SettingsView(),
          textScale: scale,
          preferences: const {'fontSize': 30.0, 'lineHeight': 1.8},
        );

        expect(find.text('Nie gaś ekranu przy pieśni'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Do dołu listy da się dojechać: nic nie zasłania ostatniej sekcji.
        await tester.scrollUntilVisible(find.text('Wersja bazy pieśni'), 300.0);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
