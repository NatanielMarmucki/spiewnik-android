import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/view/my_song_detail_view.dart';
import 'package:spiewnik/view/settings_view.dart';
import 'package:spiewnik/view/song_detail_view.dart';
import 'package:spiewnik/view/song_list_view.dart';
import 'package:spiewnik/view/widgets/app_navigation_bar.dart';
import 'package:spiewnik/view/widgets/song_list_tile.dart';
import 'package:spiewnik/viewmodel/my_song_viewmodel.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';

import 'support/fakes/fake_my_song_repository.dart';
import 'support/fakes/fake_song_repository.dart';
import 'support/platform_fakes.dart';
import 'support/screen_harness.dart';

/// Krok 5b: każdy cel dotknięcia ma co najmniej 40 x 48 dp (docs/DESIGN-SYSTEM.md, sekcja 6).
///
/// Mierzone są też stany nieaktywne: strzałka na krańcu śpiewnika zostaje na miejscu, więc
/// musi trzymać swój rozmiar, żeby pasek nie skakał.
void main() {
  late FakeWakelock wakelock;
  late FakeShare share;

  late SemanticsHandle semantics;

  setUp(() {
    wakelock = FakeWakelock()..install();
    share = FakeShare()..install();
  });

  tearDown(() {
    wakelock.uninstall();
    share.uninstall();
  });

  /// Cel dotknięcia bywa większy niż rysunek: Material dokłada wokół ikony obszar reakcji
  /// (`MaterialTapTargetSize.padded`), który widać dopiero w drzewie semantyki. Liczy się to,
  /// co faktycznie łapie palec, czyli większy z dwóch prostokątów.
  void expectTarget(WidgetTester tester, Finder finder, String what) {
    semantics = tester.ensureSemantics();
    final widgetSize = tester.getSize(finder);
    final semanticsSize = tester.getSemantics(finder).rect.size;
    final width = math.max(widgetSize.width, semanticsSize.width);
    final height = math.max(widgetSize.height, semanticsSize.height);
    semantics.dispose();

    expect(width, greaterThanOrEqualTo(40.0), reason: '$what: szerokość celu');
    expect(height, greaterThanOrEqualTo(48.0), reason: '$what: wysokość celu');
  }

  Finder tapRegionOf(Finder inner) => find.ancestor(of: inner, matching: find.byType(InkWell)).first;

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

  testWidgets('wiersz listy i pole wyszukiwania', (tester) async {
    final viewModel = songs();
    await pumpScreen(tester, (context) => Scaffold(body: SongListView(viewModel: viewModel)));

    expectTarget(tester, find.byType(SongListTile).first, 'wiersz listy');

    await tester.enterText(find.byType(TextField), 'Alleluja');
    await tester.pumpAndSettle();
    expectTarget(tester, find.byTooltip('Wyczyść wyszukiwanie'), 'czyszczenie wyszukiwania');
  });

  testWidgets('zakładki dolnej nawigacji, także nieaktywne', (tester) async {
    await pumpScreen(
      tester,
      (context) => Scaffold(
        body: const SizedBox.shrink(),
        bottomNavigationBar: AppNavigationBar(selectedIndex: 0, onSelected: (_) {}),
      ),
    );

    for (final destination in AppNavigationBar.destinations) {
      expectTarget(tester, tapRegionOf(find.text(destination.label)), 'zakładka ${destination.label}');
    }
  });

  group('pasek pieśni', () {
    testWidgets('ikony paska górnego', (tester) async {
      final viewModel = songs();
      await pumpScreen(
        tester,
        (context) => SongDetailView(song: viewModel.findSongByNumber(1)!, viewModel: viewModel),
      );

      expectTarget(tester, find.byTooltip('Dodaj do ulubionych'), 'serce');
      expectTarget(tester, find.byTooltip('Opcje pieśni'), 'trzy kropki');
    });

    testWidgets('strzałki i przejście do numeru, przy nieaktywnej strzałce', (tester) async {
      final viewModel = songs();
      // Pierwsza pieśń: lewa strzałka jest nieaktywna, ale zostaje na miejscu.
      await pumpScreen(
        tester,
        (context) => SongDetailView(song: viewModel.findSongByNumber(1)!, viewModel: viewModel),
      );

      expectTarget(tester, tapRegionOf(find.byIcon(Icons.chevron_left)), 'strzałka wstecz (nieaktywna)');
      expectTarget(tester, tapRegionOf(find.byIcon(Icons.chevron_right)), 'strzałka w przód');
      expectTarget(tester, tapRegionOf(find.byIcon(Icons.search)), 'przejście do numeru');
    });

    testWidgets('pozycje arkusza opcji', (tester) async {
      final viewModel = songs();
      await pumpScreen(
        tester,
        (context) => SongDetailView(song: viewModel.findSongByNumber(1)!, viewModel: viewModel),
      );
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      for (final label in ['Udostępnij pieśń', 'Rozmiar tekstu', 'Kopiuj tekst']) {
        expectTarget(tester, tapRegionOf(find.text(label)), 'arkusz: $label');
      }
    });

    testWidgets('akcje modalu przejścia do numeru, w tym zablokowany przycisk', (tester) async {
      final viewModel = songs();
      await pumpScreen(
        tester,
        (context) => SongDetailView(song: viewModel.findSongByNumber(1)!, viewModel: viewModel),
      );
      await tester.tap(find.byIcon(Icons.search), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Bez wpisanego numeru „Przejdź” jest zablokowany, a mimo to trzyma swój rozmiar.
      expectTarget(tester, find.widgetWithText(TextButton, 'Przejdź'), 'Przejdź (zablokowany)');
      expectTarget(tester, find.widgetWithText(TextButton, 'Anuluj'), 'Anuluj');
    });
  });

  testWidgets('akcje własnej pieśni', (tester) async {
    final viewModel = mySongs();
    await pumpScreen(
      tester,
      (context) => MySongDetailView(song: viewModel.getMySongs().first, viewModel: viewModel),
    );

    for (final label in ['Udostępnij pieśń', 'Edytuj pieśń', 'Usuń pieśń']) {
      expectTarget(tester, find.byTooltip(label), label);
    }
  });

  testWidgets('wiersze ustawień, przełącznik i wybór motywu', (tester) async {
    await pumpScreen(tester, (context) => const SettingsView());

    expectTarget(tester, tapRegionOf(find.text('Nie gaś ekranu przy pieśni')), 'przełącznik blokady');
    expectTarget(tester, tapRegionOf(find.text('Kontakt')), 'ustawienia: Kontakt');
    // Segmenty motywu: każdy osobnym celem, choć siedzą w jednym przełączniku.
    for (final label in ['System', 'Jasny', 'Ciemny']) {
      expectTarget(tester, tapRegionOf(find.text(label)), 'motyw: $label');
    }
    expectTarget(
      tester,
      find.widgetWithText(TextButton, 'Przywróć domyślny rozmiar i interlinię'),
      'reset ustawień czytania',
    );
  });
}
