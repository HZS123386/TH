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
  testWidgets('the city field browses and searches only the selected country', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const places = [
      {
        'id': 'geonames:1816670',
        'countryCode': 'CN',
        'nameChinese': '北京市',
        'nameEnglish': 'Beijing',
        'timeZone': 'Asia/Shanghai',
        'placeType': 'city',
      },
      {
        'id': 'geonames:1808963',
        'countryCode': 'CN',
        'nameChinese': '邯郸市',
        'nameEnglish': 'Handan',
        'provinceNameChinese': '河北省',
        'timeZone': 'Asia/Shanghai',
        'placeType': 'city',
      },
      {
        'id': 'geonames:1609350',
        'countryCode': 'TH',
        'nameChinese': '曼谷',
        'nameThai': 'กรุงเทพมหานคร',
        'nameEnglish': 'Bangkok',
        'timeZone': 'Asia/Bangkok',
        'placeType': 'city',
      },
    ];
    final browser = TestBrowser();
    final repo = ReportRepository(
      browser,
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        final params = request.url.queryParameters;
        expect(params['country'], 'CN');
        expect(params['level'], 'locality');
        expect(params.containsKey('province'), isFalse);
        final items = switch (params['query']) {
          '邯郸' => [places[1]],
          '' => [places[0], places[2]],
          _ => [],
        };
        return http.Response(
          jsonEncode({'items': items, 'total': items.length}),
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
                    country: 'CN',
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
    final followingPosition = tester.getTopLeft(find.text('outside'));
    void checkFloatingMenu(String id) {
      expect(tester.getTopLeft(find.text('outside')), followingPosition);
      final input = tester.getRect(find.byKey(ValueKey(id)));
      final menu = tester.getRect(find.byKey(ValueKey('$id-options')));
      expect(menu.top, closeTo(input.bottom + 5, .1));
      expect(menu.width, closeTo(input.width, .1));
    }

    expect(find.byKey(const ValueKey('birth-country')), findsNothing);
    expect(find.byKey(const ValueKey('birth-province')), findsNothing);
    expect(chosen, isNull);
    await mouse(arrow('birth-city'));
    checkFloatingMenu('birth-city');
    expect(find.text('曼谷'), findsNothing);
    await mouse(find.text('北京市'));
    expect(value('birth-city'), '北京市');
    expect(chosen?.id, places.first['id']);
    expect(chosen?.country, 'CN');
    expect(chosen?.zone, 'Asia/Shanghai');

    await tester.enterText(find.byKey(const ValueKey('birth-city')), '邯郸');
    await tester.pumpAndSettle();
    expect(chosen, isNull);
    expect(find.text('北京市'), findsNothing);
    expect(find.text('河北省 · Handan'), findsOneWidget);
    await mouse(find.text('邯郸市'));
    expect(value('birth-city'), '邯郸市');
    expect(chosen?.id, places[1]['id']);
    await mouse(arrow('birth-city'));
    expect(find.byKey(const ValueKey('birth-city-options')), findsOneWidget);
    await mouse(find.text('outside'));
    expect(find.byKey(const ValueKey('birth-city-options')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    h5.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  testWidgets(
    'floating menus follow scrolling and stay above the phone keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final browser = TestBrowser();
      final scroll = ScrollController();
      final city = Place({
        'id': 'geonames:1609350',
        'countryCode': 'TH',
        'nameThai': 'กรุงเทพมหานคร',
        'nameEnglish': 'Bangkok',
        'timeZone': 'Asia/Bangkok',
        'placeType': 'city',
      });
      final repo = ReportRepository(
        browser,
        baseUrl: 'https://example.test',
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'items': [city.json],
              'total': 1,
            }),
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
              controller: scroll,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 160),
                    BirthplaceFields(
                      h5: h5,
                      country: 'TH',
                      initialPlace: city,
                      onSelected: (value) => chosen = value,
                    ),
                    const SizedBox(height: 400),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Finder arrow(String key) => find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(IconButton),
      );
      await tester.tap(arrow('birth-city'));
      await tester.pumpAndSettle();
      Rect menu(String id) =>
          tester.getRect(find.byKey(ValueKey('$id-options')));
      Rect input(String id) => tester.getRect(find.byKey(ValueKey(id)));
      expect(
        menu('birth-city').bottom,
        closeTo(input('birth-city').top - 5, .1),
      );
      scroll.jumpTo(24);
      await tester.pumpAndSettle();
      expect(
        menu('birth-city').bottom,
        closeTo(input('birth-city').top - 5, .1),
      );
      await tester.tap(find.widgetWithText(InkWell, 'กรุงเทพมหานคร'));
      await tester.pumpAndSettle();
      expect(chosen?.id, city.id);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      scroll.dispose();
      h5.dispose();
    },
  );
}
