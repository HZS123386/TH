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
    'landing presents six relationship sections in the existing theme boards',
    (tester) async {
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
      final board = find.byType(ThemeBoards);
      for (final key in relationshipKeys) {
        final label = controller.copy.t('relationship', 'sections.$key');
        expect(label, isNotEmpty);
        expect(
          find.descendant(of: board, matching: find.text(label)),
          findsOneWidget,
        );
      }
      expect(find.text(controller.copy.t('jy', 'formCaption')), findsOneWidget);
      for (final key in personalKeys) {
        expect(
          find.descendant(
            of: board,
            matching: find.text(
              controller.copy.t('jy', 'report.westernSections.$key'),
            ),
          ),
          findsNothing,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
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
            final unlock = tester.widget<JYButton>(
              find.byKey(const ValueKey('jy-payment-preview')),
            );
            expect(
              unlock.label,
              controller.copy.t('jy', 'personal.relationshipUnlock'),
            );
            expect(unlock.label, isNotEmpty);
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
      expect(find.text('฿39'), findsOneWidget);
      expect(find.text('฿30'), findsNothing);
      expect(
        find.text(controller.copy.t('jy', 'checkout.preview')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<JYButton>(find.byKey(const ValueKey('jy-payment-preview')))
            .onPressed,
        isNull,
      );
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
