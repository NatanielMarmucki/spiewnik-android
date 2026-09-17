import 'package:spiewnik/data/repositories/song_repository.dart';
import 'package:spiewnik/model/song_model.dart';

/// In-memory [SongRepository] for tests of view models and views.
class FakeSongRepository implements SongRepository {
  final List<Song> songs = [];
  int _nextId = 1;

  FakeSongRepository([List<Song> initial = const []]) {
    for (final song in initial) {
      if (song.id == 0) {
        song.id = _nextId++;
      }
      songs.add(song);
    }
  }

  @override
  List<Song> all() => List.of(songs);

  @override
  int count() => songs.length;

  @override
  List<Song> favorites() => songs.where((song) => song.favorite).toList();

  @override
  Song? byNumber(int number) => songs.where((song) => song.number == number).firstOrNull;

  @override
  void setFavorite(Song song, bool favorite) {
    song.favorite = favorite;
  }
}
