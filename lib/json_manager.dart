
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:objectbox/objectbox.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:logger/logger.dart';

class JsonManager {
  final Store objectBoxStore;
  final Logger _logger;

  JsonManager(this.objectBoxStore, this._logger);

  Future<void> loadDataFromJsonIfNeeded({bool forceUpdate = false}) async {
    final songBox = objectBoxStore.box<Song>();

    if (songBox.isEmpty()) {
      _logger.i('ObjectBox Store is empty. Loading initial data from JSON.');
      await _populateFreshStoreFromJson(songBox);
    } else if (forceUpdate) {
      _logger.i('Forced update. Updating data from JSON while preserving favorites.');
      await _updateStoreFromJson(songBox);
    } else {
      _logger.i('ObjectBox Store already contains data. Skipping loading/updating from JSON.');
    }
  }

  Future<void> _populateFreshStoreFromJson(Box<Song> songBox) async {
    try {
      final String jsonString = await rootBundle.loadString('assets/songs_data.json');
      final dynamic jsonData = jsonDecode(jsonString);

      List<dynamic> jsonList;

      if (jsonData is Map<String, dynamic> && jsonData.containsKey('songs') && jsonData['songs'] is List) {
        jsonList = jsonData['songs'] as List<dynamic>;
      } else if (jsonData is List<dynamic>) {
        jsonList = jsonData;
      } else {
        _logger.e('JSON data is not in the expected format (List or Map with a "songs" key).');
        return;
      }

      final List<Song> songsToPut = [];

      for (final songData in jsonList) {
        if (songData is Map<String, dynamic>) {
          songsToPut.add(Song.fromJson(songData));
        }
      }

      if (songsToPut.isNotEmpty) {
        songBox.putMany(songsToPut);
        _logger.i('Successfully loaded ${songsToPut.length} songs into the empty ObjectBox Store.');
      } else {
        _logger.i('No songs found in the JSON file or the file is empty/malformed.');
      }
    } catch (e, s) {
      _logger.e('Error during initial data loading from JSON: $e', error: e, stackTrace: s);
    }
  }

  Future<void> _updateStoreFromJson(Box<Song> songBox) async {
    try {
      final List<Song> existingSongs = songBox.getAll();
      final Map<int, Song> existingSongsMap = {
        for (var song in existingSongs) song.number: song
      };

      final String jsonString = await rootBundle.loadString('assets/songs_data.json');
      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;

      final List<Song> songsToPutOrUpdate = [];
      final Set<int> songNumbersFromJson = {};

      for (final jsonData in jsonList) {
        if (jsonData is Map<String, dynamic>) {
          final songFromJson = Song.fromJson(jsonData);
          songNumbersFromJson.add(songFromJson.number);

          if (existingSongsMap.containsKey(songFromJson.number)) {
            final existingSong = existingSongsMap[songFromJson.number]!;

            existingSong.title = songFromJson.title;
            existingSong.content = songFromJson.content;

            songsToPutOrUpdate.add(existingSong);
          } else {
            songsToPutOrUpdate.add(songFromJson);
          }
        }
      }

      final List<int> songIdsToRemove = [];
      for (final existingSong in existingSongs) {
        if (!songNumbersFromJson.contains(existingSong.number)) {
          songIdsToRemove.add(existingSong.id);
        }
      }

      if (songsToPutOrUpdate.isNotEmpty) {
        songBox.putMany(songsToPutOrUpdate);
        _logger.i('Successfully updated/added ${songsToPutOrUpdate.length} songs.');
      }

      if (songIdsToRemove.isNotEmpty) {
        songBox.removeMany(songIdsToRemove);
        _logger.i('Removed ${songIdsToRemove.length} songs that were not in the JSON file.');
      }

      if (songsToPutOrUpdate.isEmpty && songIdsToRemove.isEmpty) {
        _logger.i('No songs found in the JSON file for update or the file is empty.');
      }

    } catch (e) {
      _logger.e('Error during data update from JSON: $e');
    }
  }
}
