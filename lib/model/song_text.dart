/// Parser znaczników tekstu pieśni z docs/DESIGN-SYSTEM.md, sekcja 3.
///
/// Baza trzyma jeden ciąg znaków ze znacznikami. Parser **zdejmuje znaczniki z toku tekstu**
/// i zwraca strukturę bloków, żeby renderer zamienił je na typografię, a nie na ikony:
///
/// | wzorzec | znaczenie |
/// |---|---|
/// | `^\d+\.\s` | numer zwrotki |
/// | `^Refren:\s` | refren |
/// | `[: … :]` | powtórzenie |
/// | `\n\n` | granica bloku |
///
/// Znaki powtórzenia zostają w treści jako [RepeatMark], bo renderer pokazuje je w akcencie.
/// Pojedyncze `\n` wewnątrz bloku jest zachowywane: gdyby dane kiedyś odzyskały łamanie wierszy,
/// ten sam renderer zacznie je pokazywać bez przeprojektowania.
library;

/// Blok tekstu: zwrotka, refren albo akapit bez znacznika.
sealed class SongBlock {
  /// Treść bloku po zdjęciu znaczników, w kawałkach.
  final List<SongInline> inlines;

  const SongBlock(this.inlines);

  /// Sam tekst bloku, bez znaków powtórzenia. Przydatne w testach i do czytnika ekranu.
  String get text => inlines.whereType<SongText>().map((part) => part.text).join();
}

/// Zwrotka z numerem, np. `1. Alleluja…`.
class VerseBlock extends SongBlock {
  final int number;

  /// Pierwsza zwrotka pieśni: renderer otwiera ją inicjałem zamiast numeru.
  final bool isFirst;

  const VerseBlock({required this.number, required this.isFirst, required List<SongInline> inlines})
    : super(inlines);
}

/// Refren, w danych oznaczony `Refren:`.
class RefrainBlock extends SongBlock {
  const RefrainBlock(super.inlines);
}

/// Akapit bez znacznika na początku.
class PlainBlock extends SongBlock {
  const PlainBlock(super.inlines);
}

/// Kawałek treści bloku.
sealed class SongInline {
  const SongInline();
}

/// Zwykły tekst.
class SongText extends SongInline {
  final String text;

  const SongText(this.text);
}

/// Znak powtórzenia: `[:` albo `:]`. Renderer pokazuje go w kolorze akcentu,
/// przyklejonego do sąsiedniego słowa.
class RepeatMark extends SongInline {
  final bool isOpening;

  const RepeatMark({required this.isOpening});

  String get text => isOpening ? '[:' : ':]';
}

/// Rozkłada treść pieśni na bloki.
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

  /// Dzieli tekst bloku na zwykły tekst i znaki powtórzenia.
  ///
  /// Znakiem powtórzenia zostaje tylko **para** `[: … :]`. Niesparowany znak zostaje zwykłym
  /// tekstem: w danych zdarzają się literówki w rodzaju `[Czym prędzej pośpiesz Doń!:]`,
  /// gdzie otwarcie zgubiło dwukropek. Renderer nie udaje wtedy powtórzenia.
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
        i++; // drugi znak pary
        continue;
      }
      buffer.write(text[i]);
    }
    flush();

    return parts;
  }

  /// Pozycje znaków, które tworzą pary otwarcie-zamknięcie.
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
