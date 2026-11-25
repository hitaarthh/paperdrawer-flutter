import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/domain/account/account_scope.dart';
import 'package:paperdrawer/domain/plans/active_plan.dart';
import 'package:paperdrawer/domain/plans/entitlement.dart';
import 'package:paperdrawer/domain/plans/plan.dart';

void main() {
  final day = DateTime.utc(2026, 12, 1);
  const lifetimeEssential = PlanGrant(
    plan: Plan.essential,
    store: PurchaseStore.appStore,
  );
  PlanGrant proUntil(
    DateTime expiry, {
    PurchaseStore store = PurchaseStore.appStore,
    DateTime? storeGraceUntil,
  }) => PlanGrant(
    plan: Plan.pro,
    store: store,
    expiresAt: expiry,
    storeGraceUntil: storeGraceUntil,
  );

  group('Entitlements.planAt', () {
    test('no grants means Base', () {
      expect(Entitlements.none(day).planAt(day), Plan.base);
    });

    test('a lifetime grant never expires', () {
      final e = Entitlements(grants: const [lifetimeEssential], verifiedAt: day);
      expect(e.planAt(day.add(const Duration(days: 3650))), Plan.essential);
      expect(e.ownsForLife(Plan.essential), isTrue);
    });

    test('the highest valid grant wins', () {
      final e = Entitlements(
        grants: [lifetimeEssential, proUntil(day.add(const Duration(days: 10)))],
        verifiedAt: day,
      );
      expect(e.planAt(day), Plan.pro);
    });

    test('Pro ending falls back to owned Essential, not Base', () {
      final expiry = day.add(const Duration(days: 10));
      final e = Entitlements(
        grants: [lifetimeEssential, proUntil(expiry)],
        verifiedAt: expiry.add(const Duration(days: 1)),
      );
      expect(e.planAt(expiry.add(const Duration(days: 2))), Plan.essential);
    });

    test('offline grace: unverified since expiry keeps Pro for 14 days', () {
      final expiry = day.add(const Duration(days: 10));
      final e = Entitlements(grants: [proUntil(expiry)], verifiedAt: day);
      final inGrace = expiry.add(const Duration(days: 13));
      expect(e.planAt(inGrace), Plan.pro);
      expect(e.isInGrace(inGrace), isTrue);
      expect(e.planAt(expiry.add(const Duration(days: 14))), Plan.base);
    });

    test('verified exactly at expiry still gets offline grace', () {
      final expiry = day.add(const Duration(days: 10));
      final e = Entitlements(grants: [proUntil(expiry)], verifiedAt: expiry);
      expect(e.planAt(expiry.add(const Duration(days: 1))), Plan.pro);
    });

    test('no grace once we verified after the expiry date', () {
      final expiry = day.add(const Duration(days: 10));
      final e = Entitlements(
        grants: [proUntil(expiry)],
        verifiedAt: expiry.add(const Duration(hours: 1)),
      );
      expect(e.planAt(expiry.add(const Duration(days: 1))), Plan.base);
    });

    test("the store's billing retry keeps Pro on, and isn't offline grace", () {
      final expiry = day.add(const Duration(days: 10));
      final e = Entitlements(
        grants: [
          proUntil(expiry, storeGraceUntil: expiry.add(const Duration(days: 16))),
        ],
        verifiedAt: expiry.add(const Duration(days: 1)),
      );
      final retrying = expiry.add(const Duration(days: 5));
      expect(e.planAt(retrying), Plan.pro);
      expect(e.isInGrace(retrying), isFalse);
    });

    test('not in grace when another valid grant gives the same plan', () {
      final expiry = day.add(const Duration(days: 10));
      final e = Entitlements(
        grants: [
          proUntil(expiry),
          proUntil(
            day.add(const Duration(days: 60)),
            store: PurchaseStore.web,
          ),
        ],
        verifiedAt: day,
      );
      expect(e.isInGrace(expiry.add(const Duration(days: 1))), isFalse);
    });

    test("purchases don't cross stores", () {
      final e = Entitlements(grants: const [lifetimeEssential], verifiedAt: day);
      expect(
        e.planAt(day, usableStores: {PurchaseStore.playStore, PurchaseStore.web}),
        Plan.base,
      );
    });

    test('grants cannot be changed after creation', () {
      final e = Entitlements(grants: [lifetimeEssential], verifiedAt: day);
      expect(() => e.grants.add(lifetimeEssential), throwsUnsupportedError);
    });
  });

  group('ActivePlan.resolve', () {
    final clara = UserScope.parse(
      projectKey: 'cHJvamVjdA',
      userId: '2f1d1a52-6c1e-4b8e-9d55-0d7c3b7f9a10',
    ).requireValue;

    test('nothing saved yet means Base', () {
      final active = ActivePlan.resolve(
        scope: const GuestScope(),
        entitlements: null,
        now: day,
      );
      expect(active.plan, Plan.base);
      expect(active.canSync, isFalse);
      expect(active.needsAccountSetup, isFalse);
    });

    test('signed-in Essential syncs through iCloud', () {
      final active = ActivePlan.resolve(
        scope: clara,
        entitlements: Entitlements(
          grants: const [lifetimeEssential],
          verifiedAt: day,
        ),
        now: day,
      );
      expect(active.plan, Plan.essential);
      expect(active.syncKind, SyncKind.iCloud);
      expect(active.scope, clara);
    });

    test('paid as a guest (sign-in failed): unlocked, but no sync until setup',
        () {
      final active = ActivePlan.resolve(
        scope: const GuestScope(),
        entitlements: Entitlements(
          grants: const [lifetimeEssential],
          verifiedAt: day,
        ),
        now: day,
      );
      expect(active.plan, Plan.essential);
      expect(active.needsAccountSetup, isTrue);
      expect(active.canSync, isFalse);
    });
  });
}
