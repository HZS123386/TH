import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fate_h5/app/controller.dart';
import 'package:fate_h5/app/h5_app.dart';
import 'package:fate_h5/app/languages.dart';
import 'package:fate_h5/core/repository.dart';
import 'package:fate_h5/features/landing_page.dart';
import 'support.dart';

void main() {
  test('fresh and unsupported entry languages default to Thai', () {
    expect(h5Language(null), 'th');
    expect(h5Language('unsupported'), 'th');
    for (final option in h5Languages) {
      expect(h5Language(option.$1), option.$1);
    }
  });

  testWidgets(
    'the language menu has nine unique choices and preserves the entry parameters',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final browser = TestBrowser();
      final repo = ReportRepository(browser);
      final h5 = H5Controller(translations(), repo, browser);
      expect(h5.language, 'th');
      await tester.pumpWidget(
        H5App(controller: h5, initialLocation: '/?topic=love&startup=1'),
      );
      await tester.pumpAndSettle();
      expect(h5Languages.map((option) => option.$1).toSet(), hasLength(9));
      expect(h5Languages.map((option) => option.$2).toSet(), hasLength(9));
      for (final language in [
        'en',
        'vi',
        'my',
        'km',
        'lo',
        'ms',
        'id',
        'zh',
        'th',
      ]) {
        await tester.ensureVisible(find.byKey(const ValueKey('language-menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('language-menu')));
        await tester.pumpAndSettle();
        expect(find.byType(PopupMenuItem<String>), findsNWidgets(9));
        for (final option in h5Languages) {
          expect(
            find.byKey(ValueKey('language-option-${option.$1}')),
            findsOneWidget,
          );
        }
        await tester.tap(find.byKey(ValueKey('language-option-$language')));
        await tester.pumpAndSettle();
        expect(h5.language, language);
        expect(repo.language, language);
        final uri = GoRouter.of(
          tester.element(find.byType(LandingPage)),
        ).routeInformationProvider.value.uri;
        expect(uri.queryParameters['lang'], language);
        expect(uri.queryParameters['topic'], 'love');
        expect(uri.queryParameters['startup'], '1');
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );
}
