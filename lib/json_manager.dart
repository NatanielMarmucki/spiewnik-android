
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:objectbox/objectbox.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:logger/logger.dart';

/// Contents of the songs asset.
///
/// Reads the current format `{"dataVersion": int, "songs": [...]}` and the
/// legacy formats `{"songs": [...]}` and a bare list, which have
/// [dataVersion] 0.
class SongsData {
  final int dataVersion;
  final List<Song> songs;

  const SongsData({required this.dataVersion, required this.songs});

  factory SongsData.fromJsonString(String jsonString) => SongsData.fromJson(jsonDecode(jsonString));

  /// Throws [FormatException] on any malformed entry instead of skipping it:
  /// an update removes songs missing from the file, so partial data would
  /// delete songs together with their favorite status.
  factory SongsData.fromJson(Object? json) {
    final int dataVersion;
    final Object? rawSongs;
    if (json is Map<String, dynamic>) {
      final version = json['dataVersion'];
      if (version == null) {
        dataVersion = 0;
      } else if (version is int && version >= 1) {
        dataVersion = version;
      } else {
        throw FormatException('"dataVersion" must be a positive integer, got: $version');
      }
      rawSongs = json['songs'];
    } else {
      dataVersion = 0;
      rawSongs = json;
    }

    if (rawSongs is! List) {
      throw const FormatException('Expected a list of songs (top-level list or a "songs" key).');
    }
    if (rawSongs.isEmpty) {
      throw const FormatException('The songs list is empty.');
    }

    final List<Song> songs = [];
    final Set<int> numbers = {};
    for (var i = 0; i < rawSongs.length; i++) {
      final item = rawSongs[i];
      if (item is! Map<String, dynamic>) {
        throw FormatException('songs[$i] is not an object.');
      }
      final number = item['number'];
      if (number is! int || item['title'] is! String || item['content'] is! String) {
        throw FormatException('songs[$i] must have an int "number" and string "title" and "content".');
      }
      if (!numbers.add(number)) {
        throw FormatException('songs[$i] has a duplicate number $number.');
      }
      songs.add(Song.fromJson(item));
    }
    return SongsData(dataVersion: dataVersion, songs: songs);
  }
}

class JsonManager {
  static const String assetPath = 'assets/songs_data.json';

  /// dataVersion of the songs asset last written to the store.
  static const String dataVersionKey = 'songs_data_version';

  final Store objectBoxStore;
  final Logger _logger;

  JsonManager(this.objectBoxStore, this._logger);

  Future<void> loadDataFromJsonIfNeeded({bool forceUpdate = false}) async {
    final SongsData data;
    try {
      data = SongsData.fromJsonString(await rootBundle.loadString(assetPath));
    } catch (e, s) {
      _logger.e('Could not read $assetPath. Keeping the current data.', error: e, stackTrace: s);
      return;
    }
    await applySongsData(data, forceUpdate: forceUpdate);
  }

  /// Fills an empty store, or overwrites titles and contents when [forceUpdate]
  /// is set or [SongsData.dataVersion] is newer than the last applied one.
  /// Favorites are preserved. The applied dataVersion is saved only after the
  /// store was written successfully.
  Future<void> applySongsData(SongsData data, {bool forceUpdate = false}) async {
    final songBox = objectBoxStore.box<Song>();
    final appliedVersion = await _readAppliedDataVersion();

    try {
      if (songBox.isEmpty()) {
        _logger.i('ObjectBox Store is empty. Loading ${data.songs.length} songs (dataVersion ${data.dataVersion}).');
        songBox.putMany(data.songs);
      } else if (forceUpdate || data.dataVersion > appliedVersion) {
        _logger.i('Updating songs from dataVersion $appliedVersion to ${data.dataVersion} '
            '(forceUpdate: $forceUpdate) while preserving favorites.');
        _updateStore(songBox, data.songs);
      } else {
        _logger.i('Songs are up to date (dataVersion $appliedVersion). Skipping update.');
        return;
      }
    } catch (e, s) {
      _logger.e('Error while writing songs to ObjectBox. Keeping the previous data version.', error: e, stackTrace: s);
      return;
    }

    await _saveAppliedDataVersion(data.dataVersion);
  }

  void _updateStore(Box<Song> songBox, List<Song> songsFromJson) {
    objectBoxStore.runInTransaction(TxMode.write, () {
      final Map<int, Song> existingByNumber = {};
      final List<int> songIdsToRemove = [];
      for (final song in songBox.getAll()) {
        final kept = existingByNumber[song.number];
        if (kept == null) {
          existingByNumber[song.number] = song;
        } else {
          kept.favorite = kept.favorite || song.favorite;
          songIdsToRemove.add(song.id);
        }
      }

      final Set<int> numbersFromJson = {};
      final List<Song> songsToPut = [];
      for (final songFromJson in songsFromJson) {
        numbersFromJson.add(songFromJson.number);
        final existing = existingByNumber[songFromJson.number];
        if (existing == null) {
          songsToPut.add(songFromJson);
        } else {
          existing.title = songFromJson.title;
          existing.content = songFromJson.content;
          songsToPut.add(existing);
        }
      }
      for (final song in existingByNumber.values) {
        if (!numbersFromJson.contains(song.number)) {
          songIdsToRemove.add(song.id);
        }
      }

      songBox.putMany(songsToPut);
      if (songIdsToRemove.isNotEmpty) {
        songBox.removeMany(songIdsToRemove);
      }
      _logger.i('Updated/added ${songsToPut.length} songs, removed ${songIdsToRemove.length}.');
    });
  }

  Future<int> _readAppliedDataVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(dataVersionKey) ?? 0;
    } catch (e) {
      _logger.e('Could not read $dataVersionKey. Assuming 0.', error: e);
      return 0;
    }
  }

  Future<void> _saveAppliedDataVersion(int version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(dataVersionKey, version);
    } catch (e) {
      _logger.e('Could not save $dataVersionKey.', error: e);
    }
  }
}
