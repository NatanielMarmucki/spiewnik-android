import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spiewnik/model/font_size_model.dart';
import 'package:spiewnik/model/song_text.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/theme/app_text_theme.dart';
import 'package:spiewnik/theme/song_text_scale.dart';

/// Treść pieśni z docs/DESIGN-SYSTEM.md, sekcja 3: znaczniki zamienione na typografię.
///
/// - inicjał `2,16 × S` otwiera pierwszą zwrotkę i zastępuje jej numer,
/// - kolejne zwrotki: cyfra `0,74 × S` z linią,
/// - refren: wersalik „Refren” z linią i wcięcie `0,74 × S`, bez kursywy,
/// - powtórzenie: znaki `[:` i `:]` w akcencie, przyklejone do sąsiednich słów,
/// - granica bloku to odstęp `1,26 × S`, nigdy pusty wiersz.
///
/// Rozmiar bierze się z ustawień użytkownika (`S`), a systemowe powiększenie czcionki
/// nakłada się na to osobno, przez `textScaler` — nigdy zamiast niego (reguła 5, sekcja 7).
class SongContent extends StatelessWidget {
  final String content;

  const SongContent({super.key, required this.content});

  static const SongTextParser _parser = SongTextParser();

  @override
  Widget build(BuildContext context) {
    final fontSizeModel = context.watch<FontSizeModel>();
    final scale = fontSizeModel.songTextScale;
    final blocks = _parser.parse(content);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: scale.maxColumnWidth),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: SongTextScale.sideMargin, vertical: scale.blockGap),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < blocks.length; i++) ...[
                if (i > 0) SizedBox(height: scale.blockGap),
                _Block(block: blocks[i], scale: scale),
              ],
            ],
          ),
        ),
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

/// Pierwsza zwrotka: inicjał zamiast numeru.
class _FirstVerse extends StatelessWidget {
  final VerseBlock block;
  final SongTextScale scale;

  const _FirstVerse({required this.block, required this.scale});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final color = Theme.of(context).colorScheme.onSurface;
    final body = scale.textStyle(color: color);
    final initialStyle = body.copyWith(fontSize: scale.initialSize, height: 1.0);

    final spans = _inlineSpans(block.inlines, body, appColors.accent);
    final first = spans.isEmpty ? null : spans.first;

    // Inicjał to pierwsza litera treści; reszta pierwszego kawałka idzie dalej normalnie.
    if (first is! TextSpan || (first.text ?? '').isEmpty) {
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

/// Kolejna zwrotka: cyfra z linią nad akapitem.
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

/// Refren: wersalik z linią i wcięcie.
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

/// Etykieta bloku z hairline'em ciągnącym się do prawej krawędzi kolumny.
class _MarkerLine extends StatelessWidget {
  final Widget label;

  const _MarkerLine({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        label,
        const SizedBox(width: 8.0),
        Expanded(child: Container(height: 1.0, color: context.appColors.line)),
      ],
    );
  }
}

/// Akapit treści bloku, ze znakami powtórzenia w akcencie.
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

/// Zamienia kawałki bloku na spany: zwykły tekst i znaki powtórzenia w akcencie.
///
/// Znaki nie mają odstępu od sąsiedniego słowa, więc trzymają się frazy także wtedy,
/// gdy akapit zawinie się w jej środku.
List<InlineSpan> _inlineSpans(List<SongInline> inlines, TextStyle style, Color accent) {
  return [
    for (final part in inlines)
      switch (part) {
        SongText(:final text) => TextSpan(text: text),
        RepeatMark() => TextSpan(text: part.text, style: style.copyWith(color: accent)),
      },
  ];
}
