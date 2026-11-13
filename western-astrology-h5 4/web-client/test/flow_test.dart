import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
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

void main() {
  testWidgets('checkout and app buttons cannot bypass verified payment', (tester) async {
    phone(tester);
    final browser = TestBrowser();
    final paid = fixture(full: true);
    final data = {
      ...fixture(),
      'payment_simulation': false,
      'price': {'amount': 3000, 'currency': 'THB', 'display': '฿30', 'mode': 'sunlands_order_only'},
      'chapters': paid['chapters'],
      'plan': paid['plan'],
    };
    final calls = <String>[];
    final repo = ReportRepository(browser, baseUrl: 'https://example.test',
      client: MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (request.url.path.endsWith('/payment')) return http.Response('', 204);
        return response(data);
      }),
    );
    final h5 = H5Controller(translations(), repo, browser, language: 'zh');
    await tester.pumpWidget(H5App(controller: h5,
      initialLocation: '/report.html?id=${data['id']}&lang=zh&checkout=1'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('free-report-content')), findsOneWidget);
    final paidText = text(object(objects(paid['chapters']).first['summary'])['text']);
    expect(find.text(paidText), findsNothing);
    final appButton = find.byKey(const ValueKey('jy-app-download'));
    expect(tester.widget<JYButton>(appButton).onPressed, isNotNull);
    await click(tester, appButton);
    expect(find.text(h5.copy.t('jy', 'checkout.downloadUnavailable')), findsOneWidget);
    await click(tester, find.byKey(const ValueKey('jy-payment-preview')));
    expect(find.byKey(const ValueKey('order-mobile')), findsOneWidget);
    await click(tester, find.widgetWithText(TextButton, h5.copy.t('checkout', 'cancelOrderEntry')));
    expect(find.byType(ReportPaymentDialog), findsNothing);
    expect(find.byType(ReportCheckout), findsOneWidget);
    expect(calls.where((call) => call.endsWith('/unlock') ||
        call == 'POST /api/life-reports/${data['id']}/payment' ||
        call.endsWith('/payment/simulate')), isEmpty);
    expect(browser.openedPages, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    h5.dispose();
  });

  testWidgets('Sunlands opens and cancels phone entry without creating an order', (tester) async {
    phone(tester);
    final browser = TestBrowser();
    final report = LifeReport.parse({
      ...fixture(),
      'payment_simulation': false,
      'price': {'amount': 3000, 'currency': 'THB', 'display': '฿30', 'mode': 'sunlands_order_only'},
    });
    final requests = <http.Request>[];
    final repo = ReportRepository(browser, baseUrl: 'https://example.test', client: MockClient((request) async {
      requests.add(request);
      return http.Response('', 204);
    }));
    final h5 = H5Controller(translations(), repo, browser, language: 'zh');
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      body: TextButton(onPressed: () => showDialog<void>(context: context,
        builder: (_) => ReportPaymentDialog(h5: h5, report: report)), child: const Text('Open checkout')),
    ))));
    for (var attempt = 0; attempt < 2; attempt++) {
      await click(tester, find.text('Open checkout'));
      await tester.enterText(find.byKey(const ValueKey('order-mobile')), '812345678');
      await click(tester, find.text(h5.copy.t('checkout', 'cancelOrderEntry')));
      expect(find.byType(ReportPaymentDialog), findsNothing);
      expect(requests.length, attempt + 1);
      expect(requests.every((r) => r.method == 'GET' && r.url.path.endsWith('/payment')), isTrue);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    h5.dispose();
  });

  testWidgets('Sunlands creates an order without submitting payment or unlocking', (tester) async {
    phone(tester);
    final browser = TestBrowser();
    final paths = <String>[];
    final bodies = <Json>[];
    final report = LifeReport.parse({
      ...fixture(),
      'payment_simulation': false,
      'price': {'amount': 3000, 'currency': 'THB', 'display': '฿30', 'mode': 'sunlands_order_only'},
    });
    final repo = ReportRepository(browser, baseUrl: 'https://example.test', client: MockClient((request) async {
      if (request.method == 'GET') return http.Response('', 204);
      paths.add(request.url.path);
      bodies.add(object(jsonDecode(request.body)));
      return response({'reference': '000000000001', 'amount': 3000, 'currency': 'THB',
        'order_only': true, 'state': 'CREATED', 'order_number': '202611120001'});
    }));
    final h5 = H5Controller(translations(), repo, browser, language: 'zh');
    await tester.pumpWidget(MaterialApp(home: ReportPaymentDialog(h5: h5, report: report)));
    await tester.pumpAndSettle();
    expect(find.text('฿30'), findsOneWidget);
    expect(paths, isEmpty);
    await click(tester, find.byType(FilledButton));
    expect(paths, isEmpty);
    expect(find.text(h5.copy.t('checkout', 'life_order_phone_invalid')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('order-nation-code')), '+86');
    await tester.enterText(find.byKey(const ValueKey('order-mobile')), '130 0000 0000');
    await click(tester, find.byType(FilledButton));
    expect(bodies, [{'mobile': '13000000000', 'nationCode': '86'}]);
    expect(find.textContaining('202611120001'), findsOneWidget);
    expect(find.text(h5.copy.t('checkout', 'orderCreated')), findsOneWidget);
    expect(find.text('待支付 · 报告未解锁'), findsOneWidget);
    expect(find.byKey(const ValueKey('test-card-number')), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(paths, ['/api/life-reports/${report.id}/payment']);
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
        if (request.method == 'GET') return http.Response('', 204);
        paths.add(request.url.path);
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
      expect(paths, isEmpty);
      await tester.enterText(find.byKey(const ValueKey('order-mobile')), '812345678');
      await click(tester, find.byType(FilledButton));
      expect(find.text(h5.copy.t('checkout', failure.$2)), findsOneWidget);
      expect(find.text(h5.copy.t('checkout', 'orderCreated')), findsNothing);
      expect(find.byKey(const ValueKey('test-card-number')), findsNothing);
      expect(paths, ['/api/life-reports/${report.id}/payment']);
      if (failure.$1 == 'life_order_access_denied') {
        await click(tester, find.widgetWithText(FilledButton, h5.copy.t('checkout', 'createOrderOnly')));
        expect(find.text(h5.copy.t('checkout', 'pendingOrder')), findsOneWidget);
        expect(paths, List.filled(2, '/api/life-reports/${report.id}/payment'));
      }
      expect(find.byType(FilledButton), findsNothing);
      expect(report.full, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    });
  }
  testWidgets('Sunlands reopens and closes the saved cashier without creating or paying', (tester) async {
    phone(tester);
    final browser = TestBrowser();
    final requests = <http.Request>[];
    const url = 'http://trade.sunlands.com/trade/web/trade/payDirect.action?orderNumber=OFFLINE_ORDER_003&termType=mobile&tradeType=WX_MWEB';
    final report = LifeReport.parse({
      ...fixture(), 'payment_simulation': false,
      'price': {'amount': 3000, 'currency': 'THB', 'display': '฿30', 'mode': 'sunlands_order_only'},
    });
    final repo = ReportRepository(browser, baseUrl: 'https://example.test', client: MockClient((request) async {
      requests.add(request);
      return response({'reference': '000000000003', 'amount': 3000, 'currency': 'THB',
        'order_only': true, 'state': 'CREATED', 'order_number': 'OFFLINE_ORDER_003', 'checkout_url': url});
    }));
    final h5 = H5Controller(translations(), repo, browser, language: 'zh');
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      body: TextButton(onPressed: () => showDialog<void>(context: context,
        builder: (_) => ReportPaymentDialog(h5: h5, report: report)), child: const Text('Open checkout')),
    ))));
    for (var attempt = 0; attempt < 2; attempt++) {
      await click(tester, find.text('Open checkout'));
      expect(find.textContaining('OFFLINE_ORDER_003'), findsOneWidget);
      expect(find.byKey(const ValueKey('order-mobile')), findsNothing);
      expect(find.byKey(const ValueKey('test-card-number')), findsNothing);
      await click(tester, find.widgetWithText(FilledButton, h5.copy.t('checkout', 'openCashier')));
      expect(browser.openedPages, List.filled(attempt + 1, url));
      expect(find.text(h5.copy.t('checkout', 'pendingOrder')), findsOneWidget);
      await click(tester, find.text(h5.copy.t('checkout', 'close')));
    }
    expect(requests.length, 2);
    expect(requests.every((r) => r.method == 'GET' && r.url.path.endsWith('/payment')), isTrue);
    expect(report.full, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    h5.dispose();
  });

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
    await tester.pumpWidget(MaterialApp(home: ReportPaymentDialog(h5: h5, report: report)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('order-mobile')), findsNothing);
    expect(find.text(h5.copy.t('checkout', 'createOrderOnly')), findsNothing);
    await click(tester, find.widgetWithText(FilledButton, h5.copy.t('checkout', 'retry')));
    expect(requests.length, 2);
    expect(requests.every((r) => r.method == 'GET'), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    h5.dispose();
  });

  testWidgets('Sunlands reopens a saved access denial and permits explicit phone retry', (tester) async {
    phone(tester);
    final browser = TestBrowser();
    final requests = <http.Request>[];
    final report = LifeReport.parse({
      ...fixture(), 'payment_simulation': false,
      'price': {'amount': 3000, 'currency': 'THB', 'display': '฿30', 'mode': 'sunlands_order_only'},
    });
    final repo = ReportRepository(browser, baseUrl: 'https://example.test', client: MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        return http.Response('{"code":"life_order_access_denied"}', 503,
          headers: {'content-type': 'application/json'});
      }
      return response({'reference': '000000000001', 'amount': 3000, 'currency': 'THB',
        'order_only': true, 'state': 'CREATED', 'order_number': 'OFFLINE_ORDER_RETRY'});
    }));
    final h5 = H5Controller(translations(), repo, browser, language: 'zh');
    await tester.pumpWidget(MaterialApp(home: ReportPaymentDialog(h5: h5, report: report)));
    await tester.pumpAndSettle();
    expect(requests.map((r) => r.method), ['GET']);
    expect(find.byKey(const ValueKey('order-mobile')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('order-mobile')), '812345678');
    await click(tester, find.widgetWithText(FilledButton, h5.copy.t('checkout', 'createOrderOnly')));
    expect(requests.map((r) => r.method), ['GET', 'POST']);
    expect(jsonDecode(requests.last.body), {'mobile': '812345678', 'nationCode': '66'});
    expect(find.textContaining('OFFLINE_ORDER_RETRY'), findsOneWidget);
    expect(browser.openedPages, isEmpty);
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
          builder: (_) => ReportPaymentDialog(h5: h5, report: report));
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
      final wheelState = tester.state(wheel);
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
      expect(tester.state(wheel), same(wheelState));
      expect(tester.widget<GenerationVideo>(wheel).finishing, isFalse);
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
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(tester.widget<GenerationVideo>(wheel).finishing, isTrue);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(completed, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
      h5.dispose();
    },
  );

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
      expect(find.textContaining('从出生时刻，读懂你的运程'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );
  testWidgets(
    'JY inline form, unknown time and consent lead to the locked checkout without a paid request',
    (tester) async {
      phone(tester);
      final browser = TestBrowser();
      Json? input;
      var current = fixture();
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
            return response({
              'accepted': true,
              'notice_version': H5Controller.noticeVersion,
            });
          }
          if (request.method == 'POST') {
            input = object(jsonDecode(request.body));
            final chart = object(fixture()['chart']);
            current = {
              ...fixture(),
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
      final h5 = H5Controller(translations(), repo, browser, language: 'zh')
        ..enterLanding();
      await tester.pumpWidget(
        H5App(controller: h5, initialLocation: '/?lang=zh'),
      );
      await tester.pumpAndSettle();
      await click(tester, find.byKey(const ValueKey('birth-date')));
      await click(
        tester,
        find.widgetWithText(FilledButton, h5.copy.t('ui', 'confirm')),
      );
      await click(tester, find.byKey(const ValueKey('birth-time-unknown')));
      await click(tester, find.byKey(const ValueKey('birth-country')));
      await click(tester, find.text('泰国'));
      await click(tester, find.byKey(const ValueKey('birth-province')));
      await click(
        tester,
        find.descendant(
          of: find.byType(PlacePicker),
          matching: find.text('曼谷'),
        ),
      );
      await click(tester, find.byKey(const ValueKey('birth-city')));
      await click(
        tester,
        find.descendant(
          of: find.byType(PlacePicker),
          matching: find.text('曼谷'),
        ),
      );
      await click(tester, find.byKey(const ValueKey('generate-report')));
      expect(input, isNull);
      expect(find.text('确认使用出生资料'), findsOneWidget);
      await click(tester, find.text('取消'));
      expect(input, isNull);
      expect(find.text('确认使用出生资料'), findsNothing);
      await click(tester, find.byKey(const ValueKey('generate-report')));
      expect(find.text('确认使用出生资料'), findsOneWidget);
      expect(input, isNull);
      await click(tester, find.byKey(const ValueKey('data-use-agree')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(input, isNotNull);
      expect(object(input!['profile'])['birth_time'], isNull);
      expect(object(input!['profile'])['birth_date'], '1999-01-01');
      expect(object(input!['profile'])['location_id'], province['id']);
      expect(input!['report_kind'], 'fortune');
      expect(calls, contains('POST /api/life-reports'));
      expect(calls.any((value) => value.endsWith('/unlock')), isFalse);
      expect(find.byType(GenerationDialog), findsNothing);
      expect(find.byType(ReportCheckout), findsOneWidget);
      expect(find.text('解锁您的运程'), findsOneWidget);
      expect(find.text('฿39'), findsOneWidget);
      expect(find.textContaining('先看清自己的判断习惯'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );
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
      await tester.pumpAndSettle();
      final labels = h5.copy.forReport(LifeReport.parse(data));
      expect(find.text(text(data['title'])), findsOneWidget);
      expect(find.text(labels.t('report', 'birth')), findsOneWidget);
      expect(find.text(labels.t('report', 'takeaway')), findsOneWidget);
      expect(find.text(labels.t('report', 'traits')), findsOneWidget);
      expect(find.byType(ReportCheckout), findsNothing);
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
    'latest language request wins after an earlier slow font download',
    () async {
      final gate = Completer<void>();
      final browser = TestBrowser();
      final repo = ReportRepository(browser);
      final h5 = H5Controller(
        translations(),
        repo,
        browser,
        ensureFont: (lang) => lang == 'zh' ? gate.future : Future.value(),
      );
      final chinese = h5.changeLanguage('zh');
      await h5.changeLanguage('th');
      gate.complete();
      expect(await chinese, isFalse);
      expect(h5.language, 'th');
      h5.dispose();
    },
  );
}
