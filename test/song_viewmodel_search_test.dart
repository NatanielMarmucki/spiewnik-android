import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/model/polish_collation.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';

import 'support/fakes/fake_song_repository.dart';

void main() {
  late SongViewModel viewModel;

  setUp(() {
    final repository = FakeSongRepository([
      Song(number: 1, title: 'Źródło', content: 'Źródło wody żywej', favorite: false),
      Song(number: 2, title: 'Zrodlo', content: 'Zrodlo bez ogonkow', favorite: false),
      Song(number: 3, title: 'Żniwo', content: 'ŻNIWO WIELKIE, ŁASKA PANA', favorite: false),
      Song(number: 12, title: 'Inna', content: '1. Chwalcie, ludy, Pana!', favorite: false),
    ]);
    viewModel = SongViewModel(repository);
  });

  List<int> search(String query) {
    viewModel.searchText = query;
    return viewModel.filteredSongsNotifier.value.map((song) => song.number).toList();
  }

  group('search', () {
    test('a query without diacritics finds text with and without them', () {
      expect(search('zrodlo'), [1, 2]);
    });

    test('a query with diacritics finds text with and without them', () {
      expect(search('źródło'), [1, 2]);
    });

    test('ignores letter case, also for Polish capital letters', () {
      expect(search('zniwo wielkie'), [3]);
      expect(search('Łaska'), [3]);
      expect(search('ŻYWEJ'), [1]);
    });

    test('still ignores the removed punctuation and matches song numbers', () {
      expect(search('chwalcie ludy pana'), [12]);
      expect(search('12'), [12]);
    });

    test('shows all songs for an empty query', () {
      expect(search(''), [1, 2, 3, 12]);
    });
  });

  group('title', () {
    test('a query that matches only the title also finds the song', () {
      expect(search('Żniwo'), [3]);
      expect(search('zniwo'), [3]);
    });

    test('returns the matched part of the title with its original letters', () {
      viewModel.searchText = 'zrodlo';
      final song = viewModel.filteredSongsNotifier.value.firstWhere((song) => song.number == 1);

      expect(viewModel.titleMatches(song), ['Źródło']);
    });

    test('returns nothing when the title does not match', () {
      viewModel.searchText = 'ogonkow';
      final song = viewModel.filteredSongsNotifier.value.single;

      expect(song.number, 2);
      expect(viewModel.titleMatches(song), isEmpty);
    });

    test('an empty query highlights nothing', () {
      viewModel.searchText = '';

      expect(viewModel.titleMatches(viewModel.filteredSongsNotifier.value.first), isEmpty);
    });
  });

  group('removePolishDiacritics', () {
    test('replaces every Polish letter with its base letter and keeps letter case', () {
      expect(removePolishDiacritics('ąćęłńóśźż ĄĆĘŁŃÓŚŹŻ'), 'acelnoszz ACELNOSZZ');
    });

    test('keeps other characters unchanged', () {
      expect(removePolishDiacritics('Café, „Pieśń” — 12!'), 'Café, „Piesn” — 12!');
    });
  });
}
