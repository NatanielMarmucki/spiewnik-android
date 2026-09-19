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
    // Real queries: common short words, inflected forms, phrases, numbers, punctuation and extra spaces.
    const queries = [
      'a', 'na', 'pan', 'chwała', 'chwala', 'zbawien', 'baranek', 'boży zmiłuj', 'alleluja!', 'matko',
      '12', '1', '0', 'x', '  jezu   ufam  ', 'ŚWIĘTY', 'duch święty', 'o', 'nie ma',
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
