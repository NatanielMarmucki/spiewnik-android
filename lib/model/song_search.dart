import 'package:spiewnik/model/polish_collation.dart';
import 'package:spiewnik/model/song_model.dart';

/// Song search over the text of the whole songbook.
///
/// The search text of each song (lower case, no diacritics, cleaned content) is computed once, on the
/// first search, and kept in memory: recomputing it for 2000 songs on every query took about 120 ms in
/// release. Songs are keyed by number and the entry is rebuilt when the title or content differs, so
/// the cache survives the reloads a favorite causes (new Song objects, same text).
///
/// Pure Dart on purpose, so tools/search_benchmark.dart measures this code compiled ahead of time.
class SongSearch {
  final Map<int, _SearchText> _texts = {};

  /// Songs matching [query], in the order of [songs]: title, content or number contains the query,
  /// ignoring letter case and Polish diacritics.
  List<Song> filter(List<Song> songs, String query) {
    final needle = normalizeWhitespace(removePolishDiacritics(query.toLowerCase()));
    final titleNeedle = removePolishDiacritics(query.toLowerCase());
    return [
      for (final song in songs)
        if (_matches(_textOf(song), song, needle, titleNeedle, query)) song,
    ];
  }

  bool _matches(_SearchText text, Song song, String needle, String titleNeedle, String query) =>
      (titleNeedle.isNotEmpty && text.title.contains(titleNeedle)) ||
      text.content.contains(needle) ||
      song.number.toString().contains(query);

  _SearchText _textOf(Song song) {
    final cached = _texts[song.number];
    if (cached != null && cached.sourceTitle == song.title && cached.sourceContent == song.content) {
      return cached;
    }
    return _texts[song.number] = _SearchText(song.title, song.content);
  }

  /// Collapses runs of whitespace into a single space.
  ///
  /// Removing the ignored characters leaves gaps inside the text: „Baranku Boży, x zmiłuj się"
  /// became „Baranku Boży  zmiłuj się" with a double space, so the query „boży zmiłuj" did not
  /// match, but „boży  zmiłuj" did. Both sides are now normalized the same way, so both work.
  static String normalizeWhitespace(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

class _SearchText {
  final String sourceTitle;
  final String sourceContent;
  final String title;
  final String content;

  _SearchText(this.sourceTitle, this.sourceContent)
      : title = removePolishDiacritics(sourceTitle.toLowerCase()),
        content = _removeIgnored(removePolishDiacritics(sourceContent.toLowerCase()));

  /// Verse numbers, punctuation and the repeat markers' x, removed from the content before matching.
  /// The set is kept as it was; issue #49 lists its inconsistencies (no 0, no /, x everywhere).
  static final Set<int> _ignored = "123456789,.;:'[]()!?-”—„x".codeUnits.toSet();

  /// Removes the ignored characters and collapses whitespace in one pass; the same result as removing
  /// them and then applying [SongSearch.normalizeWhitespace], at a fraction of the cost (the regex alone
  /// took about half of the first search).
  static String _removeIgnored(String text) {
    final units = <int>[];
    var pendingSpace = false;
    for (final unit in text.codeUnits) {
      if (_ignored.contains(unit)) {
        continue;
      }
      if (_isWhitespace(unit)) {
        pendingSpace = units.isNotEmpty;
        continue;
      }
      if (pendingSpace) {
        units.add(0x20);
        pendingSpace = false;
      }
      units.add(unit);
    }
    return String.fromCharCodes(units);
  }

  /// The characters matched by `\s` in a Dart regular expression.
  static bool _isWhitespace(int unit) =>
      (unit >= 0x09 && unit <= 0x0D) ||
      unit == 0x20 ||
      unit == 0xA0 ||
      unit == 0x1680 ||
      (unit >= 0x2000 && unit <= 0x200A) ||
      unit == 0x2028 ||
      unit == 0x2029 ||
      unit == 0x202F ||
      unit == 0x205F ||
      unit == 0x3000 ||
      unit == 0xFEFF;
}
