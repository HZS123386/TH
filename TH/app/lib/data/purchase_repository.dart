import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

import '../core/network/api_client.dart';
import '../core/storage/session_store.dart';

class PurchaseIntent {
  const PurchaseIntent(this.id, this.productId, this.accountRef);

  final String id, productId, accountRef;

  factory PurchaseIntent.fromJson(Map<String, dynamic> value) {
    final id = value['order_id'];
    final product = value['store_product_id'];
    final account = value['app_account_ref'];
    if (id is! String ||
        id.isEmpty ||
        product is! String ||
        product.isEmpty ||
        account is! String ||
        !RegExp(
          r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$',
          caseSensitive: false,
        ).hasMatch(account)) {
      throw const FormatException('invalid_purchase_order');
    }
    return PurchaseIntent(id, product, account);
  }

  Map<String, dynamic> toJson() => {
    'order_id': id,
    'store_product_id': productId,
    'app_account_ref': accountRef,
  };
}

class PurchaseRepository extends ChangeNotifier {
  PurchaseRepository(this.api, this.drafts, {InAppPurchase? store})
    : _injectedStore = store;

  final ApiClient api;
  final LocalDraftStore drafts;
  final InAppPurchase? _injectedStore;
  static const _draft = 'pending-apple-order';

  InAppPurchase? _store;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  SK2PurchaseDetails? _pending;
  int _generation = 0;
  String _owner = 'guest';
  bool _enabled = false, _working = false, _awaitingStore = false;

  PurchaseIntent? intent;
  ProductDetails? product;
  String? errorCode;
  Future<void> Function()? onVerified;

  bool get nativeAvailable => _store != null;
  bool get needsVerification => _pending != null;
  bool get busy => _working || _awaitingStore;

  Future<void> configure(String owner, bool enabled) async {
    if (_owner == owner && _enabled == enabled) return;
    final generation = ++_generation;
    _owner = owner;
    _enabled = enabled;
    _store = null;
    _pending = null;
    intent = null;
    product = null;
    errorCode = null;
    _working = _awaitingStore = false;
    final subscription = _subscription;
    _subscription = null;
    notifyListeners();
    await subscription?.cancel();
    if (generation != _generation ||
        !enabled ||
        owner == 'guest' ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    try {
      final store = _injectedStore ?? InAppPurchase.instance;
      if (!await store.isAvailable() || generation != _generation) return;
      final cached = drafts.read(owner, _draft);
      if (cached != null) {
        try {
          intent = PurchaseIntent.fromJson(cached);
        } on FormatException {
          await drafts.remove(owner, _draft);
        }
      }
      if (generation != _generation) return;
      _store = store;
      _subscription = store.purchaseStream.listen(
        (events) => unawaited(_receive(events, generation)),
      );
      notifyListeners();
    } catch (_) {
      if (generation == _generation) {
        _store = null;
        errorCode = 'purchase_unavailable';
        notifyListeners();
      }
    }
  }

  Future<void> prepare(String reportId, String key) async {
    final store = _store;
    if (store == null || busy || needsVerification) {
      throw const ApiFailure('purchase_unavailable');
    }
    final generation = _generation;
    final owner = _owner;
    _working = true;
    product = null;
    errorCode = null;
    notifyListeners();
    try {
      final order = PurchaseIntent.fromJson(
        await api.request(
          'POST',
          '/api/orders',
          requestKey: key,
          body: {
            'report_id': reportId,
            'store': 'apple',
            'catalog_sku': 'western_natal',
          },
        ),
      );
      if (generation != _generation) return;
      final catalog = await store.queryProductDetails({order.productId});
      if (generation != _generation) return;
      final sku = catalog.productDetails
          .where((item) => item.id == order.productId)
          .firstOrNull;
      if (sku == null) throw const ApiFailure('purchase_unavailable');
      await drafts.write(owner, _draft, order.toJson());
      if (generation != _generation) return;
      intent = order;
      product = sku;
    } finally {
      if (generation == _generation) {
        _working = false;
        notifyListeners();
      }
    }
  }

  Future<void> buy() async {
    final store = _store, sku = product, order = intent;
    if (store == null ||
        sku == null ||
        order == null ||
        busy ||
        needsVerification) {
      return;
    }
    final generation = _generation;
    _awaitingStore = true;
    errorCode = null;
    notifyListeners();
    try {
      final requested = await store.buyNonConsumable(
        purchaseParam: Sk2PurchaseParam(
          productDetails: sku,
          applicationUserName: order.accountRef,
        ),
      );
      if (!requested) throw const ApiFailure('purchase_unavailable');
    } catch (_) {
      if (generation == _generation) {
        _awaitingStore = false;
        errorCode = 'purchase_unavailable';
        notifyListeners();
      }
    }
  }

  Future<void> _receive(List<PurchaseDetails> events, int generation) async {
    for (final event in events) {
      if (generation != _generation || intent == null) return;
      final order = intent!;
      if (event.productID != order.productId) continue;
      if (event.status == PurchaseStatus.pending) continue;
      if (event.status == PurchaseStatus.canceled ||
          event.status == PurchaseStatus.error) {
        _awaitingStore = false;
        errorCode = event.status == PurchaseStatus.error
            ? 'purchase_unavailable'
            : null;
        notifyListeners();
        continue;
      }
      if (event is! SK2PurchaseDetails ||
          event.appAccountToken?.toLowerCase() !=
              order.accountRef.toLowerCase() ||
          event.purchaseID == null ||
          event.verificationData.serverVerificationData.isEmpty) {
        errorCode = 'purchase_verification_required';
        notifyListeners();
        continue;
      }
      if (_working) continue;
      _awaitingStore = false;
      _pending = event;
      await retryVerification();
    }
  }

  Future<void> retryVerification() async {
    final store = _store, event = _pending, order = intent;
    if (store == null || event == null || order == null || _working) return;
    final generation = _generation, owner = _owner;
    _working = true;
    errorCode = null;
    notifyListeners();
    var verified = false;
    try {
      final key = sha256.convert(
        utf8.encode('${order.id}:${event.purchaseID}'),
      );
      final result = await api.request(
        'POST',
        '/api/orders/${Uri.encodeComponent(order.id)}/verify',
        requestKey: key.toString(),
        body: {
          'signed_transaction': event.verificationData.serverVerificationData,
        },
      );
      if (generation != _generation) return;
      if (result['state'] != 'paid') {
        errorCode = 'purchase_verifying';
        return;
      }
      if (event.pendingCompletePurchase) await store.completePurchase(event);
      if (generation != _generation) return;
      await drafts.remove(owner, _draft);
      if (generation != _generation) return;
      _pending = null;
      intent = null;
      product = null;
      errorCode = null;
      verified = true;
    } catch (_) {
      if (generation == _generation) {
        errorCode = 'purchase_verification_required';
      }
    } finally {
      if (generation == _generation) {
        _working = false;
        notifyListeners();
      }
    }
    if (verified && generation == _generation) await onVerified?.call();
  }

  Future<void> restore() async {
    final store = _store;
    if (store == null) throw const ApiFailure('restore_unavailable');
    await store.restorePurchases(applicationUserName: intent?.accountRef);
  }

  @override
  void dispose() {
    ++_generation;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
