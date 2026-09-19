import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spiewnik/model/font_size_model.dart';
import 'package:spiewnik/model/song_text.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/theme/app_text_theme.dart';
import 'package:spiewnik/theme/song_text_scale.dart';

/// Song content from docs/DESIGN-SYSTEM.md, section 3: markers replaced with typography.
///
/// - a `2.16 × S` drop cap opens the first verse and replaces its number,
/// - subsequent verses: a `0.74 × S` digit with a rule,
/// - chorus: an uppercase „Refren” label with a rule and a `0.74 × S` indent, no italics,
/// - repeat: `[:` and `:]` marks in the accent, attached to the neighboring words,
/// - a block boundary is a `1.26 × S` gap, never an empty line.
///
/// The size comes from the user's settings (`S`), and the system font scaling is applied on top
/// of it separately, through `textScaler` — never instead of it (rule 5, section 7).
class SongContent extends StatelessWidget {
  final String content;

  /// Inner padding; by default 22 dp on the sides and a block gap at the top and bottom.
  final EdgeInsets? padding;

  /// Whether the content scrolls on its own. The preview in settings already sits in a list, so no.
  final bool scrollable;

  const SongContent({super.key, required this.content, this.padding, this.scrollable = true});

  static const SongTextParser _parser = SongTextParser();

  @override
  Widget build(BuildContext context) {
    final fontSizeModel = context.watch<FontSizeModel>();
    final scale = fontSizeModel.songTextScale;
    final blocks = _parser.parse(content);
    final insets =
        padding ?? EdgeInsets.symmetric(horizontal: SongTextScale.sideMargin, vertical: scale.blockGap);

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) SizedBox(height: scale.blockGap),
          _Block(block: blocks[i], scale: scale),
        ],
      ],
    );

    return Align(
      // To the top, not the center: a short song hung vertically centered and it looked like an
      // accidental empty band above the text.
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: scale.maxColumnWidth),
        child: scrollable
            ? SingleChildScrollView(padding: insets, child: column)
            : Padding(padding: insets, child: column),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  final SongBlock block;
  final SongTextScale scale;

  const _Block({required this.block, required this.scale});

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      VerseBlock(isFirst: true) => _FirstVerse(block: block as VerseBlock, scale: scale),
      VerseBlock() => _Verse(block: block as VerseBlock, scale: scale),
      RefrainBlock() => _Refrain(block: block as RefrainBlock, scale: scale),
      PlainBlock() => _Paragraph(block: block, scale: scale),
    };
  }
}

/// First verse: a drop cap instead of the number.
class _FirstVerse extends StatelessWidget {
  final VerseBlock block;
  final SongTextScale scale;

  const _FirstVerse({required this.block, required this.scale});

  /// A letter, including Polish ones with diacritics (ą, ę) — digits, brackets and quotation marks get
  /// no drop cap.
  static bool _startsWithLetter(String text) => RegExp(r'^\p{L}', unicode: true).hasMatch(text);

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final color = Theme.of(context).colorScheme.onSurface;
    final body = scale.textStyle(color: color);
    final initialStyle = body.copyWith(fontSize: scale.initialSize, height: 1.0);

    final spans = _inlineSpans(block.inlines, body, appColors.accent);
    final first = spans.isEmpty ? null : spans.first;

    // The drop cap is the first **letter** of the content. When a verse starts with a symbol (e.g. the
    // „[:” that opens a repeat, or a quotation mark), enlarging it looks like a bug, so the verse goes
    // without a drop cap.
    if (first is! TextSpan || (first.text ?? '').isEmpty || !_startsWithLetter(first.text!)) {
      return Text.rich(TextSpan(children: spans), style: body);
    }
    final text = first.text!;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text.substring(0, 1), style: initialStyle),
          TextSpan(text: text.substring(1), style: body),
          ...spans.skip(1),
        ],
      ),
      style: body,
    );
  }
}

/// Subsequent verse: a digit with a rule above the paragraph.
class _Verse extends StatelessWidget {
  final VerseBlock block;
  final SongTextScale scale;

  const _Verse({required this.block, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MarkerLine(
          ruleWidth: scale.verseRuleWidth,
          label: Text(
            '${block.number}',
            style: scale.textStyle(color: context.appColors.textSecondary).copyWith(
              fontSize: scale.verseNumberSize,
              fontFeatures: tabularFigures,
            ),
          ),
        ),
        SizedBox(height: scale.blockGap / 3),
        _Paragraph(block: block, scale: scale),
      ],
    );
  }
}

/// Chorus: an uppercase label with a rule, and an indent.
class _Refrain extends StatelessWidget {
  final RefrainBlock block;
  final SongTextScale scale;

  const _Refrain({required this.block, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MarkerLine(
          ruleWidth: scale.verseRuleWidth,
          label: Text('REFREN', style: Theme.of(context).textTheme.labelMedium),
        ),
        SizedBox(height: scale.blockGap / 3),
        Padding(
          padding: EdgeInsets.only(left: scale.refrainIndent),
          child: _Paragraph(block: block, scale: scale),
        ),
      ],
    );
  }
}

/// Block label with a short hairline next to it.
///
/// The line is **short and fixed** (1.5 × S): a full-width leader line means something else in the
/// index, where it guides the eye to the song number, and repeating it in the song text is confusing.
class _MarkerLine extends StatelessWidget {
  final Widget label;
  final double ruleWidth;

  const _MarkerLine({required this.label, required this.ruleWidth});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        label,
        const SizedBox(width: 8.0),
        Container(height: 1.0, width: ruleWidth, color: context.appColors.line),
      ],
    );
  }
}

/// Paragraph of the block content, with the repeat marks in the accent.
class _Paragraph extends StatelessWidget {
  final SongBlock block;
  final SongTextScale scale;

  const _Paragraph({required this.block, required this.scale});

  @override
  Widget build(BuildContext context) {
    final style = scale.textStyle(color: Theme.of(context).colorScheme.onSurface);
    return Text.rich(
      TextSpan(children: _inlineSpans(block.inlines, style, context.appColors.accent)),
      style: style,
    );
  }
}

/// Turns the block's pieces into spans: plain text and repeat marks in the accent.
///
/// The marks have no space before or after the neighboring word, so they stay with the phrase even
/// when the paragraph wraps in the middle of it.
List<InlineSpan> _inlineSpans(List<SongInline> inlines, TextStyle style, Color accent) {
  return [
    for (final part in inlines)
      switch (part) {
        SongText(:final text) => TextSpan(text: text),
        RepeatMark() => TextSpan(text: part.text, style: style.copyWith(color: accent)),
      },
  ];
}
