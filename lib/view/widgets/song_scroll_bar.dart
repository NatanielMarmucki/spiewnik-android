import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:spiewnik/theme/app_colors.dart';
import 'package:spiewnik/theme/app_text_theme.dart';

/// Fast scrolling for the song list: a draggable thumb at the right edge and, while dragging,
/// a label with the number of the song you are currently at.
///
/// It is back after it was dropped together with the `draggable_scrollbar` package — with 2000
/// items, search alone does not replace scrolling. The visual system document did not describe this
/// component, so the sizes and colors come from existing tokens (section 5 of the document).
///
/// **Dragging** converts the thumb position into a fraction of `maxScrollExtent` — like any
/// scrollbar and, more importantly, robust to rows of different heights. **The label** does not
/// guess anything from the offset: it asks the list which row really is the first visible one
/// (see [firstVisibleItemIndex]), so it works the same at ×1.0 and ×2.0 scaling.
class SongScrollBar extends StatefulWidget {
  final ScrollController controller;

  /// Label for the row at the given index — the song number **from the model**, not "index + 1".
  /// Null hides the label, for example when the index falls outside the list.
  final String? Function(int index) labelForIndex;

  /// The thumb shows only when fast scrolling makes sense: on the full list, not on search
  /// results.
  final bool enabled;

  final Widget child;

  const SongScrollBar({
    super.key,
    required this.controller,
    required this.labelForIndex,
    required this.child,
    this.enabled = true,
  });

  /// Width of the visible thumb.
  static const double thumbWidth = 6.0;

  /// Thumb height; also the minimum vertical touch target.
  static const double thumbHeight = 48.0;

  /// Width of the touch-sensitive area. The thumb itself is narrow so it does not cover
  /// the row, but the finger has to hit 48 dp (section 6 of the document).
  static const double hitWidth = 48.0;

  /// Below this many screens of content the thumb makes no sense and is not shown.
  static const double minScreensToShow = 2.0;

  @override
  State<SongScrollBar> createState() => _SongScrollBarState();
}

class _SongScrollBarState extends State<SongScrollBar> {
  bool _dragging = false;
  String? _label;
  bool _labelReadScheduled = false;

  @override
  void initState() {
    super.initState();
    // The controller attaches only during the list's layout, i.e. after the bar is first built,
    // and attaching alone does not notify listeners. Without this the thumb would appear only after
    // the first scroll.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
    widget.controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  @override
  void didUpdateWidget(SongScrollBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _dragging) {
      _dragging = false;
      _label = null;
    }
  }

  /// Scroll fraction, 0 at the top and 1 at the bottom.
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

  /// We read the label after layout, because only then does the list know what is really visible.
  ///
  /// One read per frame and none from the `build` method: calling it from there during build could
  /// fall into a "repaint → read → repaint" loop, which ended in an ANR on the emulator.
  void _updateLabel() {
    if (_labelReadScheduled) {
      return;
    }
    _labelReadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _labelReadScheduled = false;
      if (!mounted || !_dragging) {
        return;
      }
      final index = firstVisibleItemIndex(widget.controller);
      final label = index == null ? null : widget.labelForIndex(index);
      if (label != _label) {
        setState(() => _label = label);
      }
    });
  }

  /// Scrolling changes what is visible, so the label asks the list again after every position change.
  void _onScroll() {
    if (_dragging) {
      _updateLabel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      // A change in the list's dimensions (rotation, a different font) changes the thumb track length.
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
    // First frame: the list does not know its dimensions yet, and maxScrollExtent would force them.
    if (!position.hasContentDimensions || !position.hasViewportDimension) {
      return const SizedBox.shrink();
    }
    // Short list: there is nothing to fast-scroll through.
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
        // Narrow drawing in a wide touch target: the thumb does not cover the row content.
        width: SongScrollBar.hitWidth,
        height: SongScrollBar.thumbHeight,
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: SongScrollBar.thumbWidth,
            height: SongScrollBar.thumbHeight,
            decoration: BoxDecoration(
              color: dragging ? appColors.accent : appColors.indexDots,
              borderRadius: BorderRadius.circular(SongScrollBar.thumbWidth), // pill
            ),
          ),
        ),
      ),
    );
  }
}

/// Song number next to the thumb: the same typeface and tabular figures as the number in the list row.
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
            borderRadius: BorderRadius.circular(999.0), // pill
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

/// Index of the first visible row of the list driven by [controller], or `null`
/// when it cannot be read.
///
/// **Why the render layer.** Rows have different heights — they grow with the system font,
/// and a long title wraps onto two lines — so the row number cannot be computed from
/// `position.pixels` alone. The previous solution divided the offset by a fixed 70, which is why it
/// stopped working when `itemExtent` was removed. Instead of guessing, we ask the list what is
/// really visible: `RenderSliverMultiBoxAdaptor.indexOf` is a public method (no `@protected`,
/// unlike the neighboring methods in the same engine file).
///
/// **If the API changes.** Every step is guarded and a failure means `null`, i.e. no
/// label — the list keeps scrolling. Alternatives, from most to least sensible: the
/// `super_sliver_list` package (it reports visible indexes, but it is a new dependency) or the
/// approximation `fraction × row count`, which drifts with wrapped titles.
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
    // firstChild can be a row from the cache area above the screen, so we look for the first one
    // that reaches the viewport. Threshold: a row clipped to a few pixels is invisible to the eye,
    // and the label would then show a number one lower than the one the user reads at the top.
    for (RenderBox? child = sliver.firstChild; child != null; child = sliver.childAfter(child)) {
      final childOffset = sliver.childScrollOffset(child);
      if (childOffset == null) {
        continue;
      }
      if (childOffset + child.size.height > scrollOffset + _visibleThreshold) {
        return sliver.indexOf(child);
      }
    }
    return null;
  } catch (_) {
    // Swallowed on purpose: a missing label is survivable, a crashed list screen is not.
    return null;
  }
}

/// How much of a row has to remain below the top edge for it to count as visible.
const double _visibleThreshold = 8.0;

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
