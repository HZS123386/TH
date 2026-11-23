import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:go_router/go_router.dart';
import 'package:fate_h5/app/controller.dart';
import 'package:fate_h5/app/h5_app.dart';
import 'package:fate_h5/core/models.dart';
import 'package:fate_h5/core/repository.dart';
import 'package:fate_h5/features/birth_date_dialog.dart';
import 'package:fate_h5/features/generation_dialog.dart';
import 'package:fate_h5/features/generation_video.dart';
import 'package:fate_h5/features/landing_page.dart';
import 'package:fate_h5/features/report_view_model.dart';
import 'package:fate_h5/features/place_picker.dart';
import 'package:fate_h5/features/checkout_dialog.dart';

import 'support.dart';

http.Response response(dynamic value) => http.Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
const province = {
  'id': 'geonames:1609348',
  'countryCode': 'TH',
  'nameEnglish': 'Bangkok',
  'nameChinese': '曼谷',
  'nameThai': 'กรุงเทพมหานคร',
  'timeZone': 'Asia/Bangkok',
  'placeType': 'province',
  'latitude': 13.75398,
  'longitude': 100.50144,
};

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(
    tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
  );
}

Future<void> click(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final language in ['zh', 'th']) {
    testWidgets('$language history retries list and sign-in code timeouts', (
      tester,
    ) async {
      phone(tester);
      final report = fixture(language: language);
      final browser = TestBrowser();
      final slowList = Completer<http.Response>();
      final slowCode = Completer<http.Response>();
      var listRequests = 0, codeRequests = 0;
      final repo = ReportRepository(
        browser,
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          if (request.url.path == '/api/life-reports') {
            expect(request.method, 'GET');
            listRequests++;
            if (listRequests == 1) return slowList.future;
            return response({
              'items': [report],
            });
          }
          if (request.url.path ==
              "/api/life-reports/${report['id']}/app-login-code") {
            expect(request.headers['X-Report-Key'], browser.key);
            codeRequests++;
            if (codeRequests == 1) return slowCode.future;
            return response({'code': 'A2B3C4', 'expires_in': 600});
          }
          return response({'notice_version': H5Controller.noticeVersion});
        }),
      );
      final h5 = H5Controller(translations(), repo, browser, language: language)
        ..enterLanding();
      await tester.pumpWidget(
        H5App(controller: h5, initialLocation: '/?lang=$language'),
      );
      await tester.pumpAndSettle();
      String label(String key) => h5.copy.t('jy', key);

      final history = find.text(label('history'));
      await tester.ensureVisible(history);
      await tester.tap(history);
      await tester.pump();
      final retryList = find.text(h5.copy.t('generation', 'retry'));
      await tester.pump(const Duration(seconds: 9));
      expect(listRequests, 1);
      expect(retryList, findsNothing);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(retryList, findsOneWidget);
      expect(codeRequests, 0);
      await click(tester, retryList);
      slowList.complete(response({'items': []}));
      await tester.pumpAndSettle();
      expect(listRequests, 2);
      expect(find.text(label('openReport')), findsOneWidget);
      await click(tester, find.text(label('appLogin.get')));
      expect(find.text(label('appLogin.loading')), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text(label('appLogin.failed')), findsOneWidget);
      await click(tester, find.text(label('appLogin.refresh')));
      slowCode.complete(response({'code': 'D5E6F7', 'expires_in': 600}));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<SelectableText>(
              find.byKey(const ValueKey('h5-app-login-code')),
            )
            .data,
        'A2B3C4',
      );
      expect(codeRequests, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    });

    testWidgets(
      '$language refresh resumes the saved queue with no duplicate submission',
      (tester) async {
        phone(tester);
        final done = fixture(language: language);
        var current = {
          ...done,
          'preview': null,
          'preview_state': 'queued',
          'chart': null,
          'generation_queue': {'state': 'queued', 'position': 12},
        };
        final browser = TestBrowser()
          ..settings['session:active-preview'] = done['id'] as String;
        final requests = <String>[];
        var codeRequests = 0;
        final repo = ReportRepository(
          browser,
          baseUrl: 'https://example.test',
          client: MockClient((request) async {
            if (request.url.path ==
                "/api/life-reports/${done['id']}/app-login-code") {
              expect(request.method, 'POST');
              expect(request.headers['X-Report-Key'], browser.key);
              codeRequests++;
              return response({'code': 'A2B3C4', 'expires_in': 600});
            }
            if (request.url.path.startsWith('/api/life-reports')) {
              requests.add('${request.method} ${request.url.path}');
              return response(current);
            }
            return response({'notice_version': H5Controller.noticeVersion});
          }),
        );
        final h5 = H5Controller(
          translations(),
          repo,
          browser,
          language: language,
        )..enterLanding();
        await tester.pumpWidget(
          H5App(controller: h5, initialLocation: '/?lang=$language'),
        );
        await tester.pumpAndSettle();
        expect(find.byType(GenerationDialog), findsOneWidget);
        expect(
          find.text(h5.copy.t('jy', 'interpretation.queued')),
          findsOneWidget,
        );
        expect(find.byType(AppLoginCodePanel), findsNothing);
        expect(requests.every((request) => request.startsWith('GET ')), isTrue);
        tester
            .widget<GenerationDialog>(find.byType(GenerationDialog))
            .onCancel();
        await tester.pumpAndSettle();
        final queuedLabel = h5.copy.t('life', 'previewStates.queued');
        expect(queuedLabel, isNotEmpty);
        expect(find.text(queuedLabel), findsOneWidget);
        expect(find.text(h5.copy.t('life', 'viewProgress')), findsOneWidget);
        expect(find.byType(AppLoginCodePanel), findsOneWidget);
        current = done;
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('free-report-content')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('h5-app-login-code')), findsOneWidget);
        expect(codeRequests, 1);
        expect(requests.every((request) => request.startsWith('GET ')), isTrue);
        for (final width in [320.0, 360.0, 1100.0]) {
          tester.view.physicalSize = Size(width, 640);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$language report at width $width',
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        h5.dispose();
      },
    );

    testWidgets(
      '$language paid queue resumes the original report and keeps polling after leaving the animation',
      (tester) async {
        phone(tester);
        final done = fixture(language: language, full: true);
        var current = {
          ...done,
          'full_state': 'queued',
          'chapters': [],
          'plan': null,
          'progress': {
            'completed': 0,
            'total': object(done['progress'])['total'],
          },
        };
        final browser = TestBrowser();
        final methods = <String>[];
        var codeRequests = 0;
        final repo = ReportRepository(
          browser,
          baseUrl: 'https://example.test',
          client: MockClient((request) async {
            if (request.url.path ==
                "/api/life-reports/${done['id']}/app-login-code") {
              expect(request.method, 'POST');
              codeRequests++;
              return response({'code': 'A2B3C4', 'expires_in': 600});
            }
            if (request.url.path.startsWith('/api/life-reports')) {
              methods.add(request.method);
            }
            return response(current);
          }),
        );
        final h5 = H5Controller(
          translations(),
          repo,
          browser,
          language: language,
        );
        await tester.pumpWidget(
          H5App(
            controller: h5,
            initialLocation: '/report.html?id=${done['id']}&lang=$language',
          ),
        );
        await tester.pumpAndSettle();
        final label = h5.copy.t('life', 'states.queued');
        expect(label, isNotEmpty);
        expect(find.textContaining(label), findsWidgets);
        await click(tester, find.text(h5.copy.t('life', 'viewProgress')));
        expect(
          find.text(h5.copy.t('jy', 'interpretation.queued')),
          findsOneWidget,
        );
        tester
            .widget<GenerationDialog>(find.byType(GenerationDialog))
            .onCancel();
        await tester.pumpAndSettle();
        current = done;
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(find.textContaining(label), findsNothing);
        expect(find.text(h5.copy.t('life', 'viewProgress')), findsNothing);
        expect(methods.length, greaterThan(1));
        expect(methods.every((method) => method == 'GET'), isTrue);
        expect(find.byType(AppLoginCodePanel), findsOneWidget);
        expect(codeRequests, 1);
        for (final width in [320.0, 1100.0]) {
          tester.view.physicalSize = Size(width, 640);
          await tester.pumpAndSettle();
        }
        await tester.pumpWidget(const SizedBox.shrink());
        h5.dispose();
      },
    );
  }

  for (final variant in ['zh', 'th', 'en', 'zh-legacy', 'zh-unknown']) {
    final language = variant.split('-').first;
    final legacy = variant == 'zh-legacy';
    final unknown = variant == 'zh-unknown';
    testWidgets(
      'three-paragraph preview keeps free answers and evidence without a checkout in $variant',
      (tester) async {
        phone(tester);
        final browser = TestBrowser();
        final data = fixture();
        final input = object(data['input']);
        data['format'] = 'western-compact';
        data['input'] = {
          ...input,
          'profile': {
            ...object(input['profile']),
            'language': language,
            if (unknown) 'birth_time': null,
          },
        };
        if (unknown) {
          data.remove('chart');
          data['time_accuracy'] = {
            'mode': 'estimated',
            'assumed_local_time': '12:00',
          };
        }
        data['catalog'] = [
          for (final item in objects(data['catalog']).take(5).indexed)
            {...item.$2, 'key': westernKeys[item.$1]},
        ];
        data['progress'] = {'completed': 0, 'total': 6};
        data['price'] = {
          'amount': 3000,
          'currency': 'THB',
          'display': '฿30',
          'mode': 'sunlands_order_only',
        };
        data['outlook'] = {
          'state': 'ready',
          'start': '2026-11-16',
          'end': '2027-02-13',
          'timezone': 'UTC',
        };
        final summary = object(object(data['preview'])['summary']);
        if (legacy) {
          summary['text'] =
              '你的内心节奏偏向沉稳，习惯在行动前确认环境的舒适度与可行性。'
              '这种对质感的重视让你在处理日常事务时显得从容，但也容易因过度斟酌而放慢脚步。';
        }
        const legacyTraits = [
          '你往往被具体、可触摸的美好事物吸引，无论是美食还是整洁的空间，都能迅速为你补充精力。'
              '这种对生活质感的敏锐度让你在平凡日子里也能找到满足感，不易被外界的喧嚣带走注意力。',
          '面对选择时，你倾向于反复权衡利弊，直到找到一个既安全又具实际价值的方案才肯放手去做。'
              '这种谨慎能帮你避开许多不必要的风险，但有时也会因为害怕出错而陷入犹豫。',
          '在人际交往中，你渴望一种温和且充满感官愉悦的连接方式，喜欢通过分享好物或共同享受闲暇来拉近距离。'
              '当对话变得过于尖锐或匆忙时，你可能会感到不适并选择退后一步观察。',
        ];
        data['preview'] = {
          ...object(data['preview']),
          'summary': summary,
          'traits': [
            for (final item in objects(
              object(data['preview'])['traits'],
            ).indexed)
              {
                ...item.$2,
                'text': legacy
                    ? legacyTraits[item.$1]
                    : 'Synthetic identity detail ${item.$1 + 1}.\nContinued.',
                'evidence': [
                  ...objects(summary['evidence']),
                  {
                    'id': 'identity-${item.$1}',
                    'title': 'Identity factor ${item.$1 + 1}',
                    'detail': 'Supporting detail ${item.$1 + 1}',
                  },
                ],
              },
          ],
          'environment': {...summary, 'text': 'Synthetic environment answer'},
          'favorable': {...summary, 'text': 'Synthetic helpful factor'},
          'unfavorable': {...summary, 'text': 'Synthetic manageable pressure'},
          'response': {...summary, 'text': 'One free career response'},
          'sample_topic': 'career',
          'recent': {
            ...summary,
            'text': 'Synthetic near-term theme',
            'window': {
              'start': '2026-11-23',
              'end': '2026-11-29',
              'event_date': '2026-11-24',
              'timezone': 'UTC',
            },
          },
        };
        data['chapters'] = fixture(full: true)['chapters'];
        if (legacy) {
          for (final key in [
            'environment',
            'favorable',
            'unfavorable',
            'recent',
            'response',
          ]) {
            (data['preview'] as Json).remove(key);
          }
          data.remove('outlook');
        }
        data['plan'] = fixture(full: true)['plan'];
        final calls = <String>[];
        final h5 = H5Controller(
          translations(),
          ReportRepository(
            browser,
            client: MockClient((request) async {
              calls.add('${request.method} ${request.url.path}');
              if (request.url.path.endsWith('/payment')) {
                return http.Response('', 204);
              }
              return response(data);
            }),
          ),
          browser,
          language: language,
        );
        await tester.pumpWidget(
          H5App(
            controller: h5,
            initialLocation:
                '/report.html?id=${data['id']}&lang=$language&checkout=1',
          ),
        );
        await tester.pumpAndSettle();
        for (final key in ['who', 'environment', 'influence', 'timing']) {
          expect(
            find.text(h5.copy.t('jy', 'report.questions.$key')),
            findsNothing,
          );
        }
        for (final key in ['identity', 'environment', 'recent']) {
          if (key == 'recent' && (legacy || unknown)) {
            expect(
              find.byKey(ValueKey('preview-paragraph-$key')),
              findsNothing,
            );
            expect(
              find.byKey(const ValueKey('preview-timing-unavailable')),
              findsOneWidget,
            );
            continue;
          }
          expect(
            find.byKey(ValueKey('preview-paragraph-$key')),
            findsOneWidget,
          );
          expect(
            find.text(h5.copy.t('jy', 'report.previewParagraphs.$key')),
            findsOneWidget,
          );
        }
        final identity = find.byKey(
          const ValueKey('preview-paragraph-identity'),
        );
        final identityText = [
          text(summary['text']),
          for (var i = 1; i <= 3; i++)
            legacy
                ? legacyTraits[i - 1]
                : 'Synthetic identity detail $i. Continued.',
        ].join(language == 'zh' ? '' : ' ');
        expect(
          find.descendant(of: identity, matching: find.text(identityText)),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('identity-details')), findsNothing);
        for (final trait in objects(object(data['preview'])['traits'])) {
          expect(find.text(text(trait['title'])), findsNothing);
        }
        final identityEvidence = find.descendant(
          of: identity,
          matching: find.byType(ExpansionTile),
        );
        expect(identityEvidence, findsOneWidget);
        await click(tester, identityEvidence);
        for (final item in objects(summary['evidence'])) {
          expect(
            find.descendant(
              of: identity,
              matching: find.text(text(item['title'])),
            ),
            findsOneWidget,
          );
        }
        for (var i = 1; i <= 3; i++) {
          expect(
            find.descendant(
              of: identity,
              matching: find.text('Identity factor $i'),
            ),
            findsOneWidget,
          );
        }
        await click(tester, identityEvidence);
        expect(
          find.byKey(const ValueKey('checkout-theme-badges')),
          findsOneWidget,
        );
        if (legacy) {
          expect(
            find.textContaining(
              h5.copy.t('jy', 'report.previewParagraphs.legacyEnvironment'),
            ),
            findsOneWidget,
          );
          expect(
            find.textContaining(
              h5.copy.t('jy', 'report.previewParagraphs.legacyRecent'),
            ),
            findsOneWidget,
          );
        } else {
          expect(
            find.textContaining('Synthetic environment answer'),
            findsOneWidget,
          );
          expect(
            find.textContaining('Synthetic helpful factor'),
            findsOneWidget,
          );
          expect(
            find.textContaining('Synthetic manageable pressure'),
            findsOneWidget,
          );
          expect(
            find.textContaining('One free career response'),
            unknown ? findsNothing : findsOneWidget,
          );
          expect(
            find.textContaining('Synthetic near-term theme'),
            unknown ? findsNothing : findsOneWidget,
          );
          if (unknown) {
            expect(
              find.textContaining(
                h5.copy.t('jy', 'report.questions.timeUnknown'),
              ),
              findsOneWidget,
            );
            expect(
              find.textContaining(
                h5.copy.t('jy', 'report.questions.timingNote'),
              ),
              findsNothing,
            );
          }
        }
        expect(
          find.textContaining('2026-11-23 – 2026-11-29'),
          legacy || unknown ? findsNothing : findsOneWidget,
        );
        expect(find.textContaining('付费专属分析正文'), findsNothing);
        expect(find.byKey(const ValueKey('jy-payment-preview')), findsNothing);
        expect(
          calls.where(
            (call) =>
                call.startsWith('POST ') &&
                (call.endsWith('/unlock') || call.endsWith('/payment')),
          ),
          isEmpty,
        );
        expect(find.byType(GenerationDialog), findsNothing);
        expect(find.byType(ReportCheckout), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        h5.dispose();
      },
    );
  }

  for (final full in [false, true]) {
    testWidgets(
      '${full ? 'full' : 'free'} report back button restores birth details for the active country',
      (tester) async {
        phone(tester);
        final language = full ? 'th' : 'zh';
        final browser = TestBrowser();
        final data = fixture(language: language, full: full);
        final input = object(data['input']);
        data['input'] = {
          ...input,
          'profile': {
            ...object(input['profile']),
            if (full) 'birth_time': null,
            if (full) 'location_id': province['id'],
          },
          if (full)
            'career_question': {'stage': 'searching', 'start': '2026-11-13'},
          if (!full) 'user_question': '我想调整工作方向',
        };
        if (full) {
          data['location'] = province;
          data['time_accuracy'] = {
            'mode': 'estimated',
            'assumed_local_time': '12:00',
          };
          final chart = object(data['chart']);
          data['chart'] = {
            ...chart,
            'precision': 'estimated',
            'houses': [],
            'aspects': [],
            'planets': [
              for (final p in objects(chart['planets']))
                if (p['id'] != 'ascendant') {...p, 'house': null},
            ],
          };
        }
        var posts = 0;
        final repo = ReportRepository(
          browser,
          baseUrl: 'https://example.test',
          client: MockClient((request) async {
            if (request.method == 'POST') posts++;
            if (request.url.path == '/api/thai-locations') {
              return response({
                'items': [province],
                'total': 1,
              });
            }
            return response(data);
          }),
        );
        // A direct report entry has no surviving home widget or form state.
        final h5 = H5Controller(
          translations(),
          repo,
          browser,
          language: language,
        );
        await tester.pumpWidget(
          H5App(
            controller: h5,
            initialLocation: '/report.html?id=${data['id']}&lang=$language',
          ),
        );
        await tester.pumpAndSettle();
        final back = find.byKey(const ValueKey('report-back-home'));
        expect(back, findsOneWidget);
        expect(tester.getTopLeft(back).dx, lessThan(50));
        await click(tester, back);
        expect(find.byType(LandingPage), findsOneWidget);
        expect(h5.welcomeOpen, isFalse);
        expect(
          GoRouter.of(
            tester.element(find.byType(LandingPage)),
          ).routeInformationProvider.value.uri.toString(),
          '/?lang=$language',
        );
        String field(String key) => tester
            .widget<TextFormField>(find.byKey(ValueKey(key)))
            .controller!
            .text;
        final date = tester.widget<TextFormField>(
          find.descendant(
            of: find.byKey(const ValueKey('birth-date')),
            matching: find.byType(TextFormField),
          ),
        );
        expect(date.initialValue, birthDateLabel('1995-08-17', language));
        final time = tester.widget<TextFormField>(
          find.descendant(
            of: find.byKey(const ValueKey('birth-time')),
            matching: find.byType(TextFormField),
          ),
        );
        expect(time.initialValue, full ? '' : '09:30');
        expect(time.enabled, !full);
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, full);
        expect(find.byKey(const ValueKey('birth-country')), findsNothing);
        expect(find.byKey(const ValueKey('birth-province')), findsNothing);
        expect(field('birth-city'), full ? 'กรุงเทพมหานคร' : isEmpty);
        if (full) {
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('question-2')),
              matching: find.text(h5.copy.t('jy', 'selected')),
            ),
            findsOneWidget,
          );
        } else {
          expect(find.byKey(const ValueKey('custom-question')), findsNothing);
        }
        expect(posts, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        h5.dispose();
      },
    );
  }

  for (final kind in ['city', 'slim', 'coordinates', 'offline']) {
    testWidgets(
      '$kind location restores usable data for editing and resubmission',
      (tester) async {
        phone(tester);
        final browser = TestBrowser();
        final data = fixture(language: 'th');
        final city = {
          ...object(data['location']),
          'nameThai': 'กรุงเทพฯ',
          'placeType': 'city',
          'coordinateKind': 'administrative-area',
        };
        final input = object(data['input']);
        final profile = {
          ...object(input['profile']),
          'location_id': kind == 'coordinates' ? null : city['id'],
          'latitude': city['latitude'],
          'longitude': city['longitude'],
        };
        data['input'] = {...input, 'profile': profile};
        data['location'] = kind == 'city'
            ? city
            : {
                'latitude': city['latitude'],
                'longitude': city['longitude'],
                'timeZone': profile['timezone'],
                'nameEnglish': profile['birthplace'],
                'country': profile['country_code'],
              };
        var detailRequests = 0, cityListings = 0;
        Json? submitted;
        final repo = ReportRepository(
          browser,
          baseUrl: 'https://example.test',
          client: MockClient((request) async {
            if (request.url.path == '/api/landing/config') {
              return response({'notice_version': H5Controller.noticeVersion});
            }
            if (request.url.path == '/api/landing/consents') {
              return response({
                'accepted': true,
                'notice_version': H5Controller.noticeVersion,
              });
            }
            if (request.url.path == '/api/thai-locations') {
              final query = request.url.queryParameters;
              expect(query['country'], 'TH');
              if (query['level'] == 'detail') {
                detailRequests++;
                expect(query['query'], profile['location_id']);
                if (kind == 'offline') return http.Response('{}', 503);
                return response({
                  'resolved': city,
                  'items': [city],
                  'total': 1,
                });
              }
              expect(query['level'], 'locality');
              expect(query.containsKey('province'), isFalse);
              cityListings++;
              return response({
                'items': [city],
                'total': 1,
              });
            }
            if (request.method == 'POST' &&
                request.url.path == '/api/life-reports') {
              submitted = object(jsonDecode(request.body));
            }
            return response(
              submitted == null ? data : marriageFixture(input: submitted),
            );
          }),
        );
        final h5 = H5Controller(translations(), repo, browser, language: 'th');
        await tester.pumpWidget(
          H5App(
            controller: h5,
            initialLocation: '/report.html?id=${data['id']}&lang=th',
          ),
        );
        await tester.pumpAndSettle();
        await click(tester, find.byKey(const ValueKey('report-back-home')));
        String field(String key) => tester
            .widget<TextFormField>(find.byKey(ValueKey(key)))
            .controller!
            .text;
        if (kind == 'city' || kind == 'slim') {
          expect(field('birth-city'), city['nameThai']);
          await click(tester, find.byKey(const ValueKey('birth-city')));
          expect(cityListings, 1);
          await click(
            tester,
            find.descendant(
              of: find.byType(PlacePicker),
              matching: find.text(text(city['nameThai'])),
            ),
          );
        } else {
          expect(field('birth-city'), profile['birthplace']);
        }
        expect(detailRequests, kind == 'slim' || kind == 'offline' ? 1 : 0);
        expect(submitted, isNull);
        await click(tester, find.byKey(const ValueKey('generate-report')));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
        final sent = object(submitted?['profile']);
        for (final key in [
          'birth_date',
          'birth_time',
          'birthplace',
          'timezone',
          'country_code',
          'location_id',
          'latitude',
          'longitude',
        ]) {
          expect(sent[key], profile[key], reason: '$kind.$key');
        }
        expect(find.byType(ReportCheckout), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        h5.dispose();
      },
    );
  }

  testWidgets(
    'LINE delivery opens the QR dialog and copies the five-digit claim code',
    (tester) async {
      phone(tester);
      final browser = TestBrowser();
      final paid = fixture(full: true);
      final data = {
        ...fixture(),
        'claim_code': '57248',
        'payment_simulation': false,
        'price': {
          'amount': 3000,
          'currency': 'THB',
          'display': '฿30',
          'mode': 'sunlands_order_only',
        },
        'chapters': paid['chapters'],
        'plan': paid['plan'],
      };
      final calls = <String>[];
      final repo = ReportRepository(
        browser,
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          return response(data);
        }),
      );
      final h5 = H5Controller(translations(), repo, browser, language: 'zh');
      await tester.pumpWidget(
        H5App(
          controller: h5,
          initialLocation: '/report.html?id=${data['id']}&lang=zh&checkout=1',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('free-report-content')), findsOneWidget);
      expect(browser.activities.last, {
        'page': 'preview_report',
        'action': 'report_ready',
      });
      final paidText = text(
        object(objects(paid['chapters']).first['summary'])['text'],
      );
      expect(find.text(paidText), findsNothing);
      final appButton = find.byKey(const ValueKey('jy-app-download'));
      expect(appButton, findsNothing);
      expect(find.byKey(const ValueKey('jy-payment-preview')), findsNothing);
      final contact = find.byKey(const ValueKey('jy-line-contact'));
      expect(find.text('57248'), findsOneWidget);
      final messenger = tester.binding.defaultBinaryMessenger;
      String? copied;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await click(
        tester,
        find.widgetWithText(
          TextButton,
          h5.copy.t('jy', 'lineContact.copyReportId'),
        ),
      );
      expect(copied, '57248');
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/images/line-contact-qr.jpg'),
          tester.element(contact),
        );
      });
      await click(tester, contact);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('57248'),
        ),
        findsOneWidget,
      );
      expect(
        browser.activities.where((event) => event['action'] == 'line_qr_shown'),
        hasLength(1),
      );
      await click(tester, find.text(h5.copy.t('jy', 'lineContact.open')));
      expect(browser.openedPages, ['https://line.me/ti/p/TrGGcMWmuV']);
      await click(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, h5.copy.t('jy', 'close')),
        ),
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        calls.where(
          (call) => call.contains('/payment') || call.endsWith('/unlock'),
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );

  testWidgets(
    'paid generation keeps the same visible wheel across stages until the report is ready',
    (tester) async {
      phone(tester);
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: false);
      final browser = TestBrowser();
      final h5 = H5Controller(
        translations(),
        ReportRepository(browser),
        browser,
        language: 'zh',
      );
      final report = LifeReport.parse(fixture());
      final state = GenerationState()..update(report, 0, 'preview');
      var completed = 0, cancelled = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: GenerationDialog(
            h5: h5,
            state: state,
            full: true,
            onCancel: () => cancelled++,
            onRetry: state.retry,
            onComplete: (_) => completed++,
          ),
        ),
      );
      final wheel = find.byType(GenerationVideo);
      final wheelElement = tester.element(wheel);
      expect(tester.widget<GenerationVideo>(wheel).active, isTrue);
      expect(tester.getTopLeft(wheel).dy, greaterThanOrEqualTo(320));
      expect(find.text('准备中'), findsOneWidget);
      expect(find.text('0%'), findsNothing);
      state.update(report, 19, 'preview');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('19%'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2100));
      await tester.pump(const Duration(milliseconds: 2600));
      state.update(report, 99, 'preview');
      await tester.pump(const Duration(seconds: 12));
      expect(tester.element(wheel), same(wheelElement));
      expect(tester.widget<GenerationVideo>(wheel).active, isTrue);
      expect(completed, 0);
      expect(find.text('正在校验并保存解读内容'), findsOneWidget);
      expect(find.byType(AppLoginCodePanel), findsNothing);
      state.fail('连接中断');
      await tester.pump();
      expect(find.text('本次生成暂未完成，请重试'), findsOneWidget);
      expect(find.byType(AppLoginCodePanel), findsNothing);
      expect(tester.widget<GenerationVideo>(wheel).active, isFalse);
      final retry = find.widgetWithText(
        OutlinedButton,
        h5.copy.t('jy', 'interpretation.retryFull'),
      );
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pump();
      expect(tester.widget<GenerationVideo>(wheel).active, isTrue);
      await tester.tap(find.widgetWithText(TextButton, '取消等待'));
      expect(cancelled, 1);
      state.ready(report);
      await tester.pump();
      expect(find.text('100%'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 319));
      expect(completed, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(completed, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
      h5.dispose();
    },
  );

  testWidgets(
    'failed marriage generation offers retry without draft progress',
    (tester) async {
      phone(tester);
      final browser = TestBrowser();
      final h5 = H5Controller(
        translations(),
        ReportRepository(browser),
        browser,
        language: 'zh',
      );
      final report = LifeReport.parse(
        marriageFixture()
          ..['access'] = 'full'
          ..['full_state'] = 'unavailable',
      );
      const savedDraftHint = '这次生成未完成，已完成的章节已保留，可以继续生成。';
      final state = GenerationState()
        ..update(report, 95, 'full')
        ..fail(savedDraftHint);
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: GenerationDialog(
            h5: h5,
            state: state,
            full: true,
            onCancel: () {},
            onRetry: () => retries++,
            onComplete: (_) {},
          ),
        ),
      );
      expect(
        find.text(h5.copy.t('jy', 'interpretation.interrupted')),
        findsOneWidget,
      );
      expect(find.text(savedDraftHint), findsNothing);
      expect(find.byType(ReadingProgress), findsNothing);
      await click(
        tester,
        find.text(h5.copy.t('jy', 'interpretation.retryFull')),
      );
      expect(retries, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
      h5.dispose();
    },
  );

  for (final (wait, full) in [
    (Duration.zero, false),
    (const Duration(seconds: 20), false),
    (Duration.zero, true),
  ]) {
    testWidgets(
      'readable report opens without waiting for the wheel: $wait, full=$full',
      (tester) async {
        phone(tester);
        tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: false);
        final browser = TestBrowser();
        final h5 = H5Controller(
          translations(),
          ReportRepository(browser),
          browser,
          language: 'zh',
        );
        final report = LifeReport.parse(fixture());
        final state = GenerationState()..update(report, 99, 'preview');
        var completed = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: GenerationDialog(
              h5: h5,
              state: state,
              full: full,
              onCancel: () {},
              onRetry: () {},
              onComplete: (_) => completed++,
            ),
          ),
        );
        await tester.pump(wait);
        expect(completed, 0);
        state.ready(report);
        await tester.pump(Duration(milliseconds: full ? 320 : 16));
        expect(completed, 1);
        expect(
          tester.widget<GenerationVideo>(find.byType(GenerationVideo)).active,
          isTrue,
        );
        await tester.pump(const Duration(seconds: 10));
        expect(completed, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        state.dispose();
        h5.dispose();
      },
    );
  }

  testWidgets(
    'Thai birth picker fits a small phone and language switching preserves the entry URL',
    (tester) async {
      phone(tester);
      final browser = TestBrowser();
      final h5 = H5Controller(
        translations(),
        ReportRepository(browser),
        browser,
      );
      h5.enterLanding();
      await tester.pumpWidget(
        H5App(
          controller: h5,
          initialLocation: '/?lang=th&topic=love&startup=1',
        ),
      );
      await tester.pumpAndSettle();
      await click(tester, find.byKey(const ValueKey('birth-date')));
      expect(find.byType(BirthDateDialog), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'ยืนยัน'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await click(tester, find.widgetWithText(FilledButton, 'ยืนยัน'));
      await click(tester, find.byKey(const ValueKey('language-menu')));
      await click(tester, find.byKey(const ValueKey('language-option-zh')));
      final route = GoRouter.of(
        tester.element(find.byType(LandingPage)),
      ).routeInformationProvider.value.uri;
      expect(route.queryParameters, containsPair('lang', 'zh'));
      expect(route.queryParameters, containsPair('topic', 'love'));
      expect(route.queryParameters, containsPair('startup', '1'));
      expect(find.text(h5.copy.t('jy', 'formTitle')), findsOneWidget);
      expect(find.text(h5.copy.t('jy', 'formCaption')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );

  testWidgets(
    'birth details alone start a free marriage report with one click',
    (tester) async {
      phone(tester);
      const city = {
        'id': 'geonames:1816670',
        'countryCode': 'CN',
        'nameEnglish': 'Beijing',
        'nameChinese': '北京市',
        'timeZone': 'Asia/Shanghai',
        'placeType': 'city',
      };
      final browser = TestBrowser()..settings.remove('fate-data-use-version');
      Json? input;
      var current = fixture();
      final calls = <String>[];
      final repo = ReportRepository(
        browser,
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          if (request.url.path == '/api/thai-locations') {
            expect(request.url.queryParameters['country'], 'CN');
            expect(request.url.queryParameters['level'], 'locality');
            return response({
              'items': [city],
              'total': 1,
            });
          }
          if (request.method == 'POST' &&
              request.url.path == '/api/life-reports') {
            input = object(jsonDecode(request.body));
            current = marriageFixture(input: input);
          }
          return response(current);
        }),
      );
      final h5 = H5Controller(translations(), repo, browser, language: 'zh')
        ..enterLanding();
      await tester.pumpWidget(
        H5App(controller: h5, initialLocation: '/?lang=zh'),
      );
      await tester.pumpAndSettle();
      await click(tester, find.byKey(const ValueKey('birth-date')));
      await click(
        tester,
        find.widgetWithText(FilledButton, h5.copy.t('ui', 'confirm')),
      );
      await click(tester, find.byKey(const ValueKey('birth-time-unknown')));
      await click(tester, find.byKey(const ValueKey('birth-city')));
      await click(
        tester,
        find.descendant(
          of: find.byType(PlacePicker),
          matching: find.widgetWithText(InkWell, '北京市'),
        ),
      );
      expect(find.byKey(const ValueKey('data-use-notice')), findsNothing);
      for (final field in [
        'relationship-status',
        'custom-question',
        'relationship-roles',
        'relationship-event',
        'relationship-source',
      ]) {
        expect(find.byKey(ValueKey(field)), findsNothing);
      }
      expect(input, isNull);
      expect(calls, isNot(contains('POST /api/landing/consents')));
      expect(browser.viewReadingClicks, 0);
      await click(tester, find.byKey(const ValueKey('generate-report')));
      expect(browser.viewReadingClicks, 1);
      expect(find.text('确认使用出生资料'), findsNothing);
      expect(find.byKey(const ValueKey('data-use-agree')), findsNothing);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(input, isNotNull);
      expect(object(input!['profile'])['birth_time'], isNull);
      expect(object(input!['profile'])['birth_date'], '1999-01-01');
      expect(object(input!['profile'])['location_id'], city['id']);
      expect(object(input!['profile'])['country_code'], 'CN');
      expect(object(input!['profile'])['timezone'], 'Asia/Shanghai');
      expect(input!['report_kind'], 'marriage');
      expect(input!.containsKey('relationship'), isFalse);
      expect(input!.containsKey('user_question'), isFalse);
      expect(calls, contains('POST /api/life-reports'));
      expect(calls, isNot(contains('POST /api/landing/consents')));
      expect(calls.any((value) => value.endsWith('/unlock')), isFalse);
      expect(find.byType(GenerationDialog), findsNothing);
      expect(find.byType(ReportCheckout), findsOneWidget);
      expect(find.text('解锁后，深入查看六大主题'), findsOneWidget);
      final themeBadges = find.byKey(const ValueKey('checkout-theme-badges'));
      expect(themeBadges, findsOneWidget);
      final labels = ['本命解读', '事业**', '财运解读', '感情姻缘', '***预警', '行动建议'];
      final centers = [
        for (final title in labels)
          tester.getCenter(
            find.descendant(of: themeBadges, matching: find.text(title)),
          ),
      ];
      for (final row in [centers.take(3).toList(), centers.skip(3).toList()]) {
        expect(row[0].dy, closeTo(row[2].dy, 2));
        expect(row[0].dx, lessThan(row[1].dx));
        expect(row[1].dx, lessThan(row[2].dx));
      }
      expect(centers[0].dy, lessThan(centers[3].dy));
      expect(find.byKey(const ValueKey('jy-payment-preview')), findsNothing);
      expect(find.text('从出生时刻，揪出感情的搅局者'), findsOneWidget);
      for (final title in ['上升在感情里的真实样子', '当前感情能量', '领取完整报告']) {
        expect(find.text(title), findsOneWidget);
      }
      expect(find.text('感情模式快照'), findsNothing);
      expect(find.text('Free marriage section 3.'), findsOneWidget);
      expect(find.text('婚姻与长期关系完整解剖'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );

  testWidgets(
    'saved complete reports use JY sections and retain all original chapters, plan and PDF export',
    (tester) async {
      phone(tester);
      final browser = TestBrowser();
      final data = fixture(full: true);
      final repo = ReportRepository(
        browser,
        baseUrl: 'https://example.test',
        client: MockClient((_) async => response(data)),
      );
      final h5 = H5Controller(translations(), repo, browser, language: 'zh');
      await tester.pumpWidget(
        H5App(
          controller: h5,
          initialLocation: '/report.html?id=${data['id']}&lang=zh',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('你的专属星盘报告'), findsOneWidget);
      expect(find.byType(ReportCheckout), findsNothing);
      expect(find.textContaining('付费章节重点'), findsWidgets);
      for (final label in ['这对你意味着什么', '需要留意的地方', '你可以这样做']) {
        expect(find.text(label), findsNothing);
      }
      expect(find.text('先观察当前的习惯'), findsOneWidget);
      await click(tester, find.byTooltip(h5.copy.t('life', 'exportPdf')));
      expect(browser.exported!['access'], 'full');
      expect(objects(browser.exported!['chapters']), hasLength(7));
      expect(
        objects(object(browser.exported!['plan'])['phases']),
        hasLength(3),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );

  test(
    'saved free report waits for its language and body fonts before showing its contents',
    () async {
      final gate = Completer<void>();
      final bodyFonts = Completer<void>();
      final browser = TestBrowser();
      final repo = ReportRepository(
        browser,
        baseUrl: 'https://example.test',
        client: MockClient((_) async => response(fixture())),
      );
      final h5 = H5Controller(
        translations(),
        repo,
        browser,
        language: 'th',
        ensureFont: (_) => gate.future,
        ensureTextFont: (_, _) => bodyFonts.future,
      );
      final model = ReportViewModel(h5, fixture()['id']);
      final pending = model.load();
      await Future<void>.delayed(Duration.zero);
      expect(model.report, isNull);
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(model.report, isNull);
      bodyFonts.complete();
      await pending;
      expect(model.report!.language, 'zh');
      expect(h5.language, 'zh');
      model.dispose();
      h5.dispose();
    },
  );

  test(
    'latest language request wins and previously loaded copy is reused',
    () async {
      final gate = Completer<void>();
      final browser = TestBrowser();
      final repo = ReportRepository(browser);
      final initial = translations();
      final chineseCopy = <String, dynamic>{
        'jy': {'zh': object(initial['jy'])['zh']},
      };
      var loads = 0;
      final h5 = H5Controller(
        initial,
        repo,
        browser,
        loadTranslations: (_) async {
          loads++;
          return chineseCopy;
        },
        ensureFont: (lang) => lang == 'zh' ? gate.future : Future.value(),
      );
      final chinese = h5.changeLanguage('zh');
      await h5.changeLanguage('th');
      gate.complete();
      expect(await chinese, isFalse);
      expect(h5.language, 'th');
      expect(h5.translations, same(initial));
      expect(await h5.changeLanguage('zh'), isTrue);
      expect(h5.translations, same(chineseCopy));
      expect(loads, 1);
      h5.dispose();
    },
  );
}
