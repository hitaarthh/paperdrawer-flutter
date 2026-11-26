import 'package:flutter/foundation.dart';

import '../../core/result/result.dart';
import '../account/account_scope.dart';
import 'entitlement.dart';
import 'purchase_products.dart';

/// A product as the store sells it right now, with the store's own price.
///
/// The price is only ever the store's formatted label: PaperDrawer never
/// hard-codes or computes prices (spec: prices come from the store).
@immutable
final class ProductOffer {
  const ProductOffer({
    required this.product,
    required this.displayPrice,
    required this.currencyCode,
  });

  final PurchaseProduct product;

  /// The store's formatted price for this storefront, such as "₹999.00".
  final String displayPrice;

  /// ISO 4217 code of [displayPrice].
  final String currencyCode;

  @override
  bool operator ==(Object other) =>
      other is ProductOffer &&
      other.product == product &&
      other.displayPrice == displayPrice &&
      other.currencyCode == currencyCode;

  @override
  int get hashCode => Object.hash(product, displayPrice, currencyCode);
}

/// The purchase service (port): App Store purchases through RevenueCat in
/// the app, a fake in tests and the simulator.
///
/// Rules every implementation keeps:
/// - Every method returns a [Result] and never throws.
/// - A purchase belongs to the PaperDrawer account it was made under, never
///   to the phone or the Apple ID. Call [logIn] as soon as an account is
///   signed in, so purchases are recorded against that account. A purchase
///   never moves to another account by itself.
/// - A guest (no account) can still buy: the purchase is kept under the
///   store's anonymous customer, the plan unlocks on this device
///   (`ActivePlan.needsAccountSetup`), and [logIn] later attaches it to the
///   new account.
/// - Results are [Entitlements] as just confirmed by the service, so the
///   caller saves them with `EntitlementStore.save` for offline plan checks.
///
/// Failure cases (all methods that reach the store):
/// - `PurchaseFailure(cancelled)`: the user closed the sheet (silent).
/// - `PurchaseFailure(pending)`: Ask to Buy or a slow payment method. The
///   plan unlocks later through [entitlementChanges].
/// - `PurchaseFailure(notAllowed)`: purchases are disabled on this device,
///   or the store purchase belongs to another PaperDrawer account.
/// - `PurchaseFailure(unavailable)`: the product isn't sold in this
///   storefront.
/// - `PurchaseFailure(storeError)`: any other store or service error
///   (retryable).
/// - `NetworkFailure`: offline or timed out (retryable). Local work is never
///   blocked by this; the saved entitlements stay in force.
/// - `UnexpectedFailure`: anything else.
abstract interface class PurchaseGateway {
  /// The products for sale, with the store's prices, in
  /// [PurchaseProducts.forSale] order. A product the store doesn't return is
  /// left out.
  Future<Result<List<ProductOffer>>> products();

  /// The entitlements of the current customer, as the service knows them.
  Future<Result<Entitlements>> currentEntitlements();

  /// Shows the store's purchase sheet for [product].
  Future<Result<Entitlements>> purchase(PurchaseProduct product);

  /// "Restore purchases" (App Review requirement): asks the store for this
  /// Apple ID's purchases and returns the account's entitlements.
  Future<Result<Entitlements>> restore();

  /// Identifies the customer as [scope]'s account. Purchases made as a
  /// guest on this phone attach to the account when the account owns none.
  Future<Result<Entitlements>> logIn(UserScope scope);

  /// Forgets the account (sign-out). Ok when no account was logged in.
  Future<Result<Unit>> logOut();

  /// Entitlements each time the service reports a change: a pending
  /// purchase completed, a renewal, an expiry, a refund.
  Stream<Entitlements> get entitlementChanges;
}
