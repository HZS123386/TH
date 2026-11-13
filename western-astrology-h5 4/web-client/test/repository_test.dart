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
  test(
    '429 honors Retry-After while polling, and no synthetic progress reaches 100',
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
              headers: {'retry-after': '7'},
            );
          }
          return jsonResponse(ready);
        }),
      );
      await repo.generate(object(ready['input']), token, (_, percent, phase) {
        percentages.add(percent);
        phases.add(phase);
      });
      expect(token.delays, [
        const Duration(seconds: 3),
        const Duration(seconds: 7),
      ]);
      expect(phases, contains('waiting'));
      expect(percentages.where((p) => p == 100), hasLength(1));
    },
  );
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
