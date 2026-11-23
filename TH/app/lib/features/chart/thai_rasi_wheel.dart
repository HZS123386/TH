import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';

class ThaiRasiData {
  const ThaiRasiData({required this.thai, required this.arabic});

  final List<String> thai, arabic;

  // Calculated by the Thai preview endpoint for the synthetic Bangkok sample
  // 1995-08-17 09:30. This data is never used for a personal chart.
  static const example = ThaiRasiData(
    thai: ['๒', '', '', '๑๖', '๔*๙', 'ลั๓', '๘', '๕', '', '๐', '๗', ''],
    arabic: ['2', '', '', '16', '4*9', 'ลั3', '8', '5', '', '0', '7', ''],
  );

  static ThaiRasiData? fromChart(Object? chart) {
    final charts = chart is Map ? chart['charts'] : null;
    final rasi = charts is Map ? charts['rasi'] : null;
    final channels = rasi is Map ? rasi['channels'] : null;
    if (channels is! Map) return null;

    List<String>? read(Object? channel) =>
        channel is List &&
            channel.length == 12 &&
            channel.every((value) => value is String)
        ? List<String>.unmodifiable(channel.cast<String>())
        : null;
    final thai = read(channels['thai']);
    final arabic = read(channels['arabic']);
    return thai == null || arabic == null
        ? null
        : ThaiRasiData(thai: thai, arabic: arabic);
  }
}

class ThaiRasiWheel extends StatelessWidget {
  const ThaiRasiWheel({required this.data, required this.label, super.key});

  final ThaiRasiData data;
  final String label;
  static final _markers = RegExp(r'ลั|[0-9๐-๙]\*?');

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final source = s.localeName == 'th' ? data.thai : data.arabic;
    final channels = [
      for (final channel in source)
        _markers
            .allMatches(channel)
            .map((mark) => mark[0] == 'ลั' ? s.thaiRasiAscendant : mark[0]!)
            .join(' '),
    ];
    final signs = s.zodiacNames;
    final placements = [
      for (var index = 0; index < signs.length; index++)
        if (channels[index].isNotEmpty) '${signs[index]} ${channels[index]}',
    ];
    return Column(
      children: [
        Semantics(
          container: true,
          image: true,
          label: [label, ...placements].join(' · '),
          child: AspectRatio(
            aspectRatio: 1,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _ThaiRasiPainter(channels, s.thaiRasiAscendant),
              ),
            ),
          ),
        ),
        Text(
          s.thaiRasiLegend,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ThaiRasiPainter extends CustomPainter {
  const _ThaiRasiPainter(this.channels, this.ascendantMark);

  final List<String> channels;
  final String ascendantMark;
  static const _signs = [
    '♈',
    '♉',
    '♊',
    '♋',
    '♌',
    '♍',
    '♎',
    '♏',
    '♐',
    '♑',
    '♒',
    '♓',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * .48;
    canvas.translate(center.dx, center.dy);

    final ring = Rect.fromCircle(center: Offset.zero, radius: radius);
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF321E42), canvasColor],
        ).createShader(ring),
    );
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = goldColor.withValues(alpha: .72);
    canvas.drawCircle(Offset.zero, radius, border);
    final gridRadius = radius * .82;
    border.color = goldColor.withValues(alpha: .45);
    canvas.drawCircle(Offset.zero, gridRadius, border);

    // The fixed Rasi layout starts at Aries and advances counterclockwise.
    final halfSquare = gridRadius * .215;
    final chord = sqrt(gridRadius * gridRadius - halfSquare * halfSquare);
    final corner = gridRadius / sqrt2;
    for (final offset in [-halfSquare, halfSquare]) {
      canvas.drawLine(Offset(offset, -chord), Offset(offset, chord), border);
      canvas.drawLine(Offset(-chord, offset), Offset(chord, offset), border);
    }
    for (final x in [-1, 1]) {
      for (final y in [-1, 1]) {
        canvas.drawLine(
          Offset(x * halfSquare, y * halfSquare),
          Offset(x * corner, y * corner),
          border,
        );
      }
    }

    for (var index = 0; index < _signs.length; index++) {
      final angle = -pi / 2 - index * pi / 6;
      final direction = Offset(cos(angle), sin(angle));
      _text(
        canvas,
        _signs[index],
        direction * (radius * .91),
        radius * .112,
        goldColor,
        radius * .3,
        font: 'NotoSansSymbols',
      );
      final value = channels[index];
      if (value.isNotEmpty) {
        _text(
          canvas,
          value,
          direction * (gridRadius * .70),
          radius * .116,
          value.contains(ascendantMark) ? const Color(0xFFFFBAA0) : inkColor,
          gridRadius * .58,
        );
      }
    }

    final star = halfSquare * .64;
    final inset = star * .25;
    final emblem = Path()
      ..moveTo(0, -star)
      ..lineTo(inset, -inset)
      ..lineTo(star, 0)
      ..lineTo(inset, inset)
      ..lineTo(0, star)
      ..lineTo(-inset, inset)
      ..lineTo(-star, 0)
      ..lineTo(-inset, -inset)
      ..close();
    canvas.drawPath(emblem, border..color = goldColor);
  }

  void _text(
    Canvas canvas,
    String value,
    Offset at,
    double fontSize,
    Color color,
    double width, {
    String font = 'NotoSansThai',
  }) {
    final text = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: font,
          fontFamilyFallback: const ['NotoSansSC', 'NotoSansSymbols'],
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    text.paint(canvas, at - Offset(text.width / 2, text.height / 2));
    text.dispose();
  }

  @override
  bool shouldRepaint(_ThaiRasiPainter oldDelegate) =>
      !listEquals(channels, oldDelegate.channels) ||
      ascendantMark != oldDelegate.ascendantMark;
}
