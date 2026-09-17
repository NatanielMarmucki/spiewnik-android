/// Compares text in Polish alphabetical order, ignoring letter case: a ą b c ć d e ę … z ź ż.
///
/// Dart has no locale-aware collation, and comparing code units would put every Polish letter
/// after "z". Each Polish letter sorts right after its base letter (ż after ź). Characters outside
/// the Polish alphabet keep their code point order: digits and punctuation before letters, other
/// accented letters after "ż". A shorter text that is a prefix of a longer one comes first, so an
/// empty text is always first.
int comparePolish(String a, String b) {
  final left = a.toLowerCase().runes.toList();
  final right = b.toLowerCase().runes.toList();
  final length = left.length < right.length ? left.length : right.length;
  for (var i = 0; i < length; i++) {
    final result = _weight(left[i]).compareTo(_weight(right[i]));
    if (result != 0) {
      return result;
    }
  }
  return left.length.compareTo(right.length);
}

/// Position of each Polish letter after its base letter: 1 for ą ć ę ł ń ó ś ź, 2 for ż.
final Map<int, (int, int)> _polishLetters = {
  for (final entry in {
    'ą': ('a', 1),
    'ć': ('c', 1),
    'ę': ('e', 1),
    'ł': ('l', 1),
    'ń': ('n', 1),
    'ó': ('o', 1),
    'ś': ('s', 1),
    'ź': ('z', 1),
    'ż': ('z', 2),
  }.entries)
    entry.key.runes.single: (entry.value.$1.runes.single, entry.value.$2),
};

/// Replaces Polish letters with their base letters, keeping letter case: "Źródło" becomes "Zrodlo".
/// Used by search, so a query typed without diacritics finds text with them and the other way round.
String removePolishDiacritics(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    buffer.writeCharCode(_baseLetters[rune] ?? rune);
  }
  return buffer.toString();
}

/// Base letter of each Polish letter, in lower and upper case.
final Map<int, int> _baseLetters = {
  for (final entry in _polishLetters.entries) ...{
    entry.key: entry.value.$1,
    String.fromCharCode(entry.key).toUpperCase().runes.single:
        String.fromCharCode(entry.value.$1).toUpperCase().runes.single,
  },
};

int _weight(int rune) {
  final polish = _polishLetters[rune];
  return polish == null ? rune * 3 : polish.$1 * 3 + polish.$2;
}
