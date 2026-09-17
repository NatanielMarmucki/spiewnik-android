import 'package:flutter/foundation.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/objectbox.g.dart';

class MySongViewModel {
  final Store store;
  final ValueNotifier<List<MySong>> mySongsNotifier = ValueNotifier([]);

  MySongViewModel(this.store) {
    _loadMySongs();
  }

  /// User songs, newest first.
  List<MySong> getMySongs() {
    final query = store.box<MySong>().query().order(MySong_.createdAt, flags: Order.descending).build();
    final songs = query.find();
    query.close();
    return songs;
  }

  void _loadMySongs() {
    mySongsNotifier.value = getMySongs();
  }
}
