import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_text_theme.dart';

/// A magnifying glass with a character **in the lens**: "search by number", not the current song's number.
///
/// The lens holds a fixed [label] — the open song's number is already in the top bar, and a varying
/// number of digits would make the lens change width on every move between songs.
class GoToNumberIcon extends StatelessWidget {
  final Color color;

  /// The character in the lens. Fixed and **a single character**: three digits blew the lens up to
  /// a size at which the magnifying glass overwhelmed the bar.
  final String label;

  const GoToNumberIcon({super.key, required this.color, this.label = '1'});

  /// The smallest lens; with a single character it is what sets the icon size.
  static const double minLensDiameter = 15.0;

  /// Gap between the character and the lens outline.
  static const double _padding = 2.0;

  /// Length of the magnifier handle, measured from the lens edge. A shorter one got lost next to the
  /// lens and the magnifier read as a plain circle.
  static const double _handle = 7.0;

  static const double _stroke = 1.4;
  static const double _fontSize = 9.0;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final style = TextStyle(
      // Typeface from the tokens: without it the digits fall back to the system default, which the
      // golden container does not have at all, so they render as rectangles.
      fontFamily: AppFonts.ui,
      fontSize: textScaler.scale(_fontSize),
      height: 1.0,
      fontWeight: FontWeight.w600,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
    )..layout();

    final diameter = math.max(
      textScaler.scale(minLensDiameter),
      math.max(painter.width, painter.height) + 2 * _padding,
    );
    final side = diameter + _handle + _stroke;

    return CustomPaint(
      size: Size(side, side),
      painter: _GoToNumberPainter(painter: painter, diameter: diameter, color: color),
    );
  }
}

class _GoToNumberPainter extends CustomPainter {
  final TextPainter painter;
  final double diameter;
  final Color color;

  const _GoToNumberPainter({required this.painter, required this.diameter, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = diameter / 2;
    final center = Offset(radius + GoToNumberIcon._stroke / 2, radius + GoToNumberIcon._stroke / 2);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = GoToNumberIcon._stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, stroke);

    // The handle leaves the lens at 45°, to the right and down, as in a magnifier icon.
    final diagonal = math.sqrt1_2;
    final from = center + Offset(radius * diagonal, radius * diagonal);
    final to = from + Offset(GoToNumberIcon._handle * diagonal, GoToNumberIcon._handle * diagonal);
    canvas.drawLine(from, to, stroke);

    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(_GoToNumberPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.diameter != diameter ||
        oldDelegate.painter.text != painter.text;
  }
}
