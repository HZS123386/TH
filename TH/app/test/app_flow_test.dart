import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fate_app/app/dependencies.dart';
import 'package:fate_app/app/fate_app.dart';
import 'package:fate_app/core/models/birth_profile.dart';
import 'package:fate_app/core/network/api_client.dart';
import 'package:fate_app/core/storage/session_store.dart';
import 'package:fate_app/l10n/generated/app_localizations_en.dart';
import 'package:fate_app/features/home/home_page.dart';

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
    'home opens the horoscope, tarot, daily number, and chart example',
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
      expect(find.byType(NavigationDestination), findsNWidgets(4));
      final s = AppLocalizationsEn();
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

      await tester.tap(find.byType(NavigationDestination).at(1));
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
      final read = find.widgetWithText(FilledButton, 'Read this chart');
      await tester.ensureVisible(read);
      await tester.tap(read);
      await tester.pumpAndSettle();
      final unlock = find.byKey(const ValueKey('unlock-report'));
      expect(unlock, findsOneWidget);
      await tester.tap(unlock);
      await tester.pumpAndSettle();
      final nativeBuy = find.widgetWithText(
        FilledButton,
        'Purchase in the iOS app',
      );
      expect(tester.widget<FilledButton>(nativeBuy).onPressed, isNull);
      final preview = find.textContaining(AppLocalizationsEn().previewFull);
      expect(preview, findsOneWidget);
      await tester.ensureVisible(preview);
      await tester.tap(preview);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('unlock-report')), findsNothing);
      expect(d.reports.report, isNull);
      expect(d.purchaseRepository.intent, isNull);
      expect(
        requests,
        unorderedEquals([
          '/api/config',
          '/api/thai-calendar/today',
          '/api/daily-horoscope/today',
        ]),
      );
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
      final start = find.widgetWithText(OutlinedButton, s.start);
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
