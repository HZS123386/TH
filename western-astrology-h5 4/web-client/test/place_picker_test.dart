import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
  testWidgets(
    'desktop arrows and mouse options select countries, provinces and cities without typing',
    (tester) async {
      tester.view.physicalSize = const Size(720, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const places = {
        'CN': {
          'id': 'geonames:1808773',
          'countryCode': 'CN',
          'nameChinese': '河北省',
          'nameEnglish': 'Hebei',
          'timeZone': 'Asia/Shanghai',
          'placeType': 'province',
        },
        'TH': {
          'id': 'geonames:1153671',
          'countryCode': 'TH',
          'nameChinese': '清迈府',
          'nameEnglish': 'Chiang Mai',
          'timeZone': 'Asia/Bangkok',
          'placeType': 'province',
        },
      };
      const cities = {
        'CN': {
          'id': 'geonames:1808963',
          'countryCode': 'CN',
          'provinceId': 'geonames:1808773',
          'nameChinese': '邯郸市',
          'nameEnglish': 'Handan',
          'timeZone': 'Asia/Shanghai',
          'placeType': 'city',
        },
        'TH': {
          'id': 'geonames:1153671',
          'countryCode': 'TH',
          'provinceId': 'geonames:1153671',
          'nameChinese': '清迈',
          'nameEnglish': 'Chiang Mai',
          'timeZone': 'Asia/Bangkok',
          'placeType': 'city',
        },
      };
      final browser = TestBrowser();
      final repo = ReportRepository(
        browser,
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          final query = request.url.queryParameters,
              country = query['country']!;
          final province = query['level'] == 'province';
          if (!province) expect(query['province'], places[country]!['id']);
          return http.Response(
            jsonEncode({
              'items': [province ? places[country] : cities[country]],
              'total': 1,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final h5 = H5Controller(translations(), repo, browser, language: 'zh');
      Place? chosen;
      await tester.pumpWidget(
        MaterialApp(
          theme: h5Theme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    BirthplaceFields(
                      h5: h5,
                      onSelected: (value) => chosen = value,
                    ),
                    const Text('below fields'),
                    const SizedBox(height: 220),
                    const Text('outside'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> mouse(Finder finder) async {
        await tester.ensureVisible(finder);
        final pointer = await tester.startGesture(
          tester.getCenter(finder),
          kind: PointerDeviceKind.mouse,
        );
        // Keep pointer down across a frame: a blur must not remove the option before mouse up.
        await tester.pump();
        await pointer.up();
        await tester.pumpAndSettle();
      }

      Finder arrow(String key) => find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(IconButton),
      );
      String value(String key) => tester
          .widget<TextFormField>(find.byKey(ValueKey(key)))
          .controller!
          .text;
      final below = find.text('below fields');
      final originalPosition = tester.getTopLeft(below);
      for (final country in ['CN', 'TH']) {
        await mouse(arrow('birth-country'));
        expect(tester.getTopLeft(below), originalPosition);
        expect(find.widgetWithText(InkWell, '中国'), findsOneWidget);
        expect(find.widgetWithText(InkWell, '泰国'), findsOneWidget);
        await mouse(
          find.widgetWithText(InkWell, country == 'CN' ? '中国' : '泰国'),
        );
        expect(value('birth-country'), country == 'CN' ? '中国' : '泰国');
        expect(value('birth-province'), isEmpty);
        expect(value('birth-city'), isEmpty);
        expect(chosen, isNull);
        await mouse(arrow('birth-province'));
        expect(tester.getTopLeft(below), originalPosition);
        final province = find.descendant(
          of: find.byType(PlacePicker),
          matching: find.text(places[country]!['nameChinese']!),
        );
        expect(province, findsOneWidget);
        await mouse(province);
        expect(value('birth-province'), places[country]!['nameChinese']);
        await mouse(arrow('birth-city'));
        expect(tester.getTopLeft(below), originalPosition);
        final city = find.descendant(
          of: find.byType(PlacePicker),
          matching: find.text(cities[country]!['nameChinese']!),
        );
        expect(city, findsOneWidget);
        await mouse(city);
        expect(value('birth-city'), cities[country]!['nameChinese']);
        expect(chosen?.id, cities[country]!['id']);
      }
      // Editing remains available, and a mouse click can select the filtered result.
      await mouse(find.byKey(const ValueKey('birth-country')));
      await tester.enterText(find.byKey(const ValueKey('birth-country')), '中国');
      await tester.pumpAndSettle();
      await mouse(find.widgetWithText(InkWell, '中国'));
      expect(value('birth-country'), '中国');
      expect(chosen, isNull);
      await mouse(arrow('birth-country'));
      expect(find.widgetWithText(InkWell, '泰国'), findsOneWidget);
      await mouse(find.text('outside'));
      expect(find.widgetWithText(InkWell, '泰国'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  testWidgets(
    'country suggestions open above the field when the keyboard leaves no room below',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final browser = TestBrowser();
      final h5 = H5Controller(
        translations(),
        ReportRepository(browser),
        browser,
        language: 'zh',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: h5Theme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 246),
                  BirthplaceFields(h5: h5, onSelected: (_) {}),
                ],
              ),
            ),
          ),
        ),
      );
      final country = find.byKey(const ValueKey('birth-country'));
      await tester.tap(
        find.descendant(of: country, matching: find.byType(IconButton)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(find.text('泰国')).dy,
        lessThan(tester.getTopLeft(country).dy),
      );
      await tester.tap(find.text('泰国'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(country).controller!.text, '泰国');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
  );

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
    Place? chosen;
    await tester.pumpWidget(
      MaterialApp(
        theme: h5Theme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: PlacePicker(
              h5: h5,
              country: 'TH',
              province: province,
              onSelected: (value) => chosen = value,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('กรุงเทพมหานคร'), findsOneWidget);
    expect(find.text(h5.copy.t('ui', 'noCity')), findsNothing);
    await tester.tap(find.text('กรุงเทพมหานคร'));
    expect(chosen?.id, province.id);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    h5.dispose();
  });
}
