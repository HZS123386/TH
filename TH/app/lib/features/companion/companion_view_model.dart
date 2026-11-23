import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../app/session_view_model.dart';
import '../../core/network/api_client.dart';
import '../../data/companion_repository.dart';
import 'guardian.dart';

class CompanionViewModel extends ChangeNotifier {
  CompanionViewModel(this.repository, this.session) {
    _owner = session.owner;
    _profileScope = session.profile?.toJson().toString();
    _restoreSelection();
    session.addListener(_sessionChanged);
  }
  final CompanionRepository repository;
  final SessionViewModel session;
  late String _owner;
  String? _profileScope;
  Guardian selected = Guardian.love;
  List<Map<String, dynamic>> history = [], memories = [];
  Map<String, dynamic> _guardians = {};
  bool loading = false, sending = false, _disposed = false;
  String? error, pendingMessage;
  Guardian? sendingGuardian;
  String? _loadedOwner;
  int _generation = 0;
  int _memoryRevision = 0;

  void _restoreSelection() {
    final stored = session.drafts.read(_owner, 'companion') ?? {};
    final choice = stored['selected'];
    selected = Guardian.fromId(choice is String ? choice : null);
    final associations = stored['guardians'];
    _guardians = associations is Map
        ? {
            for (final entry in associations.entries)
              if (entry.key is String &&
                  Guardian.values.any((g) => g.name == entry.value))
                entry.key as String: entry.value,
          }
        : {};
  }

  void _sessionChanged() {
    if (_owner == session.owner) {
      final profileScope = session.profile?.toJson().toString();
      if (_profileScope != profileScope) {
        ++_generation;
        _loadedOwner = null;
        history = [];
        sending = loading = false;
        sendingGuardian = null;
        pendingMessage = null;
        unawaited(load(force: true));
      }
      _profileScope = profileScope;
      return;
    }
    ++_generation;
    _owner = session.owner;
    _profileScope = session.profile?.toJson().toString();
    _loadedOwner = null;
    history = [];
    memories = [];
    pendingMessage = error = null;
    sending = loading = false;
    sendingGuardian = null;
    _restoreSelection();
    _notify();
    unawaited(load());
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> select(Guardian guardian) async {
    selected = guardian;
    _notify();
    await _saveSelection();
  }

  Future<void> _saveSelection() async {
    try {
      await session.drafts.write(_owner, 'companion', {
        'selected': selected.name,
        'guardians': _guardians,
      });
    } catch (_) {
      /* A saved server conversation survives local storage failure. */
    }
  }

  Guardian? guardianFor(Map<String, dynamic> row) {
    final id = _guardians[row['id']];
    return id is String ? Guardian.fromId(id) : null;
  }

  int conversations(Guardian guardian) => history
      .where(
        (row) => row['role'] == 'assistant' && guardianFor(row) == guardian,
      )
      .length;

  List<Map<String, dynamic>> conversation(Guardian guardian) {
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < history.length; i++) {
      if (history[i]['role'] != 'assistant' ||
          guardianFor(history[i]) != guardian) {
        continue;
      }
      if (i > 0 && history[i - 1]['role'] == 'user') result.add(history[i - 1]);
      result.add(history[i]);
    }
    return result;
  }

  Future<void> load({bool force = false}) async {
    if (loading ||
        sending ||
        !session.auth.hasSession ||
        (!force && _loadedOwner == _owner)) {
      return;
    }
    final generation = _generation;
    final memoryRevision = _memoryRevision;
    loading = true;
    error = null;
    _notify();
    try {
      final values = await Future.wait([
        repository.history(),
        repository.memories(),
      ]);
      if (_disposed || generation != _generation) return;
      history = values[0];
      if (memoryRevision == _memoryRevision) memories = values[1];
      final ids = history.map((row) => row['id']).toSet();
      _guardians.removeWhere((id, _) => !ids.contains(id));
      _loadedOwner = _owner;
    } on ApiFailure catch (failure) {
      if (generation == _generation) error = failure.code;
    } catch (_) {
      if (generation == _generation) error = 'request_failed';
    } finally {
      if (generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  Future<bool> send(
    Guardian guardian,
    String message, {
    ReadingHandoff? reading,
  }) async {
    if (sending ||
        loading ||
        message.trim().isEmpty ||
        message.trim().length > 2000) {
      return false;
    }
    final provider = session.capabilities.companionProvider;
    if (reading?.owner != null && reading!.owner != _owner) {
      error = 'session_changed';
      _notify();
      return false;
    }
    if (provider == null ||
        !session.auth.hasSession ||
        session.profile == null) {
      error = session.profile == null
          ? 'profile_required'
          : 'provider_unconfigured';
      _notify();
      return false;
    }
    final generation = _generation;
    final text = message.trim();
    if (!session.companionConsent) {
      error = 'consent_required';
      _notify();
      return false;
    }
    sending = true;
    sendingGuardian = guardian;
    pendingMessage = text;
    error = null;
    _notify();
    try {
      // Pass only content already visible to the user, never locked report sections.
      var context = 'Selected conversation topic: ${guardian.name}.';
      if (reading != null) context += '\n${reading.title}\n${reading.text}';
      if (context.length > 1500) context = context.substring(0, 1500);
      final reply = await repository.send(
        message: text,
        provider: provider,
        context: context,
        period: reading?.period,
      );
      if (_disposed || generation != _generation) return false;
      final id = reply['id'] as String;
      _guardians[id] = guardian.name;
      final now = DateTime.now().millisecondsSinceEpoch / 1000;
      history = [
        ...history,
        {'id': 'question-$id', 'role': 'user', 'content': text, 'created': now},
        {...reply, 'role': 'assistant', 'created': now},
      ];
      if (history.length > 60) history = history.sublist(history.length - 60);
      final ids = history.map((row) => row['id']).toSet();
      _guardians.removeWhere((id, _) => !ids.contains(id));
      await _saveSelection();
      return true;
    } on ApiFailure catch (failure) {
      if (generation == _generation) error = failure.code;
      return false;
    } catch (_) {
      if (generation == _generation) error = 'request_failed';
      return false;
    } finally {
      if (generation == _generation) {
        sending = false;
        sendingGuardian = null;
        pendingMessage = null;
        _notify();
      }
    }
  }

  Future<void> saveMemory(String content, {String? id}) async {
    if (sending) throw const ApiFailure('chat_in_progress');
    if (!session.auth.hasSession) await session.auth.ensureGuest();
    final generation = _generation;
    final saved = await repository.saveMemory(content.trim(), id: id);
    if (_disposed || generation != _generation) {
      throw const ApiFailure('session_changed');
    }
    // An older history fetch must not replace a just-confirmed memory edit.
    ++_memoryRevision;
    memories = [...memories.where((row) => row['id'] != saved['id']), saved];
    _notify();
  }

  Future<void> clearHistory() async {
    if (sending || loading) throw const ApiFailure('chat_in_progress');
    final generation = _generation;
    loading = true;
    _notify();
    try {
      await repository.clearHistory();
      if (_disposed || generation != _generation) {
        throw const ApiFailure('session_changed');
      }
      history = [];
      _guardians = {};
      await _saveSelection();
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> deleteMemory(String id) async {
    if (sending) throw const ApiFailure('chat_in_progress');
    final generation = _generation;
    await repository.deleteMemory(id);
    if (_disposed || generation != _generation) {
      throw const ApiFailure('session_changed');
    }
    ++_memoryRevision;
    memories = memories.where((row) => row['id'] != id).toList();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    session.removeListener(_sessionChanged);
    super.dispose();
  }
}
