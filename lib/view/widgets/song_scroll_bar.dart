import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/theme/app_text_theme.dart';

/// Szybkie przewijanie listy pieśni: przeciągany uchwyt przy prawej krawędzi, a przy przeciąganiu
/// etykieta z numerem pieśni, na której właśnie jesteś.
///
/// Wraca po tym, jak wypadło razem z paczką `draggable_scrollbar` — przy 2000 pozycjach sama
/// wyszukiwarka nie zastępuje przewijania. Dokumentu systemu wizualnego ten komponent nie opisywał,
/// więc wymiary i kolory pochodzą z istniejących tokenów (sekcja 5 dokumentu).
///
/// **Przeciąganie** przelicza pozycję uchwytu na ułamek `maxScrollExtent` — tak jak każdy pasek
/// przewijania i, co ważniejsze, odporne na wiersze o różnej wysokości. **Etykieta** nie zgaduje
/// niczego z offsetu: pyta listę, który wiersz naprawdę jest pierwszy widoczny
/// (patrz [firstVisibleItemIndex]), więc działa tak samo przy powiększeniu ×1,0 i ×2,0.
class SongScrollBar extends StatefulWidget {
  final ScrollController controller;

  /// Etykieta dla wiersza o danym indeksie — numer pieśni **z modelu**, nie „indeks + 1".
  /// Null chowa etykietę, na przykład gdy indeks wypadł poza listę.
  final String? Function(int index) labelForIndex;

  /// Uchwyt pokazuje się tylko wtedy, gdy przewijanie ma sens: na pełnej liście, nie na wynikach
  /// wyszukiwania.
  final bool enabled;

  final Widget child;

  const SongScrollBar({
    super.key,
    required this.controller,
    required this.labelForIndex,
    required this.child,
    this.enabled = true,
  });

  /// Szerokość widocznego uchwytu.
  static const double thumbWidth = 6.0;

  /// Wysokość uchwytu; jednocześnie minimalny cel dotknięcia w pionie.
  static const double thumbHeight = 48.0;

  /// Szerokość obszaru reagującego na dotknięcie. Sam uchwyt jest wąski, żeby nie zasłaniał
  /// wiersza, ale palec ma trafiać w 48 dp (sekcja 6 dokumentu).
  static const double hitWidth = 48.0;

  /// Poniżej tylu ekranów treści uchwyt nie ma sensu i się nie pokazuje.
  static const double minScreensToShow = 2.0;

  @override
  State<SongScrollBar> createState() => _SongScrollBarState();
}

class _SongScrollBarState extends State<SongScrollBar> {
  bool _dragging = false;
  String? _label;

  @override
  void initState() {
    super.initState();
    // Kontroler podpina się dopiero przy układzie listy, czyli po pierwszym zbudowaniu paska,
    // a samo podpięcie nie powiadamia słuchaczy. Bez tego uchwyt pojawiałby się dopiero po
    // pierwszym przewinięciu.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(SongScrollBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _dragging) {
      _dragging = false;
      _label = null;
    }
  }

  /// Ułamek przewinięcia, 0 na górze i 1 na dole.
  double get _fraction {
    final position = widget.controller.position;
    if (!position.hasContentDimensions || position.maxScrollExtent <= 0) {
      return 0.0;
    }
    return (position.pixels / position.maxScrollExtent).clamp(0.0, 1.0);
  }

  void _scrollToThumbCenter(double localY, double trackHeight) {
    final travel = trackHeight - SongScrollBar.thumbHeight;
    if (travel <= 0 || !widget.controller.hasClients || !widget.controller.position.hasContentDimensions) {
      return;
    }
    final fraction = ((localY - SongScrollBar.thumbHeight / 2) / travel).clamp(0.0, 1.0);
    widget.controller.jumpTo(fraction * widget.controller.position.maxScrollExtent);
    _updateLabel();
  }

  /// Etykietę czytamy po przeliczeniu układu, bo dopiero wtedy lista wie, co naprawdę widać.
  void _updateLabel() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final index = firstVisibleItemIndex(widget.controller);
      final label = index == null ? null : widget.labelForIndex(index);
      if (label != _label) {
        setState(() => _label = label);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      // Zmiana wymiarów listy (obrót, inna czcionka) zmienia długość toru uchwytu.
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
          }
        });
        return false;
      },
      child: Stack(
        children: [
          widget.child,
          if (widget.enabled)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: widget.controller,
                builder: (context, _) => _buildBar(context),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBar(BuildContext context) {
    if (!widget.controller.hasClients) {
      return const SizedBox.shrink();
    }
    final position = widget.controller.position;
    // Pierwsza klatka: lista nie zna jeszcze swoich wymiarów, a maxScrollExtent by je wymusił.
    if (!position.hasContentDimensions || !position.hasViewportDimension) {
      return const SizedBox.shrink();
    }
    // Krótka lista: nie ma czego przewijać na skróty.
    if (position.maxScrollExtent < position.viewportDimension * (SongScrollBar.minScreensToShow - 1)) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackHeight = constraints.maxHeight;
        final travel = trackHeight - SongScrollBar.thumbHeight;
        final thumbTop = travel <= 0 ? 0.0 : _fraction * travel;

        return Stack(
          children: [
            Positioned(
              top: thumbTop,
              right: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: (details) {
                  setState(() => _dragging = true);
                  _updateLabel();
                },
                onVerticalDragUpdate: (details) {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) {
                    return;
                  }
                  _scrollToThumbCenter(box.globalToLocal(details.globalPosition).dy, trackHeight);
                },
                onVerticalDragEnd: (_) => setState(() {
                  _dragging = false;
                  _label = null;
                }),
                onVerticalDragCancel: () => setState(() {
                  _dragging = false;
                  _label = null;
                }),
                child: _Thumb(dragging: _dragging),
              ),
            ),
            if (_dragging && _label != null)
              Positioned(
                top: thumbTop,
                right: SongScrollBar.hitWidth,
                child: _Label(text: _label!),
              ),
          ],
        );
      },
    );
  }
}

class _Thumb extends StatelessWidget {
  final bool dragging;

  const _Thumb({required this.dragging});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    return Semantics(
      label: 'Szybkie przewijanie listy',
      container: true,
      excludeSemantics: true,
      child: SizedBox(
        // Wąski rysunek w szerokim celu dotknięcia: uchwyt nie wchodzi na treść wiersza.
        width: SongScrollBar.hitWidth,
        height: SongScrollBar.thumbHeight,
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: SongScrollBar.thumbWidth,
            height: SongScrollBar.thumbHeight,
            decoration: BoxDecoration(
              color: dragging ? appColors.accent : appColors.indexDots,
              borderRadius: BorderRadius.circular(SongScrollBar.thumbWidth), // pastylka
            ),
          ),
        ),
      ),
    );
  }
}

/// Numer pieśni przy uchwycie: ten sam krój i cyfry tabelaryczne co numer w wierszu listy.
class _Label extends StatelessWidget {
  final String text;

  const _Label({required this.text});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: SongScrollBar.thumbHeight,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(999.0), // pastylka
            border: Border.all(color: appColors.line),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: AppFonts.serif,
              fontSize: 17.0,
              height: 1.0,
              color: colors.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

/// Indeks pierwszego widocznego wiersza listy sterowanej przez [controller], albo `null`,
/// gdy nie da się go odczytać.
///
/// **Dlaczego warstwa renderowania.** Wiersze mają różną wysokość — rosną z systemową czcionką,
/// a długi tytuł zawija się do dwóch linii — więc z samego `position.pixels` nie da się policzyć
/// numeru wiersza. Poprzednie rozwiązanie dzieliło offset przez stałe 70 i dlatego przestało
/// działać, gdy `itemExtent` zniknął. Zamiast zgadywać, pytamy listę, co naprawdę widać:
/// `RenderSliverMultiBoxAdaptor.indexOf` to publiczna metoda (bez `@protected`, w odróżnieniu od
/// sąsiednich metod w tym samym pliku silnika).
///
/// **Gdyby API się zmieniło.** Każdy krok jest osłonięty i porażka oznacza `null`, czyli brak
/// etykiety — lista przewija się dalej. Alternatywy, w kolejności rozsądku: paczka
/// `super_sliver_list` (podaje widoczne indeksy, ale to nowa zależność) albo przybliżenie
/// `ułamek × liczba wierszy`, które przy zawijanych tytułach się rozjeżdża.
int? firstVisibleItemIndex(ScrollController controller) {
  if (!controller.hasClients) {
    return null;
  }
  try {
    final renderObject = controller.position.context.storageContext.findRenderObject();
    if (renderObject == null) {
      return null;
    }
    final sliver = _findSliverAdaptor(renderObject);
    if (sliver == null || !sliver.geometry!.visible && sliver.firstChild == null) {
      return null;
    }
    final scrollOffset = sliver.constraints.scrollOffset;
    // firstChild bywa wierszem z zapasu nad ekranem, więc szukamy pierwszego, który sięga widoku.
    for (RenderBox? child = sliver.firstChild; child != null; child = sliver.childAfter(child)) {
      final childOffset = sliver.childScrollOffset(child);
      if (childOffset == null) {
        continue;
      }
      if (childOffset + child.size.height > scrollOffset) {
        return sliver.indexOf(child);
      }
    }
    return null;
  } catch (_) {
    // Świadomie połykamy: brak etykiety jest do przeżycia, wywrócony ekran listy nie.
    return null;
  }
}

RenderSliverMultiBoxAdaptor? _findSliverAdaptor(RenderObject root) {
  if (root is RenderSliverMultiBoxAdaptor) {
    return root;
  }
  RenderSliverMultiBoxAdaptor? found;
  root.visitChildren((child) {
    found ??= _findSliverAdaptor(child);
  });
  return found;
}
