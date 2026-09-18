import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:spiewnik/theme/app_text_theme.dart';

/// Lupa z cyframi **w soczewce**: znak „szukaj po numerze", nie numer bieżącej pieśni.
///
/// W soczewce stoi stała próbka [label] — numer otwartej pieśni jest już w pasku górnym, a przy
/// czterech cyfrach soczewka musiałaby zmieniać szerokość przy każdym przejściu między pieśniami.
class GoToNumberIcon extends StatelessWidget {
  final Color color;

  /// Cyfry w soczewce. Stałe, żeby ikona nie skakała.
  final String label;

  const GoToNumberIcon({super.key, required this.color, this.label = '123'});

  /// Najmniejsza soczewka: przy jednej cyfrze lupa nie ma być mikroskopijna.
  static const double minLensDiameter = 20.0;

  /// Odstęp między cyfrą a obwódką soczewki.
  static const double _padding = 3.0;

  /// Długość uchwytu lupy, liczona od krawędzi soczewki.
  static const double _handle = 5.0;

  static const double _stroke = 1.5;
  static const double _fontSize = 10.0;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final style = TextStyle(
      // Krój z tokenów: bez niego cyfry lecą na domyślny systemowy, którego w kontenerze
      // golden w ogóle nie ma i rysują się jako prostokąty.
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

    // Uchwyt wychodzi z soczewki pod 45°, w prawo i w dół, jak w ikonie lupy.
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
