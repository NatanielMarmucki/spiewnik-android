import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/data/repositories/song_repository.dart';
import 'package:spiewnik/model/song_model.dart';

import '../support/fakes/fake_song_repository.dart';
import '../support/test_store.dart';

/// The same expectations for the real repository and for the fake used in view model
/// and widget tests, so the fake cannot drift away from ObjectBox behaviour.
void main() {
  late TestStore testStore;

  setUp(() => testStore = TestStore.open());
  tearDown(() => testStore.close());

  Song buildSong(int number, {bool favorite = false}) =>
      Song(number: number, title: 'Pieśń $number', content: 'treść $number', favorite: favorite);

  void runContract(String name, SongRepository Function(List<Song>) open) {
    group(name, () {
      test('lists songs in the order they were stored in', () {
        final repository = open([buildSong(30), buildSong(10), buildSong(20)]);

        expect(repository.all().map((song) => song.number), [30, 10, 20]);
      });

      test('lists only favorites, in the stored order', () {
        final repository = open([buildSong(3, favorite: true), buildSong(1), buildSong(2, favorite: true)]);

        expect(repository.favorites().map((song) => song.number), [3, 2]);
      });

      test('finds a song by number and returns null for a missing one', () {
        final repository = open([buildSong(1), buildSong(2)]);

        expect(repository.byNumber(2)?.title, 'Pieśń 2');
        expect(repository.byNumber(3), isNull);
      });

      test('marking a favorite changes the song and the favorites list', () {
        final repository = open([buildSong(1), buildSong(2)]);
        final song = repository.byNumber(1)!;

        repository.setFavorite(song, true);

        expect(song.favorite, isTrue);
        expect(repository.favorites().map((song) => song.number), [1]);
      });

      test('unmarking a favorite removes it from the favorites list', () {
        final repository = open([buildSong(1, favorite: true)]);

        repository.setFavorite(repository.byNumber(1)!, false);

        expect(repository.favorites(), isEmpty);
      });

      test('has empty lists without songs', () {
        final repository = open([]);

        expect(repository.all(), isEmpty);
        expect(repository.favorites(), isEmpty);
      });
    });
  }

  runContract('ObjectBoxSongRepository', (songs) {
    testStore.store.box<Song>().putMany(songs);
    return ObjectBoxSongRepository(testStore.store);
  });
  runContract('FakeSongRepository', FakeSongRepository.new);
}
