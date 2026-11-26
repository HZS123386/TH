import 'dart:async';
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
    await H5App.loadRoutesForWidgetTests();
  });
  for (final enabled in [false, true]) {
    testWidgets(
      'marriage preview keeps LINE as the claim option: $enabled',
      (tester) async {
        phone(tester);
        final data = marriageFixture()
          ..addAll({
            'checkout_enabled': enabled,
            'claim_code': '27801',
            'price': {
              'amount': 1000,
              'currency': 'THB',
              'display': '฿10',
              'mode': 'sunlands_order_only',
            },
          });
        final requests = <http.Request>[];
        final browser = TestBrowser();
        final repo = ReportRepository(
          browser,
          baseUrl: 'https://example.test',
          client: MockClient((request) async {
            requests.add(request);
            if (request.url.path == '/api/life-reports/${data['id']}')
              return response(data);
            return response({});
          }),
        );
        final h5 = H5Controller(translations(), repo, browser, language: 'zh');
        await tester.pumpWidget(
          H5App(
            controller: h5,
            initialLocation: '/report.html?id=${data['id']}&lang=zh',
          ),
        );
        await waitForDeferredView(
          tester,
          find.byKey(const ValueKey('free-report-content')),
        );
        expect(find.byKey(const ValueKey('jy-line-contact')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('jy-payment-preview')),
          findsNothing,
        );
        expect(
          requests.where(
            (request) =>
                request.url.path.contains('/payment') ||
                request.url.path.endsWith('/unlock'),
          ),
          isEmpty,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        h5.dispose();
      },
    );
  }
  testWidgets(
    'cashier return reads and verifies the existing order without creating another',
    (tester) async {
      phone(tester);
      final data = marriageFixture()
        ..addAll({
          'checkout_enabled': true,
          'price': {
            'amount': 1000,
            'currency': 'THB',
            'display': '฿10',
            'mode': 'sunlands_order_only',
          },
        });
      final reportPath = '/api/life-reports/${data['id']}';
      final calls = <String>[];
      final browser = TestBrowser();
      final repo = ReportRepository(
        browser,
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          if (request.url.path.contains('/payment'))
            calls.add('${request.method} ${request.url.path}');
          if (request.url.path == reportPath) return response(data);
          if (request.url.path == '$reportPath/payment')
            return response({
              'reference': '000000000001',
              'amount': 1000,
              'currency': 'THB',
              'order_number': 'OFFLINE_ORDER',
              'order_only': true,
              'state': 'CREATED',
            });
          if (request.url.path == '$reportPath/payment/check')
            return response({'paid': false});
          return response({});
        }),
      );
      final h5 = H5Controller(translations(), repo, browser, language: 'zh');
      await tester.pumpWidget(
        H5App(
          controller: h5,
          initialLocation:
              '/report.html?id=${data['id']}&lang=zh&payment_return=1',
        ),
      );
      await waitForDeferredView(tester, find.byType(ReportPaymentDialog));
      expect(calls, [
        'GET $reportPath/payment',
        'POST $reportPath/payment/check',
      ]);
      expect(find.text(h5.copy.t('checkout', 'pendingOrder')), findsOneWidget);
      expect(find.text(h5.copy.t('checkout', 'success')), findsNothing);
      expect(browser.openedPages, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );
  for (final language in ['zh', 'th']) {
    for (final existingOrder in [false, true]) {
      final orderType = existingOrder ? 'existing order' : 'new order';
      testWidgets(
        'Sunlands displays the current quote and waits for a selected method ($language, $orderType)',
        (tester) async {
          phone(tester);
          if (language == 'th') tester.view.physicalSize = const Size(320, 568);
          if (language == 'zh' && existingOrder) {
            tester.view.physicalSize = const Size(1280, 820);
          }
          final browser = TestBrowser();
          final data = fixture(language: language);
          final reportPath = '/api/life-reports/${data['id']}';
          final calls = <String>[];
          var paymentLaunches = 0;
          final currentAmount = existingOrder ? 3000 : 1000;
          const url =
              'https://trade.sunlands.com/trade/web/trade/payDirect.action?orderNumber=OFFLINE_ORDER&termType=mobile';
          final launches = existingOrder
              ? ['FM_PAYPAL', 'FM_ANTOM_LINEPAY']
              : ['FM_ANTOM_LINEPAY', 'FM_PAYPAL'];
          final launchError = existingOrder
              ? 'life_checkout_return_unavailable'
              : 'life_checkout_channel_link_missing';
          final redirect = existingOrder
              ? 'https://checkout.example.test/selected-method'
              : 'https://www.sandbox.paypal.com/checkoutnow?token=fixture';
          const methods = [
            'FM_ANTOM_LINEPAY',
            'FM_PAYPAL',
            'FM_ANTOM_PIX',
            'FM_ANTOM_PAGALEVE',
            'FM_ANTOM_MERCADOPAGO_BR',
          ];
          final order = {
            'reference': '000000000001',
            'amount': currentAmount,
            'currency': 'THB',
            'order_only': true,
            'state': 'CREATED',
            'order_number': 'OFFLINE_ORDER',
            'checkout_url': url,
          };
          final repo = ReportRepository(
            browser,
            baseUrl: 'https://example.test',
            client: MockClient((request) async {
              final path = request.url.path;
              if (path == '$reportPath/payment') {
                calls.add('${request.method} payment');
                expect(jsonDecode(request.body), isEmpty);
                return response(order);
              }
              if (path == '$reportPath/payment/methods') {
                calls.add('${request.method} methods');
                return response({'methods': methods, 'check_payment': false});
              }
              if (path == '$reportPath/payment/start') {
                calls.add('${request.method} start');
                paymentLaunches++;
                expect(jsonDecode(request.body), {
                  'method': launches[paymentLaunches - 1],
                });
                if (paymentLaunches == 1) {
                  return http.Response(
                    jsonEncode({'code': launchError}),
                    503,
                    headers: {'content-type': 'application/json'},
                  );
                }
                return response({'redirect_url': redirect});
              }
              if (path == '$reportPath/payment/check') {
                calls.add('${request.method} check');
              }
              return response({'paid': false});
            }),
          );
          final h5 = H5Controller(
            translations(),
            repo,
            browser,
            language: language,
          );
          final report = LifeReport.parse({
            ...data,
            'payment_simulation': false,
            'price': {
              'amount': currentAmount,
              'currency': 'THB',
              'display': '฿${currentAmount ~/ 100}',
              'mode': 'sunlands_order_only',
            },
          });
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ReportPaymentDialog(h5: h5, report: report),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(calls, ['POST payment', 'GET methods']);
          final dialog = find.byType(ReportPaymentDialog);
          expect(
            find.descendant(
              of: dialog,
              matching: find.text('฿${currentAmount ~/ 100}.00'),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(of: dialog, matching: find.byType(TextField)),
            findsNothing,
          );
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Image &&
                  widget.image is AssetImage &&
                  (widget.image as AssetImage).assetName.startsWith(
                    'assets/images/payment-',
                  ),
            ),
            findsNWidgets(5),
          );
          Finder tile(String method) =>
              find.byKey(ValueKey('payment-method-$method'));
          expect(
            tester.getTopLeft(tile(methods[0])).dy,
            tester.getTopLeft(tile(methods[1])).dy,
          );
          expect(
            tester.getTopLeft(tile(methods[0])).dx,
            tester.getTopLeft(tile(methods[2])).dx,
          );
          expect(browser.sameTabPages, isEmpty);
          final continueButton = find.byKey(const ValueKey('continue-payment'));
          expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);
          await click(tester, tile(launches.first));
          await click(tester, continueButton);
          expect(browser.openedPages, isEmpty);
          final message = h5.copy.t('checkout', launchError);
          expect(message, isNot(launchError));
          expect(find.text(message), findsOneWidget);
          expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);
          await click(tester, tile(launches.last));
          await click(tester, continueButton);
          expect(calls.last, 'POST start');
          if (existingOrder) {
            expect(browser.sameTabPages, [redirect]);
          } else {
            expect(browser.openedPages, isEmpty);
            expect(
              find.text(h5.copy.t('checkout', 'pendingOrder')),
              findsOneWidget,
            );
            final openPayPal = find.byKey(const ValueKey('open-paypal'));
            await click(tester, openPayPal);
            expect(browser.openedPages, [redirect]);
            expect(browser.sameTabPages, isEmpty);
            await tester.pump(const Duration(seconds: 5));
            await tester.pumpAndSettle();
            expect(calls.last, 'POST check');
            expect(paymentLaunches, 2);
            expect(find.text(h5.copy.t('checkout', 'success')), findsNothing);
            expect(find.byType(ReportPaymentDialog), findsOneWidget);
            expect(tester.widget<FilledButton>(openPayPal).onPressed, isNull);
            await click(
              tester,
              find.text(h5.copy.t('checkout', 'openPayPalHere')),
            );
            expect(browser.sameTabPages, [redirect]);
            expect(paymentLaunches, 2);
          }
          expect(
            browser.readSetting(
              ReportPaymentDialog.pendingReportKey,
              session: true,
            ),
            data['id'],
          );
          await tester.pumpWidget(const SizedBox.shrink());
          h5.dispose();
        },
      );
    }
  }

  testWidgets(
    'Sunlands keeps an order locked when checkout cannot verify the quote',
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
          if (request.url.path.endsWith('/methods')) {
            return http.Response(
              '{"code":"life_checkout_unavailable"}',
              409,
              headers: {'content-type': 'application/json'},
            );
          }
          bodies.add(object(jsonDecode(request.body)));
          return response({
            'reference': '000000000001',
            'amount': 1000,
            'currency': 'THB',
            'order_only': true,
            'state': 'CREATED',
            'order_number': '202611120001',
            'checkout_url':
                'https://trade.sunlands.com/trade/web/trade/payDirect.action?orderNumber=202611120001',
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
      expect(find.text('฿10.00'), findsOneWidget);
      expect(bodies, [{}]);
      expect(
        find.text(h5.copy.t('checkout', 'life_checkout_unavailable')),
        findsOneWidget,
      );
      expect(browser.openedPages, isEmpty);
      expect(
        find.widgetWithText(FilledButton, h5.copy.t('checkout', 'openCashier')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('test-card-number')), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(paths, [
        '/api/life-reports/${report.id}/payment',
        '/api/life-reports/${report.id}/payment/methods',
      ]);
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
            if (request.url.path.endsWith('/methods')) {
              return response({'methods': [], 'check_payment': false});
            }
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
          expect(find.text(h5.copy.t('checkout', 'noMethods')), findsOneWidget);
          expect(paths, [
            '/api/life-reports/${report.id}/payment',
            '/api/life-reports/${report.id}/payment',
            '/api/life-reports/${report.id}/payment/methods',
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
              ? find.text(h5.copy.t('jy', 'report.title'))
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
}
