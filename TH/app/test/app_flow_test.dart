import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fate_app/app/dependencies.dart';
import 'package:fate_app/app/fate_app.dart';
import 'package:fate_app/core/models/birth_profile.dart';
import 'package:fate_app/core/network/api_client.dart';
import 'package:fate_app/core/storage/session_store.dart';
import 'package:fate_app/features/actions/action_ledger.dart';
import 'package:fate_app/features/actions/action_page.dart';
import 'package:fate_app/features/chart/thai_chart_page.dart';
import 'package:fate_app/features/reports/h5_report_page.dart';
import 'package:fate_app/features/reports/reports_page.dart';
import 'package:fate_app/l10n/generated/app_localizations.dart';
import 'package:fate_app/l10n/generated/app_localizations_en.dart';
import 'package:fate_app/features/home/home_page.dart';
import 'package:fate_app/data/configuration_repository.dart';
import 'package:fate_app/ui/theme.dart';

class DelayedHeroBundle extends CachingAssetBundle {
  final requested = Completer<void>();
  final bytes = Completer<ByteData>();

  @override
  Future<ByteData> load(String key) {
    if (key == 'AssetManifest.bin') {
      return Future.value(
        const StandardMessageCodec().encodeMessage(<String, Object?>{})!,
      );
    }
    if (key == homeHeroImage.assetName) {
      if (!requested.isCompleted) requested.complete();
      return bytes.future;
    }
    return rootBundle.load(key);
  }
}

class MemorySessionStore implements SessionStore {
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
  for (final locale in [const Locale('zh'), const Locale('th')]) {
    testWidgets(
      'H5 unlocked report shows its generation state in ${locale.languageCode}',
      (tester) async {
        tester.view.physicalSize = const Size(390, 820);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({
          'fate.locale': locale.languageCode,
        });
        var state = 'limited';
        final d = AppDependencies(
          await SharedPreferences.getInstance(),
          secureStore: MemorySessionStore(),
          client: ApiClient(
            'https://api.example.test',
            client: MockClient((request) async {
              final report = {
                'id': 'report-1',
                'title': 'H5 fixture',
                'access': 'full',
                'preview_state': 'ready',
                'full_state': state,
                'chapters': [
                  {'key': 'annual', 'title': 'Saved chapter'},
                ],
              };
              final data = switch (request.url.path) {
                '/api/auth/h5-code' => {
                  'token': 'web-session',
                  'user_id': 'web-user',
                  'account': {'user_id': 'web-user', 'kind': 'h5'},
                },
                '/api/app/h5-reports' => {
                  'items': [report],
                  'next_cursor': null,
                },
                '/api/app/h5-reports/report-1' => report,
                _ => null,
              };
              return http.Response(jsonEncode(data), 200);
            }),
          ),
        );
        addTearDown(d.dispose);
        await d.auth.signInH5Code('A2B3C4');
        final s = await AppLocalizations.delegate.load(locale);

        Future<void> show(Widget page) async {
          await tester.pumpWidget(
            DependencyScope(
              dependencies: d,
              child: MaterialApp(
                locale: locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: page),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        await show(const ReportsPage());
        expect(find.textContaining(s.h5ReportLimited), findsOneWidget);
        expect(find.text(s.fullReport), findsNothing);

        await show(const H5ReportPage(id: 'report-1'));
        expect(find.text(s.h5ReportLimited), findsOneWidget);
        expect(find.text(s.h5ReportLimitedHelp), findsOneWidget);
        expect(find.text('Saved chapter'), findsOneWidget);
        state = 'ready';
        await tester.tap(find.byTooltip(s.h5Refresh));
        await tester.pumpAndSettle();
        expect(find.text(s.fullReport), findsOneWidget);
        expect(find.text(s.h5ReportLimitedHelp), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'motion preserves the draft, chat feedback, and iOS back gesture',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        SharedPreferences.setMockInitialValues({'fate.locale': 'en'});
        final reply = Completer<http.Response>();
        final d = AppDependencies(
          await SharedPreferences.getInstance(),
          secureStore: MemorySessionStore(),
          client: ApiClient(
            'https://api.example.test',
            client: MockClient((request) async {
              return switch (request.url.path) {
                '/api/auth/guest' => http.Response('{"token":"fixture"}', 201),
                '/api/auth/me' => http.Response(
                  '{"user_id":"motion-test","kind":"guest"}',
                  200,
                ),
                '/api/profile' => http.Response('null', 200),
                '/api/history' || '/api/memories' => http.Response('[]', 200),
                '/api/chat' => reply.future,
                _ => http.Response('{}', 404),
              };
            }),
          ),
        );
        await d.auth.ensureGuest();
        d.session.capabilities = const AppCapabilities(
          companionProvider: 'companion',
        );
        d.session.profile = const BirthProfile(
          date: '1995-02-03',
          timezone: 'Asia/Bangkok',
          place: 'Bangkok',
        );
        d.session.notifyListeners();
        await d.companion.load();
        await tester.pumpWidget(
          DependencyScope(
            dependencies: d,
            child: FateApp(dependencies: d),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('guardian-talk-love')),
        );
        await tester.tap(find.byKey(const ValueKey('guardian-talk-love')));
        await tester.pumpAndSettle();
        final s = AppLocalizationsEn();
        await tester.enterText(find.byType(TextField), 'Keep this draft');
        tester.view.physicalSize = const Size(320, 640);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        expect(
          tester.getBottomRight(find.byType(TextField)).dy,
          lessThanOrEqualTo(360),
        );
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        tester.view.physicalSize = const Size(390, 844);
        await tester.pumpAndSettle();
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
        await tester.pumpAndSettle();
        expect(find.text('Keep this draft'), findsOneWidget);
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures();
        await tester.pumpAndSettle();
        expect(find.text('Keep this draft'), findsOneWidget);
        await tester.tap(find.byTooltip(s.sendMessage));
        await tester.pumpAndSettle();
        expect(find.text(s.aiPermission), findsOneWidget);
        await tester.tap(find.text(s.decline));
        await tester.pumpAndSettle();
        expect(d.companion.sending, isFalse);
        expect(find.text('Keep this draft'), findsOneWidget);
        await tester.tap(find.byTooltip(s.sendMessage));
        await tester.pumpAndSettle();
        await tester.tap(find.text(s.aiAllow));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text(s.assistantListening), findsOneWidget);
        expect(d.companion.sending, isTrue);
        reply.complete(
          http.Response(
            'event: token\ndata: {"text":"A thoughtful reply."}\n\n'
            'event: done\ndata: {"message_id":"motion-reply"}\n\n',
            200,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('A thoughtful reply.'), findsOneWidget);
        expect(find.text(s.assistantListening), findsNothing);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
        await tester.dragFrom(const Offset(4, 300), const Offset(350, 0));
        await tester.pumpAndSettle();
        expect(find.byType(NavigationBar), findsOneWidget);
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('guardian-talk-career')),
        );
        await tester.tap(find.byKey(const ValueKey('guardian-talk-career')));
        await tester.pumpAndSettle();
        expect(d.companion.selected.name, 'career');
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        d.dispose();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('the first visible frame includes the decoded home artwork', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      // Asset decoding uses real engine I/O rather than the widget fake clock.
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({'fate.locale': 'zh'});
        final dependencies = AppDependencies(
          await SharedPreferences.getInstance(),
          client: ApiClient(
            'https://api.example.test',
            client: MockClient(
              (_) async => http.Response('{"modules":[]}', 200),
            ),
          ),
          secureStore: MemorySessionStore(),
        );
        final bundle = DelayedHeroBundle();
        final bytes = await rootBundle.load(homeHeroImage.assetName);
        final decoded = Completer<void>();
        late ImageStream stream;
        final listener = ImageStreamListener((image, _) {
          image.dispose();
          if (!decoded.isCompleted) decoded.complete();
        });
        stream = homeHeroImage.resolve(ImageConfiguration(bundle: bundle));
        stream.addListener(listener);
        await bundle.requested.future.timeout(const Duration(seconds: 5));
        await tester.pumpWidget(
          DefaultAssetBundle(
            bundle: bundle,
            child: DependencyScope(
              dependencies: dependencies,
              child: FateApp(dependencies: dependencies),
            ),
          ),
        );
        await tester.pump();
        expect(bundle.requested.isCompleted, isTrue);
        expect(tester.binding.sendFramesToEngine, isFalse);

        bundle.bytes.complete(bytes);
        await decoded.future.timeout(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(tester.binding.sendFramesToEngine, isTrue);
        final hero = find.byWidgetPredicate(
          (widget) => widget is Image && widget.image == homeHeroImage,
        );
        final heroFrame = find.descendant(
          of: hero,
          matching: find.byType(RawImage),
        );
        expect(tester.widget<RawImage>(heroFrame).image, isNotNull);
        expect(tester.takeException(), isNull);
        stream.removeListener(listener);
        await tester.pumpWidget(const SizedBox.shrink());
        dependencies.dispose();
      });
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
  testWidgets(
    'five-tab navigation keeps companions, tools, and existing readings reachable',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'fate.locale': 'en'});
      final requests = <String>[];
      final api = ApiClient(
        'https://api.example.test',
        client: MockClient((request) async {
          requests.add(request.url.path);
          if (request.url.path == '/api/thai-calendar/today') {
            return http.Response(
              jsonEncode({
                'date': '2026-11-09',
                'buddhist_year': 2569,
                'lunar': {
                  'phase': 'waning',
                  'day': 14,
                  'month': 11,
                  'second_eighth_month': false,
                },
                'day_kind': 'mixed',
                'auspicious_hours': [
                  {'start': '08:24', 'end': '10:48'},
                  {'start': '15:36', 'end': '18:00'},
                ],
                'refresh_after_seconds': 3600,
              }),
              200,
            );
          }
          if (request.url.path == '/api/daily-horoscope/today') {
            return http.Response(
              jsonEncode({
                'date': '2026-11-09',
                'signs': [
                  for (var sign = 0; sign < 12; sign++)
                    {
                      'sign': sign,
                      'scores': {
                        'love': 80 + sign,
                        'work': 67,
                        'money': 73,
                        'health': 76,
                      },
                      'highlight': {
                        'topic': 'love',
                        'tone': 'supportive',
                        'planet': 'venus',
                        'house': sign + 1,
                      },
                    },
                ],
                'refresh_after_seconds': 3600,
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'modules': [
                {'id': 'western_astrology', 'status': 'planned'},
              ],
              'app_capabilities': {'apple_login': true},
              'account_login': true,
            }),
            200,
          );
        }),
      );
      final d = AppDependencies(
        await SharedPreferences.getInstance(),
        client: api,
        secureStore: MemorySessionStore(),
      );
      await tester.pumpWidget(
        DependencyScope(
          dependencies: d,
          child: FateApp(dependencies: d),
        ),
      );
      await d.session.initialize();
      await tester.pumpAndSettle();
      expect(find.byType(NavigationDestination), findsNWidgets(5));
      final s = AppLocalizationsEn();
      expect(find.text(s.todayQuestion), findsOneWidget);
      expect(find.byKey(const ValueKey('home-entry-purchase')), findsNothing);
      expect(find.text(s.thaiGuide), findsWidgets);
      expect(find.text(s.loveGuardian), findsOneWidget);
      expect(find.text(s.careerGuardian), findsOneWidget);
      expect(find.text(s.wealthGuardian), findsOneWidget);
      expect(find.text(s.wellbeingGuardian), findsOneWidget);
      await tester.ensureVisible(find.text(s.dailyHoroscopeTitle));
      expect(find.text(s.dailyHoroscopeTitle).hitTestable(), findsOneWidget);
      expect(find.widgetWithText(ListTile, s.reports), findsOneWidget);
      for (final title in [
        s.thaiCalendarTitle,
        s.chart,
        s.birth,
        s.luckyNumbers,
        s.start,
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      await tester.ensureVisible(
        find.byKey(const ValueKey('guardian-talk-wealth')),
      );
      await tester.tap(find.byKey(const ValueKey('guardian-talk-wealth')));
      await tester.pumpAndSettle();
      expect(d.companion.selected.name, 'wealth');
      expect(find.text(s.chatProfileNeeded), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavigationDestination).at(4));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(s.bondNav));
      await tester.tap(find.text(s.bondNav));
      await tester.pumpAndSettle();
      expect(find.text(s.bondTitle), findsOneWidget);
      expect(find.text(s.bondNew), findsNWidgets(4));
      await tester.tap(find.byType(NavigationDestination).at(0));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(s.thaiCalendarMixed));
      expect(find.text(s.thaiCalendarWaning(14)), findsOneWidget);
      expect(find.text(s.thaiCalendarMixed), findsOneWidget);
      expect(find.textContaining('08:24–10:48'), findsOneWidget);
      expect(find.text(s.dailyHoroscopeTitle), findsOneWidget);
      expect(find.text(s.dailyHoroscopeToday(s.zAries)), findsNothing);
      expect(requests, isNot(contains('/api/daily-horoscope/today')));
      final horoscope = find.text(s.dailyHoroscopeChooseSign);
      await tester.ensureVisible(horoscope);
      await tester.tap(horoscope);
      await tester.pumpAndSettle();
      expect(find.text(s.dailyHoroscopeTitle), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('80'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('daily-zodiac-1')));
      await tester.pumpAndSettle();
      expect(find.text('81'), findsOneWidget);
      expect(find.textContaining('Venus transits house 2.'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text(s.dailyHoroscopeToday(s.zTaurus)), findsOneWidget);
      expect(find.text('81'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getInt('fate.daily_zodiac'),
        1,
      );
      await tester.tap(find.byType(NavigationDestination).at(4));
      await tester.pumpAndSettle();
      expect(find.text(s.purchaseCenter), findsNothing);
      final login = find.widgetWithText(ListTile, s.optionalLogin);
      await tester.ensureVisible(login);
      await tester.tap(login);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('h5-code-input')), findsOneWidget);
      expect(find.text(s.appleLogin), findsNothing);
      expect(find.text(s.appleLoginUnavailable), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(s.fortunePeriods));
      await tester.tap(find.text(s.fortunePeriods));
      await tester.pumpAndSettle();
      expect(find.text(s.dailyHoroscopeToday(s.zTaurus)), findsOneWidget);
      expect(find.text('81'), findsOneWidget);

      await d.session.saveProfile(
        const BirthProfile(
          date: '1995-02-03',
          timezone: 'Asia/Bangkok',
          place: 'Bangkok',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(s.dailyHoroscopeToday(s.zAquarius)), findsOneWidget);
      expect(find.text('90'), findsOneWidget);
      final more = find.widgetWithText(TextButton, s.dailyHoroscopeMore);
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.text('90'), findsOneWidget);
      final aquarius = find.byKey(const ValueKey('daily-zodiac-10'));
      final pisces = find.byKey(const ValueKey('daily-zodiac-11'));
      await tester.tap(pisces);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tap(aquarius);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tap(pisces);
      await tester.pumpAndSettle();
      expect(find.text('91'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text(s.dailyHoroscopeToday(s.zAquarius)), findsOneWidget);
      await d.session.clearBirth();
      await tester.pumpAndSettle();
      expect(find.text(s.dailyHoroscopeToday(s.zTaurus)), findsOneWidget);

      final tarot = find.text(s.tarot);
      await tester.ensureVisible(tarot);
      await tester.tap(tarot);
      await tester.pumpAndSettle();
      expect(find.text(s.tarotDrawHint), findsOneWidget);
      final tarotLabels = {for (var i = 1; i <= 30; i++) s.tarotChooseCard(i)};
      for (var drawn = 0; drawn < 3; drawn++) {
        final visibleCard = find
            .byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  tarotLabels.contains(widget.properties.label),
            )
            .hitTestable()
            .last;
        await tester.tap(visibleCard);
        await tester.pumpAndSettle();
        expect(find.text(s.tarotProgress(drawn + 1, 3)), findsOneWidget);
      }
      expect(find.text(s.tarotResult), findsOneWidget);
      final drawAgain = find.widgetWithText(TextButton, s.tarotDrawAgain);
      await tester.ensureVisible(drawAgain);
      await tester.tap(drawAgain);
      await tester.pumpAndSettle();
      expect(find.text(s.tarotDrawHint), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      final luckyNumbers = find.text(s.luckyNumbers);
      await tester.ensureVisible(luckyNumbers);
      await tester.tap(luckyNumbers);
      await tester.pumpAndSettle();
      expect(find.text(s.todayLuckyNumber), findsOneWidget);
      final today = DateTime.now();
      final number = (today.year + today.month + today.day - 1) % 9 + 1;
      expect(find.text('$number'), findsOneWidget);

      await tester.tap(find.byType(NavigationDestination).at(4));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(s.fortunePeriods));
      await tester.tap(find.text(s.fortunePeriods));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(s.chart));
      await tester.tap(find.text(s.chart));
      await tester.pumpAndSettle();
      expect(find.text(AppLocalizationsEn().birthIntro), findsOneWidget);
      expect(find.text(AppLocalizationsEn().birthStorage), findsOneWidget);
      final example = find.text(AppLocalizationsEn().example);
      await tester.ensureVisible(example);
      await tester.tap(example);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('not calculated from your birth details'),
        findsOneWidget,
      );
      final read = find.widgetWithText(FilledButton, s.chartRead);
      await tester.ensureVisible(read);
      await tester.tap(read);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('unlock-report')), findsNothing);
      expect(find.byKey(const ValueKey('unlocked-reading')), findsOneWidget);
      expect(find.text(s.storeBuy), findsNothing);
      expect(d.reports.report, isNull);
      expect(d.purchaseRepository.intent, isNull);
      expect(
        requests.toSet(),
        unorderedEquals([
          '/api/config',
          '/api/thai-calendar/today',
          '/api/daily-horoscope/today',
        ]),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      d.dispose();
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );
  testWidgets(
    'Thai review build opens the Thai chart and redirects hidden feature routes',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'fate.locale': 'en'});
      final requests = <http.Request>[];
      final d = AppDependencies(
        await SharedPreferences.getInstance(),
        client: ApiClient(
          'https://api.example.test',
          client: MockClient((request) async {
            requests.add(request);
            final response = switch (request.url.path) {
              '/api/config' => {
                'guest_reading': true,
                'modules': [
                  {'id': 'thai_astrology', 'status': 'ready'},
                  {'id': 'western_astrology', 'status': 'ready'},
                ],
                'app_capabilities': {'western_reports': true},
              },
              '/api/thai-chart/preview' => {
                'status': 'ready',
                'chart': {
                  'points': {
                    'ascendant': {'signName': 'Aries', 'degrees': 12.5},
                  },
                },
              },
              _ => null,
            };
            return http.Response(
              jsonEncode(response),
              response == null ? 404 : 200,
            );
          }),
        ),
        secureStore: MemorySessionStore(),
        thaiAstrologyOnly: true,
      );
      await d.session.initialize();
      await d.session.saveProfile(
        const BirthProfile(
          date: '1990-01-01',
          time: '12:00',
          timezone: 'Asia/Bangkok',
          place: 'Bangkok, TH',
          countryCode: 'TH',
        ),
      );
      await tester.pumpWidget(
        DependencyScope(
          dependencies: d,
          child: FateApp(dependencies: d, playOpening: true),
        ),
      );
      await tester.pumpAndSettle();
      final chart = find.byType(ThaiChartPage);
      final router = GoRouter.of(tester.element(chart));
      final s = AppLocalizationsEn();
      expect(find.text('Aries  12.5°'), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(2));
      expect(find.byType(HomePage), findsNothing);
      for (final path in [
        '/live',
        '/action',
        '/shop',
        '/divination',
        '/fortune/tarot',
        '/fortune/lucky-numbers',
        '/chart',
        '/reports/h5/old',
        '/profile',
        '/login',
        '/purchases',
      ]) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/fortune');
        expect(chart, findsOneWidget);
      }
      router.go('/more');
      await tester.pumpAndSettle();
      expect(find.text(s.language), findsOneWidget);
      expect(find.text(s.recoverReports), findsNothing);
      expect(find.text(s.optionalLogin), findsNothing);
      expect(find.text(s.shopOrders), findsNothing);
      router.go('/privacy');
      await tester.pumpAndSettle();
      expect(find.text(s.thaiBirthStorage), findsOneWidget);
      expect(find.text(s.clearBirth), findsOneWidget);
      expect(find.text(s.deleteAccount), findsNothing);
      expect(requests.map((request) => request.url.path).toSet(), {
        '/api/config',
        '/api/thai-chart/preview',
      });
      await tester.pumpWidget(const SizedBox.shrink());
      d.dispose();
    },
  );
  testWidgets(
    'action suggestions and custom tasks fill an offering once per completion',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'fate.locale': 'en'});
      final preferences = await SharedPreferences.getInstance();
      final d = AppDependencies(
        preferences,
        client: ApiClient(
          'https://api.example.test',
          client: MockClient((_) async => http.Response('{}', 404)),
        ),
        secureStore: MemorySessionStore(),
      );
      final s = AppLocalizationsEn();
      await tester.pumpWidget(
        DependencyScope(
          dependencies: d,
          child: MaterialApp(
            theme: fateTheme(),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: ActionPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(s.offeringJasmine), findsOneWidget);
      expect(find.text('0 / 100'), findsOneWidget);

      await tester.tap(find.text(s.actionDailySuggestion));
      await tester.pumpAndSettle();
      final done = find.widgetWithText(CheckboxListTile, s.actionCompleted);
      await tester.ensureVisible(done);
      await tester.tap(done);
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      final owner = d.session.owner;
      final plan = d.actions.plans(owner).single;
      expect(plan.id, startsWith('daily-'));
      expect(plan.done, isTrue);
      expect(plan.readyOn(DateUtils.dateOnly(DateTime.now())), isTrue);
      expect(find.text('20 / 100'), findsOneWidget);

      await tester.tap(find.text(s.actionCustomPlan));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Water the basil');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      final custom = d.actions.plans(owner).first;
      expect(custom.title, 'Water the basil');
      expect(custom.done, isFalse);
      expect(d.actions.energyFor(owner), 20);

      for (var i = 0; i < 3; i++) {
        await d.actions.save(
          owner,
          ActionPlan(
            id: 'completed-fixture-$i',
            title: 'Completed action $i',
            category: 0,
            beneficiary: 0,
            date: plan.date,
            reviewDate: plan.reviewDate,
            notes: '',
            reflection: '',
            done: true,
            reviewed: false,
          ),
        );
      }
      await tester.pumpAndSettle();
      expect(find.text('80 / 100'), findsOneWidget);
      final completeButton = find.widgetWithText(
        FilledButton,
        s.actionCompleteNow,
      );
      await tester.scrollUntilVisible(completeButton.hitTestable(), 155);
      await tester.pumpAndSettle();
      await tester.tap(completeButton.hitTestable());
      await tester.pump();
      expect(d.actions.energyFor(owner), 100);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 820));
      final fill = find.byWidgetPredicate(
        (widget) =>
            widget is LinearProgressIndicator &&
            widget.semanticsLabel == s.offeringEnergy,
      );
      expect(
        tester.widget<LinearProgressIndicator>(fill).value,
        inExclusiveRange(.8, 1.0),
      );
      await tester.pump(const Duration(milliseconds: 680));
      expect(find.text('100 / 100'), findsOneWidget);
      expect(find.text(s.offeringPresenting), findsOneWidget);
      expect(find.text(s.offeringBlessing), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('100 / 100'), findsOneWidget);
      expect(find.text(s.offeringComplete), findsOneWidget);
      expect(find.text(s.offeringBlessing), findsOneWidget);

      await d.actions.complete(owner, custom.id);
      final reloaded = ActionLedger(LocalDraftStore(preferences));
      expect(reloaded.energyFor(owner), 100);
      expect(reloaded.energyFor('another-owner'), 0);
      reloaded.dispose();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      d.dispose();
    },
  );
  testWidgets(
    'birth form uses Gregorian dates and removes name and timezone fields',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'fate.locale': 'en'});
      final api = ApiClient(
        'https://api.example.test',
        client: MockClient((_) async => http.Response('{"modules":[]}', 200)),
      );
      final d = AppDependencies(
        await SharedPreferences.getInstance(),
        client: api,
        secureStore: MemorySessionStore(),
      );
      final s = AppLocalizationsEn();
      await tester.pumpWidget(
        DependencyScope(
          dependencies: d,
          child: FateApp(dependencies: d),
        ),
      );
      await d.session.initialize();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavigationDestination).at(4));
      await tester.pumpAndSettle();
      final start = find.widgetWithText(TextButton, s.birth);
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(find.text('Preferred name (optional)'), findsNothing);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      final choose = find.widgetWithText(OutlinedButton, s.chooseBirthDate);
      await tester.ensureVisible(choose);
      await tester.tap(choose);
      await tester.pumpAndSettle();
      expect(find.text('Buddhist Era'), findsNothing);
      expect(find.text(s.calendarGregorian), findsOneWidget);
      expect(tester.takeException(), isNull);
      final done = find.widgetWithText(FilledButton, s.pickerDone);
      expect(done, findsOneWidget);
      await tester.tap(done);
      await tester.pumpAndSettle();
      expect(find.text('1999-01-01'), findsOneWidget);
      expect(d.session.profile, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      d.dispose();
    },
  );
}
