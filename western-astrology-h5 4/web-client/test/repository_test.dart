import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fate_h5/core/models.dart';
import 'package:fate_h5/core/repository.dart';

import 'support.dart';

http.Response jsonResponse(dynamic data) => http.Response(
  jsonEncode(data),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class ImmediateToken extends CancelToken {
  final delays = <Duration>[];
  @override
  Future<void> pause(Duration delay) async {
    check();
    delays.add(delay);
  }
}

void main() {
  for (final language in ['zh', 'th']) {
    test(
      '$language resumes a queued preview through calculation without creating another report',
      () async {
        final done = fixture(language: language);
        final queued = {
          ...done,
          'preview': null,
          'preview_state': 'queued',
          'chart': null,
          'generation_queue': {'state': 'queued', 'position': 68},
        };
        final token = ImmediateToken();
        final phases = <String>[];
        final requests = <http.Request>[];
        final repo = ReportRepository(
          TestBrowser(),
          baseUrl: 'https://example.test',
          client: MockClient((request) async {
            requests.add(request);
            return jsonResponse(
              requests.length == 1
                  ? {
                      ...queued,
                      'preview_state': 'generating',
                      'generation_queue': {
                        'state': 'calculating',
                        'position': 0,
                      },
                    }
                  : done,
            );
          }),
        );
        final result = await repo.resumeGeneration(
          LifeReport.parse(queued),
          token,
          (_, _, phase) => phases.add(phase),
          full: false,
        );
        expect(result.preview, isNotEmpty);
        expect(result.language, language);
        expect(phases, ['queued', 'calculating', 'preview']);
        expect(
          requests.every(
            (r) =>
                r.method == 'GET' && r.url.path.endsWith(done['id'] as String),
          ),
          isTrue,
        );
        expect(token.delays, [Duration.zero, const Duration(seconds: 2)]);
      },
    );
  }

  test(
    'request failures retain visit ownership without sending personal paths to telemetry',
    () async {
      final browser = TestBrowser()..visit = {'id': 'synthetic-visit'};
      final failures = <List<String>>[];
      late http.Request sent;
      final repo =
          ReportRepository(
              browser,
              baseUrl: 'https://example.test',
              client: MockClient((request) async {
                sent = request;
                throw http.ClientException('offline');
              }),
            )
            ..visitContext = browser.visitContext
            ..onClientFailure = ((path, code, method) =>
                failures.add([path, code, method]));
      await expectLater(
        repo.request(
          '/api/life-reports/private-report/payment?secret=discard',
          CancelToken(),
        ),
        throwsA(isA<ApiFailure>()),
      );
      expect(sent.headers['X-Visit-Id'], 'synthetic-visit');
      expect(sent.headers['X-Report-Key'], browser.key);
      expect(failures, [
        ['/api/life-reports/{report_id}/payment', 'network', 'GET'],
      ]);
      await expectLater(
        repo.request('/api/landing/visits', CancelToken(), body: browser.visit),
        throwsA(isA<ApiFailure>()),
      );
      expect(failures.length, 1);
      await expectLater(
        repo.request(
          '/api/thai-locations?country=TH',
          CancelToken(),
          owned: false,
        ),
        throwsA(isA<ApiFailure>()),
      );
      expect(sent.headers['X-Visit-Id'], 'synthetic-visit');
      expect(failures.last, ['/api/thai-locations', 'network', 'GET']);
    },
  );

  test(
    'a stalled progress read times out without cancelling the report',
    () async {
      final gate = Completer<void>();
      var calls = 0;
      final token = CancelToken();
      final data = fixture();
      final repo = ReportRepository(
        TestBrowser(),
        baseUrl: 'https://example.test',
        client: MockClient((_) async {
          if (calls++ == 0) await gate.future;
          return jsonResponse(data);
        }),
      );
      await expectLater(
        repo.request(
          '/api/life-reports/${data['id']}',
          token,
          timeout: const Duration(milliseconds: 10),
        ),
        throwsA(isA<ApiFailure>().having((e) => e.code, 'code', 'network')),
      );
      expect(token.cancelled, isFalse);
      gate.complete();
      expect((await repo.load(data['id'], token)).id, data['id']);
    },
  );

  test(
    'preview generation uses the original input, language and existing owner key',
    () async {
      final browser = TestBrowser();
      late http.Request sent;
      final data = fixture();
      final repo = ReportRepository(
        browser,
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          sent = request;
          return jsonResponse(data);
        }),
      )..language = 'zh';
      final report = await repo.generate(
        object(data['input']),
        CancelToken(),
        (_, _, _) {},
      );
      expect(sent.method, 'POST');
      expect(sent.url.path, '/api/life-reports');
      expect(sent.url.queryParameters['wait'], 'false');
      expect(sent.headers['X-Report-Key'], browser.key);
      expect(sent.headers['Accept-Language'], 'zh');
      expect(jsonDecode(sent.body), data['input']);
      expect(report.preview, isNotEmpty);
    },
  );

  for (final retryAfter in ['7', '1', null]) {
    test(
      '429 honors Retry-After $retryAfter and resumes normal polling',
      () async {
        final ready = fixture();
        final generating = {
          ...ready,
          'preview': null,
          'preview_state': 'generating',
        };
        var reads = 0;
        final phases = <String>[];
        final percentages = <double>[];
        final token = ImmediateToken();
        final repo = ReportRepository(
          TestBrowser(),
          baseUrl: 'https://example.test',
          client: MockClient((request) async {
            if (request.method == 'POST') return jsonResponse(generating);
            if (reads++ == 0) {
              return http.Response(
                '{"detail":"limited"}',
                429,
                headers: retryAfter == null
                    ? const {}
                    : {'retry-after': retryAfter},
              );
            }
            return jsonResponse(reads == 2 ? generating : ready);
          }),
        );
        await repo.generate(object(ready['input']), token, (_, percent, phase) {
          percentages.add(percent);
          phases.add(phase);
        });
        expect(token.delays, [
          Duration.zero,
          Duration(
            seconds: retryAfter == null
                ? 60
                : retryAfter == '1'
                ? 3
                : 7,
          ),
          const Duration(seconds: 2),
        ]);
        expect(phases, contains('waiting'));
        expect(percentages.where((p) => p == 100), hasLength(1));
      },
    );
  }

  for (final language in ['zh', 'th']) {
    test(
      'long previews complete with two-second polling in $language',
      () async {
        final ready = fixture();
        ready['input'] = {
          ...object(ready['input']),
          'profile': {
            ...object(object(ready['input'])['profile']),
            'language': language,
          },
        };
        final generating = {
          ...ready,
          'preview': null,
          'preview_state': 'generating',
        };
        final token = ImmediateToken();
        var reads = 0;
        var starts = 0;
        final repo = ReportRepository(
          TestBrowser(),
          baseUrl: 'https://example.test',
          client: MockClient((request) async {
            expect(request.headers['Accept-Language'], language);
            if (request.method == 'POST') {
              starts++;
              return jsonResponse(generating);
            }
            return jsonResponse(++reads < 36 ? generating : ready);
          }),
        )..language = language;
        final result = await repo.generate(
          object(ready['input']),
          token,
          (_, _, _) {},
        );
        expect(result.preview, isNotEmpty);
        expect(starts, 1);
        expect(reads, 36);
        expect(token.delays, [
          Duration.zero,
          ...List.filled(35, const Duration(seconds: 2)),
        ]);
        expect(
          token.delays.fold<int>(
            0,
            (seconds, delay) => seconds + delay.inSeconds,
          ),
          70,
        );
      },
    );
  }

  test(
    'pending provider response is a busy rejection, not a pollable job',
    () async {
      final data = fixture()..['preview'] = null;
      data['preview_state'] = 'pending';
      var calls = 0;
      final repo = ReportRepository(
        TestBrowser(),
        baseUrl: 'https://example.test',
        client: MockClient((_) async {
          calls++;
          return jsonResponse(data);
        }),
      );
      await expectLater(
        repo.generate(object(data['input']), ImmediateToken(), (_, _, _) {}),
        throwsA(isA<ApiFailure>().having((e) => e.code, 'code', 'busy')),
      );
      expect(calls, 1);
    },
  );

  test(
    'a failed or unconfigured generation stops and retains server report state',
    () async {
      final data = fixture()..['preview'] = null;
      data['preview_state'] = 'unconfigured';
      final repo = ReportRepository(
        TestBrowser(),
        baseUrl: 'https://example.test',
        client: MockClient((_) async => jsonResponse(data)),
      );
      await expectLater(
        repo.generate(object(data['input']), ImmediateToken(), (_, _, _) {}),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.code,
            'code',
            'previewStates.unconfigured',
          ),
        ),
      );
    },
  );

  test(
    'unlock requires the server to return full access for the same report',
    () async {
      final preview = LifeReport.parse(fixture());
      final repo = ReportRepository(
        TestBrowser(),
        baseUrl: 'https://example.test',
        client: MockClient((request) async => jsonResponse(fixture())),
      );
      await expectLater(
        repo.unlock(preview, ImmediateToken(), (_, _, _) {}),
        throwsA(isA<ApiFailure>().having((e) => e.code, 'code', 'badResult')),
      );
    },
  );

  test(
    'successful unlock uses the existing endpoint and retains every paid chapter',
    () async {
      final full = fixture(full: true);
      late http.Request request;
      final repo = ReportRepository(
        TestBrowser(),
        baseUrl: 'https://example.test',
        client: MockClient((sent) async {
          request = sent;
          return jsonResponse(full);
        }),
      );
      final report = await repo.unlock(
        LifeReport.parse(fixture()),
        CancelToken(),
        (_, _, _) {},
      );
      expect(request.url.path, '/api/life-reports/${report.id}/unlock');
      expect(request.body, '{}');
      expect(report.chapters, hasLength(7));
      expect(report.ready, isTrue);
    },
  );

  test(
    'location queries preserve country/province scope without sending an owner key',
    () async {
      late http.Request request;
      final repo = ReportRepository(
        TestBrowser(),
        baseUrl: 'https://example.test',
        client: MockClient((sent) async {
          request = sent;
          return http.Response('{"items":[],"total":0}', 200);
        }),
      );
      await repo.cities('TH', 'geonames:1609348', 'Bangkok', 20, CancelToken());
      expect(request.url.queryParameters, {
        'country': 'TH',
        'province': 'geonames:1609348',
        'level': 'locality',
        'query': 'Bangkok',
        'offset': '20',
      });
      expect(request.headers.containsKey('X-Report-Key'), isFalse);
    },
  );

  test(
    'free preview starts a completion wait immediately and still requires saved content',
    () async {
      final ready = fixture();
      Json generating(int percent) => {
        ...ready,
        'preview': null,
        'preview_state': 'generating',
        'preview_generation_progress': {
          'percent': percent,
          'sections': [
            for (final key in previewKeys) {'key': key, 'percent': percent},
          ],
        },
      };
      var reads = 0;
      final token = ImmediateToken();
      final percentages = <double>[];
      final repo = ReportRepository(
        TestBrowser(),
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          if (request.method == 'GET') {
            expect(request.url.queryParameters['wait_preview'], 'true');
          }
          return jsonResponse(
            request.method == 'POST'
                ? generating(20)
                : reads++ == 0
                ? generating(99)
                : ready,
          );
        }),
      );
      await repo.generate(
        object(ready['input']),
        token,
        (_, percent, _) => percentages.add(percent),
      );
      expect(token.delays, [Duration.zero, const Duration(seconds: 2)]);
      expect(percentages, [20, 99, 100]);
    },
  );

  test('a slow final preview stays below the server polling limit', () async {
    final ready = fixture();
    final generating = {
      ...ready,
      'preview': null,
      'preview_state': 'generating',
      'preview_generation_progress': {
        'percent': 99,
        'sections': [
          for (final key in previewKeys) {'key': key, 'percent': 99},
        ],
      },
    };
    final token = ImmediateToken();
    final accepted = <int>[];
    var reads = 0, rejected = 0;
    final repo = ReportRepository(
      TestBrowser(),
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        if (request.method == 'POST') return jsonResponse(generating);
        final elapsed = token.delays.fold<int>(
          0,
          (sum, delay) => sum + delay.inSeconds,
        );
        accepted.removeWhere((time) => time <= elapsed - 60);
        if (accepted.length >= 30) {
          rejected++;
          return http.Response(
            '{"detail":"limited"}',
            429,
            headers: {'retry-after': '30'},
          );
        }
        accepted.add(elapsed);
        return jsonResponse(reads++ < 40 ? generating : ready);
      }),
    );
    final result = await repo.generate(
      object(ready['input']),
      token,
      (_, _, _) {},
    );
    expect(result.preview, isNotEmpty);
    expect(rejected, 0);
    expect(
      token.delays.fold<int>(0, (sum, delay) => sum + delay.inSeconds),
      greaterThan(60),
    );
    expect(token.delays.first, Duration.zero);
    expect(token.delays.last, const Duration(seconds: 2));
  });

  test('cancel interrupts a long polling delay immediately', () async {
    final token = CancelToken();
    final wait = token.pause(const Duration(seconds: 60));
    scheduleMicrotask(token.cancel);
    await expectLater(wait, throwsA(isA<Cancelled>()));
  });

  test('reports for a mismatched input never become visible', () async {
    final data = fixture();
    final wrong = object(data['input']);
    wrong['year'] = 2025;
    final repo = ReportRepository(
      TestBrowser(),
      baseUrl: 'https://example.test',
      client: MockClient((_) async => jsonResponse(data)),
    );
    await expectLater(
      repo.generate(wrong, ImmediateToken(), (_, _, _) {}),
      throwsFormatException,
    );
  });
}
