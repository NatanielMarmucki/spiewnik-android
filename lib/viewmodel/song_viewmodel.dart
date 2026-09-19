import 'package:flutter/foundation.dart';
import 'package:spiewnik/data/repositories/song_repository.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/model/song_search.dart';
import 'package:flutter/material.dart';

class SongViewModel {
  final SongRepository repository;
  final ValueNotifier<List<Song>> allSongsNotifier = ValueNotifier([]);
  final ValueNotifier<List<Song>> favoriteSongsNotifier = ValueNotifier([]);
  final ValueNotifier<List<Song>> filteredSongsNotifier = ValueNotifier([]);
  final SongSearch _search = SongSearch();
  String _searchText = '';

  SongViewModel(this.repository) {
    _loadAllSongs();
    _loadFavoriteSongs();
    _filterSongs();
  }

  /// Text from the search field. The view asks for it to know whether it shows the full list.
  String get searchText => _searchText;

  set searchText(String value) {
    _searchText = value;
    _filterSongs();
  }

  void _loadAllSongs() {
    allSongsNotifier.value = _getAllSongs();
    _filterSongs();
  }

  void _loadFavoriteSongs() {
    favoriteSongsNotifier.value = _getFavoriteSongs();
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

  // Private on purpose: reads from the repository go only through the notifiers, because a view
  // calling these directly would bypass the list refresh.
  List<Song> _getAllSongs() => repository.all();

  List<Song> _getFavoriteSongs() => repository.favorites();

  Song? findSongByNumber(int number) => repository.byNumber(number);

  void toggleFavoriteStatus(Song song) {
    repository.setFavorite(song, !song.favorite);
    // Both lists, because a favorite changes both the row in the main list and the contents of the favorites list.
    _loadAllSongs();
    _loadFavoriteSongs();
  }

  void _filterSongs() {
    if (_searchText.isEmpty) {
      filteredSongsNotifier.value = List.from(allSongsNotifier.value);
      return;
    }

    // Diacritics are removed from both sides, so "zrodlo" finds "źródło" and "źródło" finds "zrodlo".
    filteredSongsNotifier.value = _search.filter(allSongsNotifier.value, _searchText);
  }

  /// Parts of [song]'s title matching the words of the search, with the original letters; empty when
  /// nothing matches. Used by the list to highlight the hits (docs/DESIGN-SYSTEM.md, section 5).
  List<String> titleMatches(Song song) => _searchText.isEmpty ? const [] : _search.titleMatches(song, _searchText);

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
