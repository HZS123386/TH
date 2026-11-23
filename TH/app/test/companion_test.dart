import 'dart:async';
import 'dart:convert';
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

class _SessionStore implements SessionStore {
  @override
  Future<Map<String, dynamic>?> read() async => null;
  @override
  Future<void> write(Map<String, dynamic> value) async {}
  @override
  Future<void> clear() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('a late memory list cannot undo a confirmed edit or deletion', () async {
    SharedPreferences.setMockInitialValues({});
    final stale = Completer<http.Response>(), started = Completer<void>();
    final d = AppDependencies(
      await SharedPreferences.getInstance(),
      secureStore: _SessionStore(),
      client: ApiClient(
        'https://api.example.test',
        client: MockClient((request) async {
          switch (request.url.path) {
            case '/api/auth/guest':
              return http.Response('{"token":"fixture"}', 201);
            case '/api/auth/me':
              return http.Response(
                '{"user_id":"memory-owner","kind":"guest"}',
                200,
              );
            case '/api/profile':
              return http.Response('null', 200);
            case '/api/history':
              return http.Response('[]', 200);
            case '/api/memories':
              if (request.method == 'GET') {
                started.complete();
                return stale.future;
              }
              return http.Response(
                '{"id":"m1","content":"I prefer short replies."}',
                201,
              );
            case '/api/memories/m1':
              return http.Response('', 204);
            default:
              return http.Response('{}', 404);
          }
        }),
      ),
    );
    addTearDown(d.dispose);
    await d.auth.ensureGuest();
    await started.future;
    await d.companion.saveMemory('I prefer short replies.');
    expect(d.companion.memories.single['content'], 'I prefer short replies.');
    stale.complete(http.Response('[]', 200));
    await Future<void>.delayed(Duration.zero);
    expect(d.companion.memories.single['id'], 'm1');
    await d.companion.deleteMemory('m1');
    expect(d.companion.memories, isEmpty);
  });
  test(
    'successful guardian conversations restore; failures and old sessions do not count',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var owner = 'visitor-a', mode = 'success';
      final history = <Map<String, dynamic>>[];
      final delayed = Completer<http.Response>(), started = Completer<void>();
      AppDependencies makeDependencies() => AppDependencies(
        prefs,
        secureStore: _SessionStore(),
        client: ApiClient(
          'https://api.example.test',
          client: MockClient((request) async {
            switch (request.url.path) {
              case '/api/auth/guest':
                return http.Response('{"token":"fixture"}', 201);
              case '/api/auth/me':
                return http.Response(
                  jsonEncode({'user_id': owner, 'kind': 'guest'}),
                  200,
                );
              case '/api/profile':
                return http.Response('null', 200);
              case '/api/history':
                return http.Response(jsonEncode(history), 200);
              case '/api/memories':
                return http.Response('[]', 200);
              case '/api/chat':
                if (mode == 'delayed') {
                  started.complete();
                  return delayed.future;
                }
                if (mode == 'failed') {
                  return http.Response(
                    'event: token\ndata: {"text":"unfinished"}\n\n',
                    200,
                  );
                }
                final body = jsonDecode(request.body) as Map;
                expect(
                  (body['context'] as String).length,
                  lessThanOrEqualTo(1500),
                );
                expect(body['context'], contains('Visible preview'));
                history.addAll([
                  {
                    'id': 'u1',
                    'role': 'user',
                    'content': body['message'],
                    'created': 1,
                  },
                  {
                    'id': 'a1',
                    'role': 'assistant',
                    'content': 'A considered response.',
                    'created': 1,
                  },
                ]);
                return http.Response(
                  'event: token\ndata: {"text":"A considered response."}\n\n'
                  'event: done\ndata: {"message_id":"a1"}\n\n',
                  200,
                );
              default:
                return http.Response('{}', 404);
            }
          }),
        ),
      );
      Future<void> prepare(AppDependencies d) async {
        d.session.capabilities = const AppCapabilities(
          companionProvider: 'companion',
        );
        await d.auth.ensureGuest();
        await Future<void>.delayed(Duration.zero);
        await d.session.allowCompanion(d.session.owner, 'companion');
        d.session.profile = const BirthProfile(
          date: '1995-02-03',
          timezone: 'Asia/Bangkok',
          place: 'Bangkok',
        );
      }

      var d = makeDependencies();
      await prepare(d);
      expect(
        await d.companion.send(
          Guardian.career,
          'What could I reflect on?',
          reading: ReadingHandoff(
            title: 'Report',
            text: 'Visible preview ${'x' * 2000}',
          ),
        ),
        isTrue,
      );
      expect(d.companion.conversations(Guardian.career), 1);
      expect(d.companion.conversations(Guardian.love), 0);
      d.dispose();

      d = makeDependencies();
      await prepare(d);
      expect(
        d.companion.conversation(Guardian.career).map((row) => row['content']),
        ['What could I reflect on?', 'A considered response.'],
      );
      mode = 'failed';
      expect(
        await d.companion.send(Guardian.career, 'Another thought'),
        isFalse,
      );
      expect(d.companion.conversations(Guardian.career), 1);

      mode = 'delayed';
      final reply = d.companion.send(Guardian.career, 'Old owner question');
      await started.future;
      await d.auth.clear();
      owner = 'visitor-b';
      history.clear();
      await d.auth.ensureGuest();
      delayed.complete(
        http.Response(
          'event: token\ndata: {"text":"Old reply"}\n\n'
          'event: done\ndata: {"message_id":"a2"}\n\n',
          200,
        ),
      );
      expect(await reply, isFalse);
      expect(d.companion.history, isEmpty);
      expect(d.companion.conversations(Guardian.career), 0);
      d.dispose();
    },
  );
}
