import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
import 'package:paperdrawer/core/logging/app_logger.dart';
import 'package:paperdrawer/core/result/result.dart';
import 'package:paperdrawer/core/time/clock.dart';
import 'package:paperdrawer/data/drawer/drawer_paths.dart';
import 'package:paperdrawer/data/purchases/revenuecat_client.dart';
import 'package:paperdrawer/data/purchases/revenuecat_purchase_gateway.dart';
import 'package:paperdrawer/domain/account/account_scope.dart';
import 'package:paperdrawer/domain/plans/active_plan.dart';
import 'package:paperdrawer/domain/plans/entitlement.dart';
import 'package:paperdrawer/domain/plans/plan.dart';
import 'package:paperdrawer/domain/plans/purchase_products.dart';
import 'package:purchases_flutter/purchases_flutter.dart' show PurchasesErrorCode;

import 'fake_revenuecat_client.dart';

final _supabase = Uri.parse('https://example.supabase.co');
const _clara = '11111111-1111-4111-8111-111111111111';
const _john = '22222222-2222-4222-8222-222222222222';

UserScope _scope(String id) => DrawerPaths.userScope(_supabase, id).requireValue;

void main() {
  late FixedClock clock;
  late FakeRevenueCatClient client;
  late MemoryLogger logger;
  late RevenueCatPurchaseGateway gateway;

  RevenueCatPurchaseGateway gatewayFor(FakeRevenueCatClient c) =>
      RevenueCatPurchaseGateway(
        client: c,
        clock: clock,
        logger: logger,
        failures: RevenueCatPurchaseGateway.failureMapper(),
      );

  setUp(() {
    clock = FixedClock(DateTime.utc(2026, 11, 25, 10));
    client = FakeRevenueCatClient();
    logger = MemoryLogger();
    gateway = gatewayFor(client);
  });

  Plan planOf(Result<Entitlements> result) =>
      result.requireValue.planAt(clock.now());

  group('store errors become purchase failures', () {
    Future<AppFailure?> purchaseFailing(PurchasesErrorCode code) async {
      client.throwNext = RevenueCatException(code);
      return (await gateway.purchase(PurchaseProducts.essential)).failureOrNull;
    }

    test('closing the sheet is a silent cancel', () async {
      final failure = await purchaseFailing(
        PurchasesErrorCode.purchaseCancelledError,
      );
      expect(failure, const PurchaseFailure(PurchaseFailureKind.cancelled));
      expect(failure!.isSilent, isTrue);
    });

    test('Ask to Buy is pending', () async {
      expect(
        await purchaseFailing(PurchasesErrorCode.paymentPendingError),
        const PurchaseFailure(PurchaseFailureKind.pending),
      );
    });

    test('Screen Time restrictions are not allowed', () async {
      expect(
        await purchaseFailing(PurchasesErrorCode.purchaseNotAllowedError),
        const PurchaseFailure(PurchaseFailureKind.notAllowed),
      );
    });

    test('a store problem is a retryable store error', () async {
      final failure = await purchaseFailing(
        PurchasesErrorCode.storeProblemError,
      );
      expect(failure, const PurchaseFailure(PurchaseFailureKind.storeError));
      expect(failure!.isRetryable, isTrue);
    });

    test('offline is a network failure', () async {
      expect(
        await purchaseFailing(PurchasesErrorCode.networkError),
        const NetworkFailure(),
      );
    });

    test('a product the storefront lacks is unavailable', () async {
      client.storefront = {};
      final result = await gateway.purchase(PurchaseProduct.proYearly);
      expect(
        result.failureOrNull,
        const PurchaseFailure(PurchaseFailureKind.unavailable),
      );
    });

    test('failures are logged by code only', () async {
      await purchaseFailing(PurchasesErrorCode.storeProblemError);
      expect(
        logger.entries.single.$2,
        'RevenueCatPurchaseGateway.purchase: PurchaseFailure(storeError) '
        '(RevenueCatException)',
      );
    });
  });

  test('pending purchase unlocks later through entitlement changes', () async {
    client.throwNext = const RevenueCatException(
      PurchasesErrorCode.paymentPendingError,
    );
    final first = await gateway.purchase(PurchaseProducts.essential);
    expect(first.failureOrNull, const PurchaseFailure(PurchaseFailureKind.pending));

    final changes = gateway.entitlementChanges.first;
    client.server.owned[client.current] = [
      const RevenueCatEntitlement(
        identifier: PurchaseProducts.essentialEntitlement,
        isActive: true,
        store: PurchaseStore.appStore,
      ),
    ];
    client.updates.add(RevenueCatCustomer(entitlements: client.server.of(client.current)));
    expect((await changes).planAt(clock.now()), Plan.essential);
  });

  test('products come with the store price, in paywall order', () async {
    final offers = (await gateway.products()).requireValue;
    expect(offers.map((o) => o.product), PurchaseProducts.forSale);
    expect(offers.first.displayPrice, '₹essential_lifetime');
    expect(offers.first.currencyCode, 'INR');
  });

  test('purchase as a guest unlocks the plan but needs account setup', () async {
    final bought = await gateway.purchase(PurchaseProducts.essential);
    expect(planOf(bought), Plan.essential);
    expect(client.calls, ['purchase essential_lifetime as ${client.anonymousId}']);

    final plan = ActivePlan.resolve(
      scope: const GuestScope(),
      entitlements: bought.requireValue,
      now: clock.now(),
    );
    expect(plan.needsAccountSetup, isTrue);
    expect(plan.canSync, isFalse);

    // Signing in attaches the guest purchase to the new account.
    final loggedIn = await gateway.logIn(_scope(_clara));
    expect(planOf(loggedIn), Plan.essential);
    expect(client.server.of(_clara), isNotEmpty);
  });

  test('purchases are recorded against the signed-in account', () async {
    await gateway.logIn(_scope(_clara));
    await gateway.purchase(PurchaseProduct.proMonthly);

    expect(client.server.of(_clara), hasLength(1));
    expect(client.server.of(client.anonymousId), isEmpty);
  });

  test('logs in again before buying if RevenueCat drifted', () async {
    await gateway.logIn(_scope(_clara));
    client.resetToAnonymous();

    await gateway.purchase(PurchaseProducts.essential);

    expect(client.calls, [
      'logIn $_clara',
      'logIn $_clara',
      'purchase essential_lifetime as $_clara',
    ]);
  });

  test("a purchase never moves to another account", () async {
    await gateway.logIn(_scope(_clara));
    await gateway.purchase(PurchaseProducts.essential);
    await gateway.logOut();

    final john = await gateway.logIn(_scope(_john));
    expect(planOf(john), Plan.base);
    expect(planOf(await gateway.restore()), Plan.base);
    expect(client.server.of(_clara), hasLength(1));
  });

  test('restore on a new phone brings the account its purchase', () async {
    await gateway.logIn(_scope(_clara));
    await gateway.purchase(PurchaseProducts.essential);

    final newPhone = FakeRevenueCatClient(
      server: client.server,
      anonymousId: r'$RCAnonymousID:new-phone',
    );
    final newGateway = gatewayFor(newPhone);
    await newGateway.logIn(_scope(_clara));
    final restored = await newGateway.restore();

    expect(planOf(restored), Plan.essential);
    expect(restored.requireValue.verifiedAt, clock.now());
  });

  test('restore offline fails as a network failure', () async {
    client.throwNext = const RevenueCatException(
      PurchasesErrorCode.offlineConnectionError,
    );
    expect((await gateway.restore()).failureOrNull, const NetworkFailure());
  });

  test('a refund moves the plan down; the grant disappears', () async {
    await gateway.logIn(_scope(_clara));
    await gateway.purchase(PurchaseProducts.essential);

    final changes = gateway.entitlementChanges.first;
    client.refund(PurchaseProducts.essentialEntitlement);
    final after = await changes;

    expect(after.grants, isEmpty);
    expect(after.planAt(clock.now()), Plan.base);
  });

  test('log out of a guest is a no-op; of an account it calls the SDK', () async {
    expect(await gateway.logOut(), const Ok(unit));
    expect(client.calls, isEmpty);

    await gateway.logIn(_scope(_clara));
    expect(await gateway.logOut(), const Ok(unit));
    expect(client.calls.last, 'logOut');
  });

  test('entitlements are stamped with the clock as verified', () async {
    final result = await gateway.currentEntitlements();
    expect(result.requireValue.verifiedAt, clock.now());
  });

  test('an unexpected error never escapes', () async {
    client.throwNext = StateError('bug');
    final result = await gateway.currentEntitlements();
    expect(result.failureOrNull, isA<UnexpectedFailure>());
  });

  tearDown(() async => client.updates.close());
}
