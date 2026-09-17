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
}
