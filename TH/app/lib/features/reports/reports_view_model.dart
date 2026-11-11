import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/session_view_model.dart';
import '../../core/models/calculation.dart';
import '../../core/models/report.dart';
import '../../core/network/api_client.dart';
import '../../data/reports_repository.dart';
import '../chart/chart_view_model.dart';

class ReportsViewModel extends ChangeNotifier with WidgetsBindingObserver {
  ReportsViewModel(this.repository, this.session) {
    _scope = session.scope;
    session.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
  }
  final ReportsRepository repository;
  final SessionViewModel session;
  ReportSnapshot? report;
  ReportReference? reference;
  List<ReportReference> history = [];
  bool loading = false;
  String? error;
  String _scope = '', _requestKey = newRequestKey();
  int _generation = 0, _failures = 0;
  bool _active = false, _foreground = true;
  Object? _activeView;
  Timer? _poll;
  bool get exampleSaved => repository.exampleSaved(session.owner);
  bool get hasResumable {
    final saved = repository.active(session.owner);
    return saved != null &&
        saved.locale == session.locale.languageCode &&
        saved.profileRevision != null &&
        saved.profileRevision == session.profile?.revision;
  }

  Future<void> saveExample() async {
    await repository.saveExample(session.owner);
    notifyListeners();
  }

  Future<void> removeExample() async {
    await repository.removeExample(session.owner);
    notifyListeners();
  }

  void _changed() {
    if (_scope == session.scope) return;
    _scope = session.scope;
    ++_generation;
    _requestKey = newRequestKey();
    _poll?.cancel();
    report = null;
    reference = null;
    history = [];
    loading = false;
    error = null;
    notifyListeners();
    if (_active && _foreground && session.auth.hasSession && hasResumable) {
      unawaited(resume());
    }
  }

  void setActive(bool value, {Object? view}) {
    // An outgoing route must not stop polling for the newly displayed report.
    if (!value && view != null && view != _activeView) return;
    _active = value;
    _activeView = value ? view : null;
    _poll?.cancel();
    if (value && reference != null) {
      unawaited(refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _poll?.cancel();
    if (_foreground && _active && reference != null) unawaited(refresh());
  }

  Future<void> generate(CalculationSnapshot result) async {
    if (result.example || loading) return;
    if (!session.capabilities.reports || session.profile?.revision == null) {
      throw const ApiFailure('service_unavailable');
    }
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final ref = await repository.create(
        session.owner,
        result.id,
        session.profile!.revision!,
        session.locale.languageCode,
        _requestKey,
      );
      if (generation != _generation) return;
      reference = ref;
    } catch (_) {
      if (generation == _generation) error = 'report_failed';
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
    if (generation == _generation && reference != null) await refresh();
  }

  Future<void> resume([ReportReference? selected]) async {
    final next = selected ?? repository.active(session.owner);
    if (next == null || next.locale != session.locale.languageCode) return;
    final generation = ++_generation, owner = session.owner;
    _poll?.cancel();
    reference = next;
    report = null;
    loading = false;
    _failures = 0;
    await repository.remember(owner, next);
    if (generation != _generation || owner != session.owner) return;
    await refresh();
  }

  Future<void> refresh() async {
    final ref = reference, generation = _generation;
    if (loading || ref == null || !_foreground) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final next = await repository.read(ref);
      if (generation != _generation || ref != reference) return;
      report = next;
      _failures = 0;
    } catch (_) {
      if (generation == _generation) {
        error = 'report_failed';
        ++_failures;
      }
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
        _poll?.cancel();
        if (_active &&
            _foreground &&
            _failures < 3 &&
            (report?.generating ?? false)) {
          _poll = Timer(const Duration(seconds: 3), refresh);
        }
      }
    }
  }

  Future<void> loadHistory() async {
    if (!session.auth.hasSession || !session.capabilities.reports) return;
    final generation = _generation;
    try {
      final rows = await repository.list();
      if (generation == _generation) {
        history = rows
            .where((r) => r.locale == session.locale.languageCode)
            .toList();
        notifyListeners();
      }
    } catch (_) {
      if (generation == _generation) {
        error = 'report_failed';
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    ++_generation;
    _poll?.cancel();
    session.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
