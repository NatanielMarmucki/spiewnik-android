import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_colors.dart';

/// Wiersz listy z docs/DESIGN-SYSTEM.md, sekcja 5. Jeden wariant dla trzech list:
/// pieśni, ulubionych i własnych pieśni.
///
/// Tytuł, linia wiodąca z kropek i numer na prawej krawędzi. Serce ulubionej stoi **przy tytule**,
/// nie na końcu wiersza, żeby nie ginęło przy długim tytule. Własna pieśń dostaje wersalik `MOJA`
/// zamiast numeru. Wiersz nie ma tła ani promienia: rozdziela go odstęp i linia wiodąca.
///
/// Wysokość to **minimum** 48 dp, więc wiersz rośnie razem z systemowym powiększeniem czcionki
/// (reguła 1 i 6 z sekcji 7 dokumentu).
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: _Title(title: widget.title, highlight: widget.highlight),
              ),
              if (widget.isFavorite) ...[
                const SizedBox(width: 8.0),
                Icon(Icons.favorite, size: 11.0, color: appColors.favorite),
              ],
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: CustomPaint(
                    painter: _LeaderDotsPainter(color: appColors.indexDots),
                    size: const Size(double.infinity, 2.0),
                  ),
                ),
              ),
              if (widget.badge != null)
                Text(widget.badge!, style: theme.textTheme.labelMedium)
              else if (widget.number != null)
                Text('${widget.number}', style: numberStyle),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tytuł w jednej linii, z opcjonalnym podświetleniem trafienia wyszukiwania.
class _Title extends StatelessWidget {
  final String title;
  final String? highlight;

  const _Title({required this.title, this.highlight});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    final spans = _spans(context, style);
    return Text.rich(
      TextSpan(children: spans),
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  List<TextSpan> _spans(BuildContext context, TextStyle? style) {
    final query = highlight;
    if (query == null || query.isEmpty) {
      return [TextSpan(text: title)];
    }
    final start = title.toLowerCase().indexOf(query.toLowerCase());
    if (start < 0) {
      return [TextSpan(text: title)];
    }
    final end = start + query.length;
    final highlighted = style?.copyWith(color: context.appColors.accent);
    return [
      if (start > 0) TextSpan(text: title.substring(0, start)),
      TextSpan(text: title.substring(start, end), style: highlighted),
      if (end < title.length) TextSpan(text: title.substring(end)),
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
