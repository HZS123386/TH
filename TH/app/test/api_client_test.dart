import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fate_app/core/network/api_client.dart';

void main() {
  test(
    'does not replay an old request under a new account after a refresh',
    () async {
      final started = Completer<void>(), refresh = Completer<bool>();
      var calls = 0;
      final api = ApiClient(
        'https://api.example.test',
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 401);
        }),
      );
      api.refreshSession = () {
        started.complete();
        return refresh.future;
      };
      final result = api.get('/api/profile');
      final check = expectLater(
        result,
        throwsA(
          isA<ApiFailure>().having((e) => e.code, 'code', 'session_changed'),
        ),
      );
      await started.future;
      api.sessionVersion++;
      api.accessToken = 'new-account';
      refresh.complete(true);
      await check;
      expect(calls, 1);
      expect(api.accessToken, 'new-account');
      api.close();
    },
  );
  test(
    'retries the same operation after refresh without changing its idempotency key',
    () async {
      final headers = <Map<String, String>>[];
      final api = ApiClient(
        'https://api.example.test',
        client: MockClient((request) async {
          headers.add(request.headers);
          return request.headers['Authorization'] == 'Bearer old'
              ? http.Response('{}', 401)
              : http.Response('{"result_id":"c1"}', 200);
        }),
      )..accessToken = 'old';
      api.refreshSession = () async {
        api.accessToken = 'new';
        return true;
      };
      expect(
        await api.request(
          'POST',
          '/api/calculations',
          requestKey: 'stable-key',
          body: {'system': 'western_natal'},
        ),
        {'result_id': 'c1'},
      );
      expect(headers.map((h) => h['Idempotency-Key']), [
        'stable-key',
        'stable-key',
      ]);
      api.close();
    },
  );
  test('concurrent 401 responses share one refresh', () async {
    final completion = Completer<bool>();
    var refreshes = 0;
    final api = ApiClient(
      'https://api.example.test',
      client: MockClient(
        (request) async => http.Response(
          '{}',
          request.headers['Authorization'] == 'Bearer old' ? 401 : 200,
        ),
      ),
    )..accessToken = 'old';
    api.refreshSession = () {
      refreshes++;
      return completion.future;
    };
    final requests = [api.get('/api/profile'), api.get('/api/life-reports')];
    await Future<void>.delayed(Duration.zero);
    expect(refreshes, 1);
    api.accessToken = 'new';
    completion.complete(true);
    await Future.wait(requests);
    api.close();
  });
  test(
    'structured errors retain a request id without exposing raw response text',
    () async {
      final api = ApiClient(
        'https://api.example.test',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {
                'code': 'profile_required',
                'retryable': false,
                'request_id': 'trace-1',
              },
            }),
            422,
          ),
        ),
      );
      await expectLater(
        api.get('/api/profile'),
        throwsA(
          isA<ApiFailure>()
              .having((e) => e.code, 'code', 'profile_required')
              .having((e) => e.requestId, 'requestId', 'trace-1'),
        ),
      );
      api.close();
    },
  );
}
