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
    'Thai province selection supports mouse, search, clearing and outside dismissal',
    (tester) async {
      tester.view.physicalSize = const Size(720, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const places = [
        {
          'id': 'geonames:1153671',
          'countryCode': 'TH',
          'nameChinese': '清迈府',
          'nameThai': 'เชียงใหม่',
          'nameEnglish': 'Chiang Mai',
          'timeZone': 'Asia/Bangkok',
          'placeType': 'province',
        },
        {
          'id': 'geonames:1609350',
          'countryCode': 'TH',
          'nameChinese': '曼谷',
          'nameThai': 'กรุงเทพมหานคร',
          'nameEnglish': 'Bangkok',
          'timeZone': 'Asia/Bangkok',
          'placeType': 'province',
        },
      ];
      final browser = TestBrowser();
      final repo = ReportRepository(
        browser,
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          expect(request.url.queryParameters, {
            'country': 'TH',
            'level': 'province',
          });
          return http.Response(
            jsonEncode({'items': places, 'total': places.length}),
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
      final followingPosition = tester.getTopLeft(find.text('outside'));
      void checkFloatingMenu(String id) {
        expect(tester.getTopLeft(find.text('outside')), followingPosition);
        final input = tester.getRect(find.byKey(ValueKey(id)));
        final menu = tester.getRect(find.byKey(ValueKey('$id-options')));
        expect(menu.top, closeTo(input.bottom + 5, .1));
        expect(menu.width, closeTo(input.width, .1));
      }

      expect(find.byKey(const ValueKey('birth-country')), findsNothing);
      expect(find.byKey(const ValueKey('birth-city')), findsNothing);
      expect(chosen, isNull);
      await mouse(arrow('birth-province'));
      checkFloatingMenu('birth-province');
      await mouse(find.text('清迈府'));
      expect(value('birth-province'), '清迈府');
      expect(chosen?.id, places.first['id']);
      expect(chosen?.country, 'TH');
      expect(chosen?.zone, 'Asia/Bangkok');

      await tester.enterText(
        find.byKey(const ValueKey('birth-province')),
        'กรุงเทพ',
      );
      await tester.pumpAndSettle();
      expect(chosen, isNull);
      expect(find.text('清迈府'), findsNothing);
      await mouse(find.text('曼谷'));
      expect(value('birth-province'), '曼谷');
      expect(chosen?.id, places.last['id']);
      await mouse(arrow('birth-province'));
      expect(
        find.byKey(const ValueKey('birth-province-options')),
        findsOneWidget,
      );
      await mouse(find.text('outside'));
      expect(
        find.byKey(const ValueKey('birth-province-options')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      h5.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
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
          (request) async => http.Response(
            jsonEncode({
              'items': request.url.queryParameters['level'] == 'province'
                  ? [province.json]
                  : [],
              'total': request.url.queryParameters['level'] == 'province'
                  ? 1
                  : 0,
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
                    const SizedBox(height: 180),
                    BirthplaceFields(
                      h5: h5,
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
      await tester.tap(arrow('birth-province'));
      await tester.pumpAndSettle();
      Rect menu(String id) =>
          tester.getRect(find.byKey(ValueKey('$id-options')));
      Rect input(String id) => tester.getRect(find.byKey(ValueKey(id)));
      expect(
        menu('birth-province').bottom,
        closeTo(input('birth-province').top - 5, .1),
      );
      scroll.jumpTo(24);
      await tester.pumpAndSettle();
      expect(
        menu('birth-province').bottom,
        closeTo(input('birth-province').top - 5, .1),
      );
      await tester.tap(find.text('กรุงเทพมหานคร'));
      await tester.pumpAndSettle();
      expect(chosen?.id, province.id);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      scroll.dispose();
      h5.dispose();
    },
  );
}
