import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/models.dart';
import '../ui/theme.dart';

String planetName(Json p, Copy c) => c.language == 'zh'
    ? const {
            'sun': '太阳',
            'moon': '月亮',
            'mercury': '水星',
            'venus': '金星',
            'mars': '火星',
            'jupiter': '木星',
            'saturn': '土星',
            'uranus': '天王星',
            'neptune': '海王星',
            'pluto': '冥王星',
            'ascendant': '上升点',
            'rahu': '罗睺',
            'ketu': '计都',
          }[p['id']] ??
          text(p['label'])
    : text(p['label']);
String planetSign(Json p, Copy c) {
  const names = [
    '白羊座',
    '金牛座',
    '双子座',
    '巨蟹座',
    '狮子座',
    '处女座',
    '天秤座',
    '天蝎座',
    '射手座',
    '摩羯座',
    '水瓶座',
    '双鱼座',
  ];
  final index = (p['sign_index'] as num?)?.toInt();
  return c.language == 'zh' && index != null && index >= 0 && index < 12
      ? names[index]
      : text(p['sign_name']);
}

class ChartView extends StatefulWidget {
  const ChartView({required this.report, required this.copy, super.key});
  final LifeReport report;
  final Copy copy;
  @override
  State<ChartView> createState() => _ChartViewState();
}

class _ChartViewState extends State<ChartView> {
  String _selected = 'sun';
  @override
  Widget build(BuildContext context) {
    final c = widget.copy,
        chart = object(widget.report.json['chart']),
        planets = objects(chart['planets']);
    final exact = chart['precision'] == 'exact';
    final current =
        planets.where((p) => p['id'] == _selected).firstOrNull ??
        planets.firstOrNull;
    if (planets.isEmpty) {
      return Text(
        c.t('jy', 'report.readingUnavailable'),
        style: const TextStyle(color: lavender, fontSize: 12),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (exact)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(
                builder: (context, box) {
                  final painter = _ChartPainter(chart, _selected);
                  return Semantics(
                    label: c.t('jy', 'chart.wheel'),
                    image: true,
                    child: GestureDetector(
                      onTapUp: (event) {
                        final point =
                            event.localPosition / (box.maxWidth / 320);
                        for (final p in planets) {
                          final marker = painter.planetPoint(
                            p,
                            planets.indexOf(p),
                          );
                          if ((point - marker).distance < 12) {
                            setState(() => _selected = text(p['id']));
                            break;
                          }
                        }
                      },
                      child: CustomPaint(painter: painter),
                    ),
                  );
                },
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              c.t('jy', 'chart.noTime'),
              style: const TextStyle(color: gold, fontSize: 12, height: 1.65),
            ),
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in planets)
              Semantics(
                button: true,
                selected: p == current,
                child: InkWell(
                  onTap: () => setState(() => _selected = text(p['id'])),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: p == current
                          ? const Color(0xFFF3CF9A)
                          : const Color(0xFF2D2041),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: p == current ? const Color(0xFFF3CF9A) : line,
                      ),
                    ),
                    child: Text(
                      planetName(p, c),
                      style: TextStyle(
                        fontSize: 12,
                        color: p == current
                            ? const Color(0xFF221630)
                            : const Color(0xFFF8EDFF),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (current != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Text(
              '${planetName(current, c)}${c.t('jy', 'chart.inSign')}${planetSign(current, c)}'
              '${current['degree'] is num ? ' · ${(current['degree'] as num).toStringAsFixed(2)}°' : ''}'
              '${current['house'] is num ? ' · ${c.language == 'zh' ? '第 ${current['house']} 宫' : 'เรือน ${current['house']}'}' : ''}',
              style: const TextStyle(color: Color(0xFFF8DCAE), fontSize: 13),
            ),
          ),
      ],
    );
  }
}

class PlacementMetrics extends StatelessWidget {
  const PlacementMetrics({required this.report, required this.copy, super.key});
  final LifeReport report;
  final Copy copy;
  @override
  Widget build(BuildContext context) {
    final chart = object(report.json['chart']), all = objects(chart['planets']);
    final preferred = all
        .where((p) => ['sun', 'moon', 'ascendant'].contains(p['id']))
        .take(3)
        .toList();
    final planets = preferred.isEmpty ? all.take(3).toList() : preferred;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${copy.t('jy', 'interpretation.planets')} ${all.length} · ${copy.t('jy', 'interpretation.houses')} ${objects(chart['houses']).length}',
          style: const TextStyle(color: gold, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final p in planets)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xA8150D25),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        planetName(p, copy),
                        style: const TextStyle(
                          color: Color(0xFFC8BAD9),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        planetSign(p, copy),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (report.estimated)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              copy.t('jy', 'unknownNote'),
              style: const TextStyle(fontSize: 11, color: lavender),
            ),
          ),
      ],
    );
  }
}

class ReportFactors extends StatelessWidget {
  const ReportFactors({required this.report, required this.copy, super.key});
  final LifeReport? report;
  final Copy copy;
  @override
  Widget build(BuildContext context) {
    final strengths = <Json>[], warnings = <Json>[];
    if (report != null) {
      for (final chapter in report!.chapters) {
        strengths.addAll(objects(chapter['insights']));
        warnings.addAll(objects(chapter['watchpoints']));
      }
      if (strengths.isEmpty) {
        strengths.addAll(objects(report!.preview['traits']));
      }
    }
    Widget factor(String name, List<Json> entries, bool warning) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xA8170E28),
        border: Border.all(color: const Color(0x35DCB88C)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.t('jy', 'chart.factors.$name'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: warning
                  ? const Color(0xFFFFC0BD)
                  : const Color(0xFFF5D69C),
            ),
          ),
          const SizedBox(height: 4),
          if (entries.isEmpty)
            const Text('—', style: TextStyle(fontSize: 12, color: cream)),
          for (final p in entries.take(2))
            Text(
              text(p['title']),
              style: const TextStyle(fontSize: 12, color: cream),
            ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        factor('favorable', strengths, false),
        const SizedBox(height: 9),
        factor('unfavorable', warnings, true),
        const SizedBox(height: 9),
        Text(
          copy.t('jy', 'chart.factors.basis'),
          style: const TextStyle(fontSize: 11, color: lavender),
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.chart, this.selected);
  final Json chart;
  final String selected;
  double get origin =>
      (objects(
                chart['planets'],
              ).where((p) => p['id'] == 'ascendant').firstOrNull?['longitude']
              as num?)
          ?.toDouble() ??
      0;
  Offset point(num degree, double radius) {
    final a = math.pi - ((degree - origin) * math.pi / 180);
    return Offset(160 + math.cos(a) * radius, 160 - math.sin(a) * radius);
  }

  Offset planetPoint(Json p, int index) =>
      point(p['longitude'] as num, 95 + (index % 3) * 6.0);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 320);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFA486B6);
    for (final radius in [148.0, 119.0, 91.0]) {
      canvas.drawCircle(const Offset(160, 160), radius, paint);
    }
    void label(String value, Offset at, double fontSize, {double spacing = 0}) {
      final text = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            color: const Color(0xFFEDC99A),
            fontFamily: h5FontFamily,
            fontFamilyFallback: h5FontFallback,
            fontSize: fontSize,
            letterSpacing: spacing,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, at - Offset(text.width / 2, text.height / 2));
    }

    const signs = ['♈', '♉', '♊', '♋', '♌', '♍', '♎', '♏', '♐', '♑', '♒', '♓'];
    for (var i = 0; i < 12; i++) {
      paint.color = const Color(0xFF80638E);
      canvas.drawLine(point(i * 30, 119), point(i * 30, 148), paint);
      label(signs[i], point(i * 30 + 15, 134), 16);
    }
    for (final house in objects(chart['houses'])) {
      canvas.drawLine(
        point(house['longitude'] as num, 91),
        point(house['longitude'] as num, 118),
        paint,
      );
    }
    final planets = objects(chart['planets']);
    for (final entry in planets.indexed) {
      final at = planetPoint(entry.$2, entry.$1),
          active = entry.$2['id'] == selected;
      paint
        ..style = PaintingStyle.fill
        ..color = active ? Colors.white : const Color(0xFFF2CC97);
      canvas.drawCircle(at, active ? 6 : 3.7, paint);
      paint
        ..style = PaintingStyle.stroke
        ..color = active ? const Color(0xFFF2CC97) : const Color(0xFF201536)
        ..strokeWidth = active ? 2 : 1;
      canvas.drawCircle(at, active ? 6 : 3.7, paint);
    }
    label('FATE', const Offset(160, 164), 13, spacing: 2.8);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ChartPainter oldDelegate) =>
      oldDelegate.chart != chart || oldDelegate.selected != selected;
}
