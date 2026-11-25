import 'package:flutter/foundation.dart';

import '../account/account_scope.dart';
import 'entitlement.dart';
import 'plan.dart';
import 'plan_policy.dart';

/// The plan in force right now for the open drawer, and what the UI must
/// tell the user about it.
///
/// Resolved from the open drawer ([scope]) and the saved [Entitlements], so
/// it works offline at startup. It carries its scope so the plan and the
/// drawer can never disagree.
@immutable
final class ActivePlan {
  const ActivePlan._({
    required this.scope,
    required this.policy,
    required this.needsAccountSetup,
    required this.inOfflineGrace,
  });

  /// Resolves the active plan.
  ///
  /// - No entitlements saved yet → Base.
  /// - A guest who paid but whose sign-in failed keeps the paid plan's
  ///   features on this device, with [needsAccountSetup] set so the UI shows
  ///   "Finish setup: sign in to start syncing". Sync never starts without an
  ///   account.
  factory ActivePlan.resolve({
    required AccountScope scope,
    required Entitlements? entitlements,
    required DateTime now,
    Set<PurchaseStore>? usableStores,
  }) {
    final plan =
        entitlements?.planAt(now, usableStores: usableStores) ?? Plan.base;
    final policy = PlanPolicy.of(plan);
    return ActivePlan._(
      scope: scope,
      policy: policy,
      needsAccountSetup: scope.isGuest && policy.requiresAccount,
      inOfflineGrace:
          entitlements?.isInGrace(now, usableStores: usableStores) ?? false,
    );
  }

  final AccountScope scope;
  final PlanPolicy policy;

  /// Paid, but no account yet: features unlock, sync waits for sign-in.
  final bool needsAccountSetup;

  /// The plan holds only because we couldn't confirm a renewal while offline.
  final bool inOfflineGrace;

  Plan get plan => policy.plan;

  /// The sync to run now: the plan's, or none for a guest.
  SyncKind get syncKind =>
      scope is UserScope ? policy.syncKind : SyncKind.none;

  /// True when the plan's sync transport may run now.
  bool get canSync => syncKind != SyncKind.none;

  @override
  bool operator ==(Object other) =>
      other is ActivePlan &&
      other.scope == scope &&
      other.policy == policy &&
      other.needsAccountSetup == needsAccountSetup &&
      other.inOfflineGrace == inOfflineGrace;

  @override
  int get hashCode =>
      Object.hash(scope, policy, needsAccountSetup, inOfflineGrace);
}
