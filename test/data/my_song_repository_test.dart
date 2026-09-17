import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/data/repositories/my_song_repository.dart';
import 'package:spiewnik/model/my_song_model.dart';

import '../support/fakes/fake_my_song_repository.dart';
import '../support/test_store.dart';

/// The same expectations for the real repository and for the fake used in view model
/// and widget tests, so the fake cannot drift away from ObjectBox behaviour.
void main() {
  late TestStore testStore;

  setUp(() => testStore = TestStore.open());
  tearDown(() => testStore.close());

  MySong buildMySong(String title, {String content = 'treść'}) {
    final now = DateTime(2026, 9, 17, 12);
    return MySong(title: title, content: content, createdAt: now, updatedAt: now);
  }

  void runContract(String name, MySongRepository Function() open) {
    group(name, () {
      late MySongRepository repository;

      setUp(() => repository = open());

      test('starts empty', () {
        expect(repository.all(), isEmpty);
      });

      test('saving a new song gives it an id and stores it', () {
        final song = buildMySong('Pieśń');

        repository.save(song);

        expect(song.id, isNonZero);
        final stored = repository.all().single;
        expect(stored.id, song.id);
        expect(stored.title, 'Pieśń');
        expect(stored.content, 'treść');
        expect(stored.createdAt.isAtSameMomentAs(song.createdAt), isTrue);
      });

      test('saving an existing song replaces it instead of adding another one', () {
        final song = buildMySong('Przed');
        repository.save(song);

        song.title = 'Po';
        repository.save(song);

        expect(repository.all().map((stored) => stored.title), ['Po']);
      });

      test('lists songs in Polish alphabetical order, ignoring letter case', () {
        for (final title in ['Żniwo', 'baranek', 'Łaska', 'Zbawienie', 'Lampa', 'Ósemka', 'Oda']) {
          repository.save(buildMySong(title));
        }

        expect(
          repository.all().map((song) => song.title),
          ['baranek', 'Lampa', 'Łaska', 'Oda', 'Ósemka', 'Zbawienie', 'Żniwo'],
        );
      });

      test('orders songs with the same title by id, lowest first', () {
        final first = buildMySong('Ta sama');
        final second = buildMySong('ta sama');
        repository.save(first);
        repository.save(second);

        expect(repository.all().map((song) => song.id), [first.id, second.id]);
      });

      test('deletes only the given song', () {
        final kept = buildMySong('Zostaje');
        final removed = buildMySong('Do usunięcia');
        repository.save(kept);
        repository.save(removed);

        repository.delete(removed.id);

        expect(repository.all().map((song) => song.id), [kept.id]);
      });

      test('deleting a song that is not there changes nothing', () {
        repository.save(buildMySong('Zostaje'));

        repository.delete(404);

        expect(repository.all(), hasLength(1));
      });
    });
  }

  runContract('ObjectBoxMySongRepository', () => ObjectBoxMySongRepository(testStore.store));
  runContract('FakeMySongRepository', FakeMySongRepository.new);
}
