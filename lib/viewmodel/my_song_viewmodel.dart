import 'package:flutter/foundation.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/objectbox.g.dart';

class MySongViewModel {
  final Store store;
  final DateTime Function() _now;
  final ValueNotifier<List<MySong>> mySongsNotifier = ValueNotifier([]);

  MySongViewModel(this.store, {DateTime Function()? now}) : _now = now ?? DateTime.now {
    _loadMySongs();
  }

  /// User songs, newest first.
  List<MySong> getMySongs() {
    final query = store.box<MySong>().query().order(MySong_.createdAt, flags: Order.descending).build();
    final songs = query.find();
    query.close();
    return songs;
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
