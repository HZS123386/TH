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
import 'package:fate_h5/features/landing_page.dart';
import 'package:fate_h5/features/report_view_model.dart';
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
    'Thai birth picker fits a small phone and language switching preserves the entry URL',
    (tester) async {
      phone(tester);
      final browser = TestBrowser();
      final h5 = H5Controller(
        translations(),
        ReportRepository(browser),
        browser,
      );
      await tester.pumpWidget(
        H5App(
          controller: h5,
          initialLocation: '/?lang=th&topic=love&startup=1',
        ),
      );
      await tester.pumpAndSettle();
      await click(
        tester,
        find.widgetWithText(TextFormField, 'วันเกิด · ปี ค.ศ.'),
      );
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
      expect(find.text('从出生时刻，读懂你的运程'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );
  testWidgets(
    'small-phone birth entry, unknown time and cached report completion preserve the real payload',
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
              'items': [province],
              'total': 1,
            });
          }
          if (request.method == 'POST') {
            input = object(jsonDecode(request.body));
            current = {
              ...fixture(),
              'input': input,
              'time_accuracy': {
                'mode': 'estimated',
                'assumed_local_time': '12:00',
              },
            };
          }
          return response(current);
        }),
      );
      final h5 = H5Controller(translations(), repo, browser, language: 'zh');
      await tester.pumpWidget(
        H5App(controller: h5, initialLocation: '/?lang=zh'),
      );
      await tester.pumpAndSettle();
      await click(tester, find.widgetWithText(TextFormField, '出生日期 · 阳历'));
      expect(find.byType(BirthDateDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await click(
        tester,
        find.widgetWithText(FilledButton, h5.copy.t('ui', 'confirm')),
      );
      await click(
        tester,
        find.widgetWithText(CheckboxListTile, h5.copy.t('ui', 'unknown')),
      );
      await click(
        tester,
        find.widgetWithText(TextFormField, h5.copy.t('ui', 'country')),
      );
      await click(tester, find.widgetWithText(ListTile, '泰国'));
      await click(
        tester,
        find.widgetWithText(TextFormField, h5.copy.t('ui', 'province')),
      );
      await click(tester, find.widgetWithText(ListTile, '曼谷'));
      await click(
        tester,
        find.widgetWithText(FilledButton, h5.copy.t('life', 'generate')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GenerationDialog), findsNothing);
      expect(input, isNotNull);
      expect(object(input!['profile'])['birth_time'], isNull);
      expect(object(input!['profile'])['birth_date'], '1999-01-01');
      expect(object(input!['profile'])['location_id'], province['id']);
      expect(object(input!['profile'])['latitude'], isNull);
      expect(input!['report_kind'], 'fortune');
      expect(calls, contains('POST /api/life-reports'));
      expect(find.textContaining('先看清自己的判断习惯'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );
  testWidgets(
    'preview export, test checkout, all themes, plan and full export preserve server permission',
    (tester) async {
      phone(tester);
      final browser = TestBrowser();
      var full = false;
      final calls = <String>[];
      final repo = ReportRepository(
        browser,
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          if (request.url.path.endsWith('/unlock')) full = true;
          return response(fixture(full: full));
        }),
      );
      final h5 = H5Controller(translations(), repo, browser, language: 'zh');
      final c = h5.copy;
      await tester.pumpWidget(
        H5App(
          controller: h5,
          initialLocation: '/report.html?id=${fixture()['id']}&lang=zh',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('付费章节重点'), findsNothing);
      await click(tester, find.byTooltip(c.t('life', 'exportPdf')));
      expect(browser.exported!['access'], 'preview');
      expect(browser.exported!['chapters'], isEmpty);
      final purchase = find.byKey(const ValueKey('life-sticky-buy'));
      await click(tester, purchase);
      expect(find.text(c.t('checkout', 'demo')), findsOneWidget);
      await click(
        tester,
        find.widgetWithText(TextButton, c.t('checkout', 'fillCard')),
      );
      await click(tester, find.byKey(const ValueKey('confirm-test-payment')));
      expect(
        calls,
        contains('POST /api/life-reports/${fixture()['id']}/unlock'),
      );
      expect(find.byKey(const ValueKey('life-sticky-buy')), findsNothing);
      expect(find.textContaining('付费章节重点'), findsOneWidget);
      for (final topic in c.topics) {
        expect(find.text(c.topicTitle(topic, 2026)), findsWidgets);
      }
      await click(tester, find.text(c.t('life', 'plan')));
      expect(find.text('先观察当前的习惯'), findsOneWidget);
      await click(tester, find.byTooltip(c.t('life', 'exportPdf')));
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
