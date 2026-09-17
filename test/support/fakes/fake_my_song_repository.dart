import 'package:spiewnik/data/repositories/my_song_repository.dart';
import 'package:spiewnik/model/my_song_model.dart';

/// In-memory [MySongRepository] for tests of view models and views.
/// Assigns ids like ObjectBox does: new songs get the next free id.
class FakeMySongRepository implements MySongRepository {
  final List<MySong> songs = [];
  int _nextId = 1;

  FakeMySongRepository([List<MySong> initial = const []]) {
    initial.forEach(save);
  }

  @override
  List<MySong> all() => List.of(songs)..sort(compareMySongs);

  @override
  void save(MySong song) {
    if (song.id == 0) {
      song.id = _nextId++;
      songs.add(song);
      return;
    }
    _nextId = song.id >= _nextId ? song.id + 1 : _nextId;
    final index = songs.indexWhere((stored) => stored.id == song.id);
    if (index == -1) {
      songs.add(song);
    } else {
      songs[index] = song;
    }
  }

  @override
  void delete(int id) => songs.removeWhere((song) => song.id == id);

  void saveAll(Iterable<MySong> songs) => songs.forEach(save);

  MySong? byId(int id) => songs.where((song) => song.id == id).firstOrNull;
}
