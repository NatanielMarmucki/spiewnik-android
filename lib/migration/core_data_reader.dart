import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;

/// User song stored by the old iOS app (table ZMYSONG). Title and content are
/// optional in the Core Data model and are returned as stored, including null.
class CoreDataMySong {
  /// Z_PK of the row, stable within one database file.
  final int primaryKey;
  final String? title;
  final String? content;

  const CoreDataMySong({required this.primaryKey, required this.title, required this.content});
}

/// User data read from the old iOS app database (Documents/Model.sqlite).
class CoreDataSnapshot {
  /// Numbers of songs marked as favorite, ascending. Numbers are returned even when
  /// they do not exist in the current songbook; the migration decides what to skip.
  final List<int> favoriteSongNumbers;

  /// Favorite rows skipped because ZNUMBER is not an integer (e.g. NULL).
  final int favoriteRowsWithoutNumber;

  final List<CoreDataMySong> mySongs;

  /// False for the template database bundled in the iOS repo, which has no ZMYSONG table.
  final bool hasMySongTable;

  const CoreDataSnapshot({
    required this.favoriteSongNumbers,
    required this.favoriteRowsWithoutNumber,
    required this.mySongs,
    required this.hasMySongTable,
  });
}

class CoreDataReadException implements Exception {
  final String message;
  final Object? cause;

  const CoreDataReadException(this.message, [this.cause]);

  @override
  String toString() => cause == null ? 'CoreDataReadException: $message' : 'CoreDataReadException: $message ($cause)';
}

/// Reads favorites and user songs from the old iOS Core Data database.
///
/// Schema: docs/SCHEMA-ZMYSONG.md. The original file is never opened: the database and its
/// -wal and -shm files are copied to a temporary directory and only SELECT queries run on
/// the copy, which is deleted afterwards.
///
/// - Copying the -wal file keeps rows the iOS app wrote but never checkpointed.
/// - Opening the original could create or modify -wal/-shm files next to the backup copy.
/// - The copy is not opened with SQLite's read-only flag: a WAL database whose -wal/-shm files
///   are missing (e.g. removed after a checkpoint) cannot be opened read-only, because SQLite
///   has to create the WAL index first.
class CoreDataReader {
  static const _companionSuffixes = ['-wal', '-shm'];

  final sqflite.DatabaseFactory _databaseFactory;

  CoreDataReader({sqflite.DatabaseFactory? databaseFactory})
      : _databaseFactory = databaseFactory ?? sqflite.databaseFactory;

  Future<CoreDataSnapshot> read(String databasePath) async {
    final source = File(databasePath);
    if (!await source.exists()) {
      throw CoreDataReadException('Database file does not exist: $databasePath');
    }
    if (await source.length() == 0) {
      throw CoreDataReadException('Database file is empty: $databasePath');
    }

    final workDirectory = await Directory.systemTemp.createTemp('core_data_reader_');
    try {
      final copyPath = p.join(workDirectory.path, 'Model.sqlite');
      await source.copy(copyPath);
      for (final suffix in _companionSuffixes) {
        final companion = File('$databasePath$suffix');
        if (await companion.exists()) {
          await companion.copy('$copyPath$suffix');
        }
      }
      return await _readCopy(copyPath);
    } on CoreDataReadException {
      rethrow;
    } catch (error) {
      throw CoreDataReadException('Could not read database: $databasePath', error);
    } finally {
      await workDirectory.delete(recursive: true);
    }
  }

  Future<CoreDataSnapshot> _readCopy(String copyPath) async {
    final database = await _databaseFactory.openDatabase(
      copyPath,
      options: sqflite.OpenDatabaseOptions(singleInstance: false),
    );
    try {
      final tables = (await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('ZSONG', 'ZMYSONG')",
      ))
          .map((row) => row['name'])
          .toSet();
      if (!tables.contains('ZSONG')) {
        throw const CoreDataReadException('Database has no ZSONG table');
      }

      final favoriteRows = await database.rawQuery('SELECT ZNUMBER FROM ZSONG WHERE ZFAVORITE = 1 ORDER BY ZNUMBER');
      final favoriteNumbers = <int>[];
      var favoriteRowsWithoutNumber = 0;
      for (final row in favoriteRows) {
        final number = row['ZNUMBER'];
        if (number is int) {
          favoriteNumbers.add(number);
        } else {
          favoriteRowsWithoutNumber++;
        }
      }

      final hasMySongTable = tables.contains('ZMYSONG');
      final mySongs = <CoreDataMySong>[];
      if (hasMySongTable) {
        final rows = await database.rawQuery('SELECT Z_PK, ZTITLE, ZCONTENT FROM ZMYSONG ORDER BY Z_PK');
        for (final row in rows) {
          mySongs.add(CoreDataMySong(
            primaryKey: row['Z_PK'] as int,
            title: row['ZTITLE'] as String?,
            content: row['ZCONTENT'] as String?,
          ));
        }
      }

      return CoreDataSnapshot(
        favoriteSongNumbers: favoriteNumbers,
        favoriteRowsWithoutNumber: favoriteRowsWithoutNumber,
        mySongs: mySongs,
        hasMySongTable: hasMySongTable,
      );
    } finally {
      await database.close();
    }
  }
}
