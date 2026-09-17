import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/migration/core_data_migration.dart';
import 'package:spiewnik/migration/core_data_reader.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/core_data_fixtures.dart';
import 'support/test_store.dart';

class _AllLogs extends LogFilter {
  @override
  bool shouldLog(LogEvent event) => true;
}

void main() {
  final migrationTime = DateTime(2026, 9, 17, 15, 30);
  late TestStore testStore;
  late Directory documents;
  late MemoryOutput logs;
  late Logger logger;
  late CoreDataReader reader;

  setUpAll(sqfliteFfiInit);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    testStore = TestStore.open();
    documents = Directory.systemTemp.createTempSync('core_data_migration_documents_');
    logs = MemoryOutput(bufferSize: 100);
    logger = Logger(filter: _AllLogs(), printer: SimplePrinter(colors: false), output: logs);
    reader = CoreDataReader(databaseFactory: databaseFactoryFfiNoIsolate);
    // Songbook after loading the asset: numbers 1-20, song 3 already favorite in the new app.
    testStore.store.box<Song>().putMany([
      for (var number = 1; number <= 20; number++)
        Song(number: number, title: 'Pieśń $number', content: 'treść $number', favorite: number == 3),
    ]);
  });

  tearDown(() {
    testStore.close();
    documents.deleteSync(recursive: true);
  });

  CoreDataMigration migration() =>
      CoreDataMigration(store: testStore.store, logger: logger, reader: reader, now: () => migrationTime);

  Future<CoreDataMigrationResult> runMigration(String path) => migration().run(() async => path);

  List<int> favoriteNumbers() =>
      (testStore.store.box<Song>().getAll().where((song) => song.favorite).map((song) => song.number).toList())
        ..sort();

  List<MySong> mySongs() => testStore.store.box<MySong>().getAll();

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  Map<String, Uint8List> snapshotFiles(Directory directory) => {
        for (final file in directory.listSync().whereType<File>())
          p.basename(file.path): file.readAsBytesSync(),
      };

  void expectFilesUnchanged(Directory directory, Map<String, Uint8List> before) {
    final after = snapshotFiles(directory);
    expect(after.keys.toSet(), before.keys.toSet());
    for (final name in before.keys) {
      expect(listEquals(after[name], before[name]), isTrue, reason: '$name changed');
    }
  }

  group('device databases', () {
    test('migrates favorites and user songs and keeps the old database untouched', () async {
      final path = CoreDataFixtures.copyTo('ios_with_data', documents);
      final filesBefore = snapshotFiles(documents);

      final result = await runMigration(path);

      expect(result.status, CoreDataMigrationStatus.migrated);
      expect(result.favoritesMarked, 2);
      expect(result.mySongsAdded, 1);
      expect(favoriteNumbers(), [3, 5, 12]);
      final mySong = mySongs().single;
      expect(mySong.title, 'Pieśń poranna');
      expect(mySong.content, '1. Dziękuję Ci, Panie, za nowy dzień.');
      expect(mySong.createdAt.isAtSameMomentAs(migrationTime), isTrue);
      expect(mySong.updatedAt.isAtSameMomentAs(migrationTime), isTrue);
      expect((await prefs()).getBool(CoreDataMigration.doneKey), isTrue);
      expect((await prefs()).getBool(CoreDataMigration.failedKey), isNull);
      expectFilesUnchanged(documents, filesBefore);
    });

    test('migrates nothing from a fresh installation and sets the done flag', () async {
      final result = await runMigration(CoreDataFixtures.copyTo('ios_fresh', documents));

      expect(result.status, CoreDataMigrationStatus.migrated);
      expect(favoriteNumbers(), [3]);
      expect(mySongs(), isEmpty);
      expect((await prefs()).getBool(CoreDataMigration.doneKey), isTrue);
    });

    test('migrates a database without the ZMYSONG table', () async {
      final result = await runMigration(CoreDataFixtures.copyTo('ios_no_mysong', documents));

      expect(result.status, CoreDataMigrationStatus.migrated);
      expect(mySongs(), isEmpty);
      expect((await prefs()).getBool(CoreDataMigration.doneKey), isTrue);
    });
  });

  group('missing or broken database', () {
    test('sets the done flag and changes nothing when there is no old database', () async {
      final result = await runMigration(p.join(documents.path, 'Model.sqlite'));

      expect(result.status, CoreDataMigrationStatus.noDatabase);
      expect(favoriteNumbers(), [3]);
      expect(mySongs(), isEmpty);
      expect((await prefs()).getBool(CoreDataMigration.doneKey), isTrue);
      expect((await prefs()).getBool(CoreDataMigration.failedKey), isNull);
    });

    test('records the failure, keeps the file and writes nothing for a corrupted database', () async {
      final path = p.join(documents.path, 'Model.sqlite');
      File(path).writeAsBytesSync(List.generate(8192, (index) => (index * 31) % 256));
      final filesBefore = snapshotFiles(documents);

      final result = await runMigration(path);

      expect(result.status, CoreDataMigrationStatus.failed);
      expect(result.error, contains('CoreDataReadException'));
      final preferences = await prefs();
      expect(preferences.getBool(CoreDataMigration.doneKey), isTrue);
      expect(preferences.getBool(CoreDataMigration.failedKey), isTrue);
      expect(preferences.getString(CoreDataMigration.errorKey), result.error);
      expect(favoriteNumbers(), [3]);
      expect(mySongs(), isEmpty);
      expectFilesUnchanged(documents, filesBefore);
      expect(logs.buffer.any((event) => event.level == Level.error), isTrue);
    });

    test('does not retry after a failure', () async {
      final path = p.join(documents.path, 'Model.sqlite');
      File(path).writeAsBytesSync([1, 2, 3, 4]);
      await runMigration(path);
      CoreDataFixtures.copyTo('ios_with_data', documents);

      final result = await runMigration(path);

      expect(result.status, CoreDataMigrationStatus.alreadyDone);
      expect(favoriteNumbers(), [3]);
      expect(mySongs(), isEmpty);
    });
  });

  group('idempotency', () {
    test('a second run does nothing', () async {
      final path = CoreDataFixtures.copyTo('ios_with_data', documents);
      await runMigration(path);

      final second = await runMigration(path);

      expect(second.status, CoreDataMigrationStatus.alreadyDone);
      expect(favoriteNumbers(), [3, 5, 12]);
      expect(mySongs(), hasLength(1));
    });

    test('running again without the done flag creates no duplicates', () async {
      // Simulates the app being killed after the data was written but before the flag was saved.
      final path = CoreDataFixtures.copyTo('ios_with_data', documents);
      await CoreDataFixtures.changeCopy(path, (database) async {
        // SYNTHETIC DATA: two identical user songs must both survive, once.
        await database.rawInsert(
          'INSERT INTO ZMYSONG (Z_PK, Z_ENT, Z_OPT, ZCONTENT, ZTITLE) VALUES (2, 1, 1, ?, ?), (3, 1, 1, ?, ?)',
          ['Ta sama treść', 'Duplikat', 'Ta sama treść', 'Duplikat'],
        );
      });
      await runMigration(path);
      await (await prefs()).remove(CoreDataMigration.doneKey);

      final second = await runMigration(path);

      expect(second.status, CoreDataMigrationStatus.migrated);
      expect(second.mySongsAdded, 0);
      expect(favoriteNumbers(), [3, 5, 12]);
      expect(mySongs().map((song) => song.title).toList()..sort(), ['Duplikat', 'Duplikat', 'Pieśń poranna']);
    });
  });

  group('synthetic data', () {
    test('skips and logs favorites missing from the current songbook', () async {
      final path = CoreDataFixtures.copyTo('ios_with_data', documents);
      await CoreDataFixtures.changeCopy(path, (database) async {
        // SYNTHETIC DATA: favorite number outside the current songbook.
        await database.rawInsert(
          'INSERT INTO ZSONG (Z_PK, Z_ENT, Z_OPT, ZFAVORITE, ZNUMBER, ZCONTENT, ZTITLE) VALUES (2500, NULL, 1, 1, 2500, ?, ?)',
          ['treść', 'Pieśń spoza śpiewnika'],
        );
      });

      final result = await runMigration(path);

      expect(result.status, CoreDataMigrationStatus.migrated);
      expect(result.skippedFavoriteNumbers, [2500]);
      expect(favoriteNumbers(), [3, 5, 12]);
      expect(
        logs.buffer.any((event) => event.level == Level.warning && event.origin.message.toString().contains('2500')),
        isTrue,
      );
    });

    test('stores NULL title and content of user songs as empty text', () async {
      final path = CoreDataFixtures.copyTo('ios_with_data', documents);
      await CoreDataFixtures.changeCopy(path, (database) async {
        // SYNTHETIC DATA
        await database.rawInsert(
          'INSERT INTO ZMYSONG (Z_PK, Z_ENT, Z_OPT, ZCONTENT, ZTITLE) VALUES '
          '(2, 1, 1, ?, NULL), (3, 1, 1, NULL, ?), (4, 1, 1, NULL, NULL)',
          ['Treść bez tytułu', 'Tytuł bez treści'],
        );
      });

      final result = await runMigration(path);

      expect(result.mySongsAdded, 4);
      final songs = {for (final song in mySongs()) '${song.title}|${song.content}': song};
      expect(songs.keys.toSet(), {
        'Pieśń poranna|1. Dziękuję Ci, Panie, za nowy dzień.',
        '|Treść bez tytułu',
        'Tytuł bez treści|',
        '|',
      });
    });
  });

  group('startup', () {
    test('does nothing outside iOS', () async {
      CoreDataFixtures.copyTo('ios_with_data', documents);

      final result = await CoreDataMigration.runOnStartup(
        store: testStore.store,
        logger: logger,
        isIOS: false,
        documentsDirectory: () async => documents,
        reader: reader,
      );

      expect(result, isNull);
      expect(favoriteNumbers(), [3]);
      expect((await prefs()).getBool(CoreDataMigration.doneKey), isNull);
    });

    test('migrates Model.sqlite from the documents directory on iOS', () async {
      CoreDataFixtures.copyTo('ios_with_data', documents);

      final result = await CoreDataMigration.runOnStartup(
        store: testStore.store,
        logger: logger,
        isIOS: true,
        documentsDirectory: () async => documents,
        reader: reader,
      );

      expect(result!.status, CoreDataMigrationStatus.migrated);
      expect(favoriteNumbers(), [3, 5, 12]);
      expect(File(p.join(documents.path, 'Model.sqlite')).existsSync(), isTrue);
    });

    test('does not throw when the documents directory is unavailable', () async {
      final result = await CoreDataMigration.runOnStartup(
        store: testStore.store,
        logger: logger,
        isIOS: true,
        documentsDirectory: () async => throw const FileSystemException('no documents directory'),
        reader: reader,
      );

      expect(result!.status, CoreDataMigrationStatus.failed);
      expect((await prefs()).getBool(CoreDataMigration.failedKey), isTrue);
      expect((await prefs()).getString(CoreDataMigration.errorKey), contains('no documents directory'));
    });
  });
}
