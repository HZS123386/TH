import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/models/calculation.dart';
import '../../ui/theme.dart';

Offset _planetCenter(Size size, CalculationSnapshot result, int index) {
  final angle =
      (180 + (result.ascendant ?? 0) - result.planets[index].longitude) *
      pi /
      180;
  return Offset(size.width / 2, size.height / 2) +
      Offset(cos(angle), sin(angle)) *
          (size.width * (.32 + (index % 2) * .035));
}

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
        behavior: HitTestBehavior.opaque,
        // The wheel needs the real tap position, not a single semantic button's center.
        excludeFromSemantics: true,
        onTapUp: (event) {
          final size = Size.square(box.maxWidth);
          String? nearest;
          var nearestDistance = 22.0;
          for (var i = 0; i < result.planets.length; i++) {
            final distance =
                (_planetCenter(size, result, i) - event.localPosition).distance;
            // Nearby hit areas can overlap; ties follow the painter's stacking order.
            if (distance <= nearestDistance) {
              nearestDistance = distance;
              nearest = result.planets[i].key;
            }
          }
          if (nearest != null) onSelected(nearest);
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
    const innerRingScale = .49;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7
      ..color = goldColor.withValues(alpha: .5);
    for (final scale in [1.0, .97, .81, .66, innerRingScale]) {
      canvas.drawCircle(c, r * scale, paint);
    }
    Offset point(double angle, double radius) =>
        c +
        Offset(
              cos((180 + (result.ascendant ?? 0) - angle) * pi / 180),
              sin((180 + (result.ascendant ?? 0) - angle) * pi / 180),
            ) *
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
          style: TextStyle(
            fontFamily: 'NotoSansSymbols',
            fontFamilyFallback: const ['NotoSansThai'],
            fontSize: fontSize,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }

    const signs = ['♈', '♉', '♊', '♋', '♌', '♍', '♎', '♏', '♐', '♑', '♒', '♓'];
    for (var i = 0; i < 12; i++) {
      text(signs[i], point(i * 30 + 15, r * .89), goldColor, 17);
    }
    // House cusps use the provider's longitudes, never twelve equal wedges.
    for (final house in result.houses.entries) {
      paint.color = goldColor.withValues(alpha: .38);
      canvas.drawLine(
        point(house.value, r * innerRingScale),
        point(house.value, r * .81),
        paint,
      );
      final nextCusp = result.houses[house.key % 12 + 1];
      if (nextCusp != null) {
        // Follow the zodiac through 0° to center labels in unequal houses.
        final middle = house.value + (nextCusp - house.value) % 360 / 2;
        text(
          '${house.key}',
          point(middle, r * (innerRingScale + .66) / 2),
          mutedColor,
          9,
        );
      }
    }
    for (final angle in [('ASC', result.ascendant), ('MC', result.midheaven)]) {
      if (angle.$2 == null) continue;
      paint.color = goldColor;
      canvas.drawLine(
        point(angle.$2!, r * .66),
        point(angle.$2!, r * .97),
        paint,
      );
      text(angle.$1, point(angle.$2!, r * .73), goldColor, 9);
    }
    // Leave a visible gap between aspect chords and the innermost ring.
    final aspectGap = max(4.0, r * .025);
    final aspectRadius = r * innerRingScale - aspectGap - paint.strokeWidth;
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
        point(from.first.longitude, aspectRadius),
        point(to.first.longitude, aspectRadius),
        paint,
      );
    }
    for (var i = 0; i < result.planets.length; i++) {
      final p = result.planets[i],
          at = _planetCenter(size, result, i),
          active = p.key == selected;
      canvas.drawCircle(
        at,
        10,
        Paint()..color = active ? goldColor : panelColor,
      );
      canvas.drawCircle(
        at,
        10,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = goldColor.withValues(alpha: .65)
          ..strokeWidth = .7,
      );
      text(p.symbol, at, active ? panelColor : goldColor, 13);
    }
    text('✧', c - const Offset(0, 7), goldColor, 28);
    text('FATE', c + const Offset(0, 16), mutedColor, 9);
  }

  @override
  bool shouldRepaint(_WheelPainter old) =>
      old.result != result || old.selected != selected;
}
