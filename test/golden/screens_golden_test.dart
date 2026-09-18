@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/view/favorite_songs_view.dart';
import 'package:spiewnik/view/my_song_detail_view.dart';
import 'package:spiewnik/view/my_song_form_view.dart';
import 'package:spiewnik/view/my_songs_view.dart';
import 'package:spiewnik/view/settings_view.dart';
import 'package:spiewnik/view/song_detail_view.dart';
import 'package:spiewnik/view/song_list_view.dart';
import 'package:spiewnik/viewmodel/my_song_viewmodel.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';

import '../support/fakes/fake_my_song_repository.dart';
import '../support/fakes/fake_song_repository.dart';
import '../support/golden_harness.dart';
import '../support/platform_fakes.dart';

/// Zrzuty wszystkich ekranów w obu motywach, renderowane bez urządzenia.
///
/// Obrazy powstają na Linuksie, bo rasteryzacja czcionek różni się między platformami.
/// Na innych systemach testy są pomijane, żeby lokalne `flutter test` zostało szybkie
/// i zielone; sprawdzasz je przez `tools/golden.sh` (kontener z Linuksem).
void main() {
  // Obrazy w repozytorium pochodzą z Linuksa i tylko tam zgadzają się co do piksela.
  // Na macOS i Windowsie testy są pomijane; sprawdzasz je przez tools/golden.sh.
  final bool skipOnOtherPlatforms = !Platform.isLinux;

  late FakeWakelock wakelock;
  late FakeShare share;

  setUpAll(loadAppFonts);

  setUp(() {
    // Ekrany szczegółów wołają kanały platformy; bez atrap test wywraca się na MissingPluginException.
    wakelock = FakeWakelock()..install();
    share = FakeShare()..install();
  });

  tearDown(() {
    wakelock.uninstall();
    share.uninstall();
  });

  SongViewModel songs({bool empty = false}) =>
      SongViewModel(FakeSongRepository(empty ? [] : sampleSongs()));

  MySongViewModel mySongs({bool empty = false}) {
    final repository = FakeMySongRepository();
    if (!empty) {
      repository.save(sampleMySong());
    }
    return MySongViewModel(repository);
  }

  testWidgets('lista pieśni', (tester) async {
    await goldenScreen(tester, '01-lista-piesni', (context) {
      return Scaffold(appBar: AppBar(title: const Text('Śpiewnik')), body: SongListView(viewModel: songs()));
    });
  }, skip: skipOnOtherPlatforms);

  testWidgets('lista pieśni: wynik wyszukiwania', (tester) async {
    await goldenScreen(
      tester,
      '02-wyszukiwanie-wyniki',
      (context) => Scaffold(appBar: AppBar(title: const Text('Śpiewnik')), body: SongListView(viewModel: songs())),
      afterPump: (tester) async {
        await tester.enterText(find.byType(TextField), 'chwal');
        await tester.pump(const Duration(milliseconds: 400));
      },
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('lista pieśni: brak wyników', (tester) async {
    await goldenScreen(
      tester,
      '03-wyszukiwanie-brak-wynikow',
      (context) => Scaffold(appBar: AppBar(title: const Text('Śpiewnik')), body: SongListView(viewModel: songs())),
      afterPump: (tester) async {
        await tester.enterText(find.byType(TextField), 'qqqq');
        await tester.pump(const Duration(milliseconds: 400));
      },
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('ulubione', (tester) async {
    await goldenScreen(
      tester,
      '04-ulubione',
      (context) => Scaffold(appBar: AppBar(title: const Text('Ulubione')), body: FavoriteSongsView(viewModel: songs())),
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('ulubione: pusta lista', (tester) async {
    await goldenScreen(
      tester,
      '04b-ulubione-puste',
      (context) => Scaffold(
        appBar: AppBar(title: const Text('Ulubione')),
        body: FavoriteSongsView(viewModel: songs(empty: true)),
      ),
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('moje pieśni', (tester) async {
    await goldenScreen(
      tester,
      '05-moje-piesni',
      (context) => Scaffold(appBar: AppBar(title: const Text('Moje pieśni')), body: MySongsView(viewModel: mySongs())),
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('moje pieśni: pusta lista', (tester) async {
    await goldenScreen(
      tester,
      '05b-moje-piesni-puste',
      (context) => Scaffold(
        appBar: AppBar(title: const Text('Moje pieśni')),
        body: MySongsView(viewModel: mySongs(empty: true)),
      ),
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('dialog usuwania własnej pieśni', (tester) async {
    await goldenScreen(
      tester,
      '06-usuwanie-dialog',
      (context) => Scaffold(appBar: AppBar(title: const Text('Moje pieśni')), body: MySongsView(viewModel: mySongs())),
      afterPump: (tester) async {
        await tester.drag(find.text('Wieczorna modlitwa'), const Offset(-600, 0));
        await tester.pumpAndSettle();
      },
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('formularz: puste pola', (tester) async {
    await goldenScreen(tester, '07-formularz-pusty', (context) => MySongFormView(viewModel: mySongs(empty: true)));
  }, skip: skipOnOtherPlatforms);

  testWidgets('formularz: walidacja', (tester) async {
    await goldenScreen(
      tester,
      '08-formularz-walidacja',
      (context) => MySongFormView(viewModel: mySongs(empty: true)),
      afterPump: (tester) async {
        await tester.tap(find.byTooltip('Zapisz'));
        await tester.pumpAndSettle();
      },
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('formularz: dialog odrzucenia zmian', (tester) async {
    await goldenScreen(
      tester,
      '09-formularz-odrzuc-zmiany',
      (context) => MySongFormView(viewModel: mySongs(empty: true)),
      afterPump: (tester) async {
        await tester.enterText(find.byType(TextFormField).first, 'Nowa');
        await tester.pumpAndSettle();
        // Formularz jest tu ekranem startowym, więc nie ma przycisku wstecz:
        // wyjście wywołujemy tak, jak robi to gest systemowy.
        await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
        await tester.pumpAndSettle();
      },
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('podgląd własnej pieśni', (tester) async {
    final viewModel = mySongs();
    await goldenScreen(
      tester,
      '10-podglad-mojej-piesni',
      (context) => MySongDetailView(song: viewModel.getMySongs().single, viewModel: viewModel),
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('szczegóły pieśni', (tester) async {
    final viewModel = songs();
    await goldenScreen(
      tester,
      '12-szczegoly-piesni',
      (context) => SongDetailView(song: viewModel.findSongByNumber(1)!, viewModel: viewModel),
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('szczegóły pieśni: dialog przejścia do numeru', (tester) async {
    final viewModel = songs();
    await goldenScreen(
      tester,
      '13-dialog-przejdz-do-piesni',
      (context) => SongDetailView(song: viewModel.findSongByNumber(1)!, viewModel: viewModel),
      afterPump: (tester) async {
        // warnIfMissed: ikona leży w InkWellu w pasku; ostrzeżenie o trafieniu jest mylące,
        // dialog otwiera się poprawnie.
        await tester.tap(find.byIcon(Icons.search), warnIfMissed: false);
        await tester.pumpAndSettle();
      },
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('szczegóły pieśni: komunikat o numerze', (tester) async {
    final viewModel = songs();
    await goldenScreen(
      tester,
      '14-dialog-uwaga',
      (context) => SongDetailView(song: viewModel.findSongByNumber(1)!, viewModel: viewModel),
      afterPump: (tester) async {
        // warnIfMissed: ikona leży w InkWellu w pasku; ostrzeżenie o trafieniu jest mylące,
        // dialog otwiera się poprawnie.
        await tester.tap(find.byIcon(Icons.search), warnIfMissed: false);
        await tester.pumpAndSettle();
        if (find.text('Przejdź').evaluate().isEmpty) {
          await tester.tap(find.byIcon(Icons.search), warnIfMissed: false);
          await tester.pumpAndSettle();
        }
        // Puste pole to też niepoprawny numer, więc wystarczy zatwierdzić.
        await tester.tap(find.text('Przejdź'));
        await tester.pumpAndSettle();
      },
    );
  }, skip: skipOnOtherPlatforms);

  testWidgets('ustawienia', (tester) async {
    await goldenScreen(tester, '16-ustawienia', (context) => const SettingsView());
  }, skip: skipOnOtherPlatforms);

  testWidgets('ustawienia: największy tekst', (tester) async {
    await goldenScreen(
      tester,
      '16b-ustawienia-max',
      (context) => const SettingsView(),
      preferences: const {'fontSize': 30.0, 'lineHeight': 1.8},
    );
  }, skip: skipOnOtherPlatforms);
}
