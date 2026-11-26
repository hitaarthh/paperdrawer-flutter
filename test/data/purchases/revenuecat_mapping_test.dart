import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
import 'package:paperdrawer/data/purchases/customer_entitlements.dart';
import 'package:paperdrawer/data/purchases/profile_plan_grant.dart';
import 'package:paperdrawer/data/purchases/revenuecat_client.dart';
import 'package:paperdrawer/data/purchases/revenuecat_failure_rule.dart';
import 'package:paperdrawer/data/purchases/revenuecat_purchase_gateway.dart';
import 'package:paperdrawer/domain/plans/entitlement.dart';
import 'package:paperdrawer/domain/plans/plan.dart';
import 'package:paperdrawer/domain/plans/purchase_products.dart';
import 'package:purchases_flutter/purchases_flutter.dart' show PurchasesErrorCode;

void main() {
  final trace = StackTrace.current;
  final now = DateTime.utc(2026, 11, 25, 10);

  group('RevenueCatFailureRule', () {
    final mapper = RevenueCatPurchaseGateway.failureMapper();
    AppFailure map(PurchasesErrorCode code) =>
        mapper.map(RevenueCatException(code), trace);

    test('maps each documented store code to its kind', () {
      const expected = {
        PurchasesErrorCode.purchaseCancelledError: PurchaseFailureKind.cancelled,
        PurchasesErrorCode.paymentPendingError: PurchaseFailureKind.pending,
        PurchasesErrorCode.purchaseNotAllowedError:
            PurchaseFailureKind.notAllowed,
        PurchasesErrorCode.insufficientPermissionsError:
            PurchaseFailureKind.notAllowed,
        PurchasesErrorCode.receiptAlreadyInUseError:
            PurchaseFailureKind.belongsToAnotherAccount,
        PurchasesErrorCode.productNotAvailableForPurchaseError:
            PurchaseFailureKind.unavailable,
        PurchasesErrorCode.ineligibleError: PurchaseFailureKind.unavailable,
        PurchasesErrorCode.storeProblemError: PurchaseFailureKind.storeError,
      };
      expected.forEach((code, kind) {
        expect(map(code), PurchaseFailure(kind), reason: code.name);
      });
    });

    test('every other RevenueCat code is a store error', () {
      expect(
        map(PurchasesErrorCode.unknownError),
        const PurchaseFailure(PurchaseFailureKind.storeError),
      );
      expect(
        map(PurchasesErrorCode.invalidCredentialsError),
        const PurchaseFailure(PurchaseFailureKind.storeError),
      );
    });

    test('connection codes are network failures', () {
      expect(map(PurchasesErrorCode.networkError), const NetworkFailure());
      expect(
        map(PurchasesErrorCode.offlineConnectionError),
        const NetworkFailure(),
      );
    });

    test('ignores errors that are not RevenueCat errors', () {
      expect(const RevenueCatFailureRule().tryMap(StateError('x'), trace), isNull);
    });
  });

  group('CustomerEntitlements', () {
    test('active entitlements become grants with store and expiry', () {
      final expiry = now.add(const Duration(days: 30));
      final entitlements = CustomerEntitlements.map(
        RevenueCatCustomer(
          entitlements: [
            const RevenueCatEntitlement(
              identifier: PurchaseProducts.essentialEntitlement,
              isActive: true,
              store: PurchaseStore.appStore,
            ),
            RevenueCatEntitlement(
              identifier: PurchaseProducts.proEntitlement,
              isActive: true,
              store: PurchaseStore.web,
              expiresAt: expiry,
            ),
          ],
        ),
        now,
      );

      expect(entitlements.grants, [
        const PlanGrant(plan: Plan.essential, store: PurchaseStore.appStore),
        PlanGrant(plan: Plan.pro, store: PurchaseStore.web, expiresAt: expiry),
      ]);
      expect(entitlements.verifiedAt, now);
      expect(entitlements.ownsForLife(Plan.essential), isTrue);
    });

    test('refunded (inactive) and unknown entitlements grant nothing', () {
      final entitlements = CustomerEntitlements.map(
        RevenueCatCustomer(
          entitlements: [
            RevenueCatEntitlement(
              identifier: PurchaseProducts.essentialEntitlement,
              isActive: false,
              store: PurchaseStore.appStore,
              expiresAt: now,
            ),
            const RevenueCatEntitlement(
              identifier: 'family',
              isActive: true,
              store: PurchaseStore.appStore,
            ),
          ],
        ),
        now,
      );

      expect(entitlements.grants, isEmpty);
      expect(entitlements.planAt(now), Plan.base);
    });

    test('Pro ending falls back to owned Essential', () {
      final entitlements = CustomerEntitlements.map(
        RevenueCatCustomer(
          entitlements: [
            const RevenueCatEntitlement(
              identifier: PurchaseProducts.essentialEntitlement,
              isActive: true,
              store: PurchaseStore.appStore,
            ),
            RevenueCatEntitlement(
              identifier: PurchaseProducts.proEntitlement,
              isActive: false,
              store: PurchaseStore.appStore,
              expiresAt: now,
            ),
          ],
        ),
        now,
      );
      expect(entitlements.planAt(now), Plan.essential);
    });
  });

  group('ProfilePlanGrant', () {
    test("profiles.plan == 'pro' is a web Pro grant valid for the grace", () {
      expect(
        ProfilePlanGrant.fromProfile('pro', readAt: now),
        PlanGrant(
          plan: Plan.pro,
          store: PurchaseStore.web,
          expiresAt: now.add(Entitlements.offlineGrace),
        ),
      );
    });

    test('any other value grants nothing', () {
      for (final value in [null, '', 'base', 'free', 'family']) {
        expect(ProfilePlanGrant.fromProfile(value, readAt: now), isNull);
      }
    });

    test('a web Pro subscriber keeps Pro offline until the grace ends', () {
      final grant = ProfilePlanGrant.fromProfile('pro', readAt: now)!;
      final entitlements = Entitlements(grants: [grant], verifiedAt: now);

      expect(entitlements.planAt(now.add(const Duration(days: 13))), Plan.pro);
      expect(
        entitlements.isInGrace(now.add(const Duration(days: 13))),
        isFalse,
      );
    });
  });
}
