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

  group('several words', () {
    // Independent of the search code: word starts found with a regular expression on the plain text.
    List<int> containingAll(List<String> wordStarts) => [
          for (final song in songbook)
            if (wordStarts.every((start) => RegExp('(?<![a-z])$start')
                .hasMatch(removePolishDiacritics('${song.title} ${song.content}'.toLowerCase()))))
              song.number,
        ];

    test('finds a song by words in a different order than in the text', () {
      // Song 9: "Chwałę daj Panu, o duszo moja!" - the phrase "duszo chwałę" appears in no song.
      expect(search('duszo chwałę'), contains(9));
    });

    test('every word must occur, not any of them', () {
      // "duszo" and "chwałę" are searched by their stems "dusz" and "chwal" (see "inflected forms").
      expect(search('duszo chwałę'), containingAll(['dusz', 'chwal']));
      expect(search('duszo chwałę').length, lessThan(containingAll(['dusz']).length));
    });

    test('extra spaces between the words do not matter', () {
      expect(search('  duszo    chwałę '), search('duszo chwałę'));
    });

    test('highlights every word found in the title, with its original letters', () {
      viewModel.searchText = 'panu chwałę';
      final song = viewModel.filteredSongsNotifier.value.firstWhere((song) => song.number == 9);

      expect(viewModel.titleMatches(song), ['Panu', 'Chwałę']);
    });

    test('punctuation in the query is ignored, as in the text', () {
      expect(search('alleluja!'), search('alleluja'));
      expect(search('alleluja!'), hasLength(84));
    });
  });

  group('inflected forms', () {
    test('"chwała" finds a song that only has "chwały"', () {
      // Song 3 "Bądź Panu cześć": "chwały", no form of "chwała" that contains it.
      expect(search('chwała'), contains(3));
      expect(search('chwala'), contains(3));
    });

    test('"matko" finds a song that only has "matka"', () {
      expect(search('matko'), contains(1000)); // "Pewna matka bardzo"
    });

    test('"zbawien" finds "zbawienia"', () {
      expect(search('zbawien'), contains(3));
    });

    test('a word matches the beginning of words in the text, not their middle', () {
      // Song 24 has "pan" only inside "wspaniałości".
      expect(search('pan'), isNot(contains(24)));
      expect(search('pan'), contains(9)); // "Chwałę daj Panu"
    });

    test('a one- or two-letter word matches whole words only, so it does not return everything', () {
      expect(search('o'), contains(9)); // "o duszo moja"
      expect(search('o').length, lessThan(songbook.length ~/ 2));
    });
  });
}

