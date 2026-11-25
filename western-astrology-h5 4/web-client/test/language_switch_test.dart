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
import 'package:fate_h5/features/landing_page.dart';
import 'package:fate_h5/ui/language_fonts.dart';

import 'support.dart';

void main() {
  test(
    'language switch and landing entry defer common fonts until text needs them',
    () async {
      final common = Completer<void>();
      final loaded = <String>[];
      final fonts = LanguageFonts(
        loadFont: (family, asset) async {
          loaded.add(family);
          if (family == 'NotoSansSCCommon') await common.future;
        },
      );
      final browser = TestBrowser();
      final controller = H5Controller(
        translations(),
        ReportRepository(browser),
        browser,
        ensureFont: fonts.ensure,
        ensureTextFont: fonts.ensureText,
      );
      expect(await controller.changeLanguage('zh'), isTrue);
      expect(controller.language, 'zh');
      expect(controller.languageLoading, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(loaded, ['NotoSansSC']);
      final text = controller.prepareText('龘');
      await Future<void>.delayed(Duration.zero);
      expect(loaded, ['NotoSansSC', 'NotoSansSCCommon']);
      expect(common.isCompleted, isFalse);
      common.complete();
      await text;
      expect(loaded, ['NotoSansSC', 'NotoSansSCCommon', 'NotoSansSCFull']);
      controller.dispose();
    },
  );

  test('failed UI font leaves the active language unchanged', () async {
    final browser = TestBrowser();
    final repository = ReportRepository(browser);
    final controller = H5Controller(
      translations(),
      repository,
      browser,
      ensureFont: (_) async => throw StateError('offline'),
    );
    expect(await controller.changeLanguage('zh'), isFalse);
    expect(controller.language, 'th');
    expect(repository.language, 'th');
    expect(controller.languageLoading, isFalse);
    expect(browser.locale, isEmpty);
    controller.dispose();
  });

  testWidgets(
    'switching birth countries clears the old city and keeps date, time and scroll',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final ui = Completer<void>(), body = Completer<void>();
      final browser = TestBrowser();
      final calls = <String>[];
      const chinaCity = {
        'id': 'geonames:2037355',
        'countryCode': 'CN',
        'placeType': 'city',
        'timeZone': 'Asia/Shanghai',
        'nameEnglish': 'Fushun',
        'nameChinese': '抚顺市',
      };
      final controller =
          H5Controller(
              translations(),
              ReportRepository(
                browser,
                client: MockClient((request) async {
                  calls.add(request.method);
                  if (request.url.path == '/api/thai-locations') {
                    expect(request.url.queryParameters['country'], 'CN');
                    expect(request.url.queryParameters['level'], 'locality');
                    return http.Response(
                      jsonEncode({
                        'items': [chinaCity],
                        'total': 1,
                      }),
                      200,
                      headers: {
                        'content-type': 'application/json; charset=utf-8',
                      },
                    );
                  }
                  return http.Response('{}', 200);
                }),
              ),
              browser,
              ensureFont: (language) =>
                  language == 'zh' ? ui.future : Future.value(),
              ensureTextFont: (language, value) =>
                  language == 'zh' ? body.future : Future.value(),
            )
            ..landingInput = {
              'profile': {'birth_date': '2001-02-03', 'birth_time': '09:15'},
            }
            ..landingPlace = Place({
              'id': 'synthetic-place',
              'countryCode': 'TH',
              'placeType': 'city',
              'timeZone': 'Asia/Bangkok',
              'nameEnglish': 'Chiang Mai',
              'nameThai': 'เชียงใหม่',
            });
      await tester.pumpWidget(
        H5App(controller: controller, initialLocation: '/?lang=th&topic=love'),
      );
      await tester.pumpAndSettle();
      final city = find.byKey(const ValueKey('birth-city'));
      expect(tester.widget<TextFormField>(city).controller!.text, 'เชียงใหม่');
      final page = find.byType(LandingPage);
      final initialState = tester.state(page);
      final scroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const ValueKey('landing-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      scroll.position.jumpTo(450);
      await tester.pump();
      final initialOffset = scroll.position.pixels;
      final menu = tester.widget<PopupMenuButton<String>>(
        find.byKey(const ValueKey('language-menu')),
      );
      menu.onSelected!('zh');
      await tester.pump();
      expect(controller.language, 'th');
      expect(controller.languageLoading, isTrue);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      ui.complete();
      await tester.pumpAndSettle();
      expect(controller.language, 'zh');
      expect(controller.languageLoading, isFalse);
      expect(identical(tester.state(page), initialState), isTrue);
      expect(scroll.position.pixels, closeTo(initialOffset, 1));
      expect(
        find.byKey(const ValueKey('birth-date:2001年2月3日')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('birth-time:09:15')), findsOneWidget);
      final uri = GoRouter.of(
        tester.element(page),
      ).routeInformationProvider.value.uri;
      expect(uri.queryParameters, containsPair('lang', 'zh'));
      expect(uri.queryParameters, containsPair('topic', 'love'));
      expect(tester.widget<TextFormField>(city).controller!.text, isEmpty);
      await tester.ensureVisible(city);
      await tester.tap(city);
      await tester.pump();
      expect(find.text('抚顺市'), findsNothing);
      body.complete();
      await tester.pumpAndSettle();
      await tester.tap(find.text('抚顺市'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(city).controller!.text, '抚顺市');
      expect(calls.where((method) => method != 'GET'), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}
