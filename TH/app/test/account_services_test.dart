import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fate_app/app/dependencies.dart';
import 'package:fate_app/core/models/birth_profile.dart';
import 'package:fate_app/core/network/api_client.dart';
import 'package:fate_app/core/storage/session_store.dart';
import 'package:fate_app/data/configuration_repository.dart';
import 'package:fate_app/features/companion/guardian.dart';
import 'package:fate_app/features/reports/content_report_sheet.dart';
import 'package:fate_app/l10n/generated/app_localizations.dart';
import 'package:fate_app/l10n/generated/app_localizations_en.dart';
import 'package:fate_app/ui/theme.dart';

class _Store implements SessionStore {
  @override
  Future<Map<String, dynamic>?> read() async => null;
  @override
  Future<void> clear() async {}
  @override
  Future<void> write(Map<String, dynamic> value) async {}
}

Future<AppDependencies> setup(
  http.Response Function(http.Request) handle,
) async {
  final d = AppDependencies(
    await SharedPreferences.getInstance(),
    secureStore: _Store(),
    client: ApiClient(
      'https://fixture.test',
      client: MockClient((request) async {
        return switch (request.url.path) {
          '/api/auth/guest' => http.Response('{"token":"fixture"}', 201),
          '/api/auth/me' => http.Response(
            '{"user_id":"owner-a","kind":"guest"}',
            200,
          ),
          '/api/profile' => http.Response('null', 200),
          '/api/history' || '/api/memories' => http.Response('[]', 200),
          _ => handle(request),
        };
      }),
    ),
  );
  await d.auth.ensureGuest();
  await Future<void>.delayed(Duration.zero);
  return d;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'AI permission blocks sending, is revocable and binds to recipient and owner',
    () async {
      var chats = 0;
      final d = await setup((request) {
        chats++;
        return http.Response(
          'event: token\ndata: {"text":"A reply"}\n\n'
          'event: done\ndata: {"message_id":"reply-1"}\n\n',
          200,
        );
      });
      addTearDown(d.dispose);
      d.session.capabilities = const AppCapabilities(
        companionProvider: 'companion',
        companionRecipients: ['qwen'],
      );
      d.session.profile = const BirthProfile(
        date: '1995-02-03',
        timezone: 'Asia/Bangkok',
        place: 'Bangkok',
      );
      d.session.notifyListeners();
      await Future<void>.delayed(Duration.zero);
      expect(await d.companion.send(Guardian.love, 'Hello'), isFalse);
      expect(chats, 0);
      await d.session.allowCompanion(d.session.owner, 'companion');
      expect(await d.companion.send(Guardian.love, 'Hello'), isTrue);
      expect(chats, 1);
      d.session.capabilities = const AppCapabilities(
        companionProvider: 'companion',
        companionRecipients: ['qwen', 'kimi'],
      );
      expect(d.session.companionConsent, isFalse);
      expect(await d.companion.send(Guardian.love, 'Another'), isFalse);
      await d.session.allowCompanion(d.session.owner, 'companion');
      await d.session.revokeCompanion();
      expect(await d.companion.send(Guardian.love, 'Another'), isFalse);
      expect(chats, 1);
      await d.auth.clear();
      expect(d.session.companionConsent, isFalse);
    },
  );

  test(
    'deletion is closed by default; failures preserve data; confirmed deletion clears only its owner',
    () async {
      var status = 'pending', calls = 0;
      final d = await setup((request) {
        calls++;
        return http.Response(
          jsonEncode({'status': status, 'user_id': 'owner-a'}),
          200,
        );
      });
      addTearDown(d.dispose);
      final draft = {'date': '1995-02-03'};
      await d.session.drafts.write('owner-a', 'birth', draft);
      await d.session.drafts.write('owner-b', 'birth', draft);
      await expectLater(
        d.accountServices.deleteAccount(
          expectedOwner: 'owner-a',
          requestKey: 'delete-key',
        ),
        throwsA(isA<ApiFailure>()),
      );
      expect(calls, 0);
      d.session.capabilities = const AppCapabilities(accountDeletion: true);
      await expectLater(
        d.accountServices.deleteAccount(
          expectedOwner: 'owner-a',
          requestKey: 'delete-key',
        ),
        throwsA(isA<ApiFailure>()),
      );
      expect(d.auth.hasSession, isTrue);
      expect(d.session.drafts.read('owner-a', 'birth'), isNotNull);
      status = 'deleted';
      await d.accountServices.deleteAccount(
        expectedOwner: 'owner-a',
        requestKey: 'delete-key',
      );
      expect(d.auth.hasSession, isFalse);
      expect(d.session.drafts.read('owner-a', 'birth'), isNull);
      expect(d.session.drafts.read('owner-b', 'birth'), isNotNull);
    },
  );

  test(
    'reporting requires a receipt and sends no transcript or profile',
    () async {
      var valid = false, calls = 0;
      final d = await setup((request) {
        calls++;
        final body = jsonDecode(request.body) as Map;
        expect(body.keys.toSet(), {
          'content_type',
          'content_id',
          'reason',
          'details',
          'locale',
        });
        expect(request.headers['Idempotency-Key'], 'same-report-key');
        return http.Response(
          valid ? '{"status":"received","report_id":"case-4"}' : '{}',
          200,
        );
      });
      addTearDown(d.dispose);
      Future<String> send() => d.accountServices.reportContent(
        kind: 'chat',
        id: 'reply-1',
        reason: 'harmful',
        detail: 'My explanation',
        requestKey: 'same-report-key',
      );
      await expectLater(send(), throwsA(isA<ApiFailure>()));
      expect(calls, 0);
      d.session.capabilities = const AppCapabilities(contentReporting: true);
      await expectLater(send(), throwsA(isA<ApiFailure>()));
      valid = true;
      expect(await send(), 'case-4');
    },
  );

  testWidgets(
    'report form keeps draft after failure and needs a receipt to show success',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var valid = false;
      final submittedKeys = <String?>[];
      final d = (await tester.runAsync(
        () => setup((request) {
          submittedKeys.add(request.headers['Idempotency-Key']);
          return http.Response(
            valid ? '{"status":"received","report_id":"case-5"}' : '{}',
            200,
          );
        }),
      ))!;
      d.session.capabilities = const AppCapabilities(contentReporting: true);
      final s = AppLocalizationsEn();
      await tester.pumpWidget(
        DependencyScope(
          dependencies: d,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: fateTheme(),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      showContentReport(context, kind: 'chat', id: 'r1'),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.reasonHarmful));
      await tester.enterText(
        find.byType(TextField),
        'Please review this response',
      );
      await tester.ensureVisible(find.text(s.reportSend));
      await tester.tap(find.text(s.reportSend));
      await tester.pumpAndSettle();
      expect(find.text(s.error), findsOneWidget);
      expect(find.text('Please review this response'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'Please review this corrected explanation',
      );
      valid = true;
      await tester.ensureVisible(find.text(s.reportSend));
      await tester.tap(find.text(s.reportSend));
      await tester.pumpAndSettle();
      expect(find.text(s.reportReceived('case-5')), findsOneWidget);
      expect(submittedKeys[1], isNot(submittedKeys[0]));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      d.dispose();
    },
  );
}
