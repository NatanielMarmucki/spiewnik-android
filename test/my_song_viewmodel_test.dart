import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/viewmodel/my_song_viewmodel.dart';

import 'support/fakes/fake_my_song_repository.dart';

void main() {
  late FakeMySongRepository repository;

  setUp(() => repository = FakeMySongRepository());

  MySong buildMySong(String title, DateTime createdAt) {
    return MySong(title: title, content: 'treść', createdAt: createdAt, updatedAt: createdAt);
  }

  group('order', () {
    List<String> titles(MySongViewModel viewModel) =>
        viewModel.mySongsNotifier.value.map((song) => song.title).toList();

    test('lists user songs alphabetically by title, not by creation date', () {
      repository.saveAll([
        buildMySong('Środkowa', DateTime(2026, 5, 1)),
        buildMySong('Najnowsza', DateTime(2026, 9, 1)),
        buildMySong('Najstarsza', DateTime(2025, 1, 1)),
      ]);

      expect(titles(MySongViewModel(repository)), ['Najnowsza', 'Najstarsza', 'Środkowa']);
    });

    test('puts Polish letters right after their base letters', () {
      repository.saveAll([
        for (final title in ['Żniwo', 'Modlitwa', 'Źródło', 'Ósemka', 'Łaska', 'Zbawienie', 'Oda', 'Lampa'])
          buildMySong(title, DateTime(2026)),
      ]);

      expect(
        titles(MySongViewModel(repository)),
        ['Lampa', 'Łaska', 'Modlitwa', 'Oda', 'Ósemka', 'Zbawienie', 'Źródło', 'Żniwo'],
      );
    });

    test('ignores letter case', () {
      repository.saveAll([
        for (final title in ['baranek', 'CIEBIE', 'Anioł', 'łaska', 'Lampa']) buildMySong(title, DateTime(2026)),
      ]);

      expect(titles(MySongViewModel(repository)), ['Anioł', 'baranek', 'CIEBIE', 'Lampa', 'łaska']);
    });

    test('orders songs with the same title by id, lowest first', () {
      final songs = [
        buildMySong('Ta sama', DateTime(2026, 9, 1)),
        buildMySong('ta sama', DateTime(2026, 1, 1)),
        buildMySong('Ta sama', DateTime(2025, 1, 1)),
      ];
      repository.saveAll(songs);

      final viewModel = MySongViewModel(repository);

      expect(viewModel.mySongsNotifier.value.map((song) => song.id), songs.map((song) => song.id));
    });

    test('puts songs with an empty title first', () {
      repository.saveAll([
        buildMySong('Alleluja', DateTime(2026)),
        buildMySong('', DateTime(2026)),
        buildMySong('1. Psalm', DateTime(2026)),
      ]);

      expect(titles(MySongViewModel(repository)), ['', '1. Psalm', 'Alleluja']);
    });
  });

  test('starts with an empty list when there are no user songs', () {
    expect(MySongViewModel(repository).mySongsNotifier.value, isEmpty);
  });

  group('adding and editing', () {
    late DateTime now;
    late MySongViewModel viewModel;

    setUp(() {
      now = DateTime(2026, 9, 17, 12);
      viewModel = MySongViewModel(repository, now: () => now);
    });

    test('adds a user song with createdAt and updatedAt set to now and shows it in the list', () {
      viewModel.addSong(title: 'Starsza', content: 'treść');
      now = DateTime(2026, 9, 17, 13);

      final added = viewModel.addSong(title: 'Nowa', content: '1. Zwrotka');

      final stored = repository.byId(added.id)!;
      expect(stored.title, 'Nowa');
      expect(stored.content, '1. Zwrotka');
      expect(stored.createdAt.isAtSameMomentAs(now), isTrue);
      expect(stored.updatedAt.isAtSameMomentAs(now), isTrue);
      expect(viewModel.mySongsNotifier.value.map((song) => song.title), ['Nowa', 'Starsza']);
    });

    test('editing saves title and content, updates updatedAt and keeps createdAt', () {
      final createdAt = now;
      final song = viewModel.addSong(title: 'Przed', content: 'stara treść');
      now = DateTime(2026, 9, 18, 8);

      final updated = viewModel.updateSong(song, title: 'Po', content: 'nowa treść');

      final stored = repository.byId(song.id)!;
      expect(updated, isTrue);
      expect(stored.title, 'Po');
      expect(stored.content, 'nowa treść');
      expect(stored.createdAt.isAtSameMomentAs(createdAt), isTrue);
      expect(stored.updatedAt.isAtSameMomentAs(now), isTrue);
      expect(viewModel.mySongsNotifier.value.single.title, 'Po');
    });

    test('deletes a user song and refreshes the list', () {
      final kept = viewModel.addSong(title: 'Zostaje', content: 'treść');
      final removed = viewModel.addSong(title: 'Do usunięcia', content: 'treść');

      viewModel.deleteSong(removed);

      expect(repository.byId(removed.id), isNull);
      expect(viewModel.mySongsNotifier.value.map((song) => song.id), [kept.id]);
    });

    test('editing without changes leaves updatedAt untouched', () {
      final createdAt = now;
      final song = viewModel.addSong(title: 'Bez zmian', content: 'treść');
      now = DateTime(2026, 9, 18, 8);

      final updated = viewModel.updateSong(song, title: 'Bez zmian', content: 'treść');

      expect(updated, isFalse);
      expect(repository.byId(song.id)!.updatedAt.isAtSameMomentAs(createdAt), isTrue);
    });
  });
}
