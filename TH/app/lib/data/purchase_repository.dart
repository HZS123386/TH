import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

import '../core/network/api_client.dart';
import '../core/storage/session_store.dart';

class OrderIntent {
  const OrderIntent(this.id, this.productId, this.accountRef, this.reportId);
  final String id, productId, accountRef, reportId;
  factory OrderIntent.fromJson(Map<String, dynamic> row, String reportId) {
    if (row['order_id'] is! String ||
        row['store_product_id'] is! String ||
        row['app_account_ref'] is! String) {
      throw const ApiFailure('invalid_order');
    }
    // StoreKit 2 appAccountToken is a UUID owned and supplied by the backend.
    if (!RegExp(r'^[a-fA-F0-9]{8}(-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}$')
        .hasMatch(row['app_account_ref'] as String)) {
      throw const ApiFailure('invalid_account_reference');
    }
    return OrderIntent(
      row['order_id'] as String,
      row['store_product_id'] as String,
      row['app_account_ref'] as String,
      reportId,
    );
  }
  Map<String, dynamic> toJson() => {
    'order_id': id,
    'store_product_id': productId,
    'app_account_ref': accountRef,
    'report_id': reportId,
  };
}

/// Store callbacks trigger server verification; they never grant local access.
class PurchaseRepository extends ChangeNotifier {
  PurchaseRepository(this.api, this.drafts, {InAppPurchase? store})
    : _store = store ?? InAppPurchase.instance;
  final ApiClient api;
  final LocalDraftStore drafts;
  final InAppPurchase _store;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  String _owner = 'guest';
  OrderIntent? intent;
  ProductDetails? product;
  bool busy = false, enabled = false;
  String? errorCode;
  Future<void> Function()? onVerified;
  bool get nativeAvailable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  int _generation = 0;
  final _verifying = <String>{}, _verified = <String>{};
  PurchaseDetails? _pendingVerification;
  bool get needsVerification => _pendingVerification != null;
  Future<void> retryVerification() async {
    final pending = _pendingVerification;
    if (pending != null) await _handle([pending]);
  }

  Future<void> configure(String owner, bool backendEnabled) async {
    if (_owner == owner && enabled == backendEnabled) return;
    ++_generation;
    _pendingVerification = null;
    _verifying.clear();
    _verified.clear();
    _owner = owner;
    enabled = backendEnabled;
    intent = null;
    product = null;
    busy = false;
    errorCode = null;
    final saved = drafts.read(owner, 'pending-apple-order');
    if (saved != null) {
      try {
        intent = OrderIntent.fromJson(saved, saved['report_id'] as String);
      } catch (_) {
        /* Invalid local draft grants nothing. */
      }
    }
    if (nativeAvailable && enabled) {
      _subscription ??= _store.purchaseStream.listen(
        (events) {
          _handle(events);
        },
        onError: (_) {
          errorCode = 'purchase_failed';
          notifyListeners();
        },
      );
    }
    notifyListeners();
  }

  Future<void> prepare(String reportId, String requestKey) async {
    if (!nativeAvailable || !enabled || _owner == 'guest') {
      throw const ApiFailure('native_purchase_required');
    }
    if (busy) return;
    final generation = _generation;
    busy = true;
    notifyListeners();
    try {
      if (!await _store.isAvailable()) {
        throw const ApiFailure('store_unavailable');
      }
      final order = OrderIntent.fromJson(
        await api.request(
          'POST',
          '/api/orders',
          requestKey: requestKey,
          body: {
            'report_id': reportId,
            'store': 'apple',
            'catalog_sku': 'natal_report',
          },
        ),
        reportId,
      );
      if (generation != _generation) return;
      await drafts.write(_owner, 'pending-apple-order', order.toJson());
      intent = order;
      final response = await _store.queryProductDetails({order.productId});
      if (generation != _generation) return;
      if (response.error != null ||
          response.productDetails.length != 1 ||
          response.productDetails.single.id != order.productId) {
        throw const ApiFailure('product_unavailable');
      }
      product = response.productDetails.single;
    } finally {
      if (generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> buy() async {
    if (busy ||
        needsVerification ||
        !enabled ||
        !nativeAvailable ||
        product == null ||
        intent == null ||
        _owner == 'guest') {
      return;
    }
    busy = true;
    errorCode = null;
    notifyListeners();
    try {
      final started = await _store.buyNonConsumable(
        purchaseParam: Sk2PurchaseParam(
          productDetails: product!,
          applicationUserName: intent!.accountRef,
        ),
      );
      if (!started) {
        busy = false;
        errorCode = 'purchase_failed';
        notifyListeners();
      }
    } catch (_) {
      busy = false;
      errorCode = 'purchase_failed';
      notifyListeners();
    }
  }

  Future<void> restore() async {
    if (!nativeAvailable || !enabled || _owner == 'guest') {
      throw const ApiFailure('native_purchase_required');
    }
    await _store.restorePurchases(applicationUserName: intent?.accountRef);
    await onVerified?.call();
  }

  Future<void> _handle(List<PurchaseDetails> events) async {
    for (final purchase in events) {
      if (purchase.status == PurchaseStatus.pending) {
        busy = true;
        notifyListeners();
        continue;
      }
      if ([
        PurchaseStatus.error,
        PurchaseStatus.canceled,
      ].contains(purchase.status)) {
        busy = false;
        errorCode = purchase.status == PurchaseStatus.canceled
            ? 'purchase_canceled'
            : 'purchase_failed';
        notifyListeners();
        continue;
      }
      final order = intent, owner = _owner, generation = _generation;
      if (order == null ||
          owner == 'guest' ||
          purchase.productID != order.productId ||
          purchase is! SK2PurchaseDetails ||
          purchase.appAccountToken?.toLowerCase() !=
              order.accountRef.toLowerCase() ||
          purchase.verificationData.serverVerificationData.split('.').length !=
              3) {
        errorCode = 'purchase_verification_required';
        notifyListeners();
        continue;
      }
      final transactionKey = '$owner:${purchase.purchaseID}';
      if (_verified.contains(transactionKey) ||
          !_verifying.add(transactionKey)) {
        continue;
      }
      _pendingVerification = purchase;
      try {
        final response = await api.request(
          'POST',
          '/api/orders/${Uri.encodeComponent(order.id)}/verify',
          requestKey:
              'apple-${order.id}-${purchase.purchaseID ?? base64Url.encode(utf8.encode(order.id))}',
          body: {
            'signed_transaction':
                purchase.verificationData.serverVerificationData,
          },
        );
        if (generation != _generation) return;
        if (response['state'] != 'paid') {
          errorCode = 'purchase_verifying';
          busy = false;
          notifyListeners();
          continue;
        }
        if (purchase.pendingCompletePurchase) {
          await _store.completePurchase(purchase);
        }
        if (generation != _generation) return;
        await drafts.remove(owner, 'pending-apple-order');
        _verified.add(transactionKey);
        _pendingVerification = null;
        await onVerified?.call();
        busy = false;
        errorCode = null;
        notifyListeners();
      } catch (_) {
        if (generation == _generation) {
          busy = false;
          errorCode = 'purchase_verification_required';
          notifyListeners();
        }
      } finally {
        _verifying.remove(transactionKey);
      }
    }
  }

  @override
  void dispose() {
    ++_generation;
    _subscription?.cancel();
    super.dispose();
  }
}
