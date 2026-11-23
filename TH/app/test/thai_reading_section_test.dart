import 'dart:convert';

import 'package:fate_app/app/dependencies.dart';
import 'package:fate_app/core/network/api_client.dart';
import 'package:fate_app/features/chart/thai_reading_section.dart';
import 'package:fate_app/l10n/generated/app_localizations.dart';
import 'package:fate_app/l10n/generated/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'Thai reports keep retry available after incomplete or busy responses',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final s = AppLocalizationsEn();
      const profile = {'birth_time': '09:30', 'language': 'en'};
      final requests = <http.Request>[];
      final dependencies = AppDependencies(
        await SharedPreferences.getInstance(),
        thaiAstrologyOnly: true,
        client: ApiClient(
          'https://api.example.test',
          client: MockClient((request) async {
            requests.add(request);
            final attempt = requests.length;
            final generation = switch (attempt) {
              2 => {'state': 'unavailable', 'failure_code': 'model_timeout'},
              3 => {'state': 'pending'},
              _ => {'state': 'ready'},
            };
            return http.Response(
              jsonEncode(
                attempt == 4
                    ? {'code': 'too_many_requests'}
                    : {
                        'input': jsonDecode(request.body),
                        'report': {
                          'language': 'en',
                          'generation': generation,
                          'summary': 'A complete result stays visible.',
                          'sections': [
                            for (final section in [
                              'interpretation',
                              'opportunities',
                              if (attempt != 1) 'advice',
                            ])
                              {
                                'id': section,
                                'title': 'Heading for $section',
                                'items': [
                                  {
                                    'title': 'A useful point',
                                    'text': 'Keep the next action manageable.',
                                  },
                                ],
                              },
                          ],
                        },
                      },
              ),
              attempt == 4 ? 429 : 200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );
      addTearDown(dependencies.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: DependencyScope(
            dependencies: dependencies,
            child: const Scaffold(
              body: SingleChildScrollView(
                child: ThaiReadingSection(profile: profile),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final generate = find.widgetWithText(FilledButton, s.consentGenerate);
      for (final message in [
        s.reportFailedText,
        s.reportServiceTimeout,
        s.thaiReadingPending,
        s.reportServiceBusy,
      ]) {
        await tester.ensureVisible(generate);
        await tester.tap(generate);
        await tester.pumpAndSettle();
        expect(find.text(message), findsOneWidget);
        expect(find.text('A complete result stays visible.'), findsNothing);
        expect(generate, findsOneWidget);
      }
      await tester.ensureVisible(generate);
      await tester.tap(generate);
      await tester.pumpAndSettle();
      expect(find.text('A complete result stays visible.'), findsOneWidget);
      expect(find.text('Heading for advice'), findsOneWidget);
      expect(requests, hasLength(5));
      expect(
        requests.every((request) => request.headers['Authorization'] == null),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
