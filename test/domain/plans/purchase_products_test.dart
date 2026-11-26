import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/domain/plans/plan.dart';
import 'package:paperdrawer/domain/plans/purchase_products.dart';

void main() {
  test('product IDs match the spec', () {
    expect(PurchaseProduct.essentialLifetime.id, 'essential_lifetime');
    expect(PurchaseProduct.proMonthly.id, 'pro_monthly');
    expect(PurchaseProduct.proYearly.id, 'pro_yearly');
  });

  test('Essential is sold once until the spec decides otherwise', () {
    expect(PurchaseProducts.essential, PurchaseProduct.essentialLifetime);
    expect(PurchaseProducts.essential.isSubscription, isFalse);
    expect(PurchaseProducts.essential.plan, Plan.essential);
  });

  test('Pro is sold monthly and yearly, both subscriptions', () {
    expect(PurchaseProducts.pro, [
      PurchaseProduct.proMonthly,
      PurchaseProduct.proYearly,
    ]);
    expect(PurchaseProducts.pro.every((p) => p.isSubscription), isTrue);
    expect(PurchaseProducts.pro.every((p) => p.plan == Plan.pro), isTrue);
  });

  test('the paywall lists Essential first, then Pro', () {
    expect(PurchaseProducts.forSale, [
      PurchaseProducts.essential,
      ...PurchaseProducts.pro,
    ]);
  });

  test('products for each plan; Base sells nothing', () {
    expect(PurchaseProducts.forPlan(Plan.base), isEmpty);
    expect(PurchaseProducts.forPlan(Plan.essential), [
      PurchaseProducts.essential,
    ]);
    expect(PurchaseProducts.forPlan(Plan.pro), PurchaseProducts.pro);
  });

  test('looks products up by store ID; unknown IDs are not guessed', () {
    expect(PurchaseProducts.byId('pro_yearly'), PurchaseProduct.proYearly);
    expect(PurchaseProducts.byId('family_monthly'), isNull);
  });

  test('entitlements map to plans and back; unknown ones are ignored', () {
    for (final plan in [Plan.essential, Plan.pro]) {
      final id = PurchaseProducts.entitlementFor(plan)!;
      expect(PurchaseProducts.planForEntitlement(id), plan);
    }
    expect(PurchaseProducts.entitlementFor(Plan.base), isNull);
    expect(PurchaseProducts.planForEntitlement('family'), isNull);
  });
}
