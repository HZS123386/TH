import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../app/session_view_model.dart';
import '../../core/models/calculation.dart';
import '../../core/network/api_client.dart';
import '../../data/western_repository.dart';

String newRequestKey() => List.generate(
  24,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

class ChartViewModel extends ChangeNotifier {
  ChartViewModel(this.repository, this.session) {
    _scope = session.scope;
    session.addListener(_changed);
  }
  final WesternRepository repository;
  final SessionViewModel session;
  String _scope = '', _requestKey = newRequestKey();
  CalculationSnapshot? result;
  bool loading = false, unavailable = false;
  String? error;
  int _generation = 0;
  void _changed() {
    if (_scope == session.scope) return;
    _scope = session.scope;
    ++_generation;
    _requestKey = newRequestKey();
    result = null;
    loading = false;
    error = null;
    unavailable = false;
    notifyListeners();
  }

  Future<void> calculate() async {
    if (loading) return;
    final profile = session.profile;
    if (!session.capabilities.western ||
        profile == null ||
        !profile.isServerRevision) {
      unavailable = true;
      notifyListeners();
      return;
    }
    final generation = ++_generation;
    loading = true;
    error = null;
    result = null;
    notifyListeners();
    try {
      final next = await repository.calculate(profile, _requestKey);
      if (generation == _generation) result = next;
    } on ApiFailure catch (failure) {
      if (generation == _generation) error = failure.code;
    } catch (_) {
      if (generation == _generation) error = 'calculation_failed';
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    ++_generation;
    session.removeListener(_changed);
    super.dispose();
  }
}
