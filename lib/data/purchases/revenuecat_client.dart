import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart' show PurchasesErrorCode;

import '../../domain/plans/entitlement.dart';

/// One RevenueCat entitlement as the SDK reports it, without SDK types.
@immutable
final class RevenueCatEntitlement {
  const RevenueCatEntitlement({
    required this.identifier,
    required this.isActive,
    required this.store,
    this.expiresAt,
    this.graceUntil,
  });

  /// The entitlement's identifier in the RevenueCat dashboard.
  final String identifier;

  /// False once it expired, was refunded or revoked.
  final bool isActive;

  /// Where it was bought. Stores that follow the account everywhere (web
  /// billing, promotional grants) are [PurchaseStore.web].
  final PurchaseStore store;

  /// `null` for a lifetime purchase.
  final DateTime? expiresAt;

  /// The store's billing-retry grace end, when known. RevenueCat already
  /// extends [expiresAt] through a store grace period, so this is usually
  /// `null`.
  final DateTime? graceUntil;

  @override
  bool operator ==(Object other) =>
      other is RevenueCatEntitlement &&
      other.identifier == identifier &&
      other.isActive == isActive &&
      other.store == store &&
      other.expiresAt == expiresAt &&
      other.graceUntil == graceUntil;

  @override
  int get hashCode =>
      Object.hash(identifier, isActive, store, expiresAt, graceUntil);
}

/// A RevenueCat customer's entitlements (from `CustomerInfo`).
@immutable
final class RevenueCatCustomer {
  RevenueCatCustomer({required List<RevenueCatEntitlement> entitlements})
    : entitlements = List.unmodifiable(entitlements);

  final List<RevenueCatEntitlement> entitlements;

  @override
  bool operator ==(Object other) =>
      other is RevenueCatCustomer &&
      listEquals(other.entitlements, entitlements);

  @override
  int get hashCode => Object.hashAll(entitlements);
}

/// A product as the store returned it (from `StoreProduct`).
@immutable
final class RevenueCatProduct {
  const RevenueCatProduct({
    required this.id,
    required this.displayPrice,
    required this.currencyCode,
  });

  final String id;
  final String displayPrice;
  final String currencyCode;
}

/// A RevenueCat error, reduced to its code. Content-free, so safe to keep as
/// a failure's cause.
final class RevenueCatException implements Exception {
  const RevenueCatException(this.code);

  final PurchasesErrorCode code;

  @override
  String toString() => 'RevenueCatException(${code.name})';
}

/// The RevenueCat SDK, reduced to what PaperDrawer calls (port).
///
/// `PurchasesFlutterClient` is the only implementation that touches the
/// plugin; tests use a fake. Every method throws [RevenueCatException] for a
/// store or service error; other errors pass through.
abstract interface class RevenueCatClient {
  /// The customer ID RevenueCat uses now: the PaperDrawer user ID after
  /// [logIn], an anonymous ID before.
  Future<String> appUserId();

  Future<bool> isAnonymous();

  Future<RevenueCatCustomer> customer();

  /// Fetches [oneTime] (non-subscription) and [subscriptions] products.
  Future<List<RevenueCatProduct>> products({
    required Set<String> oneTime,
    required Set<String> subscriptions,
  });

  /// Buys [productId]. Throws `productNotAvailableForPurchaseError` when the
  /// store doesn't sell it.
  Future<RevenueCatCustomer> purchase(
    String productId, {
    required bool subscription,
  });

  Future<RevenueCatCustomer> restore();

  Future<RevenueCatCustomer> logIn(String appUserId);

  Future<RevenueCatCustomer> logOut();

  /// Each customer change RevenueCat reports (renewal, refund, a pending
  /// purchase that completed).
  Stream<RevenueCatCustomer> get customerUpdates;
}
