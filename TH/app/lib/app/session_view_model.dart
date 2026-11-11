import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/models/birth_profile.dart';
import '../core/storage/session_store.dart';
import '../data/auth_repository.dart';
import '../data/configuration_repository.dart';
import '../data/profile_repository.dart';
import '../core/network/api_client.dart';

class SessionViewModel extends ChangeNotifier {
  SessionViewModel(this.auth, this.profiles, this.configuration, this.drafts) {
    final saved = drafts.preferences.getString('fate.locale');
    if (['th', 'en', 'zh', 'vi'].contains(saved)) locale = Locale(saved!);
    auth.api.locale = locale.languageCode;
    profile = profiles.local(auth.owner);
    _owner = auth.owner;
    auth.addListener(_identityChanged);
  }
  final AuthRepository auth;
  final ProfileRepository profiles;
  final ConfigurationRepository configuration;
  final LocalDraftStore drafts;
  Locale locale = const Locale('th');
  AppCapabilities capabilities = const AppCapabilities();
  BirthProfile? profile;
  bool loading = true, offline = false;
  String _owner = 'guest';
  String get owner => auth.owner;
  String? get displayName {
    final username = auth.account?['username'];
    if (username is String && username.trim().isNotEmpty) return username;
    final nickname = profile?.name.trim();
    return nickname == null || nickname.isEmpty ? null : nickname;
  }

  String get scope =>
      jsonEncode([owner, locale.languageCode, profile?.toJson()]);
  Future<void> initialize() async {
    try {
      capabilities = await configuration.load();
      await auth.restore();
    } catch (_) {
      offline = true;
    }
    loading = false;
    notifyListeners();
  }

  void _identityChanged() {
    if (_owner != owner) {
      _owner = owner;
      profile = profiles.local(owner);
      if (auth.hasSession && profile?.isServerRevision != true) {
        _restoreProfile(owner);
      }
    }
    notifyListeners();
  }

  Future<void> _restoreProfile(String expectedOwner) async {
    final previous = profile;
    try {
      final restored = await profiles.remote();
      if (restored == null || owner != expectedOwner || profile != previous) {
        return;
      }
      await profiles.save(expectedOwner, restored, serverContractReady: false);
      if (owner == expectedOwner && profile == previous) {
        profile = restored;
        notifyListeners();
      }
    } catch (_) {
      /* Keep local editing available while the remote profile is unavailable. */
    }
  }

  Future<void> changeLocale(String language) async {
    if (!['th', 'en', 'zh', 'vi'].contains(language)) return;
    locale = Locale(language);
    auth.api.locale = language;
    await drafts.preferences.setString('fate.locale', language);
    notifyListeners();
  }

  Future<void> saveProfile(BirthProfile value) async {
    if (capabilities.western && !auth.hasSession) {
      if (!capabilities.guestReading) {
        throw const ApiFailure('service_unavailable');
      }
      await auth.ensureGuest();
    }
    final currentOwner = owner;
    final sessionVersion = auth.api.sessionVersion;
    var candidate = value;
    if (capabilities.western && auth.hasSession && value.revision == null) {
      final existing = await profiles.remote();
      if (owner != currentOwner || auth.api.sessionVersion != sessionVersion) {
        throw const ApiFailure('session_changed');
      }
      if (existing != null) {
        candidate = BirthProfile.fromJson({
          ...value.toJson(),
          'profile_id': existing.id,
          'revision': existing.revision,
        });
      }
    }
    final saved = await profiles.save(
      currentOwner,
      candidate,
      serverContractReady: capabilities.western,
    );
    if (currentOwner != owner || auth.api.sessionVersion != sessionVersion) {
      throw const ApiFailure('session_changed');
    }
    profile = saved;
    notifyListeners();
  }

  Future<void> clearBirth() async {
    final currentOwner = owner;
    await profiles.clearLocal(currentOwner);
    if (currentOwner == owner) {
      profile = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    auth.removeListener(_identityChanged);
    super.dispose();
  }
}
