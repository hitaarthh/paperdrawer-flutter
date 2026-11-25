import 'package:flutter/foundation.dart';

import 'plan.dart';

/// Where a purchase was made.
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
  });

  final Plan plan;
  final PurchaseStore store;

  /// `null` for a one-time purchase that never expires.
  final DateTime? expiresAt;

  bool get isLifetime => expiresAt == null;

  @override
  bool operator ==(Object other) =>
      other is PlanGrant &&
      other.plan == plan &&
      other.store == store &&
      other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(plan, store, expiresAt);
}

/// The account's purchases as last confirmed by the purchase service, saved
/// in the account's own database so plan checks work offline.
@immutable
final class Entitlements {
  const Entitlements({required this.grants, required this.verifiedAt});

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
  /// A grant counts while it hasn't expired. A subscription that expired
  /// *after* we last verified it also counts for [offlineGrace], because the
  /// store may well have renewed it while the phone was offline. Once we've
  /// verified after the expiry date, the purchase service is the truth: if it
  /// still listed the grant, a renewal would have moved [PlanGrant.expiresAt].
  Plan planAt(DateTime now) =>
      Plan.highest(grants.where((grant) => _activeAt(grant, now)).map((g) => g.plan));

  /// True when [plan] is owned for life (Essential), whatever else lapses.
  bool ownsForLife(Plan plan) =>
      grants.any((grant) => grant.plan == plan && grant.isLifetime);

  /// True when the active plan at [now] only holds thanks to [offlineGrace].
  bool isInGrace(DateTime now) => grants.any(
    (grant) =>
        _activeAt(grant, now) &&
        grant.expiresAt != null &&
        !now.isBefore(grant.expiresAt!),
  );

  bool _activeAt(PlanGrant grant, DateTime now) {
    final expiresAt = grant.expiresAt;
    if (expiresAt == null) return true;
    if (now.isBefore(expiresAt)) return true;
    final unverifiedSinceExpiry = verifiedAt.isBefore(expiresAt);
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
