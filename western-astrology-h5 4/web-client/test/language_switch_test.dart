import 'dart:async';

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
      controller.enterLanding();
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
    'language switching preserves form and scroll while selected place names wait for their glyphs',
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
      final controller =
          H5Controller(
              translations(),
              ReportRepository(
                browser,
                client: MockClient((request) async {
                  calls.add(request.method);
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
              'user_question': 'Original question',
            }
            ..landingPlace = Place({
              'id': 'synthetic-place',
              'countryCode': 'CN',
              'placeType': 'province',
              'timeZone': 'Asia/Shanghai',
              'nameEnglish': 'Fushun',
              'nameChinese': '抚顺市',
              'nameThai': 'ฟู่ซุ่น',
            })
            ..enterLanding();
      await tester.pumpWidget(
        H5App(controller: controller, initialLocation: '/?lang=th&topic=love'),
      );
      await tester.pumpAndSettle();
      final question = find.byKey(const ValueKey('custom-question'));
      await tester.ensureVisible(question);
      await tester.enterText(question, 'Keep this edited question');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
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
        tester.widget<TextField>(question).controller!.text,
        'Keep this edited question',
      );
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
      final city = find.byKey(const ValueKey('birth-city'));
      expect(tester.widget<TextFormField>(city).controller!.text, 'ฟู่ซุ่น');
      body.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(city).controller!.text, '抚顺市');
      expect(calls.where((method) => method != 'GET'), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}
