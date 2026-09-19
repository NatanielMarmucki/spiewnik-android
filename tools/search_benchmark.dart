// Measures song search on the real songbook, compiled ahead of time like a release build:
//
//   dart compile exe tools/search_benchmark.dart -o build/search_benchmark && build/search_benchmark
//
// Numbers are from this machine's CPU; a mid-range phone is a few times slower.
// ignore_for_file: avoid_print (a command-line tool: printing is its output)
import 'dart:convert';
import 'dart:io';

import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/model/song_search.dart';

const _queries = ['a', 'na', 'pan', 'chwala', 'zbawien', 'chwala pan', 'matko', 'jezu ufam tobie', '12'];

void main() {
  final json = jsonDecode(File('assets/songs_data.json').readAsStringSync()) as Map<String, dynamic>;
  final songs = [
    for (final s in json['songs'] as List)
      Song(number: s['number'] as int, title: s['title'] as String, content: s['content'] as String, favorite: false),
  ];

  final search = SongSearch();
  final first = Stopwatch()..start();
  search.filter(songs, 'pan');
  print('first search (builds the normalized text): ${_ms(first.elapsedMicroseconds)} ms');

  print('query'.padRight(18) + 'median ms'.padLeft(10) + 'hits'.padLeft(7));
  for (final query in _queries) {
    final times = <int>[];
    late int hits;
    for (var i = 0; i < 25; i++) {
      final watch = Stopwatch()..start();
      hits = search.filter(songs, query).length;
      times.add(watch.elapsedMicroseconds);
    }
    times.sort();
    print(query.padRight(18) + _ms(times[times.length ~/ 2]).padLeft(10) + '$hits'.padLeft(7));
  }
}

String _ms(int microseconds) => (microseconds / 1000).toStringAsFixed(1);
