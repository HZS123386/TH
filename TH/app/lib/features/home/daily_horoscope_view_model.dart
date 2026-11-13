import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/session_view_model.dart';
import '../../data/daily_horoscope_repository.dart';

class DailyHoroscopeViewModel extends ChangeNotifier
    with WidgetsBindingObserver {
  DailyHoroscopeViewModel(this._repository, this._preferences, this._session) {
    final stored = _preferences.getInt(_signKey);
    _manualSign = stored != null && stored >= 0 && stored < 12 ? stored : null;
    _birthSign = _session.profile?.westernSignIndex;
    _session.addListener(_profileChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  static const _signKey = 'fate.daily_zodiac';
  final DailyHoroscopeRepository _repository;
  final SharedPreferences _preferences;
  final SessionViewModel _session;
  int? _manualSign, _birthSign;
  Future<DailyHoroscopeDay>? _today;
  DailyHoroscopeDay? _loadedDay;
  Timer? _midnight;
  DateTime? _expires;
  bool _disposed = false;

  int? get birthSign => _birthSign;
  int? get homeSign => _birthSign ?? _manualSign;
  DailyHoroscopeDay? get loadedDay => _loadedDay;

  Future<DailyHoroscopeDay> get today => _today ??= _loadToday();

  void _profileChanged() {
    final nextSign = _session.profile?.westernSignIndex;
    if (nextSign == _birthSign) return;
    _birthSign = nextSign;
    notifyListeners();
  }

  Future<void> selectManualSign(int sign) async {
    if (_birthSign != null || sign == _manualSign) return;
    _manualSign = sign;
    notifyListeners();
    try {
      await _preferences.setInt(_signKey, sign);
    } on Exception {
      // The current session still uses the selected sign.
    }
  }

  Future<DailyHoroscopeDay> _loadToday() async {
    final day = await _repository.loadToday();
    if (!_disposed) {
      _loadedDay = day;
      _expires = DateTime.now().add(day.refreshAfter);
      _midnight = Timer(day.refreshAfter, refresh);
    }
    return day;
  }

  void refresh() {
    _midnight?.cancel();
    _expires = null;
    _today = null;
    _loadedDay = null;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final expires = _expires;
    if (state == AppLifecycleState.resumed &&
        expires != null &&
        !DateTime.now().isBefore(expires)) {
      refresh();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _midnight?.cancel();
    _session.removeListener(_profileChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
