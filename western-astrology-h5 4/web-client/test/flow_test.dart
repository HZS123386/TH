import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:go_router/go_router.dart';
import 'package:fate_h5/app/controller.dart';
import 'package:fate_h5/app/h5_app.dart';
import 'package:fate_h5/core/models.dart';
import 'package:fate_h5/core/repository.dart';
import 'package:fate_h5/features/birth_date_dialog.dart';
import 'package:fate_h5/features/generation_dialog.dart';
import 'package:fate_h5/features/generation_video.dart';
import 'package:fate_h5/features/landing_page.dart';
import 'package:fate_h5/features/report_view_model.dart';
import 'package:fate_h5/features/place_picker.dart';
import 'package:fate_h5/features/checkout_dialog.dart';
import 'package:fate_h5/ui/jy_components.dart';
import 'package:fate_h5/ui/theme.dart';
import 'support.dart';

http.Response response(dynamic value) => http.Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
const province = {
  'id': 'geonames:1609348',
  'countryCode': 'TH',
  'nameEnglish': 'Bangkok',
  'nameChinese': '曼谷',
  'nameThai': 'กรุงเทพมหานคร',
  'timeZone': 'Asia/Bangkok',
  'placeType': 'province',
  'latitude': 13.75398,
  'longitude': 100.50144,
};

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
    await LandingPage.loadDialogsForWidgetTests();
  });

  for (final language in ['zh', 'th']) {
    testWidgets('$language history retries list and sign-in code timeouts', (tester) async {
      phone(tester);
      final report = fixture(language: language);
      final browser = TestBrowser();
      final slowList = Completer<http.Response>();
      final slowCode = Completer<http.Response>();
      var listRequests = 0, codeRequests = 0;
      final repo = ReportRepository(browser, baseUrl: 'https://example.test', client: MockClient((request) async {
        if (request.url.path == '/api/life-reports') {
          expect(request.method, 'GET');
          listRequests++;
          if (listRequests == 1) return slowList.future;
          return response({'items': [report]});
        }
        if (request.url.path == "/api/life-reports/${report['id']}/app-login-code") {
          expect(request.headers['X-Report-Key'], browser.key);
          codeRequests++;
          if (codeRequests == 1) return slowCode.future;
          return response({'code': 'A2B3C4', 'expires_in': 600});
        }
        return response({'notice_version': H5Controller.noticeVersion});
      }));
      final h5 = H5Controller(translations(), repo, browser, language: language)..enterLanding();
      await tester.pumpWidget(H5App(controller: h5, initialLocation: '/?lang=$language'));
      await tester.pumpAndSettle();
      String label(String key) => h5.copy.t('jy', key);

      final history = find.text(label('history'));
      await tester.ensureVisible(history);
      await tester.tap(history);
      await tester.pump();
      final retryList = find.text(h5.copy.t('generation', 'retry'));
      await tester.pump(const Duration(seconds: 9));
      expect(listRequests, 1);
      expect(retryList, findsNothing);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(retryList, findsOneWidget);
      expect(codeRequests, 0);
      await click(tester, retryList);
      slowList.complete(response({'items': []}));
      await tester.pumpAndSettle();
      expect(listRequests, 2);
      expect(find.text(label('openReport')), findsOneWidget);
      await click(tester, find.text(label('appLogin.get')));
      expect(find.text(label('appLogin.loading')), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text(label('appLogin.failed')), findsOneWidget);
      await click(tester, find.text(label('appLogin.refresh')));
      slowCode.complete(response({'code': 'D5E6F7', 'expires_in': 600}));
      await tester.pumpAndSettle();

      expect(tester.widget<SelectableText>(find.byKey(const ValueKey('h5-app-login-code'))).data, 'A2B3C4');
      expect(codeRequests, 2);
      final historyHome = find.descendant(
        of: find.byType(Dialog),
        matching: find.byTooltip(label('checkout.back')),
      );
      await click(tester, historyHome);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byKey(const ValueKey('welcome-start')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    });

    testWidgets('$language refresh resumes the saved queue with no duplicate submission', (tester) async {
      phone(tester);
      final done = fixture(language: language);
      var current = {...done, 'preview': null, 'preview_state': 'queued', 'chart': null,
        'generation_queue': {'state': 'queued', 'position': 12}};
      final browser = TestBrowser()..settings['session:active-preview'] = done['id'] as String;
      final requests = <String>[];
      var codeRequests = 0;
      final repo = ReportRepository(browser, baseUrl: 'https://example.test', client: MockClient((request) async {
        if (request.url.path == "/api/life-reports/${done['id']}/app-login-code") {
          expect(request.method, 'POST');
          expect(request.headers['X-Report-Key'], browser.key);
          codeRequests++;
          return response({'code': 'A2B3C4', 'expires_in': 600});
        }
        if (request.url.path.startsWith('/api/life-reports')) {
          requests.add('${request.method} ${request.url.path}');
          return response(current);
        }
        return response({'notice_version': H5Controller.noticeVersion});
      }));
      final h5 = H5Controller(translations(), repo, browser, language: language)..enterLanding();
      await tester.pumpWidget(H5App(controller: h5, initialLocation: '/?lang=$language'));
      await waitForDeferredView(tester, find.byType(GenerationDialog));
      expect(find.byType(GenerationDialog), findsOneWidget);
      expect(find.text(h5.copy.t('jy', 'interpretation.queued')), findsOneWidget);
      expect(tester.widget<SelectableText>(find.byKey(const ValueKey('h5-app-login-code'))).data, 'A2B3C4');
      expect(requests.every((request) => request.startsWith('GET ')), isTrue);
      tester.widget<GenerationDialog>(find.byType(GenerationDialog)).onCancel();
      await tester.pumpAndSettle();
      final queuedLabel = h5.copy.t('life', 'previewStates.queued');
      expect(queuedLabel, isNotEmpty);
      expect(find.text(queuedLabel), findsOneWidget);
      expect(find.text(h5.copy.t('life', 'viewProgress')), findsOneWidget);
      current = done;
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('free-report-content')), findsOneWidget);
      expect(codeRequests, 1);
      expect(requests.every((request) => request.startsWith('GET ')), isTrue);
      for (final width in [320.0, 360.0, 1100.0]) {
        tester.view.physicalSize = Size(width, 640);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$language report at width $width');
      }
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    });

    testWidgets('$language paid queue resumes the original report and keeps polling after leaving the animation', (tester) async {
      phone(tester);
      final done = fixture(language: language, full: true);
      var current = {
        ...done,
        'full_state': 'queued',
        'chapters': [],
        'plan': null,
        'progress': {'completed': 0, 'total': object(done['progress'])['total']},
      };
      final browser = TestBrowser();
      final methods = <String>[];
      var codeRequests = 0;
      final repo = ReportRepository(browser, baseUrl: 'https://example.test',
        client: MockClient((request) async {
          if (request.url.path == "/api/life-reports/${done['id']}/app-login-code") {
            expect(request.method, 'POST');
            codeRequests++;
            return response({'code': 'A2B3C4', 'expires_in': 600});
          }
          if (request.url.path.startsWith('/api/life-reports')) methods.add(request.method);
          return response(current);
        }),
      );
      final h5 = H5Controller(translations(), repo, browser, language: language);
      await tester.pumpWidget(H5App(
        controller: h5, initialLocation: '/report.html?id=${done['id']}&lang=$language',
      ));
      final label = h5.copy.t('life', 'states.queued');
      expect(label, isNotEmpty);
      await waitForDeferredView(tester, find.textContaining(label));
      expect(find.textContaining(label), findsWidgets);
      await click(tester, find.text(h5.copy.t('life', 'viewProgress')));
      expect(find.text(h5.copy.t('jy', 'interpretation.queued')), findsOneWidget);
      if (language == 'th') {
        browser.writeSetting('active-preview', text(done['id']), session: true);
        await click(tester, find.byTooltip(h5.copy.t('jy', 'checkout.back')));
        expect(find.byType(LandingPage), findsNothing);
        expect(find.byType(GenerationDialog), findsNothing);
        expect(find.byKey(const ValueKey('welcome-start')), findsOneWidget);
        expect(browser.readSetting('active-preview', session: true), isEmpty);
        expect(methods.every((method) => method == 'GET'), isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
        h5.dispose();
        return;
      }
      tester.widget<GenerationDialog>(find.byType(GenerationDialog)).onCancel();
      await tester.pumpAndSettle();
      current = done;
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.textContaining(label), findsNothing);
      expect(find.text(h5.copy.t('life', 'viewProgress')), findsNothing);
      expect(methods.length, greaterThan(1));
      expect(methods.every((method) => method == 'GET'), isTrue);
      expect(codeRequests, 1);
      for (final width in [320.0, 1100.0]) {
        tester.view.physicalSize = Size(width, 640);
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    });
  }
  testWidgets('legacy H5 checkout opens the free report with LINE contact', (tester) async {
    phone(tester);
    final browser = TestBrowser();
    final paid = fixture(full: true);
    final data = {
      ...fixture(),
      'claim_code': '57248',
      'payment_simulation': false,
      'price': {'amount': 3000, 'currency': 'THB', 'display': '฿30', 'mode': 'sunlands_order_only'},
      'chapters': paid['chapters'],
      'plan': paid['plan'],
    };
    final calls = <String>[];
    final repo = ReportRepository(browser, baseUrl: 'https://example.test',
      client: MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        return response(data);
      }),
    );
    final h5 = H5Controller(translations(), repo, browser, language: 'zh');
    await tester.pumpWidget(H5App(controller: h5,
      initialLocation: '/report.html?id=${data['id']}&lang=zh&checkout=1'));
    await waitForDeferredView(tester, find.byKey(const ValueKey('free-report-content')));
    expect(find.byKey(const ValueKey('free-report-content')), findsOneWidget);
    expect(browser.activities.last, {'page': 'preview_report', 'action': 'report_ready'});
    final paidText = text(object(objects(paid['chapters']).first['summary'])['text']);
    expect(find.text(paidText), findsNothing);
    expect(find.byType(ReportBadges), findsOneWidget);
    final contact = find.byKey(const ValueKey('jy-line-contact'));
    expect(find.text(h5.copy.t('jy', 'lineContact.action')), findsOneWidget);
    final claimNumber = find.byWidgetPredicate(
      (widget) => widget is SelectableText && widget.data == data['claim_code'],
    );
    expect(claimNumber, findsOneWidget);
    expect(find.text(h5.copy.t('jy', 'lineContact.claimNumber')), findsOneWidget);
    final messenger = tester.binding.defaultBinaryMessenger;
    String? copied;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await click(tester, find.widgetWithText(TextButton, h5.copy.t('jy', 'lineContact.copyReportId')));
    expect(copied, data['claim_code']);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/images/line-contact-qr.jpg'),
        tester.element(contact),
      );
    });
    await click(tester, contact);
    final qr = find.descendant(of: find.byType(AlertDialog), matching: find.byType(Image));
    expect((tester.widget<Image>(qr).image as AssetImage).assetName,
        'assets/images/line-contact-qr.jpg');
    expect(find.descendant(of: find.byType(AlertDialog), matching: claimNumber), findsOneWidget);
    expect(find.text(h5.copy.t('jy', 'lineContact.scan')), findsOneWidget);
    expect(browser.openedPages, isEmpty);
    await click(tester, find.text(h5.copy.t('jy', 'lineContact.open')));
    expect(browser.openedPages, ['https://line.me/ti/p/TrGGcMWmuV']);
    browser.openedPages.clear();
    await click(tester, find.widgetWithText(TextButton, h5.copy.t('jy', 'close')));
    expect(find.byType(AlertDialog), findsNothing);
    await click(tester, contact);
    await click(tester, find.widgetWithText(TextButton, h5.copy.t('jy', 'close')));
    expect(browser.activities.where((event) => event['action'] == 'open_line_contact'), hasLength(2));
    expect(browser.activities.where((event) => event['action'] == 'line_qr_shown'), hasLength(2));
    expect(find.byKey(const ValueKey('jy-app-download')), findsNothing);
    expect(find.byKey(const ValueKey('jy-payment-preview')), findsNothing);
    expect(find.text('฿30'), findsNothing);
    expect(find.byType(ReportPaymentDialog), findsNothing);
    expect(find.byType(ReportPreview), findsOneWidget);
    expect(calls.where((call) => call.contains('/payment') || call.endsWith('/unlock')), isEmpty);
    expect(browser.openedPages, isEmpty);
    await click(tester, find.byTooltip(h5.copy.t('jy', 'checkout.back')));
    expect(find.byType(ReportPreview), findsNothing);
    expect(find.byKey(const ValueKey('welcome-start')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    h5.dispose();
  });

  for (final language in ['zh', 'th']) {
    for (final existingOrder in [false, true]) {
      final orderType = existingOrder ? 'existing order' : 'new order';
      testWidgets('Sunlands displays the current quote and waits for a selected method ($language, $orderType)', (tester) async {
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
        const url = 'https://trade.sunlands.com/trade/web/trade/payDirect.action?orderNumber=OFFLINE_ORDER&termType=mobile';
        final launches = existingOrder ? ['FM_PAYPAL', 'FM_ANTOM_LINEPAY'] : ['FM_ANTOM_LINEPAY', 'FM_PAYPAL'];
        final launchError = existingOrder ? 'life_checkout_return_unavailable' : 'life_checkout_channel_link_missing';
        final redirect = existingOrder ? 'https://checkout.example.test/selected-method' :
            'https://www.sandbox.paypal.com/checkoutnow?token=fixture';
        const methods = [
          'FM_ANTOM_LINEPAY', 'FM_PAYPAL', 'FM_ANTOM_PIX',
          'FM_ANTOM_PAGALEVE', 'FM_ANTOM_MERCADOPAGO_BR',
        ];
        final order = {
          'reference': '000000000001', 'amount': currentAmount, 'currency': 'THB',
          'order_only': true, 'state': 'CREATED', 'order_number': 'OFFLINE_ORDER', 'checkout_url': url,
        };
        final repo = ReportRepository(browser, baseUrl: 'https://example.test',
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
              expect(jsonDecode(request.body), {'method': launches[paymentLaunches - 1]});
              if (paymentLaunches == 1) {
                return http.Response(jsonEncode({'code': launchError}), 503,
                    headers: {'content-type': 'application/json'});
              }
              return response({'redirect_url': redirect});
            }
            if (path == '$reportPath/payment/check') {
              calls.add('${request.method} check');
            }
            return response({'paid': false});
          }),
        );
        final h5 = H5Controller(translations(), repo, browser, language: language);
        final report = LifeReport.parse({
          ...data,
          'payment_simulation': false,
          'price': {
            'amount': currentAmount, 'currency': 'THB',
            'display': '฿${currentAmount ~/ 100}', 'mode': 'sunlands_order_only',
          },
        });
        await tester.pumpWidget(MaterialApp(home: Scaffold(
          body: ReportPaymentDialog(h5: h5, report: report),
        )));
        await tester.pumpAndSettle();
        expect(calls, ['POST payment', 'GET methods']);
        final dialog = find.byType(ReportPaymentDialog);
        expect(find.descendant(of: dialog, matching: find.text('฿${currentAmount ~/ 100}.00')),
            findsOneWidget);
        expect(find.descendant(of: dialog, matching: find.byType(TextField)), findsNothing);
        expect(find.byWidgetPredicate((widget) =>
          widget is Image && widget.image is AssetImage &&
          (widget.image as AssetImage).assetName.startsWith('assets/images/payment-'),
        ), findsNWidgets(5));
        Finder tile(String method) => find.byKey(ValueKey('payment-method-$method'));
        expect(tester.getTopLeft(tile(methods[0])).dy, tester.getTopLeft(tile(methods[1])).dy);
        expect(tester.getTopLeft(tile(methods[0])).dx, tester.getTopLeft(tile(methods[2])).dx);
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
          expect(find.text(h5.copy.t('checkout', 'pendingOrder')), findsOneWidget);
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
          await click(tester, find.text(h5.copy.t('checkout', 'openPayPalHere')));
          expect(browser.sameTabPages, [redirect]);
          expect(paymentLaunches, 2);
        }
        expect(browser.readSetting(ReportPaymentDialog.pendingReportKey, session: true), data['id']);
        await tester.pumpWidget(const SizedBox.shrink());
        h5.dispose();
      });
    }
  }

  testWidgets('Sunlands keeps an order locked when checkout cannot verify the quote', (tester) async {
    phone(tester);
    final browser = TestBrowser();
    final paths = <String>[];
    final bodies = <Json>[];
    final report = LifeReport.parse({
      ...fixture(),
      'payment_simulation': false,
      'price': {'amount': 1000, 'currency': 'THB', 'display': '฿10', 'mode': 'sunlands_order_only'},
    });
    final repo = ReportRepository(browser, baseUrl: 'https://example.test', client: MockClient((request) async {
      paths.add(request.url.path);
      if (request.url.path.endsWith('/methods')) {
        return http.Response('{"code":"life_checkout_unavailable"}', 409,
            headers: {'content-type': 'application/json'});
      }
      bodies.add(object(jsonDecode(request.body)));
      return response({'reference': '000000000001', 'amount': 1000, 'currency': 'THB',
        'order_only': true, 'state': 'CREATED', 'order_number': '202611120001',
        'checkout_url': 'https://trade.sunlands.com/trade/web/trade/payDirect.action?orderNumber=202611120001'});
    }));
    final h5 = H5Controller(translations(), repo, browser, language: 'zh');
    await tester.pumpWidget(MaterialApp(home: ReportPaymentDialog(h5: h5, report: report)));
    await tester.pumpAndSettle();
    expect(find.text('฿10.00'), findsOneWidget);
    expect(bodies, [{}]);
    expect(find.text(h5.copy.t('checkout', 'life_checkout_unavailable')), findsOneWidget);
    expect(browser.openedPages, isEmpty);
    expect(find.text('前往收银台'), findsNothing);
    expect(find.byKey(const ValueKey('test-card-number')), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(paths, ['/api/life-reports/${report.id}/payment', '/api/life-reports/${report.id}/payment/methods']);
    expect(report.full, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    h5.dispose();
  });
  for (final failure in [
    ('life_order_access_denied', 'accessDenied', 503),
    ('life_order_rejected', 'orderRejected', 409),
    ('life_order_channel_invalid', 'channelInvalid', 409),
    ('life_order_needs_review', 'orderNeedsReview', 409),
  ]) {
    testWidgets('Sunlands shows ${failure.$1} without payment or automatic retry', (tester) async {
      phone(tester);
      final browser = TestBrowser();
      final paths = <String>[];
      final report = LifeReport.parse({
        ...fixture(),
        'payment_simulation': false,
        'price': {'amount': 3000, 'currency': 'THB', 'display': '฿30', 'mode': 'sunlands_order_only'},
      });
      final repo = ReportRepository(browser, baseUrl: 'https://example.test', client: MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path.endsWith('/methods')) {
          return response({'methods': [], 'check_payment': false});
        }
        if (paths.length == 1) {
          return http.Response(jsonEncode({'code': failure.$1}), failure.$3,
              headers: {'content-type': 'application/json'});
        }
        return response({'reference': '000000000001', 'amount': 3000, 'currency': 'THB',
          'order_only': true, 'state': 'CREATED', 'order_number': '202611120001'});
      }));
      final h5 = H5Controller(translations(), repo, browser, language: 'zh');
      await tester.pumpWidget(MaterialApp(home: ReportPaymentDialog(h5: h5, report: report)));
      await tester.pumpAndSettle();
      expect(find.text(h5.copy.t('checkout', failure.$2)), findsOneWidget);
      expect(find.byKey(const ValueKey('continue-payment')), findsNothing);
      expect(find.byKey(const ValueKey('test-card-number')), findsNothing);
      expect(paths, ['/api/life-reports/${report.id}/payment']);
      if (failure.$1 == 'life_order_access_denied') {
        await click(tester, find.widgetWithText(TextButton, h5.copy.t('checkout', 'retry')));
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
    });
  }
  for (final (language, providerReturn, full) in [
    ('th', false, false), ('zh', true, false), ('th', true, true),
  ]) {
    final returnMethod = providerReturn ? 'provider return' : 'browser return';
    testWidgets('H5 reads the original $language report without payment on $returnMethod', (tester) async {
      phone(tester);
      final browser = TestBrowser();
      final requests = <http.Request>[];
      final data = fixture(language: language, full: full);
      final reportPath = '/api/life-reports/${data['id']}';
      if (!providerReturn) {
        browser.writeSetting(ReportPaymentDialog.pendingReportKey, text(data['id']), session: true);
      }
      final repo = ReportRepository(browser, baseUrl: 'https://example.test', client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == reportPath) {
          return response({
            ...data, 'payment_simulation': false,
            'price': {'amount': 1000, 'currency': 'THB', 'display': '฿10', 'mode': 'sunlands_order_only'},
          });
        }
        return response({});
      }));
      final h5 = H5Controller(translations(), repo, browser, language: language);
      final returnQuery = providerReturn ? '&payment_return=1' : '';
      await tester.pumpWidget(H5App(controller: h5,
        initialLocation: '/report.html?id=${data['id']}&lang=$language$returnQuery'));
      await waitForDeferredView(tester, full
          ? find.text(text(data['title']))
          : find.byKey(const ValueKey('free-report-content')));
      await tester.pumpAndSettle();
      expect(find.byType(ReportPaymentDialog), findsNothing);
      expect(requests.where((r) => r.url.path == reportPath), hasLength(1));
      expect(requests.where((r) => r.url.path.contains('/payment') ||
          r.url.path.endsWith('/unlock')), isEmpty);
      expect(browser.openedPages, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    });
  }

  testWidgets('Sunlands retries a failed order read without falling through to create', (tester) async {
    phone(tester);
    final browser = TestBrowser();
    final requests = <http.Request>[];
    final report = LifeReport.parse({
      ...fixture(), 'payment_simulation': false,
      'price': {'amount': 3000, 'currency': 'THB', 'display': '฿30', 'mode': 'sunlands_order_only'},
    });
    final repo = ReportRepository(browser, baseUrl: 'https://example.test', client: MockClient((request) async {
      requests.add(request);
      return http.Response('{}', 500, headers: {'content-type': 'application/json'});
    }));
    final h5 = H5Controller(translations(), repo, browser, language: 'zh');
    await tester.pumpWidget(MaterialApp(home: ReportPaymentDialog(h5: h5, report: report, returning: true)));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await click(tester, find.widgetWithText(TextButton, h5.copy.t('checkout', 'retry')));
    expect(requests.length, 2);
    expect(requests.every((r) => r.method == 'GET'), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    h5.dispose();
  });

  testWidgets('Sunlands retries inquiry after permission failure and opens report only after confirmed paid', (tester) async {
    phone(tester);
    final browser = TestBrowser();
    final requests = <http.Request>[];
    var checks = 0;
    bool? completed;
    final report = LifeReport.parse({
      ...fixture(), 'payment_simulation': false,
      'price': {'amount': 3000, 'currency': 'THB', 'display': '฿30', 'mode': 'sunlands_order_only'},
    });
    final repo = ReportRepository(browser, baseUrl: 'https://example.test', client: MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        return response({'reference': '000000000003', 'amount': 3000, 'currency': 'THB',
          'order_only': true, 'state': 'CREATED', 'order_number': 'OFFLINE_ORDER_SETTLEMENT'});
      }
      expect(request.url.path, '/api/life-reports/${report.id}/payment/check');
      checks++;
      if (checks == 1) {
        return http.Response('{"code":"life_payment_check_access_denied"}', 503,
          headers: {'content-type': 'application/json'});
      }
      return response({'paid': checks >= 3});
    }));
    final h5 = H5Controller(translations(), repo, browser, language: 'zh');
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      body: TextButton(onPressed: () async {
        completed = await showDialog<bool>(context: context,
          builder: (_) => ReportPaymentDialog(h5: h5, report: report, returning: true));
      }, child: const Text('Open checkout')),
    ))));
    await click(tester, find.text('Open checkout'));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(checks, 1);
    expect(completed, isNull);
    final retry = find.widgetWithText(TextButton, h5.copy.t('checkout', 'checkPayment'));
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
    expect(requests.where((r) => r.method == 'POST' && r.url.path.endsWith('/payment')), isEmpty);
    expect(browser.openedPages, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    h5.dispose();
  });

  testWidgets('simulated card checkout validates locally and sends only the order reference', (tester) async {
    phone(tester);
    final browser = TestBrowser();
    final paid = Completer<http.Response>();
    final submitted = <Json>[];
    final report = LifeReport.parse({
      ...fixture(),
      'payment_simulation': true,
      'price': {'amount': 3000, 'currency': 'THB', 'display': '฿30', 'mode': 'direct'},
    });
    final repo = ReportRepository(browser, baseUrl: 'https://example.test', client: MockClient((request) async {
      if (request.url.path.endsWith('/payment/simulate')) {
        submitted.add(object(jsonDecode(request.body)));
        return paid.future;
      }
      return response({'reference': '000000000001', 'amount': 3000, 'currency': 'THB'});
    }));
    final h5 = H5Controller(translations(), repo, browser, language: 'zh');
    await tester.pumpWidget(MaterialApp(home: ReportPaymentDialog(h5: h5, report: report)));
    await tester.pumpAndSettle();
    expect(find.text('฿30'), findsOneWidget);
    expect(find.textContaining('0001'), findsOneWidget);
    final confirm = find.widgetWithText(FilledButton, h5.copy.t('checkout', 'cardConfirm'));
    await click(tester, confirm);
    expect(submitted, isEmpty);
    await tester.enterText(find.byKey(const ValueKey('test-card-number')), '4000 0000 0000 0000');
    await tester.enterText(find.byKey(const ValueKey('test-card-expiry')), '12/30');
    await tester.enterText(find.byKey(const ValueKey('test-card-security-code')), '123');
    await click(tester, confirm);
    expect(submitted, isEmpty);
    await click(tester, find.widgetWithText(OutlinedButton, h5.copy.t('checkout', 'fillCard')));
    await click(tester, confirm);
    expect(submitted, [{'reference': '000000000001'}]);
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    expect(find.text(h5.copy.t('checkout', 'demoSuccess')), findsNothing);
    paid.complete(response({'paid': true}));
    await tester.pumpAndSettle();
    expect(find.text(h5.copy.t('checkout', 'demoSuccess')), findsOneWidget);
    expect(find.byKey(const ValueKey('test-card-number')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    h5.dispose();
  });
  testWidgets(
    'generation keeps the same visible wheel across stages until the report is ready',
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
            full: false,
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
      expect(find.text(h5.copy.t('jy', 'interpretation.complete')), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.textContaining(RegExp('Qwen|RoxyAPI', caseSensitive: false)), findsNothing);
      await tester.pump(const Duration(milliseconds: 320));
      await tester.pump();
      expect(completed, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
      h5.dispose();
    },
  );
  testWidgets('an already readable report skips the remaining stages', (tester) async {
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

  testWidgets(
    'Thai birth picker fits a small phone and language switching preserves the entry URL',
    (tester) async {
      phone(tester);
      final browser = TestBrowser();
      final h5 = H5Controller(
        translations(),
        ReportRepository(browser),
        browser,
      );
      h5.enterLanding();
      await tester.pumpWidget(
        H5App(
          controller: h5,
          initialLocation: '/?lang=th&topic=love&startup=1',
        ),
      );
      await tester.pumpAndSettle();
      final thaiHeading = tester.widget<Text>(
        find.text('จากเวลาเกิด ค้นหาคนที่ชักใยความรักของคุณ'),
      );
      final thaiCaption = tester.widget<Text>(
        find.text(
          'อ่านลักษณะพื้นดวงฟรี แล้วค้นหาอิทธิพลของดาวที่เป็นอุปสรรคต่อความรัก',
        ),
      );
      expect(thaiHeading.style?.color, gold);
      expect(thaiCaption.style?.color, lavender);
      await click(tester, find.byKey(const ValueKey('birth-date')));
      expect(find.byType(BirthDateDialog), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'ยืนยัน'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await click(tester, find.widgetWithText(FilledButton, 'ยืนยัน'));
      await click(tester, find.widgetWithText(TextButton, '中文'));
      final route = GoRouter.of(
        tester.element(find.byType(LandingPage)),
      ).routeInformationProvider.value.uri;
      expect(route.queryParameters, containsPair('lang', 'zh'));
      expect(route.queryParameters, containsPair('topic', 'love'));
      expect(route.queryParameters, containsPair('startup', '1'));
      final heading = tester.widget<Text>(
        find.text('从出生时刻，揪出感情的搅局者'),
      );
      final caption = tester.widget<Text>(
        find.text('先免费获取本命星象特质，定位姻缘里的暗星阻碍'),
      );
      expect(heading.style?.color, gold);
      expect(caption.style?.color, lavender);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );
  for (final language in ['zh', 'th']) {
    testWidgets(
      'JY submits with no data-use dialog and opens the free report ($language)',
      (tester) async {
        phone(tester);
        final browser = TestBrowser()..settings.remove('fate-data-use-version');
        Json? input;
        final preview = fixture(language: language);
        var current = preview;
        var consentAttempts = 0;
        final calls = <String>[];
        final repo = ReportRepository(
          browser,
          baseUrl: 'https://example.test',
          client: MockClient((request) async {
            calls.add('${request.method} ${request.url.path}');
            if (request.url.path == '/api/thai-locations') {
              return response({
                'items': request.url.queryParameters['level'] == 'province'
                    ? [province]
                    : [],
                'total': request.url.queryParameters['level'] == 'province'
                    ? 1
                    : 0,
              });
            }
            if (request.url.path == '/api/landing/config') {
              return response({'notice_version': H5Controller.noticeVersion});
            }
            if (request.url.path == '/api/landing/consents') {
              expect(jsonDecode(request.body), {
                'notice_version': H5Controller.noticeVersion,
                'granted': true,
              });
              consentAttempts++;
              if (language == 'zh' && consentAttempts == 1) {
                return http.Response('{"code":"busy"}', 503,
                    headers: {'content-type': 'application/json'});
              }
              return response({
                'accepted': true,
                'notice_version': H5Controller.noticeVersion,
              });
            }
            if (request.method == 'POST' && request.url.path == '/api/life-reports') {
              input = object(jsonDecode(request.body));
              final chart = object(preview['chart']);
              current = {
                ...preview,
                'input': input,
                'time_accuracy': {
                  'mode': 'estimated',
                  'assumed_local_time': '12:00',
                },
                'chart': {
                  ...chart,
                  'precision': 'estimated',
                  'houses': [],
                  'planets': [
                    for (final p in objects(chart['planets']))
                      if (p['id'] != 'ascendant') {...p, 'house': null},
                  ],
                },
              };
            }
            return response(current);
          }),
        );
        final h5 = H5Controller(translations(), repo, browser, language: language)
          ..enterLanding();
        await tester.pumpWidget(
          H5App(controller: h5, initialLocation: '/?lang=$language'),
        );
        await tester.pumpAndSettle();
        expect(browser.activities.last['action'], 'form_progress_empty');
        await click(tester, find.byKey(const ValueKey('birth-date')));
        expect(browser.activities.last['action'], 'select_birth_date');
        await click(
          tester,
          find.widgetWithText(FilledButton, h5.copy.t('ui', 'confirm')),
        );
        expect(browser.activities.last['action'], 'form_progress_time');
        await click(tester, find.byKey(const ValueKey('birth-time-unknown')));
        expect(browser.activities.last['action'], 'form_progress_place');
        expect(find.byKey(const ValueKey('birth-country')), findsNothing);
        expect(find.byKey(const ValueKey('birth-city')), findsNothing);
        expect(find.byKey(const ValueKey('write-question')), findsNothing);
        expect(find.byKey(const ValueKey('custom-question')), findsNothing);
        expect(find.byKey(const ValueKey('question-0')), findsNothing);
        await click(tester, find.byKey(const ValueKey('birth-province')));
        await click(
          tester,
          find.descendant(
            of: find.byType(PlacePicker),
            matching: find.text(Place(province).label(language)),
          ),
        );
        expect(browser.activities.last['action'], 'form_progress_complete');
        expect(input, isNull);
        await click(tester, find.byKey(const ValueKey('birth-time-unknown')));
        expect(browser.activities.last['action'], 'form_progress_time');
        await click(tester, find.byKey(const ValueKey('birth-time-unknown')));
        expect(find.text(h5.copy.t('jy', 'submitConsent')), findsOneWidget);
        expect(consentAttempts, 0);
        final generate = find.byKey(const ValueKey('generate-report'));
        await click(tester, generate);
        expect(find.byType(AlertDialog), findsNothing);
        if (language == 'zh') {
          expect(find.text(h5.copy.t('jy', 'consentError')), findsOneWidget);
          expect(input, isNull);
          expect(h5.noticeAccepted, isFalse);
          await click(tester, generate);
        }
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 600));
        await waitForDeferredView(tester, find.byType(ReportPreview));
        expect(input, isNotNull);
        expect(object(input!['profile'])['birth_time'], isNull);
        expect(object(input!['profile'])['birth_date'], '1999-01-01');
        expect(object(input!['profile'])['location_id'], province['id']);
        expect(object(input!['profile'])['country_code'], 'TH');
        expect(object(input!['profile'])['timezone'], 'Asia/Bangkok');
        expect(input!.containsKey('career_question'), isFalse);
        expect(input!.containsKey('user_question'), isFalse);
        expect(input!['report_kind'], 'fortune');
        expect(calls.indexOf('POST /api/landing/consents'), greaterThanOrEqualTo(0));
        expect(calls.indexOf('POST /api/landing/consents'),
            lessThan(calls.indexOf('POST /api/life-reports')));
        expect(h5.noticeAccepted, isTrue);
        expect(browser.activities.any((activity) => activity['page'] == 'consent'), isFalse);
        expect(
          browser.activities.where((activity) => activity['action'] == 'consent_accept'),
          [{'page': 'birth_form', 'action': 'consent_accept'}],
        );
        expect(calls.any((value) => value.endsWith('/unlock')), isFalse);
        expect(find.byType(GenerationDialog), findsNothing);
        expect(find.byType(ReportPreview), findsOneWidget);
        expect(find.text(h5.copy.t('jy', 'report.freeTitle')), findsOneWidget);
        expect(find.byKey(const ValueKey('jy-payment-preview')), findsNothing);
        expect(find.byKey(const ValueKey('free-report-content')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        h5.dispose();
      },
    );
  }
  testWidgets(
    'saved complete reports show the original cover, expandable chapters and PDF export',
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
      await click(
        tester,
        find.widgetWithText(InkWell, labels.t('report', 'plan')),
      );
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
