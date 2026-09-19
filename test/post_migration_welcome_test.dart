import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/migration/core_data_migration.dart';
import 'package:spiewnik/migration/core_data_reader.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/post_migration_welcome.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/core_data_fixtures.dart';
import 'support/test_store.dart';

/// The post-migration welcome screen: once, and only for someone whose data we just moved.
void main() {
  final logger = Logger(level: Level.off);

  PostMigrationWelcome welcome() => PostMigrationWelcome(logger: logger);

  Future<bool?> shownFlag() async => (await SharedPreferences.getInstance()).getBool(PostMigrationWelcome.shownKey);

  group('decision from the migration result in this session', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    const migratedData = CoreDataMigrationResult(
      CoreDataMigrationStatus.migrated,
      favoritesMarked: 3,
      mySongsAdded: 2,
    );

    test('shows when the migration moved favorites and user songs, and saves the flag', () async {
      expect(
        await welcome().decide(coreDataResult: migratedData, migratedFontSize: null, isIOS: true),
        WelcomeVariant.songs,
      );
      expect(await shownFlag(), isTrue);
    });

    test('shows when it moved only favorites', () async {
      const result = CoreDataMigrationResult(CoreDataMigrationStatus.migrated, favoritesMarked: 1);
      expect(await welcome().decide(coreDataResult: result, migratedFontSize: null, isIOS: true), WelcomeVariant.songs);
    });

    test('shows when it moved only user songs', () async {
      const result = CoreDataMigrationResult(CoreDataMigrationStatus.migrated, mySongsAdded: 1);
      expect(await welcome().decide(coreDataResult: result, migratedFontSize: null, isIOS: true), WelcomeVariant.songs);
    });

    test('shows the „tylko ustawienia” variant when the database was empty but the font size was moved',
        () async {
      const result = CoreDataMigrationResult(CoreDataMigrationStatus.migrated);
      expect(
        await welcome().decide(coreDataResult: result, migratedFontSize: 24.0, isIOS: true),
        WelcomeVariant.settingsOnly,
      );
      expect(await shownFlag(), isTrue);
    });

    test('songs and font size together: the songs variant', () async {
      const result = CoreDataMigrationResult(CoreDataMigrationStatus.migrated, favoritesMarked: 1);
      expect(await welcome().decide(coreDataResult: result, migratedFontSize: 24.0, isIOS: true), WelcomeVariant.songs);
    });

    test('does not show when the migration found nothing', () async {
      const result = CoreDataMigrationResult(CoreDataMigrationStatus.migrated);
      expect(await welcome().decide(coreDataResult: result, migratedFontSize: null, isIOS: true), isNull);
      expect(await shownFlag(), isNull);
    });

    test('does not show on a clean install: no old database', () async {
      const result = CoreDataMigrationResult(CoreDataMigrationStatus.noDatabase);
      expect(await welcome().decide(coreDataResult: result, migratedFontSize: null, isIOS: true), isNull);
    });

    test('does not show when the migration ran on an earlier launch', () async {
      const result = CoreDataMigrationResult(CoreDataMigrationStatus.alreadyDone);
      // A font size from a retried settings migration is not enough: Core Data decides the migration session.
      expect(await welcome().decide(coreDataResult: result, migratedFontSize: 24.0, isIOS: true), isNull);
    });

    test('does not show after a failed migration, even with a moved font size', () async {
      const result = CoreDataMigrationResult(CoreDataMigrationStatus.failed, error: 'CoreDataReadException');
      expect(await welcome().decide(coreDataResult: result, migratedFontSize: 24.0, isIOS: true), isNull);
      expect(await shownFlag(), isNull);
    });

    test('does not show on Android, even with a migration result that has data', () async {
      expect(await welcome().decide(coreDataResult: migratedData, migratedFontSize: 24.0, isIOS: false), isNull);
      expect(await shownFlag(), isNull);
    });

    test('does not show when there was no migration (runOnStartup returns null outside iOS)', () async {
      expect(await welcome().decide(coreDataResult: null, migratedFontSize: null, isIOS: true), isNull);
    });

    test('does not show a second time when the flag is already saved', () async {
      SharedPreferences.setMockInitialValues({PostMigrationWelcome.shownKey: true});
      expect(await welcome().decide(coreDataResult: migratedData, migratedFontSize: null, isIOS: true), isNull);
    });

    test('a second call in the same install no longer shows', () async {
      expect(
        await welcome().decide(coreDataResult: migratedData, migratedFontSize: null, isIOS: true),
        WelcomeVariant.songs,
      );
      expect(await welcome().decide(coreDataResult: migratedData, migratedFontSize: null, isIOS: true), isNull);
    });
  });

  /// Consecutive launches with a real migration on copies of iOS databases, in the order used by main():
  /// the Core Data migration, then the decision. State (ObjectBox and SharedPreferences) carries over between launches.
  group('consecutive launches with a real migration', () {
    late TestStore testStore;
    late Directory documents;
    late CoreDataReader reader;

    setUpAll(sqfliteFfiInit);

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      testStore = TestStore.open();
      documents = Directory.systemTemp.createTempSync('post_migration_welcome_documents_');
      reader = CoreDataReader(databaseFactory: databaseFactoryFfiNoIsolate);
      testStore.store.box<Song>().putMany([
        for (var number = 1; number <= 20; number++)
          Song(number: number, title: 'Pieśń $number', content: 'treść', favorite: false),
      ]);
    });

    tearDown(() {
      testStore.close();
      documents.deleteSync(recursive: true);
    });

    Future<WelcomeVariant?> launch({bool isIOS = true, double? migratedFontSize}) async {
      final result = await CoreDataMigration.runOnStartup(
        store: testStore.store,
        logger: logger,
        isIOS: isIOS,
        documentsDirectory: () async => documents,
        reader: reader,
      );
      return welcome().decide(coreDataResult: result, migratedFontSize: migratedFontSize, isIOS: isIOS);
    }

    test('database with data: shows on the first launch, not on the second or third', () async {
      CoreDataFixtures.copyTo('ios_with_data', documents);

      expect(await launch(), WelcomeVariant.songs);
      expect(await launch(), isNull);
      expect(await launch(), isNull);
    });

    test('database without favorites or user songs, but with a font size: „tylko ustawienia” variant, once',
        () async {
      CoreDataFixtures.copyTo('ios_fresh', documents);

      expect(await launch(migratedFontSize: 26.0), WelcomeVariant.settingsOnly);
      expect(await launch(), isNull);
    });

    test('database without favorites or user songs: does not show', () async {
      CoreDataFixtures.copyTo('ios_fresh', documents);

      expect(await launch(), isNull);
      expect(await launch(), isNull);
    });

    test('clean install without an old database: does not show now or later', () async {
      expect(await launch(), isNull);
      expect(await launch(), isNull);
    });

    test('corrupted database: the migration fails and no screen is shown', () async {
      File(p.join(documents.path, 'Model.sqlite')).writeAsBytesSync(List.generate(8192, (i) => (i * 31) % 256));

      expect(await launch(migratedFontSize: 24.0), isNull);
      expect((await SharedPreferences.getInstance()).getBool(CoreDataMigration.failedKey), isTrue);
      expect(await launch(), isNull);
    });

    test('Android with Model.sqlite in the directory: the migration does not run and no screen is shown', () async {
      CoreDataFixtures.copyTo('ios_with_data', documents);

      expect(await launch(isIOS: false), isNull);
      expect(await shownFlag(), isNull);
    });
  });
}
