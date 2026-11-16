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
        expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
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
    'Western-only navigation opens an explicit example and expands only that example',
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
      expect(
        find.byKey(const ValueKey('app-bottom-navigation')),
        findsOneWidget,
      );
      expect(find.text('Tarot'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('app-nav/chart')));
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
      final read = find.widgetWithText(
        FilledButton,
        AppLocalizationsEn().chartRead,
      );
      await tester.ensureVisible(read);
      await tester.tap(read);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reading-chart')), findsOneWidget);
      expect(find.byKey(const ValueKey('reading-back')), findsOneWidget);
      expect(find.byKey(const ValueKey('app-bottom-navigation')), findsNothing);
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
      expect(requests, equals(['/api/config']));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('app-bottom-navigation')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('standalone-chart-reading')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('app-nav/profile')));
      await tester.pumpAndSettle();
      final history = find.byKey(const ValueKey('profile-reading-history'));
      await tester.ensureVisible(history);
      await tester.tap(history);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('standalone-chart-reading')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('app-bottom-navigation')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      d.dispose();
    },
  );
  testWidgets(
    'account language row opens a dialog and saves the selected language',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'fate.locale': 'en'});
      final preferences = await SharedPreferences.getInstance();
      final d = AppDependencies(
        preferences,
        client: ApiClient(
          'https://api.example.test',
          client: MockClient((_) async => http.Response('{"modules":[]}', 200)),
        ),
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
      await tester.tap(find.byKey(const ValueKey('app-nav/profile')));
      await tester.pumpAndSettle();
      final language = find.byKey(const ValueKey('profile-language'));
      await tester.ensureVisible(language);
      await tester.tap(language);
      await tester.pumpAndSettle();
      expect(find.byType(SimpleDialog), findsOneWidget);
      for (final code in ['th', 'en', 'zh', 'vi']) {
        expect(find.byKey(ValueKey('language-option-$code')), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('language-option-zh')));
      await tester.pumpAndSettle();
      expect(find.byType(SimpleDialog), findsNothing);
      expect(d.session.locale.languageCode, 'zh');
      expect(preferences.getString('fate.locale'), 'zh');
      await tester.tap(language);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('language-option-zh')),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pumpAndSettle();
      expect(find.byType(SimpleDialog), findsNothing);
      expect(d.session.locale.languageCode, 'zh');
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
