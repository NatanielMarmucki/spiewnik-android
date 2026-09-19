import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/migration/core_data_reader.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/objectbox.g.dart';

enum CoreDataMigrationStatus {
  /// coreDataMigrationDone was already set, nothing was read.
  alreadyDone,

  /// No database of the old iOS app was found; the flag was set.
  noDatabase,

  /// Favorites and user songs were written and the flag was set.
  migrated,

  /// The migration failed; both flags and the error message were saved, nothing was written.
  failed,
}

class CoreDataMigrationResult {
  final CoreDataMigrationStatus status;
  final int favoritesMarked;

  /// Favorite numbers from the old app that do not exist in the current songbook.
  final List<int> skippedFavoriteNumbers;
  final int mySongsAdded;
  final String? error;

  const CoreDataMigrationResult(
    this.status, {
    this.favoritesMarked = 0,
    this.skippedFavoriteNumbers = const [],
    this.mySongsAdded = 0,
    this.error,
  });
}

/// One-time migration of favorites and user songs from the old iOS app database
/// (Documents/Model.sqlite, schema in docs/SCHEMA-ZMYSONG.md) into ObjectBox.
///
/// Runs after the songs are loaded from the asset. The old database is never deleted: it stays
/// as a backup. A failure never blocks the start of the app: it is logged, recorded in
/// SharedPreferences and not retried, because the old file does not change between starts.
class CoreDataMigration {
  static const String doneKey = 'coreDataMigrationDone';
  static const String failedKey = 'coreDataMigrationFailed';
  static const String errorKey = 'coreDataMigrationError';
  static const String databaseFileName = 'Model.sqlite';

  final Store store;
  final CoreDataReader reader;
  final Logger logger;
  final DateTime Function() _now;

  CoreDataMigration({
    required this.store,
    required this.logger,
    CoreDataReader? reader,
    DateTime Function()? now,
  })  : reader = reader ?? CoreDataReader(),
        _now = now ?? DateTime.now;

  /// Entry point used at startup. Does nothing outside iOS. Never throws.
  static Future<CoreDataMigrationResult?> runOnStartup({
    required Store store,
    required Logger logger,
    bool? isIOS,
    Future<Directory> Function()? documentsDirectory,
    CoreDataReader? reader,
  }) async {
    if (!(isIOS ?? Platform.isIOS)) {
      return null;
    }
    final migration = CoreDataMigration(store: store, logger: logger, reader: reader);
    return migration.run(() async {
      final directory = await (documentsDirectory ?? getApplicationDocumentsDirectory)();
      return p.join(directory.path, databaseFileName);
    });
  }

  /// Migrates the database at the path returned by [databasePath]. Never throws.
  Future<CoreDataMigrationResult> run(Future<String> Function() databasePath) async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(doneKey) ?? false) {
        logger.i('Core Data migration: already done, skipping.');
        return const CoreDataMigrationResult(CoreDataMigrationStatus.alreadyDone);
      }

      final path = await databasePath();
      if (!await File(path).exists()) {
        logger.i('Core Data migration: no database of the old iOS app, nothing to migrate.');
        await prefs.setBool(doneKey, true);
        return const CoreDataMigrationResult(CoreDataMigrationStatus.noDatabase);
      }

      final snapshot = await reader.read(path);
      final result = _write(snapshot);
      await prefs.setBool(doneKey, true);

      if (result.skippedFavoriteNumbers.isNotEmpty) {
        logger.w('Core Data migration: skipped favorites missing from the current songbook: '
            '${result.skippedFavoriteNumbers.join(', ')}.');
      }
      if (snapshot.favoriteRowsWithoutNumber > 0) {
        logger.w('Core Data migration: skipped ${snapshot.favoriteRowsWithoutNumber} favorites without a number.');
      }
      logger.i('Core Data migration: marked ${result.favoritesMarked} favorites, '
          'added ${result.mySongsAdded} user songs.');
      return result;
    } catch (error, stackTrace) {
      final message = '${error.runtimeType}: $error';
      logger.e('Core Data migration failed.', error: error, stackTrace: stackTrace);
      try {
        final preferences = prefs ?? await SharedPreferences.getInstance();
        await preferences.setBool(doneKey, true);
        await preferences.setBool(failedKey, true);
        await preferences.setString(errorKey, message);
      } catch (saveError) {
        logger.e('Core Data migration: could not save the failure flags.', error: saveError);
      }
      return CoreDataMigrationResult(CoreDataMigrationStatus.failed, error: message);
    }
  }

  CoreDataMigrationResult _write(CoreDataSnapshot snapshot) {
    return store.runInTransaction(TxMode.write, () {
      final songBox = store.box<Song>();
      final favoriteSongs = <Song>[];
      final skippedNumbers = <int>[];
      for (final number in snapshot.favoriteSongNumbers.toSet()) {
        final query = songBox.query(Song_.number.equals(number)).build();
        final songs = query.find();
        query.close();
        if (songs.isEmpty) {
          skippedNumbers.add(number);
          continue;
        }
        for (final song in songs) {
          song.favorite = true;
          favoriteSongs.add(song);
        }
      }
      songBox.putMany(favoriteSongs);

      // Adds only user songs that are not stored yet, so running the migration again
      // (e.g. after the app was killed before the done flag was saved) creates no duplicates.
      final mySongBox = store.box<MySong>();
      final existingCounts = <(String, String), int>{};
      for (final song in mySongBox.getAll()) {
        existingCounts.update(_mySongKey(song.title, song.content), (count) => count + 1, ifAbsent: () => 1);
      }
      // The old database has no dates, only the order in which songs were saved (Z_PK, the read
      // order). Each song gets the migration time plus its position in milliseconds, so that order
      // survives in createdAt and does not depend on sorting by id as well.
      final migrationTime = _now();
      final mySongsToAdd = <MySong>[];
      for (final song in snapshot.mySongs) {
        final title = song.title ?? '';
        final content = song.content ?? '';
        final key = _mySongKey(title, content);
        final existing = existingCounts[key] ?? 0;
        if (existing > 0) {
          existingCounts[key] = existing - 1;
          continue;
        }
        final createdAt = migrationTime.add(Duration(milliseconds: mySongsToAdd.length));
        mySongsToAdd.add(MySong(title: title, content: content, createdAt: createdAt, updatedAt: createdAt));
      }
      mySongBox.putMany(mySongsToAdd);

      return CoreDataMigrationResult(
        CoreDataMigrationStatus.migrated,
        favoritesMarked: favoriteSongs.length,
        skippedFavoriteNumbers: skippedNumbers..sort(),
        mySongsAdded: mySongsToAdd.length,
      );
    });
  }

  static (String, String) _mySongKey(String title, String content) => (title, content);
}
