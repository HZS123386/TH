import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
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
  testWidgets(
    'generation keeps the same visible wheel across stages until the report is ready',
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
      final state = GenerationState()..update(report, 19, 'preview');
      var completed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: GenerationDialog(
            h5: h5,
            state: state,
            full: false,
            onCancel: () {},
            onRetry: () {},
            onComplete: (_) => completed++,
          ),
        ),
      );
      final wheel = find.byType(GenerationVideo);
      final wheelState = tester.state(wheel);
      expect(tester.widget<GenerationVideo>(wheel).active, isTrue);
      await tester.pump(const Duration(milliseconds: 2100));
      await tester.pump(const Duration(milliseconds: 2600));
      state.update(report, 99, 'preview');
      await tester.pump(const Duration(seconds: 12));
      expect(tester.state(wheel), same(wheelState));
      expect(tester.widget<GenerationVideo>(wheel).finishing, isFalse);
      expect(completed, 0);
      state.ready(report);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(tester.widget<GenerationVideo>(wheel).finishing, isTrue);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(completed, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
      h5.dispose();
    },
  );

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
      await click(tester, find.widgetWithText(TextButton, '中文'));
      final route = GoRouter.of(
        tester.element(find.byType(LandingPage)),
      ).routeInformationProvider.value.uri;
      expect(route.queryParameters, containsPair('lang', 'zh'));
      expect(route.queryParameters, containsPair('topic', 'love'));
      expect(route.queryParameters, containsPair('startup', '1'));
      expect(find.textContaining('从出生时刻，读懂你的运程'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );
  testWidgets(
    'JY inline form, unknown time and consent lead to the locked checkout without a paid request',
    (tester) async {
      phone(tester);
      final browser = TestBrowser();
      Json? input;
      var current = fixture();
      final calls = <String>[];
      final repo = ReportRepository(
        browser,
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          if (request.url.path == '/api/thai-locations') {
            return response({
              'items': request.url.queryParameters['level'] == 'province'
                  ? [province]
                  : [],
              'total': request.url.queryParameters['level'] == 'province'
                  ? 1
                  : 0,
            });
          }
          if (request.url.path == '/api/landing/consents') {
            return response({'accepted': true});
          }
          if (request.method == 'POST') {
            input = object(jsonDecode(request.body));
            final chart = object(fixture()['chart']);
            current = {
              ...fixture(),
              'input': input,
              'time_accuracy': {
                'mode': 'estimated',
                'assumed_local_time': '12:00',
              },
              'chart': {
                ...chart,
                'precision': 'estimated',
                'houses': [],
                'planets': [
                  for (final p in objects(chart['planets']))
                    if (p['id'] != 'ascendant') {...p, 'house': null},
                ],
              },
            };
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
      await click(tester, find.byKey(const ValueKey('birth-country')));
      await click(tester, find.text('泰国'));
      await click(tester, find.byKey(const ValueKey('birth-province')));
      await click(
        tester,
        find.descendant(
          of: find.byType(PlacePicker),
          matching: find.text('曼谷'),
        ),
      );
      await click(tester, find.byKey(const ValueKey('birth-city')));
      await click(
        tester,
        find.descendant(
          of: find.byType(PlacePicker),
          matching: find.text('曼谷'),
        ),
      );
      await click(tester, find.byKey(const ValueKey('generate-report')));
      expect(input, isNull);
      expect(find.text('确认使用出生资料'), findsOneWidget);
      await click(tester, find.byKey(const ValueKey('data-use-agree')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(input, isNotNull);
      expect(object(input!['profile'])['birth_time'], isNull);
      expect(object(input!['profile'])['birth_date'], '1999-01-01');
      expect(object(input!['profile'])['location_id'], province['id']);
      expect(input!['report_kind'], 'fortune');
      expect(calls, contains('POST /api/life-reports'));
      expect(calls.any((value) => value.endsWith('/unlock')), isFalse);
      expect(find.byType(GenerationDialog), findsNothing);
      expect(find.byType(ReportCheckout), findsOneWidget);
      expect(find.text('解锁您的运程'), findsOneWidget);
      expect(find.text('฿39'), findsOneWidget);
      expect(find.textContaining('先看清自己的判断习惯'), findsNothing);
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
    'saved report waits for its language font before showing its contents',
    () async {
      final gate = Completer<void>();
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
      );
      final model = ReportViewModel(h5, fixture()['id']);
      final pending = model.load();
      await Future<void>.delayed(Duration.zero);
      expect(model.report, isNull);
      gate.complete();
      await pending;
      expect(model.report!.language, 'zh');
      expect(h5.language, 'zh');
      model.dispose();
      h5.dispose();
    },
  );
  test(
    'latest language request wins after an earlier slow font download',
    () async {
      final gate = Completer<void>();
      final browser = TestBrowser();
      final repo = ReportRepository(browser);
      final h5 = H5Controller(
        translations(),
        repo,
        browser,
        ensureFont: (lang) => lang == 'zh' ? gate.future : Future.value(),
      );
      final chinese = h5.changeLanguage('zh');
      await h5.changeLanguage('th');
      gate.complete();
      expect(await chinese, isFalse);
      expect(h5.language, 'th');
      h5.dispose();
    },
  );
}
