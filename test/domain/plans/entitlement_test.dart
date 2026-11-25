import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/domain/account/account_scope.dart';
import 'package:paperdrawer/domain/plans/active_plan.dart';
import 'package:paperdrawer/domain/plans/entitlement.dart';
import 'package:paperdrawer/domain/plans/plan.dart';

void main() {
  final day = DateTime(2026, 12, 1);
  const lifetimeEssential = PlanGrant(
    plan: Plan.essential,
    store: PurchaseStore.appStore,
  );
  PlanGrant proUntil(DateTime expiry) =>
      PlanGrant(plan: Plan.pro, store: PurchaseStore.appStore, expiresAt: expiry);

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

    test('no grace once we verified after the expiry date', () {
      final expiry = day.add(const Duration(days: 10));
      final e = Entitlements(
        grants: [proUntil(expiry)],
        verifiedAt: expiry.add(const Duration(hours: 1)),
      );
      expect(e.planAt(expiry.add(const Duration(days: 1))), Plan.base);
    });

    test('not in grace before expiry', () {
      final e = Entitlements(
        grants: [proUntil(day.add(const Duration(days: 5)))],
        verifiedAt: day,
      );
      expect(e.isInGrace(day), isFalse);
    });
  });

  group('ActivePlan.resolve', () {
    final clara = UserScope.parse('2f1d1a52-6c1e-4b8e-9d55-0d7c3b7f9a10').requireValue;

    test('nothing saved yet means Base', () {
      final active = ActivePlan.resolve(scope: const GuestScope(), entitlements: null, now: day);
      expect(active.plan, Plan.base);
      expect(active.canSync, isFalse);
      expect(active.needsAccountSetup, isFalse);
    });

    test('signed-in Essential can sync', () {
      final active = ActivePlan.resolve(
        scope: clara,
        entitlements: Entitlements(grants: const [lifetimeEssential], verifiedAt: day),
        now: day,
      );
      expect(active.plan, Plan.essential);
      expect(active.canSync, isTrue);
    });

    test('paid as a guest (sign-in failed): unlocked, but no sync until setup', () {
      final active = ActivePlan.resolve(
        scope: const GuestScope(),
        entitlements: Entitlements(grants: const [lifetimeEssential], verifiedAt: day),
        now: day,
      );
      expect(active.plan, Plan.essential);
      expect(active.needsAccountSetup, isTrue);
      expect(active.canSync, isFalse);
    });
  });
}
