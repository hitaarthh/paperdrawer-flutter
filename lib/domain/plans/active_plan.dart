import 'package:flutter/foundation.dart';

import '../account/account_scope.dart';
import 'entitlement.dart';
import 'plan.dart';
import 'plan_policy.dart';

/// The plan in force right now, and what the UI must tell the user about it.
///
/// Resolved from the open drawer ([AccountScope]) and the saved
/// [Entitlements], so it works offline at startup.
@immutable
final class ActivePlan {
  const ActivePlan._({
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
  }) {
    final plan = entitlements?.planAt(now) ?? Plan.base;
    final policy = PlanPolicy.of(plan);
    return ActivePlan._(
      policy: policy,
      needsAccountSetup: scope.isGuest && policy.requiresAccount,
      inOfflineGrace: entitlements?.isInGrace(now) ?? false,
    );
  }

  final PlanPolicy policy;

  /// Paid, but no account yet: features unlock, sync waits for sign-in.
  final bool needsAccountSetup;

  /// The plan holds only because we couldn't confirm a renewal while offline.
  final bool inOfflineGrace;

  Plan get plan => policy.plan;

  /// True when the plan's sync transport may run now.
  bool get canSync => policy.syncKind != SyncKind.none && !needsAccountSetup;

  @override
  bool operator ==(Object other) =>
      other is ActivePlan &&
      other.policy == policy &&
      other.needsAccountSetup == needsAccountSetup &&
      other.inOfflineGrace == inOfflineGrace;

  @override
  int get hashCode => Object.hash(policy, needsAccountSetup, inOfflineGrace);
}
