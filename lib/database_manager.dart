import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:objectbox/objectbox.dart';
import 'package:sqflite/sqflite.dart';
import 'package:spiewnik/model/song_model.dart';

class DatabaseManager {
  final Store objectBoxStore;

  DatabaseManager(this.objectBoxStore);

  Future<void> initializeDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = '${documentsDirectory.path}/songs.sqlite';
    Database sqliteDb = await openDatabase(path);

    final songBox = objectBoxStore.box<Song>();

    if (songBox.isEmpty()) {
      await migrateDatabase(sqliteDb);
    }
  }

  Future<void> migrateDatabase(Database sqliteDb) async {
    final songBox = objectBoxStore.box<Song>();

    final List<Map<String, dynamic>> sqliteSongs = await sqliteDb.rawQuery('SELECT * FROM ZSONG');

    for (final sqliteSong in sqliteSongs) {
      final song = Song(
        id: sqliteSong['id'] as int? ?? 0,
        content: sqliteSong['ZCONTENT'] ?? '',
        favorite: (sqliteSong['ZFAVORITE'] as int?) == 1,
        number: sqliteSong['ZNUMBER'] as int? ?? 0,
        title: sqliteSong['ZTITLE'] ?? '',
      );

      songBox.put(song);
    }
  }
}