import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:fate_app/core/network/api_client.dart';
import 'package:fate_app/data/thai_calendar_repository.dart';
import 'package:fate_app/features/home/thai_calendar_page.dart';
import 'package:fate_app/l10n/generated/app_localizations.dart';
import 'package:fate_app/ui/theme.dart';

class _RetryBundle extends CachingAssetBundle {
  _RetryBundle(this.json);
  final String json;
  bool failed = false;
  @override
  Future<ByteData> load(String key) => throw UnimplementedError();
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (!failed) {
      failed = true;
      throw FlutterError('Offline asset unavailable');
    }
    return json;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ApiClient api;
  setUp(() {
    api = ApiClient(
      'https://unused.example.test',
      client: MockClient((_) async {
        throw StateError(
          'Calendar browsing must not make a business API request',
        );
      }),
    );
  });
  tearDown(() => api.close());

  test(
    'bundled calendar matches the reference date, leap day and Bangkok boundary',
    () async {
      final repository = ThaiCalendarRepository(api);
      final month = await repository.loadMonth(DateTime.utc(2026, 11));
      final reference = month[8];
      expect(month.length, 30);
      expect(reference.day.date, DateTime.utc(2026, 11, 9));
      expect(reference.day.buddhistYear, 2569);
      expect(reference.smallEra, 1388);
      expect(reference.day.lunar, (
        waxing: false,
        day: 14,
        month: 11,
        secondEighthMonth: false,
      ));
      expect(reference.kalayok, [Kalayok.thongchai, Kalayok.lokawinas]);
      expect(reference.day.kind, ThaiDayKind.mixed);
      expect(reference.wanPhra, isTrue);
      expect(reference.riangMon, isTrue);
      expect(reference.day.hours, ['08:24–10:48', '15:36–18:00']);
      expect(reference.mansion.index, 16);
      expect(reference.mansion.quarter, 2);
      expect(month[9].day.lunar!.day, 1);
      expect(month[9].day.lunar!.waxing, isTrue);
      expect(month[9].wanPhra, isFalse);
      final leapMonth = await repository.loadMonth(DateTime.utc(2028, 2));
      expect(leapMonth.last.day.date, DateTime.utc(2028, 2, 29));
      await expectLater(
        repository.loadMonth(DateTime.utc(2031)),
        throwsA(isA<ApiFailure>()),
      );
      expect(
        ThaiCalendarRepository.bangkokToday(
          DateTime.parse('2026-11-14T16:59:59Z'),
        ),
        DateTime.utc(2026, 11, 14),
      );
      expect(
        ThaiCalendarRepository.bangkokToday(
          DateTime.parse('2026-11-14T17:00:00Z'),
        ),
        DateTime.utc(2026, 11, 15),
      );
      final json =
          (jsonDecode(
                    await rootBundle.loadString('assets/calendar/2026.json'),
                  )['days']
                  as List)[8]
              as Map<String, dynamic>;
      expect(() => ThaiCalendarDay.fromJson(json), throwsA(isA<ApiFailure>()));
      expect(
        ThaiCalendarDay.fromJson({
          ...json,
          'refresh_after_seconds': 3600,
        }).refreshAfter,
        const Duration(hours: 1),
      );
    },
  );

  Widget page(
    ThaiCalendarRepository repository,
    DateTime initial, {
    String locale = 'th',
    double scale = 1,
    bool reduced = false,
  }) => MaterialApp(
    theme: fateTheme(),
    locale: Locale(locale),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduced,
        ),
        child: Scaffold(
          body: ThaiCalendarPage(repository: repository, initialDate: initial),
        ),
      ),
    ),
  );

  testWidgets(
    'selecting a date updates all five details on a narrow Thai screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final json = await tester.runAsync(
        () => rootBundle.loadString('assets/calendar/2026.json'),
      );
      final repository = ThaiCalendarRepository(
        api,
        bundle: _RetryBundle(json!)..failed = true,
      );
      await tester.pumpWidget(
        page(repository, DateTime.utc(2026, 11, 9), scale: 1.2, reduced: true),
      );
      await tester.pumpAndSettle();
      for (var i = 1; i <= 5; i++) {
        expect(find.byKey(ValueKey('calendar-detail-0$i')), findsOneWidget);
      }
      expect(find.text('วิสาขะนักษัตรที่ ๑๖'), findsOneWidget);
      expect(find.text('วันจันทร์ที่ 9 พฤศจิกายน 2569'), findsOneWidget);
      expect(find.text('ดิถีเรียงหมอน'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('calendar-day-2026-11-10')));
      await tester.pumpAndSettle();
      expect(find.text('วิสาขะนักษัตรที่ ๑๖'), findsNothing);
      expect(find.text('ดิถีเรียงหมอน'), findsNothing);
      expect(find.text('ไม่ตรงกับดิถีเรียงหมอน'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('calendar-next')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('calendar-day-2026-12-10')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('calendar-today')));
      await tester.pumpAndSettle();
      final today = ThaiCalendarRepository.bangkokToday()
          .toIso8601String()
          .substring(0, 10);
      expect(
        tester
            .widget<Semantics>(find.byKey(ValueKey('calendar-day-$today')))
            .properties
            .selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'month navigation clamps the 31st and respects the asset boundary',
    (tester) async {
      final json = await tester.runAsync(
        () => rootBundle.loadString('assets/calendar/2025.json'),
      );
      final repository = ThaiCalendarRepository(
        api,
        bundle: _RetryBundle(json!)..failed = true,
      );
      await tester.pumpWidget(
        page(repository, DateTime.utc(2025, 1, 31), locale: 'zh'),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('calendar-previous')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('calendar-next')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Semantics>(
              find.byKey(const ValueKey('calendar-day-2025-02-28')),
            )
            .properties
            .selected,
        isTrue,
      );
      expect(find.text('佛历 2568 年 · 公历 2025 年'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'failed calendar load can retry without leaving stale detail cards',
    (tester) async {
      final json = await tester.runAsync(
        () => rootBundle.loadString('assets/calendar/2026.json'),
      );
      final repository = ThaiCalendarRepository(
        api,
        bundle: _RetryBundle(json!),
      );
      await tester.pumpWidget(
        page(repository, DateTime.utc(2026, 11, 9), locale: 'en'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('This month could not be loaded. Please try again.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('calendar-detail-01')), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Vishakha'), findsOneWidget);
      expect(find.byKey(const ValueKey('calendar-detail-05')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
