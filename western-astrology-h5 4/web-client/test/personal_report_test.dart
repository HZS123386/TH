import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fate_h5/app/controller.dart';
import 'package:fate_h5/app/h5_app.dart';
import 'package:fate_h5/core/models.dart';
import 'package:fate_h5/core/repository.dart';
import 'package:fate_h5/features/checkout_dialog.dart';
import 'package:fate_h5/ui/jy_components.dart';

import 'support.dart';

void main() {
  test('free report can open checkout before paid timing is prepared', () {
    final data = personalFixture();
    data['outlook'] = {'state': 'not_started'};
    data['personal'] = {
      ...object(data['personal']),
      'availability': {'full_report': true, 'reason': 'not_started'},
    };
    final report = LifeReport.parse(data);
    expect(report.hasPreview, isTrue);
    expect(report.canPay, isTrue);
    expect(report.full, isFalse);
    expect(report.ready, isFalse);
    expect(report.nodes, isEmpty);
  });
  testWidgets(
    'landing shows three labels next to each of the two illustrations',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final browser = TestBrowser();
      final controller = H5Controller(
        translations(),
        ReportRepository(
          browser,
          client: MockClient(
            (request) async => http.Response(
              '{}',
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        ),
        browser,
        language: 'zh',
      )..enterLanding();
      await tester.pumpWidget(
        H5App(controller: controller, initialLocation: '/?lang=zh'),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.widgetWithText(JYButton, '查看解析'), findsOneWidget);
      final board = find.byType(ThemeBoards);
      for (final label in ['本命解读', '事业**', '财运解读', '感情姻缘', '***预警', '行动建议']) {
        expect(
          find.descendant(of: board, matching: find.text(label)),
          findsOneWidget,
        );
      }
      final artwork = find.descendant(
        of: board,
        matching: find.byType(FateImage),
      );
      expect(artwork, findsNWidgets(2));
      Offset artworkCenter(Finder image) => tester.getCenter(
        find.ancestor(of: image, matching: find.byType(ClipPath)).first,
      );
      final upperImage = artworkCenter(artwork.first);
      final lowerImage = artworkCenter(artwork.last);
      expect(upperImage.dy, lessThan(lowerImage.dy));
      expect(upperImage.dx, lessThan(tester.getCenter(find.text('事业**')).dx));
      expect(
        lowerImage.dx,
        greaterThan(tester.getCenter(find.text('***预警')).dx),
      );
      expect(find.text(controller.copy.t('jy', 'formCaption')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
  for (final full in [false, true]) {
    testWidgets(
      'relationship ${full ? 'full' : 'free'} report displays and exports only the authorized reading',
      (tester) async {
        final freeReading = {
          'judgment': ['反复改约的人让关系始终停在口头承诺上。'],
          'basis': ['水星与金星合相\n你容易把善意的表达当成关系正在推进。'],
        };
        final paidReading = {
          'judgment': ['前任两次取消约定。关系卡在计划一再变动。'],
          'basis': ['水星与火星四分相\n对方改约时，解释越多越容易让你忽略原定安排。'],
        };
        final data = personalFixture(full: true)
          ..['access'] = full ? 'full' : 'preview'
          ..['version'] = 'western-relationship-3'
          ..['catalog'] = [
            {'key': 'judgment', 'title': '判断', 'ready': full},
            {'key': 'basis', 'title': '星盘依据', 'ready': full},
          ]
          ..['progress'] = {'completed': full ? 2 : 0, 'total': 2};
        data['input'] = {
          ...object(data['input']),
          'relationship': {'status': 'single', 'source': 'unspecified'},
        };
        data['personal'] = {
          ...object(data['personal']),
          'relationship_preview_sections': freeReading,
          'relationship_sections': paidReading,
        };
        final browser = TestBrowser();
        final controller = H5Controller(
          translations(),
          ReportRepository(
            browser,
            client: MockClient(
              (request) async => http.Response(
                jsonEncode(data),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              ),
            ),
          ),
          browser,
          language: 'zh',
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          H5App(
            controller: controller,
            initialLocation: '/report.html?id=${data['id']}&lang=zh&checkout=1',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('判断'), findsOneWidget);
        expect(find.text('星盘依据'), findsOneWidget);
        final shown = full ? paidReading : freeReading;
        final hidden = full ? freeReading : paidReading;
        for (final key in relationshipKeys) {
          expect(find.text(shown[key]!.single), findsOneWidget);
          expect(find.text(hidden[key]!.single), findsNothing);
        }
        expect(find.text('Synthetic personal talent.'), findsNothing);
        expect(find.byKey(const ValueKey('personal-signs')), findsNothing);
        final reportCopy = controller.copy.forReport(LifeReport.parse(data));
        final pdf = full
            ? find.byTooltip(reportCopy.t('report', 'exportPdf'))
            : find.ancestor(
                of: find.text(reportCopy.t('life', 'exportPdf')),
                matching: find.bySubtype<OutlinedButton>(),
              );
        await tester.ensureVisible(pdf);
        await tester.tap(pdf);
        await tester.pumpAndSettle();
        expect(browser.exportFormat, 'pdf');
        final exported = object(browser.exported?['personal']);
        expect(exported['relationship_preview_sections'], freeReading);
        expect(exported['relationship_sections'], full ? paidReading : isNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('marriage preview shows a short birth line', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final data = marriageFixture();
    final marriage = object(data['marriage']);
    final preview = objects(marriage['preview']);
    preview.first['paragraphs'] = [
      '1990-05-20 · 10:30 · Asia/Shanghai',
      'Sample City, CN',
      '上升 · 巨蟹座',
      '出生时间说明',
    ];
    const oldTitles = [
      '你的感情里，藏着一个你没发现的“隐形卡点”',
      '接下来的30天，你的感情搅局者正在发力',
      '你一直在被“隐形搅局者”偷偷消耗精力',
      '解锁完整报告，让你不再受搅局者的困扰',
    ];
    for (var i = 0; i < oldTitles.length; i++) {
      preview[i + 1]['title'] = oldTitles[i];
    }
    data['marriage'] = {...marriage, 'preview': preview};
    final browser = TestBrowser();
    final controller = H5Controller(
      translations(),
      ReportRepository(
        browser,
        client: MockClient(
          (request) async => http.Response(
            jsonEncode(data),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      ),
      browser,
      language: 'zh',
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      H5App(
        controller: controller,
        initialLocation: '/report.html?id=${data['id']}&lang=zh',
      ),
    );
    await tester.pumpAndSettle();
    final titles = controller.copy.list('marriage', 'preview');
    final birthDetails = find.text('1995-08-17 · 09:30 · Bangkok, TH');
    expect(birthDetails, findsOneWidget);
    expect(find.text(titles.first), findsNothing);
    for (final title in titles.skip(1)) {
      expect(
        find.text(title),
        title == '感情模式快照' ? findsNothing : findsOneWidget,
      );
    }
    for (final title in oldTitles) {
      expect(find.text(title), findsNothing);
    }
    expect(find.text('Free marriage section 3.'), findsOneWidget);
    expect(find.textContaining('1990-05-20'), findsNothing);
    for (final paragraph in preview.first['paragraphs'] as List<String>) {
      expect(find.text(paragraph), findsNothing);
    }
    expect(find.text(controller.copy.t('jy', 'appLogin.title')), findsNothing);
    expect(find.text(controller.copy.t('life', 'exportPdf')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('saved marriage report shows the paid outline in order', (
    tester,
  ) async {
    final data = marriageFixture(full: true);
    final browser = TestBrowser();
    final controller = H5Controller(
      translations(),
      ReportRepository(
        browser,
        client: MockClient(
          (request) async => http.Response(
            jsonEncode(data),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      ),
      browser,
      language: 'zh',
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      H5App(
        controller: controller,
        initialLocation: '/report.html?id=${data['id']}&lang=zh',
      ),
    );
    await tester.pumpAndSettle();
    final titles = controller.copy.list('marriage', 'full');
    expect(find.text('1995-08-17 · 09:30 · Bangkok, TH'), findsOneWidget);
    for (var i = 0; i < titles.length; i++) {
      expect(find.text(titles[i]), findsOneWidget);
      expect(find.text('Paid marriage section ${i + 1}.'), findsOneWidget);
    }
    expect(
      tester.getTopLeft(find.text(titles[1])).dy,
      lessThan(tester.getTopLeft(find.text(titles[4])).dy),
    );
    expect(find.text('Free marriage section 3.'), findsNothing);
    final pdf = find.widgetWithText(
      OutlinedButton,
      controller.reportCopy(LifeReport.parse(data)).t('report', 'exportPdf'),
    );
    expect(pdf, findsOneWidget);
    expect(tester.widget<OutlinedButton>(pdf).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final language in ['zh', 'th']) {
    for (final full in [false, true]) {
      testWidgets(
        'personal ${full ? 'full' : 'free'} report renders the authorized blocks in $language',
        (tester) async {
          tester.view.physicalSize = const Size(360, 740);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final data = personalFixture(language: language, full: true);
          if (!full) data['access'] = 'preview';
          final requests = <String>[];
          final browser = TestBrowser();
          final controller = H5Controller(
            translations(),
            ReportRepository(
              browser,
              client: MockClient((request) async {
                requests.add(request.method);
                return http.Response(
                  jsonEncode(data),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'},
                );
              }),
            ),
            browser,
            language: language,
          );
          await tester.pumpWidget(
            H5App(
              controller: controller,
              initialLocation:
                  '/report.html?id=${data['id']}&lang=$language&checkout=1',
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('checkout-theme-badges')),
            full ? findsNothing : findsOneWidget,
          );
          expect(
            find.textContaining(controller.copy.t('jy', 'checkout.contents')),
            full ? findsNothing : findsOneWidget,
          );
          expect(find.textContaining('Bangkok'), findsNothing);
          expect(find.textContaining('1995-08-17'), findsNothing);
          expect(find.textContaining('RoxyAPI'), findsNothing);
          expect(find.textContaining('Placidus'), findsNothing);
          if (full) {
            await tester.tap(find.byKey(const ValueKey('saved-free-report')));
            await tester.pumpAndSettle();
          }
          for (var i = 0; i < 3; i++) {
            expect(
              find.byKey(ValueKey('personal-trait-title-$i')),
              findsOneWidget,
            );
            expect(find.text('Everyday behavior $i.'), findsOneWidget);
            expect(
              find.descendant(
                of: find.byKey(const ValueKey('personal-free-zone-1')),
                matching: find.byKey(ValueKey('personal-trait-text-$i')),
              ),
              findsOneWidget,
            );
          }
          expect(find.byKey(const ValueKey('personal-signs')), findsOneWidget);
          final relationship = find.byKey(
            const ValueKey('free-relationship-preview'),
          );
          expect(relationship, findsOneWidget);
          expect(
            find.text(
              'A distinct view of closeness, needs and relationship boundaries.',
            ),
            findsOneWidget,
          );
          expect(
            tester.getTopLeft(relationship).dy,
            lessThan(
              tester
                  .getTopLeft(
                    find.byKey(const ValueKey('personal-free-zone-0')),
                  )
                  .dy,
            ),
          );
          for (var i = 0; i < 2; i++) {
            expect(
              find.byKey(ValueKey('personal-keyword-Personal trait $i')),
              findsOneWidget,
            );
          }
          expect(find.text('Synthetic free line one.'), findsNothing);
          expect(find.text('Synthetic free line two.'), findsOneWidget);
          expect(find.text('Synthetic free line three.'), findsOneWidget);
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('personal-free-zone-2')),
              matching: find.text('Prepare one example to share.'),
            ),
            findsOneWidget,
          );
          if (full) {
            expect(find.byType(ReportCheckout), findsNothing);
            expect(find.text('Synthetic personal talent.'), findsOneWidget);
            for (final key in ['wealth', 'love', 'risk']) {
              expect(find.text('Synthetic $key reading.'), findsOneWidget);
            }
            expect(find.text('2027-03 · Synthetic theme 3'), findsOneWidget);
            expect(find.text('Synthetic small action 3'), findsOneWidget);
          } else {
            expect(find.byType(ReportCheckout), findsOneWidget);
            final aboutTitles = controller.copy.list(
              'jy',
              'checkout.relationshipAboutTitle',
            );
            expect(aboutTitles, hasLength(2));
            for (final title in aboutTitles) {
              expect(find.text(title), findsOneWidget);
            }
            expect(
              find.text(controller.copy.t('jy', 'checkout.relationshipAbout')),
              findsOneWidget,
            );
            for (var i = 0; i < 3; i++) {
              expect(
                find.byKey(ValueKey('personal-free-zone-$i')),
                findsOneWidget,
              );
            }
            for (final key in ['keywords', 'traits', 'opportunity']) {
              expect(
                find.text(controller.copy.t('jy', 'personal.$key')),
                findsOneWidget,
              );
            }
            expect(find.text('Synthetic personal talent.'), findsNothing);
            for (final key in ['wealth', 'love', 'risk']) {
              expect(find.text('Synthetic $key reading.'), findsNothing);
            }
            expect(find.textContaining('2027-01'), findsNothing);
            expect(find.textContaining('Synthetic theme'), findsNothing);
            expect(find.textContaining('Synthetic benefit'), findsNothing);
          }
          expect(requests.where((method) => method != 'GET'), isEmpty);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          controller.dispose();
        },
      );
    }
  }
  test('saved personal reports can omit the new free details', () {
    final data = personalFixture();
    final personal = object(data['personal']);
    personal.remove('traits');
    personal.remove('opportunity_action');
    data['personal'] = personal;
    final report = LifeReport.parse(data);
    expect(report.hasPreview, isTrue);
    expect(report.freeTraits, isEmpty);
    expect(report.opportunityAction, isEmpty);
    personal['traits'] = [
      {'title': 'Incomplete trait'},
    ];
    data['personal'] = personal;
    expect(() => LifeReport.parse(data), throwsFormatException);
  });
  testWidgets(
    'personal checkout restores the original preview price and hint without bypassing unavailable periods',
    (tester) async {
      final data = personalFixture();
      data['personal'] = {
        ...object(data['personal']),
        'availability': {
          'full_report': false,
          'reason': 'insufficient_periods',
        },
      };
      final requests = <String>[];
      final browser = TestBrowser();
      final controller = H5Controller(
        translations(),
        ReportRepository(
          browser,
          client: MockClient((request) async {
            requests.add(request.method);
            return http.Response(
              jsonEncode(data),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
        browser,
        language: 'zh',
      );
      await tester.pumpWidget(
        H5App(
          controller: controller,
          initialLocation: '/report.html?id=${data['id']}&lang=zh&checkout=1',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ReportCheckout), findsOneWidget);
      expect(find.text('฿39'), findsNothing);
      expect(find.text('฿30'), findsNothing);
      expect(find.byKey(const ValueKey('jy-payment-preview')), findsNothing);
      expect(requests.where((method) => method != 'GET'), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
  testWidgets(
    'personal forecast failure offers retry without showing a ready report',
    (tester) async {
      final data = personalFixture()..['preview_state'] = 'unavailable';
      final browser = TestBrowser();
      final controller = H5Controller(
        translations(),
        ReportRepository(
          browser,
          client: MockClient(
            (request) async => http.Response(
              jsonEncode(data),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
        ),
        browser,
        language: 'zh',
      );
      await tester.pumpWidget(
        H5App(
          controller: controller,
          initialLocation: '/report.html?id=${data['id']}&lang=zh',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ReportCheckout), findsNothing);
      expect(find.text('Synthetic free line one.'), findsNothing);
      expect(
        find.text(controller.copy.t('jy', 'appLogin.title')),
        findsNothing,
      );
      expect(
        find.text(
          controller.copy
              .forReport(LifeReport.parse(data))
              .t('report', 'retryPreview'),
        ),
        findsOneWidget,
      );
      expect(find.byType(JYButton), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}
