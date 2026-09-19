import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/json_manager.dart';
import 'package:spiewnik/model/polish_collation.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';

import 'support/fakes/fake_song_repository.dart';

/// Search on the real songbook from the asset, not on made-up strings.
void main() {
  late List<Song> songbook;
  late SongViewModel viewModel;

  setUp(() {
    songbook = SongsData.fromJsonString(File('assets/songs_data.json').readAsStringSync()).songs;
    viewModel = SongViewModel(FakeSongRepository(songbook));
  });

  List<int> search(String query) {
    viewModel.searchText = query;
    return [for (final song in viewModel.filteredSongsNotifier.value) song.number];
  }

  group('normalized text kept in memory', () {
    // Real one-word queries: common short words, inflected forms, numbers, x and 0. Queries of several
    // words or with punctuation behave differently since the words are matched separately (below).
    const queries = [
      'a', 'na', 'pan', 'chwała', 'chwala', 'zbawien', 'baranek', 'matko', '12', '1', '0', 'x', 'ŚWIĘTY', 'o',
    ];

    test('finds exactly what the search without it finds', () {
      for (final query in queries) {
        expect(search(query), _reference(songbook, query), reason: 'query "$query"');
      }
    });

    test('still finds the same after a favorite reloads the songs', () {
      viewModel.toggleFavoriteStatus(songbook.first);
      for (final query in queries) {
        expect(search(query), _reference(viewModel.allSongsNotifier.value, query), reason: 'query "$query"');
      }
    });
  });

  group('several words', () {
    List<int> containingAll(List<String> words) => [
          for (final song in songbook)
            if (words.every(removePolishDiacritics('${song.title} ${song.content}'.toLowerCase()).contains))
              song.number,
        ];

    test('finds a song by words in a different order than in the text', () {
      // Song 9: "Chwałę daj Panu, o duszo moja!" - the phrase "duszo chwałę" appears in no song.
      expect(search('duszo chwałę'), contains(9));
    });

    test('every word must occur, not any of them', () {
      expect(search('duszo chwałę'), containingAll(['duszo', 'chwale']));
      expect(search('duszo chwałę'), hasLength(15));
    });

    test('extra spaces between the words do not matter', () {
      expect(search('  duszo    chwałę '), search('duszo chwałę'));
    });

    test('punctuation in the query is ignored, as in the text', () {
      expect(search('alleluja!'), search('alleluja'));
      expect(search('alleluja!'), hasLength(84));
    });
  });
}

/// The search as it was before the normalized text was kept in memory: everything recomputed per query.
List<int> _reference(List<Song> songs, String query) {
  String normalizeWhitespace(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();
  String removeNumber(String str) {
    const charactersToRemove = "123456789,.;:'[]()!?-”—„x";
    return normalizeWhitespace(str.split('').where((char) => !charactersToRemove.contains(char)).join());
  }

  if (query.isEmpty) return [for (final song in songs) song.number];
  final needle = normalizeWhitespace(removePolishDiacritics(query.toLowerCase()));
  final titleNeedle = removePolishDiacritics(query.toLowerCase());
  return [
    for (final song in songs)
      if ((titleNeedle.isNotEmpty && removePolishDiacritics(song.title.toLowerCase()).contains(titleNeedle)) ||
          removeNumber(removePolishDiacritics(song.content.toLowerCase())).contains(needle) ||
          song.number.toString().contains(query))
        song.number,
  ];
}
