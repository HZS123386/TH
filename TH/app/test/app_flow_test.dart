import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart' show CupertinoPicker;
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
import 'package:fate_app/features/account/account_page.dart';
import 'package:fate_app/features/account/birth_page.dart';
import 'package:fate_app/features/actions/action_ledger.dart';
import 'package:fate_app/features/actions/action_page.dart';
import 'package:fate_app/features/chart/thai_chart_page.dart';
import 'package:fate_app/features/chart/thai_rasi_wheel.dart';
import 'package:fate_app/features/reports/h5_report_page.dart';
import 'package:fate_app/features/reports/reports_page.dart';
import 'package:fate_app/l10n/generated/app_localizations.dart';
import 'package:fate_app/l10n/generated/app_localizations_en.dart';
import 'package:fate_app/features/home/home_page.dart';
import 'package:fate_app/features/home/thai_home_page.dart';
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
    'route content has an opaque surface on push, back, and tab changes',
    (tester) async {
      SharedPreferences.setMockInitialValues({'fate.locale': 'en'});
      final d = AppDependencies(
        await SharedPreferences.getInstance(),
        secureStore: MemorySessionStore(),
        client: ApiClient(
          'https://api.example.test',
          client: MockClient((_) async => http.Response('{}', 200)),
        ),
        thaiAstrologyOnly: true,
      );
      await tester.pumpWidget(
        DependencyScope(
          dependencies: d,
          child: FateApp(dependencies: d),
        ),
      );
      await tester.pumpAndSettle();

      void expectOpaqueSurface(Finder page) {
        final viewport = find.byWidget(
          Navigator.of(tester.element(page)).widget,
        );
        final surface = find.ancestor(
          of: page,
          matching: find.descendant(
            of: viewport,
            matching: find.byWidgetPredicate((widget) {
              final decoration = widget is DecoratedBox
                  ? widget.decoration
                  : null;
              return decoration is BoxDecoration &&
                  decoration.gradient?.colors.every((color) => color.a == 1) ==
                      true;
            }),
          ),
        );
        expect(surface, findsOneWidget);
        expect(tester.getSize(surface), tester.getSize(viewport));
        expect(
          find.ancestor(of: page, matching: find.byType(FadeTransition)),
          findsNothing,
        );
      }

      final s = AppLocalizationsEn();
      await tester.tap(find.widgetWithText(NavigationDestination, s.mine));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, s.birth));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final birth = find.byType(BirthPage);
      expect(
        ModalRoute.of(tester.element(birth))!.animation!.isAnimating,
        isTrue,
      );
      expectOpaqueSurface(birth);

      await d.session.changeReduceMotion(true);
      await tester.pump();
      expectOpaqueSurface(birth);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      expectOpaqueSurface(find.byType(AccountPage));
      await tester.pumpAndSettle();

      await d.session.changeReduceMotion(false);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(NavigationDestination, s.home));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expectOpaqueSurface(find.byType(ThaiHomePage));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      d.dispose();
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );

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
      // A new destination must win even when the previous transition is unfinished.
      for (final index in [4, 1, 0, 4, 0]) {
        await tester.tap(find.byType(NavigationDestination).at(index));
        await tester.pump(const Duration(milliseconds: 35));
      }
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      expect(find.text(s.todayQuestion), findsOneWidget);
      expect(tester.takeException(), isNull);
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
    'Thai review build saves from Home and shows a localized personal chart',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      SharedPreferences.setMockInitialValues({'fate.locale': 'en'});
      final requests = <http.Request>[];
      Iterable<String> requestedThaiBirthTimes() => requests
          .where((request) => request.url.path == '/api/thai-chart/preview')
          .map((request) => jsonDecode(request.body)['birth_time'] as String);
      Iterable<http.Request> readingRequests() =>
          requests.where((request) => request.url.path == '/api/thai-reading');
      var chartReady = false;
      const otherThaiPointNames = {
        'sun': 'อาทิตย์',
        'mars': 'อังคาร',
        'mercury': 'พุธ',
        'jupiter': 'พฤหัสบดี',
        'venus': 'ศุกร์',
        'saturn': 'เสาร์',
        'rahu': 'ราหู',
        'ketu': 'เกตุ',
        'uranus': 'มฤตยู',
      };
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
              '/api/landing/config' => {
                'support_email': 'support@example.test',
              },
              '/api/thai-locations' => {
                'items': [
                  {
                    'id': 'geonames:1609350',
                    'countryCode': 'TH',
                    'nameEnglish': 'Bangkok',
                    'nameChinese': '曼谷',
                    'timeZone': 'Asia/Bangkok',
                    'latitude': 13.75,
                    'longitude': 100.5,
                  },
                ],
              },
              '/api/thai-chart/preview' => {
                'status': 'ready',
                'chart': chartReady
                    ? {
                        'charts': {
                          'rasi': {
                            'channels': {
                              'thai': [
                                'ลั',
                                '',
                                '',
                                '',
                                '',
                                '',
                                '',
                                '๑๓๔๕*๖๗๘๙๐',
                                '',
                                '',
                                '',
                                '๒',
                              ],
                              'arabic': [
                                'ลั',
                                '',
                                '',
                                '',
                                '',
                                '',
                                '',
                                '1345*67890',
                                '',
                                '',
                                '',
                                '2',
                              ],
                            },
                          },
                        },
                        'points': {
                          'ascendant': {
                            'sign': 0,
                            'signName': 'เมษ',
                            'degrees': 12.5,
                          },
                          'moon': {
                            'sign': 11,
                            'signName': 'มีน',
                            'degrees': 5.4,
                          },
                          for (final point in otherThaiPointNames.entries)
                            point.key: {
                              'nameThai': point.value,
                              'sign': 7,
                              'signName': 'พิจิก',
                              'degrees': 10,
                            },
                        },
                      }
                    : 'invalid response',
              },
              '/api/thai-reading' => {
                'input': jsonDecode(request.body),
                'report': {
                  'language': 'en',
                  'summary': 'Choose one practical priority for the year.',
                  'generation': {'state': 'ready'},
                  'sections': [
                    {
                      'id': 'interpretation',
                      'title': 'What your chart suggests',
                      'items': [
                        {
                          'title': 'Review your commitments',
                          'text': 'Make room for the work you most value.',
                          'period': {'year': 2027, 'month': 7},
                        },
                      ],
                    },
                    for (final id in ['opportunities', 'advice'])
                      {
                        'id': id,
                        'title': 'More about $id',
                        'items': [
                          {
                            'title': 'Keep your next step simple',
                            'text':
                                'Choose an action you can realistically take.',
                          },
                        ],
                      },
                  ],
                },
              },
              _ => null,
            };
            return http.Response(
              jsonEncode(response),
              response == null ? 404 : 200,
              headers: {'content-type': 'application/json; charset=utf-8'},
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
          timezone: 'Asia/Bangkok',
          place: 'Bangkok, TH',
          placeId: 'geonames:1609350',
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
      final home = find.byType(ThaiHomePage);
      final chart = find.byType(ThaiChartPage);
      final wheel = find.byType(ThaiRasiWheel);
      final router = GoRouter.of(tester.element(home));
      final s = AppLocalizationsEn();
      expect(router.routeInformationProvider.value.uri.path, '/home');
      expect(find.byType(NavigationDestination), findsNWidgets(3));
      expect(find.text(s.thaiSampleChart), findsOneWidget);
      expect(tester.widget<ThaiRasiWheel>(wheel).data, ThaiRasiData.example);
      expect(
        tester.getTopLeft(wheel).dy,
        lessThan(tester.getTopLeft(find.text(s.birth)).dy),
      );
      tester.view.physicalSize = const Size(744, 1133);
      await tester.pumpAndSettle();
      expect(
        tester.getTopRight(wheel).dx,
        lessThan(tester.getTopLeft(find.text(s.birth)).dx),
      );

      tester.view.physicalSize = const Size(568, 320);
      tester.view.padding = const FakeViewPadding(
        left: 44,
        right: 44,
        bottom: 21,
      );
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pumpAndSettle();
      final dateButton = find.widgetWithText(OutlinedButton, '1990-01-01');
      await tester.ensureVisible(dateButton);
      expect(tester.getRect(dateButton).left, greaterThan(44));
      expect(tester.getRect(dateButton).right, lessThan(568 - 44));
      await tester.tap(dateButton);
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoPicker), findsNWidgets(3));
      final done = find.widgetWithText(FilledButton, s.pickerDone);
      await tester.ensureVisible(done);
      await tester.tap(done);
      await tester.pumpAndSettle();
      expect(dateButton, findsOneWidget);
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(430, 932);
      tester.view.resetPadding();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.pumpAndSettle();
      expect(requestedThaiBirthTimes(), isEmpty);
      final save = find.widgetWithText(FilledButton, s.saveBirth);
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/chart/thai');
      expect(chart, findsOneWidget);
      expect(find.text(s.error), findsOneWidget);
      expect(requestedThaiBirthTimes(), ['12:00']);
      chartReady = true;
      await tester.tap(find.widgetWithText(TextButton, s.retry));
      await tester.pumpAndSettle();
      expect(requestedThaiBirthTimes(), ['12:00', '12:00']);
      expect(find.text(s.estimatedChart), findsOneWidget);
      expect(find.text(s.thaiEstimatedChartNote), findsOneWidget);
      expect(tester.widget<ThaiRasiWheel>(wheel).data.arabic.first, 'ลั');
      expect(find.text(s.myChart), findsOneWidget);
      final chartPositions = find.text(s.thaiChartPositions);
      expect(
        tester.getTopLeft(wheel).dy,
        lessThan(tester.getTopLeft(chartPositions).dy),
      );
      expect(
        tester.getTopLeft(chartPositions).dy,
        lessThan(tester.getTopLeft(find.text(s.thaiReadingTitle)).dy),
      );
      expect(find.text(s.thaiReadingNeedsTime), findsOneWidget);
      expect(find.text(s.consentGenerate), findsNothing);
      expect(readingRequests(), isEmpty);
      expect(find.text('Aries  12.5°'), findsOneWidget);
      expect(find.text(s.moon), findsOneWidget);
      final back = find.byType(BackButton);
      expect(back, findsOneWidget);
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(home, findsOneWidget);
      expect(find.text('1990-01-01'), findsOneWidget);
      expect(find.text(s.unknownTime), findsOneWidget);
      expect(find.text(s.example), findsNothing);
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(chart, findsOneWidget);
      expect(find.text(s.estimatedChart), findsOneWidget);
      expect(d.session.profiles.local(d.session.owner)?.time, isNull);

      await d.session.saveProfile(
        const BirthProfile(
          date: '1990-01-01',
          time: '09:45',
          timezone: 'Asia/Bangkok',
          place: 'Bangkok, TH',
          placeId: 'geonames:1609350',
          countryCode: 'TH',
        ),
      );
      router.go('/fortune');
      await tester.pumpAndSettle();
      expect(requestedThaiBirthTimes().last, '09:45');
      expect(find.text(s.estimatedChart), findsNothing);
      expect(find.text('Aries  12.5°'), findsOneWidget);
      for (final title in [
        s.thaiReadingOverview,
        s.thaiReadingWork,
        s.thaiReadingMoney,
        s.thaiReadingLove,
        s.thaiReadingFamily,
        s.thaiReadingAnnual,
      ]) {
        expect(find.widgetWithText(ChoiceChip, title), findsOneWidget);
      }
      expect(readingRequests(), isEmpty);
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pumpAndSettle();
      final annual = find.widgetWithText(ChoiceChip, s.thaiReadingAnnual);
      await tester.ensureVisible(annual);
      await tester.pumpAndSettle();
      await tester.tap(annual);
      await tester.pumpAndSettle();
      final year = find.byType(TextFormField);
      await tester.ensureVisible(year);
      await tester.pumpAndSettle();
      await tester.tap(year);
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      await tester.enterText(year, '2027');
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      final generate = find.text(s.consentGenerate);
      await tester.ensureVisible(generate);
      await tester.pumpAndSettle();
      await tester.tap(generate);
      await tester.pumpAndSettle();
      final request = readingRequests().single;
      final input = jsonDecode(request.body) as Map;
      expect(request.headers['Authorization'], isNull);
      expect(input['reading'], 'annual');
      expect(input['year'], 2027);
      expect(input['profile']['birth_time'], '09:45');
      expect(input['profile']['location_id'], 'geonames:1609350');
      expect(
        find.text('Choose one practical priority for the year.'),
        findsOneWidget,
      );
      expect(find.text('July 2027 · Review your commitments'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final chartRequests = requestedThaiBirthTimes().length;
      tester.view.physicalSize = const Size(1366, 1024);
      await tester.pumpAndSettle();
      expect(
        tester.getTopRight(wheel).dx,
        lessThan(tester.getTopLeft(chartPositions).dx),
      );
      expect(find.text('July 2027 · Review your commitments'), findsOneWidget);
      expect(requestedThaiBirthTimes(), hasLength(chartRequests));
      expect(readingRequests(), hasLength(1));
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(430, 932);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.pumpAndSettle();
      expect(find.byType(NavigationDestination), findsNWidgets(3));
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
        expect(router.routeInformationProvider.value.uri.path, '/home');
        expect(home, findsOneWidget);
      }
      router.go('/more');
      await tester.pumpAndSettle();
      expect(find.text(s.language), findsOneWidget);
      expect(find.text(s.settingsBirthSaved), findsOneWidget);
      expect(find.text(s.guest), findsNothing);
      expect(find.text(s.recoverReports), findsNothing);
      expect(find.text(s.optionalLogin), findsNothing);
      expect(find.text(s.shopOrders), findsNothing);
      final birthSettings = find.widgetWithText(ListTile, s.birth);
      await tester.tap(birthSettings);
      await tester.pumpAndSettle();
      expect(find.text(s.birthIntro), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text(s.settingsBirthChart), findsOneWidget);

      final motion = find.widgetWithText(
        SwitchListTile,
        s.settingsReduceMotion,
      );
      await tester.tap(motion);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(motion).value, isTrue);
      expect(MediaQuery.disableAnimationsOf(tester.element(motion)), isTrue);
      expect(
        d.session.drafts.preferences.getBool('fate.reduce_motion'),
        isTrue,
      );
      await tester.tap(motion);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(motion).value, isFalse);
      expect(MediaQuery.disableAnimationsOf(tester.element(motion)), isFalse);

      await tester.tap(find.widgetWithText(ListTile, s.privacyCenter));
      await tester.pumpAndSettle();
      expect(find.text(s.thaiPrivacyLocalPresent), findsOneWidget);
      expect(find.text(s.thaiPrivacyInputBody), findsOneWidget);
      expect(find.text(s.clearBirth), findsOneWidget);
      expect(find.text(s.deleteAccount), findsNothing);
      expect(find.text(s.policyUnavailable), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      final support = find.widgetWithText(ListTile, s.supportTitle);
      await tester.ensureVisible(support);
      await tester.tap(support);
      await tester.pumpAndSettle();
      expect(find.text(s.supportOpenEmail), findsOneWidget);
      expect(find.text(s.copyAddress), findsOneWidget);
      expect(find.text(s.supportFaqHeading), findsOneWidget);
      final timeQuestion = find.text(s.thaiHelpTimeQuestion);
      await tester.ensureVisible(timeQuestion);
      await tester.pumpAndSettle();
      await tester.tap(timeQuestion);
      await tester.pumpAndSettle();
      expect(find.text(s.unknownTime), findsOneWidget);
      final privacy = find.widgetWithText(TextButton, s.privacyCenter);
      await tester.ensureVisible(privacy);
      await tester.pumpAndSettle();
      await tester.tap(privacy);
      await tester.pumpAndSettle();
      expect(find.text(s.thaiPrivacyInputBody), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/more');
      expect(find.widgetWithText(ListTile, s.supportTitle), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, s.language));
      await tester.pumpAndSettle();
      expect(find.byType(SimpleDialog), findsOneWidget);
      await tester.tap(find.text('中文'));
      await tester.pumpAndSettle();
      expect(find.text('偏好设置'), findsOneWidget);
      expect(find.text('减少动态效果'), findsOneWidget);
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      for (final (language, sampleTitle, positionsTitle) in const [
        ('th', 'ตัวอย่างผังดวง', 'ผลการผูกดวง'),
        ('vi', 'Lá số mẫu', 'Kết quả lập lá số'),
        ('zh', '示例星盘', '排盘结果'),
      ]) {
        await d.session.changeLocale(language);
        router.go('/home');
        await tester.pumpAndSettle();
        expect(find.text(sampleTitle), findsOneWidget);
        router.go('/chart/thai');
        await tester.pumpAndSettle();
        expect(find.text(positionsTitle), findsOneWidget);
        expect(tester.takeException(), isNull, reason: language);
      }
      expect(router.routeInformationProvider.value.uri.path, '/chart/thai');
      await tester.pumpAndSettle();
      for (final text in [
        '我的本命星盘',
        '数字是星体代号，升代表上升点。',
        '上升',
        '太阳',
        '月亮',
        '火星',
        '水星',
        '木星',
        '金星',
        '土星',
        '罗睺',
        '计都',
        '天王星',
        '1990-01-01 · 曼谷, 泰国',
        '白羊座  12.5°',
        '双鱼座  5.4°',
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      expect(
        find.descendant(
          of: chart,
          matching: find.textContaining(RegExp(r'[\u0E00-\u0E7F]')),
        ),
        findsNothing,
      );
      tester.view.physicalSize = const Size(430, 932);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      router.go('/privacy');
      await tester.pumpAndSettle();
      final clear = find.widgetWithText(OutlinedButton, '清除本机出生资料');
      await tester.tap(clear);
      await tester.pumpAndSettle();
      expect(d.session.profile, isNotNull);
      await tester.tap(find.widgetWithText(FilledButton, '清除本机出生资料'));
      await tester.pumpAndSettle();
      expect(d.session.profiles.local(d.session.owner), isNull);
      expect(find.text('此设备当前没有保存出生资料。'), findsOneWidget);
      expect(requests.map((request) => request.url.path).toSet(), {
        '/api/config',
        '/api/thai-chart/preview',
        '/api/thai-reading',
        '/api/thai-locations',
        '/api/landing/config',
      });
      await tester.pumpWidget(const SizedBox.shrink());
      d.dispose();
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
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
