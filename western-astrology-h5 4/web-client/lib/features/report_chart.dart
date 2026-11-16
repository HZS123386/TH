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
    : c.t('reading', 'planets.${p['id']}').isNotEmpty
    ? c.t('reading', 'planets.${p['id']}')
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
  final localized = c.list('reading', 'signs');
  return index != null && index >= 0 && index < 12
      ? (c.language == 'zh' ? names[index] : localized[index])
      : text(p['sign_name']);
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
