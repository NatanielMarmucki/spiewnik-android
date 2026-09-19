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

  /// Songs matching [query], in the order of [songs]: the number contains the query, or **every** word
  /// of the query is found in the title or the content (see [findWord]), in any order, ignoring letter
  /// case, Polish diacritics and punctuation.
  List<Song> filter(List<Song> songs, String query) {
    final words = queryWords(query);
    return [
      for (final song in songs)
        if (song.number.toString().contains(query) || (words.isNotEmpty && _hasAll(_textOf(song), words))) song,
    ];
  }

  bool _hasAll(_SearchText text, List<String> words) =>
      words.every((word) => findWord(text.title, word) >= 0 || findWord(text.content, word) >= 0);

  /// Parts of [song]'s title matching the words of [query], with the original letters, for highlighting.
  List<String> titleMatches(Song song, String query) {
    final title = _textOf(song).title;
    return [
      for (final word in queryWords(query))
        if (findWord(title, word) case final start when start >= 0)
          // Lowercasing and removing diacritics keep every letter in place, so positions match the original.
          song.title.substring(start, _highlightEnd(title, start, word)),
    ];
  }

  /// End of the highlight for [word] found at [start]: as long as the typed word, but not past the end
  /// of the word in the title, so "chwałę" highlights "Chwały" whole and "chwal" only "Chwal" of "Chwalże".
  static int _highlightEnd(String title, int start, String word) {
    var end = start;
    while (end < title.length && end - start < word.length && _isLetter(title.codeUnitAt(end))) {
      end++;
    }
    return end;
  }

  /// Where [word] of a query is found in normalized [text], or -1. The rule depends on its length:
  /// - 1-2 letters: a whole word, so "o" or "na" do not match inside every other word;
  /// - 3-4 letters: the start of a word ("pan" finds "Panu", not "wspaniały");
  /// - 5 letters or more: the start of a word, after cutting a Polish ending off the query word
  ///   ([stem]), so "chwała" finds "chwały" and "matko" finds "matka".
  static int findWord(String text, String word) {
    final needle = _needle(word);
    final whole = word.length <= 2;
    for (var at = text.indexOf(needle); at >= 0; at = text.indexOf(needle, at + 1)) {
      final startsWord = at == 0 || !_isLetter(text.codeUnitAt(at - 1));
      final end = at + needle.length;
      final endsWord = end == text.length || !_isLetter(text.codeUnitAt(end));
      if (startsWord && (!whole || endsWord)) {
        return at;
      }
    }
    return -1;
  }

  static String _needle(String word) => word.length >= 5 ? stem(word) : word;

  /// [word] without its Polish inflectional ending, if at least 4 letters remain: "chwala" becomes
  /// "chwal", "jezusowi" "jezus". A light stemmer, not a dictionary: an ending is cut only when the word
  /// has one from the list, and alternating vowels ("baranek", "baranka") stay out of reach.
  static String stem(String word) {
    for (final ending in _endings) {
      if (word.length - ending.length >= 4 && word.endsWith(ending)) {
        return word.substring(0, word.length - ending.length);
      }
    }
    return word;
  }

  /// Polish endings, without diacritics (ą, ę became a, e), longest first so "-ami" wins over "-i".
  static const List<String> _endings = [
    'ami', 'ach', 'ego', 'emu', 'ymi', 'imi', 'owi', //
    'ow', 'om', 'ie', 'ia', 'iu', 'ej', //
    'a', 'e', 'i', 'o', 'u', 'y',
  ];

  /// A letter of the normalized text: a-z, or anything from Latin-1 letters up (foreign accented
  /// letters). Spaces, digits, "/" of the repeat markers and other punctuation separate words.
  static bool _isLetter(int unit) =>
      (unit >= 0x61 && unit <= 0x7A) || (unit >= 0xC0 && unit != 0xD7 && unit != 0xF7 && unit < 0x2000);

  /// Words of [query]: lower case, no diacritics, split on whitespace and on the punctuation that is
  /// removed from the song text too.
  static List<String> queryWords(String query) => [
        for (final word in removePolishDiacritics(query.toLowerCase()).split(_wordSeparators))
          if (word.isNotEmpty) word,
      ];

  static final RegExp _wordSeparators = RegExp(r"[\s,.;:'\[\]()!?\-”—„]+");

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
