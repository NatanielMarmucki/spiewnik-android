import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Old iOS app databases in test/fixtures, see test/fixtures/README.md.
class CoreDataFixtures {
  static const directory = 'test/fixtures';

  /// Copies [name] (e.g. 'ios_with_data') with its -wal and -shm files into [target] as Model.sqlite.
  static String copyTo(String name, Directory target) {
    final targetPath = p.join(target.path, 'Model.sqlite');
    for (final suffix in ['', '-wal', '-shm']) {
      final source = File(p.join(directory, '$name.sqlite$suffix'));
      if (source.existsSync()) {
        source.copySync('$targetPath$suffix');
      }
    }
    return targetPath;
  }

  /// SYNTHETIC DATA: applies [change] to a copy of a fixture.
  static Future<void> changeCopy(String path, Future<void> Function(Database database) change) async {
    final database = await databaseFactoryFfiNoIsolate.openDatabase(path);
    await change(database);
    await database.close();
  }
}
