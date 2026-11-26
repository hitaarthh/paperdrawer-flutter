import '../../domain/plans/entitlement.dart';
import '../../domain/plans/purchase_products.dart';
import 'revenuecat_client.dart';

/// Turns a RevenueCat customer into [Entitlements] (data mapper).
///
/// - Only active entitlements become grants. A refund, revocation or expiry
///   makes RevenueCat report the entitlement inactive, so the grant
///   disappears and the plan moves down (data on the phone is untouched).
/// - Entitlement identifiers map to plans through
///   [PurchaseProducts.planForEntitlement]; unknown ones are ignored.
/// - [Entitlements.verifiedAt] is [verifiedAt]: the service just confirmed
///   these grants.
abstract final class CustomerEntitlements {
  static Entitlements map(RevenueCatCustomer customer, DateTime verifiedAt) =>
      Entitlements(
        grants: [
          for (final entitlement in customer.entitlements)
            if (entitlement.isActive)
              if (PurchaseProducts.planForEntitlement(entitlement.identifier)
                  case final plan?)
                PlanGrant(
                  plan: plan,
                  store: entitlement.store,
                  expiresAt: entitlement.expiresAt,
                  storeGraceUntil: entitlement.graceUntil,
                ),
        ],
        verifiedAt: verifiedAt,
      );
}
