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
    api.onSessionExpired = () {
      clear();
    };
  }
  final ApiClient api;
  final SessionStore store;
  Map<String, dynamic>? account;
  String? _refreshToken;
  int _generation = 0;
  Future<void>? _creatingGuest;
  String get owner => account?['user_id'] as String? ?? 'guest';
  bool get hasSession => account != null;
  bool get isGuest => account?['kind'] == 'guest';
  bool get signedIn => hasSession && !isGuest;

  Future<void> ensureGuest() {
    if (hasSession) return Future.value();
    return _creatingGuest ??= _createGuest().whenComplete(
      () => _creatingGuest = null,
    );
  }

  Future<void> _createGuest() async {
    final generation = _generation;
    final response = await api.request(
      'POST',
      '/api/auth/guest',
      authenticated: false,
    );
    if (generation != _generation || hasSession) {
      throw const ApiFailure('session_changed');
    }
    await _accept(response);
    if (!isGuest || owner != response['user_id']) {
      throw const ApiFailure('session_changed');
    }
  }

  Future<void> restore() async {
    final sessionVersion = api.sessionVersion;
    final stored = await store.read();
    if (stored == null || api.sessionVersion != sessionVersion) return;
    api.accessToken = stored['access_token'] as String?;
    _refreshToken = stored['refresh_token'] as String?;
    try {
      await _loadAccount();
      if (api.sessionVersion != sessionVersion) return;
    } on ApiFailure catch (error) {
      if (api.sessionVersion != sessionVersion) return;
      if (error.status == 401) {
        await clear();
      } else {
        rethrow;
      }
    }
  }

  Future<void> signInApple() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      throw const ApiFailure('native_apple_required');
    }
    final nonce = List.generate(
      32,
      (_) => Random.secure().nextInt(256),
    ).map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email],
      nonce: sha256.convert(utf8.encode(nonce)).toString(),
    );
    if (credential.identityToken == null) {
      throw const ApiFailure('apple_identity_missing');
    }
    final response = await api.request(
      'POST',
      '/api/auth/apple',
      authenticated: false,
      body: {
        'authorization_code': credential.authorizationCode,
        'id_token': credential.identityToken,
        'nonce': nonce,
      },
    );
    await _accept(response);
  }

  // Kept until the existing FastAPI account API has moved to Apple/LINE sessions.
  bool get canUseDevelopmentLogin =>
      kDebugMode ||
      (kIsWeb &&
          const bool.fromEnvironment('FATE_DEVELOPMENT_PREVIEW') &&
          ['127.0.0.1', 'localhost'].contains(Uri.base.host));

  Future<void> signInDevelopment(
    String username,
    String password, {
    bool register = false,
  }) async {
    if (!canUseDevelopmentLogin) {
      throw const ApiFailure('development_login_disabled');
    }
    await _accept(
      await api.request(
        'POST',
        '/api/auth/${register ? 'register' : 'login'}',
        authenticated: register && isGuest,
        body: {'username': username.trim(), 'password': password},
      ),
    );
  }

  Future<void> _accept(Map<String, dynamic> response) async {
    final token = response['access_token'] ?? response['token'];
    if (token is! String || token.isEmpty) {
      throw const ApiFailure('invalid_session');
    }
    final sessionVersion = ++api.sessionVersion;
    api.accessToken = token;
    _refreshToken = response['refresh_token'] as String?;
    try {
      await _loadAccount();
      if (api.sessionVersion != sessionVersion) return;
      await store.write({
        'access_token': token,
        'refresh_token': _refreshToken,
      });
    } catch (_) {
      if (api.sessionVersion == sessionVersion) await clear();
      rethrow;
    }
  }

  Future<void> _loadAccount() async {
    final generation = ++_generation;
    final response = await api.get('/api/auth/me');
    if (response['user_id'] is! String) {
      throw const ApiFailure('invalid_identity');
    }
    if (generation == _generation) {
      account = response;
      notifyListeners();
    }
  }

  Future<bool> refresh() async {
    final token = _refreshToken, generation = _generation;
    if (token == null) return false;
    try {
      final response = await api.request(
        'POST',
        '/api/auth/refresh',
        authenticated: false,
        body: {'refresh_token': token},
      );
      if (generation != _generation ||
          response['access_token'] is! String ||
          response['refresh_token'] is! String) {
        return false;
      }
      api.accessToken = response['access_token'] as String;
      _refreshToken = response['refresh_token'] as String;
      await store.write({
        'access_token': api.accessToken,
        'refresh_token': _refreshToken,
      });
      return generation == _generation;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await api.request('POST', '/api/auth/logout');
    } finally {
      await clear();
    }
  }

  Future<void> clear() async {
    ++api.sessionVersion;
    ++_generation;
    api.accessToken = null;
    _refreshToken = null;
    account = null;
    notifyListeners();
    await store.clear();
  }
}
