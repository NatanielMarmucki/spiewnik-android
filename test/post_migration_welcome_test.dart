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

/// Ekran powitalny po migracji: raz, tylko dla kogoś, czyje dane właśnie przenieśliśmy.
void main() {
  final logger = Logger(level: Level.off);

  PostMigrationWelcome welcome() => PostMigrationWelcome(logger: logger);

  Future<bool?> shownFlag() async => (await SharedPreferences.getInstance()).getBool(PostMigrationWelcome.shownKey);

  group('decyzja z wyniku migracji w tej sesji', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    const migratedData = CoreDataMigrationResult(
      CoreDataMigrationStatus.migrated,
      favoritesMarked: 3,
      mySongsAdded: 2,
    );

    test('pokazuje, gdy migracja przeniosła ulubione i własne pieśni, i zapisuje flagę', () async {
      expect(await welcome().shouldShow(coreDataResult: migratedData, migratedFontSize: null, isIOS: true), isTrue);
      expect(await shownFlag(), isTrue);
    });

    test('pokazuje, gdy przeniosła same ulubione', () async {
      const result = CoreDataMigrationResult(CoreDataMigrationStatus.migrated, favoritesMarked: 1);
      expect(await welcome().shouldShow(coreDataResult: result, migratedFontSize: null, isIOS: true), isTrue);
    });

    test('pokazuje, gdy przeniosła same własne pieśni', () async {
      const result = CoreDataMigrationResult(CoreDataMigrationStatus.migrated, mySongsAdded: 1);
      expect(await welcome().shouldShow(coreDataResult: result, migratedFontSize: null, isIOS: true), isTrue);
    });

    test('pokazuje, gdy baza była pusta, ale przeniósł się rozmiar czcionki', () async {
      const result = CoreDataMigrationResult(CoreDataMigrationStatus.migrated);
      expect(await welcome().shouldShow(coreDataResult: result, migratedFontSize: 24.0, isIOS: true), isTrue);
    });

    test('nie pokazuje, gdy migracja nic nie zastała', () async {
      const result = CoreDataMigrationResult(CoreDataMigrationStatus.migrated);
      expect(await welcome().shouldShow(coreDataResult: result, migratedFontSize: null, isIOS: true), isFalse);
      expect(await shownFlag(), isNull);
    });

    test('nie pokazuje przy czystej instalacji: brak starej bazy', () async {
      const result = CoreDataMigrationResult(CoreDataMigrationStatus.noDatabase);
      expect(await welcome().shouldShow(coreDataResult: result, migratedFontSize: null, isIOS: true), isFalse);
    });

    test('nie pokazuje, gdy migracja odbyła się przy wcześniejszym uruchomieniu', () async {
      const result = CoreDataMigrationResult(CoreDataMigrationStatus.alreadyDone);
      // Rozmiar czcionki z ponowionej migracji ustawień nie wystarcza: sesją migracji rządzi Core Data.
      expect(await welcome().shouldShow(coreDataResult: result, migratedFontSize: 24.0, isIOS: true), isFalse);
    });

    test('nie pokazuje po migracji zakończonej błędem, nawet z przeniesionym rozmiarem czcionki', () async {
      const result = CoreDataMigrationResult(CoreDataMigrationStatus.failed, error: 'CoreDataReadException');
      expect(await welcome().shouldShow(coreDataResult: result, migratedFontSize: 24.0, isIOS: true), isFalse);
      expect(await shownFlag(), isNull);
    });

    test('nie pokazuje na Androidzie, nawet przy wyniku migracji z danymi', () async {
      expect(await welcome().shouldShow(coreDataResult: migratedData, migratedFontSize: 24.0, isIOS: false), isFalse);
      expect(await shownFlag(), isNull);
    });

    test('nie pokazuje, gdy migracji nie było (runOnStartup poza iOS zwraca null)', () async {
      expect(await welcome().shouldShow(coreDataResult: null, migratedFontSize: null, isIOS: true), isFalse);
    });

    test('nie pokazuje drugi raz, gdy flaga już jest zapisana', () async {
      SharedPreferences.setMockInitialValues({PostMigrationWelcome.shownKey: true});
      expect(await welcome().shouldShow(coreDataResult: migratedData, migratedFontSize: null, isIOS: true), isFalse);
    });

    test('drugie zapytanie w tej samej instalacji już nie pokazuje', () async {
      expect(await welcome().shouldShow(coreDataResult: migratedData, migratedFontSize: null, isIOS: true), isTrue);
      expect(await welcome().shouldShow(coreDataResult: migratedData, migratedFontSize: null, isIOS: true), isFalse);
    });
  });

  /// Kolejne uruchomienia z prawdziwą migracją na kopiach baz z iOS, w kolejności z main():
  /// migracja Core Data, potem decyzja. Stan (ObjectBox i SharedPreferences) przechodzi między startami.
  group('kolejne uruchomienia z prawdziwą migracją', () {
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

    Future<bool> launch({bool isIOS = true, double? migratedFontSize}) async {
      final result = await CoreDataMigration.runOnStartup(
        store: testStore.store,
        logger: logger,
        isIOS: isIOS,
        documentsDirectory: () async => documents,
        reader: reader,
      );
      return welcome().shouldShow(coreDataResult: result, migratedFontSize: migratedFontSize, isIOS: isIOS);
    }

    test('baza z danymi: pokazuje przy pierwszym starcie, przy drugim i trzecim już nie', () async {
      CoreDataFixtures.copyTo('ios_with_data', documents);

      expect(await launch(), isTrue);
      expect(await launch(), isFalse);
      expect(await launch(), isFalse);
    });

    test('baza bez ulubionych i własnych pieśni: nie pokazuje', () async {
      CoreDataFixtures.copyTo('ios_fresh', documents);

      expect(await launch(), isFalse);
      expect(await launch(), isFalse);
    });

    test('czysta instalacja bez starej bazy: nie pokazuje ani teraz, ani później', () async {
      expect(await launch(), isFalse);
      expect(await launch(), isFalse);
    });

    test('uszkodzona baza: migracja kończy się błędem i ekranu nie ma', () async {
      File(p.join(documents.path, 'Model.sqlite')).writeAsBytesSync(List.generate(8192, (i) => (i * 31) % 256));

      expect(await launch(migratedFontSize: 24.0), isFalse);
      expect((await SharedPreferences.getInstance()).getBool(CoreDataMigration.failedKey), isTrue);
      expect(await launch(), isFalse);
    });

    test('Android z plikiem Model.sqlite w katalogu: migracja nie rusza, ekranu nie ma', () async {
      CoreDataFixtures.copyTo('ios_with_data', documents);

      expect(await launch(isIOS: false), isFalse);
      expect(await shownFlag(), isNull);
    });
  });
}
