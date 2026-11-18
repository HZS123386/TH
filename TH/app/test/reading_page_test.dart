import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fate_app/app/dependencies.dart';
import 'package:fate_app/app/fate_app.dart';
import 'package:fate_app/core/models/birth_profile.dart';
import 'package:fate_app/core/network/api_client.dart';
import 'package:fate_app/core/storage/session_store.dart';
import 'package:fate_app/features/chart/chart_wheel.dart';
import 'package:fate_app/l10n/generated/app_localizations_en.dart';

class _GuestStore implements SessionStore {
  @override
  Future<Map<String, dynamic>?> read() async => {'access_token': 'test-guest'};
  @override
  Future<void> write(Map<String, dynamic> value) async {}
  @override
  Future<void> clear() async {}
}

void main() {
  for (final scenario in [
    (true, false, false),
    (false, false, false),
    (true, true, false),
    (false, true, false),
    (true, false, true),
  ]) {
    final (full, estimated, fails) = scenario;
    testWidgets(
      'chart opens a ${estimated ? 'noon-estimated' : 'known-time'} reading with server-controlled ${full ? 'full' : 'preview'} sections${fails ? ' and keeps failed progress visible' : ''}',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({'fate.locale': 'en'});
        final calculation =
            jsonDecode(
                  File(
                    'test/fixtures/western_roxy_snapshot.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        if (estimated) {
          calculation['input_precision'] = 'estimated_time';
          calculation['status'] = 'partial';
          calculation['rules'] = {'assumed_local_time': '12:00'};
          for (final fact in calculation['facts'] as List) {
            (fact['value'] as Map)['estimated'] = true;
          }
        }
        var creates = 0, consents = 0, ready = false, failed = false;
        var transientPollFailure = false;
        var deleted = false, deletes = 0;
        const number = 'FATE-A1B2C3D4E5';
        final sections = [
          for (final key in [
            'personality',
            'career',
            'money',
            'relationships',
            'watch',
            'actions',
          ])
            {
              'key': key,
              'title': key.toUpperCase(),
              'paragraphs': [
                '$key personal interpretation',
                'An everyday example\n$key example from this chart.',
                'What you can do\n1. $key first step.\n\n2. $key second step.',
              ],
            },
        ];
        final d = AppDependencies(
          await SharedPreferences.getInstance(),
          secureStore: _GuestStore(),
          client: ApiClient(
            'https://api.example.test',
            client: MockClient((request) async {
              final path = request.url.path;
              if (path == '/api/western/reports/r1' && transientPollFailure) {
                transientPollFailure = false;
                return http.Response(
                  jsonEncode({
                    'error': {'code': 'too_many_requests', 'retryable': true},
                  }),
                  429,
                );
              }
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
              } else if (path == '/api/auth/me') {
                response = {'user_id': 'g1', 'kind': 'guest'};
              } else if (path == '/api/calculations') {
                response = calculation;
              } else if (path == '/api/western/reports' &&
                  request.method == 'GET') {
                response = {
                  'items':
                      creates == 0 ||
                          deleted ||
                          !number
                              .replaceAll('-', '')
                              .toLowerCase()
                              .contains(
                                (request.url.queryParameters['q'] ?? '')
                                    .replaceAll('-', '')
                                    .toLowerCase(),
                              )
                      ? []
                      : [
                          {
                            'report_id': 'r1',
                            'result_id': calculation['result_id'],
                            'locale': 'en',
                            'profile_revision': 1,
                            'report_number': number,
                            'created_at': 1794481200,
                            'state': failed
                                ? 'failed'
                                : ready
                                ? 'ready'
                                : 'running',
                          },
                        ],
                };
              } else if (path == '/api/privacy/consents') {
                consents++;
                status = 204;
              } else if (path == '/api/western/reports' &&
                  request.method == 'POST') {
                expect(consents, 1);
                expect(
                  (jsonDecode(request.body) as Map)['calculation_result_id'],
                  calculation['result_id'],
                );
                creates++;
                status = 202;
                response = {'report_id': 'r1', 'report_number': number};
              } else if (path == '/api/western/reports/r1' &&
                  request.method == 'DELETE') {
                deletes++;
                deleted = true;
                status = 204;
              } else if (path == '/api/western/reports/r1') {
                response = {
                  'system': 'western_natal',
                  'report_id': 'r1',
                  'report_number': number,
                  'calculation_result_id': calculation['result_id'],
                  'calculation': calculation,
                  'locale': 'en',
                  'access': full ? 'full' : 'preview',
                  'summary': 'Your personal chart summary',
                  'preview_state': failed
                      ? 'failed'
                      : ready
                      ? 'ready'
                      : 'running',
                  'full_state': full
                      ? (failed
                            ? 'failed'
                            : ready
                            ? 'ready'
                            : 'running')
                      : 'locked',
                  'failure_reason': failed ? 'service_busy' : null,
                  'generation_progress': {
                    'percent': ready || failed ? 100 : 40,
                    'stage': failed
                        ? 'failed'
                        : ready
                        ? 'complete'
                        : 'writing',
                    'completed_topics': ready
                        ? [
                            'personality',
                            'career',
                            'money',
                            'relationships',
                            'watch',
                            'actions',
                          ]
                        : ['personality'],
                    'total_topics': 6,
                  },
                  'preview': ready ? sections.take(1).toList() : [],
                  'sections': ready && full ? sections.skip(1).toList() : [],
                };
              } else {
                fail('Unexpected request: ${request.method} $path');
              }
              return http.Response(
                status == 204 ? '' : jsonEncode(response),
                status,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }),
          ),
        );
        await d.session.profiles.save(
          'g1',
          BirthProfile(
            date: '1992-04-15',
            time: estimated ? null : '07:15',
            timezone: 'Asia/Bangkok',
            place: 'Bangkok',
            id: 'p1',
            revision: 1,
          ),
          serverContractReady: false,
        );
        await d.session.initialize();
        await d.chart.calculate();
        await tester.pumpWidget(
          DependencyScope(
            dependencies: d,
            child: FateApp(dependencies: d),
          ),
        );
        await tester.pumpAndSettle();
        final s = AppLocalizationsEn();
        await tester.tap(find.byKey(const ValueKey('app-nav/chart')));
        await tester.pumpAndSettle();
        final read = find.widgetWithText(FilledButton, s.chartRead);
        await tester.ensureVisible(read);
        await tester.tap(read);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byKey(const ValueKey('reading-back')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('app-bottom-navigation')),
          findsNothing,
        );
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(creates, 0);
        if (!full) {
          await tester.tap(find.text(s.decline));
          await tester.pumpAndSettle();
          expect(creates, 0);
          final generate = find.widgetWithText(FilledButton, s.generate);
          await tester.ensureVisible(generate);
          await tester.tap(generate);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        }
        await tester.tap(find.text(s.consentGenerate));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(creates, 1);
        expect(d.auth.signedIn, isFalse);
        expect(find.byKey(const ValueKey('reading-progress')), findsOneWidget);
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byKey(const ValueKey('reading-progress-bar')),
              )
              .value,
          .4,
        );
        expect(find.text(s.progressTopics(1, 6)), findsOneWidget);
        expect(find.text('personality personal interpretation'), findsNothing);
        expect(find.byKey(const ValueKey('unlock-report')), findsNothing);

        if (fails) {
          failed = true;
          await tester.pump(const Duration(seconds: 4));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('reading-progress')),
            findsOneWidget,
          );
          expect(find.text(s.reportServiceBusy), findsOneWidget);
          expect(
            tester
                .widget<LinearProgressIndicator>(
                  find.byKey(const ValueKey('reading-progress-bar')),
                )
                .value,
            .99,
          );
          expect(find.text('Your personal chart summary'), findsNothing);
          final returnButton = find.widgetWithText(
            FilledButton,
            s.progressReturn,
          );
          await tester.ensureVisible(returnButton);
          await tester.tap(returnButton);
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('reading-progress')), findsNothing);
          expect(find.text(s.reportServiceBusy), findsOneWidget);
          expect(find.widgetWithText(FilledButton, s.generate), findsOneWidget);
          expect(creates, 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          d.dispose();
          return;
        }
        if (full && !estimated) {
          final later = find.text(s.progressLater);
          await tester.ensureVisible(later);
          await tester.tap(later);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('app-bottom-navigation')),
            findsOneWidget,
          );
          await tester.tap(find.byKey(const ValueKey('app-nav/reports')));
          await tester.pumpAndSettle();
          expect(find.text(s.reportRecords), findsOneWidget);
          expect(find.text(number), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('open-report-r1')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('reading-progress')),
            findsOneWidget,
          );
          expect(find.text(s.progressTopics(1, 6)), findsOneWidget);
          expect(creates, 1);
          await tester.ensureVisible(later);
          await tester.tap(later);
          await tester.pumpAndSettle();
          expect(find.text(s.reportRecords), findsOneWidget);
          expect(
            find.byKey(const ValueKey('app-bottom-navigation')),
            findsOneWidget,
          );
          await tester.tap(find.byKey(const ValueKey('open-report-r1')));
          await tester.pumpAndSettle();
          transientPollFailure = true;
          await tester.pump(const Duration(seconds: 3));
          await tester.pumpAndSettle();
          expect(find.text(s.progressDisconnected), findsOneWidget);
          expect(
            find.byKey(const ValueKey('reading-progress')),
            findsOneWidget,
          );
        }

        ready = true;
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('reading-progress')), findsNothing);
        expect(find.byKey(const ValueKey('reading-chart')), findsOneWidget);
        expect(
          find.text(s.estimatedChart),
          estimated ? findsOneWidget : findsNothing,
        );
        expect(
          tester.widget<ChartWheel>(find.byType(ChartWheel)).result.id,
          calculation['result_id'],
        );
        expect(find.text('Your personal chart summary'), findsOneWidget);
        expect(
          find.text('personality personal interpretation'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('unlock-report')),
          full ? findsNothing : findsOneWidget,
        );
        expect(
          find.text('actions personal interpretation'),
          full ? findsOneWidget : findsNothing,
        );
        if (full) {
          final jump = find.byKey(const ValueKey('reading-jump-actions'));
          await tester.ensureVisible(jump);
          await tester.tap(jump);
          await tester.pumpAndSettle();
          final actionText = find.text('actions personal interpretation');
          expect(tester.getTopLeft(actionText).dy, inExclusiveRange(56, 720));
        }
        final back = find.byKey(const ValueKey('reading-back'));
        await tester.ensureVisible(back);
        await tester.tap(back);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('app-bottom-navigation')),
          findsOneWidget,
        );
        if (full && !estimated) {
          expect(find.text(s.reportRecords), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('app-nav/chart')));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(read);
        await tester.tap(read);
        await tester.pumpAndSettle();
        expect(creates, 1);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Your personal chart summary'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('chart-reading-history')));
        await tester.pumpAndSettle();
        expect(find.text(s.reportRecords), findsOneWidget);
        expect(find.text(number), findsOneWidget);
        expect(
          find.byKey(const ValueKey('app-bottom-navigation')),
          findsNothing,
        );
        final historyItem = find.widgetWithText(ListTile, s.reportTitle);
        await tester.ensureVisible(historyItem);
        await tester.tap(find.byKey(const ValueKey('open-report-r1')));
        await tester.pumpAndSettle();
        expect(find.text('Your personal chart summary'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('app-bottom-navigation')),
          findsNothing,
        );
        expect(creates, 1);
        await tester.tap(back);
        await tester.pumpAndSettle();
        await tester.tap(back);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('app-nav/reports')));
        await tester.pumpAndSettle();
        expect(find.text(s.reportRecords), findsOneWidget);
        expect(find.text(number), findsOneWidget);
        expect(find.text('Your personal chart summary'), findsNothing);
        expect(find.widgetWithText(ListTile, s.reportTitle), findsOneWidget);
        expect(find.widgetWithText(FilledButton, s.generate), findsNothing);
        expect(
          find.byKey(const ValueKey('app-bottom-navigation')),
          findsOneWidget,
        );
        final search = find.byKey(const ValueKey('report-number-search'));
        await tester.enterText(search, 'missing');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(find.text(s.noMatchingReports), findsOneWidget);
        await tester.enterText(search, 'a1b2');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(find.text(number), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('open-report-r1')));
        await tester.pumpAndSettle();
        expect(find.text('Your personal chart summary'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('app-bottom-navigation')),
          findsNothing,
        );
        await tester.tap(back);
        await tester.pumpAndSettle();
        expect(find.text(s.reportRecords), findsOneWidget);
        expect(
          find.byKey(const ValueKey('app-bottom-navigation')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('open-report-r1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('chart-reading-history')));
        await tester.pumpAndSettle();
        expect(find.text(s.reportRecords), findsOneWidget);
        expect(
          find.byKey(const ValueKey('app-bottom-navigation')),
          findsOneWidget,
        );
        expect(creates, 1);
        await tester.tap(find.byKey(const ValueKey('app-nav/profile')));
        await tester.pumpAndSettle();
        final profileReports = find.byKey(
          const ValueKey('profile-reading-history'),
        );
        await tester.ensureVisible(profileReports);
        await tester.tap(profileReports);
        await tester.pumpAndSettle();
        await tester.enterText(search, 'missing');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(find.text(s.noMatchingReports), findsOneWidget);
        await tester.enterText(search, 'a1b2');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(find.text(number), findsOneWidget);
        final delete = find.byKey(const ValueKey('delete-report-r1'));
        await tester.tap(delete);
        await tester.pumpAndSettle();
        await tester.tap(find.text(s.cancel));
        await tester.pumpAndSettle();
        expect(deletes, 0);
        expect(find.text(number), findsOneWidget);
        await tester.tap(delete);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('confirm-delete-report')));
        await tester.pumpAndSettle();
        expect(deletes, 1);
        expect(find.byKey(const ValueKey('report-record-r1')), findsNothing);
        expect(d.reports.reference, isNull);
        expect(d.reports.repository.active(d.session.owner), isNull);
        await tester.tap(back);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('profile-reading-history')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        d.dispose();
      },
    );
  }
}
