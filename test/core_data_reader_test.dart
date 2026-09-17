import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:spiewnik/migration/core_data_reader.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Fixtures in test/fixtures come from the iOS app (see SCHEMA-ZMYSONG.md and test/fixtures/README.md)
/// and tests never modify them:
/// - ios_with_data: database from a simulator with favorites 5 and 12 and one user song
///   (its title and content were edited by hand, see test/fixtures/README.md),
/// - ios_fresh: database from a simulator right after installation,
/// - ios_no_mysong: template database bundled in the iOS repo, without the ZMYSONG table.
void main() {
  const fixturesDirectory = 'test/fixtures';
  late CoreDataReader reader;
  late Directory tempDirectory;
  final originalFixtures = <String, Uint8List>{};

  setUpAll(() {
    sqfliteFfiInit();
    for (final file in Directory(fixturesDirectory).listSync().whereType<File>()) {
      originalFixtures[p.basename(file.path)] = file.readAsBytesSync();
    }
  });

  tearDownAll(() {
    final currentFixtures = {
      for (final file in Directory(fixturesDirectory).listSync().whereType<File>())
        p.basename(file.path): file.readAsBytesSync(),
    };
    expect(currentFixtures.keys.toSet(), originalFixtures.keys.toSet(), reason: 'fixture files were added or removed');
    for (final name in originalFixtures.keys) {
      expect(listEquals(currentFixtures[name], originalFixtures[name]), isTrue, reason: '$name was modified');
    }
  });

  setUp(() {
    reader = CoreDataReader(databaseFactory: databaseFactoryFfiNoIsolate);
    tempDirectory = Directory.systemTemp.createTempSync('core_data_reader_test_');
  });

  tearDown(() => tempDirectory.deleteSync(recursive: true));

  /// Copies a fixture with its -wal and -shm files into [directory] as Model.sqlite.
  String copyFixture(String name, {Directory? directory}) {
    final target = directory ?? tempDirectory;
    final targetPath = p.join(target.path, 'Model.sqlite');
    for (final suffix in ['', '-wal', '-shm']) {
      final source = File(p.join(fixturesDirectory, '$name.sqlite$suffix'));
      if (source.existsSync()) {
        source.copySync('$targetPath$suffix');
      }
    }
    return targetPath;
  }

  /// SYNTHETIC DATA: applies [change] to a copy of a fixture. The connection is closed afterwards,
  /// so the changes end up checkpointed in the main database file.
  Future<void> changeCopy(String path, Future<void> Function(Database database) change) async {
    final database = await databaseFactoryFfiNoIsolate.openDatabase(path);
    await change(database);
    await database.close();
  }

  group('device fixtures', () {
    test('reads favorites and user songs from a database with data', () async {
      final snapshot = await reader.read(copyFixture('ios_with_data'));

      expect(snapshot.favoriteSongNumbers, [5, 12]);
      expect(snapshot.favoriteRowsWithoutNumber, 0);
      expect(snapshot.hasMySongTable, isTrue);
      expect(snapshot.mySongs, hasLength(1));
      expect(snapshot.mySongs.single.primaryKey, 1);
      expect(snapshot.mySongs.single.title, 'Pieśń poranna');
      expect(snapshot.mySongs.single.content, '1. Dziękuję Ci, Panie, za nowy dzień.');
    });

    test('returns no favorites and no user songs for a fresh installation', () async {
      final snapshot = await reader.read(copyFixture('ios_fresh'));

      expect(snapshot.favoriteSongNumbers, isEmpty);
      expect(snapshot.hasMySongTable, isTrue);
      expect(snapshot.mySongs, isEmpty);
    });

    test('treats a database without the ZMYSONG table as having no user songs', () async {
      final snapshot = await reader.read(copyFixture('ios_no_mysong'));

      expect(snapshot.hasMySongTable, isFalse);
      expect(snapshot.mySongs, isEmpty);
      expect(snapshot.favoriteSongNumbers, isEmpty);
    });

    test('leaves the original database and its directory untouched when reading in place', () async {
      final path = copyFixture('ios_with_data');
      final directory = Directory(p.dirname(path));
      List<String> listing() => directory.listSync().map((entity) => p.basename(entity.path)).toList()..sort();
      final filesBefore = listing();
      final bytesBefore = {for (final name in filesBefore) name: File(p.join(directory.path, name)).readAsBytesSync()};

      await reader.read(path);

      expect(listing(), filesBefore);
      for (final name in filesBefore) {
        expect(listEquals(File(p.join(directory.path, name)).readAsBytesSync(), bytesBefore[name]), isTrue,
            reason: '$name changed');
      }
    });
  });

  group('synthetic data (generated on copies of device fixtures)', () {
    test('reads favorites and user songs written only to the -wal file, before any checkpoint', () async {
      // SYNTHETIC DATA: simulates a user marking a favorite and adding a song right before the update,
      // while the iOS app had not checkpointed the WAL yet.
      final workingPath = copyFixture('ios_with_data', directory: Directory(p.join(tempDirectory.path, 'app'))..createSync());
      final database = await databaseFactoryFfiNoIsolate.openDatabase(workingPath);
      expect((await database.rawQuery('PRAGMA journal_mode')).single.values.single, 'wal');
      await database.execute('PRAGMA wal_autocheckpoint = 0');
      await database.rawUpdate('UPDATE ZSONG SET ZFAVORITE = 1 WHERE ZNUMBER = 7');
      await database.rawInsert(
        'INSERT INTO ZMYSONG (Z_PK, Z_ENT, Z_OPT, ZCONTENT, ZTITLE) VALUES (2, 1, 1, ?, ?)',
        ['Treść zapisana tylko w WAL', 'Tuż przed aktualizacją'],
      );

      // Take the files while the connection is still open, as they would be on the device at update time.
      final deviceDirectory = Directory(p.join(tempDirectory.path, 'device'))..createSync();
      final devicePath = p.join(deviceDirectory.path, 'Model.sqlite');
      for (final suffix in ['', '-wal', '-shm']) {
        File('$workingPath$suffix').copySync('$devicePath$suffix');
      }
      await database.close();
      expect(File('$devicePath-wal').lengthSync(), greaterThan(0));

      // Control: without the -wal file the new rows are not visible.
      final mainFileOnlyDirectory = Directory(p.join(tempDirectory.path, 'main_file_only'))..createSync();
      final mainFileOnlyPath = p.join(mainFileOnlyDirectory.path, 'Model.sqlite');
      File(devicePath).copySync(mainFileOnlyPath);
      final withoutWal = await reader.read(mainFileOnlyPath);
      expect(withoutWal.favoriteSongNumbers, [5, 12]);
      expect(withoutWal.mySongs, hasLength(1));

      final snapshot = await reader.read(devicePath);

      expect(snapshot.favoriteSongNumbers, [5, 7, 12]);
      expect(snapshot.mySongs.map((song) => song.title), ['Pieśń poranna', 'Tuż przed aktualizacją']);
      expect(snapshot.mySongs.last.content, 'Treść zapisana tylko w WAL');
    });

    test('reads a database whose -shm file is missing while -wal is present', () async {
      // SYNTHETIC DATA: same WAL-only change as above, but the -shm file did not survive the copy.
      final workingPath = copyFixture('ios_with_data', directory: Directory(p.join(tempDirectory.path, 'app'))..createSync());
      final database = await databaseFactoryFfiNoIsolate.openDatabase(workingPath);
      await database.execute('PRAGMA wal_autocheckpoint = 0');
      await database.rawUpdate('UPDATE ZSONG SET ZFAVORITE = 1 WHERE ZNUMBER = 1999');
      final devicePath = p.join((Directory(p.join(tempDirectory.path, 'device'))..createSync()).path, 'Model.sqlite');
      for (final suffix in ['', '-wal']) {
        File('$workingPath$suffix').copySync('$devicePath$suffix');
      }
      await database.close();

      final snapshot = await reader.read(devicePath);

      expect(snapshot.favoriteSongNumbers, [5, 12, 1999]);
    });

    test('returns a user song with NULL title without skipping it', () async {
      // SYNTHETIC DATA
      final path = copyFixture('ios_with_data');
      await changeCopy(path, (database) => database.rawInsert(
            'INSERT INTO ZMYSONG (Z_PK, Z_ENT, Z_OPT, ZCONTENT, ZTITLE) VALUES (2, 1, 1, ?, NULL)',
            ['Treść bez tytułu'],
          ));

      final snapshot = await reader.read(path);

      expect(snapshot.mySongs, hasLength(2));
      expect(snapshot.mySongs.last.title, isNull);
      expect(snapshot.mySongs.last.content, 'Treść bez tytułu');
    });

    test('returns a user song with NULL content without skipping it', () async {
      // SYNTHETIC DATA
      final path = copyFixture('ios_with_data');
      await changeCopy(path, (database) => database.rawInsert(
            'INSERT INTO ZMYSONG (Z_PK, Z_ENT, Z_OPT, ZCONTENT, ZTITLE) VALUES (2, 1, 1, NULL, ?)',
            ['Tytuł bez treści'],
          ));

      final snapshot = await reader.read(path);

      expect(snapshot.mySongs, hasLength(2));
      expect(snapshot.mySongs.last.title, 'Tytuł bez treści');
      expect(snapshot.mySongs.last.content, isNull);
    });

    test('returns a user song with both title and content NULL without skipping it', () async {
      // SYNTHETIC DATA
      final path = copyFixture('ios_with_data');
      await changeCopy(path, (database) => database.rawInsert(
            'INSERT INTO ZMYSONG (Z_PK, Z_ENT, Z_OPT, ZCONTENT, ZTITLE) VALUES (2, 1, 1, NULL, NULL)',
          ));

      final snapshot = await reader.read(path);

      expect(snapshot.mySongs, hasLength(2));
      expect(snapshot.mySongs.last.primaryKey, 2);
      expect(snapshot.mySongs.last.title, isNull);
      expect(snapshot.mySongs.last.content, isNull);
    });

    test('returns a favorite number outside the current songbook range', () async {
      // SYNTHETIC DATA
      final path = copyFixture('ios_with_data');
      await changeCopy(path, (database) => database.rawInsert(
            'INSERT INTO ZSONG (Z_PK, Z_ENT, Z_OPT, ZFAVORITE, ZNUMBER, ZCONTENT, ZTITLE) VALUES (2500, NULL, 1, 1, 2500, ?, ?)',
            ['treść', 'Pieśń spoza śpiewnika'],
          ));

      final snapshot = await reader.read(path);

      expect(snapshot.favoriteSongNumbers, [5, 12, 2500]);
    });

    test('rejects a database without the ZSONG table', () async {
      // SYNTHETIC DATA
      final path = p.join(tempDirectory.path, 'Model.sqlite');
      await changeCopy(path, (database) => database.execute(
            'CREATE TABLE ZMYSONG (Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER, ZCONTENT VARCHAR, ZTITLE VARCHAR)',
          ));

      expect(() => reader.read(path), throwsA(isA<CoreDataReadException>()));
    });
  });

  group('invalid files', () {
    test('rejects a missing file', () async {
      expect(
        () => reader.read(p.join(tempDirectory.path, 'Model.sqlite')),
        throwsA(isA<CoreDataReadException>()),
      );
    });

    test('rejects an empty file', () async {
      final path = p.join(tempDirectory.path, 'Model.sqlite');
      File(path).writeAsBytesSync([]);

      expect(() => reader.read(path), throwsA(isA<CoreDataReadException>()));
    });

    test('rejects a file that is not a database', () async {
      final path = p.join(tempDirectory.path, 'Model.sqlite');
      final random = Random(42);
      File(path).writeAsBytesSync(List.generate(8192, (_) => random.nextInt(256)));

      expect(() => reader.read(path), throwsA(isA<CoreDataReadException>()));
    });

    test('rejects a truncated database', () async {
      final path = p.join(tempDirectory.path, 'Model.sqlite');
      final original = File(p.join(fixturesDirectory, 'ios_with_data.sqlite')).readAsBytesSync();
      File(path).writeAsBytesSync(original.sublist(0, 8192));

      expect(() => reader.read(path), throwsA(isA<CoreDataReadException>()));
    });
  });
}
