import 'package:flutter_test/flutter_test.dart';
import 'package:fate_h5/core/models.dart';
import 'support.dart';

void main() {
  for (final language in ['zh', 'th']) {
    test('$language preserves the seven topics and full action plan', () {
      final report = LifeReport.parse(fixture(language: language, full: true));
      expect(report.ready, isTrue);
      expect(report.catalog.map((item) => item['key']), fortuneKeys);
      expect(report.chapters, hasLength(7));
      expect(objects(report.plan['phases']), hasLength(3));
      expect(report.language, language);
      expect(report.percent(true), 100);
    });
    test(
      '$language preview cannot expose injected paid chapters in the UI or export',
      () {
        final data = fixture(language: language, full: true)
          ..['access'] = 'preview';
        final report = LifeReport.parse(data);
        expect(report.chapters, isEmpty);
        expect(report.plan, isEmpty);
        expect(report.exportPayload()['chapters'], isEmpty);
        expect(report.exportPayload()['plan'], isNull);
        expect(report.percent(true), 99);
        expect(report.preview, isNotEmpty);
      },
    );
  }
  test('a report for another birth input or identifier is rejected', () {
    final data = fixture();
    final input = object(data['input']);
    final other = {
      ...input,
      'profile': {...object(input['profile']), 'birth_date': '1999-01-01'},
    };
    expect(
      () => LifeReport.parse(data, expectedInput: other),
      throwsFormatException,
    );
    expect(
      () => LifeReport.parse(data, id: 'other-report-id'),
      throwsFormatException,
    );
  });
  test('unknown birth time remains null in signatures and exports', () {
    final data = fixture();
    object(data['input']);
    final input = object(data['input']);
    input['profile'] = {...object(input['profile']), 'birth_time': null};
    data['input'] = input;
    final chart = object(data['chart']);
    data['chart'] = {
      ...chart,
      'precision': 'estimated',
      'houses': [],
      'planets': [
        for (final p in objects(chart['planets']))
          if (p['id'] != 'ascendant') {...p, 'house': null},
      ],
    };
    data['time_accuracy'] = {
      'mode': 'estimated',
      'assumed_local_time': '12:00',
    };
    final report = LifeReport.parse(data, expectedInput: input);
    expect(report.estimated, isTrue);
    expect(report.profile['birth_time'], isNull);
    expect(
      object(object(report.exportPayload()['input'])['profile'])['birth_time'],
      isNull,
    );
  });
  test(
    'a corrupted chart cannot reach the canvas or present unknown-time houses as exact',
    () {
      final invalid = fixture();
      final chart = object(invalid['chart']);
      invalid['chart'] = {
        ...chart,
        'planets': [
          {...objects(chart['planets']).first, 'longitude': double.nan},
        ],
      };
      expect(() => LifeReport.parse(invalid), throwsFormatException);
      final unknown = fixture();
      unknown['input'] = {
        ...object(unknown['input']),
        'profile': {
          ...object(object(unknown['input'])['profile']),
          'birth_time': null,
        },
      };
      expect(() => LifeReport.parse(unknown), throwsFormatException);
    },
  );
  test(
    'invalid or duplicated progress sections cannot produce fabricated completion',
    () {
      final data = fixture();
      data['preview_generation_progress'] = {
        'percent': 100,
        'sections': [
          for (var i = 0; i < 4; i++)
            {'key': 'preview_summary', 'percent': 100},
        ],
      };
      expect(() => LifeReport.parse(data), throwsFormatException);
    },
  );
  test('ready state with incomplete chapters does not display 100 percent', () {
    final data = fixture(full: true);
    data['progress'] = {'completed': 1, 'total': 8};
    final report = LifeReport.parse(data);
    expect(report.ready, isFalse);
    expect(report.percent(true), lessThan(100));
    expect(report.exportPayload()['access'], 'preview');
    expect(report.exportPayload()['chapters'], isEmpty);
    expect(report.exportPayload()['plan'], isNull);
  });
  test('unsupported payment modes and negative prices are rejected', () {
    for (final change in [
      {'mode': 'unverified_live'},
      {'amount': -1},
      {'currency': 'unknown'},
    ]) {
      final data = fixture();
      data['price'] = {...object(data['price']), ...change};
      expect(() => LifeReport.parse(data), throwsFormatException);
    }
  });
  test('all generation labels and both languages remain present', () {
    final data = translations();
    for (final language in ['zh', 'th']) {
      final c = Copy(data, language);
      for (final key in [...previewKeys, ...fortuneKeys, 'plan']) {
        expect(c.t('generation', 'sections.$key'), isNotEmpty);
      }
      for (final topic in c.topics) {
        expect(c.topicTitle(topic, 2026), isNotEmpty);
        expect(object(topic[language])['questions'], isNotEmpty);
      }
      expect(c.t('checkout', 'cardConfirm'), isNotEmpty);
    }
  });
  test('date validation rejects impossible, future, and pre-1901 dates', () {
    for (final value in [
      '2025-02-29',
      '2026-11-11',
      '1900-12-31',
      '1999-13-01',
      'not-a-date',
    ]) {
      expect(validBirthDate(value, '2026-11-10'), isFalse);
    }
    expect(validBirthDate('2000-02-29', '2026-11-10'), isTrue);
  });
}
