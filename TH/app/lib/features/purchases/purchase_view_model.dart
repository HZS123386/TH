import 'package:flutter/foundation.dart';
import '../../app/session_view_model.dart';
import '../../data/purchase_repository.dart';
import '../chart/chart_view_model.dart';

class PurchaseViewModel extends ChangeNotifier {
  PurchaseViewModel(this.repository, this.session) {
    repository.addListener(notifyListeners);
    session.addListener(_configure);
    _configure();
  }
  final PurchaseRepository repository;
  final SessionViewModel session;
  String? error;
  bool restoring = false, restoreChecked = false, _disposed = false;
  String _owner = '';
  bool get storeEnabled =>
      !session.thaiAstrologyOnly &&
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        TargetPlatform.iOS => session.capabilities.applePurchase,
        TargetPlatform.android => session.capabilities.googlePurchase,
        _ => false,
      };
  String _orderRequestKey = newRequestKey(), _reportId = '';
  bool get canPurchase =>
      repository.nativeAvailable &&
      storeEnabled &&
      session.auth.signedIn &&
      repository.product != null &&
      !repository.needsVerification &&
      !busy;
  bool get busy => repository.busy || restoring;
  bool get canRestore =>
      repository.nativeAvailable &&
      storeEnabled &&
      session.auth.signedIn &&
      !repository.needsVerification &&
      !busy;
  String? get price => repository.product?.price;
  String? get status => error ?? repository.errorCode;
  void _configure() {
    if (_owner != session.owner) {
      _owner = session.owner;
      error = null;
      restoring = restoreChecked = false;
      _reportId = '';
      _orderRequestKey = newRequestKey();
    }
    repository.configure(session.owner, storeEnabled && session.auth.signedIn);
  }

  Future<void> prepare(String reportId) async {
    final owner = session.owner;
    if (_reportId != reportId) {
      _reportId = reportId;
      _orderRequestKey = newRequestKey();
    }
    error = null;
    try {
      await repository.prepare(reportId, _orderRequestKey);
    } catch (_) {
      if (!_disposed && session.owner == owner) {
        error = 'purchase_unavailable';
        notifyListeners();
      }
    }
  }

  Future<void> buy() => repository.buy();
  bool get needsVerification => repository.needsVerification;
  Future<void> retryVerification() => repository.retryVerification();
  Future<void> restore() async {
    if (!canRestore) return;
    final owner = session.owner;
    error = null;
    restoring = true;
    restoreChecked = false;
    notifyListeners();
    try {
      await repository.restore().timeout(const Duration(seconds: 35));
      if (!_disposed && session.owner == owner) restoreChecked = true;
    } catch (_) {
      if (!_disposed && session.owner == owner) error = 'restore_unavailable';
    } finally {
      if (!_disposed && session.owner == owner) {
        restoring = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    session.removeListener(_configure);
    repository.removeListener(notifyListeners);
    super.dispose();
  }
}
