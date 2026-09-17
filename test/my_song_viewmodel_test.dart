import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/viewmodel/my_song_viewmodel.dart';

import 'support/test_store.dart';

void main() {
  late TestStore testStore;

  setUp(() => testStore = TestStore.open());
  tearDown(() => testStore.close());

  MySong buildMySong(String title, DateTime createdAt) {
    return MySong(title: title, content: 'treść', createdAt: createdAt, updatedAt: createdAt);
  }

  test('loads user songs newest first', () {
    testStore.store.box<MySong>().putMany([
      buildMySong('Środkowa', DateTime(2026, 5, 1)),
      buildMySong('Najnowsza', DateTime(2026, 9, 1)),
      buildMySong('Najstarsza', DateTime(2025, 1, 1)),
    ]);

    final viewModel = MySongViewModel(testStore.store);

    expect(viewModel.mySongsNotifier.value.map((song) => song.title), ['Najnowsza', 'Środkowa', 'Najstarsza']);
  });

  test('starts with an empty list when there are no user songs', () {
    expect(MySongViewModel(testStore.store).mySongsNotifier.value, isEmpty);
  });

  group('adding and editing', () {
    late DateTime now;
    late MySongViewModel viewModel;

    setUp(() {
      now = DateTime(2026, 9, 17, 12);
      viewModel = MySongViewModel(testStore.store, now: () => now);
    });

    test('adds a user song with createdAt and updatedAt set to now and shows it first', () {
      viewModel.addSong(title: 'Starsza', content: 'treść');
      now = DateTime(2026, 9, 17, 13);

      final added = viewModel.addSong(title: 'Nowa', content: '1. Zwrotka');

      final stored = testStore.store.box<MySong>().get(added.id)!;
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

      final stored = testStore.store.box<MySong>().get(song.id)!;
      expect(updated, isTrue);
      expect(stored.title, 'Po');
      expect(stored.content, 'nowa treść');
      expect(stored.createdAt.isAtSameMomentAs(createdAt), isTrue);
      expect(stored.updatedAt.isAtSameMomentAs(now), isTrue);
      expect(viewModel.mySongsNotifier.value.single.title, 'Po');
    });

    test('editing without changes leaves updatedAt untouched', () {
      final createdAt = now;
      final song = viewModel.addSong(title: 'Bez zmian', content: 'treść');
      now = DateTime(2026, 9, 18, 8);

      final updated = viewModel.updateSong(song, title: 'Bez zmian', content: 'treść');

      expect(updated, isFalse);
      expect(testStore.store.box<MySong>().get(song.id)!.updatedAt.isAtSameMomentAs(createdAt), isTrue);
    });
  });
}
