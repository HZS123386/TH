import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fate_h5/app/controller.dart';
import 'package:fate_h5/app/h5_app.dart';
import 'package:fate_h5/core/models.dart';
import 'package:fate_h5/core/repository.dart';
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
    'returning from a report supplies the saved profile to the HTML form',
    (tester) async {
      final browser = TestBrowser();
      final controller = H5Controller(
        translations(),
        ReportRepository(browser),
        browser,
      );
      controller.restoreLandingFromReport(LifeReport.parse(fixture()));
      await tester.pumpWidget(
        H5App(controller: controller, initialLocation: '/'),
      );
      await tester.pumpAndSettle();
      expect(browser.formInitial?['input'], controller.landingInput);
      expect(browser.formInitial?['place'], controller.landingPlace?.json);
      expect(browser.formVisible, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(browser.formVisible, isFalse);
      controller.dispose();
    },
  );
}
