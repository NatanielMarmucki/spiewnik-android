import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/json_manager.dart';

void main() {
  group('SongsData.fromJson', () {
    test('reads the current format with dataVersion', () {
      final data = SongsData.fromJsonString(
        '{"dataVersion": 3, "songs": [{"number": 1, "title": "A", "content": "1. a"}]}',
      );
      expect(data.dataVersion, 3);
      expect(data.songs.single.number, 1);
      expect(data.songs.single.title, 'A');
      expect(data.songs.single.content, '1. a');
      expect(data.songs.single.favorite, isFalse);
    });

    test('reads the legacy {"songs": [...]} format as dataVersion 0', () {
      final data = SongsData.fromJsonString(
        '{"songs": [{"number": 1, "title": "A", "content": "a", "favorite": false}]}',
      );
      expect(data.dataVersion, 0);
      expect(data.songs, hasLength(1));
    });

    test('reads a bare list as dataVersion 0', () {
      final data = SongsData.fromJsonString('[{"number": 1, "title": "A", "content": "a"}]');
      expect(data.dataVersion, 0);
      expect(data.songs, hasLength(1));
    });

    final invalid = {
      'dataVersion 0': '{"dataVersion": 0, "songs": [{"number": 1, "title": "A", "content": "a"}]}',
      'dataVersion as string': '{"dataVersion": "1", "songs": [{"number": 1, "title": "A", "content": "a"}]}',
      'no songs key': '{"dataVersion": 1}',
      'empty songs': '{"dataVersion": 1, "songs": []}',
      'entry is not an object': '{"dataVersion": 1, "songs": [1]}',
      'missing title': '{"dataVersion": 1, "songs": [{"number": 1, "content": "a"}]}',
      'number as string': '{"dataVersion": 1, "songs": [{"number": "1", "title": "A", "content": "a"}]}',
      'duplicate number':
          '{"dataVersion": 1, "songs": [{"number": 1, "title": "A", "content": "a"}, {"number": 1, "title": "B", "content": "b"}]}',
    };
    invalid.forEach((name, json) {
      test('rejects: $name', () {
        expect(() => SongsData.fromJsonString(json), throwsFormatException);
      });
    });
  });

  group('bundled song files', () {
    void expectFullSongbook(SongsData data) {
      expect(data.songs, hasLength(2000));
      expect(data.songs.map((s) => s.number).toList(), List.generate(2000, (i) => i + 1));
      expect(data.songs.every((s) => s.title.trim().isNotEmpty && s.content.trim().isNotEmpty), isTrue);
    }

    test('assets/songs_data_v2.json parses with dataVersion 1', () {
      final file = File('assets/songs_data_v2.json');
      if (!file.existsSync()) {
        markTestSkipped('assets/songs_data_v2.json not present');
        return;
      }
      final data = SongsData.fromJsonString(file.readAsStringSync());
      expect(data.dataVersion, 1);
      expectFullSongbook(data);
    });

    test('assets/songs_data.json parses', () {
      final data = SongsData.fromJsonString(File(JsonManager.assetPath).readAsStringSync());
      expectFullSongbook(data);
    });
  });
}
