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
  String _orderRequestKey = newRequestKey(), _reportId = '';
  bool get canPurchase =>
      repository.nativeAvailable &&
      session.capabilities.applePurchase &&
      session.auth.signedIn &&
      repository.product != null &&
      !repository.needsVerification &&
      !repository.busy;
  bool get busy => repository.busy;
  String? get price => repository.product?.price;
  String? get status => error ?? repository.errorCode;
  void _configure() {
    repository.configure(session.owner, session.capabilities.applePurchase);
  }

  Future<void> prepare(String reportId) async {
    if (_reportId != reportId) {
      _reportId = reportId;
      _orderRequestKey = newRequestKey();
    }
    error = null;
    try {
      await repository.prepare(reportId, _orderRequestKey);
    } catch (_) {
      error = 'purchase_unavailable';
      notifyListeners();
    }
  }

  Future<void> buy() => repository.buy();
  bool get needsVerification => repository.needsVerification;
  Future<void> retryVerification() => repository.retryVerification();
  Future<void> restore() async {
    error = null;
    try {
      await repository.restore();
    } catch (_) {
      error = 'restore_unavailable';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    session.removeListener(_configure);
    repository.removeListener(notifyListeners);
    super.dispose();
  }
}
