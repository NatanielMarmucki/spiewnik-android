// Requires the ObjectBox native library in lib/; run tools/fetch_objectbox_lib.sh first.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/json_manager.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/objectbox.g.dart';

void main() {
  late Directory directory;
  late Store store;
  late Box<MySong> mySongBox;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('my_song_test_');
    store = Store(getObjectBoxModel(), directory: directory.path);
    mySongBox = store.box<MySong>();
  });

  tearDown(() {
    store.close();
    directory.deleteSync(recursive: true);
  });

  MySong buildMySong(String title, DateTime createdAt) {
    return MySong(title: title, content: '1. $title', createdAt: createdAt, updatedAt: createdAt);
  }

  group('MySong CRUD', () {
    test('creates a user song and reads back every field', () {
      final createdAt = DateTime(2026, 9, 17, 14, 30, 5, 123, 456);
      final updatedAt = DateTime(2026, 9, 18, 8, 0, 0, 0, 789);
      final song = MySong(
        title: 'Zażółć gęślą jaźń',
        content: '1. Pierwsza zwrotka\n\nRefren: Alleluja!\n\n2. Druga zwrotka',
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final id = mySongBox.put(song);
      final stored = mySongBox.get(id)!;

      expect(id, greaterThan(0));
      expect(song.id, id);
      expect(stored.title, 'Zażółć gęślą jaźń');
      expect(stored.content, '1. Pierwsza zwrotka\n\nRefren: Alleluja!\n\n2. Druga zwrotka');
      expect(stored.createdAt.isAtSameMomentAs(createdAt), isTrue);
      expect(stored.updatedAt.isAtSameMomentAs(updatedAt), isTrue);
    });

    test('reads user songs ordered by createdAt, newest first', () {
      mySongBox.putMany([
        buildMySong('Środkowa', DateTime(2026, 5, 1)),
        buildMySong('Najstarsza', DateTime(2025, 1, 1)),
        buildMySong('Najnowsza', DateTime(2026, 9, 1)),
      ]);

      final query = mySongBox.query().order(MySong_.createdAt, flags: Order.descending).build();
      final titles = query.find().map((song) => song.title).toList();
      query.close();

      expect(titles, ['Najnowsza', 'Środkowa', 'Najstarsza']);
    });

    test('updates title, content and updatedAt without changing id or createdAt', () {
      final createdAt = DateTime(2026, 1, 1, 10);
      final id = mySongBox.put(buildMySong('Przed edycją', createdAt));
      final editedAt = DateTime(2026, 2, 2, 12, 0, 0, 0, 1);

      final song = mySongBox.get(id)!
        ..title = 'Po edycji'
        ..content = '1. Nowa treść'
        ..updatedAt = editedAt;
      mySongBox.put(song);
      final stored = mySongBox.get(id)!;

      expect(mySongBox.count(), 1);
      expect(stored.title, 'Po edycji');
      expect(stored.content, '1. Nowa treść');
      expect(stored.createdAt.isAtSameMomentAs(createdAt), isTrue);
      expect(stored.updatedAt.isAtSameMomentAs(editedAt), isTrue);
    });

    test('deletes a user song and keeps the others', () {
      final keptId = mySongBox.put(buildMySong('Zostaje', DateTime(2026, 1, 1)));
      final removedId = mySongBox.put(buildMySong('Do usunięcia', DateTime(2026, 1, 2)));

      final removed = mySongBox.remove(removedId);

      expect(removed, isTrue);
      expect(mySongBox.get(removedId), isNull);
      expect(mySongBox.getAll().map((song) => song.id), [keptId]);
    });

    test('reports nothing removed for a missing user song', () {
      expect(mySongBox.remove(999), isFalse);
      expect(mySongBox.get(999), isNull);
    });
  });

  group('MySong independence from songs data', () {
    test('overwriting songs from the asset leaves user songs untouched', () async {
      SharedPreferences.setMockInitialValues({});
      final songBox = store.box<Song>();
      songBox.putMany([
        Song(number: 1, title: 'Stary tytuł', content: 'stara treść', favorite: true),
        Song(number: 2, title: 'Pieśń spoza nowych danych', content: 'treść', favorite: false),
      ]);
      final createdAt = DateTime(2026, 3, 3, 9, 15);
      final mySongId = mySongBox.put(MySong(
        title: 'Stary tytuł',
        content: 'Moja własna treść',
        createdAt: createdAt,
        updatedAt: createdAt,
      ));

      await JsonManager(store, Logger(level: Level.off)).applySongsData(
        SongsData(dataVersion: 2, songs: [Song(number: 1, title: 'Nowy tytuł', content: 'nowa treść', favorite: false)]),
      );

      final songs = songBox.getAll();
      expect(songs.map((song) => song.title), ['Nowy tytuł']);
      expect(songs.single.favorite, isTrue);

      final mySong = mySongBox.get(mySongId)!;
      expect(mySongBox.count(), 1);
      expect(mySong.title, 'Stary tytuł');
      expect(mySong.content, 'Moja własna treść');
      expect(mySong.createdAt.isAtSameMomentAs(createdAt), isTrue);
      expect(mySong.updatedAt.isAtSameMomentAs(createdAt), isTrue);
    });

    test('removing user songs leaves songs from the asset untouched', () {
      final songBox = store.box<Song>();
      songBox.put(Song(number: 7, title: 'Pieśń', content: 'treść', favorite: true));
      mySongBox.put(buildMySong('Moja', DateTime(2026, 1, 1)));

      mySongBox.removeAll();

      expect(mySongBox.isEmpty(), isTrue);
      expect(songBox.count(), 1);
      expect(songBox.getAll().single.favorite, isTrue);
    });
  });
}
