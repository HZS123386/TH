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
