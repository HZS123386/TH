import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/models/calculation.dart';
import '../../ui/theme.dart';

class ChartWheel extends StatelessWidget {
  const ChartWheel({
    required this.result,
    required this.selected,
    required this.onSelected,
    super.key,
  });
  final CalculationSnapshot result;
  final String selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: LayoutBuilder(
      builder: (context, box) => GestureDetector(
        onTapUp: (event) {
          final center = Offset(box.maxWidth / 2, box.maxWidth / 2),
              radius = box.maxWidth * .32;
          for (var i = 0; i < result.planets.length; i++) {
            final p = result.planets[i], a = (p.longitude - 90) * pi / 180;
            final point =
                center +
                Offset(cos(a), sin(a)) *
                    (radius + (i % 2) * box.maxWidth * .035);
            if ((point - event.localPosition).distance < 22) {
              onSelected(p.key);
              return;
            }
          }
        },
        child: CustomPaint(painter: _WheelPainter(result, selected)),
      ),
    ),
  );
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.result, this.selected);
  final CalculationSnapshot result;
  final String selected;
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2), r = size.width * .47;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7
      ..color = goldColor.withValues(alpha: .5);
    for (final scale in [1.0, .97, .81, .66, .49]) {
      canvas.drawCircle(c, r * scale, paint);
    }
    Offset point(double angle, double radius) =>
        c +
        Offset(cos((angle - 90) * pi / 180), sin((angle - 90) * pi / 180)) *
            radius;
    for (var i = 0; i < 72; i++) {
      canvas.drawLine(
        point(i * 5, r * (i % 6 == 0 ? 0.66 : 0.94)),
        point(i * 5, r * .97),
        paint,
      );
    }
    void text(String value, Offset at, Color color, double fontSize) {
      final tp = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(fontSize: fontSize, color: color),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }

    const signs = ['♈', '♉', '♊', '♋', '♌', '♍', '♎', '♏', '♐', '♑', '♒', '♓'];
    for (var i = 0; i < 12; i++) {
      text(signs[i], point(i * 30 + 15, r * .89), goldColor, 17);
    }
    for (final aspect in result.aspects) {
      final from = result.planets.where((p) => p.key == aspect.from),
          to = result.planets.where((p) => p.key == aspect.to);
      if (from.isEmpty || to.isEmpty) continue;
      paint.color =
          ([90.0, 180.0].contains(aspect.angle)
                  ? const Color(0xFFC78B9C)
                  : const Color(0xFF8FAFE3))
              .withValues(alpha: .5);
      canvas.drawLine(
        point(from.first.longitude, r * .59),
        point(to.first.longitude, r * .59),
        paint,
      );
    }
    for (var i = 0; i < result.planets.length; i++) {
      final p = result.planets[i],
          at = point(
            p.longitude,
            size.width * .32 + (i % 2) * size.width * .035,
          ),
          active = p.key == selected;
      canvas.drawCircle(
        at,
        13,
        Paint()..color = active ? goldColor : panelColor,
      );
      canvas.drawCircle(
        at,
        13,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = goldColor.withValues(alpha: .65)
          ..strokeWidth = .7,
      );
      text(p.symbol, at, active ? panelColor : goldColor, 17);
    }
    text('✧', c - const Offset(0, 7), goldColor, 28);
    text('FATE', c + const Offset(0, 16), mutedColor, 9);
  }

  @override
  bool shouldRepaint(_WheelPainter old) =>
      old.result != result || old.selected != selected;
}
