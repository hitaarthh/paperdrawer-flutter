import '../../domain/plans/entitlement.dart';
import '../../domain/plans/plan.dart';

/// Maps design-v1's `profiles.plan` column (written by the website) to a
/// [PlanGrant], so a web Pro subscriber keeps Pro while the app is offline.
///
/// The column carries no expiry, so the grant is valid for
/// [Entitlements.offlineGrace] from the moment the profile was read
/// ([readAt]); every profile pull refreshes it. Once a read says the plan is
/// no longer `pro`, the grant is gone. (`Entitlements` adds its own offline
/// grace after that expiry when nothing was verified since, so an offline
/// phone keeps web Pro for at most twice the grace. A real expiry column on
/// the server would remove this approximation.)
///
/// Merging this grant with the store's grants is the entitlement
/// repository's job (wave 2): keep it as a separate source so a RevenueCat
/// web-billing grant is never mistaken for it.
abstract final class ProfilePlanGrant {
  /// The `profiles.plan` value for Pro.
  static const proValue = 'pro';

  /// The grant for [plan], or `null` when the profile grants nothing.
  static PlanGrant? fromProfile(String? plan, {required DateTime readAt}) =>
      plan?.trim().toLowerCase() == proValue
      ? PlanGrant(
          plan: Plan.pro,
          store: PurchaseStore.web,
          expiresAt: readAt.add(Entitlements.offlineGrace),
        )
      : null;
}
