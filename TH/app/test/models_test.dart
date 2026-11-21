import 'package:flutter_test/flutter_test.dart';
import 'package:fate_app/core/models/birth_profile.dart';
import 'package:fate_app/core/models/calculation.dart';
import 'package:fate_app/core/models/report.dart';

Map<String, dynamic> calculation({String precision = 'exact_time'}) => {
  'result_id': 'c1',
  'system': 'western_natal',
  'engine_version': 'e1',
  'ruleset_version': 'r1',
  'status': 'partial',
  'input_precision': precision,
  'missing_fields': <String>[],
  'facts': [
    {
      'fact_id': 'sun-1',
      'kind': 'planet',
      'value': {'key': 'sun', 'longitude': 142},
    },
  ],
};
void main() {
  test(
    'explicit noon estimates include Moon, angles, houses and aspects without claiming an exact time',
    () {
      final data = {
        ...calculation(precision: 'estimated_time'),
        'rules': {'assumed_local_time': '12:00'},
        'facts': [
          {
            'fact_id': 'sun',
            'kind': 'planet',
            'value': {
              'key': 'sun',
              'longitude': 142,
              'house': 5,
              'estimated': true,
            },
          },
          {
            'fact_id': 'moon',
            'kind': 'planet',
            'value': {
              'key': 'moon',
              'longitude': 232,
              'house': 8,
              'estimated': true,
            },
          },
          {
            'fact_id': 'asc',
            'kind': 'ascendant',
            'value': {'longitude': 0, 'estimated': true},
          },
          {
            'fact_id': 'mc',
            'kind': 'midheaven',
            'value': {'longitude': 270, 'estimated': true},
          },
          for (var n = 1; n <= 12; n++)
            {
              'fact_id': 'h$n',
              'kind': 'house',
              'value': {
                'number': n,
                'longitude': (n - 1) * 30,
                'estimated': true,
              },
            },
          {
            'fact_id': 'aspect',
            'kind': 'aspect',
            'value': {
              'from': 'sun',
              'to': 'moon',
              'angle': 90,
              'orb': 0,
              'estimated': true,
            },
          },
        ],
      };
      final result = CalculationSnapshot.fromJson(data);
      expect(result.exactTime, isFalse);
      expect(result.estimatedTime, isTrue);
      expect(result.assumedLocalTime, '12:00');
      expect(result.planets.last.key, 'moon');
      expect(result.planets.every((p) => p.estimated), isTrue);
      expect(result.ascendant, 0);
      expect(result.houses, hasLength(12));
      expect(result.aspects.single.estimated, isTrue);
      expect(
        () => CalculationSnapshot.fromJson({...data, 'rules': {}}),
        throwsFormatException,
      );
      final unmarked = {
        ...data,
        'facts': [
          {
            'fact_id': 'sun',
            'kind': 'planet',
            'value': {'key': 'sun', 'longitude': 142},
          },
        ],
      };
      expect(
        () => CalculationSnapshot.fromJson(unmarked),
        throwsFormatException,
      );
    },
  );

  test('Western facts cannot be substituted with Thai results', () {
    expect(
      CalculationSnapshot.fromJson(calculation()).planets.single.longitude,
      142,
    );
    expect(
      () => CalculationSnapshot.fromJson({
        ...calculation(),
        'system': 'thai_natal',
      }),
      throwsFormatException,
    );
  });
  test('unknown time rejects ascendant, houses and planet house placement', () {
    for (final fact in [
      {
        'fact_id': 'a',
        'kind': 'ascendant',
        'value': {'longitude': 12},
      },
      {
        'fact_id': 'h',
        'kind': 'house',
        'value': {'number': 1, 'longitude': 12},
      },
      {
        'fact_id': 'p',
        'kind': 'planet',
        'value': {'key': 'sun', 'longitude': 12, 'house': 1},
      },
    ]) {
      expect(
        () => CalculationSnapshot.fromJson({
          ...calculation(precision: 'date_only'),
          'facts': [fact],
        }),
        throwsFormatException,
      );
    }
  });
  test('invalid and duplicate planets fail closed', () {
    for (final longitude in [-1, 360, double.nan]) {
      expect(
        () => CalculationSnapshot.fromJson({
          ...calculation(),
          'facts': [
            {
              'fact_id': 'p',
              'kind': 'planet',
              'value': {'key': 'sun', 'longitude': longitude},
            },
          ],
        }),
        throwsFormatException,
      );
    }
    final facts = calculation()['facts'] as List;
    expect(
      () => CalculationSnapshot.fromJson({
        ...calculation(),
        'facts': [
          ...facts,
          {
            'fact_id': 'p2',
            'kind': 'planet',
            'value': {'key': 'sun', 'longitude': 50},
          },
        ],
      }),
      throwsFormatException,
    );
  });
  test(
    'reports require matching result, locale and server-controlled access',
    () {
      final raw = {
        'report_id': 'r',
        'system': 'western_natal',
        'calculation_result_id': 'c1',
        'locale': 'th',
        'access': 'preview',
        'summary': 'preview',
        'preview': <dynamic>[],
        'sections': <dynamic>[],
      };
      expect(
        ReportSnapshot.fromJson(raw, resultId: 'c1', locale: 'th').full,
        isFalse,
      );
      expect(
        ReportSnapshot.fromJson(
          {...raw, 'calculation': calculation()},
          resultId: 'c1',
          locale: 'th',
        ).calculation!.id,
        'c1',
      );
      expect(
        () => ReportSnapshot.fromJson(
          {
            ...raw,
            'calculation': {...calculation(), 'result_id': 'another-chart'},
          },
          resultId: 'c1',
          locale: 'th',
        ),
        throwsFormatException,
      );
      expect(
        () => ReportSnapshot.fromJson(raw, resultId: 'c2', locale: 'th'),
        throwsFormatException,
      );
      expect(
        () => ReportSnapshot.fromJson(raw, resultId: 'c1', locale: 'en'),
        throwsFormatException,
      );
      expect(
        () => ReportSnapshot.fromJson(
          {
            ...raw,
            'sections': [
              {
                'key': 'paid',
                'title': 'full',
                'paragraphs': ['private body'],
              },
            ],
          },
          resultId: 'c1',
          locale: 'th',
        ),
        throwsFormatException,
      );
    },
  );
  test('generation progress cannot finish before the report is ready', () {
    final pending = ReportGenerationProgress.fromJson({
      'percent': 100,
      'stage': 'complete',
      'completed_topics': ['career', 'personality', 'career', 'unknown'],
    }, ready: false);
    expect(pending.percent, 99);
    expect(pending.stage, 'preparing');
    expect(pending.completedTopics, ['personality', 'career']);
    expect(ReportGenerationProgress.fromJson(null, ready: false).percent, 0);
    expect(
      ReportGenerationProgress.fromJson({'percent': -1}, ready: false).percent,
      0,
    );
    expect(ReportGenerationProgress.fromJson(null, ready: true).percent, 100);
    expect(
      ReportGenerationProgress.fromJson(null, ready: true).completedTopics,
      ReportGenerationProgress.topics,
    );
  });
  test('birth data preserves unknown time and rejects impossible dates', () {
    final raw = {
      'birth_date': '1999-02-20',
      'birth_time': null,
      'tzid': 'Asia/Bangkok',
    };
    expect(BirthProfile.fromJson(raw).time, isNull);
    expect(
      () => BirthProfile.fromJson({...raw, 'birth_date': '1999-02-30'}),
      throwsFormatException,
    );
    expect(
      () => BirthProfile.fromJson({...raw, 'birth_time': '25:00'}),
      throwsFormatException,
    );
  });
}
