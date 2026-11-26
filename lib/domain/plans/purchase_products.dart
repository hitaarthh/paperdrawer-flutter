import 'plan.dart';

/// How a product is paid for.
enum ProductBilling {
  /// Paid once, owned for life (a non-consumable in-app purchase).
  oneTime,

  /// An auto-renewing subscription, billed every month.
  monthly,

  /// An auto-renewing subscription, billed every year.
  yearly;

  /// True for auto-renewing subscriptions.
  bool get isSubscription => switch (this) {
    ProductBilling.oneTime => false,
    ProductBilling.monthly || ProductBilling.yearly => true,
  };
}

/// One product PaperDrawer sells in the stores.
///
/// The [id]s are the App Store Connect (and, later, Play Console) product
/// IDs, and the ones RevenueCat's products are configured with. Prices are
/// never part of the catalogue: they always come from the store at runtime
/// (`ProductOffer.displayPrice`).
enum PurchaseProduct {
  essentialLifetime(
    id: 'essential_lifetime',
    plan: Plan.essential,
    billing: ProductBilling.oneTime,
  ),
  proMonthly(id: 'pro_monthly', plan: Plan.pro, billing: ProductBilling.monthly),
  proYearly(id: 'pro_yearly', plan: Plan.pro, billing: ProductBilling.yearly);

  const PurchaseProduct({
    required this.id,
    required this.plan,
    required this.billing,
  });

  /// The store product ID.
  final String id;

  /// The plan this product grants.
  final Plan plan;

  final ProductBilling billing;

  bool get isSubscription => billing.isSubscription;
}

/// The catalogue the app sells, and the RevenueCat entitlement names that
/// map a purchase back to a [Plan].
///
/// Open in the spec, decided here by one line each:
/// - Essential one-time or yearly: [essential] (one-time for now). If it
///   becomes yearly, add the product to [PurchaseProduct] and point
///   [essential] at it.
/// - Prices: never hard-coded; they come from the store.
abstract final class PurchaseProducts {
  /// The product that sells Essential. Spec: open (one-time or yearly).
  static const PurchaseProduct essential = PurchaseProduct.essentialLifetime;

  /// The products that sell Pro, monthly first.
  static const List<PurchaseProduct> pro = [
    PurchaseProduct.proMonthly,
    PurchaseProduct.proYearly,
  ];

  /// Everything on the paywall, in display order.
  static const List<PurchaseProduct> forSale = [essential, ...pro];

  /// RevenueCat entitlement identifier that unlocks Essential.
  static const essentialEntitlement = 'essential';

  /// RevenueCat entitlement identifier that unlocks Pro.
  static const proEntitlement = 'pro';

  /// The products that sell [plan] (none for Base).
  static List<PurchaseProduct> forPlan(Plan plan) => switch (plan) {
    Plan.base => const [],
    Plan.essential => const [essential],
    Plan.pro => pro,
  };

  /// The product with store ID [id], or `null` when PaperDrawer doesn't
  /// sell it (an old or unknown product).
  static PurchaseProduct? byId(String id) {
    for (final product in forSale) {
      if (product.id == id) return product;
    }
    return null;
  }

  /// The plan a RevenueCat entitlement grants, or `null` for an entitlement
  /// this app doesn't know (it is then ignored, never guessed).
  static Plan? planForEntitlement(String identifier) => switch (identifier) {
    essentialEntitlement => Plan.essential,
    proEntitlement => Plan.pro,
    _ => null,
  };

  /// The RevenueCat entitlement for [plan], or `null` for Base.
  static String? entitlementFor(Plan plan) => switch (plan) {
    Plan.base => null,
    Plan.essential => essentialEntitlement,
    Plan.pro => proEntitlement,
  };
}
