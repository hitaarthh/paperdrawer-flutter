import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
import 'package:paperdrawer/core/result/result.dart';
import 'package:paperdrawer/core/time/clock.dart';
import 'package:paperdrawer/data/drawer/drawer_paths.dart';
import 'package:paperdrawer/data/purchases/fake_purchase_gateway.dart';
import 'package:paperdrawer/data/purchases/memory_entitlement_store.dart';
import 'package:paperdrawer/domain/account/account_scope.dart';
import 'package:paperdrawer/domain/plans/active_plan.dart';
import 'package:paperdrawer/domain/plans/entitlement.dart';
import 'package:paperdrawer/domain/plans/plan.dart';
import 'package:paperdrawer/domain/plans/plan_change.dart';
import 'package:paperdrawer/domain/plans/purchase_products.dart';

final _supabase = Uri.parse('https://example.supabase.co');
const _clara = '11111111-1111-4111-8111-111111111111';
const _john = '22222222-2222-4222-8222-222222222222';

UserScope _scope(String id) => DrawerPaths.userScope(_supabase, id).requireValue;

/// End-to-end purchase cases from the spec, on the fake gateway the
/// simulator uses.
void main() {
  late FixedClock clock;
  late FakePurchaseLedger ledger;
  late FakePurchaseGateway phone;

  setUp(() {
    clock = FixedClock(DateTime.utc(2026, 11, 25, 10));
    ledger = FakePurchaseLedger();
    phone = FakePurchaseGateway(clock: clock, ledger: ledger);
  });

  tearDown(() => phone.dispose());

  ActivePlan resolve(AccountScope scope, Entitlements entitlements) =>
      ActivePlan.resolve(
        scope: scope,
        entitlements: entitlements,
        now: clock.now(),
      );

  test('pays as a guest: Essential unlocks, setup pending, then attaches',
      () async {
    final guestStore = MemoryEntitlementStore();
    final bought = (await phone.purchase(PurchaseProducts.essential)).requireValue;
    expect(await guestStore.save(bought), const Ok(unit));

    final guestPlan = resolve(const GuestScope(), bought);
    expect(guestPlan.plan, Plan.essential);
    expect(guestPlan.needsAccountSetup, isTrue);
    expect(guestPlan.canSync, isFalse);

    final signedIn = (await phone.logIn(_scope(_clara))).requireValue;
    final accountPlan = resolve(_scope(_clara), signedIn);
    expect(accountPlan.needsAccountSetup, isFalse);
    expect(accountPlan.syncKind, SyncKind.iCloud);
    expect(
      PlanChange.finishAccountSetup(Plan.essential).steps,
      const [OfferMoveGuestItems(), StartSyncWithFullUpload(SyncKind.iCloud)],
    );
  });

  test('signs in, then cancels the purchase: stays on Base', () async {
    await phone.logIn(_scope(_clara));
    phone.failNextWith = const PurchaseFailure(PurchaseFailureKind.cancelled);

    final result = await phone.purchase(PurchaseProducts.essential);

    expect(result.failureOrNull?.isSilent, isTrue);
    expect(
      (await phone.currentEntitlements()).requireValue.planAt(clock.now()),
      Plan.base,
    );
  });

  test('Ask to Buy: pending, then the plan arrives as a change', () async {
    phone.purchasesPending = true;
    final first = await phone.purchase(PurchaseProducts.essential);
    expect(first.failureOrNull, const PurchaseFailure(PurchaseFailureKind.pending));

    final changed = phone.entitlementChanges.first;
    phone.completePending();
    expect((await changed).planAt(clock.now()), Plan.essential);
  });

  test('new iPhone: signing in and restoring brings Essential back', () async {
    await phone.logIn(_scope(_clara));
    await phone.purchase(PurchaseProducts.essential);

    final newPhone = FakePurchaseGateway(
      clock: clock,
      ledger: ledger,
      anonymousId: r'$RCAnonymousID:new',
    );
    await newPhone.logIn(_scope(_clara));
    final restored = (await newPhone.restore()).requireValue;

    expect(restored.planAt(clock.now()), Plan.essential);
    await newPhone.dispose();
  });

  test("Clara's purchase stays hers when John signs in on her phone", () async {
    await phone.logIn(_scope(_clara));
    await phone.purchase(PurchaseProducts.essential);
    await phone.logOut();

    final john = (await phone.logIn(_scope(_john))).requireValue;
    expect(john.planAt(clock.now()), Plan.base);
    expect(ledger.grantsOf(_clara), hasLength(1));
  });

  test('a refund drops the plan to Base and asks only to stop sync', () async {
    await phone.logIn(_scope(_clara));
    final before = (await phone.purchase(PurchaseProducts.essential)).requireValue;
    expect(before.planAt(clock.now()), Plan.essential);

    final changed = phone.entitlementChanges.first;
    phone.refund(Plan.essential);
    final after = await changed;

    final plan = resolve(_scope(_clara), after);
    expect(plan.plan, Plan.base);
    expect(
      PlanChange.between(Plan.essential, plan.plan, isGuest: false).steps,
      const [StopSync(SyncKind.iCloud)],
    );
  });

  test('offline: the saved entitlements keep the plan', () async {
    await phone.logIn(_scope(_clara));
    final bought = (await phone.purchase(PurchaseProduct.proMonthly)).requireValue;
    final store = MemoryEntitlementStore(bought);

    phone.failNextWith = const NetworkFailure();
    final check = await phone.currentEntitlements();
    expect(check.failureOrNull, const NetworkFailure());

    final saved = (await store.load()).requireValue!;
    expect(resolve(_scope(_clara), saved).plan, Plan.pro);
  });

  test('a Pro subscription carries its renewal date', () async {
    final yearly =
        (await phone.purchase(PurchaseProduct.proYearly)).requireValue;
    expect(
      yearly.grants.single.expiresAt,
      clock.now().add(const Duration(days: 365)),
    );
  });

  test('the fake shows placeholder prices, never real ones', () async {
    final offers = (await phone.products()).requireValue;
    expect(offers.map((o) => o.product), PurchaseProducts.forSale);
    expect(offers.every((o) => o.displayPrice == 'Price from store'), isTrue);
  });

  test('the memory store reports injected storage failures', () async {
    final store = MemoryEntitlementStore()
      ..failNextWith = const StorageFailure(StorageFailureKind.full);
    final result = await store.save(Entitlements.none(clock.now()));
    expect(result.failureOrNull, const StorageFailure(StorageFailureKind.full));
    expect(store.saved, isNull);
  });
}
