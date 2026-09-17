import 'dart:io';

import 'package:spiewnik/objectbox.g.dart';

/// ObjectBox store in a temporary directory. Requires the native library in lib/,
/// see tools/fetch_objectbox_lib.sh.
class TestStore {
  final Directory _directory;
  final Store store;

  TestStore._(this._directory, this.store);

  factory TestStore.open() {
    final directory = Directory.systemTemp.createTempSync('spiewnik_test_');
    return TestStore._(directory, Store(getObjectBoxModel(), directory: directory.path));
  }

  void close() {
    store.close();
    _directory.deleteSync(recursive: true);
  }
}
