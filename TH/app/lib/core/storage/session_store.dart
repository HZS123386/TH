import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SessionStore {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> value);
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  const SecureSessionStore();
  static const _storage = FlutterSecureStorage();
  static const _key = 'fate.session.v1';
  static Future<void> _writes = Future.value();
  static Future<void> _ordered(Future<void> Function() action) {
    final operation = _writes.then((_) => action());
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  @override
  Future<Map<String, dynamic>?> read() async {
    await _writes;
    final value = await _storage.read(key: _key);
    if (value == null) return null;
    try {
      return jsonDecode(value) as Map<String, dynamic>;
    } on FormatException {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(Map<String, dynamic> value) =>
      _ordered(() => _storage.write(key: _key, value: jsonEncode(value)));
  @override
  Future<void> clear() => _ordered(() => _storage.delete(key: _key));
}

/// Preferences contain local drafts and example bookmarks, never entitlements.
class LocalDraftStore {
  LocalDraftStore(this.preferences);
  final SharedPreferences preferences;
  Map<String, dynamic>? read(String owner, String kind) {
    final raw = preferences.getString('fate.$kind.$owner');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(
    String owner,
    String kind,
    Map<String, dynamic> value,
  ) async {
    if (!await preferences.setString('fate.$kind.$owner', jsonEncode(value))) {
      throw StateError('storage_failed');
    }
  }

  Future<void> remove(String owner, String kind) async {
    await preferences.remove('fate.$kind.$owner');
  }
}
