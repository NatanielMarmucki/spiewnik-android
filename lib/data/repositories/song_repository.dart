import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/objectbox.g.dart';

/// The songbook loaded from the asset. The only way for view models to reach the database.
abstract class SongRepository {
  /// All songs, in the order they are stored in. There is no explicit sorting yet
  /// (see "Lista pieśni: sortowanie" in docs/PARITY.md).
  List<Song> all();

  List<Song> favorites();

  /// How many songs the songbook has.
  int count();

  Song? byNumber(int number);

  void setFavorite(Song song, bool favorite);
}

class ObjectBoxSongRepository implements SongRepository {
  final Store _store;

  ObjectBoxSongRepository(this._store);

  @override
  List<Song> all() => _store.box<Song>().getAll();

  @override
  int count() => _store.box<Song>().count();

  @override
  List<Song> favorites() {
    final query = _store.box<Song>().query(Song_.favorite.equals(true)).build();
    try {
      return query.find();
    } finally {
      query.close();
    }
  }

  @override
  Song? byNumber(int number) {
    final query = _store.box<Song>().query(Song_.number.equals(number)).build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  @override
  void setFavorite(Song song, bool favorite) {
    song.favorite = favorite;
    _store.box<Song>().put(song);
  }
}
