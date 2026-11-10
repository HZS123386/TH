import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fate_h5/app/controller.dart';
import 'package:fate_h5/app/h5_app.dart';
import 'package:fate_h5/core/models.dart';
import 'package:fate_h5/core/repository.dart';
import 'package:fate_h5/features/history_dialog.dart';
import 'package:fate_h5/features/information_page.dart';
import 'package:fate_h5/features/landing_page.dart';
import 'package:fate_h5/features/welcome_page.dart';
import 'support.dart';

http.Response reply(dynamic value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

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

void main() {
  testWidgets(
    'welcome enters the existing landing and preserves deep-link parameters',
    (tester) async {
      phone(tester);
      final browser = TestBrowser()..settings.clear();
      final h5 = H5Controller(
        translations(),
        ReportRepository(browser),
        browser,
        language: 'zh',
      );
      await tester.pumpWidget(
        H5App(
          controller: h5,
          initialLocation: '/?lang=zh&topic=love&utm_source=facebook',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('很高兴遇见你'), findsOneWidget);
      final landingState = tester.state(find.byType(LandingPage));
      await tester.tap(find.byKey(const ValueKey('welcome-start')));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomePage), findsNothing);
      expect(tester.state(find.byType(LandingPage)), same(landingState));
      final uri = GoRouter.of(
        tester.element(find.byType(LandingPage)),
      ).routeInformationProvider.value.uri;
      expect(uri.queryParameters['topic'], 'love');
      expect(uri.queryParameters['utm_source'], 'facebook');
      expect(browser.readSetting('fate-welcome-seen'), '1');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
      expect(
        H5Controller(
          translations(),
          ReportRepository(browser),
          browser,
        ).welcomeOpen,
        isFalse,
      );
      browser.settings.remove('session:fate-welcome-dismissed');
      final returning = H5Controller(
        translations(),
        ReportRepository(browser),
        browser,
      );
      expect(returning.returningVisitor, isTrue);
      expect(returning.welcomeOpen, isTrue);
      returning.dispose();
    },
  );

  testWidgets(
    'privacy deep link bypasses welcome and retains its URL while switching language',
    (tester) async {
      phone(tester);
      final browser = TestBrowser()..settings.clear();
      final h5 = H5Controller(
        translations(),
        ReportRepository(browser),
        browser,
        language: 'zh',
      );
      await tester.pumpWidget(
        H5App(controller: h5, initialLocation: '/privacy.html?lang=zh'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WelcomePage), findsNothing);
      expect(find.text('隐私与资料使用'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'TH'));
      await tester.pumpAndSettle();
      final uri = GoRouter.of(
        tester.element(find.byType(InformationPage)),
      ).routeInformationProvider.value.uri;
      expect(uri.path, '/privacy.html');
      expect(uri.queryParameters['lang'], 'th');
      expect(find.text('ความเป็นส่วนตัวและการใช้ข้อมูล'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );

  testWidgets(
    'data-use cancel sends nothing; failed acceptance can retry before saving the preference',
    (tester) async {
      phone(tester);
      final browser = TestBrowser()..settings.remove('fate-data-use-version');
      var attempts = 0;
      final repo = ReportRepository(
        browser,
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          expect(request.url.path, '/api/landing/consents');
          expect(request.headers['X-Report-Key'], browser.key);
          expect(jsonDecode(request.body), {
            'notice_version': 'h5-data-use-1',
            'granted': true,
          });
          attempts++;
          return attempts == 1
              ? reply({'code': 'busy'}, 503)
              : reply({'accepted': true});
        }),
      );
      final h5 = H5Controller(translations(), repo, browser, language: 'zh');
      bool? accepted;
      await tester.pumpWidget(
        H5Scope(
          controller: h5,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    accepted = await confirmDataUse(context, h5);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('暂不解析'));
      await tester.pumpAndSettle();
      expect(accepted, isFalse);
      expect(attempts, 0);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('data-use-agree')));
      await tester.pumpAndSettle();
      expect(h5.noticeAccepted, isFalse);
      expect(browser.readSetting('fate-data-use-version'), isNull);
      await tester.tap(find.byKey(const ValueKey('data-use-agree')));
      await tester.pumpAndSettle();
      expect(accepted, isTrue);
      expect(h5.noticeAccepted, isTrue);
      expect(
        browser.readSetting('fate-data-use-version'),
        H5Controller.noticeVersion,
      );
      expect(attempts, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );

  testWidgets(
    'history deletion requires confirmation and handles an empty 204 response',
    (tester) async {
      phone(tester);
      final browser = TestBrowser();
      final report = fixture();
      var deleted = false;
      final repo = ReportRepository(
        browser,
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          if (request.method == 'DELETE') {
            expect(request.url.path, '/api/life-reports/${report['id']}');
            expect(request.headers['X-Report-Key'], browser.key);
            deleted = true;
            return http.Response('', 204);
          }
          return reply({
            'items': [report],
          });
        }),
      );
      final h5 = H5Controller(translations(), repo, browser, language: 'zh');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HistoryDialog(h5: h5)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('删除报告'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保留报告'));
      await tester.pumpAndSettle();
      expect(deleted, isFalse);
      await tester.tap(find.byTooltip('删除报告'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '删除报告'));
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
      expect(find.byTooltip('删除报告'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );

  test(
    'funnel waits for submission acknowledgment before counting report display and deduplicates calls',
    () async {
      final browser = TestBrowser()
        ..visit = {
          'id': '2de0ed5d-ccee-4901-bd26-868c3260fc74',
          'source': 'facebook',
          'campaign': 'fortune',
        };
      final gate = Completer<void>();
      final events = <String>[];
      final repo = ReportRepository(
        browser,
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          final body = object(jsonDecode(request.body));
          expect(body.containsKey('profile'), isFalse);
          final name = text(body['event']);
          events.add(name.isEmpty ? 'visit' : name);
          if (name == 'submitted') await gate.future;
          return reply({'ok': true});
        }),
      );
      final h5 = H5Controller(translations(), repo, browser);
      final submitted = h5.trackReport('report-id', 'submitted');
      final seen = h5.trackReport('report-id', 'seen');
      await Future<void>.delayed(Duration.zero);
      expect(events, ['visit', 'submitted']);
      gate.complete();
      await Future.wait([submitted, seen]);
      await h5.trackReport('report-id', 'seen');
      expect(events, ['visit', 'submitted', 'seen']);
      h5.dispose();
    },
  );

  test(
    'disabled or unavailable traffic counts cannot block an original report request',
    () async {
      for (final enabled in [false, true]) {
        final browser = TestBrowser()
          ..visit = enabled ? {'id': 'test-visit'} : {};
        var visits = 0;
        final repo = ReportRepository(
          browser,
          baseUrl: 'https://example.test',
          client: MockClient((request) async {
            if (request.url.path.startsWith('/api/landing')) {
              visits++;
              throw Exception('offline analytics');
            }
            return reply(fixture());
          }),
        );
        final h5 = H5Controller(translations(), repo, browser);
        await h5.trackReport('report-id', 'submitted');
        final report = await repo.generate(
          object(fixture()['input']),
          CancelToken(),
          (_, _, _) {},
        );
        expect(report.preview, isNotEmpty);
        expect(visits, enabled ? 1 : 0);
        h5.dispose();
      }
    },
  );
}
