import 'package:flutter/foundation.dart';

import 'plan.dart';

/// Where a purchase was made.
///
/// `web` also covers a plan recorded on the account's server profile (the
/// existing `profiles.plan` column), so web Pro subscribers aren't capped at
/// 25 items while the app is offline.
enum PurchaseStore { appStore, playStore, web }

/// One plan an account has bought.
///
/// An account can hold several grants at once (Essential bought for life
/// *and* a Pro subscription). The active plan is the highest grant that is
/// still valid, which is how "Pro ended, Essential owned → back to
/// Essential" falls out without a special case.
@immutable
final class PlanGrant {
  const PlanGrant({
    required this.plan,
    required this.store,
    this.expiresAt,
    this.storeGraceUntil,
  });

  final Plan plan;
  final PurchaseStore store;

  /// `null` for a one-time purchase that never expires.
  final DateTime? expiresAt;

  /// The store's billing-retry or grace period end, when the store reports
  /// one (spec: "Pro stays on during billing retry").
  final DateTime? storeGraceUntil;

  bool get isLifetime => expiresAt == null;

  @override
  bool operator ==(Object other) =>
      other is PlanGrant &&
      other.plan == plan &&
      other.store == store &&
      other.expiresAt == expiresAt &&
      other.storeGraceUntil == storeGraceUntil;

  @override
  int get hashCode => Object.hash(plan, store, expiresAt, storeGraceUntil);
}

/// The account's purchases as last confirmed by the purchase service, saved
/// in the account's own database so plan checks work offline.
@immutable
final class Entitlements {
  Entitlements({required List<PlanGrant> grants, required this.verifiedAt})
    : grants = List.unmodifiable(grants);

  /// No purchases (a new account, or a guest).
  factory Entitlements.none(DateTime now) =>
      Entitlements(grants: const [], verifiedAt: now);

  final List<PlanGrant> grants;

  /// When the purchase service last confirmed [grants].
  final DateTime verifiedAt;

  /// How long past its expiry a subscription keeps working while we can't
  /// reach the purchase service. Spec: open, leaning 14 days.
  static const offlineGrace = Duration(days: 14);

  /// The plan in force at [now].
  ///
  /// A grant counts while it hasn't expired, or while the store's own grace
  /// (billing retry) lasts. A subscription that expired at or after the last
  /// verification also counts for [offlineGrace], because the store may well
  /// have renewed it while the phone was offline. Once we've verified after
  /// the expiry date, the purchase service is the truth.
  ///
  /// [usableStores] drops grants that can't apply on this platform
  /// ("purchases don't cross stores": an App Store Essential can't unlock
  /// anything on Android).
  Plan planAt(DateTime now, {Set<PurchaseStore>? usableStores}) => Plan.highest(
    _usable(usableStores)
        .where((grant) => _activeAt(grant, now, allowOfflineGrace: true))
        .map((grant) => grant.plan),
  );

  /// True when [plan] is owned for life, whatever else lapses.
  bool ownsForLife(Plan plan) =>
      grants.any((grant) => grant.plan == plan && grant.isLifetime);

  /// True when the plan at [now] only holds thanks to [offlineGrace].
  bool isInGrace(DateTime now, {Set<PurchaseStore>? usableStores}) =>
      planAt(now, usableStores: usableStores) !=
      Plan.highest(
        _usable(usableStores)
            .where((grant) => _activeAt(grant, now, allowOfflineGrace: false))
            .map((grant) => grant.plan),
      );

  Iterable<PlanGrant> _usable(Set<PurchaseStore>? stores) => stores == null
      ? grants
      : grants.where((grant) => stores.contains(grant.store));

  bool _activeAt(
    PlanGrant grant,
    DateTime now, {
    required bool allowOfflineGrace,
  }) {
    final expiresAt = grant.expiresAt;
    if (expiresAt == null) return true;
    if (now.isBefore(expiresAt)) return true;
    final storeGrace = grant.storeGraceUntil;
    if (storeGrace != null && now.isBefore(storeGrace)) return true;
    if (!allowOfflineGrace) return false;
    final unverifiedSinceExpiry = !verifiedAt.isAfter(expiresAt);
    return unverifiedSinceExpiry && now.isBefore(expiresAt.add(offlineGrace));
  }

  @override
  bool operator ==(Object other) =>
      other is Entitlements &&
      other.verifiedAt == verifiedAt &&
      listEquals(other.grants, grants);

  @override
  int get hashCode => Object.hash(verifiedAt, Object.hashAll(grants));
}
