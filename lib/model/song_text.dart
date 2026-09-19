/// Parser for the song text markers from docs/DESIGN-SYSTEM.md, section 3.
///
/// The database holds one string with markers. The parser **strips the markers from the text flow**
/// and returns a structure of blocks, so the renderer turns them into typography, not icons:
///
/// | pattern | meaning |
/// |---|---|
/// | `^\d+\.\s` | verse number |
/// | `^Refren:\s` | chorus |
/// | `[: … :]` | repeat |
/// | `\n\n` | block boundary |
///
/// Repeat marks stay in the content as [RepeatMark], because the renderer shows them in the accent color.
/// A single `\n` inside a block is kept: if the data ever gets its line breaks back,
/// the same renderer will start showing them without a redesign.
library;

/// A block of text: a verse, a chorus, or a paragraph without a marker.
sealed class SongBlock {
  /// Block content after the markers are stripped, in pieces.
  final List<SongInline> inlines;

  const SongBlock(this.inlines);

  /// Just the block text, without repeat marks. Useful in tests and for the screen reader.
  String get text => inlines.whereType<SongText>().map((part) => part.text).join();
}

/// A numbered verse, e.g. `1. Alleluja…`.
class VerseBlock extends SongBlock {
  final int number;

  /// The first verse of the song: the renderer opens it with a drop cap instead of the number.
  final bool isFirst;

  const VerseBlock({required this.number, required this.isFirst, required List<SongInline> inlines})
    : super(inlines);
}

/// The chorus, marked `Refren:` in the data.
class RefrainBlock extends SongBlock {
  const RefrainBlock(super.inlines);
}

/// A paragraph without a marker at the start.
class PlainBlock extends SongBlock {
  const PlainBlock(super.inlines);
}

/// A piece of block content.
sealed class SongInline {
  const SongInline();
}

/// Plain text.
class SongText extends SongInline {
  final String text;

  const SongText(this.text);
}

/// A repeat mark: `[:` or `:]`. The renderer shows it in the accent color,
/// attached to the neighboring word.
class RepeatMark extends SongInline {
  final bool isOpening;

  const RepeatMark({required this.isOpening});

  String get text => isOpening ? '[:' : ':]';
}

/// Splits song content into blocks.
class SongTextParser {
  static final RegExp _verse = RegExp(r'^(\d+)\.\s+');
  static final RegExp _refrain = RegExp(r'^Refren:\s+');
  static final RegExp _blockSeparator = RegExp(r'\n\s*\n+');

  const SongTextParser();

  List<SongBlock> parse(String content) {
    final blocks = <SongBlock>[];
    var seenVerse = false;

    for (final raw in content.split(_blockSeparator)) {
      final block = raw.trim();
      if (block.isEmpty) {
        continue;
      }

      final verse = _verse.firstMatch(block);
      if (verse != null) {
        final number = int.parse(verse.group(1)!);
        blocks.add(
          VerseBlock(
            number: number,
            isFirst: !seenVerse,
            inlines: _inlines(block.substring(verse.end)),
          ),
        );
        seenVerse = true;
        continue;
      }

      final refrain = _refrain.firstMatch(block);
      if (refrain != null) {
        blocks.add(RefrainBlock(_inlines(block.substring(refrain.end))));
        continue;
      }

      blocks.add(PlainBlock(_inlines(block)));
    }

    return blocks;
  }

  /// Splits block text into plain text and repeat marks.
  ///
  /// Only a **pair** `[: … :]` becomes repeat marks. An unpaired mark stays plain text:
  /// the data has typos like `[Czym prędzej pośpiesz Doń!:]`, where the opening lost its colon.
  /// The renderer then does not pretend there is a repeat.
  List<SongInline> _inlines(String text) {
    final paired = _pairedMarkOffsets(text);
    final parts = <SongInline>[];
    final buffer = StringBuffer();

    void flush() {
      if (buffer.isNotEmpty) {
        parts.add(SongText(buffer.toString()));
        buffer.clear();
      }
    }

    for (var i = 0; i < text.length; i++) {
      if (paired.contains(i)) {
        flush();
        parts.add(RepeatMark(isOpening: text.startsWith('[:', i)));
        i++; // second character of the pair
        continue;
      }
      buffer.write(text[i]);
    }
    flush();

    return parts;
  }

  /// Positions of the marks that form opening-closing pairs.
  Set<int> _pairedMarkOffsets(String text) {
    final openings = <int>[];
    final paired = <int>{};
    for (var i = 0; i < text.length - 1; i++) {
      if (text.startsWith('[:', i)) {
        openings.add(i);
        i++;
      } else if (text.startsWith(':]', i)) {
        if (openings.isNotEmpty) {
          paired..add(openings.removeLast())..add(i);
        }
        i++;
      }
    }
    return paired;
  }
}
