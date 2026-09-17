import 'package:flutter/foundation.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/model/polish_collation.dart';
import 'package:spiewnik/objectbox.g.dart';

class MySongViewModel {
  final Store store;
  final DateTime Function() _now;
  final ValueNotifier<List<MySong>> mySongsNotifier = ValueNotifier([]);

  MySongViewModel(this.store, {DateTime Function()? now}) : _now = now ?? DateTime.now {
    _loadMySongs();
  }

  /// User songs in Polish alphabetical order of titles, ignoring letter case, like the old iOS app.
  /// Songs with the same title are ordered by id, lowest first.
  List<MySong> getMySongs() {
    return store.box<MySong>().getAll()
      ..sort((a, b) {
        final byTitle = comparePolish(a.title, b.title);
        return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
      });
  }

  MySong addSong({required String title, required String content}) {
    final now = _now();
    final song = MySong(title: title, content: content, createdAt: now, updatedAt: now);
    store.box<MySong>().put(song);
    _loadMySongs();
    return song;
  }

  /// Saves new title and content. Returns false and leaves updatedAt untouched when nothing changed.
  bool updateSong(MySong song, {required String title, required String content}) {
    if (song.title == title && song.content == content) {
      return false;
    }
    song
      ..title = title
      ..content = content
      ..updatedAt = _now();
    store.box<MySong>().put(song);
    _loadMySongs();
    return true;
  }

  void deleteSong(MySong song) {
    store.box<MySong>().remove(song.id);
    _loadMySongs();
  }

  void _loadMySongs() {
    mySongsNotifier.value = getMySongs();
  }
}
