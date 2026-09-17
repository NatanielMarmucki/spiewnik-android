import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';

import 'support/fakes/fake_song_repository.dart';
import 'support/platform_fakes.dart';

/// Characterization tests: they describe what SongViewModel does today, including the
/// surprising parts, so a refactoring cannot change behaviour unnoticed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSongRepository repository;
  late FakeInAppReview inAppReview;

  setUp(() {
    repository = FakeSongRepository();
    inAppReview = FakeInAppReview()..install();
  });

  tearDown(() => inAppReview.uninstall());

  void putSongs(List<Song> songs) => songs.forEach(repository.songs.add);

  Song song(int number, {String? title, String? content, bool favorite = false}) =>
      Song(number: number, title: title ?? 'Pieśń $number', content: content ?? 'treść $number', favorite: favorite);

  SongViewModel open() => SongViewModel(repository);

  List<int> numbers(List<Song> songs) => songs.map((song) => song.number).toList();

  group('loading', () {
    test('publishes all songs, favorites and the unfiltered list on creation', () {
      putSongs([song(2), song(1, favorite: true), song(3)]);

      final viewModel = open();

      expect(numbers(viewModel.allSongsNotifier.value), [2, 1, 3]);
      expect(numbers(viewModel.favoriteSongsNotifier.value), [1]);
      expect(numbers(viewModel.filteredSongsNotifier.value), [2, 1, 3]);
    });

    test('keeps the order the songs were stored in; there is no explicit sorting', () {
      putSongs([song(30), song(10), song(20)]);

      expect(numbers(open().allSongsNotifier.value), [30, 10, 20]);
    });

    test('has empty lists when there are no songs', () {
      final viewModel = open();

      expect(viewModel.allSongsNotifier.value, isEmpty);
      expect(viewModel.favoriteSongsNotifier.value, isEmpty);
      expect(viewModel.filteredSongsNotifier.value, isEmpty);
    });
  });

  group('finding songs', () {
    test('finds a song by its number, and returns null for a number outside the songbook', () {
      putSongs([song(1), song(2)]);
      final viewModel = open();

      expect(viewModel.findSongByNumber(2)?.number, 2);
      expect(viewModel.findSongByNumber(3), isNull);
    });

    test('next and previous song are the neighbouring numbers, null at the ends', () {
      putSongs([song(1), song(2), song(3)]);
      final viewModel = open();

      expect(viewModel.findNextSong(2)?.number, 3);
      expect(viewModel.findPreviousSong(2)?.number, 1);
      expect(viewModel.findNextSong(3), isNull);
      expect(viewModel.findPreviousSong(1), isNull);
    });

    test('skips a gap in numbering instead of jumping over it', () {
      putSongs([song(1), song(3)]);

      expect(open().findNextSong(1), isNull);
    });
  });

  group('going to a number', () {
    late SongViewModel viewModel;

    setUp(() {
      putSongs([song(1), song(2), song(4)]);
      viewModel = open();
    });

    test('reports how many songs the songbook has', () {
      expect(viewModel.songCount, 4); // Deliberately wrong: throwaway branch to show CI blocking a red test.
    });

    test('finds the song for a number that exists', () {
      final result = viewModel.goToNumber('2');

      expect(result.outcome, GoToSongOutcome.found);
      expect(result.song?.number, 2);
    });

    test('ignores spaces around the number', () {
      expect(viewModel.goToNumber(' 2 ').outcome, GoToSongOutcome.found);
    });

    test('rejects text that is not a number, including an empty input', () {
      for (final input in ['', '   ', 'abc', '1a', '2,5']) {
        expect(viewModel.goToNumber(input).outcome, GoToSongOutcome.invalidNumber, reason: 'input "$input"');
      }
    });

    test('rejects numbers outside the songbook', () {
      for (final input in ['0', '-1', '4', '2000']) {
        expect(viewModel.goToNumber(input).outcome, GoToSongOutcome.invalidNumber, reason: 'input "$input"');
      }
    });

    test('reports a gap in the numbering separately from an invalid number', () {
      putSongs([song(10)]);
      final withGap = open();

      expect(withGap.goToNumber('3').outcome, GoToSongOutcome.notFound);
      expect(withGap.goToNumber('5').outcome, GoToSongOutcome.invalidNumber);
    });
  });

  group('favorites', () {
    test('marking a song updates the song, the favorites list and the full list', () {
      putSongs([song(1), song(2)]);
      final viewModel = open();

      viewModel.toggleFavoriteStatus(viewModel.allSongsNotifier.value.first);

      expect(numbers(viewModel.favoriteSongsNotifier.value), [1]);
      expect(viewModel.allSongsNotifier.value.first.favorite, isTrue);
      expect(repository.byNumber(1)!.favorite, isTrue);
    });

    test('marking a song again removes it from favorites', () {
      putSongs([song(1, favorite: true)]);
      final viewModel = open();

      viewModel.toggleFavoriteStatus(viewModel.allSongsNotifier.value.single);

      expect(viewModel.favoriteSongsNotifier.value, isEmpty);
      expect(repository.byNumber(1)!.favorite, isFalse);
    });

    test('keeps the current search filter', () {
      putSongs([song(1, content: 'Alleluja'), song(2, content: 'Baranek')]);
      final viewModel = open();
      viewModel.searchText = 'alleluja';

      viewModel.toggleFavoriteStatus(viewModel.filteredSongsNotifier.value.single);

      expect(numbers(viewModel.filteredSongsNotifier.value), [1]);
    });

    test('asks for a review the first time a favorite is added, and never again', () async {
      putSongs([song(1), song(2)]);
      final viewModel = open();

      viewModel.toggleFavoriteStatus(viewModel.allSongsNotifier.value.first);
      await Future<void>.delayed(Duration.zero);
      expect(inAppReview.calls, ['isAvailable', 'requestReview']);

      viewModel.toggleFavoriteStatus(viewModel.allSongsNotifier.value.last);
      await Future<void>.delayed(Duration.zero);

      expect(inAppReview.calls, ['isAvailable', 'requestReview']);
    });

    test('does not ask for a review when a favorite is removed', () async {
      putSongs([song(1, favorite: true)]);
      final viewModel = open();

      viewModel.toggleFavoriteStatus(viewModel.allSongsNotifier.value.single);
      await Future<void>.delayed(Duration.zero);

      expect(inAppReview.calls, isEmpty);
    });
  });

  group('search', () {
    late SongViewModel viewModel;

    setUp(() {
      putSongs([
        song(1, title: 'Alleluja', content: '1. Alleluja, chwalcie Pana!'),
        song(2, title: 'Baranek', content: 'Baranku Boży, x zmiłuj się'),
        song(11, title: 'Inna', content: 'Zupełnie różna treść'),
      ]);
      viewModel = open();
    });

    test('an empty query shows every song', () {
      viewModel.searchText = 'alleluja';
      viewModel.searchText = '';

      expect(numbers(viewModel.filteredSongsNotifier.value), [1, 2, 11]);
    });

    test('matches the content, ignoring letter case', () {
      viewModel.searchText = 'CHWALCIE';

      expect(numbers(viewModel.filteredSongsNotifier.value), [1]);
    });

    test('does not match the title when the content does not contain the query', () {
      viewModel.searchText = 'Inna';

      expect(viewModel.filteredSongsNotifier.value, isEmpty);
    });

    test('matches a song number as text, so "1" also matches 11', () {
      viewModel.searchText = '1';

      expect(numbers(viewModel.filteredSongsNotifier.value), [1, 11]);
    });

    test('ignores digits and punctuation in the content, so "alleluja chwalcie" matches', () {
      viewModel.searchText = 'alleluja chwalcie';

      expect(numbers(viewModel.filteredSongsNotifier.value), [1]);
    });

    test('removes the letter x from the content, which leaves a double space behind', () {
      viewModel.searchText = 'boży  zmiłuj';
      expect(numbers(viewModel.filteredSongsNotifier.value), [2]);

      viewModel.searchText = 'boży zmiłuj';
      expect(viewModel.filteredSongsNotifier.value, isEmpty);
    });

    test('searching does not change the full list or the favorites list', () {
      viewModel.searchText = 'alleluja';

      expect(numbers(viewModel.allSongsNotifier.value), [1, 2, 11]);
      expect(viewModel.favoriteSongsNotifier.value, isEmpty);
    });
  });
}
