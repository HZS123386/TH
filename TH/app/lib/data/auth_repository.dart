import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../core/network/api_client.dart';
import '../core/storage/session_store.dart';

class AuthRepository extends ChangeNotifier {
  AuthRepository(this.api, this.store) {
    api.refreshSession = refresh;
    api.onSessionExpired = () => unawaited(clear());
  }

  final ApiClient api;
  final SessionStore store;
  Map<String, dynamic>? _account;
  String? _refreshToken;
  Future<void>? _guestRequest;

  Map<String, dynamic>? get account => _account;
  String get owner => _account?['user_id'] as String? ?? 'guest';
  bool get hasSession => _account != null;
  bool get isGuest => _account?['kind'] == 'guest';
  bool get hasH5Reports => _account?['kind'] == 'h5';
  bool get signedIn => hasSession && !isGuest;
  bool get canUseDevelopmentLogin =>
      kDebugMode ||
      (kIsWeb &&
          const bool.fromEnvironment('FATE_DEVELOPMENT_PREVIEW') &&
          ['localhost', '127.0.0.1'].contains(Uri.base.host));

  Future<void> ensureGuest() {
    if (hasSession) return Future.value();
    return _guestRequest ??= _signIn(
      () => api.request('POST', '/api/auth/guest', authenticated: false),
    ).whenComplete(() => _guestRequest = null);
  }

  Future<void> restore() async {
    final generation = api.sessionVersion;
    final session = await store.read();
    if (session == null || generation != api.sessionVersion) return;
    api.accessToken = _token(session);
    _refreshToken = session['refresh_token'] as String?;
    try {
      final account = await _readAccount();
      if (generation != api.sessionVersion) return;
      _account = account;
      notifyListeners();
    } catch (_) {
      if (generation == api.sessionVersion) {
        api.accessToken = null;
        _refreshToken = null;
      }
      rethrow;
    }
  }

  Future<void> signInDevelopment(
    String username,
    String password, {
    bool register = false,
  }) {
    if (!canUseDevelopmentLogin) {
      throw const ApiFailure('development_login_disabled');
    }
    final upgradeGuest = register && isGuest;
    return _signIn(() => api.request(
      'POST',
      register ? '/api/auth/register' : '/api/auth/login',
      authenticated: upgradeGuest,
      body: {'username': username.trim(), 'password': password},
    ), keepGuest: upgradeGuest);
  }

  Future<void> signInApple() => _signIn(() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      throw const ApiFailure('native_apple_required');
    }
    final random = Random.secure();
    final nonce = base64UrlEncode(
      List.generate(32, (_) => random.nextInt(256)),
    );
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [],
      nonce: sha256.convert(utf8.encode(nonce)).toString(),
    );
    final token = credential.identityToken;
    if (token == null || token.isEmpty) {
      throw const ApiFailure('invalid_credentials');
    }
    return api.request(
      'POST',
      '/api/auth/apple',
      authenticated: false,
      body: {
        'authorization_code': credential.authorizationCode,
        'id_token': token,
        'nonce': nonce,
      },
    );
  });

  Future<void> signInH5Code(String value) async {
    final code = value.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(code)) {
      throw const ApiFailure('h5_login_code_invalid');
    }
    final generation = api.sessionVersion;
    final session = await api.request(
      'POST',
      '/api/auth/h5-code',
      authenticated: false,
      body: {'code': code},
    );
    if (generation != api.sessionVersion) {
      throw const ApiFailure('session_changed');
    }
    _token(session);
    final account = _validatedAccount(session['account']);
    if (account['user_id'] != session['user_id']) {
      throw const ApiFailure('invalid_credentials');
    }
    // Save the accepted one-time grant without another network request.
    await _signIn(() async => session, verifiedAccount: account);
  }

  Future<void> _signIn(
    Future<Map<String, dynamic>> Function() request, {
    Map<String, dynamic>? verifiedAccount,
    bool keepGuest = false,
  }) async {
    final clearing = keepGuest ? Future<void>.value() : clear();
    final generation = api.sessionVersion;
    await clearing;
    if (generation != api.sessionVersion) {
      throw const ApiFailure('session_changed');
    }
    final session = await request();
    if (generation != api.sessionVersion) {
      throw const ApiFailure('session_changed');
    }
    api.accessToken = _token(session);
    _refreshToken = session['refresh_token'] as String?;
    try {
      final account = verifiedAccount ?? await _readAccount();
      if (generation != api.sessionVersion) {
        throw const ApiFailure('session_changed');
      }
      await store.write(_session(api.accessToken!, _refreshToken));
      if (generation != api.sessionVersion) {
        throw const ApiFailure('session_changed');
      }
      _account = account;
      notifyListeners();
    } catch (_) {
      if (generation == api.sessionVersion) await clear();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _readAccount() async =>
      _validatedAccount(await api.get('/api/auth/me'));

  static Map<String, dynamic> _validatedAccount(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const ApiFailure('invalid_credentials');
    }
    final userId = value['user_id'];
    if (userId is! String || userId.isEmpty || value['kind'] == 'demo') {
      throw const ApiFailure('invalid_credentials');
    }
    return value;
  }

  Future<bool> refresh() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return false;
    final generation = api.sessionVersion;
    try {
      final next = await api.request(
        'POST',
        '/api/auth/refresh',
        authenticated: false,
        body: {'refresh_token': refreshToken},
      );
      if (generation != api.sessionVersion) return false;
      final token = _token(next);
      final rotated = next['refresh_token'] as String?;
      if (rotated == null || rotated.isEmpty) return false;
      await store.write(_session(token, rotated));
      if (generation != api.sessionVersion) return false;
      api.accessToken = token;
      _refreshToken = rotated;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    final revoke = api
        .request('POST', '/api/auth/logout', retryAuth: false)
        .then<void>((_) {}, onError: (Object _) {});
    await clear();
    await revoke;
  }

  Future<void> clear() async {
    ++api.sessionVersion;
    api.accessToken = null;
    _refreshToken = null;
    _account = null;
    notifyListeners();
    await store.clear();
  }

  static String _token(Map<String, dynamic> value) {
    final token = value['access_token'] ?? value['token'];
    if (token is! String || token.isEmpty) {
      throw const ApiFailure('invalid_credentials');
    }
    return token;
  }

  static Map<String, dynamic> _session(String token, String? refreshToken) => {
    'access_token': token,
    'refresh_token': ?refreshToken,
  };

  @override
  void dispose() {
    ++api.sessionVersion;
    api.refreshSession = null;
    api.onSessionExpired = null;
    super.dispose();
  }
}
