import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fate_app/app/dependencies.dart';
import 'package:fate_app/core/models/birth_profile.dart';
import 'package:fate_app/core/network/api_client.dart';
import 'package:fate_app/core/storage/session_store.dart';
import 'package:fate_app/data/reports_repository.dart';

class GuestSessionStore implements SessionStore {
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
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.windows);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'an outgoing reports page cannot cancel polling for the incoming reading page',
    () async {
      SharedPreferences.setMockInitialValues({'fate.locale': 'en'});
      var reads = 0;
      final d = AppDependencies(
        await SharedPreferences.getInstance(),
        secureStore: GuestSessionStore(),
        client: ApiClient(
          'https://api.example.test',
          client: MockClient((request) async {
            expect(request.url.path, '/api/western/reports/r1');
            reads++;
            return http.Response(
              jsonEncode({
                'system': 'western_natal',
                'report_id': 'r1',
                'calculation_result_id': 'c1',
                'locale': 'en',
                'access': 'preview',
                'preview': [],
                'sections': [],
                'preview_state': reads >= 4 ? 'ready' : 'running',
              }),
              200,
            );
          }),
        ),
      );
      await d.reports.resume(
        const ReportReference('r1', 'c1', 'en', profileRevision: 1),
      );
      addTearDown(d.dispose);
      expect(d.reports.report!.generating, isTrue);
      final ready = Completer<void>();
      d.reports.addListener(() {
        if (d.reports.report?.previewState == 'ready' && !ready.isCompleted) {
          ready.complete();
        }
      });
      final outgoing = Object(), incoming = Object();
      d.reports.setActive(true, view: outgoing);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      d.reports.setActive(true, view: incoming);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      d.reports.setActive(false, view: outgoing);
      await ready.future.timeout(const Duration(seconds: 5));
      expect(reads, 4);
      expect(d.reports.report!.generating, isFalse);
    },
  );

  test(
    'guest saves birth details, reads a personal report, and restores it without logging in',
    () async {
      SharedPreferences.setMockInitialValues({'fate.locale': 'en'});
      final preferences = await SharedPreferences.getInstance();
      final secureStore = GuestSessionStore();
      final calculation =
          jsonDecode(
                File(
                  'test/fixtures/western_roxy_snapshot.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      Map<String, dynamic>? savedProfile;
      var guests = 0, reportReads = 0, consents = 0;
      ApiClient client() => ApiClient(
        'https://api.example.test',
        client: MockClient((request) async {
          final path = request.url.path;
          Object? response;
          var status = 200;
          if (path == '/api/config') {
            response = {
              'guest_reading': true,
              'modules': [
                {'id': 'western_astrology', 'status': 'ready'},
              ],
              'app_capabilities': {
                'western_reports': true,
                'ai_notice_version': 'notice-1',
              },
            };
          } else if (path == '/api/auth/guest') {
            guests++;
            response = {
              'token': 'private-guest-token',
              'user_id': 'guest-owner-1',
            };
            status = 201;
          } else {
            expect(
              request.headers['authorization'],
              'Bearer private-guest-token',
            );
            if (path == '/api/auth/me') {
              response = {'user_id': 'guest-owner-1', 'kind': 'guest'};
            } else if (path == '/api/profile') {
              if (request.method == 'PUT') {
                final body = jsonDecode(request.body) as Map<String, dynamic>;
                expect(body['system'], 'western_natal');
                expect(body['timezone'], 'Asia/Bangkok');
                savedProfile = {
                  'profile_id': 'p1',
                  'revision': 1,
                  'profile': body,
                };
              }
              response = savedProfile;
            } else if (path == '/api/calculations') {
              final body = jsonDecode(request.body) as Map;
              expect(body['profile_id'], 'p1');
              expect(body['profile_revision'], 1);
              response = calculation;
            } else if (path == '/api/privacy/consents') {
              consents++;
              status = 204;
            } else if (path == '/api/western/reports' &&
                request.method == 'POST') {
              expect(
                (jsonDecode(request.body) as Map)['calculation_result_id'],
                calculation['result_id'],
              );
              response = {'report_id': 'r1'};
              status = 202;
            } else if (path == '/api/western/reports/r1') {
              reportReads++;
              response = {
                'system': 'western_natal',
                'report_id': 'r1',
                'calculation_result_id': calculation['result_id'],
                'locale': 'en',
                'access': 'preview',
                'summary': 'Your personal guest reading',
                'preview': [
                  {
                    'key': 'personality',
                    'title': 'Your personality',
                    'paragraphs': ['Personal chart interpretation.'],
                  },
                ],
                'sections': [],
              };
            } else if (path == '/api/western/reports') {
              response = {
                'items': [
                  {
                    'report_id': 'r1',
                    'result_id': calculation['result_id'],
                    'locale': 'en',
                    'profile_revision': 1,
                  },
                ],
              };
            } else {
              fail('Unexpected request: ${request.method} $path');
            }
          }
          return http.Response(
            status == 204 ? '' : jsonEncode(response),
            status,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final d = AppDependencies(
        preferences,
        client: client(),
        secureStore: secureStore,
      );
      await d.session.initialize();
      expect(d.auth.hasSession, isFalse);
      await d.session.saveProfile(
        const BirthProfile(
          date: '1992-04-15',
          time: '07:15',
          timezone: 'Asia/Bangkok',
          place: 'Bangkok, TH',
          placeId: 'geonames:1609350',
          countryCode: 'TH',
          latitude: 13.7563,
          longitude: 100.5018,
        ),
      );
      expect(d.auth.isGuest, isTrue);
      expect(d.auth.signedIn, isFalse);
      expect(d.session.profile!.isServerRevision, isTrue);
      await d.chart.calculate();
      expect(d.chart.result!.example, isFalse);
      await d.session.configuration.consent('notice-1');
      await d.reports.generate(d.chart.result!);
      expect(d.reports.report!.summary, 'Your personal guest reading');
      expect(
        d.reports.report!.full,
        isFalse,
      ); // Guest access never grants a paid entitlement.
      await d.reports.loadHistory();
      expect(d.reports.history.single.id, 'r1');
      expect(guests, 1);
      expect(consents, 1);
      d.dispose();

      final restored = AppDependencies(
        preferences,
        client: client(),
        secureStore: secureStore,
      );
      restored.reports.setActive(true);
      final ready = Completer<void>();
      restored.reports.addListener(() {
        if (restored.reports.report != null && !ready.isCompleted) {
          ready.complete();
        }
      });
      await restored.session.initialize();
      await ready.future.timeout(const Duration(seconds: 2));
      expect(restored.auth.isGuest, isTrue);
      expect(restored.auth.signedIn, isFalse);
      expect(restored.reports.report!.id, 'r1');
      expect(guests, 1);
      expect(reportReads, 2);
      restored.dispose();
    },
  );
}
