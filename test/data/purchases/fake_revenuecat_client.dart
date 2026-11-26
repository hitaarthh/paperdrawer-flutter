import 'dart:async';

import 'package:paperdrawer/data/purchases/revenuecat_client.dart';
import 'package:paperdrawer/domain/plans/entitlement.dart';
import 'package:paperdrawer/domain/plans/purchase_products.dart';
import 'package:purchases_flutter/purchases_flutter.dart' show PurchasesErrorCode;

/// RevenueCat's server and SDK in memory: customers own entitlements; an
/// anonymous customer's purchases attach to an account that owns none.
final class FakeRevenueCatServer {
  final Map<String, List<RevenueCatEntitlement>> owned = {};

  List<RevenueCatEntitlement> of(String customer) => owned[customer] ?? const [];
}

final class FakeRevenueCatClient implements RevenueCatClient {
  FakeRevenueCatClient({
    FakeRevenueCatServer? server,
    this.anonymousId = r'$RCAnonymousID:phone',
    DateTime? now,
  }) : server = server ?? FakeRevenueCatServer(),
       _now = now ?? DateTime.utc(2026, 11, 25, 10);

  final FakeRevenueCatServer server;
  final String anonymousId;
  final DateTime _now;
  final List<String> calls = [];
  final StreamController<RevenueCatCustomer> updates =
      StreamController<RevenueCatCustomer>.broadcast();

  String? _account;

  /// The next call throws this, once.
  Object? throwNext;

  /// Products the storefront sells.
  Set<String> storefront = {
    for (final product in PurchaseProducts.forSale) product.id,
  };

  String get current => _account ?? anonymousId;

  /// Simulates the SDK being reset to anonymous behind the gateway's back.
  void resetToAnonymous() => _account = null;

  void _maybeThrow(String call) {
    calls.add(call);
    final error = throwNext;
    if (error != null) {
      throwNext = null;
      throw error;
    }
  }

  RevenueCatCustomer _customer() =>
      RevenueCatCustomer(entitlements: server.of(current));

  @override
  Future<String> appUserId() async => current;

  @override
  Future<bool> isAnonymous() async => _account == null;

  @override
  Future<RevenueCatCustomer> customer() async {
    _maybeThrow('customer');
    return _customer();
  }

  @override
  Future<List<RevenueCatProduct>> products({
    required Set<String> oneTime,
    required Set<String> subscriptions,
  }) async {
    _maybeThrow('products');
    return [
      for (final id in [...oneTime, ...subscriptions])
        if (storefront.contains(id))
          RevenueCatProduct(id: id, displayPrice: '₹$id', currencyCode: 'INR'),
    ];
  }

  @override
  Future<RevenueCatCustomer> purchase(
    String productId, {
    required bool subscription,
  }) async {
    _maybeThrow('purchase $productId as $current');
    if (!storefront.contains(productId)) {
      throw const RevenueCatException(
        PurchasesErrorCode.productNotAvailableForPurchaseError,
      );
    }
    final product = PurchaseProducts.byId(productId)!;
    (server.owned[current] ??= []).add(
      RevenueCatEntitlement(
        identifier: PurchaseProducts.entitlementFor(product.plan)!,
        isActive: true,
        store: PurchaseStore.appStore,
        expiresAt: subscription ? _now.add(const Duration(days: 30)) : null,
      ),
    );
    return _customer();
  }

  @override
  Future<RevenueCatCustomer> restore() async {
    _maybeThrow('restore as $current');
    return _customer();
  }

  @override
  Future<RevenueCatCustomer> logIn(String appUserId) async {
    _maybeThrow('logIn $appUserId');
    if (_account == null &&
        server.of(anonymousId).isNotEmpty &&
        server.of(appUserId).isEmpty) {
      server.owned[appUserId] = [...server.of(anonymousId)];
      server.owned.remove(anonymousId);
    }
    _account = appUserId;
    return _customer();
  }

  @override
  Future<RevenueCatCustomer> logOut() async {
    _maybeThrow('logOut');
    _account = null;
    return _customer();
  }

  @override
  Stream<RevenueCatCustomer> get customerUpdates => updates.stream;

  /// The store refunded [entitlement] for the current customer.
  void refund(String entitlement) {
    server.owned[current] = [
      for (final e in server.of(current))
        if (e.identifier == entitlement)
          RevenueCatEntitlement(
            identifier: e.identifier,
            isActive: false,
            store: e.store,
            expiresAt: _now,
          )
        else
          e,
    ];
    updates.add(_customer());
  }
}
