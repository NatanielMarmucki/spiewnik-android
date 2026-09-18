import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spiewnik/json_manager.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/model/song_text.dart';

/// Parser na prawdziwych pieśniach z assetu, nie na wymyślonych ciągach.
void main() {
  const parser = SongTextParser();
  late Map<int, Song> songs;

  setUpAll(() {
    final data = SongsData.fromJsonString(File('assets/songs_data.json').readAsStringSync());
    songs = {for (final song in data.songs) song.number: song};
  });

  List<SongBlock> parseSong(int number) => parser.parse(songs[number]!.content);

  group('pieśń 1 „Alleluja, chwalcie Pana” — zwrotki, refren i powtórzenie', () {
    test('dzieli na bloki bez pustych wierszy', () {
      final blocks = parseSong(1);

      expect(blocks, isNotEmpty);
      expect(blocks.every((block) => block.text.trim().isNotEmpty), isTrue);
      expect(blocks.first, isA<VerseBlock>());
    });

    test('pierwsza zwrotka jest oznaczona jako pierwsza, kolejne nie', () {
      final verses = parseSong(1).whereType<VerseBlock>().toList();

      expect(verses.first.number, 1);
      expect(verses.first.isFirst, isTrue);
      expect(verses.skip(1).map((verse) => verse.isFirst), everyElement(isFalse));
      expect(verses.map((verse) => verse.number), [1, 2, 3]);
    });

    test('zdejmuje numer zwrotki z toku tekstu', () {
      final first = parseSong(1).whereType<VerseBlock>().first;

      expect(first.text, startsWith('Alleluja, chwalcie Pana'));
      expect(first.text, isNot(startsWith('1.')));
    });

    test('zdejmuje etykietę refrenu z toku tekstu', () {
      final refrain = parseSong(1).whereType<RefrainBlock>().single;

      expect(refrain.text, startsWith('Wysławiajcie imię Pańskie'));
      expect(refrain.text, isNot(contains('Refren:')));
    });

    test('znaki powtórzenia zostają jako osobne kawałki, a nie w tekście', () {
      final refrain = parseSong(1).whereType<RefrainBlock>().single;
      final marks = refrain.inlines.whereType<RepeatMark>().toList();

      expect(marks.map((mark) => mark.text), ['[:', ':]']);
      expect(refrain.text, isNot(contains('[:')));
      expect(refrain.text, contains('Niech są pełne Jego chwały,'));
    });
  });

  group('pieśń 2 „Barankowi chwałę” — bez refrenu', () {
    test('ma same zwrotki', () {
      final blocks = parseSong(2);

      expect(blocks.whereType<RefrainBlock>(), isEmpty);
      expect(blocks.whereType<VerseBlock>().length, blocks.length);
    });
  });

  group('pieśń 6 „Barankowi cześć” — powtórzenie przez całą zwrotkę', () {
    test('zwrotka zaczyna się i kończy znakami powtórzenia', () {
      final first = parseSong(6).whereType<VerseBlock>().first;

      expect(first.inlines.first, isA<RepeatMark>());
      expect((first.inlines.first as RepeatMark).isOpening, isTrue);
      expect(first.inlines.whereType<RepeatMark>().length, greaterThanOrEqualTo(2));
    });

    test('tekst między znakami zostaje w całości, także gdy jest długi', () {
      final first = parseSong(6).whereType<VerseBlock>().first;

      expect(first.text, contains('Barankowi cześć, chwała Mu!'));
      expect(first.text.length, greaterThan(60));
    });
  });

  group('cały śpiewnik', () {
    test('żaden blok nie jest pusty i nie zaczyna się od znacznika', () {
      for (final song in songs.values) {
        final blocks = parser.parse(song.content);
        expect(blocks, isNotEmpty, reason: 'pieśń ${song.number}');
        for (final block in blocks) {
          expect(block.text.trim(), isNotEmpty, reason: 'pieśń ${song.number}');
          expect(block.text.trimLeft(), isNot(startsWith('Refren:')), reason: 'pieśń ${song.number}');
          expect(
            RegExp(r'^\d+\.\s').hasMatch(block.text.trimLeft()),
            isFalse,
            reason: 'pieśń ${song.number}',
          );
        }
      }
    });

    test('znaki powtórzenia zawsze się równoważą w bloku', () {
      for (final song in songs.values) {
        for (final block in parser.parse(song.content)) {
          var open = 0;
          for (final mark in block.inlines.whereType<RepeatMark>()) {
            open += mark.isOpening ? 1 : -1;
            expect(open, greaterThanOrEqualTo(0), reason: 'pieśń ${song.number}: zamknięcie bez otwarcia');
          }
          expect(open, 0, reason: 'pieśń ${song.number}: otwarcie bez zamknięcia');
        }
      }
    });

    test('tekst po złożeniu z powrotem zgadza się z oryginałem bez znaczników', () {
      final song = songs[15]!;
      final joined = parser
          .parse(song.content)
          .map((block) => block.inlines.map((part) => part is SongText ? part.text : (part as RepeatMark).text).join())
          .join('\n\n');
      final original = song.content
          .replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '')
          .replaceAll(RegExp(r'^Refren:\s+', multiLine: true), '')
          .replaceAll(RegExp(r'\n\s*\n+'), '\n\n')
          .trim();

      expect(joined, original);
    });
  });

  group('literówki w danych', () {
    test('niesparowany znak zostaje zwykłym tekstem, nie znacznikiem', () {
      // Pieśń 169: w danych jest „[Czym prędzej pośpiesz Doń!:]” — otwarcie zgubiło dwukropek.
      final blocks = parseSong(169);
      final withStray = blocks.firstWhere((block) => block.text.contains('Czym prędzej'));

      expect(withStray.inlines.whereType<RepeatMark>(), isEmpty);
      expect(withStray.text, contains(':]'));
    });

    test('para w tym samym bloku nadal działa', () {
      final blocks = parser.parse('1. Zwykły [:powtarzany:] tekst i samotny :] znak');
      final marks = blocks.single.inlines.whereType<RepeatMark>().toList();

      expect(marks.map((mark) => mark.text), ['[:', ':]']);
      expect(blocks.single.text, '1. Zwykły '.replaceFirst('1. ', '') + 'powtarzany tekst i samotny :] znak');
    });
  });

  group('zachowania szczegółowe', () {
    test('pojedyncze łamanie wiersza w bloku zostaje', () {
      final blocks = parser.parse('1. Pierwszy wers\ndrugi wers\n\n2. Kolejna zwrotka');

      expect(blocks, hasLength(2));
      expect(blocks.first.text, 'Pierwszy wers\ndrugi wers');
    });

    test('blok bez znacznika trafia do akapitu zwykłego', () {
      final blocks = parser.parse('Sam tekst bez numeru');

      expect(blocks.single, isA<PlainBlock>());
      expect(blocks.single.text, 'Sam tekst bez numeru');
    });

    test('pusta treść daje pustą listę bloków', () {
      expect(parser.parse(''), isEmpty);
      expect(parser.parse('\n\n  \n'), isEmpty);
    });
  });
}
