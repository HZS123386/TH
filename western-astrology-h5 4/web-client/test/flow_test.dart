import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fate_h5/app/controller.dart';
import 'package:fate_h5/app/h5_app.dart';
import 'package:fate_h5/core/models.dart';
import 'package:fate_h5/core/repository.dart';
import 'package:fate_h5/features/generation_dialog.dart';
import 'package:fate_h5/features/generation_video.dart';
import 'package:fate_h5/features/report_view_model.dart';
import 'package:fate_h5/features/checkout_dialog.dart';
import 'package:fate_h5/ui/jy_components.dart';
import 'package:fate_h5/ui/site_header.dart';

import 'support.dart';

http.Response response(dynamic value) => http.Response(
  jsonEncode(value),
  200,
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

Future<void> click(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> waitForDeferredView(WidgetTester tester, Finder view) async {
  for (var attempt = 0; attempt < 30 && view.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(view, findsWidgets);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    // Native deferred library futures must complete outside the widget fake clock.
    await H5App.loadRoutesForWidgetTests();
  });

  for (final language in ['zh', 'th']) {
    testWidgets(
      '$language refresh resumes the saved queue with no duplicate submission',
      (tester) async {
        phone(tester);
        final done = fixture(language: language);
        var current = {
          ...done,
          'preview': null,
          'preview_state': 'queued',
          'chart': null,
          'generation_queue': {'state': 'queued', 'position': 12},
        };
        final browser = TestBrowser()
          ..settings['session:active-preview'] = done['id'] as String;
        final requests = <String>[];
        final repo = ReportRepository(
          browser,
          baseUrl: 'https://example.test',
          client: MockClient((request) async {
            if (request.url.path.startsWith('/api/life-reports')) {
              requests.add('${request.method} ${request.url.path}');
              return response(current);
            }
            return response({'notice_version': H5Controller.noticeVersion});
          }),
        );
        final h5 = H5Controller(
          translations(),
          repo,
          browser,
          language: language,
        );
        await tester.pumpWidget(
          H5App(controller: h5, initialLocation: '/?lang=$language'),
        );
        await waitForDeferredView(tester, find.byType(GenerationDialog));
        expect(find.byType(GenerationDialog), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back), findsNothing);
        expect(
          find.text(h5.copy.t('jy', 'interpretation.queued')),
          findsOneWidget,
        );
        expect(find.text(h5.copy.t('jy', 'appLogin.title')), findsNothing);
        expect(requests.every((request) => request.startsWith('GET ')), isTrue);
        tester
            .widget<GenerationDialog>(find.byType(GenerationDialog))
            .onCancel();
        await tester.pumpAndSettle();
        final queuedLabel = h5.copy.t('life', 'previewStates.queued');
        expect(browser.activities.last, {
          'page': 'report_loading',
          'action': 'cancel_generation',
        });
        expect(
          browser.activities.where((event) => event['action'] == 'report_ready'),
          isEmpty,
        );
        expect(queuedLabel, isNotEmpty);
        expect(find.text(queuedLabel), findsOneWidget);
        expect(find.text(h5.copy.t('life', 'viewProgress')), findsOneWidget);
        current = done;
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('free-report-content')),
          findsOneWidget,
        );
        expect(requests.every((request) => request.startsWith('GET ')), isTrue);
        for (final width in [320.0, 360.0, 1100.0]) {
          tester.view.physicalSize = Size(width, 640);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$language report at width $width',
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        h5.dispose();
      },
    );

    testWidgets(
      '$language paid queue resumes the original report and keeps polling after leaving the animation',
      (tester) async {
        phone(tester);
        final done = fixture(language: language, full: true);
        var current = {
          ...done,
          'full_state': 'queued',
          'chapters': [],
          'plan': null,
          'progress': {
            'completed': 0,
            'total': object(done['progress'])['total'],
          },
        };
        final browser = TestBrowser();
        final methods = <String>[];
        final repo = ReportRepository(
          browser,
          baseUrl: 'https://example.test',
          client: MockClient((request) async {
            if (request.url.path.startsWith('/api/life-reports'))
              methods.add(request.method);
            return response(current);
          }),
        );
        final h5 = H5Controller(
          translations(),
          repo,
          browser,
          language: language,
        );
        await tester.pumpWidget(
          H5App(
            controller: h5,
            initialLocation: '/report.html?id=${done['id']}&lang=$language',
          ),
        );
        final label = h5.copy.t('life', 'states.queued');
        expect(label, isNotEmpty);
        await waitForDeferredView(tester, find.textContaining(label));
        expect(find.textContaining(label), findsWidgets);
        await click(tester, find.text(h5.copy.t('life', 'viewProgress')));
        expect(
          find.text(h5.copy.t('jy', 'interpretation.queued')),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.arrow_back), findsNothing);
        if (language == 'th') {
          browser.writeSetting(
            'active-preview',
            text(done['id']),
            session: true,
          );
          await click(
            tester,
            find.widgetWithText(TextButton, h5.copy.t('generation', 'cancel')),
          );
          expect(find.byType(GenerationDialog), findsNothing);
          await click(
            tester,
            find.descendant(
              of: find.byType(SiteHeader),
              matching: find.byType(FateBrand),
            ),
          );
          expect(browser.formVisible, isTrue);
          expect(browser.readSetting('active-preview', session: true), isEmpty);
          expect(methods.every((method) => method == 'GET'), isTrue);
          await tester.pumpWidget(const SizedBox.shrink());
          h5.dispose();
          return;
        }
        tester
            .widget<GenerationDialog>(find.byType(GenerationDialog))
            .onCancel();
        await tester.pumpAndSettle();
        current = done;
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(find.textContaining(label), findsNothing);
        expect(find.text(h5.copy.t('life', 'viewProgress')), findsNothing);
        expect(find.byIcon(Icons.arrow_back), findsNothing);
        expect(
          browser.activities.where((event) =>
              event['page'] == 'full_report' && event['action'] == 'report_ready'),
          hasLength(1),
        );
        expect(methods.length, greaterThan(1));
        expect(methods.every((method) => method == 'GET'), isTrue);
        for (final width in [320.0, 1100.0]) {
          tester.view.physicalSize = Size(width, 640);
          await tester.pumpAndSettle();
        }
        await tester.pumpWidget(const SizedBox.shrink());
        h5.dispose();
      },
    );
  }
  for (final mobile in [false, true]) {
    final device = mobile ? 'mobile' : 'desktop';
    testWidgets('legacy H5 checkout offers LINE delivery on $device', (
      tester,
    ) async {
      phone(tester);
      if (!mobile) tester.view.physicalSize = const Size(1200, 720);
      final browser = TestBrowser()..supportsLineApp = mobile;
      final paid = fixture(full: true);
      final data = {
        ...fixture(),
        'claim_code': '57248',
        'payment_simulation': false,
        'price': {
          'amount': 3000,
          'currency': 'THB',
          'display': '฿30',
          'mode': 'sunlands_order_only',
        },
        'chapters': paid['chapters'],
        'plan': paid['plan'],
      };
      final calls = <String>[];
      final repo = ReportRepository(
        browser,
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          return response(data);
        }),
      );
      final h5 = H5Controller(translations(), repo, browser, language: 'zh');
      await tester.pumpWidget(
        H5App(
          controller: h5,
          initialLocation: '/report.html?id=${data['id']}&lang=zh&checkout=1',
        ),
      );
      await waitForDeferredView(
        tester,
        find.byKey(const ValueKey('free-report-content')),
      );
      expect(find.byKey(const ValueKey('free-report-content')), findsOneWidget);
      expect(browser.activities.last, {
        'page': 'preview_report',
        'action': 'report_ready',
      });
      final paidText = text(
        object(objects(paid['chapters']).first['summary'])['text'],
      );
      expect(find.text(paidText), findsNothing);
      expect(
        find.byKey(const ValueKey('checkout-theme-badges')),
        findsOneWidget,
      );
      final contact = find.byKey(const ValueKey('jy-line-contact'));
      final claimNumber = find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText && widget.data == data['claim_code'],
      );
      expect(claimNumber, findsOneWidget);
      expect(
        find.text(h5.copy.t('jy', 'lineContact.claimNumber')),
        findsOneWidget,
      );
      final qr = find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/line-contact-qr-956ed148.jpg',
      );
      expect(qr, findsOneWidget);
      expect(find.text(h5.copy.t('jy', 'lineContact.scan')), findsOneWidget);
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/images/line-contact-qr-956ed148.jpg'),
          tester.element(qr),
        );
      });
      await tester.ensureVisible(qr);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      final messenger = tester.binding.defaultBinaryMessenger;
      String? copied;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await click(
        tester,
        find.widgetWithText(
          TextButton,
          h5.copy.t('jy', 'lineContact.copyReportId'),
        ),
      );
      expect(copied, data['claim_code']);
      expect(browser.openedPages, isEmpty);
      expect(find.text(h5.copy.t('jy', 'lineContact.open')), findsOneWidget);
      await click(tester, contact);
      expect(browser.sameTabPages, ['https://line.me/ti/p/SmujXXCH9v']);
      expect(browser.lineClaimClicks, 0);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        browser.activities.where(
          (event) => event['action'] == 'open_line_contact',
        ),
        hasLength(mobile ? 0 : 1),
      );
      expect(
        browser.activities.where((event) => event['action'] == 'click_line'),
        hasLength(1),
      );
      expect(
        browser.activities.where((event) => event['action'] == 'line_qr_shown'),
        hasLength(1),
      );
      expect(find.byKey(const ValueKey('jy-app-download')), findsNothing);
      expect(find.byKey(const ValueKey('jy-payment-preview')), findsNothing);
      expect(find.text('฿30'), findsNothing);
      expect(find.byType(ReportPaymentDialog), findsNothing);
      expect(find.byType(ReportPreview), findsOneWidget);
      expect(
        calls.where(
          (call) => call.contains('/payment') || call.endsWith('/unlock'),
        ),
        isEmpty,
      );
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      await click(
        tester,
        find.descendant(
          of: find.byType(SiteHeader),
          matching: find.byType(FateBrand),
        ),
      );
      expect(find.byType(ReportPreview), findsNothing);
      expect(browser.formVisible, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    });
  }

  testWidgets(
    'Sunlands keeps an order locked when the cashier link is outside Sunlands',
    (tester) async {
      phone(tester);
      final browser = TestBrowser();
      final paths = <String>[];
      final bodies = <Json>[];
      final report = LifeReport.parse({
        ...fixture(),
        'payment_simulation': false,
        'price': {
          'amount': 1000,
          'currency': 'THB',
          'display': '฿10',
          'mode': 'sunlands_order_only',
        },
      });
      final repo = ReportRepository(
        browser,
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          paths.add(request.url.path);
          bodies.add(object(jsonDecode(request.body)));
          return response({
            'reference': '000000000001',
            'amount': 1000,
            'currency': 'THB',
            'order_only': true,
            'state': 'CREATED',
            'order_number': '202611120001',
            'checkout_url':
                'https://unrelated.example.test/trade/web/trade/payDirect.action?orderNumber=202611120001',
          });
        }),
      );
      final h5 = H5Controller(translations(), repo, browser, language: 'zh');
      await tester.pumpWidget(
        MaterialApp(
          home: ReportPaymentDialog(h5: h5, report: report),
        ),
      );
      await tester.pumpAndSettle();
      expect(bodies, [{}]);
      expect(
        find.text(h5.copy.t('checkout', 'cashierUnavailable')),
        findsOneWidget,
      );
      expect(browser.sameTabPages, isEmpty);
      expect(find.text('前往收银台'), findsNothing);
      expect(find.byKey(const ValueKey('test-card-number')), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(paths, ['/api/life-reports/${report.id}/payment']);
      expect(report.full, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );
  for (final failure in [
    ('life_order_access_denied', 'accessDenied', 503),
    ('life_order_rejected', 'orderRejected', 409),
    ('life_order_channel_invalid', 'channelInvalid', 409),
    ('life_order_needs_review', 'orderNeedsReview', 409),
  ]) {
    testWidgets(
      'Sunlands shows ${failure.$1} without payment or automatic retry',
      (tester) async {
        phone(tester);
        final browser = TestBrowser();
        final paths = <String>[];
        final report = LifeReport.parse({
          ...fixture(),
          'payment_simulation': false,
          'price': {
            'amount': 3000,
            'currency': 'THB',
            'display': '฿30',
            'mode': 'sunlands_order_only',
          },
        });
        final repo = ReportRepository(
          browser,
          baseUrl: 'https://example.test',
          client: MockClient((request) async {
            paths.add(request.url.path);
            if (paths.length == 1) {
              return http.Response(
                jsonEncode({'code': failure.$1}),
                failure.$3,
                headers: {'content-type': 'application/json'},
              );
            }
            return response({
              'reference': '000000000001',
              'amount': 3000,
              'currency': 'THB',
              'order_only': true,
              'state': 'CREATED',
              'order_number': '202611120001',
            });
          }),
        );
        final h5 = H5Controller(translations(), repo, browser, language: 'zh');
        await tester.pumpWidget(
          MaterialApp(
            home: ReportPaymentDialog(h5: h5, report: report),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(h5.copy.t('checkout', failure.$2)), findsOneWidget);
        expect(find.byKey(const ValueKey('continue-payment')), findsNothing);
        expect(find.byKey(const ValueKey('test-card-number')), findsNothing);
        expect(paths, ['/api/life-reports/${report.id}/payment']);
        if (failure.$1 == 'life_order_access_denied') {
          await click(
            tester,
            find.widgetWithText(TextButton, h5.copy.t('checkout', 'retry')),
          );
          expect(
            find.text(h5.copy.t('checkout', 'cashierUnavailable')),
            findsOneWidget,
          );
          expect(paths, [
            '/api/life-reports/${report.id}/payment',
            '/api/life-reports/${report.id}/payment',
          ]);
        }
        expect(find.byType(FilledButton), findsNothing);
        expect(report.full, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        h5.dispose();
      },
    );
  }
  for (final (language, providerReturn, full) in [
    ('th', false, false),
    ('zh', true, false),
    ('th', true, true),
  ]) {
    final returnMethod = providerReturn ? 'provider return' : 'browser return';
    testWidgets(
      'H5 reads the original $language report without payment on $returnMethod',
      (tester) async {
        phone(tester);
        final browser = TestBrowser();
        final requests = <http.Request>[];
        final data = fixture(language: language, full: full);
        final reportPath = '/api/life-reports/${data['id']}';
        if (!providerReturn) {
          browser.writeSetting(
            ReportPaymentDialog.pendingReportKey,
            text(data['id']),
            session: true,
          );
        }
        final repo = ReportRepository(
          browser,
          baseUrl: 'https://example.test',
          client: MockClient((request) async {
            requests.add(request);
            if (request.url.path == reportPath) {
              return response({
                ...data,
                'payment_simulation': false,
                'price': {
                  'amount': 1000,
                  'currency': 'THB',
                  'display': '฿10',
                  'mode': 'sunlands_order_only',
                },
              });
            }
            return response({});
          }),
        );
        final h5 = H5Controller(
          translations(),
          repo,
          browser,
          language: language,
        );
        final returnQuery = providerReturn ? '&payment_return=1' : '';
        await tester.pumpWidget(
          H5App(
            controller: h5,
            initialLocation:
                '/report.html?id=${data['id']}&lang=$language$returnQuery',
          ),
        );
        await waitForDeferredView(
          tester,
          full
              ? find.text(text(data['title']))
              : find.byKey(const ValueKey('free-report-content')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ReportPaymentDialog), findsNothing);
        expect(requests.where((r) => r.url.path == reportPath), hasLength(1));
        expect(
          requests.where(
            (r) =>
                r.url.path.contains('/payment') ||
                r.url.path.endsWith('/unlock'),
          ),
          isEmpty,
        );
        expect(browser.openedPages, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        h5.dispose();
      },
    );
  }

  testWidgets(
    'Sunlands retries a failed order read without falling through to create',
    (tester) async {
      phone(tester);
      final browser = TestBrowser();
      final requests = <http.Request>[];
      final report = LifeReport.parse({
        ...fixture(),
        'payment_simulation': false,
        'price': {
          'amount': 3000,
          'currency': 'THB',
          'display': '฿30',
          'mode': 'sunlands_order_only',
        },
      });
      final repo = ReportRepository(
        browser,
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            '{}',
            500,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final h5 = H5Controller(translations(), repo, browser, language: 'zh');
      await tester.pumpWidget(
        MaterialApp(
          home: ReportPaymentDialog(h5: h5, report: report, returning: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      await click(
        tester,
        find.widgetWithText(TextButton, h5.copy.t('checkout', 'retry')),
      );
      expect(requests.length, 2);
      expect(requests.every((r) => r.method == 'GET'), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );

  testWidgets(
    'Sunlands retries inquiry after permission failure and opens report only after confirmed paid',
    (tester) async {
      phone(tester);
      final browser = TestBrowser();
      final requests = <http.Request>[];
      var checks = 0;
      bool? completed;
      final report = LifeReport.parse({
        ...fixture(),
        'payment_simulation': false,
        'price': {
          'amount': 3000,
          'currency': 'THB',
          'display': '฿30',
          'mode': 'sunlands_order_only',
        },
      });
      final repo = ReportRepository(
        browser,
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET') {
            return response({
              'reference': '000000000003',
              'amount': 3000,
              'currency': 'THB',
              'order_only': true,
              'state': 'CREATED',
              'order_number': 'OFFLINE_ORDER_SETTLEMENT',
            });
          }
          expect(
            request.url.path,
            '/api/life-reports/${report.id}/payment/check',
          );
          checks++;
          if (checks == 1) {
            return http.Response(
              '{"code":"life_payment_check_access_denied"}',
              503,
              headers: {'content-type': 'application/json'},
            );
          }
          return response({'paid': checks >= 3});
        }),
      );
      final h5 = H5Controller(translations(), repo, browser, language: 'zh');
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  completed = await showDialog<bool>(
                    context: context,
                    builder: (_) => ReportPaymentDialog(
                      h5: h5,
                      report: report,
                      returning: true,
                    ),
                  );
                },
                child: const Text('Open checkout'),
              ),
            ),
          ),
        ),
      );
      await click(tester, find.text('Open checkout'));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(checks, 1);
      expect(completed, isNull);
      final retry = find.widgetWithText(
        TextButton,
        h5.copy.t('checkout', 'checkPayment'),
      );
      expect(tester.widget<TextButton>(retry).onPressed, isNotNull);
      await click(tester, retry);
      expect(checks, 2);
      expect(completed, isNull);
      expect(find.text(h5.copy.t('checkout', 'pendingOrder')), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(checks, 3);
      expect(find.text(h5.copy.t('checkout', 'success')), findsOneWidget);
      expect(find.text(h5.copy.t('checkout', 'pendingOrder')), findsNothing);
      expect(find.text(h5.copy.t('checkout', 'demoSuccess')), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(
        requests.where(
          (r) => r.method == 'POST' && r.url.path.endsWith('/payment'),
        ),
        isEmpty,
      );
      expect(browser.openedPages, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );

  testWidgets(
    'simulated card checkout validates locally and sends only the order reference',
    (tester) async {
      phone(tester);
      final browser = TestBrowser();
      final paid = Completer<http.Response>();
      final submitted = <Json>[];
      final report = LifeReport.parse({
        ...fixture(),
        'payment_simulation': true,
        'price': {
          'amount': 3000,
          'currency': 'THB',
          'display': '฿30',
          'mode': 'direct',
        },
      });
      final repo = ReportRepository(
        browser,
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/payment/simulate')) {
            submitted.add(object(jsonDecode(request.body)));
            return paid.future;
          }
          return response({
            'reference': '000000000001',
            'amount': 3000,
            'currency': 'THB',
          });
        }),
      );
      final h5 = H5Controller(translations(), repo, browser, language: 'zh');
      await tester.pumpWidget(
        MaterialApp(
          home: ReportPaymentDialog(h5: h5, report: report),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('฿30'), findsOneWidget);
      expect(find.textContaining('0001'), findsOneWidget);
      final confirm = find.widgetWithText(
        FilledButton,
        h5.copy.t('checkout', 'cardConfirm'),
      );
      await click(tester, confirm);
      expect(submitted, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('test-card-number')),
        '4000 0000 0000 0000',
      );
      await tester.enterText(
        find.byKey(const ValueKey('test-card-expiry')),
        '12/30',
      );
      await tester.enterText(
        find.byKey(const ValueKey('test-card-security-code')),
        '123',
      );
      await click(tester, confirm);
      expect(submitted, isEmpty);
      await click(
        tester,
        find.widgetWithText(OutlinedButton, h5.copy.t('checkout', 'fillCard')),
      );
      await click(tester, confirm);
      expect(submitted, [
        {'reference': '000000000001'},
      ]);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      expect(find.text(h5.copy.t('checkout', 'demoSuccess')), findsNothing);
      paid.complete(response({'paid': true}));
      await tester.pumpAndSettle();
      expect(find.text(h5.copy.t('checkout', 'demoSuccess')), findsOneWidget);
      expect(find.byKey(const ValueKey('test-card-number')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );
  testWidgets(
    'Sunlands retries a failed order read without falling through to create',
    (tester) async {
      phone(tester);
      final browser = TestBrowser();
      final requests = <http.Request>[];
      final report = LifeReport.parse({
        ...fixture(),
        'payment_simulation': false,
        'price': {
          'amount': 3000,
          'currency': 'THB',
          'display': '฿30',
          'mode': 'sunlands_order_only',
        },
      });
      final repo = ReportRepository(
        browser,
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            '{}',
            500,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final h5 = H5Controller(translations(), repo, browser, language: 'zh');
      await tester.pumpWidget(
        MaterialApp(
          home: ReportPaymentDialog(h5: h5, report: report, returning: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('order-mobile')), findsNothing);
      expect(find.text(h5.copy.t('checkout', 'createOrderOnly')), findsNothing);
      await click(
        tester,
        find.widgetWithText(TextButton, h5.copy.t('checkout', 'retry')),
      );
      expect(requests.length, 2);
      expect(requests.every((r) => r.method == 'GET'), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );

  testWidgets(
    'Sunlands permits an explicit retry after a gateway access denial',
    (tester) async {
      phone(tester);
      final browser = TestBrowser();
      final requests = <http.Request>[];
      const successfulCashier =
          'https://epay.sunlands.com/epay-war/ep_pay/epayPay/payDirect.action?orderNumber=OFFLINE_ORDER_RETRY';
      final report = LifeReport.parse({
        ...fixture(),
        'payment_simulation': false,
        'price': {
          'amount': 3000,
          'currency': 'THB',
          'display': '฿30',
          'mode': 'sunlands_order_only',
        },
      });
      final repo = ReportRepository(
        browser,
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          requests.add(request);
          if (requests.length == 1) {
            return http.Response(
              '{"code":"life_order_access_denied"}',
              503,
              headers: {'content-type': 'application/json'},
            );
          }
          return response({
            'reference': '000000000001',
            'amount': 3000,
            'currency': 'THB',
            'order_only': true,
            'state': 'CREATED',
            'order_number': 'OFFLINE_ORDER_RETRY',
            'checkout_url': successfulCashier,
          });
        }),
      );
      final h5 = H5Controller(translations(), repo, browser, language: 'zh');
      await tester.pumpWidget(
        MaterialApp(
          home: ReportPaymentDialog(h5: h5, report: report),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests.map((r) => r.method), ['POST']);
      expect(find.byKey(const ValueKey('order-mobile')), findsNothing);
      await click(
        tester,
        find.widgetWithText(TextButton, h5.copy.t('checkout', 'retry')),
      );
      expect(requests.map((r) => r.method), ['POST', 'POST']);
      expect(jsonDecode(requests.last.body), {});
      expect(find.textContaining('OFFLINE_ORDER_RETRY'), findsOneWidget);
      expect(browser.sameTabPages, [successfulCashier]);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );

  testWidgets(
    'Sunlands retries inquiry after permission failure and opens report only after confirmed paid',
    (tester) async {
      phone(tester);
      final browser = TestBrowser();
      final requests = <http.Request>[];
      var checks = 0;
      bool? completed;
      final report = LifeReport.parse({
        ...fixture(),
        'payment_simulation': false,
        'price': {
          'amount': 3000,
          'currency': 'THB',
          'display': '฿30',
          'mode': 'sunlands_order_only',
        },
      });
      final repo = ReportRepository(
        browser,
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET') {
            return response({
              'reference': '000000000003',
              'amount': 3000,
              'currency': 'THB',
              'order_only': true,
              'state': 'CREATED',
              'order_number': 'OFFLINE_ORDER_SETTLEMENT',
            });
          }
          expect(
            request.url.path,
            '/api/life-reports/${report.id}/payment/check',
          );
          checks++;
          if (checks == 1) {
            return http.Response(
              '{"code":"life_payment_check_access_denied"}',
              503,
              headers: {'content-type': 'application/json'},
            );
          }
          return response({'paid': checks >= 3});
        }),
      );
      final h5 = H5Controller(translations(), repo, browser, language: 'zh');
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  completed = await showDialog<bool>(
                    context: context,
                    builder: (_) => ReportPaymentDialog(
                      h5: h5,
                      report: report,
                      returning: true,
                    ),
                  );
                },
                child: const Text('Open checkout'),
              ),
            ),
          ),
        ),
      );
      await click(tester, find.text('Open checkout'));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(checks, 1);
      expect(completed, isNull);
      final retry = find.widgetWithText(
        TextButton,
        h5.copy.t('checkout', 'checkPayment'),
      );
      expect(tester.widget<TextButton>(retry).onPressed, isNotNull);
      await click(tester, retry);
      expect(checks, 2);
      expect(completed, isNull);
      expect(find.text(h5.copy.t('checkout', 'pendingOrder')), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(checks, 3);
      expect(find.text(h5.copy.t('checkout', 'success')), findsOneWidget);
      expect(find.text(h5.copy.t('checkout', 'pendingOrder')), findsNothing);
      expect(find.text(h5.copy.t('checkout', 'demoSuccess')), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(
        requests.where(
          (r) => r.method == 'POST' && r.url.path.endsWith('/payment'),
        ),
        isEmpty,
      );
      expect(browser.openedPages, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );

  testWidgets(
    'simulated card checkout validates locally and sends only the order reference',
    (tester) async {
      phone(tester);
      final browser = TestBrowser();
      final paid = Completer<http.Response>();
      final submitted = <Json>[];
      final report = LifeReport.parse({
        ...fixture(),
        'payment_simulation': true,
        'price': {
          'amount': 3000,
          'currency': 'THB',
          'display': '฿30',
          'mode': 'direct',
        },
      });
      final repo = ReportRepository(
        browser,
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/payment/simulate')) {
            submitted.add(object(jsonDecode(request.body)));
            return paid.future;
          }
          return response({
            'reference': '000000000001',
            'amount': 3000,
            'currency': 'THB',
          });
        }),
      );
      final h5 = H5Controller(translations(), repo, browser, language: 'zh');
      await tester.pumpWidget(
        MaterialApp(
          home: ReportPaymentDialog(h5: h5, report: report),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('฿30'), findsOneWidget);
      expect(find.textContaining('0001'), findsOneWidget);
      final confirm = find.widgetWithText(
        FilledButton,
        h5.copy.t('checkout', 'cardConfirm'),
      );
      await click(tester, confirm);
      expect(submitted, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('test-card-number')),
        '4000 0000 0000 0000',
      );
      await tester.enterText(
        find.byKey(const ValueKey('test-card-expiry')),
        '12/30',
      );
      await tester.enterText(
        find.byKey(const ValueKey('test-card-security-code')),
        '123',
      );
      await click(tester, confirm);
      expect(submitted, isEmpty);
      await click(
        tester,
        find.widgetWithText(OutlinedButton, h5.copy.t('checkout', 'fillCard')),
      );
      await click(tester, confirm);
      expect(submitted, [
        {'reference': '000000000001'},
      ]);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      expect(find.text(h5.copy.t('checkout', 'demoSuccess')), findsNothing);
      paid.complete(response({'paid': true}));
      await tester.pumpAndSettle();
      expect(find.text(h5.copy.t('checkout', 'demoSuccess')), findsOneWidget);
      expect(find.byKey(const ValueKey('test-card-number')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );

  testWidgets(
    'paid generation keeps the same visible wheel across stages until the report is ready',
    (tester) async {
      phone(tester);
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: false);
      final browser = TestBrowser();
      final h5 = H5Controller(
        translations(),
        ReportRepository(browser),
        browser,
        language: 'zh',
      );
      final report = LifeReport.parse(fixture());
      final state = GenerationState()..update(report, 0, 'preview');
      var completed = 0, cancelled = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: GenerationDialog(
            h5: h5,
            state: state,
            full: true,
            onCancel: () => cancelled++,
            onRetry: () {},
            onComplete: (_) => completed++,
          ),
        ),
      );
      final wheel = find.byType(GenerationVideo);
      final wheelElement = tester.element(wheel);
      expect(tester.widget<GenerationVideo>(wheel).active, isTrue);
      expect(tester.getTopLeft(wheel).dy, greaterThanOrEqualTo(320));
      expect(find.text('准备中'), findsOneWidget);
      expect(find.text('0%'), findsNothing);
      state.update(report, 19, 'preview');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('19%'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2100));
      await tester.pump(const Duration(milliseconds: 2600));
      state.update(report, 99, 'preview');
      await tester.pump(const Duration(seconds: 12));
      expect(tester.element(wheel), same(wheelElement));
      expect(tester.widget<GenerationVideo>(wheel).active, isTrue);
      expect(completed, 0);
      expect(find.text('正在校验并保存解读内容'), findsOneWidget);
      expect(find.text(h5.copy.t('jy', 'appLogin.title')), findsNothing);
      state.fail('连接中断');
      await tester.pump();
      expect(find.text('本次生成暂未完成，请重试'), findsOneWidget);
      expect(tester.widget<GenerationVideo>(wheel).active, isFalse);
      state.retry();
      await tester.pump();
      expect(tester.widget<GenerationVideo>(wheel).active, isTrue);
      await tester.tap(find.widgetWithText(TextButton, '取消等待'));
      expect(cancelled, 1);
      state.ready(report);
      await tester.pump();
      expect(
        find.text(h5.copy.t('jy', 'interpretation.complete')),
        findsOneWidget,
      );
      expect(find.text('100%'), findsOneWidget);
      expect(
        find.textContaining(RegExp('Qwen|RoxyAPI', caseSensitive: false)),
        findsNothing,
      );
      await tester.pump(const Duration(milliseconds: 320));
      await tester.pump();
      expect(completed, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
      h5.dispose();
    },
  );
  testWidgets('an already readable report skips the remaining stages', (
    tester,
  ) async {
    phone(tester);
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: false);
    final browser = TestBrowser();
    final h5 = H5Controller(translations(), ReportRepository(browser), browser);
    final report = LifeReport.parse(fixture(language: 'th'));
    final state = GenerationState()..ready(report);
    final displayed = <LifeReport>[];
    await tester.pumpWidget(
      MaterialApp(
        home: GenerationDialog(
          h5: h5,
          state: state,
          full: false,
          onCancel: () {},
          onRetry: () {},
          onComplete: displayed.add,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 319));
    expect(displayed, isEmpty);
    state.ready(report);
    await tester.pump(const Duration(milliseconds: 1));
    expect(displayed, [report]);
    await tester.pump(const Duration(seconds: 3));
    expect(displayed, [report]);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    h5.dispose();
  });

  for (final wait in [Duration.zero, const Duration(seconds: 20)]) {
    testWidgets(
      'free report opens on readiness without waiting for the wheel: $wait',
      (tester) async {
        phone(tester);
        tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: false);
        final browser = TestBrowser();
        final h5 = H5Controller(
          translations(),
          ReportRepository(browser),
          browser,
          language: 'zh',
        );
        final report = LifeReport.parse(fixture());
        final state = GenerationState()..update(report, 99, 'preview');
        var completed = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: GenerationDialog(
              h5: h5,
              state: state,
              full: false,
              onCancel: () {},
              onRetry: () {},
              onComplete: (_) => completed++,
            ),
          ),
        );
        await tester.pump(wait);
        expect(completed, 0);
        state.ready(report);
        await tester.pump(const Duration(milliseconds: 16));
        expect(completed, 1);
        expect(
          tester.widget<GenerationVideo>(find.byType(GenerationVideo)).active,
          isFalse,
        );
        await tester.pump(const Duration(seconds: 10));
        expect(completed, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        state.dispose();
        h5.dispose();
      },
    );
  }

  for (final language in ['zh', 'th']) {
    testWidgets('an accepted native report opens without a second submission ($language)', (tester) async {
      phone(tester);
      final browser = TestBrowser()..birthFormSubmitting = true;
      final data = fixture(language: language);
      final input = {...object(data['input']), 'report_kind': 'marriage'};
      final ready = marriageFixture(input: input);
      browser.writeSetting('active-preview', text(ready['id']), session: true);
      final calls = <String>[];
      final repo = ReportRepository(
        browser,
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          return response(ready);
        }),
      );
      final h5 = H5Controller(translations(), repo, browser, language: language);
      await tester.pumpWidget(H5App(controller: h5, initialLocation: '/?lang=$language'));
      await tester.pumpAndSettle();
      expect(browser.formVisible, isTrue);
      final open = browser.submitBirthForm!;
      expect(await open({'page': 'report', 'language': language, 'report': ready, 'input': {...input, 'year': 1901}}), 'badResult');
      final accepted = open({'page': 'report', 'language': language, 'report': ready, 'input': input});
      await waitForDeferredView(tester, find.byType(ReportPreview));
      expect(await accepted, '');
      expect(calls, isEmpty);
      expect(browser.readSetting('active-preview', session: true), isEmpty);
      expect(browser.formVisible, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    });
  }
  testWidgets(
    'saved complete reports use JY sections and retain all original chapters, plan and PDF export',
    (tester) async {
      phone(tester);
      final browser = TestBrowser();
      final data = fixture(full: true);
      final repo = ReportRepository(
        browser,
        baseUrl: 'https://example.test',
        client: MockClient((_) async => response(data)),
      );
      final h5 = H5Controller(translations(), repo, browser, language: 'zh');
      await tester.pumpWidget(
        H5App(
          controller: h5,
          initialLocation: '/report.html?id=${data['id']}&lang=zh',
        ),
      );
      await waitForDeferredView(tester, find.text(text(data['title'])));
      final labels = h5.copy.forReport(LifeReport.parse(data));
      expect(find.text(text(data['title'])), findsOneWidget);
      expect(find.text(labels.t('report', 'birth')), findsOneWidget);
      expect(find.text(labels.t('report', 'takeaway')), findsOneWidget);
      expect(find.text(labels.t('report', 'traits')), findsOneWidget);
      expect(find.byType(ReportPreview), findsNothing);
      expect(find.byType(ActionChip), findsNWidgets(7));
      final chapterTitle = text(objects(data['catalog']).first['title']);
      await click(tester, find.widgetWithText(ActionChip, chapterTitle));
      expect(find.textContaining('付费章节重点'), findsWidgets);
      for (final label in ['这对你意味着什么', '需要留意的地方', '你可以这样做']) {
        expect(find.text(label), findsNothing);
      }
      expect(find.text('先观察当前的习惯'), findsOneWidget);
      await click(tester, find.byTooltip(h5.copy.t('life', 'exportPdf')));
      expect(browser.exported!['access'], 'full');
      expect(objects(browser.exported!['chapters']), hasLength(7));
      expect(
        objects(object(browser.exported!['plan'])['phases']),
        hasLength(3),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );

  test(
    'saved free report waits for its language and body fonts before showing its contents',
    () async {
      final gate = Completer<void>();
      final bodyFonts = Completer<void>();
      final browser = TestBrowser();
      final repo = ReportRepository(
        browser,
        baseUrl: 'https://example.test',
        client: MockClient((_) async => response(fixture())),
      );
      final h5 = H5Controller(
        translations(),
        repo,
        browser,
        language: 'th',
        ensureFont: (_) => gate.future,
        ensureTextFont: (_, _) => bodyFonts.future,
      );
      final model = ReportViewModel(h5, fixture()['id']);
      final pending = model.load();
      await Future<void>.delayed(Duration.zero);
      expect(model.report, isNull);
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(model.report, isNull);
      bodyFonts.complete();
      await pending;
      expect(model.report!.language, 'zh');
      expect(h5.language, 'zh');
      model.dispose();
      h5.dispose();
    },
  );

  test(
    'latest language request wins and the downloaded copy is reused',
    () async {
      final gate = Completer<Json>();
      final browser = TestBrowser();
      final repo = ReportRepository(browser);
      final thai = translations();
      final translated = <String, dynamic>{
        'jy': {'zh': object(thai['jy'])['zh']},
      };
      var requests = 0;
      final h5 = H5Controller(
        thai,
        repo,
        browser,
        loadTranslations: (_) {
          requests++;
          return gate.future;
        },
      );
      final chinese = h5.changeLanguage('zh');
      await h5.changeLanguage('th');
      gate.complete(translated);
      expect(await chinese, isFalse);
      expect(h5.language, 'th');
      expect(h5.translations, same(thai));
      expect(await h5.changeLanguage('zh'), isTrue);
      expect(h5.translations, same(translated));
      expect(requests, 1);
      h5.dispose();
    },
  );
}
