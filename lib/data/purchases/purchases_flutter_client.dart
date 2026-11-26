import 'dart:async';

import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../domain/plans/entitlement.dart';
import 'revenuecat_client.dart';

/// RevenueCat settings from `--dart-define`.
///
/// `REVENUECAT_APPLE_API_KEY` is RevenueCat's public Apple SDK key
/// (`appl_…`). Staging and production use separate RevenueCat projects, so
/// each launcher passes its own key.
final class RevenueCatConfig {
  const RevenueCatConfig(this.appleApiKey);

  static const _appleKey = String.fromEnvironment('REVENUECAT_APPLE_API_KEY');

  /// The configured key, or `null` when the build has none (the composition
  /// root then uses `FakePurchaseGateway`, for example on the simulator).
  static RevenueCatConfig? fromEnvironment() => _appleKey.startsWith('appl_')
      ? const RevenueCatConfig(_appleKey)
      : null;

  final String appleApiKey;
}

/// [RevenueCatClient] over the `purchases_flutter` plugin. The only file
/// that imports the plugin's purchase API; it holds no logic beyond
/// converting types and errors.
///
/// Written against purchases_flutter 9.x; not compiled yet (rebuild mode).
final class PurchasesFlutterClient implements RevenueCatClient {
  PurchasesFlutterClient._();

  /// Configures the SDK once, at startup, as an anonymous customer. The app
  /// calls `PurchaseGateway.logIn` when an account is signed in.
  static Future<PurchasesFlutterClient> configure(RevenueCatConfig config) =>
      _call(() async {
        await Purchases.configure(PurchasesConfiguration(config.appleApiKey));
        return PurchasesFlutterClient._();
      });

  StreamController<RevenueCatCustomer>? _updates;

  @override
  Future<String> appUserId() => _call(() => Purchases.appUserID);

  @override
  Future<bool> isAnonymous() => _call(() => Purchases.isAnonymous);

  @override
  Future<RevenueCatCustomer> customer() =>
      _call(() async => _customer(await Purchases.getCustomerInfo()));

  @override
  Future<List<RevenueCatProduct>> products({
    required Set<String> oneTime,
    required Set<String> subscriptions,
  }) => _call(() async {
    final found = [
      if (oneTime.isNotEmpty)
        ...await Purchases.getProducts(
          oneTime.toList(),
          productCategory: ProductCategory.nonSubscription,
        ),
      if (subscriptions.isNotEmpty)
        ...await Purchases.getProducts(
          subscriptions.toList(),
          productCategory: ProductCategory.subscription,
        ),
    ];
    return [
      for (final product in found)
        RevenueCatProduct(
          id: product.identifier,
          displayPrice: product.priceString,
          currencyCode: product.currencyCode,
        ),
    ];
  });

  @override
  Future<RevenueCatCustomer> purchase(
    String productId, {
    required bool subscription,
  }) => _call(() async {
    final found = await Purchases.getProducts(
      [productId],
      productCategory: subscription
          ? ProductCategory.subscription
          : ProductCategory.nonSubscription,
    );
    if (found.isEmpty) {
      throw const RevenueCatException(
        PurchasesErrorCode.productNotAvailableForPurchaseError,
      );
    }
    final result = await Purchases.purchase(
      PurchaseParams.storeProduct(found.first),
    );
    return _customer(result.customerInfo);
  });

  @override
  Future<RevenueCatCustomer> restore() =>
      _call(() async => _customer(await Purchases.restorePurchases()));

  @override
  Future<RevenueCatCustomer> logIn(String appUserId) => _call(
    () async => _customer((await Purchases.logIn(appUserId)).customerInfo),
  );

  @override
  Future<RevenueCatCustomer> logOut() =>
      _call(() async => _customer(await Purchases.logOut()));

  @override
  Stream<RevenueCatCustomer> get customerUpdates {
    return (_updates ??= StreamController<RevenueCatCustomer>.broadcast(
      onListen: () => Purchases.addCustomerInfoUpdateListener(_onUpdate),
      onCancel: () => Purchases.removeCustomerInfoUpdateListener(_onUpdate),
    )).stream;
  }

  void _onUpdate(CustomerInfo info) => _updates?.add(_customer(info));

  static RevenueCatCustomer _customer(CustomerInfo info) => RevenueCatCustomer(
    entitlements: [
      for (final entitlement in info.entitlements.all.values)
        RevenueCatEntitlement(
          identifier: entitlement.identifier,
          isActive: entitlement.isActive,
          store: _store(entitlement.store),
          expiresAt: _date(entitlement.expirationDate),
        ),
    ],
  );

  static DateTime? _date(String? iso) =>
      iso == null ? null : DateTime.tryParse(iso);

  /// Comparisons rather than a `switch`: the plugin adds stores between
  /// releases. Anything not tied to one device's store (web billing,
  /// promotional) follows the account, like a web purchase.
  static PurchaseStore _store(Store store) {
    if (store == Store.appStore || store == Store.macAppStore) {
      return PurchaseStore.appStore;
    }
    if (store == Store.playStore || store == Store.amazon) {
      return PurchaseStore.playStore;
    }
    return PurchaseStore.web;
  }

  static Future<T> _call<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PlatformException catch (error) {
      throw RevenueCatException(PurchasesErrorHelper.getErrorCode(error));
    }
  }
}
