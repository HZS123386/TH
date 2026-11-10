import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fate_app/core/network/api_client.dart';
import 'package:fate_app/core/storage/session_store.dart';
import 'package:fate_app/data/auth_repository.dart';
import 'package:fate_app/data/profile_repository.dart';
import 'package:fate_app/data/configuration_repository.dart';
import 'package:fate_app/app/session_view_model.dart';

class TestSessionStore implements SessionStore {
  Map<String, dynamic>? value;
  @override
  Future<Map<String, dynamic>?> read() async => value;
  @override
  Future<void> write(Map<String, dynamic> next) async {
    value = next;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

void main() {
  test(
    'US city search selects the US catalog and keeps the returned timezone',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = ApiClient(
        'https://api.example.test',
        client: MockClient((request) async {
          expect(request.url.queryParameters['country'], 'US');
          expect(request.url.queryParameters['level'], 'city');
          return http.Response(
            '{"items":[{"id":"geonames:5128581","nameEnglish":"New York City","timeZone":"America/New_York"}]}',
            200,
          );
        }),
      );
      final rows = await ProfileRepository(
        api,
        LocalDraftStore(await SharedPreferences.getInstance()),
      ).locations('New York', 'en', country: 'US');
      expect(rows.single['timezone'], 'America/New_York');
      api.close();
    },
  );
  test(
    'city lookup uses the existing directory contract and returns a localized name with its IANA timezone',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = ApiClient(
        'https://api.example.test',
        client: MockClient((request) async {
          expect(request.url.queryParameters['query'], 'Bangkok');
          expect(request.url.queryParameters['level'], 'auto');
          expect(request.url.queryParameters['country'], 'TH');
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'geonames:1609350',
                  'nameEnglish': 'Bangkok',
                  'nameThai': 'กรุงเทพมหานคร',
                  'timeZone': 'Asia/Bangkok',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final repo = ProfileRepository(
        api,
        LocalDraftStore(await SharedPreferences.getInstance()),
      );
      final locations = await repo.locations('Bangkok', 'en');
      expect(locations.single['label'], 'Bangkok');
      expect(locations.single['timezone'], 'Asia/Bangkok');
      api.close();
    },
  );
  test(
    'an old-account response cannot expire the new account session',
    () async {
      final response = Completer<http.Response>();
      var expired = false;
      final api = ApiClient(
        'https://api.example.test',
        client: MockClient((_) => response.future),
      )..accessToken = 'account-a';
      api.onSessionExpired = () => expired = true;
      final request = api.get('/api/profile');
      final expectation = expectLater(
        request,
        throwsA(
          isA<ApiFailure>().having((e) => e.code, 'code', 'session_changed'),
        ),
      );
      api.sessionVersion++;
      api.accessToken = 'account-b';
      response.complete(http.Response('{}', 401));
      await expectation;
      expect(expired, isFalse);
      expect(api.accessToken, 'account-b');
      api.close();
    },
  );
  test(
    'a refresh completing after logout cannot restore credentials',
    () async {
      final delayed = Completer<http.Response>();
      final started = Completer<void>();
      final api = ApiClient(
        'https://api.example.test',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/refresh')) {
            started.complete();
            return delayed.future;
          }
          return http.Response('{"user_id":"a","kind":"account"}', 200);
        }),
      );
      final store = TestSessionStore()
        ..value = {'access_token': 'old', 'refresh_token': 'refresh'};
      final auth = AuthRepository(api, store);
      await auth.restore();
      final refresh = auth.refresh();
      await started.future;
      await auth.clear();
      delayed.complete(
        http.Response(
          '{"access_token":"late","refresh_token":"late-refresh"}',
          200,
        ),
      );
      expect(await refresh, isFalse);
      expect(api.accessToken, isNull);
      expect(store.value, isNull);
      auth.dispose();
      api.close();
    },
  );
  test(
    'existing account birth data is restored without copying guest data or recalculating Bazi',
    () async {
      SharedPreferences.setMockInitialValues({});
      final requests = <String>[];
      final profile = {
        'profile_id': 'profile-a',
        'revision': 2,
        'profile': {
          'birth_date': '1999-02-20',
          'birth_time': null,
          'timezone': 'Asia/Bangkok',
          'birthplace': 'Bangkok',
        },
      };
      final api = ApiClient(
        'https://api.example.test',
        client: MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          if (request.url.path == '/api/auth/login') {
            return http.Response('{"token":"account-token"}', 200);
          }
          if (request.url.path == '/api/auth/me') {
            return http.Response('{"user_id":"a","kind":"account"}', 200);
          }
          return http.Response(jsonEncode(profile), 200);
        }),
      );
      final drafts = LocalDraftStore(await SharedPreferences.getInstance()),
          auth = AuthRepository(api, TestSessionStore());
      final session = SessionViewModel(
        auth,
        ProfileRepository(api, drafts),
        ConfigurationRepository(api),
        drafts,
      );
      final restored = Completer<void>();
      session.addListener(() {
        if (session.profile?.id == 'profile-a' && !restored.isCompleted) {
          restored.complete();
        }
      });
      await auth.signInDevelopment('test-user', 'test-only-password');
      await restored.future;
      expect(session.profile?.revision, 2);
      expect(drafts.read('guest', 'birth'), isNull);
      expect(requests, [
        'POST /api/auth/login',
        'GET /api/auth/me',
        'GET /api/profile',
      ]);
      session.dispose();
      auth.dispose();
      api.close();
    },
  );
}
