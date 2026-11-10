import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:fate_app/core/network/api_client.dart';
import 'package:fate_app/core/storage/session_store.dart';
import 'package:fate_app/data/purchase_repository.dart';

const accountRef = '11111111-1111-4111-8111-111111111111';

class FakeStore extends Fake implements InAppPurchase {
  final events = StreamController<List<PurchaseDetails>>.broadcast();
  int completed = 0;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => events.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async => ProductDetailsResponse(
    productDetails: [
      ProductDetails(
        id: 'fate.natal',
        title: 'FATE',
        description: 'Report',
        price: '฿199',
        rawPrice: 199,
        currencyCode: 'THB',
      ),
    ],
    notFoundIDs: [],
  );
  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed++;
  }
}

SK2PurchaseDetails event({String token = accountRef}) => SK2PurchaseDetails(
  productID: 'fate.natal',
  purchaseID: 'transaction-1',
  verificationData: PurchaseVerificationData(
    localVerificationData: '{}',
    serverVerificationData: 'header.payload.signature',
    source: 'app_store',
  ),
  transactionDate: '1',
  status: PurchaseStatus.purchased,
  appAccountToken: token,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  test(
    'a pending verification cannot finish or unlock a purchase; a verified retry can finish once',
    () async {
      var paid = false, verified = 0;
      final keys = <String?>[];
      final store = FakeStore();
      final api = ApiClient(
        'https://api.example.test',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/verify')) {
            keys.add(request.headers['Idempotency-Key']);
            return http.Response(
              jsonEncode({'state': paid ? 'paid' : 'pending'}),
              paid ? 200 : 202,
            );
          }
          return http.Response(
            jsonEncode({
              'order_id': 'order1',
              'store_product_id': 'fate.natal',
              'app_account_ref': accountRef,
            }),
            201,
          );
        }),
      );
      final drafts = LocalDraftStore(await SharedPreferences.getInstance());
      final repo = PurchaseRepository(api, drafts, store: store)
        ..onVerified = () async {
          verified++;
        };
      await repo.configure('owner-a', true);
      await repo.prepare('report1', 'order-key');
      final pending = Completer<void>();
      repo.addListener(() {
        if (repo.errorCode == 'purchase_verifying' && !pending.isCompleted) {
          pending.complete();
        }
      });
      store.events.add([event()]);
      await pending.future;
      expect(store.completed, 0);
      expect(verified, 0);
      expect(repo.needsVerification, isTrue);
      paid = true;
      await repo.retryVerification();
      expect(store.completed, 1);
      expect(verified, 1);
      expect(keys[0], keys[1]);
      expect(drafts.read('owner-a', 'pending-apple-order'), isNull);
      expect(drafts.read('owner-a', 'entitlements'), isNull);
      repo.dispose();
      api.close();
      await store.events.close();
    },
  );
  test(
    'a transaction for another account never reaches verification',
    () async {
      var verificationCalls = 0;
      final store = FakeStore();
      final api = ApiClient(
        'https://api.example.test',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/verify')) verificationCalls++;
          return http.Response(
            jsonEncode({
              'order_id': 'order1',
              'store_product_id': 'fate.natal',
              'app_account_ref': accountRef,
            }),
            201,
          );
        }),
      );
      final repo = PurchaseRepository(
        api,
        LocalDraftStore(await SharedPreferences.getInstance()),
        store: store,
      );
      await repo.configure('owner-a', true);
      await repo.prepare('report1', 'key');
      final rejected = Completer<void>();
      repo.addListener(() {
        if (repo.errorCode == 'purchase_verification_required' &&
            !rejected.isCompleted) {
          rejected.complete();
        }
      });
      store.events.add([event(token: '22222222-2222-4222-8222-222222222222')]);
      await rejected.future;
      expect(verificationCalls, 0);
      expect(store.completed, 0);
      repo.dispose();
      api.close();
      await store.events.close();
    },
  );
}
