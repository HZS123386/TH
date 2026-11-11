import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fate_app/core/models/birth_profile.dart';
import 'package:fate_app/core/network/api_client.dart';
import 'package:fate_app/core/storage/session_store.dart';
import 'package:fate_app/data/profile_repository.dart';
import 'package:fate_app/features/account/birthplace_fields.dart';
import 'package:fate_app/l10n/generated/app_localizations.dart';

const bangkok = {
  'id': 'geonames:1609350',
  'countryCode': 'TH',
  'nameEnglish': 'Bangkok',
  'provinceId': 'geonames:1609350',
  'provinceNameEnglish': 'Bangkok',
  'timeZone': 'Asia/Bangkok',
  'latitude': 13.75398,
  'longitude': 100.50144,
};
const bangKhae = {
  'id': 'geonames:7026720',
  'countryCode': 'TH',
  'nameEnglish': 'Bang Khae',
  'provinceId': 'geonames:1609350',
  'provinceNameEnglish': 'Bangkok',
  'timeZone': 'Asia/Bangkok',
  'latitude': 13.69301,
  'longitude': 100.40755,
};
const newYork = {
  'id': 'geonames:5128581',
  'countryCode': 'US',
  'nameEnglish': 'New York City',
  'timeZone': 'America/New_York',
  'latitude': 40.71427,
  'longitude': -74.00597,
};

void main() {
  testWidgets(
    'country, region and city can be searched and invalidate a stale selected location',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final requests = <Map<String, String>>[];
      final api = ApiClient(
        'https://api.example.test',
        client: MockClient((request) async {
          final params = request.url.queryParameters;
          requests.add(params);
          final items = params['level'] == 'province'
              ? [bangkok]
              : params['country'] == 'US'
              ? [newYork]
              : [bangKhae];
          return http.Response(
            jsonEncode({'items': items, 'total': items.length}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final repository = ProfileRepository(
        api,
        LocalDraftStore(await SharedPreferences.getInstance()),
      );
      Map<String, dynamic>? selected;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Form(
              child: BirthplaceFields(
                repository: repository,
                onSelected: (v) => selected = v,
              ),
            ),
          ),
        ),
      );
      final country = find.byKey(const ValueKey('birth-country'));
      final region = find.byKey(const ValueKey('birth-region'));
      final city = find.byKey(const ValueKey('birth-city'));
      await tester.tap(country);
      await tester.enterText(country, 'Thai');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thailand'));
      await tester.pumpAndSettle();
      await tester.tap(region);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bangkok'));
      await tester.pumpAndSettle();
      await tester.tap(city);
      await tester.enterText(city, 'Bang');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bang Khae'));
      await tester.pumpAndSettle();
      expect(selected!['id'], bangKhae['id']);
      expect(selected!['timeZone'], 'Asia/Bangkok');
      expect(
        requests.any(
          (r) => r['level'] == 'locality' && r['province'] == bangkok['id'],
        ),
        isTrue,
      );
      await tester.tap(city);
      await tester.enterText(city, 'Different city');
      await tester.pump(const Duration(milliseconds: 200));
      expect(selected, isNull);
      await tester.tap(country);
      await tester.enterText(country, 'United');
      await tester.pumpAndSettle();
      await tester.tap(find.text('United States'));
      await tester.pumpAndSettle();
      expect((tester.widget<TextFormField>(region)).enabled, isFalse);
      await tester.tap(city);
      await tester.enterText(city, 'New York');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New York City'));
      await tester.pumpAndSettle();
      expect(selected!['timeZone'], 'America/New_York');
      expect(selected!['latitude'], 40.71427);
      expect(find.text('America/New_York'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      api.close();
    },
  );

  test(
    'saving a selected city carries its coordinates, country and automatic timezone to the server',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = ApiClient(
        'https://api.example.test',
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['location_id'], newYork['id']);
          expect(body['timezone'], 'America/New_York');
          expect(body['country_code'], 'US');
          expect(body['latitude'], newYork['latitude']);
          expect(body['longitude'], newYork['longitude']);
          return http.Response(
            jsonEncode({'profile_id': 'p1', 'revision': 1, 'profile': body}),
            200,
          );
        }),
      );
      final repository = ProfileRepository(
        api,
        LocalDraftStore(await SharedPreferences.getInstance()),
      );
      final profile = await repository.save(
        'account1',
        const BirthProfile(
          date: '1999-02-20',
          time: '07:15',
          timezone: 'America/New_York',
          place: 'New York City, US',
          placeId: 'geonames:5128581',
          countryCode: 'US',
          latitude: 40.71427,
          longitude: -74.00597,
        ),
        serverContractReady: true,
      );
      expect(repository.local('account1')!.timezone, 'America/New_York');
      expect(profile.countryCode, 'US');
      expect(profile.latitude, 40.71427);
      api.close();
    },
  );
}
