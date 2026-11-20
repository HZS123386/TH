import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fate_h5/app/controller.dart';
import 'package:fate_h5/app/h5_app.dart';
import 'package:fate_h5/app/languages.dart';
import 'package:fate_h5/core/models.dart';
import 'package:fate_h5/core/repository.dart';
import 'package:fate_h5/features/checkout_dialog.dart';
import 'package:fate_h5/features/information_page.dart';
import 'package:fate_h5/features/landing_page.dart';
import 'package:fate_h5/features/welcome_page.dart';
import 'package:fate_h5/ui/jy_components.dart';
import 'package:fate_h5/ui/theme.dart';

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

class _PolicyAssets extends CachingAssetBundle {
  _PolicyAssets({Set<String> failOnce = const {}}) : _failOnce = {...failOnce};
  final Set<String> _failOnce;

  @override
  Future<ByteData> load(String key) async {
    if (key.startsWith('assets/privacy/') ||
        key.startsWith('assets/support/')) {
      if (_failOnce.remove(key)) throw FlutterError('Temporary asset failure');
      return ByteData.sublistView(File(key).readAsBytesSync());
    }
    return rootBundle.load(key);
  }
}

void main() {
  testWidgets(
    'theme boards match the reference spacing and fit short screens',
    (tester) async {
      phone(tester);
      final data = translations();
      Widget boards(String language) => MaterialApp(
        theme: h5Theme(),
        home: Scaffold(
          body: LayoutBuilder(
            builder: (context, viewport) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: ThemeBoards(
                copy: Copy(data, language),
                viewportHeight: viewport.maxHeight,
              ),
            ),
          ),
        ),
      );

      final board = find.byType(ThemeBoards);
      final artwork = find.descendant(
        of: board,
        matching: find.byType(ClipPath),
      );
      tester.view.physicalSize = const Size(452, 844);
      await tester.pumpWidget(boards('zh'));
      await tester.pumpAndSettle();
      final tall = tester.getSize(board);
      final tallImage = tester.getSize(artwork.first);
      expect(tall.width, 380);
      expect(tallImage.height, closeTo(126, 1));
      expect(tester.getSize(artwork.last).height, closeTo(144, 1));
      expect(
        tester.getTopLeft(artwork.last).dy -
            tester.getBottomLeft(artwork.first).dy,
        closeTo(28, 1),
      );
      final titles = objects(
        object(data['jyThemes'])['outlook'],
      ).map((item) => find.text(text(item['zh']))).toList();
      expect(
        tester.getCenter(titles[1]).dy - tester.getCenter(titles[0]).dy,
        closeTo(40, 1),
      );

      tester.view.physicalSize = const Size(452, 610);
      await tester.pumpAndSettle();
      expect(tester.getSize(board).width, tall.width);
      expect(tester.getSize(board).height, lessThan(tall.height));
      expect(tester.getSize(artwork.first).height, lessThan(tallImage.height));

      tester.view.physicalSize = const Size(320, 568);
      await tester.pumpWidget(boards('th'));
      await tester.pumpAndSettle();
      final banner = tester.getRect(
        find.text(Copy(data, 'th').t('jy', 'topicLabel')),
      );
      for (final group in ['outlook', 'highlights']) {
        for (final item in objects(object(data['jyThemes'])[group])) {
          final topic = find.text(text(item['th']));
          expect(topic, findsOneWidget);
          expect(tester.getTopLeft(topic).dy, greaterThan(banner.bottom));
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'information text and identity are complete in all nine selected languages',
    () {
      final identity = object(
        jsonDecode(File('assets/privacy/controller.json').readAsStringSync()),
      );
      expect(identity['contact_email'], 'wangb2295@gmail.com');
      final data = translations();
      for (final kind in ['privacy', 'support']) {
        final index = object(
          jsonDecode(File('assets/$kind/index.json').readAsStringSync()),
        );
        expect(index.containsKey('fallbackNotices'), isFalse);
        final reference = object(
          jsonDecode(File('assets/$kind/en.json').readAsStringSync()),
        );
        for (final option in h5Languages) {
          final language = option.$1;
          expect(object(index['languages'])[language], language);
          final content = object(
            jsonDecode(File('assets/$kind/$language.json').readAsStringSync()),
          );
          expect(
            objects(content['sections']).map((s) => s['id']).toList(),
            objects(reference['sections']).map((s) => s['id']).toList(),
          );
          if (kind == 'support') {
            expect(Copy(data, language).t('jy', 'birthDataNotice'), isNotEmpty);
            final policies = object(content['purchasePolicies']);
            for (final policy in ['terms', 'refund', 'delivery']) {
              final sections = objects(policies[policy]);
              expect(sections.length, greaterThanOrEqualTo(2));
              for (final section in sections) {
                expect(text(section['title']), isNotEmpty);
                expect(section['paragraphs'], isNotEmpty);
              }
            }
          }
          final localized = object(object(identity['localizations'])[language]);
          expect(text(localized['controller_name']), isNotEmpty);
          expect(text(localized['controller_address']), isNotEmpty);
          if (language != 'zh') {
            expect(text(localized['translation_notice']), isNotEmpty);
            expect(
              RegExp(r'[\u3400-\u9fff]').hasMatch(jsonEncode(content)),
              isFalse,
            );
            expect(
              RegExp(r'[\u3400-\u9fff]').hasMatch(jsonEncode(localized)),
              isFalse,
            );
          }
        }
      }
    },
  );

  test(
    'report and export method labels use the report language instead of raw English metadata',
    () {
      final data = translations();
      for (final option in h5Languages) {
        final language = option.$1;
        final raw = fixture();
        final input = object(raw['input']);
        raw['format'] = 'western-compact';
        raw['method'] = {'name': 'RoxyAPI Western Astrology'};
        raw['catalog'] = [
          for (final entry in objects(raw['catalog']).take(5).indexed)
            {...entry.$2, 'key': westernKeys[entry.$1]},
        ];
        raw['progress'] = {'completed': 0, 'total': 6};
        raw['input'] = {
          ...input,
          'profile': {...object(input['profile']), 'language': language},
        };
        final c = Copy(data, 'th').forReport(LifeReport.parse(raw));
        expect(
          c.t('report', 'methodValue'),
          Copy(data, language).t('jy', 'chart.western'),
        );
        expect(
          c.t('report', 'plan'),
          Copy(data, language).t('jy', 'report.westernSections.plan'),
        );
      }
    },
  );

  testWidgets(
    'help renders every selected language and its translated operator details',
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
        DefaultAssetBundle(
          bundle: _PolicyAssets(),
          child: H5App(
            controller: h5,
            initialLocation: '/support.html?lang=zh',
          ),
        ),
      );
      final identity = object(
        jsonDecode(File('assets/privacy/controller.json').readAsStringSync()),
      );
      for (final option in h5Languages) {
        await h5.changeLanguage(option.$1);
        await tester.pumpAndSettle();
        final locale = object(object(identity['localizations'])[option.$1]);
        expect(find.text(text(locale['controller_name'])), findsOneWidget);
        expect(find.text(text(locale['controller_address'])), findsOneWidget);
        expect(
          find.byKey(ValueKey('support-content-${option.$1}')),
          findsOneWidget,
        );
        if (option.$1 != 'zh') expect(find.text('北京尚德机构科技有限公司'), findsNothing);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );

  testWidgets(
    'welcome delays hidden form work until entering and preserves its state and URL',
    (tester) async {
      phone(tester);
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: false);
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      final name = find.byKey(const ValueKey('welcome-name-strokes'));
      expect(name, findsOneWidget);
      final initialInk = tester.widget<CustomPaint>(name).painter!;
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        tester.widget<CustomPaint>(name).painter!.shouldRepaint(initialInk),
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 520));
      expect(find.text('情缘法宗师'), findsOneWidget);
      expect(find.text('该断该续？'), findsOneWidget);
      expect(find.text('揪出搅局的人'), findsOneWidget);
      expect(
        tester.getCenter(name).dx,
        greaterThan(tester.getCenter(find.text('该断该续？')).dx),
      );
      final shimmer = find.byKey(const ValueKey('welcome-name-shimmer'));
      final bright = tester.widget<Opacity>(shimmer).opacity;
      final completedInk = tester.widget<CustomPaint>(name).painter!;
      await tester.pump(const Duration(milliseconds: 900));
      expect(
        tester.widget<CustomPaint>(name).painter!.shouldRepaint(completedInk),
        isFalse,
      );
      expect(tester.widget<Opacity>(shimmer).opacity, lessThan(bright));
      expect(find.byType(LandingPage), findsNothing);
      final languageMenu = find.byKey(const ValueKey('language-menu'));
      expect(
        tester.getTopRight(languageMenu).dx,
        greaterThan(tester.getTopRight(find.byType(WelcomePage)).dx - 32),
      );
      expect(tester.getCenter(languageMenu).dy, lessThan(90));
      await tester.tap(languageMenu);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(find.byKey(const ValueKey('language-option-th')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(h5.language, 'th');
      expect(find.byType(WelcomePage), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('welcome-start')));
      await tester.pump();
      final landingState = tester.state(find.byType(LandingPage));
      await tester.pump(const Duration(milliseconds: 850));
      await tester.pump();
      expect(find.byType(WelcomePage), findsNothing);
      expect(tester.state(find.byType(LandingPage)), same(landingState));
      final uri = GoRouter.of(
        tester.element(find.byType(LandingPage)),
      ).routeInformationProvider.value.uri;
      expect(uri.queryParameters['lang'], 'th');
      expect(uri.queryParameters['topic'], 'love');
      expect(uri.queryParameters['utm_source'], 'facebook');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      // Browsers with the old preference still show the same welcome page.
      browser.writeSetting('fate-welcome-dismissed', '1', session: true);
      for (final language in ['zh', 'th']) {
        final reopened = H5Controller(
          translations(),
          ReportRepository(browser),
          browser,
          language: language,
        );
        await tester.pumpWidget(
          H5App(controller: reopened, initialLocation: '/?lang=$language'),
        );
        await tester.pump();
        expect(find.byType(WelcomePage), findsOneWidget);
        expect(
          find.byKey(const ValueKey('welcome-name-strokes')),
          findsOneWidget,
        );
        expect(
          find.text(language == 'zh' ? '该断该续？' : 'ควรพอหรือไปต่อ?'),
          findsOneWidget,
        );
        expect(find.byType(LandingPage), findsNothing);
        await tester.tap(find.byKey(const ValueKey('welcome-start')));
        await tester.pump();
        expect(find.byType(WelcomePage), findsNothing);
        expect(find.byType(LandingPage), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        reopened.dispose();
      }
    },
  );

  testWidgets(
    'privacy deep link bypasses welcome and retains its URL while switching language',
    (tester) async {
      phone(tester);
      final browser = TestBrowser()..settings.clear();
      final prepared = <(String, String)>[];
      final h5 = H5Controller(
        translations(),
        ReportRepository(
          browser,
          baseUrl: 'https://example.test',
          client: MockClient((request) async {
            expect(request.url.path, '/api/landing/config');
            expect(request.headers.containsKey('X-Report-Key'), isFalse);
            return reply({'privacy': {}});
          }),
        ),
        browser,
        language: 'zh',
        ensureTextFont: (language, value) async =>
            prepared.add((language, value)),
      );
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: _PolicyAssets(),
          child: H5App(
            controller: h5,
            initialLocation: '/privacy.html?lang=zh',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WelcomePage), findsNothing);
      expect(find.text('隐私政策'), findsOneWidget);
      expect(find.byKey(const ValueKey('privacy-content-zh')), findsOneWidget);
      expect(find.text('生效日期: 2026-11-20'), findsOneWidget);
      expect(find.textContaining('上线审阅稿：'), findsNothing);
      prepared.clear();
      await tester.tap(find.byKey(const ValueKey('language-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('language-option-th')));
      await tester.pumpAndSettle();
      final uri = GoRouter.of(
        tester.element(find.byType(InformationPage)),
      ).routeInformationProvider.value.uri;
      expect(uri.path, '/privacy.html');
      expect(uri.queryParameters['lang'], 'th');
      expect(find.text('นโยบายความเป็นส่วนตัว'), findsOneWidget);
      expect(find.byKey(const ValueKey('privacy-content-th')), findsOneWidget);
      final operator = object(
        jsonDecode(File('assets/privacy/controller.json').readAsStringSync()),
      );
      final translated = text(
        object(object(operator['localizations'])['th'])['controller_name'],
      );
      expect(find.text(translated), findsOneWidget);
      expect(find.text('北京尚德机构科技有限公司'), findsNothing);
      expect(
        prepared.any((item) => item.$1 == 'th' && item.$2.contains(translated)),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );

  testWidgets(
    'privacy remains readable without config and contents navigate on a small screen',
    (tester) async {
      phone(tester);
      final browser = TestBrowser()..settings.clear();
      final requests = <String>[];
      final h5 = H5Controller(
        translations(),
        ReportRepository(
          browser,
          baseUrl: 'https://example.test',
          client: MockClient((request) async {
            requests.add(request.url.path);
            return reply({}, 503);
          }),
        ),
        browser,
        language: 'zh',
      );
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: _PolicyAssets(),
          child: H5App(
            controller: h5,
            initialLocation: '/privacy.html?lang=zh',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('wangb2295@gmail.com'), findsOneWidget);
      expect(find.text('北京尚德机构科技有限公司'), findsOneWidget);
      expect(find.text('9. 保存期限与清理规则'), findsNWidgets(2));
      final contentsLink = find.widgetWithText(TextButton, '9. 保存期限与清理规则');
      await tester.ensureVisible(contentsLink);
      await tester.tap(contentsLink);
      await tester.pumpAndSettle();
      expect(find.text('9. 保存期限与清理规则').last.hitTestable(), findsOneWidget);
      expect(requests, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );

  testWidgets(
    'support shows the approved contact, opens an email draft and links to privacy',
    (tester) async {
      phone(tester);
      final semantics = tester.ensureSemantics();
      final browser = TestBrowser()..settings.clear();
      final requests = <String>[];
      final h5 = H5Controller(
        translations(),
        ReportRepository(
          browser,
          baseUrl: 'https://example.test',
          client: MockClient((request) async {
            requests.add(request.url.path);
            return reply({}, 503);
          }),
        ),
        browser,
        language: 'zh',
      );
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: _PolicyAssets(),
          child: H5App(
            controller: h5,
            initialLocation: '/support.html?lang=zh',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('support-content-zh')), findsOneWidget);
      expect(find.text('wangb2295@gmail.com'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('wangb2295@gmail.com')).label,
        'wangb2295@gmail.com',
      );
      semantics.dispose();
      expect(find.text('正式上线后会提供联系方式。'), findsNothing);
      final emailButton = find.byKey(const ValueKey('support-compose-email'));
      await tester.ensureVisible(emailButton);
      await tester.tap(emailButton);
      final mail = Uri.parse(browser.openedPages.single);
      expect(mail.scheme, 'mailto');
      expect(mail.path, 'wangb2295@gmail.com');
      expect(mail.queryParameters, {'subject': 'FATE 网页支持请求'});
      final faq = find.byKey(const ValueKey('support-faq-generation'));
      await tester.ensureVisible(faq);
      await tester.tap(faq);
      await tester.pumpAndSettle();
      expect(find.textContaining('先确认网络连接正常'), findsOneWidget);
      final paymentFaq = find.byKey(const ValueKey('support-faq-unlock'));
      await tester.ensureVisible(paymentFaq);
      await tester.tap(paymentFaq);
      await tester.pumpAndSettle();
      expect(find.textContaining('目前通过 LINE 领取完整报告'), findsOneWidget);
      for (final (label, policy, detail) in [
        ('服务条款', 'terms', '报告与费用'),
        ('退款政策', 'refund', '退款受理范围'),
        ('交付说明', 'delivery', '报告如何交付'),
      ]) {
        final link = find.widgetWithText(TextButton, label);
        await tester.ensureVisible(link);
        await tester.tap(link);
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('support-$policy-zh')), findsOneWidget);
        expect(find.text(detail), findsOneWidget);
        expect(find.text('wangb2295@gmail.com'), findsOneWidget);
      }
      final privacy = find.byKey(const ValueKey('support-privacy-link'));
      await tester.ensureVisible(privacy);
      await tester.tap(privacy);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('privacy-content-zh')), findsOneWidget);
      expect(requests, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );

  testWidgets(
    'privacy can retry a transient content failure instead of caching the failed future',
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
        DefaultAssetBundle(
          bundle: _PolicyAssets(failOnce: {'assets/privacy/zh.json'}),
          child: H5App(
            controller: h5,
            initialLocation: '/privacy.html?lang=zh',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('privacy-content-zh')), findsNothing);
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('privacy-content-zh')), findsOneWidget);
      expect(find.text('wangb2295@gmail.com'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );

  testWidgets(
    'JY result deletion requires confirmation and handles empty 204 responses',
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
          return reply(report);
        }),
      );
      final h5 = H5Controller(translations(), repo, browser, language: 'zh')
        ..enterLanding();
      await tester.pumpWidget(
        H5App(
          controller: h5,
          initialLocation: '/report.html?id=${report['id']}&lang=zh',
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('删除此结果'));
      await tester.tap(find.text('删除此结果'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保留报告'));
      await tester.pumpAndSettle();
      expect(deleted, isFalse);
      await tester.ensureVisible(find.text('删除此结果'));
      await tester.tap(find.text('删除此结果'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '删除报告'));
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
      expect(find.byType(ReportCheckout), findsNothing);
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
          return reply({'recorded': name.isNotEmpty});
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
          if (request.url.path == '/api/landing/config') {
            return reply({'notice_version': H5Controller.noticeVersion});
          }
          expect(request.url.path, '/api/landing/consents');
          expect(request.headers['X-Report-Key'], browser.key);
          expect(jsonDecode(request.body), {
            'notice_version': H5Controller.noticeVersion,
            'granted': true,
          });
          attempts++;
          return attempts == 1
              ? reply({'code': 'busy'}, 503)
              : reply({
                  'accepted': true,
                  'notice_version': H5Controller.noticeVersion,
                });
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
      await tester.tap(find.text('取消'));
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
    'outdated data-use notice offers a fresh page without submitting consent',
    (tester) async {
      phone(tester);
      final browser = TestBrowser()..settings.remove('fate-data-use-version');
      var unexpected = 0;
      final repo = ReportRepository(
        browser,
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          if (request.url.path == '/api/landing/config') {
            return reply({'notice_version': 'h5-data-use-future'});
          }
          unexpected++;
          return reply({}, 500);
        }),
      );
      final h5 = H5Controller(translations(), repo, browser, language: 'zh');
      await tester.pumpWidget(
        H5Scope(
          controller: h5,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => confirmDataUse(context, h5),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('data-use-agree')));
      await tester.pumpAndSettle();
      expect(find.text(h5.copy.t('jy', 'noticeOutdated')), findsOneWidget);
      expect(find.byKey(const ValueKey('data-use-agree')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('data-use-reload')));
      expect(browser.openedPages.single, contains('?lang=zh&preview=notice-'));
      expect(browser.readSetting('fate-data-use-version'), isNull);
      expect(h5.noticeAccepted, isFalse);
      expect(unexpected, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );

  test('an invalid consent acknowledgement cannot save acceptance', () async {
    final browser = TestBrowser()..settings.remove('fate-data-use-version');
    final repo = ReportRepository(
      browser,
      baseUrl: 'https://example.test',
      client: MockClient(
        (request) async => reply(
          request.url.path == '/api/landing/config'
              ? {'notice_version': H5Controller.noticeVersion}
              : {
                  'accepted': false,
                  'notice_version': H5Controller.noticeVersion,
                },
        ),
      ),
    );
    final h5 = H5Controller(translations(), repo, browser, language: 'zh');
    await expectLater(
      h5.acceptDataUse(),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.code,
          'code',
          'landing_consent_failed',
        ),
      ),
    );
    expect(browser.readSetting('fate-data-use-version'), isNull);
    expect(h5.noticeAccepted, isFalse);
    h5.dispose();
  });

  test(
    'funnel retries a failed visit and submission before recording a preview',
    () async {
      final browser = TestBrowser()
        ..visit = {'id': 'visit-retry', 'region': 'TH'};
      final attempts = <String>[];
      final repo = ReportRepository(
        browser,
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          final body = object(jsonDecode(request.body));
          final event = text(body['event']);
          final step = event.isEmpty ? 'visit' : event;
          if (event.isEmpty) expect(body['region'], 'TH');
          final first = !attempts.contains(step);
          attempts.add(step);
          if (first && step != 'seen') return reply({'code': 'temporary'}, 503);
          return reply({'ok': true, 'recorded': true});
        }),
      );
      final h5 = H5Controller(translations(), repo, browser);
      await h5.recordVisit();
      await h5.trackReport('report-retry', 'submitted');
      await h5.trackReport('report-retry', 'seen');
      expect(attempts, ['visit', 'visit', 'submitted', 'submitted', 'seen']);
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
