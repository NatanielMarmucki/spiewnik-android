import 'package:flutter/foundation.dart';
import 'package:spiewnik/model/polish_collation.dart';
import 'package:spiewnik/data/repositories/song_repository.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/model/review_model.dart';
import 'package:flutter/material.dart';

class SongViewModel {
  final SongRepository repository;
  final ValueNotifier<List<Song>> allSongsNotifier = ValueNotifier([]);
  final ValueNotifier<List<Song>> favoriteSongsNotifier = ValueNotifier([]);
  final ValueNotifier<List<Song>> filteredSongsNotifier = ValueNotifier([]);
  bool _firstAddition = true;
  final reviewModel = ReviewModel();

  String _searchText = '';

  SongViewModel(this.repository) {
    _loadAllSongs();
    _loadFavoriteSongs();
    _filterSongs();
  }

  set searchText(String value) {
    _searchText = value;
    _filterSongs();
  }

  void _loadAllSongs() {
    allSongsNotifier.value = getAllSongs();
    _filterSongs();
  }

  void _loadFavoriteSongs() {
    favoriteSongsNotifier.value = getFavoriteSongs();
  }

  /// How many songs the songbook has. Used by the "go to number" dialog and the scrollbar label.
  int get songCount => repository.count();

  /// Looks up the song for what the user typed in the "go to number" dialog.
  /// Accepts numbers from 1 to [songCount], like the hardcoded 1..2000 before,
  /// which is the whole songbook as long as the numbering has no gaps.
  GoToSongResult goToNumber(String input) {
    final number = int.tryParse(input.trim());
    if (number == null || number < 1 || number > songCount) {
      return const GoToSongResult(GoToSongOutcome.invalidNumber);
    }
    final song = findSongByNumber(number);
    return song == null
        ? const GoToSongResult(GoToSongOutcome.notFound)
        : GoToSongResult(GoToSongOutcome.found, song);
  }

  List<Song> getAllSongs() => repository.all();

  List<Song> getFavoriteSongs() => repository.favorites();

  Song? findSongByNumber(int number) => repository.byNumber(number);

  void toggleFavoriteStatus(Song song) async {
    repository.setFavorite(song, !song.favorite);
    _loadAllSongs();
    _loadFavoriteSongs();

    if (song.favorite && _firstAddition) {
      _firstAddition = false;
      await reviewModel.requestReview();
    }
  }

  void _filterSongs() {
    if (_searchText.isEmpty) {
      filteredSongsNotifier.value = List.from(allSongsNotifier.value);
      return;
    }

    // Diacritics are removed from both sides, so "zrodlo" finds "źródło" and "źródło" finds "zrodlo".
    final lowercaseSearchText = removePolishDiacritics(_searchText.toLowerCase());
    filteredSongsNotifier.value = allSongsNotifier.value.where((song) {
      final lowercaseContent = removePolishDiacritics(song.content.toLowerCase());
      final cleanedContent = _removeNumber(lowercaseContent);

      return cleanedContent.contains(lowercaseSearchText) ||
          song.number.toString().contains(_searchText);
    }).toList();
  }

  String _removeNumber(String str) {
    const charactersToRemove = "123456789,.;:'[]()!?-”—„x";
    final filteredCharacters = str.split('').where((char) => !charactersToRemove.contains(char)).join().trim();
    return filteredCharacters;
  }

  Song? findNextSong(int currentNumber) {
    return findSongByNumber(currentNumber + 1);
  }

  Song? findPreviousSong(int currentNumber) {
    return findSongByNumber(currentNumber - 1);
  }
}

enum GoToSongOutcome {
  /// The song is in the songbook.
  found,

  /// Not a number, or outside 1..[SongViewModel.songCount].
  invalidNumber,

  /// A number inside the range, but there is no song with it.
  notFound,
}

class GoToSongResult {
  final GoToSongOutcome outcome;
  final Song? song;

  const GoToSongResult(this.outcome, [this.song]);
}
