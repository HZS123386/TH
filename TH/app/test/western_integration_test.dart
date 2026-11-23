import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fate_app/core/models/birth_profile.dart';
import 'package:fate_app/core/models/calculation.dart';
import 'package:fate_app/core/network/api_client.dart';
import 'package:fate_app/core/storage/session_store.dart';
import 'package:fate_app/data/profile_repository.dart';
import 'package:fate_app/data/reports_repository.dart';
import 'package:fate_app/app/dependencies.dart';

class RestoringSessionStore implements SessionStore {
  Map<String, dynamic>? value = {'access_token': 'test-session'};
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
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.windows);
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  test(
    'restores the selected report after login recovery but not after birth details change',
    () async {
      SharedPreferences.setMockInitialValues({'fate.locale': 'en'});
      final preferences = await SharedPreferences.getInstance();
      var reads = 0;
      final api = ApiClient(
        'https://api.example.test',
        client: MockClient((request) async {
          if (request.url.path == '/api/auth/me') {
            return http.Response('{"user_id":"user1","username":"test"}', 200);
          }
          expect(request.url.path, '/api/western/reports/r1');
          reads++;
          return http.Response(
            jsonEncode({
              'system': 'western_natal',
              'report_id': 'r1',
              'calculation_result_id': 'c1',
              'locale': 'en',
              'access': 'preview',
              'summary': 'Restored personal report',
              'preview': [],
              'sections': [],
            }),
            200,
          );
        }),
      );
      final d = AppDependencies(
        preferences,
        client: api,
        secureStore: RestoringSessionStore(),
      );
      const profile = BirthProfile(
        date: '1992-04-15',
        time: '07:15',
        timezone: 'Asia/Bangkok',
        place: 'Bangkok',
        id: 'p1',
        revision: 1,
      );
      await d.session.profiles.save(
        'user1',
        profile,
        serverContractReady: false,
      );
      await d.reports.repository.remember(
        'user1',
        const ReportReference('r1', 'c1', 'en', profileRevision: 1),
      );
      d.reports.setActive(true);
      final restored = Completer<void>();
      d.reports.addListener(() {
        if (d.reports.report?.summary == 'Restored personal report' &&
            !restored.isCompleted) {
          restored.complete();
        }
      });
      await d.auth.restore();
      await restored.future.timeout(const Duration(seconds: 2));
      expect(reads, 1);
      expect(d.reports.reference!.id, 'r1');
      await d.session.saveProfile(
        const BirthProfile(
          date: '1992-04-16',
          time: '07:15',
          timezone: 'Asia/Bangkok',
          place: 'Bangkok',
          id: 'p1',
          revision: 2,
        ),
      );
      expect(d.reports.report, isNull);
      expect(d.reports.hasResumable, isFalse);
      expect(reads, 1);
      d.dispose();
    },
  );
  test(
    'preserves the actual backend error code for localized chart errors',
    () async {
      final api = ApiClient(
        'https://api.example.test',
        client: MockClient(
          (_) async => http.Response(
            '{"detail":"internal display copy","code":"profile_changed"}',
            409,
          ),
        ),
      );
      await expectLater(
        api.get('/api/profile'),
        throwsA(
          isA<ApiFailure>().having((e) => e.code, 'code', 'profile_changed'),
        ),
      );
      api.close();
    },
  );
  test(
    'parses the real Roxy reference chart through the APP wire contract',
    () {
      final raw =
          jsonDecode(
                File(
                  'test/fixtures/western_roxy_snapshot.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final result = CalculationSnapshot.fromJson(raw);
      expect(result.planets.length, 10);
      expect(result.planets.first.longitude, closeTo(25.289049, .00001));
      expect(result.ascendant, closeTo(44.174405, .00001));
      expect(result.midheaven, closeTo(305.305233, .00001));
      expect(result.houses.length, 12);
      expect(
        result.planets.singleWhere((p) => p.key == 'jupiter').retrograde,
        isTrue,
      );
      expect(result.aspects, isNotEmpty);
      expect(result.aspects.every((a) => a.orb! <= 6), isTrue);
      final facts = raw['facts'] as List;
      expect(
        () => CalculationSnapshot.fromJson({
          ...raw,
          'input_precision': 'date_only',
        }),
        throwsFormatException,
      );
      final aspect = Map<String, dynamic>.from(
        facts.firstWhere((f) => f['kind'] == 'aspect') as Map,
      );
      expect(
        () => CalculationSnapshot.fromJson({
          ...raw,
          'facts': [
            ...facts.where((f) => f != aspect),
            {
              ...aspect,
              'value': {...aspect['value'] as Map, 'orb': double.nan},
            },
          ],
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'saves birth details using the real backend fields and profile revision',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = ApiClient(
        'https://api.example.test',
        client: MockClient((request) async {
          expect(request.method, 'PUT');
          expect(request.url.path, '/api/profile');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['system'], 'western_natal');
          expect(body['timezone'], 'Asia/Bangkok');
          expect(body['location_id'], 'geonames:1609350');
          expect(body['expected_revision'], 2);
          expect(body.containsKey('tzid'), isFalse);
          return http.Response(
            jsonEncode({'profile_id': 'p1', 'revision': 3, 'profile': body}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final repository = ProfileRepository(
        api,
        LocalDraftStore(await SharedPreferences.getInstance()),
      );
      final saved = await repository.save(
        'account1',
        const BirthProfile(
          date: '1992-04-15',
          time: '07:15',
          timezone: 'Asia/Bangkok',
          place: 'Bangkok',
          placeId: 'geonames:1609350',
          id: 'p1',
          revision: 2,
        ),
        serverContractReady: true,
      );
      expect(saved.isServerRevision, isTrue);
      expect(saved.revision, 3);
      expect(repository.local('account1')!.placeId, 'geonames:1609350');
      expect(repository.local('account2'), isNull);
    },
  );
}
