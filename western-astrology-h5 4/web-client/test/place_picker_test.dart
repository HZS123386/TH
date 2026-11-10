import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fate_h5/app/controller.dart';
import 'package:fate_h5/core/models.dart';
import 'package:fate_h5/core/repository.dart';
import 'package:fate_h5/features/place_picker.dart';
import 'package:fate_h5/ui/theme.dart';
import 'support.dart';

void main() {
  testWidgets('Thai locality picker remains usable above the phone keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final browser = TestBrowser();
    final province = Place({
      'id': 'geonames:1609350',
      'countryCode': 'TH',
      'nameThai': 'กรุงเทพมหานคร',
      'nameEnglish': 'Bangkok',
      'timeZone': 'Asia/Bangkok',
      'placeType': 'province',
    });
    final repo = ReportRepository(
      browser,
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'items': [], 'total': 0}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    final h5 = H5Controller(translations(), repo, browser);
    await tester.pumpWidget(
      MaterialApp(
        theme: h5Theme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  choosePlace(context, h5, 'TH', province: province),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextField, 'เช่น เมืองเชียงใหม่'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    h5.dispose();
  });
}
