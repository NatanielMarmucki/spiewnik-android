import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_colors.dart';

/// Wiersz listy z docs/DESIGN-SYSTEM.md, sekcja 5. Jeden wariant dla trzech list:
/// pieśni, ulubionych i własnych pieśni.
///
/// Tytuł przy lewej krawędzi, numer przy prawej, a puste miejsce między nimi wypełnia linia
/// wiodąca z kropek — jak w spisie treści. **Tytuł jest widoczny w całości**: długi zawija się
/// do kolejnych wierszy, a kropki biegną od końca ostatniego wiersza do numeru. Serce ulubionej
/// stoi przy końcu tytułu, żeby nie ginęło. Własna pieśń dostaje wersalik `MOJA` zamiast numeru.
///
/// Wysokość to **minimum** 48 dp, więc wiersz rośnie razem z systemowym powiększeniem czcionki
/// i razem z liczbą wierszy tytułu (reguła 1 i 6 z sekcji 7 dokumentu).
class SongListTile extends StatefulWidget {
  /// Tytuł pieśni.
  final String title;

  /// Numer pieśni pokazywany na prawej krawędzi. Null dla własnych pieśni.
  final int? number;

  /// Tekst zamiast numeru, np. `MOJA` dla własnej pieśni.
  final String? badge;

  /// Rysuje serce przy tytule.
  final bool isFavorite;

  /// Pieśń otwarta w tej chwili: numer w kolorze akcentu.
  final bool isSelected;

  /// Fragment tytułu do podświetlenia, np. trafienie wyszukiwania.
  final String? highlight;

  final VoidCallback? onTap;

  const SongListTile({
    super.key,
    required this.title,
    this.number,
    this.badge,
    this.isFavorite = false,
    this.isSelected = false,
    this.highlight,
    this.onTap,
  });

  /// Wysokość minimalna wiersza.
  static const double minHeight = 48.0;

  /// Czas przyciemnienia tła przy dotknięciu (sekcja 6 dokumentu).
  static const Duration pressDuration = Duration(milliseconds: 80);

  @override
  State<SongListTile> createState() => _SongListTileState();
}

class _SongListTileState extends State<SongListTile> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed != pressed) {
      setState(() => _pressed = pressed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = context.appColors;
    final numberStyle = theme.textTheme.titleSmall?.copyWith(
      color: widget.isSelected ? appColors.accent : appColors.textSecondary,
    );

    return Semantics(
      button: widget.onTap != null,
      selected: widget.isSelected,
      // Jeden węzeł na wiersz: numer, tytuł i „ulubiona” czytane razem, zamiast osobnych ikon.
      container: true,
      excludeSemantics: true,
      onTap: widget.onTap,
      label: [
        if (widget.number != null) '${widget.number}',
        widget.title,
        if (widget.badge != null) widget.badge!,
        if (widget.isFavorite) 'ulubiona',
      ].join(', '),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // cały wiersz jest celem dotknięcia
        onTap: widget.onTap,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: AnimatedContainer(
          duration: SongListTile.pressDuration,
          decoration: BoxDecoration(color: _pressed ? appColors.pressedSurface : theme.colorScheme.surface),
          constraints: const BoxConstraints(minHeight: SongListTile.minHeight),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: _IndexLine(
            title: widget.title,
            highlight: widget.highlight,
            isFavorite: widget.isFavorite,
            trailingText: widget.badge ?? (widget.number == null ? null : '${widget.number}'),
            trailingStyle: widget.badge != null ? theme.textTheme.labelMedium : numberStyle,
          ),
        ),
      ),
    );
  }
}

/// Wiersz spisu treści: tytuł, kropki i numer.
///
/// Tytuł mierzymy sami [TextPainter]em i dzielimy na wiersze, bo kropki mają zaczynać się tam,
/// gdzie kończy się **ostatni** wiersz tytułu. Zwykły `Row` tego nie umie: zawinięty tekst zajmuje
/// całą szerokość, więc na kropki nie zostałoby nic.
class _IndexLine extends StatelessWidget {
  final String title;
  final String? highlight;
  final bool isFavorite;
  final String? trailingText;
  final TextStyle? trailingStyle;

  const _IndexLine({
    required this.title,
    required this.highlight,
    required this.isFavorite,
    required this.trailingText,
    required this.trailingStyle,
  });

  /// Odstęp po obu stronach kropek.
  static const double _gap = 12.0;

  /// Najkrótsza linia wiodąca, jaką zostawiamy: poniżej tego kropki przestają czytelnie prowadzić.
  static const double _minDots = 12.0;

  static const double _favoriteIcon = 11.0;
  static const double _favoriteGap = 8.0;

  /// Przy skrajnie wąskim wierszu tytuł i tak dostaje tyle miejsca; niżej nie ma co dzielić.
  static const double _minTitleWidth = 24.0;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final textScaler = MediaQuery.textScalerOf(context);
    final defaultStyle = DefaultTextStyle.of(context).style;
    final titleStyle = defaultStyle.merge(Theme.of(context).textTheme.titleMedium);
    final direction = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final trailingWidth = _measure(
          TextSpan(text: trailingText ?? '', style: defaultStyle.merge(trailingStyle)),
          direction,
          textScaler,
        );
        final favoriteWidth = isFavorite ? textScaler.scale(_favoriteIcon) + _favoriteGap : 0.0;
        // Tyle miejsca zostaje na tekst tytułu po numerze, sercu, odstępach i kropkach.
        final available = math.max(
          _minTitleWidth,
          constraints.maxWidth - trailingWidth - favoriteWidth - 2 * _gap - _minDots,
        );
        final lines = _splitIntoLines(titleStyle, direction, textScaler, available);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final line in lines.take(lines.length - 1)) _text(context, line, titleStyle),
            Row(
              children: [
                // Twarde ograniczenie zamiast Flexible: Flexible dzieliłby wolne miejsce po połowie
                // z Expanded od kropek i ucinał tytuł wielokropkiem, choć zmierzył się na tę szerokość.
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: available),
                  child: _text(context, lines.last, titleStyle),
                ),
                if (isFavorite) ...[
                  const SizedBox(width: _favoriteGap),
                  Icon(Icons.favorite, size: _favoriteIcon, color: appColors.favorite),
                ],
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _gap),
                    child: CustomPaint(
                      painter: _LeaderDotsPainter(color: appColors.indexDots),
                      size: const Size(double.infinity, 2.0),
                    ),
                  ),
                ),
                if (trailingText != null) Text(trailingText!, style: trailingStyle),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _text(BuildContext context, TextRange range, TextStyle style) {
    return Text.rich(
      TextSpan(children: _spans(context, range, style)),
      style: style,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );
  }

  double _measure(TextSpan span, TextDirection direction, TextScaler scaler) {
    final painter = TextPainter(text: span, textDirection: direction, textScaler: scaler)..layout();
    return painter.width;
  }

  /// Zakresy kolejnych wierszy tytułu przy danej szerokości. Zawsze co najmniej jeden.
  List<TextRange> _splitIntoLines(
    TextStyle style,
    TextDirection direction,
    TextScaler scaler,
    double maxWidth,
  ) {
    if (maxWidth <= 0 || title.isEmpty) {
      return [TextRange(start: 0, end: title.length)];
    }
    final painter = TextPainter(
      text: TextSpan(text: title, style: style),
      textDirection: direction,
      textScaler: scaler,
    )..layout(maxWidth: maxWidth);

    final ranges = <TextRange>[];
    var offset = 0;
    while (offset < title.length) {
      final line = painter.getLineBoundary(TextPosition(offset: offset));
      // Zabezpieczenie przed pętlą, gdyby granica nie posunęła się do przodu.
      final end = line.end > offset ? line.end : title.length;
      ranges.add(TextRange(start: offset, end: end));
      offset = end;
    }
    return ranges.isEmpty ? [TextRange(start: 0, end: title.length)] : ranges;
  }

  /// Fragment tytułu z podświetlonym trafieniem wyszukiwania, jeśli wpada w ten wiersz.
  List<TextSpan> _spans(BuildContext context, TextRange line, TextStyle style) {
    final text = title.substring(line.start, line.end).trimRight();
    final query = highlight;
    if (query == null || query.isEmpty) {
      return [TextSpan(text: text)];
    }
    final start = title.toLowerCase().indexOf(query.toLowerCase());
    if (start < 0) {
      return [TextSpan(text: text)];
    }
    final end = start + query.length;
    // Trafienie liczone w całym tytule, więc przycinamy je do tego wiersza.
    final from = (start - line.start).clamp(0, text.length);
    final to = (end - line.start).clamp(0, text.length);
    if (from >= to) {
      return [TextSpan(text: text)];
    }
    final highlighted = style.copyWith(color: context.appColors.accent);
    return [
      if (from > 0) TextSpan(text: text.substring(0, from)),
      TextSpan(text: text.substring(from, to), style: highlighted),
      if (to < text.length) TextSpan(text: text.substring(to)),
    ];
  }
}

/// Linia wiodąca z kropek między tytułem a numerem.
class _LeaderDotsPainter extends CustomPainter {
  final Color color;

  const _LeaderDotsPainter({required this.color});

  static const double _radius = 1.0;
  static const double _spacing = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final centerY = size.height / 2;
    for (var x = size.width - _radius; x >= 0; x -= _spacing) {
      canvas.drawCircle(Offset(x, centerY), _radius, paint);
    }
  }

  @override
  bool shouldRepaint(_LeaderDotsPainter oldDelegate) => oldDelegate.color != color;
}
